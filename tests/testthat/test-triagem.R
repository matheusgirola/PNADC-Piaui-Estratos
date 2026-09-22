# Testes de R/triagem.R (lógica do R/11_triagem_confiabilidade.R) sobre série
# sintética de CVs. Rodar da raiz do projeto: testthat::test_dir("tests/testthat")

source(test_path("..", "..", "R", "precisao.R"), encoding = "UTF-8")
source(test_path("..", "..", "R", "triagem.R"), encoding = "UTF-8")

TODOS <- seq(idx_tri(2016, 2), idx_tri(2026, 2))   # 41 trimestres

# Série com uma linha por chave x trimestre; `cv` é o vetor de CVs (NA = sem linha).
serie_sintetica <- function(regiao, cv, indicador = "Taxa_X") {
  tibble(Indicador = indicador, Subcategoria_Indicador = "Total",
         Regiao_Geografica = regiao, Recorte_Demografico = "Total",
         Categoria_Demografica = "Total", idx = TODOS, CV = cv) %>%
    filter(!is.na(CV))
}

test_that("índice de trimestre é contínuo e volta ao rótulo", {
  expect_identical(idx_tri(2021, 1) - idx_tri(2020, 4), 1)
  expect_identical(rotulo_idx(idx_tri(c(2016, 2026), c(2, 4))), c("2016T2", "2026T4"))
  expect_identical(trimestres_faltando(TODOS[-c(3, 10)]), TODOS[c(3, 10)])
  expect_length(trimestres_faltando(TODOS), 0)
})

test_that("amostragem espaçada conta de 5 em 5 a partir do mais recente", {
  esp <- trimestres_espacados(TODOS)
  expect_identical(max(esp), max(TODOS))
  expect_true(all(diff(esp) == 5))
  expect_length(esp, 9)                    # 41 trimestres: 0, 5, ..., 40
})

test_that("janelas: principal a partir de 2022T1, sem_pandemia tira 2020T2-2021T4", {
  j <- definir_janelas(TODOS)
  expect_equal(min(j$principal), idx_tri(2022, 1))
  expect_identical(j$serie_toda, TODOS)
  expect_length(setdiff(TODOS, j$sem_pandemia), 7)
  expect_false(any(j$sem_pandemia %in% idx_tri(2020, 2):idx_tri(2021, 4)))
})

test_that("resumir(): sem estimativa entra no denominador, não na mediana", {
  r <- resumir(c(2, 10, 20, 40, NA))
  expect_identical(r$n_trimestres, 5L)
  expect_identical(r$n_com_estimativa, 4L)
  expect_equal(r$cv_mediano, 15)
  expect_equal(r$cv_max, 40)
  expect_equal(c(r$pct_excelente, r$pct_boa, r$pct_regular, r$pct_baixa, r$pct_sem_estimativa),
               c(20, 20, 20, 20, 20))
})

test_that("resumir() de chave sem nenhuma estimativa dá NA, sem erro", {
  r <- resumir(c(NA_real_, NA_real_))
  expect_true(is.na(r$cv_mediano) && is.na(r$cv_p80) && is.na(r$cv_max))
  expect_equal(r$pct_sem_estimativa, 100)
})

test_that("critérios: limites exatos de 80% e CV 15; instável exige crit_b e CV recente >= 30", {
  tab <- tibble(pct_excelente = c(40, 40, 0, 0), pct_boa = c(40, 39.9, 100, 100),
                cv_mediano = c(14.9, 15, 10, 10), cv_p80 = c(15, 14.9, 10, 10),
                cv_max_recentes = c(30, 50, 29.9, NA))
  r <- aplicar_criterios(tab)
  expect_identical(r$crit_a, c(TRUE, FALSE, TRUE, TRUE))
  expect_identical(r$crit_b, c(TRUE, FALSE, TRUE, TRUE))
  expect_identical(r$crit_c, c(FALSE, TRUE, TRUE, TRUE))
  expect_identical(r$instavel, c(TRUE, FALSE, FALSE, FALSE))
})

test_that("nivel_geografico() classifica pelos prefixos", {
  expect_identical(
    nivel_geografico(c("Piauí", "Zona_Rural", "Situacao_Urbana", "Admin_X", "Agreg_Y", "Z"), "Piauí"),
    c("Agregado", "Zona", "Situacao", "Estrato_Admin", "Estrato_Agregado", "Outro"))
})

test_that("triar(): ponta a ponta sobre série sintética", {
  cv_estavel <- rep(10, 41); cv_estavel[41] <- 35          # boa, mas estourou no último
  cv_falho   <- rep(c(10, NA), length.out = 41)            # metade dos trimestres sem linha
  cv_trans   <- ifelse(TODOS >= idx_tri(2025, 3), 20, 10)  # dobra na transição
  serie <- bind_rows(serie_sintetica("Piauí", cv_estavel),
                     serie_sintetica("Agreg_Norte", cv_falho),
                     serie_sintetica("Zona_Rural", cv_trans))
  t <- triar(serie, geografias_agregadas = "Piauí")

  expect_identical(nrow(t), 3L * 3L * 2L)                  # chaves x janelas x amostragens
  p <- filter(t, janela == "principal", amostragem == "todos")
  expect_identical(unique(p$periodo), "2022T1-2026T2")

  pi <- filter(p, Regiao_Geografica == "Piauí")
  expect_identical(pi$Nivel_Geografico, "Agregado")
  expect_true(pi$crit_b && pi$instavel)

  norte <- filter(p, Regiao_Geografica == "Agreg_Norte")
  expect_equal(norte$n_trimestres, 18)                     # grade completa na janela
  expect_lt(norte$n_com_estimativa, norte$n_trimestres)
  expect_false(norte$crit_a)                               # ~50% sem estimativa
  expect_true(norte$crit_b)

  rural <- filter(p, Regiao_Geografica == "Zona_Rural")
  expect_equal(rural$razao_cv_transicao, 2)
  expect_false(rural$instavel)
})
