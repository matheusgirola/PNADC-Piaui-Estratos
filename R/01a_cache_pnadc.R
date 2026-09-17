# ==============================================================================
# 01a_cache_pnadc.R — cache local da PNADC trimestral (Brasil inteiro).
#
# Módulo carregado via source(), como R/derivar_variaveis.R. Não é passo do
# fluxo. Uso:
#   source("R/01a_cache_pnadc.R", encoding = "UTF-8")
#   d <- carregar_pnadc(2026, 2)
#
# Grava data/raw/pnadc_br_<ano>_<tri>.rds com o desenho BRUTO devolvido por
# PNADcIBGE::get_pnadc(deflator = TRUE): sem variáveis derivadas, que sempre
# vêm de derivar_variaveis(). Junto, um .json com a data do download: os
# deflatores (Habitual/Efetivo) são referenciados ao último trimestre
# disponível NA DATA DO DOWNLOAD, então dois arquivos baixados em datas
# diferentes não têm rendimento real na mesma base.
#
# Rodado como script (Rscript R/01a_cache_pnadc.R), faz a pré-carga
# retomável de 2016T2 até o trimestre de R/00_config.R, pulando o que já
# existe. Demora horas — rodar em segundo plano com log em arquivo.
# ==============================================================================

library(PNADcIBGE)
library(survey)

DIR_CACHE_PNADC <- "data/raw"

arquivo_cache_pnadc <- function(ano, tri) {
  file.path(DIR_CACHE_PNADC, sprintf("pnadc_br_%d_%d.rds", ano, tri))
}

carregar_pnadc <- function(ano, tri, tentativas = 3) {
  arquivo <- arquivo_cache_pnadc(ano, tri)
  if (file.exists(arquivo)) return(readRDS(arquivo))

  # get_pnadc() deixa o .zip e o .txt extraído (~2 GB por trimestre) em
  # savedir e não apaga; com o tempdir() padrão isso acumulou 72 GB na
  # pré-carga, e se o processo for morto o R nem limpa o tempdir na saída.
  # Uma pasta por trimestre, apagada assim que o .rds é gravado.
  dir_download <- file.path(tempdir(), sprintf("pnadc_%d_%d", ano, tri))
  dir.create(dir_download, showWarnings = FALSE)
  on.exit(unlink(dir_download, recursive = TRUE), add = TRUE)

  for (i in seq_len(tentativas)) {
    message(sprintf("[%s] Baixando %dT%d (tentativa %d/%d)...",
                    format(Sys.time(), "%H:%M:%S"), ano, tri, i, tentativas))
    d <- tryCatch(get_pnadc(year = ano, quarter = tri, deflator = TRUE, savedir = dir_download),
                  error = function(e) { message("  erro: ", conditionMessage(e)); NULL })
    # get_pnadc() às vezes só emite message() e devolve NULL quando o FTP falha
    if (inherits(d, "svyrep.design")) break
    d <- NULL
    if (i < tentativas) Sys.sleep(60 * i)
  }
  if (is.null(d)) stop("Falha ao baixar a PNADC ", ano, "T", tri, " após ", tentativas, " tentativas.")

  # grava em arquivo temporário e renomeia: um download interrompido não
  # deixa um .rds truncado que pareceria válido na próxima execução
  tmp <- paste0(arquivo, ".tmp")
  saveRDS(d, tmp)
  file.rename(tmp, arquivo)
  writeLines(sprintf('{"ano": %d, "trimestre": %d, "data_download": "%s", "PNADcIBGE": "%s", "linhas": %d}',
                     ano, tri, format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                     as.character(packageVersion("PNADcIBGE")), nrow(d$variables)),
             sub("\\.rds$", ".json", arquivo))
  message(sprintf("  ok: %d linhas, %.0f MB", nrow(d$variables), file.size(arquivo) / 1e6))
  d
}

# ---- Enxugar colunas (memória) -------------------------------------------------
# O microdado tem ~440 colunas; derivar_variaveis() e o catálogo usam ~25.
# No Brasil (~520 mil linhas) as colunas ocupam ~1,5 GB e são copiadas a cada
# recorte (Nordeste, Piauí). Os pesos replicados ficam em design$repweights,
# fora de $variables, e não são afetados.
# Ao incluir uma variável bruta nova em R/derivar_variaveis.R ou
# R/indicadores.R, acrescentá-la aqui — senão o R para com "objeto não
# encontrado" (falha ruidosa, não silenciosa).
COLUNAS_PNADC_USADAS <- c(
  "UF", "Estrato", "V1022", "V1023",                           # geografia
  "V2007", "V2009", "V2010", "VD2002", "V3002", "VD3004",      # demografia
  "V4019", "V4074A", "V4078A", "VD4001", "VD4002", "VD4003", "VD4004A",
  "VD4005", "VD4009", "VD4010", "VD4019", "VD4030", "VD4031"   # trabalho
)
# identificação, desenho e deflatores: mantidas se existirem na rodada
COLUNAS_PNADC_APOIO <- c("Ano", "Trimestre", "Capital", "RM_RIDE", "UPA", "V1008", "V1014",
                         "V1016", "V1027", "V1028", "V1029", "V1033", "posest", "posest_sxi",
                         "Habitual", "Efetivo")

enxugar_pnadc <- function(design, extras = character()) {
  nomes <- names(design$variables)
  faltam <- setdiff(c(COLUNAS_PNADC_USADAS, extras), nomes)
  if (length(faltam)) stop("Colunas ausentes no microdado: ", paste(faltam, collapse = ", "))
  manter <- intersect(nomes, c(COLUNAS_PNADC_USADAS, COLUNAS_PNADC_APOIO, extras))
  design$variables <- design$variables[, manter, drop = FALSE]
  design
}

# ---- Pré-carga retomável (só quando rodado como script) ----------------------
if (sys.nframe() == 0L) {
  source("R/00_config.R", encoding = "UTF-8")
  trimestres <- expand.grid(tri = 1:4, ano = 2016:ANO_REF)
  trimestres <- subset(trimestres, !(ano == 2016 & tri < 2) &
                         !(ano == ANO_REF & tri > TRIMESTRE_REF))
  # do mais recente para o mais antigo: o trimestre corrente fica disponível
  # primeiro para o teste de regressão do 01
  trimestres <- trimestres[nrow(trimestres):1, ]
  falhas <- character()
  for (k in seq_len(nrow(trimestres))) {
    a <- trimestres$ano[k]; t <- trimestres$tri[k]
    if (file.exists(arquivo_cache_pnadc(a, t))) { message(a, "T", t, ": já em cache"); next }
    ok <- tryCatch({ invisible(carregar_pnadc(a, t)); TRUE },
                   error = function(e) { message("FALHA ", a, "T", t, ": ", conditionMessage(e)); FALSE })
    if (!ok) falhas <- c(falhas, sprintf("%dT%d", a, t))
    gc()
  }
  message("PRÉ-CARGA FIM. Falhas: ", if (length(falhas)) paste(falhas, collapse = ", ") else "nenhuma")
}
