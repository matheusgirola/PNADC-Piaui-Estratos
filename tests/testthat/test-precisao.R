# Testes de R/precisao.R. Rodar da raiz do projeto: testthat::test_dir("tests/testthat")

source(test_path("..", "..", "R", "precisao.R"), encoding = "UTF-8")

test_that("calcular_cv() é 100 * SE / |estimativa|", {
  expect_equal(calcular_cv(c(0.5, 200, -4), c(0.05, 10, 1)), c(10, 5, 25))
})

test_that("calcular_cv() dá NA com estimativa zero ou faltante, sem Inf/NaN", {
  cv <- calcular_cv(c(0, 0, NA, 10), c(0, 1, 1, NA))
  expect_identical(cv, rep(NA_real_, 4))
})

test_that("classificar_cv() respeita os limites exatos 5, 15 e 30", {
  cv <- c(0, 4.999, 5, 14.999, 15, 29.999, 30, 250, Inf)
  expect_identical(classificar_cv(cv), c(
    "excelente", "excelente", "boa", "boa", "regular", "regular", "baixa", "baixa", "baixa"
  ))
})

test_that("classificar_cv() mantém NA e aceita vetor vazio", {
  expect_identical(classificar_cv(c(NA, 3)), c(NA, "excelente"))
  expect_identical(classificar_cv(numeric(0)), character(0))
})

test_that("classes seguem os LIMITES_CV declarados", {
  expect_identical(classificar_cv(unname(LIMITES_CV) - 1e-9),
                   c("excelente", "boa", "regular"))
  expect_identical(LIMITES_CV[["boa"]], 15)   # corte do IBGE
})

test_that("cv_aceitavel() é CV < 15% e trata NA como não aceitável", {
  expect_identical(cv_aceitavel(c(14.9, 15, NA)), c(TRUE, FALSE, FALSE))
})

test_that("IC 95% usa 1,96 e o piso só corta o limite inferior", {
  expect_equal(ic_inferior(10, 2), 10 - 1.96 * 2)
  expect_equal(ic_superior(10, 2), 10 + 1.96 * 2)
  expect_equal(ic_inferior(c(1, 10), c(1, 1), piso = 0), c(0, 10 - 1.96))
  expect_equal(ic_superior(1, 1), 2.96)
})
