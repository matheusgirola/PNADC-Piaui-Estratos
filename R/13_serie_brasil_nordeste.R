# ==============================================================================
# 13_serie_brasil_nordeste.R — série 2016T2+ de Brasil e Nordeste, só para os
# gráficos de linha do relatório (R/12_graficos_panorama.R).
#
# A série de confiabilidade (R/10) é só do Piauí (decisão de 17/09/2026, por
# memória). Aqui entra Brasil e Nordeste a pedido do usuário (21/09/2026), mas
# restrito ao mínimo que os gráficos usam: os indicadores de INDICADORES_SERIE,
# recorte Total, sem desigualdade nem testes. Mesmo motor do 01/10
# (montar_geografias() + estimar_trimestre(), R/indicadores.R) — só o catálogo
# e os recortes vêm reduzidos.
#
# Brasil exige o desenho inteiro (sem recorte antes de derivar): pico de RAM
# maior que o do 10. Não entra na triagem (R/11): Brasil e Nordeste seguem
# marcados pelo CV do trimestre no relatório.
#
# Saída: dados_saida/serie_br_ne/base_<ano>T<tri>.rds (mesmo esquema da `base`
# do 10). Retomável e incremental: em trimestre com arquivo pronto, calcula só
# os indicadores de INDICADORES_SERIE que ainda não estão nele (acrescentar um
# indicador aos gráficos não refaz os outros). Mudou a FÓRMULA de um que já
# está? Apague os arquivos, que o incremental não percebe.
#   Rscript R/13_serie_brasil_nordeste.R          # todos os trimestres do cache
#   Rscript R/13_serie_brasil_nordeste.R 2026 2   # um trimestre só
# ==============================================================================

suppressPackageStartupMessages({
  library(survey)
  library(dplyr)
  library(tibble)
})

source("R/00_config.R", encoding = "UTF-8")
source("R/derivar_variaveis.R", encoding = "UTF-8")
source("R/indicadores.R", encoding = "UTF-8")
source("R/01a_cache_pnadc.R", encoding = "UTF-8")

# Os indicadores dos gráficos do R/12 (INDICADORES_PAINEL + territoriais).
# Taxa_Nem_Nem e Proporcao_Populacao_14_59 entraram em 22/09/2026.
INDICADORES_SERIE <- c("Taxa_Desocupacao", "Nivel_Ocupacao", "Taxa_Participacao",
                       "Taxa_Informalidade", "Taxa_Subocupacao", "Rendimento_Medio_Habitual",
                       "Taxa_Nem_Nem", "Proporcao_Populacao_14_59")

catalogo_serie <- Filter(function(s) s$id %in% INDICADORES_SERIE, catalogo_indicadores)
faltam <- setdiff(INDICADORES_SERIE, vapply(catalogo_serie, `[[`, "", "id"))
if (length(faltam)) stop("Fora do catálogo de R/indicadores.R: ", paste(faltam, collapse = ", "))

dir_saida <- "dados_saida/serie_br_ne"
dir.create(dir_saida, recursive = TRUE, showWarnings = FALSE)

arquivos <- list.files("data/raw", pattern = "^pnadc_br_\\d{4}_\\d\\.rds$", full.names = TRUE)
trimestres <- tibble(arquivo = arquivos) %>%
  mutate(ano = as.integer(sub(".*pnadc_br_(\\d{4})_\\d\\.rds", "\\1", arquivo)),
         tri = as.integer(sub(".*pnadc_br_\\d{4}_(\\d)\\.rds", "\\1", arquivo))) %>%
  arrange(desc(ano), desc(tri))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 2) {
  trimestres <- filter(trimestres, ano == as.integer(args[1]), tri == as.integer(args[2]))
}
if (nrow(trimestres) == 0) stop("Nenhum data/raw/pnadc_br_*.rds encontrado.")

for (i in seq_len(nrow(trimestres))) {
  t <- trimestres[i, ]
  saida <- file.path(dir_saida, sprintf("base_%dT%d.rds", t$ano, t$tri))
  anterior <- if (file.exists(saida)) readRDS(saida) else NULL
  faltam <- setdiff(INDICADORES_SERIE, anterior$Indicador)
  if (length(faltam) == 0) next

  t0 <- Sys.time()
  message(sprintf("[%s] %dT%d: %s", format(t0, "%H:%M:%S"), t$ano, t$tri, paste(faltam, collapse = ", ")))

  sm <- tabela_salario_minimo$sm_hora[tabela_salario_minimo$ano == t$ano]
  if (length(sm) != 1) stop("Sem salário mínimo para ", t$ano, " em R/00_config.R.")

  d <- derivar_variaveis(enxugar_pnadc(readRDS(t$arquivo)), sm_hora = sm)
  gc()

  geo <- list(Brasil   = d,
              Nordeste = subset(d, Regiao == "Nordeste"))
  res <- estimar_trimestre(geo, geografias_agregadas, t$ano, t$tri,
                           catalogo = Filter(function(s) s$id %in% faltam, catalogo_serie),
                           recortes = recortes_demograficos["Total"],
                           incluir_desigualdade = FALSE)
  falhas <- bind_rows(res$falhas)
  if (nrow(falhas) > 0) {
    print(falhas)
    stop(sprintf("%dT%d: %d falha(s) de estimação — nada gravado.", t$ano, t$tri, nrow(falhas)))
  }

  tmp <- paste0(saida, ".tmp")
  saveRDS(bind_rows(anterior, res$base), tmp)
  if (!file.rename(tmp, saida)) stop("Não consegui substituir ", saida, " (novo em ", tmp, ")")

  message(sprintf("  %d linhas, %.1f min", nrow(res$base),
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  rm(d, geo, res); gc()
}

message("Concluído: ", length(list.files(dir_saida, pattern = "^base_\\d{4}T\\d\\.rds$")),
        " trimestre(s) em ", dir_saida)
