# ==============================================================================
# 08_mapa_aaagsse.R — a figura dos estratos do Piauí, agora com os SETE
# dígitos do código AAAGGSE, na resolução do setor censitário.
#
# O que muda em relação ao 05_setores_censitarios_piaui.R: naquele script o
# 7º dígito (E, o estrato estatístico de renda) ficou de fora, com a ressalva
# de que "esse não delimita território, varia domicílio a domicílio". Essa
# ressalva não vale mais. O E é definido sobre UPAs, e UPA é um conjunto de
# setores censitários contíguos — então o E É espacializável, desde que se
# reconstrua a UPA primeiro. É o que o 06 e o 07 fazem.
#
# PRÉ-REQUISITO: 06_upas_piaui.R e 07_estrato_estatistico.R.
#
# SAÍDAS:
#   output/figuras/mapa_aaagsse_piaui.png     a figura completa, 6 painéis
#   output/figuras/mapa_aaagsse_<painel>.png  cada painel em separado
# ==============================================================================

library(sf)
library(dplyr)
library(readr)
library(stringr)
library(ggplot2)
library(patchwork)

sf::sf_use_s2(FALSE)
dir.create("output/figuras", recursive = TRUE, showWarnings = FALSE)

setores <- st_read("output/setores_com_estrato_completo.gpkg", quiet = TRUE)

# Nomes oficiais dos estratos geográficos, direto da camada do IBGE.
nomes_geo <- st_read("output/estratos_piaui.gpkg", quiet = TRUE) %>%
  st_drop_geometry() %>%
  transmute(cd_est4 = as.character(as.integer(cd_est)), nome_geo = Nom_Estrato)

setores <- setores %>%
  left_join(nomes_geo, by = "cd_est4") %>%
  mutate(
    Administrativo = factor(case_match(AAA,
      "221" ~ "Capital (Teresina)",
      "222" ~ "Resto da RIDE",
      "225" ~ "Resto da UF",
      .default = NA_character_),
      levels = c("Capital (Teresina)", "Resto da RIDE", "Resto da UF")),

    Geografico = factor(nome_geo),

    Situacao = factor(case_match(S,
      "1" ~ "Urbano (exceto FCU)",
      "2" ~ "Rural",
      "3" ~ "FCU",
      .default = NA_character_),
      levels = c("Rural", "Urbano (exceto FCU)", "FCU")),

    Estatistico = factor(case_when(
      is.na(E) ~ NA_character_,
      E == 0   ~ "Estrato único (sem 150 UPAs)",
      TRUE     ~ paste0("Faixa ", E, " de renda")),
      levels = c("Estrato único (sem 150 UPAs)",
                 "Faixa 1 de renda", "Faixa 2 de renda", "Faixa 3 de renda")),

    Estrato7 = factor(Estrato_reconstruido)
  )

message(nrow(setores), " setores. Estratos AAAGGSE reconstruídos: ",
        n_distinct(setores$Estrato7, na.rm = TRUE))

# ---- Paleta e tema -----------------------------------------------------------
# Mesma família fria/neutra do resto do relatório.

COR_ADMIN <- c("Capital (Teresina)" = "#08306B",
               "Resto da RIDE"      = "#6BAED6",
               "Resto da UF"        = "#252525")

COR_SIT   <- c("Rural"               = "#D9D9D9",
               "Urbano (exceto FCU)" = "#2196C9",
               "FCU"                 = "#F2A900")

# E é ORDINAL (faixa de renda crescente), então a escala tem que ser sequencial:
# quanto mais escuro, maior a renda. Cinza para o estrato único, que não é
# uma faixa de renda — é a ausência de estratificação.
COR_EST   <- c("Estrato único (sem 150 UPAs)" = "#BDBDBD",
               "Faixa 1 de renda"             = "#C6DBEF",
               "Faixa 2 de renda"             = "#4292C6",
               "Faixa 3 de renda"             = "#08306B")

paleta_geo <- setNames(
  colorRampPalette(c("#08306B", "#2171B5", "#6BAED6", "#969696", "#252525"))(
    nlevels(setores$Geografico)),
  levels(setores$Geografico)
)

# Paleta do painel composto (27 estratos). Rainbow padrão do ggplot destoaria
# do resto do relatório e ainda por cima não diz nada: as 27 categorias não
# são independentes, elas têm hierarquia. Então codifico a hierarquia na cor —
# a MATIZ é o estrato geográfico, a LUMINOSIDADE é a faixa de renda (mais
# claro = renda menor). Assim o painel mostra as duas camadas de uma vez.
clarear <- function(cor, peso) {
  rgb(t((1 - peso) * col2rgb(cor) + peso * 255), maxColorValue = 255)
}

base_por_geo <- c("2210" = "#08306B",  # Teresina
                  "2220" = "#8C6D1F",  # Entorno metropolitano
                  "2251" = "#2171B5",  # Centro-Leste
                  "2252" = "#4B9B6E",  # Baixo Parnaíba
                  "2253" = "#8B4A6F")  # Alto Parnaíba e Chapadas Sul

paleta_completa <- setores %>%
  st_drop_geometry() %>%
  filter(!is.na(Estrato7)) %>%
  distinct(cd_est4, Estrato7, E) %>%
  arrange(cd_est4, E) %>%
  group_by(cd_est4) %>%
  mutate(cor = clarear(base_por_geo[cd_est4],
                       if (n() == 1) 0.25 else seq(0.62, 0, length.out = n()))) %>%
  ungroup()

cores_completa <- setNames(paleta_completa$cor, as.character(paleta_completa$Estrato7))

tema_mapa <- theme_minimal(base_size = 9) +
  theme(axis.text = element_blank(), axis.ticks = element_blank(),
        panel.grid = element_blank(), legend.position = "bottom",
        legend.title = element_blank(), legend.text = element_text(size = 7),
        legend.key.size = unit(0.35, "cm"), legend.margin = margin(0, 0, 0, 0),
        plot.title = element_text(face = "bold", size = 10),
        plot.subtitle = element_text(size = 7.5, colour = "grey30"))

mapa <- function(dados, var, cores, titulo, subtitulo = NULL, ncol_leg = 1) {
  # Sem contorno, os milhares de setores censitários ficam "picotados" -
  # dá pra ver a cor de cada categoria, mas não onde um estrato termina e
  # o outro começa. Dissolvo os setores por categoria (uma geometria por
  # valor de `var`) e desenho só o contorno dessa geometria dissolvida, por
  # cima do preenchimento — isso destaca a fronteira real dos estratos sem
  # poluir o mapa com a linha de cada setor individual.
  contorno <- dados %>%
    filter(!is.na(.data[[var]])) %>%
    group_by(.data[[var]]) %>%
    summarise(.groups = "drop") %>%
    st_make_valid()
  
  ggplot(dados) +
    geom_sf(aes(fill = .data[[var]]), color = NA) +
    geom_sf(data = contorno, fill = NA, color = "black", linewidth = 0.45) +
    scale_fill_manual(values = cores, na.value = "grey92",
                      guide = if (ncol_leg == 0) "none"
                              else guide_legend(ncol = ncol_leg)) +
    labs(title = titulo, subtitle = subtitulo) +
    tema_mapa
}

# ---- Os 6 painéis -------------------------------------------------------------

p_admin <- mapa(setores, "Administrativo", COR_ADMIN,
                "AAA — administrativo",
                "dígitos 1-3: capital, RIDE, demais")

p_geo <- mapa(setores, "Geografico", paleta_geo,
              "GG — geográfico",
              "dígitos 4-5: agrupamentos de regiões", ncol_leg = 2)

p_sit <- mapa(setores, "Situacao", COR_SIT,
              "S — situação e tipo de área",
              "dígito 6: rural, urbano e FCU")

p_est <- mapa(setores, "Estatistico", COR_EST,
              "E — estrato estatístico",
              "dígito 7: faixa de renda do responsável", ncol_leg = 2)

p_full <- mapa(setores, "Estrato7", cores_completa,
               "AAAGGSE — código completo",
               sprintf("%d estratos; matiz = geográfico, tom = renda",
                       n_distinct(setores$Estrato7, na.rm = TRUE)),
               ncol_leg = 0)

# Teresina em separado: é onde está quase toda a FCU do estado (369 dos 372
# setores) e a única célula urbana da capital com 3 faixas de renda. Na escala
# do estado inteiro nada disso é visível. Sem legenda: é a mesma do painel E.
teresina <- setores %>% filter(CD_MUN == "2211001")

p_ter <- mapa(teresina, "Estatistico", COR_EST,
              "E — Teresina em detalhe",
              sprintf("%d setores; FCU e rural sem estratificação", nrow(teresina)),
              ncol_leg = 0)

# ---- Montagem -----------------------------------------------------------------

n_upas <- format(n_distinct(setores$UPA, na.rm = TRUE), big.mark = ".", decimal.mark = ",")

figura <- (p_admin | p_geo | p_sit) / (p_est | p_full | p_ter) +
  plot_annotation(
    title = "Estratos da PNAD Contínua no Piauí — os 7 dígitos do código AAAGGSE",
    subtitle = paste0(
      "Resolução: setor censitário (Censo 2022). AAA, GG e S são a classificação oficial; ",
      "E é reconstruído a partir de ", n_upas, " UPAs estimadas\n",
      "(mínimo de 60 domicílios rurais / 90 urbanos por UPA; estratificação ótima da renda ",
      "do responsável com no mínimo 150 UPAs por estrato).\n",
      "O número de estratos por célula confere com o crosswalk oficial da PNADC em 13 de 13 casos."),
    theme = theme(plot.title = element_text(face = "bold", size = 14),
                  plot.subtitle = element_text(size = 8.5, colour = "grey30"),
                  plot.margin = margin(10, 10, 10, 10))
  )

ggsave("output/figuras/mapa_aaagsse_piaui.png", figura,
       width = 16, height = 12, dpi = 150, bg = "white")

for (nm in c("admin", "geo", "sit", "est", "full", "ter")) {
  ggsave(sprintf("output/figuras/mapa_aaagsse_%s.png", nm),
         get(paste0("p_", nm)), width = 6, height = 6.5, dpi = 150, bg = "white")
}

message("Figura salva em output/figuras/mapa_aaagsse_piaui.png (+ 6 painéis individuais).")
