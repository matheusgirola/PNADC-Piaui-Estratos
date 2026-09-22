# ==============================================================================
# graficos_serie.R — módulo (carregado via source()) com a parte sem ggplot do
# R/12_graficos_panorama.R: territórios e rótulos dos gráficos, leitura da
# série do 10 (Piauí) e do 13 (Brasil/Nordeste), escala de exibição e as
# conferências de completude. O 12 só desenha e grava as figuras.
#
# Depende de R/precisao.R (ic_inferior(), ic_superior()), carregado por quem
# usa. Os indicadores (INDICADORES_PAINEL/TERRITORIAIS/GRAFICOS) ficam no
# R/00_config.R, porque o R/13 também usa. Testado em
# tests/testthat/test-graficos_serie.R.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
})

# Os territórios do corpo do relatório (GEO_REFERENCIA + Piauí + GEO_AGREG +
# GEO_ZONA no 09_preencher_relatorio.R), nesta ordem — preenche a grade 5x2
# linha a linha: Brasil/Nordeste, Piauí/Teresina, Entorno/Centro-Leste, Baixo
# Parnaíba/Alto Parnaíba, Urbana/Rural.
GEOGRAFIAS_REFERENCIA <- c("Brasil", "Nordeste")
GEOGRAFIAS <- c(GEOGRAFIAS_REFERENCIA, "Piauí", "Teresina",
                "Agreg_Entorno metropolitano de Teresina (PI)", "Agreg_Centro-Leste do Piauí",
                "Agreg_Baixo Parnaíba do Piauí", "Agreg_Alto Parnaíba e Chapadas Sul do Piauí",
                "Zona_Urbana", "Zona_Rural")

# ---- Rótulos e escala de exibição (mesmos nomes do CATALOGO no 09) -----------

nomes_indicadores <- c(
  Taxa_Desocupacao          = "Taxa de desocupação",
  Nivel_Ocupacao            = "Nível da ocupação",
  Taxa_Participacao         = "Taxa de participação na força de trabalho",
  Taxa_Informalidade        = "Taxa de informalidade",
  Taxa_Subocupacao          = "Subocupação por insuficiência de horas",
  Rendimento_Medio_Habitual = "Rendimento médio real habitual",
  Taxa_Nem_Nem              = "Jovens de 14 a 29 anos que não estudam nem trabalham",
  Proporcao_Populacao_14_59 = "Pessoas de 14 a 59 anos na população"
)
unidade_indicador <- c(
  Taxa_Desocupacao = "pct", Nivel_Ocupacao = "pct", Taxa_Participacao = "pct",
  Taxa_Informalidade = "pct", Taxa_Subocupacao = "pct", Rendimento_Medio_Habitual = "reais",
  Taxa_Nem_Nem = "pct", Proporcao_Populacao_14_59 = "pct"
)
# Mesmos rótulos de território do GEO_AGREG/GEO_ZONA no 09_preencher_relatorio.R.
nomes_geografias <- c(
  Brasil = "Brasil", Nordeste = "Nordeste",
  Piauí = "Piauí", Teresina = "Teresina",
  "Agreg_Entorno metropolitano de Teresina (PI)" = "Entorno metropolitano",
  "Agreg_Centro-Leste do Piauí" = "Centro-Leste",
  "Agreg_Baixo Parnaíba do Piauí" = "Baixo Parnaíba",
  "Agreg_Alto Parnaíba e Chapadas Sul do Piauí" = "Alto Parnaíba e Chapadas",
  Zona_Urbana = "Zona urbana", Zona_Rural = "Zona rural"
)

# Rampa fria (mesma família de cores do projeto — R/03_comparacoes_indicadores.R,
# gerar_paleta_fria()), uma cor por território do Piauí, na ordem de
# GEOGRAFIAS; Brasil e Nordeste em laranja/marrom, fora da rampa, pra ler como
# referência externa. Nomes = rótulos de exibição.
montar_paleta <- function(geografias = GEOGRAFIAS) {
  geos_pi <- setdiff(geografias, GEOGRAFIAS_REFERENCIA)
  c(Brasil = "#A6611A", Nordeste = "#E08214",
    setNames(colorRampPalette(c("#08306B", "#2171B5", "#6BAED6", "#969696", "#252525"))(length(geos_pi)),
             unname(nomes_geografias[geos_pi])))
}

# Para com erro se algum indicador ou território não tiver rótulo/unidade —
# sem isso o gráfico sairia com faceta "NA" sem aviso.
checar_rotulos_graficos <- function(indicadores, geografias = GEOGRAFIAS) {
  sem <- c(setdiff(indicadores, names(nomes_indicadores)),
           setdiff(indicadores, names(unidade_indicador)),
           setdiff(geografias, names(nomes_geografias)))
  if (length(sem)) stop("Sem rótulo/unidade em R/graficos_serie.R: ", paste(unique(sem), collapse = ", "))
  invisible(TRUE)
}

# ---- Leitura da série --------------------------------------------------------

listar_bases <- function(dir) list.files(dir, pattern = "^base_\\d{4}T\\d\\.rds$", full.names = TRUE)

# Trimestres da série do Piauí (10) sem a de Brasil/Nordeste (13).
checar_br_ne <- function(arquivos, arquivos_br_ne) {
  faltam <- setdiff(basename(arquivos), basename(arquivos_br_ne))
  if (length(faltam) > 0) {
    stop("Brasil/Nordeste sem série para ", length(faltam), " trimestre(s) (",
         paste(head(faltam, 3), collapse = ", "), "...) — rode R/13_serie_brasil_nordeste.R antes.")
  }
  invisible(TRUE)
}

# Linhas do recorte Total dos indicadores/territórios dos gráficos.
filtrar_base <- function(base, indicadores, geografias = GEOGRAFIAS) {
  base %>%
    filter(Indicador %in% indicadores,
           Regiao_Geografica %in% geografias, Recorte_Demografico == "Total") %>%
    select(Indicador, Estimativa, SE, Ano, Trimestre, Regiao_Geografica)
}

# Lê o 10 (lista com $base) e o 13 (só a base) e junta.
ler_serie <- function(arquivos, arquivos_br_ne, indicadores) {
  bind_rows(map_dfr(arquivos, ~ filtrar_base(readRDS(.x)$base, indicadores)),
            map_dfr(arquivos_br_ne, ~ filtrar_base(readRDS(.x), indicadores)))
}

# Tempo contínuo, IC 95%, rótulos e escala de exibição (proporção -> %).
preparar_serie <- function(serie) {
  serie <- serie %>%
    mutate(
      Ano_Trimestre = Ano + (Trimestre - 1) / 4,
      IC_inf = ic_inferior(Estimativa, SE),
      IC_sup = ic_superior(Estimativa, SE)
    ) %>%
    arrange(Indicador, Regiao_Geografica, Ano, Trimestre) %>%
    mutate(
      Regiao_Nome = recode(Regiao_Geografica, !!!nomes_geografias),
      Indicador_Nome = recode(Indicador, !!!nomes_indicadores),
      unidade = unname(unidade_indicador[Indicador]),
      Estimativa_disp = ifelse(unidade == "pct", Estimativa * 100, Estimativa),
      IC_inf_disp = ifelse(unidade == "pct", IC_inf * 100, IC_inf),
      IC_sup_disp = ifelse(unidade == "pct", IC_sup * 100, IC_sup)
    )
  serie$Indicador_Nome <- factor(serie$Indicador_Nome, levels = unname(nomes_indicadores))
  serie
}

# Para com erro se o indicador não tiver série em algum território do gráfico.
checar_territorios <- function(serie, indicador, geografias = GEOGRAFIAS) {
  sem_dado <- setdiff(geografias, serie$Regiao_Geografica[serie$Indicador == indicador])
  if (length(sem_dado) > 0) {
    stop(indicador, " sem série para: ", paste(sem_dado, collapse = ", "),
         " — rode R/13 (Brasil/Nordeste) ou R/10b (Piauí) antes.")
  }
  invisible(TRUE)
}

# ---- Formatação --------------------------------------------------------------

# quebra a legenda da fonte em linhas pra caber na largura da figura
quebrar_caption <- function(txt, largura = 130) paste(strwrap(txt, largura), collapse = "\n")

formatar_eixo_y <- function(u) {
  if (u == "reais") function(x) paste0("R$ ", format(x, big.mark = ".", scientific = FALSE))
  else function(x) paste0(x, "%")
}
