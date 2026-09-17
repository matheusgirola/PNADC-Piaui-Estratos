# ==============================================================================
# 10_serie_confiabilidade.R — série de estimativas do Piauí, 2016T2 em diante,
# para a triagem de confiabilidade (CONTEXTO_PROJETO.md §1 e §8.5, passo 3).
#
# Para cada data/raw/pnadc_br_<ano>_<tri>.rds (cache de R/01a_cache_pnadc.R),
# roda o mesmo motor do 01 (estimar_trimestre(), R/indicadores.R) sobre as
# geografias do Piauí — Piauí, Teresina, Zonas, Estratos Admin e Agregados —
# SEM o estrato fino (Micro, fora do escopo) e SEM testes de significância.
# Brasil e Nordeste ficam de fora (memória; decisão do usuário, 17/09/2026).
#
# Memória: enxuga as colunas e recorta o Piauí logo após a leitura, antes de
# derivar — pico ~2,3 GB (a própria leitura do .rds), contra ~9 GB estimando
# sobre o Brasil inteiro. Recorte antes de derivar dá o mesmo resultado que
# depois (conferido no validacao_sidra.R, 2016T4, e no Nordeste, 2026T2).
#
# Saída: dados_saida/serie/base_<ano>T<tri>.rds = list(base, desigualdade,
# falhas, crosswalk). Retomável: trimestre com arquivo pronto é pulado.
#   Rscript R/10_serie_confiabilidade.R          # todos os trimestres do cache
#   Rscript R/10_serie_confiabilidade.R 2026 2   # um trimestre só
# ==============================================================================

suppressPackageStartupMessages({
  library(survey)
  library(dplyr)
  library(tibble)
})

source("R/00_config.R", encoding = "UTF-8")        # tabela_salario_minimo, geografias_agregadas
source("R/derivar_variaveis.R", encoding = "UTF-8")
source("R/indicadores.R", encoding = "UTF-8")      # montar_geografias(), estimar_trimestre()
source("R/01a_cache_pnadc.R", encoding = "UTF-8")  # enxugar_pnadc()

dir_serie <- "dados_saida/serie"
dir.create(dir_serie, recursive = TRUE, showWarnings = FALSE)

arquivos <- list.files("data/raw", pattern = "^pnadc_br_\\d{4}_\\d\\.rds$", full.names = TRUE)
trimestres <- tibble(arquivo = arquivos) %>%
  mutate(ano = as.integer(sub(".*pnadc_br_(\\d{4})_\\d\\.rds", "\\1", arquivo)),
         tri = as.integer(sub(".*pnadc_br_\\d{4}_(\\d)\\.rds", "\\1", arquivo))) %>%
  arrange(desc(ano), desc(tri))  # mais recente primeiro: a janela principal sai antes

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 2) {
  trimestres <- filter(trimestres, ano == as.integer(args[1]), tri == as.integer(args[2]))
}
if (nrow(trimestres) == 0) stop("Nenhum data/raw/pnadc_br_*.rds encontrado.")

for (i in seq_len(nrow(trimestres))) {
  t <- trimestres[i, ]
  saida <- file.path(dir_serie, sprintf("base_%dT%d.rds", t$ano, t$tri))
  if (file.exists(saida)) next

  t0 <- Sys.time()
  message(sprintf("[%s] %dT%d...", format(t0, "%H:%M:%S"), t$ano, t$tri))

  sm <- tabela_salario_minimo$sm_hora[tabela_salario_minimo$ano == t$ano]
  if (length(sm) != 1) stop("Sem salário mínimo para ", t$ano, " em R/00_config.R.")

  bruto <- enxugar_pnadc(readRDS(t$arquivo))
  bruto <- bruto[bruto$variables$UF == "Piauí", ]
  gc()
  d_pi <- derivar_variaveis(bruto, sm_hora = sm)
  rm(bruto); gc()

  # Estrato sem classificação apagaria gente das geografias sem aviso: para.
  crosswalk <- distinct(d_pi$variables, Estrato, Zona, Estrato_Admin, Estrato_agregado)
  sem_classe <- crosswalk %>% filter(is.na(Zona) | is.na(Estrato_Admin) | is.na(Estrato_agregado))
  if (nrow(sem_classe) > 0) {
    stop(sprintf("%dT%d: estrato(s) sem classificação: %s", t$ano, t$tri,
                 paste(sem_classe$Estrato, collapse = ", ")))
  }

  geo <- montar_geografias(d_pi, d_pi, incluir_brasil_nordeste = FALSE, incluir_micro = FALSE)
  res <- estimar_trimestre(geo, geografias_agregadas, t$ano, t$tri)
  res$falhas    <- bind_rows(res$falhas)
  res$crosswalk <- crosswalk

  tmp <- paste0(saida, ".tmp")
  saveRDS(res, tmp)
  file.rename(tmp, saida)

  message(sprintf("  %d linhas, %d falhas, %d estratos, %.1f min", nrow(res$base),
                  nrow(res$falhas), nrow(crosswalk),
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  rm(d_pi, geo, res); gc()
}

message("Concluído: ", length(list.files(dir_serie, pattern = "^base_\\d{4}T\\d\\.rds$")),
        " trimestre(s) em ", dir_serie)
