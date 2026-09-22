# Testes de R/relatorio_modelo.R (formatação e interpretador do modelo do
# R/09_preencher_relatorio.R), com teste_reg/vocabulário/tabelas falsos.
# Rodar da raiz do projeto: testthat::test_dir("tests/testthat")

source(test_path("..", "..", "R", "precisao.R"), encoding = "UTF-8")
source(test_path("..", "..", "R", "relatorio_modelo.R"), encoding = "UTF-8")

# Teste falso: Desocupacao/Sexo significativo, Informalidade/Sexo não, resto ausente.
teste_falso <- function(ind, recorte) {
  p <- c("Taxa_Desocupacao|Sexo" = 0.01, "Taxa_Informalidade|Sexo" = 0.30)[paste0(ind, "|", recorte)]
  if (is.na(p)) NULL else list(p_ajustado = unname(p))
}
vocab_falso <- list(est = function(ind, geo) paste0("[", ind, "@", geo, "]"),
                    vazio = function() "V")

# ---- Formatação ----------------------------------------------------------------

test_that("num() usa vírgula decimal, ponto de milhar e travessão para NA", {
  expect_identical(num(c(1234.567, NA, 0.06), 1), c("1.234,6", "—", "0,1"))
})

test_that("formatar() escala pela unidade", {
  expect_identical(formatar(0.1234, "pct"), "12,3")
  expect_identical(formatar(1234567, "mil"), "1.235")
  expect_identical(formatar(2500.4, "reais"), "R$ 2.500")
  expect_identical(formatar(1.2345, "razao"), "1,23")
  expect_identical(formatar(0.51234, "gini"), "0,512")
  expect_identical(com_unidade("Taxa", "pct"), "Taxa (%)")
  expect_identical(com_unidade("Gini", "gini"), "Gini")
})

test_that("marca_pelo_cv() e estrelas() respeitam os limites exatos", {
  expect_identical(vapply(c(14.99, 15, 29.99, 30), marca_pelo_cv, ""), c("ok", "adaga", "adaga", "traco"))
  expect_identical(estrelas(c(NA, 0.0009, 0.001, 0.049, 0.05)),
                   c("—", "\\*\\*\\*", "\\*\\*", "\\*", "ns"))
  expect_identical(classe_cv(c(NA, 3)), c("—", "excelente"))
})

test_that("rotulo_categoria() tira o prefixo da variável", {
  expect_identical(rotulo_categoria(c("Sexo_pitMulher", "Instrucao_projetoSuperior", "motivo_desistencia_grupoOutro", "Total")),
                   c("Mulher", "Superior", "Outro", "Total"))
  expect_identical(linha_md("a", "b"), "| a | b |")
})

# ---- Interpretador ---------------------------------------------------------------

test_that("@somente-modelo some; marcadores malformados param", {
  l <- c("a", "<!-- @somente-modelo -->", "x", "<!-- /@somente-modelo -->", "b")
  expect_identical(remover_somente_modelo(l), c("a", "b"))
  expect_identical(remover_somente_modelo(c("a", "b")), c("a", "b"))
  expect_error(remover_somente_modelo(c("<!-- /@somente-modelo -->", "<!-- @somente-modelo -->")), "malformados")
})

test_that("@redigir vira aviso e é registrado em ordem", {
  r <- resolver_redigir(c("texto", "  <!-- @redigir: parágrafo 1 -->", "<!-- @redigir: p2 -->"))
  expect_identical(as.vector(r), c("texto", "> **A REDIGIR** — parágrafo 1", "> **A REDIGIR** — p2"))
  expect_identical(attr(r, "redacoes"), c("parágrafo 1", "p2"))
  expect_length(attr(resolver_redigir("nada"), "redacoes"), 0)
})

test_that("@tabela chama o gerador com os argumentos e insere várias linhas", {
  expect_identical(ler_diretiva_tabela("<!-- @tabela tipo=matriz dimensao=mercado -->"),
                   c(tipo = "matriz", dimensao = "mercado"))
  expect_null(ler_diretiva_tabela("<!-- @redigir: x -->"))
  gerar <- function(arg) paste(arg[["tipo"]], c("l1", "l2"))
  expect_identical(resolver_tabelas(c("a", "<!-- @tabela tipo=destaques -->", "b"), gerar),
                   c("a", "destaques l1", "destaques l2", "b"))
})

test_that("condicionais: significância, existência e situação", {
  txt <- paste("{{#se-significativo Taxa_Desocupacao Sexo}}S1{{/se}}",
               "{{#se-significativo Taxa_Informalidade Sexo}}S2{{/se}}",
               "{{#se-nao-significativo Taxa_Informalidade Sexo}}N2{{/se}}",
               "{{#se-nao-significativo Outro Sexo}}N3{{/se}}",
               "{{#se-existe Taxa_Informalidade Sexo}}E2{{/se}}",
               "{{#se-existe Outro Sexo}}E3{{/se}}",
               "{{#se-situacao}}SIT{{/se}}{{#se-nao-situacao}}NSIT{{/se}}")
  expect_identical(resolver_condicionais(txt, teste_falso, incluir_situacao = FALSE),
                   "S1  N2  E2  NSIT")
  expect_match(resolver_condicionais("{{#se-situacao}}\nSIT\n{{/se}}", teste_falso, TRUE), "SIT")
})

test_that("expressões chamam o vocabulário com os argumentos; desconhecida para", {
  expect_identical(resolver_expressoes("a {{est Taxa_X Piauí}} b {{vazio}}", vocab_falso),
                   "a [Taxa_X@Piauí] b V")
  expect_error(resolver_expressoes("{{nao_existe x}}", vocab_falso), "nao_existe")
})

test_that("literais \\{\\{ atravessam o interpretador; LIT no texto não vira {{", {
  txt <- proteger_literais("use \\{\\{est x y\\}\\} no LITORAL")
  expect_identical(resolver_expressoes(txt, vocab_falso), txt)   # não interpreta
  expect_identical(finalizar_texto(txt), "use {{est x y}} no LITORAL")
})

test_that("finalizar_texto() escapa $ e limpa —%", {
  expect_identical(finalizar_texto("R$ 10 e —%"), "R\\$ 10 e —")
})

test_that("preencher_modelo(): ponta a ponta e parada com marcador sobrando", {
  modelo <- c("<!-- @somente-modelo -->", "doc", "<!-- /@somente-modelo -->",
              "# Título", "<!-- @redigir: abertura -->",
              "<!-- @tabela tipo=destaques -->",
              "Valor {{est Taxa_X Piauí}}{{#se-significativo Taxa_Desocupacao Sexo}}, significativo{{/se}}.",
              "R$ total")
  gerar <- function(arg) linha_md("tab", arg[["tipo"]])
  t <- preencher_modelo(modelo, gerar, teste_falso, vocab_falso, incluir_situacao = FALSE)
  expect_identical(as.vector(t), paste(c("# Título", "> **A REDIGIR** — abertura", "| tab | destaques |",
                                         "Valor [Taxa_X@Piauí], significativo.", "R\\$ total"), collapse = "\n"))
  expect_identical(attr(t, "redacoes"), "abertura")
  expect_error(suppressMessages(preencher_modelo(c("{PLACEHOLDER_ANTIGO}"), gerar, teste_falso, vocab_falso, FALSE)),
               "não foi gravado")
})
