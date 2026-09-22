# ==============================================================================
# 10b_atualizar_serie_indicador.R — recalcula, na série do 10
# (dados_saida/serie/base_<ano>T<tri>.rds), só os indicadores indicados, sem
# refazer o catálogo inteiro. Para quando a fórmula de um indicador muda em
# R/indicadores.R: as linhas dele em cada trimestre são trocadas pelas novas
# (valores, SE e o texto de Subcategoria_Indicador, que vem da fórmula), e as
# falhas antigas dele saem do log do trimestre.
#
# Mesmo caminho do 10 (enxugar -> recortar o Piauí -> derivar ->
# montar_geografias -> estimar_trimestre), só com o catálogo filtrado; o
# resultado é o mesmo que rodar o 10 do zero para esses indicadores.
# Pico ~2,3 GB (leitura do .rds do Brasil).
#
# Retomável: cada arquivo guarda em $atualizado[[id]] o texto da fórmula
# usada; trimestre em que o texto bate com o catálogo atual é pulado.
#
#   Rscript R/10b_atualizar_serie_indicador.R Proporcao_Ocupados_Escolarizados
#   Rscript R/10b_atualizar_serie_indicador.R <id> [<id> ...] -- 2026 2   # um trimestre
#
# Depois: Rscript R/11_triagem_confiabilidade.R (a triagem lê a série).
# ==============================================================================

suppressPackageStartupMessages({
  library(survey)
  library(dplyr)
  library(tibble)
})

source("R/00_config.R", encoding = "UTF-8")        # tabela_salario_minimo, geografias_agregadas
source("R/derivar_variaveis.R", encoding = "UTF-8")
source("R/indicadores.R", encoding = "UTF-8")      # catalogo_indicadores, estimar_trimestre()
source("R/01a_cache_pnadc.R", encoding = "UTF-8")  # enxugar_pnadc()

args <- commandArgs(trailingOnly = TRUE)
sep  <- match("--", args)
ids  <- if (is.na(sep)) args else head(args, sep - 1)
filtro_tri <- if (is.na(sep)) NULL else as.integer(args[(sep + 1):length(args)])
if (length(ids) == 0) stop("Informe o(s) id(s) do indicador. Ex.: Rscript R/10b_atualizar_serie_indicador.R Proporcao_Ocupados_Escolarizados")

catalogo <- Filter(function(s) s$id %in% ids, catalogo_indicadores)
desconhecidos <- setdiff(ids, vapply(catalogo, `[[`, "", "id"))
if (length(desconhecidos)) stop("Fora do catálogo: ", paste(desconhecidos, collapse = ", "))

# Assinatura da spec: muda sempre que fórmula, denominador ou subset mudam.
assinatura <- function(s) {
  paste(deparse(s[c("formula", "denominador", "subset", "fun")]), collapse = "")
}
assinaturas <- setNames(vapply(catalogo, assinatura, ""), vapply(catalogo, `[[`, "", "id"))

dir_serie <- "dados_saida/serie"
arquivos <- list.files(dir_serie, pattern = "^base_\\d{4}T\\d\\.rds$", full.names = TRUE)
trimestres <- tibble(saida = arquivos) %>%
  mutate(ano = as.integer(sub(".*base_(\\d{4})T\\d\\.rds", "\\1", saida)),
         tri = as.integer(sub(".*base_\\d{4}T(\\d)\\.rds", "\\1", saida)),
         bruto = arquivo_cache_pnadc(ano, tri)) %>%
  arrange(desc(ano), desc(tri))
if (!is.null(filtro_tri)) trimestres <- filter(trimestres, ano == filtro_tri[1], tri == filtro_tri[2])
if (nrow(trimestres) == 0) stop("Nenhum trimestre da série para atualizar em ", dir_serie)

message(sprintf("Atualizando %s em %d trimestre(s).", paste(ids, collapse = ", "), nrow(trimestres)))

for (i in seq_len(nrow(trimestres))) {
  t <- trimestres[i, ]
  res <- readRDS(t$saida)
  feitos <- vapply(ids, function(id) identical(res$atualizado[[id]], assinaturas[[id]]), TRUE)
  if (all(feitos)) next
  if (!file.exists(t$bruto)) stop("Sem cache do microdado: ", t$bruto)

  t0 <- Sys.time()
  message(sprintf("[%s] %dT%d...", format(t0, "%H:%M:%S"), t$ano, t$tri))

  sm <- tabela_salario_minimo$sm_hora[tabela_salario_minimo$ano == t$ano]
  bruto <- enxugar_pnadc(readRDS(t$bruto))
  bruto <- bruto[bruto$variables$UF == "Piauí", ]
  gc()
  d_pi <- derivar_variaveis(bruto, sm_hora = sm)
  rm(bruto); gc()

  geo  <- montar_geografias(d_pi, d_pi, incluir_brasil_nordeste = FALSE, incluir_micro = FALSE)
  novo <- estimar_trimestre(geo, geografias_agregadas, t$ano, t$tri,
                            catalogo = catalogo, incluir_desigualdade = FALSE)

  n_antes <- sum(res$base$Indicador %in% ids)
  res$base   <- bind_rows(filter(res$base, !Indicador %in% ids), novo$base)
  falhas_velhas <- if ("Indicador" %in% names(res$falhas)) filter(res$falhas, !Indicador %in% ids) else res$falhas
  res$falhas <- bind_rows(falhas_velhas, bind_rows(novo$falhas))
  for (id in ids) res$atualizado[[id]] <- assinaturas[[id]]

  tmp <- paste0(t$saida, ".tmp")
  saveRDS(res, tmp)
  if (!file.rename(tmp, t$saida)) stop("Não consegui substituir ", t$saida, " (novo em ", tmp, ")")

  message(sprintf("  %d linhas trocadas por %d, %.1f min", n_antes, nrow(novo$base),
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  rm(d_pi, geo, novo, res); gc()
}

message("Concluído. Rode R/11_triagem_confiabilidade.R para refazer a triagem.")
