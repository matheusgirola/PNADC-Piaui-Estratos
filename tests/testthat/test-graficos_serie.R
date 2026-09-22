# Testes de R/graficos_serie.R (dados e rótulos do R/12_graficos_panorama.R).
# Rodar da raiz do projeto: testthat::test_dir("tests/testthat")

source(test_path("..", "..", "R", "precisao.R"), encoding = "UTF-8")
source(test_path("..", "..", "R", "graficos_serie.R"), encoding = "UTF-8")

# INDICADORES_* ficam no 00_config.R, que cria pastas de saída relativas ao
# diretório corrente: carrega num diretório temporário.
config <- new.env()
arq_config <- normalizePath(test_path("..", "..", "R", "00_config.R"))
withr::with_dir(tempdir(), suppressMessages(
  sys.source(arq_config, envir = config, keep.source = FALSE, toplevel.env = config)))

linha <- function(indicador, regiao, estimativa, se = 0.01, ano = 2026, tri = 2, recorte = "Total") {
  tibble(Indicador = indicador, Subcategoria_Indicador = "Total", Regiao_Geografica = regiao,
         Recorte_Demografico = recorte, Categoria_Demografica = "Total",
         Estimativa = estimativa, SE = se, Ano = ano, Trimestre = tri)
}

test_that("todo indicador e território dos gráficos tem rótulo e unidade", {
  expect_true(all(config$INDICADORES_PAINEL %in% config$INDICADORES_GRAFICOS))
  expect_true(all(config$INDICADORES_TERRITORIAIS %in% config$INDICADORES_GRAFICOS))
  expect_true(checar_rotulos_graficos(config$INDICADORES_GRAFICOS))
  expect_true(all(unidade_indicador %in% c("pct", "reais")))
})

test_that("checar_rotulos_graficos() para com indicador sem rótulo", {
  expect_error(checar_rotulos_graficos(c("Taxa_Desocupacao", "Indicador_Novo")), "Indicador_Novo")
  expect_error(checar_rotulos_graficos("Taxa_Desocupacao", c("Piauí", "Agreg_Novo")), "Agreg_Novo")
})

test_that("paleta: uma cor por território, com os rótulos de exibição", {
  pal <- montar_paleta()
  expect_length(pal, length(GEOGRAFIAS))
  expect_setequal(names(pal), unname(nomes_geografias[GEOGRAFIAS]))
  expect_false(anyDuplicated(pal) > 0)
})

test_that("filtrar_base() fica só com o recorte Total dos indicadores/territórios pedidos", {
  base <- bind_rows(linha("Taxa_Desocupacao", "Piauí", 0.1),
                    linha("Taxa_Desocupacao", "Piauí", 0.2, recorte = "Sexo"),
                    linha("Taxa_Desocupacao", "Agreg_Fora", 0.3),
                    linha("Outro", "Piauí", 0.4))
  f <- filtrar_base(base, "Taxa_Desocupacao")
  expect_identical(f$Estimativa, 0.1)
  expect_identical(names(f), c("Indicador", "Estimativa", "SE", "Ano", "Trimestre", "Regiao_Geografica"))
})

test_that("ler_serie() lê o formato do 10 (lista com $base) e o do 13 (só a base)", {
  dir <- withr::local_tempdir()
  saveRDS(list(base = linha("Taxa_Desocupacao", "Piauí", 0.1)), file.path(dir, "pi.rds"))
  saveRDS(linha("Taxa_Desocupacao", "Brasil", 0.07), file.path(dir, "br.rds"))
  s <- ler_serie(file.path(dir, "pi.rds"), file.path(dir, "br.rds"), "Taxa_Desocupacao")
  expect_setequal(s$Regiao_Geografica, c("Piauí", "Brasil"))
})

test_that("preparar_serie(): proporção vira %, reais não; IC 95% e rótulos", {
  s <- preparar_serie(bind_rows(
    linha("Taxa_Desocupacao", "Agreg_Centro-Leste do Piauí", 0.10, se = 0.01, tri = 1),
    linha("Rendimento_Medio_Habitual", "Piauí", 2500, se = 100, tri = 3)))
  d <- s[s$Indicador == "Taxa_Desocupacao", ]
  r <- s[s$Indicador == "Rendimento_Medio_Habitual", ]
  expect_equal(d$Estimativa_disp, 10)
  expect_equal(d$IC_inf_disp, 100 * ic_inferior(0.10, 0.01))
  expect_equal(r$Estimativa_disp, 2500)
  expect_equal(r$IC_sup_disp, ic_superior(2500, 100))
  expect_equal(d$Ano_Trimestre, 2026)
  expect_equal(r$Ano_Trimestre, 2026.5)
  expect_identical(d$Regiao_Nome, "Centro-Leste")
  expect_identical(levels(s$Indicador_Nome), unname(nomes_indicadores))
})

test_that("conferências de completude param com mensagem útil", {
  expect_true(checar_br_ne(c("a/base_2026T2.rds"), c("b/base_2026T2.rds")))
  expect_error(checar_br_ne(c("a/base_2026T1.rds", "a/base_2026T2.rds"), "b/base_2026T2.rds"),
               "base_2026T1.rds.*R/13")
  s <- bind_rows(lapply(GEOGRAFIAS[-10], function(g) linha("Taxa_Nem_Nem", g, 0.2)))
  expect_error(checar_territorios(s, "Taxa_Nem_Nem"), GEOGRAFIAS[10])
  expect_true(checar_territorios(bind_rows(s, linha("Taxa_Nem_Nem", GEOGRAFIAS[10], 0.2)), "Taxa_Nem_Nem"))
})

test_that("formatação do eixo y e da legenda", {
  expect_identical(formatar_eixo_y("pct")(c(10, 12.5)), c("10%", "12.5%"))
  expect_identical(formatar_eixo_y("reais")(2500), "R$ 2.500")
  expect_false(any(nchar(strsplit(quebrar_caption(strrep("palavra ", 60), 50), "\n")[[1]]) > 50))
})
