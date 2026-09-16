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

  for (i in seq_len(tentativas)) {
    message(sprintf("[%s] Baixando %dT%d (tentativa %d/%d)...",
                    format(Sys.time(), "%H:%M:%S"), ano, tri, i, tentativas))
    d <- tryCatch(get_pnadc(year = ano, quarter = tri, deflator = TRUE),
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
