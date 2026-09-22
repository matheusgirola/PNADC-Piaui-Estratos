# ==============================================================================
# 13_serie_brasil_nordeste.R — série 2016T2+ de Brasil e Nordeste, só para os
# gráficos de linha do relatório (R/12_graficos_panorama.R).
#
# A série de confiabilidade (R/10) é só do Piauí (decisão de 17/09/2026, por
# memória). Aqui entra Brasil e Nordeste a pedido do usuário (21/09/2026), mas
# restrito ao mínimo que os gráficos usam: os indicadores de INDICADORES_GRAFICOS
# (R/00_config.R), recorte Total, sem desigualdade nem testes. Mesmo motor do 01/10
# (montar_geografias() + estimar_trimestre(), R/indicadores.R) — só o catálogo
# e os recortes vêm reduzidos.
#
# Brasil exige o desenho inteiro (sem recorte antes de derivar): pico de RAM
# maior que o do 10. Não entra na triagem (R/11): Brasil e Nordeste seguem
# marcados pelo CV do trimestre no relatório.
#
# Saída: dados_saida/serie_br_ne/base_<ano>T<tri>.rds (mesmo esquema da `base`
# do 10). Retomável e incremental: em trimestre com arquivo pronto, calcula só
# os indicadores de INDICADORES_SERIE que ainda não estão nele ou cuja spec
# mudou em R/indicadores.R (assinatura() gravada no atributo "assinaturas" da
# base) — acrescentar ou mudar um indicador não refaz os outros. Mudança só em
# derivar_variaveis.R não é percebida: aí apague os arquivos.
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

# Os indicadores dos gráficos do R/12: INDICADORES_GRAFICOS, do R/00_config.R
# (lista única — antes duplicada aqui e no 12).
INDICADORES_SERIE <- INDICADORES_GRAFICOS

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

assinaturas <- setNames(vapply(catalogo_serie, assinatura, ""), vapply(catalogo_serie, `[[`, "", "id"))

# Grava a base com as assinaturas dos indicadores que ela contém.
gravar_base <- function(base, saida) {
  attr(base, "assinaturas") <- assinaturas[intersect(names(assinaturas), unique(base$Indicador))]
  tmp <- paste0(saida, ".tmp")
  saveRDS(base, tmp)
  if (!file.rename(tmp, saida)) stop("Não consegui substituir ", saida, " (novo em ", tmp, ")")
}

for (i in seq_len(nrow(trimestres))) {
  t <- trimestres[i, ]
  saida <- file.path(dir_saida, sprintf("base_%dT%d.rds", t$ano, t$tri))
  anterior <- if (file.exists(saida)) readRDS(saida) else NULL
  gravadas <- attr(anterior, "assinaturas")
  if (!is.null(anterior) && is.null(gravadas)) {
    # Arquivo de antes das assinaturas (22/09/2026): assume a spec atual e só marca.
    gravar_base(anterior, saida)
    message(sprintf("%dT%d: sem assinaturas — marcado com as atuais, sem recalcular.", t$ano, t$tri))
    gravadas <- assinaturas
  }
  presentes <- intersect(INDICADORES_SERIE, anterior$Indicador)
  mudaram <- presentes[is.na(gravadas[presentes]) | gravadas[presentes] != assinaturas[presentes]]
  faltam <- union(setdiff(INDICADORES_SERIE, anterior$Indicador), mudaram)
  if (length(faltam) == 0) next
  if (!is.null(anterior)) anterior <- filter(anterior, !Indicador %in% mudaram)

  t0 <- Sys.time()
  message(sprintf("[%s] %dT%d: %s%s", format(t0, "%H:%M:%S"), t$ano, t$tri, paste(faltam, collapse = ", "),
                  if (length(mudaram)) paste0(" (spec nova: ", paste(mudaram, collapse = ", "), ")") else ""))

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

  gravar_base(bind_rows(anterior, res$base), saida)

  message(sprintf("  %d linhas, %.1f min", nrow(res$base),
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  rm(d, geo, res); gc()
}

message("Concluído: ", length(list.files(dir_saida, pattern = "^base_\\d{4}T\\d\\.rds$")),
        " trimestre(s) em ", dir_saida)
