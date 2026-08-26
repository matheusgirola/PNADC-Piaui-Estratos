# ==============================================================================
# 06_upas_piaui.R — constrói as UPAs (Unidades Primárias de Amostragem) do
# Piauí a partir dos setores censitários do Censo 2022.
#
# POR QUE ISSO EXISTE
# -------------------
# O 7º dígito do Estrato da PNADC (o "E" do AAAGGSE) é o estrato
# estatístico — a faixa de renda do responsável pelo domicílio. A
# especificação do IBGE define esse estrato em termos de UPAs, não de
# setores:
#
#   "Para cada estrato geográfico, serão definidos de 2 a 5 estratos
#    estatísticos, garantido que cada um tenha pelo menos 150 UPAs."
#
# Ou seja: sem UPA não há como chegar no E. Este script produz as UPAs; o
# 07_estrato_estatistico.R usa elas pra estimar o E.
#
# REGRA DE CONSTRUÇÃO (Censo 2022, critérios atualizados pelo IBGE)
# ----------------------------------------------------------------
#   "As UPAs são formadas por setores censitários contíguos, respeitando a
#    situação e o tipo da área, sendo admitida a constituição de UPA
#    individual quando um setor isolado atende aos critérios mínimos
#    estabelecidos. [...] mínimo de 60 domicílios particulares permanentes
#    ocupados para UPAs rurais e mínimo de 90 domicílios ocupados para UPAs
#    urbanas, tanto em FCUs quanto fora de FCUs."
#
# Traduzindo em código:
#   - contiguidade  -> grafo de adjacência entre setores (sf::st_touches)
#   - "respeitando a situação e o tipo da área" -> a agregação nunca
#     atravessa a fronteira de S (1 urbano tradicional / 2 rural / 3 FCU),
#     nem a fronteira do município
#   - mínimo        -> 60 DPPO rural, 90 DPPO urbano e FCU
#   - UPA individual -> setor que já atinge o mínimo sozinho não é fundido
#
# DE ONDE VEM O NÚMERO DE DOMICÍLIOS
# ----------------------------------
# Da tabela de renda do responsável do Censo 2022 (Agregados por Setores),
# variável V06001 = "Pessoas responsáveis em domicílios particulares
# permanentes ocupados". Como todo DPPO tem exatamente uma pessoa
# responsável, V06001 É a contagem de DPPO do setor — é a variável de
# capacidade que os critérios de 60/90 pedem.
#
# ENTRADAS
#   data/raw/setores/PI_setores_CD2022.shp      (malha do Censo 2022)
#   data/raw/renda/Agregados_por_setores_renda_responsavel_BR.xlsx
#       (ou o cache data/raw/renda/renda_responsavel_PI.csv)
#   output/estratos_piaui.gpkg                  (do 04_mapas_estratos_piaui.R)
#
# SAÍDAS
#   output/setores_com_upa_piaui.gpkg   setor -> UPA + AAA/GG/S
#   output/upas_piaui.csv               uma linha por UPA (DPPO, renda)
#   output/tabelas/diagnostico_upas.csv diagnóstico da construção
# ==============================================================================

library(sf)
library(dplyr)
library(readr)
library(stringr)
library(igraph)

sf::sf_use_s2(FALSE)   # mesma escolha do 05: a malha do IBGE tem pequenas
                       # imperfeições que o s2 rejeita e o GEOS tolera

dir.create("output/tabelas", recursive = TRUE, showWarnings = FALSE)

# Mínimos de DPPO por tipo de área — os critérios do Censo 2022.
MIN_DPPO <- c("1" = 90,   # urbano tradicional (exceto FCU)
              "2" = 60,   # rural
              "3" = 90)   # FCU (Favelas e Comunidades Urbanas)

# ---- 1. Malha de setores ------------------------------------------------------

caminho_shp <- "./data/raw/PI_setores_CD2022/PI_setores_CD2022.shp"
if (!file.exists(caminho_shp)) {
  stop("Não achei ", caminho_shp, ". Baixa a malha de setores do Censo 2022 do Piauí ",
       "(PI_setores_CD2022.zip, no geoftp do IBGE) e descompacta em data/raw/setores/.")
}

setores <- st_read(caminho_shp, quiet = TRUE) %>%
  mutate(
    CD_SETOR = as.character(CD_SETOR),
    CD_MUN   = as.character(CD_MUN),
    CD_SIT   = suppressWarnings(as.integer(as.character(CD_SIT))),
    CD_TIPO  = suppressWarnings(as.integer(as.character(CD_TIPO)))
  )

message(nrow(setores), " setores censitários no Piauí.")

# ---- 2. S (6º dígito): situação e tipo de área --------------------------------
# Na malha de 2022 o IBGE separa as duas coisas em campos diferentes:
#   CD_SIT  1,2,3 = urbano   |  5,6,7,8 = rural   |  9 = casos especiais
#   CD_TIPO 1     = FCU (Favela ou Comunidade Urbana); 0 = comum; 2..9 = outros
#           tipos especiais (aldeia indígena, quilombo, alojamento etc.)
#
# Conferido nos dados: CD_TIPO == 1 bate exatamente com CD_FCU preenchido
# (372 setores no Piauí, dos quais 369 em Teresina) — o que casa com o
# crosswalk da PNADC, onde o único estrato com S = 3 no estado é o 2210030,
# de Teresina. É a confirmação empírica de que S = 3 é FCU.

setores <- setores %>%
  mutate(S = case_when(
    CD_TIPO == 1            ~ "3",   # FCU tem precedência: é urbano, mas urbano de outro tipo
    CD_SIT %in% c(1, 2, 3)  ~ "1",   # urbano tradicional
    CD_SIT %in% c(5, 6, 7, 8) ~ "2", # rural
    TRUE                    ~ NA_character_
  ))

message("Distribuição de S (1 urbano tradicional / 2 rural / 3 FCU):")
print(table(setores$S, useNA = "ifany"))

# ---- 3. Domicílios e renda do responsável, por setor --------------------------
# A planilha oficial é do Brasil inteiro (~459 mil linhas). Filtro o Piauí uma
# vez e guardo em cache — reler o xlsx a cada rodada é desperdício.

cache_renda <- "data/raw/renda/renda_responsavel_PI.csv"
xlsx_renda  <- "data/raw/renda/Agregados_por_setores_renda_responsavel_BR.xlsx"

if (!file.exists(cache_renda)) {
  if (!file.exists(xlsx_renda)) {
    stop("Preciso de ", xlsx_renda, " (Agregados por Setores — renda do responsável, ",
         "Censo 2022) ou do cache ", cache_renda, ".")
  }
  message("Lendo a planilha de renda do Brasil inteiro e filtrando o Piauí (demora ~1 min)...")
  renda_br <- readxl::read_excel(xlsx_renda, col_types = "text")
  renda_br %>%
    filter(str_starts(CD_SETOR, "22"), nchar(CD_SETOR) == 15) %>%
    write_csv(cache_renda)
  rm(renda_br); gc()
}

# As variáveis vêm como texto porque o IBGE suprime células com "X"
# (desidentificação de setores muito pequenos). as.numeric() transforma
# esses "X" em NA, que é exatamente o tratamento que eu quero.
renda <- read_csv(cache_renda, col_types = cols(.default = col_character())) %>%
  mutate(across(starts_with("V06"), ~ suppressWarnings(as.numeric(.x))))

n_suprimido <- sum(is.na(renda$V06001))
message(sprintf("Renda por setor: %d linhas, %d com supressão 'X' (%.2f%%).",
                nrow(renda), n_suprimido, 100 * n_suprimido / nrow(renda)))

setores <- setores %>%
  left_join(
    renda %>% select(CD_SETOR, V06001, V06004, V06005, V06006),
    by = "CD_SETOR"
  ) %>%
  mutate(
    DPPO          = coalesce(V06001, 0),          # capacidade: sem dado = 0 domicílio
    renda_media   = V06004,                        # rendimento nominal médio do responsável
    renda_mediana = V06006
  )

message(sprintf("Setores sem DPPO utilizável: %d (%.2f%%) — entram na agregação com peso 0.",
                sum(setores$DPPO == 0), 100 * mean(setores$DPPO == 0)))

# ---- 4. AAA (1-3) e GG (4-5): o estrato geográfico ---------------------------
# AAA vem do município: capital, resto da RIDE, resto da UF.
# GG vem do polígono oficial da PNADC (camada do GeoServer, já baixada e
# classificada pelo 04_mapas_estratos_piaui.R) — é a única fonte pública da
# fronteira dos estratos geográficos da pesquisa.

if (!file.exists("output/estratos_piaui.gpkg")) {
  stop("output/estratos_piaui.gpkg não existe — roda o 04_mapas_estratos_piaui.R primeiro.")
}

poligonos <- st_read("output/estratos_piaui.gpkg", quiet = TRUE) %>%
  st_make_valid() %>%
  mutate(cd_est4 = as.character(as.integer(cd_est))) %>%
  select(cd_est4)

setores <- st_make_valid(setores)
if (st_crs(setores) != st_crs(poligonos)) setores <- st_transform(setores, st_crs(poligonos))

# Junção por ponto representativo (garantidamente dentro do polígono, ao
# contrário do centroide, que pode cair fora em setor côncavo).
pontos  <- st_point_on_surface(setores)
atrib   <- st_join(pontos, poligonos, join = st_within)
setores$cd_est4 <- atrib$cd_est4

# Setores que caem fora de todos os polígonos (borda da malha, ilhas
# fluviais): resolvo pelo polígono mais próximo em vez de descartar.
sem_est <- is.na(setores$cd_est4)
if (any(sem_est)) {
  idx <- st_nearest_feature(pontos[sem_est, ], poligonos)
  setores$cd_est4[sem_est] <- poligonos$cd_est4[idx]
  message(sum(sem_est), " setor(es) fora de qualquer polígono — atribuídos ao mais próximo.")
}

# O estrato geográfico da PNADC é definido sobre MUNICÍPIOS inteiros — a
# estratificação administrativa (capital / RIDE / resto da UF) é, por
# definição, municipal, e o agrupamento geográfico junta municípios inteiros.
# A junção espacial acima é feita setor a setor, então setores de um mesmo
# município podem cair em polígonos diferentes por imprecisão de fronteira
# (acontece em 4 municípios do Piauí, entre eles Beneditinos, que é da RIDE).
# Isso quebraria a UPA em duas células distintas. Resolvo o município inteiro
# pelo polígono onde está a maior parte dos seus domicílios.
resolucao_municipal <- setores %>%
  st_drop_geometry() %>%
  count(CD_MUN, cd_est4, wt = DPPO + 1, name = "peso") %>%   # +1: município sem DPPO ainda vota
  group_by(CD_MUN) %>%
  slice_max(peso, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(CD_MUN, cd_est4_mun = cd_est4)

n_divergentes <- setores %>%
  st_drop_geometry() %>%
  left_join(resolucao_municipal, by = "CD_MUN") %>%
  summarise(n = sum(cd_est4 != cd_est4_mun)) %>%
  pull(n)

setores <- setores %>%
  left_join(resolucao_municipal, by = "CD_MUN") %>%
  mutate(
    cd_est4 = cd_est4_mun,
    AAA = substr(cd_est4, 1, 3),
    GG  = paste0(substr(cd_est4, 4, 4), "0")
  ) %>%
  select(-cd_est4_mun)

message(sprintf("%d setor(es) reatribuídos para o estrato geográfico da maioria do seu município.",
                n_divergentes))

# ---- 5. Construção das UPAs ---------------------------------------------------
# Agregação com restrição de contiguidade dentro de cada célula
# (município x S). O município entra como barreira porque UPA é unidade
# operacional de campo — um entrevistador não cobre duas prefeituras.
#
# Heurística (region growing por menor carga):
#   enquanto existir unidade abaixo do mínimo e com vizinho disponível:
#     pega a unidade MENOR (a mais deficitária)
#     funde ela com o vizinho de menor DPPO
# Fundir sempre com o vizinho menor evita criar UPAs gigantes por acidente:
# a massa se espalha em vez de grudar toda num setor grande.

construir_upas_no_grupo <- function(idx_grupo, geom_grupo, dppo_grupo, minimo) {

  n <- length(idx_grupo)
  if (n == 1) return(rep(1L, 1))

  # Grafo de contiguidade. st_touches pega vizinhos que compartilham
  # fronteira ou ao menos um ponto.
  # suppressWarnings: com s2 desligado e coordenadas em lat/long o sf avisa
  # "assumes planar" a cada chamada. É esperado e inofensivo aqui — só quero
  # saber QUEM encosta em quem, não a distância exata.
  viz <- suppressWarnings(st_touches(geom_grupo, sparse = TRUE))

  membro    <- seq_len(n)                       # setor -> unidade
  carga     <- dppo_grupo                       # DPPO por unidade
  vizinhos  <- lapply(seq_len(n), function(i) unique(viz[[i]]))
  viva      <- rep(TRUE, n)

  repeat {
    # candidatas: unidades vivas, abaixo do mínimo, com pelo menos um vizinho vivo
    cand <- which(viva & carga < minimo)
    cand <- cand[vapply(cand, function(u) length(vizinhos[[u]]) > 0, logical(1))]
    if (length(cand) == 0) break

    u <- cand[which.min(carga[cand])]           # a mais deficitária
    vz <- vizinhos[[u]]
    v  <- vz[which.min(carga[vz])]              # o vizinho de menor carga

    # funde u dentro de v
    membro[membro == u] <- v
    carga[v] <- carga[v] + carga[u]
    carga[u] <- NA_real_
    viva[u]  <- FALSE

    novos <- setdiff(union(vizinhos[[v]], vizinhos[[u]]), c(u, v))
    vizinhos[[v]] <- novos
    for (w in novos) vizinhos[[w]] <- unique(c(setdiff(vizinhos[[w]], c(u, v)), v))
    vizinhos[[u]] <- integer(0)
  }

  # Sobrou unidade abaixo do mínimo sem vizinho contíguo (setor isolado, ilha,
  # enclave). Funde com a unidade mais próxima do MESMO grupo — deixa de ser
  # contígua, mas continua respeitando município e situação, que é a restrição
  # que o IBGE enuncia explicitamente. Fica registrado no diagnóstico.
  # Centroide de cada setor, calculado uma vez só: a distância entre unidades
  # é aproximada pela distância entre os centroides dos setores que as compõem.
  cent <- suppressWarnings(st_coordinates(st_point_on_surface(geom_grupo)))

  repeat {
    orfas <- which(viva & carga < minimo)
    if (length(orfas) == 0 || sum(viva) <= 1) break
    u <- orfas[which.min(carga[orfas])]
    outras <- setdiff(which(viva), u)

    cu <- colMeans(cent[membro == u, , drop = FALSE])
    co <- t(vapply(outras, function(o) colMeans(cent[membro == o, , drop = FALSE]),
                   numeric(2)))
    v <- outras[which.min((co[, 1] - cu[1])^2 + (co[, 2] - cu[2])^2)]

    membro[membro == u] <- v
    carga[v] <- carga[v] + carga[u]
    carga[u] <- NA_real_
    viva[u]  <- FALSE
  }

  as.integer(factor(membro))
}

message("Construindo UPAs por célula (município x situação)...")

setores$grupo_upa <- paste(setores$CD_MUN, setores$S, sep = "_")
grupos <- unique(setores$grupo_upa[!is.na(setores$S)])

setores$upa_local <- NA_integer_
geom_all <- st_geometry(setores)

for (g in grupos) {
  idx <- which(setores$grupo_upa == g)
  s   <- setores$S[idx[1]]
  setores$upa_local[idx] <- construir_upas_no_grupo(
    idx, geom_all[idx], setores$DPPO[idx], MIN_DPPO[[s]]
  )
}

setores <- setores %>%
  mutate(UPA = ifelse(is.na(upa_local), NA_character_,
                      sprintf("%s_%03d", grupo_upa, upa_local)))

# ---- 6. Tabela de UPAs --------------------------------------------------------
# Renda da UPA = média das rendas médias dos setores, ponderada pelo número de
# domicílios. Ressalva honesta: V06004 é o rendimento médio dos responsáveis
# COM rendimento, enquanto V06001 conta TODOS os responsáveis. O peso certo
# seria o número de responsáveis com rendimento, que a tabela não publica.
# Uso V06001 como peso — é a melhor aproximação disponível, e o viés é o mesmo
# em todos os setores da mesma UPA.

upas <- setores %>%
  st_drop_geometry() %>%
  filter(!is.na(UPA)) %>%
  # Pesos calculados ANTES do summarise. Dentro do summarise o nome `DPPO`
  # já passaria a valer o agregado `sum(DPPO)` (o dplyr avalia os argumentos
  # em sequência), e a ponderação sairia errada.
  mutate(
    peso_media   = ifelse(is.na(renda_media),   0, DPPO),
    peso_mediana = ifelse(is.na(renda_mediana), 0, DPPO)
  ) %>%
  group_by(UPA, CD_MUN, AAA, GG, S) %>%
  summarise(
    n_setores     = n(),
    DPPO          = sum(DPPO),
    renda_media   = if (sum(peso_media) > 0)
                      sum(renda_media * peso_media, na.rm = TRUE) / sum(peso_media) else NA_real_,
    renda_mediana = if (sum(peso_mediana) > 0)
                      sum(renda_mediana * peso_mediana, na.rm = TRUE) / sum(peso_mediana) else NA_real_,
    .groups = "drop"
  ) %>%
  mutate(
    estrato_geografico = paste0(AAA, GG, S),
    atinge_minimo      = DPPO >= MIN_DPPO[S]
  )

# UPA sem nenhuma renda observada (todos os setores suprimidos): imputo pela
# mediana do próprio estrato geográfico, pra não perder a UPA na hora de
# estratificar. Marco quais foram.
upas <- upas %>%
  group_by(estrato_geografico) %>%
  mutate(
    renda_imputada = is.na(renda_media),
    renda_media    = ifelse(is.na(renda_media), median(renda_media, na.rm = TRUE), renda_media)
  ) %>%
  ungroup()

# ---- 7. Diagnóstico -----------------------------------------------------------

diagnostico <- upas %>%
  group_by(estrato_geografico, AAA, GG, S) %>%
  summarise(
    n_UPAs            = n(),
    n_setores         = sum(n_setores),
    DPPO_total        = sum(DPPO),
    DPPO_mediano_UPA  = median(DPPO),
    UPAs_abaixo_min   = sum(!atinge_minimo),
    UPAs_1_setor      = sum(n_setores == 1),
    renda_imputada    = sum(renda_imputada),
    # a restrição operacional que decide se dá pra ter estrato estatístico:
    max_estratos_150  = pmin(5L, as.integer(floor(n() / 150))),
    .groups = "drop"
  ) %>%
  arrange(estrato_geografico)

message("\n--- UPAs construídas por estrato geográfico (AAAGGS) ---")
print(as.data.frame(diagnostico), row.names = FALSE)

message(sprintf("\nTOTAL: %d UPAs a partir de %d setores (%d DPPO).",
                nrow(upas), sum(upas$n_setores), sum(upas$DPPO)))
message(sprintf("UPAs abaixo do mínimo: %d (%.2f%%) — são células cujo grupo inteiro ",
                sum(!upas$atinge_minimo), 100 * mean(!upas$atinge_minimo)),
        "(município x situação) já não alcançava o mínimo sozinho.")

write_csv(diagnostico, "output/tabelas/diagnostico_upas.csv")
write_csv(upas, "output/upas_piaui.csv")

st_write(setores %>% select(CD_SETOR, CD_MUN, NM_MUN, CD_SIT, CD_TIPO, S, AAA, GG,
                            cd_est4, DPPO, renda_media, renda_mediana, UPA),
         "output/setores_com_upa_piaui.gpkg", delete_dsn = TRUE, quiet = TRUE)

message("\nSaídas: output/upas_piaui.csv, output/setores_com_upa_piaui.gpkg, ",
        "output/tabelas/diagnostico_upas.csv")
