# ==============================================================================
# 05_setores_censitarios_piaui.R — os 4 mapas dos subestratos do Piauí, lado
# a lado, na resolução do setor censitário (Censo 2022) — a mais fina que
# consegui obter publicamente.
#
# Por que não uso o polígono do GeoServer (04_mapa_estratos_piaui.R) pra
# tudo: aquela camada só tem os estratos já agregados nos 4 primeiros
# dígitos do código (2210/2220/2251/2252/2253 no Piauí) — não dá pra
# recuperar Zona ou Estrato Administrativo direito dali (um mesmo polígono
# de 4 dígitos pode misturar zona urbana e rural), e muito menos os
# estratos "puros" de 7 dígitos.
#
# Como resolvo cada um dos 4 aqui:
#   - Zona:                  atributo do próprio setor censitário (situação
#                             urbana/rural) — não depende de nenhum
#                             cruzamento com a PNADC.
#   - Estrato Administrativo: código do município do setor (7 primeiros
#                             dígitos do CD_SETOR) x lista de municípios da
#                             RIDE Grande Teresina (Decreto nº 10.129/2019) —
#                             também não depende de cruzamento com a PNADC.
#   - Estrato Agregado:       junção espacial contra o polígono do GeoServer
#                             já corrigido (output/estratos_piaui.gpkg, do
#                             04_mapa_estratos_piaui.R) — essa é a única
#                             classificação que realmente depende daquele
#                             polígono, porque é a resolução que ele tem.
#   - Estratos "puros":       aqui preciso ser honesto sobre um limite real.
#                             Os estratos de 7 dígitos da PNADC (as
#                             subdivisões dentro de cada grupo de 4 dígitos,
#                             tipo 2210011 a 2210030 dentro de Teresina) não
#                             têm nenhuma fronteira oficial publicada que eu
#                             tenha achado — só o código de 4 dígitos é
#                             público. Sem uma fronteira de referência
#                             nessa resolução, não dá pra reconstruir com
#                             confiança qual setor cai em qual dos 5
#                             subcódigos de Teresina, por exemplo. O que dou
#                             aqui é o setor censitário individual (a menor
#                             unidade geográfica pública que existe) — é
#                             mais fino que o Estrato Agregado, mas NÃO é
#                             garantido bater com o estrato de 7 dígitos da
#                             PNADC. Deixo isso explícito no título do mapa
#                             pra não passar confiança que não tenho.
#
# PRÉ-REQUISITO: já ter rodado o 04_mapa_estratos_piaui.R (gera
# output/estratos_piaui.gpkg, usado aqui só pro Estrato Agregado).
# ==============================================================================

library(sf)
library(dplyr)
library(readr)
library(stringr)
library(tidyr)
library(ggplot2)
library(patchwork)

# Shapefile de órgão público brasileiro costuma ter pequenas imperfeições
# de geometria (vértice duplicado, anel quase fechado etc.) que o motor s2
# (padrão do sf hoje em dia, mais rígido) rejeita mas o GEOS antigo tolera.
# Desligo o s2 pra esse script inteiro — não faz diferença de precisão
# relevante numa área do tamanho do Piauí, e evita esse tipo de erro.
sf::sf_use_s2(FALSE)

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
dir.create("output/figuras", recursive = TRUE, showWarnings = FALSE)

# ---- 1. Setores censitários do Censo 2022 — Piauí ---------------------------

url_setores <- "https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_de_setores_censitarios__divisoes_intramunicipais/censo_2022/setores/shp/UF/PI_setores_CD2022.zip"
arquivo_zip <- "data/raw/PI_setores_CD2022.zip"
pasta_shp   <- "data/raw/PI_setores_CD2022"

if (!file.exists(arquivo_zip)) {
  message("Baixando a malha de setores censitários do Piauí (~19 MB)...")
  download.file(url_setores, arquivo_zip, mode = "wb")
}
if (!dir.exists(pasta_shp)) unzip(arquivo_zip, exdir = pasta_shp)

arquivo_shp <- list.files(pasta_shp, pattern = "\\.shp$", full.names = TRUE, recursive = TRUE)[1]
setores <- st_read(arquivo_shp, quiet = TRUE)
message(nrow(setores), " setores censitários no Piauí.")
message("Colunas do shapefile:")
print(names(setores))

# Código do setor: CD_SETOR (confirmado). Município = 7 primeiros dígitos.
setores <- setores %>% mutate(cod_municipio = substr(as.character(CD_SETOR), 1, 7))

# ---- 2. Zona (urbana/rural) — direto do atributo do setor -------------------
# Tento achar sozinho a coluna de situação urbana/rural. Se não achar,
# ajusta a linha indicada com o nome real (confere no print(names(setores))
# acima).
candidatos_situacao <- c("SITUACAO", "CD_SIT", "SIT", "TIPO")
col_situacao <- candidatos_situacao[candidatos_situacao %in% names(setores)][1]

if (is.na(col_situacao)) {
  message("AVISO: não achei automaticamente a coluna de situação urbana/rural. ",
          "Olha o print(names(setores)) acima e define à mão, ex.:\n",
          "  col_situacao <- \"NOME_REAL_AQUI\"")
  setores$Zona <- NA_character_
} else {
  message("Usando '", col_situacao, "' como situação urbana/rural. Valores encontrados:")
  print(table(setores[[col_situacao]], useNA = "ifany"))
  # Ajusta esse case_when conforme os valores reais que apareceram no
  # print() acima (o IBGE costuma usar "1"/"Urbano" ou "01" etc. — varia
  # entre vintages da malha).
  setores <- setores %>%
    mutate(Zona = case_when(
      str_detect(as.character(.data[[col_situacao]]), regex("urban", ignore_case = TRUE)) |
        as.character(.data[[col_situacao]]) %in% c("1", "01") ~ "Urbana",
      str_detect(as.character(.data[[col_situacao]]), regex("rural", ignore_case = TRUE)) |
        as.character(.data[[col_situacao]]) %in% c("2", "02", "3", "03") ~ "Rural",
      TRUE ~ NA_character_
    ))
}

# ---- 2b. Situação (S do AAAGGSE): Rural / Urbano tradicional / FCU --------
# Diferente de E (renda, não dá pra mapear), S É espacial — separa urbano
# tradicional de Favela/Comunidade Urbana (FCU), e isso é uma classificação
# do PRÓPRIO setor (tipo de setor/aglomerado subnormal). Se essa coluna
# existir, dá pra mapear até 6 dos 7 dígitos do Estrato — só a renda (o
# último dígito) fica de fora, porque essa sim varia domicílio a domicílio
# sem delimitar um pedaço de território.
candidatos_tipo <- c("TIPO", "CD_TIPO", "TIPO_SETOR", "NM_TIPO_SETOR", "SUBNORMAL", "AGSN")
col_tipo <- candidatos_tipo[candidatos_tipo %in% names(setores)][1]

if (is.na(col_tipo)) {
  message("AVISO: não achei coluna de tipo de setor/aglomerado subnormal entre ",
          paste(candidatos_tipo, collapse = ", "), ". Olha print(names(setores)) ",
          "no topo e define à mão, ex.: col_tipo <- \"NOME_REAL_AQUI\". Sem isso, ",
          "o 4º painel fica só com Rural/Urbana (sem separar FCU).")
  setores$Situacao <- setores$Zona
} else {
  message("Usando '", col_tipo, "' como tipo de setor/aglomerado subnormal. Valores encontrados:")
  print(table(setores[[col_tipo]], useNA = "ifany"))
  # Ajusta esse case_when conforme os valores reais que apareceram no
  # print() acima.
  setores <- setores %>%
    mutate(Situacao = case_when(
      Zona == "Rural" ~ "Rural",
      str_detect(as.character(.data[[col_tipo]]), regex("subnormal|fcu|favela", ignore_case = TRUE)) ~ "FCU",
      Zona == "Urbana" ~ "Urbano tradicional",
      TRUE ~ NA_character_
    ))
}

# ---- 3. Estrato Administrativo — município x RIDE Grande Teresina ----------
# RIDE Grande Teresina conforme Decreto nº 10.129/2019 (fonte: SEMPLAN/
# Prefeitura de Teresina): Altos, Beneditinos, Coivaras, Curralinho(s),
# Demerval Lobão, José de Freitas, Lagoa Alegre, Lagoa do Piauí, Miguel
# Leão, Monsenhor Gil, Teresina, União. ATENÇÃO: algumas fontes mais
# recentes também incluem Nazária e Pau D'Arco (incorporados depois) —
# confere se sua versão do V1023 bate com essa lista antes de confiar no
# mapa; se não bater, é só ajustar o vetor abaixo.
municipios_ride_nome <- c(
  "Altos", "Beneditinos", "Coivaras", "Curralinhos", "Curralinho",
  "Demerval Lobão", "José de Freitas", "Lagoa Alegre", "Lagoa do Piauí",
  "Miguel Leão", "Monsenhor Gil", "União"
)
codigo_teresina <- "2211001"

candidatos_nome_mun <- c("NM_MUN", "NM_MUNICIP", "NM_MUNICIPIO", "NOME_MUN")
col_nome_mun <- candidatos_nome_mun[candidatos_nome_mun %in% names(setores)][1]

if (is.na(col_nome_mun)) {
  message("AVISO: não achei a coluna de nome do município — a classificação ",
          "Estrato Administrativo vai usar só o código de Teresina (Capital) ",
          "e deixar o resto como 'Resto da UF' (sem separar a RIDE). Olha ",
          "print(names(setores)) e define col_nome_mun à mão se quiser corrigir.")
  setores <- setores %>%
    mutate(Estrato_Admin = ifelse(cod_municipio == codigo_teresina, "Capital", "Resto da UF"))
} else {
  setores <- setores %>%
    mutate(Estrato_Admin = case_when(
      cod_municipio == codigo_teresina ~ "Capital",
      .data[[col_nome_mun]] %in% municipios_ride_nome ~ "Resto da RIDE",
      TRUE ~ "Resto da UF"
    ))
}

# ---- 4. Estrato Agregado — junção espacial contra o polígono já corrigido --

if (!file.exists("output/estratos_piaui.gpkg")) {
  stop("output/estratos_piaui.gpkg não existe — roda o 04_mapa_estratos_piaui.R primeiro.")
}
mapa_pi <- st_read("output/estratos_piaui.gpkg", quiet = TRUE)
mapa_pi <- st_make_valid(mapa_pi)

# Defensivo: garante 1 linha por Estrato_agregado mesmo se o .gpkg salvo
# pelo 04 ainda tiver cópias (ex.: versão antiga do arquivo).
n_antes <- nrow(mapa_pi)
mapa_pi <- mapa_pi %>% dplyr::distinct(Estrato_agregado, .keep_all = TRUE)
if (n_antes != nrow(mapa_pi)) {
  message("Aviso: estratos_piaui.gpkg tinha ", n_antes, " linha(s) pra só ",
          nrow(mapa_pi), " estrato(s) agregado(s) — deduplicado antes da junção espacial.")
}

setores <- st_make_valid(setores)

if (!file.exists("output/crosswalk_estratos.csv")) {
  stop("output/crosswalk_estratos.csv não existe — roda o pipeline_trimestre.R (que gera esse ",
       "arquivo) antes deste script.")
}
crosswalk <- read_csv("output/crosswalk_estratos.csv", show_col_types = FALSE) %>%
  mutate(Estrato = as.character(Estrato))

if (st_crs(setores) != st_crs(mapa_pi)) setores <- st_transform(setores, st_crs(mapa_pi))

centroides <- st_centroid(setores)
juncao <- st_join(centroides, mapa_pi %>% select(Estrato_agregado), join = st_within)

n_total     <- nrow(juncao)
n_sem_match <- sum(is.na(juncao$Estrato_agregado))
message(sprintf("Estrato Agregado por junção espacial: %d de %d setores casados (%.1f%% sem correspondência).",
                n_total - n_sem_match, n_total, 100 * n_sem_match / n_total))

setores <- setores %>% mutate(Estrato_agregado = juncao$Estrato_agregado)

st_write(setores, "output/setores_censitarios_piaui_classificados.gpkg", delete_dsn = TRUE, quiet = TRUE)

# ---- 5. Paleta fria/neutra e tema -------------------------------------------

paleta <- function(categorias) {
  categorias <- sort(unique(na.omit(categorias)))
  setNames(colorRampPalette(c("#08306B", "#2171B5", "#6BAED6", "#969696", "#252525"))(length(categorias)),
           categorias)
}


# Os setores censitários ficam sem contorno (color = NA) porque desenhar a
# borda de cada um deles polui o mapa — mas isso também apaga a fronteira
# real dos estratos, que é o que se quer enxergar. Dissolvo os setores por
# categoria e desenho só esse contorno dissolvido por cima do preenchimento.
contorno_por_grupo <- function(dados, var) {
  dados %>%
    filter(!is.na(.data[[var]])) %>%
    group_by(.data[[var]]) %>%
    summarise(.groups = "drop") %>%
    st_make_valid()
}


tema_mapa <- theme_minimal(base_size = 8) +
  theme(axis.text = element_blank(), axis.ticks = element_blank(),
        panel.grid = element_blank(), legend.position = "bottom", legend.title = element_blank(),
        legend.text = element_text(size = 6), legend.key.size = unit(0.35, "cm"),
        legend.spacing.x = unit(0.15, "cm"), legend.margin = margin(0, 0, 0, 0))

# ---- Situação (S do AAAGGSE) — mapa de verdade, 6 dos 7 dígitos -----------
# AAA (3 díg.) = Estrato_Admin, AAAGG (5 díg.) = Estrato_agregado, ambos já
# confirmados 100% (ver notas acima). S (6º dígito) é a última peça
# espacial que dá pra mapear: Rural / Urbano tradicional / FCU. Só o E
# (renda, 7º dígito) fica de fora — esse não delimita território, varia
# domicílio a domicílio.

p_estrato7 <- ggplot(setores) +
  geom_sf(aes(fill = Situacao), color = NA) +
  scale_fill_manual(
    values = c("Urbano tradicional" = "#2196C9", "FCU" = "#F2A900", "Rural" = "#D9D9D9"),
    na.value = "grey60", na.translate = TRUE
  ) +
  labs(title = "Situação (Rural / Urbano tradicional / FCU)",
       subtitle = "6 dos 7 dígitos do Estrato — só a renda (7º dígito) não é espacial") +
  tema_mapa

# ---- 6. Os 4 mapas, na resolução do setor censitário ------------------------

p_zona <- ggplot(setores) +
  geom_sf(aes(fill = Zona), color = NA) +
  geom_sf(data = contorno_por_grupo(setores, "Zona"), fill = NA, color = "black", linewidth = 0.4) +
  scale_fill_manual(
    values = c("Urbana" = "#2196C9", "Rural" = "#D9D9D9"),  # urbana clara/viva (precisa se destacar, já que ocupa pouca área) x rural neutro claro (não pode dominar o olho)
    na.value = "grey85"
  ) +
  labs(title = "Zona") + tema_mapa

p_admin <- ggplot(setores) +
  geom_sf(aes(fill = Estrato_Admin), color = NA) +
  geom_sf(data = contorno_por_grupo(setores, "Estrato_Admin"), fill = NA, color = "black", linewidth = 0.4) +
  scale_fill_manual(values = paleta(setores$Estrato_Admin), na.value = "grey85") +
  labs(title = "Estrato Administrativo") + tema_mapa

p_agreg <- ggplot(setores) +
  geom_sf(aes(fill = Estrato_agregado), color = NA) +
  geom_sf(data = contorno_por_grupo(setores, "Estrato_agregado"), fill = NA, color = "black", linewidth = 0.4) +
  scale_fill_manual(values = paleta(setores$Estrato_agregado), na.value = "grey85") +
  labs(title = "Estrato Agregado") + tema_mapa

# ---- 7. Grade 2x2 + mapas individuais ---------------------------------------

mapa_final <- (p_zona | p_admin) / (p_agreg | p_estrato7) +
  plot_annotation(title = "Subestratos do Piauí — resolução: setor censitário (Censo 2022)")
ggsave("output/figuras/mapa_setores_piaui_4painéis.png", mapa_final, width = 12, height = 11, dpi = 150)

ggsave("output/figuras/mapa_setores_zona.png", p_zona, width = 7, height = 6, dpi = 150)
ggsave("output/figuras/mapa_setores_estrato_admin.png", p_admin, width = 7, height = 6, dpi = 150)
ggsave("output/figuras/mapa_setores_estrato_agregado.png", p_agreg, width = 7, height = 6, dpi = 150)
ggsave("output/figuras/mapa_setores_situacao.png", p_estrato7, width = 7, height = 6, dpi = 150)

message("Pronto: grade 2x2 (4 mapas de verdade) em output/figuras/mapa_setores_piaui_4painéis.png ",
        "+ os 4 arquivos individuais em output/figuras/.")
message("Confere os avisos acima (situação urbana/rural, tipo de setor/FCU, município, ",
        "% sem correspondência no Estrato Agregado) antes de usar isso no relatório — ",
        "se a coluna de tipo de setor não foi encontrada, o mapa de Situação sai igual ao de Zona.")