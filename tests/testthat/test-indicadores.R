# Testes de R/indicadores.R (catálogo + motor) sobre a população sintética do
# helper-indicadores.R. Rodar da raiz do projeto: testthat::test_dir("tests/testthat")

d   <- desenho_teste(populacao_teste())
v   <- d$variables
w   <- weights(d, "sampling")
GEO_AGREGADAS <- c("Brasil", "Nordeste", "Piauí", "Teresina")

# ---- Contratos do catálogo --------------------------------------------------

test_that("ids do catálogo são únicos", {
  ids <- vapply(catalogo_indicadores, `[[`, "", "id")
  expect_identical(ids[duplicated(ids)], character(0))
})

test_that("toda spec tem fórmula e função conhecida; razão exige denominador", {
  funs <- list(svymean, svyratio, svytotal, convey::svygini)
  for (s in catalogo_indicadores) {
    expect_s3_class(s$formula, "formula")
    expect_true(any(vapply(funs, identical, TRUE, s$fun)), info = s$id)
    expect_identical(identical(s$fun, svyratio), !is.null(s$denominador), info = s$id)
    if (!is.null(s$subset)) expect_s3_class(s$subset, "formula")
    if (!is.null(s$geografias)) {
      expect_true(all(s$geografias %in% GEO_AGREGADAS), info = s$id)
    }
  }
})

test_that("toda variável usada no catálogo e nos recortes existe após derivar", {
  usadas <- unique(unlist(c(
    lapply(catalogo_indicadores, function(s) {
      c(all.vars(s$formula), all.vars(s$denominador), all.vars(s$subset))
    }),
    lapply(recortes_demograficos, all.vars)
  )))
  expect_identical(setdiff(usadas, names(v)), character(0))
})

test_that("composição da PIT: total e distribuição por dimensão, só no Total", {
  expect_length(catalogo_composicao_pit, 2 * length(dimensoes_pit))
  for (s in catalogo_composicao_pit) {
    expect_true(isTRUE(s$so_recorte_total), info = s$id)
    expect_identical(deparse(s$subset), "~pit == 1", info = s$id)
  }
})

# Numa taxa/proporção, quem conta no numerador tem que contar no denominador —
# senão a razão pode passar de 1 e não é a proporção que o nome diz.
# Linha com denominador NA não conta: o na.rm = TRUE do svyratio a descarta.

test_that("numerador das razões está contido no denominador", {
  for (s in catalogo_indicadores) {
    if (!identical(s$fun, svyratio)) next
    u   <- aplicar_subset(d, s$subset)$variables
    num <- as.numeric(eval(s$formula[[2]], u))
    den <- eval(s$denominador[[2]], u)
    if (is.factor(den)) den <- as.integer(den) == 1L   # svyratio usa o 1º nível
    den <- as.numeric(den)
    fora <- !is.na(num) & num != 0 & !is.na(den) & den == 0
    expect_false(any(fora), info = s$id)
  }
})

test_that("Proporcao_Ocupados_Escolarizados é a proporção entre os ocupados", {
  # Regressão: o numerador contava desocupados com médio completo.
  s <- Filter(function(s) s$id == "Proporcao_Ocupados_Escolarizados", catalogo_indicadores)[[1]]
  est <- coef(computar_estimativa(d, s, NULL))
  esperado <- sum(w * (v$medio_completo_ou_mais == 1 & v$ocup == 1)) / sum(w * v$ocup)
  expect_equal(unname(est), esperado)
  expect_lte(unname(est), 1)
})

test_that("Proporcao_Populacao_14_59 usa a população de todas as idades como base", {
  s <- Filter(function(s) s$id == "Proporcao_Populacao_14_59", catalogo_indicadores)[[1]]
  est <- coef(computar_estimativa(d, s, NULL))
  esperado <- sum(w * (v$V2009 >= 14 & v$V2009 <= 59)) / sum(w)
  expect_equal(unname(est), esperado)
  expect_lt(unname(est), 1)   # a população de teste tem criança e idoso
})

# ---- Subconjuntos -----------------------------------------------------------

test_that("aplicar_subset() descarta NA e devolve o desenho intacto com NULL", {
  expect_identical(nrow(aplicar_subset(d, NULL)), nrow(d))
  sub <- aplicar_subset(d, ~VD4002 == "Pessoas ocupadas")
  expect_equal(nrow(sub), sum(v$ocup))          # VD4002 NA fora da FT não entra
  expect_true(all(sub$variables$ocup == 1))
})

test_that("aplicar_subset_denominador(): 0/1 numérico, lógico e fator", {
  expect_identical(nrow(aplicar_subset_denominador(d, ~ft_ou_desalentada)),
                   sum(v$ft_ou_desalentada == 1))
  expect_identical(nrow(aplicar_subset_denominador(d, ~V2009 >= 14 & V2009 <= 29)),
                   sum(v$V2009 >= 14 & v$V2009 <= 29))
  expect_identical(nrow(aplicar_subset_denominador(d, ~VD4003)),
                   sum(!is.na(v$VD4003)))
})

# ---- Estimação --------------------------------------------------------------

spec_de <- function(id) Filter(function(s) s$id == id, catalogo_indicadores)[[1]]

test_that("razão sai do desenho: ponto e SE batem com o bootstrap feito à mão", {
  r <- computar_estimativa(d, spec_de("Taxa_Desocupacao"), NULL)
  mao <- razao_replicada(d, v$desocup, v$ft)
  expect_equal(unname(coef(r)), mao$ponto)
  expect_equal(unname(SE(r)), mao$se)
  expect_gt(mao$se, 0)
  # sem peso daria outro número: o motor não pode estar usando média crua
  expect_false(isTRUE(all.equal(mao$ponto, sum(v$desocup) / sum(v$ft))))
})

test_that("total é a soma ponderada", {
  r <- computar_estimativa(d, spec_de("Pessoas_Ocupadas"), NULL)
  expect_equal(unname(coef(r)), sum(w * v$ocup))
})

test_that("média respeita o subset da spec", {
  r <- computar_estimativa(d, spec_de("Rendimento_Formal"), NULL)
  f <- !is.na(v$informal) & v$informal == 0 & !is.na(v$VD4019_real)
  expect_equal(unname(coef(r)), sum((w * v$VD4019_real)[f]) / sum(w[f]))
})

test_that("com recorte, a razão é calculada dentro de cada grupo", {
  r <- computar_estimativa(d, spec_de("Taxa_Desocupacao"), ~Sexo)
  for (g in c("Masculino", "Feminino")) {
    no_g <- v$Sexo == g
    expect_equal(unname(coef(r)[g]),
                 sum((w * v$desocup)[no_g]) / sum((w * v$ft)[no_g]), info = g)
  }
})

test_that("subset vazio devolve NULL", {
  s <- list(id = "x", formula = ~ocup, fun = svytotal, subset = ~V2009 > 200)
  expect_null(computar_estimativa(d, s, NULL))
})

test_that("extrair_resultados() sem recorte: uma linha, Total", {
  r <- computar_estimativa(d, spec_de("Pessoas_Ocupadas"), NULL)
  out <- extrair_resultados(r, "Pessoas_Ocupadas", tem_by = FALSE)
  expect_identical(nrow(out), 1L)
  expect_identical(out$Categoria_Demografica, "Total")
  expect_equal(out$Estimativa, unname(coef(r)))
  expect_equal(out$SE, unname(SE(r)))
})

test_that("extrair_resultados() com fator: uma linha por nível", {
  s <- spec_de("Distribuicao_PIT_por_Sexo")
  out <- extrair_resultados(computar_estimativa(d, s, NULL), s$id, tem_by = FALSE)
  expect_identical(out$Subcategoria_Indicador, c("Sexo_pitMasculino", "Sexo_pitFeminino"))
  expect_equal(sum(out$Estimativa), 1)
})

test_that("extrair_resultados() com recorte: grupos x níveis, SE no lugar certo", {
  s <- spec_de("Distribuicao_PIT_por_Faixa_Etaria_Projeto")
  r <- computar_estimativa(d, s, ~Sexo)
  out <- extrair_resultados(r, s$id, tem_by = TRUE)
  expect_identical(nrow(out), 2L * 3L)
  expect_setequal(out$Categoria_Demografica, c("Masculino", "Feminino"))
  # dentro de cada sexo, a distribuição soma 1
  somas <- tapply(out$Estimativa, out$Categoria_Demografica, sum)
  expect_equal(as.numeric(somas), c(1, 1))
  expect_equal(sort(out$SE), sort(unlist(SE(r), use.names = FALSE)))
})

# ---- Razão formal/informal --------------------------------------------------

test_that("calcular_desigualdade(): razão das médias, IC no log e CV = SE do log", {
  res <- calcular_desigualdade(d)
  ocup <- v$ocup == 1 & !is.na(v$informal) & !is.na(v$VD4019_real)
  media <- function(f) sum((w * v$VD4019_real)[ocup & f]) / sum(w[ocup & f])
  expect_equal(res$rendimento_formal,   media(v$informal == 0))
  expect_equal(res$rendimento_informal, media(v$informal == 1))
  expect_equal(res$razao, res$rendimento_formal / res$rendimento_informal)
  expect_equal(res$cv, 100 * res$ep_log)
  expect_equal(res$ep_razao, res$razao * res$ep_log)
  expect_true(res$ic_inf < res$razao && res$razao < res$ic_sup)
  # assimétrico na escala da razão: o lado de cima é mais largo
  expect_gt(res$ic_sup - res$razao, res$razao - res$ic_inf)
})

test_that("calcular_desigualdade() devolve NULL sem um dos grupos", {
  so_formais <- aplicar_subset(d, ~is.na(informal) | informal == 0)
  expect_null(calcular_desigualdade(so_formais))
})

# ---- Geografias -------------------------------------------------------------

test_that("montar_geografias() monta os recortes do Piauí e respeita as opções", {
  g <- montar_geografias(d)
  expect_true(all(c("Brasil", "Nordeste", "Piauí", "Teresina", "Zona_Urbana",
                    "Zona_Rural", "Agreg_Teresina", "Situacao_Rural",
                    "Micro_2210011") %in% names(g)))
  expect_identical(nrow(g$Brasil), nrow(d))
  expect_true(all(g$Piauí$variables$UF == "Piauí"))
  expect_true(all(g$Teresina$variables$Estrato_agregado == "Teresina"))
  expect_false(any(grepl("São Paulo", names(g))))

  g2 <- montar_geografias(d, incluir_brasil_nordeste = FALSE, incluir_micro = FALSE)
  expect_false(any(c("Brasil", "Nordeste") %in% names(g2)))
  expect_false(any(startsWith(names(g2), "Micro_")))
})

# ---- Estimação de um trimestre ---------------------------------------------

res <- estimar_trimestre(montar_geografias(d, incluir_micro = FALSE),
                         GEO_AGREGADAS, 2026, 2)
b <- res$base

test_that("estimar_trimestre() devolve a base no esquema da base_", {
  expect_named(b, c("Indicador", "Subcategoria_Indicador", "Estimativa", "SE",
                    "Ano", "Trimestre", "Regiao_Geografica",
                    "Recorte_Demografico", "Categoria_Demografica"))
  expect_true(all(b$Ano == 2026 & b$Trimestre == 2))
})

test_that("geografias agregadas só saem no recorte Total", {
  expect_true(all(b$Recorte_Demografico[b$Regiao_Geografica %in% GEO_AGREGADAS] == "Total"))
  expect_true(any(b$Recorte_Demografico[b$Regiao_Geografica == "Zona_Rural"] == "Sexo"))
})

test_that("so_recorte_total e geografias da spec são respeitados", {
  so_total <- vapply(Filter(function(s) isTRUE(s$so_recorte_total), catalogo_indicadores),
                     `[[`, "", "id")
  expect_true(all(b$Recorte_Demografico[b$Indicador %in% so_total] == "Total"))
  motivos <- b$Regiao_Geografica[b$Indicador == "Motivo_Nao_Procura_NemNem"]
  expect_setequal(unique(motivos), c("Brasil", "Nordeste", "Piauí"))
})

test_that("indicador que falha vira registro em falhas, sem parar o resto", {
  quebrado <- list(id = "Quebrado", formula = ~variavel_inexistente, fun = svymean)
  ok       <- spec_de("Pessoas_Ocupadas")
  r <- estimar_trimestre(list(Piauí = d), "Piauí", 2026, 2,
                         catalogo = list(quebrado, ok), incluir_desigualdade = FALSE)
  expect_identical(unique(r$base$Indicador), "Pessoas_Ocupadas")
  falhas <- dplyr::bind_rows(r$falhas)
  expect_identical(falhas$Indicador, "Quebrado")
  expect_identical(falhas$Regiao_Geografica, "Piauí")
})

test_that("razão formal/informal entra na base com SE = ep_razao", {
  des <- b[b$Indicador == "Desigualdade_Formal_Informal", ]
  expect_setequal(des$Regiao_Geografica, res$desigualdade$Regiao_Geografica)
  pi <- res$desigualdade[res$desigualdade$Regiao_Geografica == "Piauí", ]
  expect_equal(des$Estimativa[des$Regiao_Geografica == "Piauí"], pi$razao)
  expect_equal(des$SE[des$Regiao_Geografica == "Piauí"], pi$ep_razao)
})
