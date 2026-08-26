# ==============================================================================
# 04_mapa_estratos_piaui.R — mapa dos subestratos do Piauí, lado a lado:
# zona, estrato administrativo, estrato agregado e estratos "puros" (o
# código bruto do estrato).
#
# Usa o polígono oficial do IBGE (v_ibge_estpnadc_trimestral_poligono, via
# WFS) e um crosswalk Estrato -> Zona/Estrato_Admin/Estrato_agregado
# exportado pelo pipeline_trimestre.R. Uso o crosswalk em vez de tentar
# redescobrir essas classificações só a partir do código do polígono —
# assim não corro o risco de duplicar/discordar da classificação que você
# já validou nos indicadores.
#
# PRÉ-REQUISITO: já ter rodado o pipeline_trimestre.R pelo menos uma vez
# (ele agora grava output/crosswalk_estratos.csv automaticamente). Se você
# rodou uma versão mais antiga do script que ainda não tinha essa linha,
# roda de novo, ou executa isso à mão logo depois de criar o design_pi:
#
#   readr::write_csv(
#     dplyr::distinct(design_pi$variables, Estrato, Zona, Estrato_Admin, Estrato_agregado),
#     "output/crosswalk_estratos.csv"
#   )
# ==============================================================================

library(sf)
library(dplyr)
library(readr)
library(ggplot2)
library(patchwork)  # install.packages("patchwork") se não tiver

# ---- 1. Polígonos do IBGE + crosswalk ---------------------------------------

poligonos_estratos <- st_read(
  "https://geoservicos.ibge.gov.br/geoserver/PNADC/wfs?service=WFS&version=2.0.0&request=GetFeature&typeName=PNADC:v_ibge_estpnadc_trimestral_poligono&outputFormat=application/json"
)
sf_use_s2(FALSE)

message("Colunas do polígono do IBGE (conferindo onde está o código do estrato):")
print(names(poligonos_estratos))

# Colunas candidatas pro código do estrato — NÃO uso mais grepl("estrato")
# sozinho porque ele pegava "Nom_Estrato" (nome, não código) antes de
# chegar num campo numérico de verdade.
candidatos_col <- c("cd_est", "cd_estpnadc_num")
col_estrato <- candidatos_col[candidatos_col %in% names(poligonos_estratos)][1]
if (is.na(col_estrato)) {
  stop("Não achei a coluna do código do estrato entre os candidatos esperados (",
       paste(candidatos_col, collapse = ", "), "). Olha o print(names(poligonos_estratos)) ",
       "acima e define à mão:\n  col_estrato <- \"NOME_REAL_AQUI\"")
}
message("Usando '", col_estrato, "' como coluna do código do estrato no polígono.")
message("Quantidade de dígitos encontrada nesse código:")
print(table(nchar(as.character(poligonos_estratos[[col_estrato]]))))

crosswalk <- read_csv("output/crosswalk_estratos.csv", show_col_types = FALSE) %>%
  mutate(Estrato = as.character(Estrato))

poligonos_estratos <- poligonos_estratos %>% mutate(.estrato_chr = as.character(.data[[col_estrato]]))

# IMPORTANTE: o polígono do GeoServer vem só nos 4 primeiros dígitos do
# código de 7 dígitos que aparece nos microdados (ex.: polígono "2251"
# cobre TODOS os estratos 2251011, 2251012, 2251013, 2251020, 2251021,
# 2251022 juntos) — não dá pra casar pelo código completo. Faço o join
# pelos 4 primeiros dígitos.
#
# Isso funciona bem pro Estrato_agregado (que já É definido nessa mesma
# granularidade de 4 dígitos). Mas Zona e Estrato_Admin podem MISTURAR
# categorias diferentes dentro do mesmo grupo de 4 dígitos (ex.: um grupo
# pode ter estratos urbanos e rurais junto) — o código abaixo confere isso
# e avisa, em vez de simplesmente assumir que dá certo.
crosswalk_4d <- crosswalk %>%
  mutate(Estrato4 = substr(Estrato, 1, 4)) %>%
  group_by(Estrato4) %>%
  summarise(
    Estrato_agregado = dplyr::first(Estrato_agregado),
    Zona          = if (n_distinct(Zona) == 1) dplyr::first(Zona) else NA_character_,
    Estrato_Admin = if (n_distinct(Estrato_Admin) == 1) dplyr::first(Estrato_Admin) else NA_character_,
    Zona_misturada          = n_distinct(Zona) > 1,
    Estrato_Admin_misturado = n_distinct(Estrato_Admin) > 1,
    .groups = "drop"
  )

if (any(crosswalk_4d$Zona_misturada) || any(crosswalk_4d$Estrato_Admin_misturado)) {
  message("AVISO: nessa resolução de 4 dígitos, Zona e/ou Estrato_Admin misturam ",
          "mais de uma categoria dentro do mesmo polígono em pelo menos um grupo — ",
          "os mapas de Zona/Estrato Administrativo abaixo vão sair incompletos (NA) ",
          "exatamente nesses grupos. Só o mapa de Estrato Agregado é confiável nessa ",
          "camada; pro resto, veja o 05_setores_censitarios_piaui.R.")
  print(crosswalk_4d %>% filter(Zona_misturada | Estrato_Admin_misturado) %>% select(Estrato4, Zona_misturada, Estrato_Admin_misturado))
}

# O join pelos 4 dígitos já restringe ao Piauí sozinho — o crosswalk só tem
# os grupos que existem em design_pi (que já é UF == "Piauí").
mapa_pi <- poligonos_estratos %>% inner_join(crosswalk_4d, by = c(".estrato_chr" = "Estrato4"))

if (nrow(mapa_pi) == 0) {
  stop("O join não bateu nenhuma linha mesmo pelos 4 dígitos. Compara alguns valores de ",
       "poligonos_estratos$", col_estrato, " com substr(crosswalk$Estrato, 1, 4) antes de seguir ",
       "— pode ter zero à esquerda faltando, ou o campo não ser o que eu imaginei.")
}

# A camada do GeoServer parece ter uma linha por PERÍODO histórico pra cada
# estrato (é "trimestral" — tem colunas de taxa por trimestre), não uma
# linha só por área. Isso faz o mesmo polígono aparecer repetido várias
# vezes com o mesmo Estrato_agregado. Fico só com uma cópia por grupo — a
# fronteira geográfica deve ser a mesma em todas (só as estatísticas
# associadas mudam por período, e essas eu não uso).
n_antes <- nrow(mapa_pi)
mapa_pi <- mapa_pi %>% distinct(Estrato_agregado, .keep_all = TRUE)
if (n_antes != nrow(mapa_pi)) {
  message("Aviso: o polígono do GeoServer tinha ", n_antes, " linha(s) pra só ",
          nrow(mapa_pi), " estrato(s) agregado(s) distinto(s) — fiquei com 1 por grupo ",
          "(provavelmente uma linha por trimestre histórico repetindo a mesma área).")
}
message(nrow(mapa_pi), " polígono(s) de estrato casados com o Piauí (de ",
        nrow(poligonos_estratos), " no Brasil todo).")

# Salva o resultado classificado — o script de setores censitários
# (05_setores_censitarios_piaui.R) usa esse arquivo em vez de refazer o
# WFS/join do zero.
dir.create("output", recursive = TRUE, showWarnings = FALSE)
st_write(mapa_pi, "output/estratos_piaui.gpkg", delete_dsn = TRUE, quiet = TRUE)

# ---- 2. Paleta fria/neutra (mesma família de cor do resto do relatório) ----

paleta <- function(categorias) {
  categorias <- sort(unique(na.omit(categorias)))
  setNames(
    colorRampPalette(c("#08306B", "#2171B5", "#6BAED6", "#969696", "#252525"))(length(categorias)),
    categorias
  )
}

tema_mapa <- theme_minimal(base_size = 9) +
  theme(axis.text = element_blank(), axis.ticks = element_blank(),
        panel.grid = element_blank(), legend.position = "bottom",
        legend.title = element_blank())

# ---- 3. Os 4 mapas -----------------------------------------------------------

p_zona <- ggplot(mapa_pi) +
  geom_sf(aes(fill = Zona), color = "white", linewidth = 0.1) +
  scale_fill_manual(values = paleta(mapa_pi$Zona), na.value = "grey85",
                    na.translate = TRUE, name = NULL) +
  labs(title = "Zona", subtitle = if (any(mapa_pi$Zona_misturada)) "cinza = grupo com zona mista nessa resolução" else NULL) +
  tema_mapa

p_admin <- ggplot(mapa_pi) +
  geom_sf(aes(fill = Estrato_Admin), color = "white", linewidth = 0.1) +
  scale_fill_manual(values = paleta(mapa_pi$Estrato_Admin), na.value = "grey85",
                    na.translate = TRUE, name = NULL) +
  labs(title = "Estrato Administrativo", subtitle = if (any(mapa_pi$Estrato_Admin_misturado)) "cinza = grupo misto nessa resolução" else NULL) +
  tema_mapa

p_agreg <- ggplot(mapa_pi) +
  geom_sf(aes(fill = Estrato_agregado), color = "white", linewidth = 0.1) +
  scale_fill_manual(values = paleta(mapa_pi$Estrato_agregado), name = NULL) +
  labs(title = "Estrato Agregado — única categoria confiável nessa resolução") + tema_mapa

# "Estratos puros" NÃO entra aqui: nessa camada do GeoServer, o código já
# vem agregado nos 4 primeiros dígitos (o mesmo nível do Estrato Agregado)
# — um painel "puro" com esse polígono ficaria idêntico ao de cima, sem
# acrescentar nada. A versão de verdade, na resolução do setor censitário,
# está no 05_setores_censitarios_piaui.R.

# ---- 4. Lado a lado -----------------------------------------------------------
# Só 3 painéis aqui (Zona, Estrato Administrativo, Estrato Agregado) — o
# quarto ("estratos puros") sai do 05_setores_censitarios_piaui.R.

mapa_final <- (p_zona | p_admin | p_agreg) +
  plot_annotation(title = "Subestratos do Piauí — PNADC (resolução: polígono agregado de 4 dígitos)")

dir.create("output/figuras", recursive = TRUE, showWarnings = FALSE)
ggsave("output/figuras/mapa_estratos_piaui.png", mapa_final, width = 15, height = 6, dpi = 150)

message("Mapa salvo em output/figuras/mapa_estratos_piaui.png (3 painéis — Zona/Admin podem sair com áreas cinzas, veja os avisos acima)")