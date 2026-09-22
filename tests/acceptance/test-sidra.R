# Teste de aceitação: indicadores do catálogo contra os valores oficiais do SIDRA,
# com o microdado real de um trimestre. Pesado (~2,3 GB de RAM, alguns minutos)
# e dependente do cache — por isso fora de tests/testthat. Rodar da raiz:
#   testthat::test_dir("tests/acceptance")
# Trimestre: o de R/00_config.R; outro via variável de ambiente, ex.
#   Sys.setenv(PNADC_ACEITE = "2025 4")
# Pula (skip) se data/raw/pnadc_br_<ano>_<tri>.rds não existir, ou se o valor
# oficial não estiver no cache data/raw/sidra/ e a API do IBGE não responder.
# Valida só o Piauí (decisão de 17/09/2026: Brasil e Nordeste já conferidos).
#
# Mesmo critério da série (scripts_teste/validacao_sidra.R): mapa e tolerâncias
# vêm de R/sidra.R, então este teste e a série não divergem.

raiz <- normalizePath(test_path("..", ".."))

withr::with_dir(raiz, {
  source("R/derivar_variaveis.R", encoding = "UTF-8")
  source("R/indicadores.R", encoding = "UTF-8")
  source("R/sidra.R", encoding = "UTF-8")
  source("R/01a_cache_pnadc.R", encoding = "UTF-8")   # arquivo_cache_pnadc(), enxugar_pnadc()
  suppressMessages(source("R/00_config.R", encoding = "UTF-8"))  # ANO_REF, salário mínimo
})

indice <- function(ano, tri) ano * 4 + tri

preparar <- function() {
  withr::local_dir(raiz)
  alvo <- Sys.getenv("PNADC_ACEITE", sprintf("%d %d", ANO_REF, TRIMESTRE_REF))
  alvo <- as.integer(strsplit(trimws(alvo), "\\s+")[[1]])
  ano <- alvo[1]; tri <- alvo[2]
  arquivo <- arquivo_cache_pnadc(ano, tri)
  if (!file.exists(arquivo)) skip(sprintf("sem cache do microdado: %s", arquivo))

  # Mesma grade de períodos da série: reaproveita o cache data/raw/sidra/.
  periodos <- if (indice(ano, tri) > indice(ANO_REF, TRIMESTRE_REF)) periodos_serie(ano, tri) else
    periodos_serie(ANO_REF, TRIMESTRE_REF)
  oficiais <- tryCatch(buscar_oficiais("Piauí", "N3[22]", periodos),
                       error = function(e) skip(paste("SIDRA indisponível:", conditionMessage(e))))

  sm <- tabela_salario_minimo$sm_hora[tabela_salario_minimo$ano == ano]
  bruto <- enxugar_pnadc(readRDS(arquivo))
  bruto <- bruto[bruto$variables$UF == "Piauí", ]
  gc()
  d <- derivar_variaveis(bruto, sm_hora = sm)
  rm(bruto); gc()

  periodo <- periodo_sidra(ano, tri)
  list(
    trimestre   = sprintf("%dT%d", ano, tri),
    comparacoes = comparar_com_sidra(
      estimar_catalogo(d, unique(mapa$Indicador)) %>%
        mutate(territorio = "Piauí", periodo = periodo),
      oficiais),
    internas    = checagens_internas(d),
    gini        = conferir_gini(d)
  )
}

# Calculado uma vez para todos os testes do arquivo.
res <- NULL
obter <- function() {
  if (is.null(res)) res <<- preparar()
  res
}

descrever <- function(x) {
  paste(sprintf("%s [%s]: estimado %.3f, oficial %.3f", x$Indicador,
                x$Subcategoria_Indicador, x$estimado, x$oficial), collapse = "\n")
}

test_that("todo indicador do mapa é estimado", {
  r <- obter()
  est <- distinct(r$comparacoes, Indicador, Subcategoria_Indicador)
  faltam <- anti_join(mapa, est, by = c("Indicador", "Subcategoria_Indicador"))
  expect(nrow(faltam) == 0,
         paste("sem estimativa:", paste(faltam$Subcategoria_Indicador, collapse = ", ")))
})

test_that("estimativas batem com o SIDRA dentro do arredondamento publicado", {
  r <- obter()
  com_oficial <- filter(r$comparacoes, !is.na(oficial))
  if (nrow(com_oficial) == 0) skip(paste("SIDRA não publica o Piauí em", r$trimestre))
  fora <- filter(com_oficial, !ok)
  expect(nrow(fora) == 0,
         sprintf("%s: %d de %d fora da tolerância\n%s", r$trimestre, nrow(fora),
                 nrow(com_oficial), descrever(fora)))
})

test_that("identidades internas valem no microdado real", {
  r <- obter()
  expect(all(r$internas$ok),
         paste("falharam:", paste(r$internas$checagem[!r$internas$ok], collapse = "; ")))
})

test_that("Gini do catálogo confere com a implementação independente", {
  r <- obter()
  expect_true(gini_confere(r$gini))
  expect_gt(r$gini$gini_catalogo, 0)
  expect_lt(r$gini$gini_catalogo, 1)
})
