# ==============================================================================
# relatorio_modelo.R — módulo (carregado via source()) com a parte do
# R/09_preencher_relatorio.R que não depende dos dados do trimestre:
# formatação de números/marcas e o interpretador do modelo
# (output/relatorio_trimestral.md). A sintaxe do modelo está documentada no
# próprio modelo (bloco @somente-modelo):
#   <!-- @somente-modelo --> ... <!-- /@somente-modelo -->  some da saída
#   <!-- @redigir: texto -->            vira "> **A REDIGIR** — texto"
#   <!-- @tabela tipo=... chave=... --> vira a tabela gerada pelo 09
#   {{#se-... args}} ... {{/se}}        condicional
#   {{expressao args}}                  valor do vocabulário do 09
#   \{\{                                "{{" literal
#
# O que depende dos dados (teste_reg(), o VOCABULARIO, os geradores de tabela)
# fica no 09 e entra aqui como argumento. Depende de R/precisao.R
# (classificar_cv(), LIMITES_CV). Testado em tests/testthat/test-relatorio_modelo.R.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(purrr)
})

# ---- Formatação ----------------------------------------------------------------

num <- function(x, casas = 1) {
  ifelse(is.na(x), "—", formatC(x, format = "f", digits = casas, big.mark = ".", decimal.mark = ","))
}

# Valor na unidade de exibição (sem símbolo) e com símbolo.
escala <- function(x, u) switch(u, pct = 100 * x, mil = x / 1000, x)
casas_de <- function(u) switch(u, pct = 1, mil = 0, reais = 0, razao = 2, gini = 3)
formatar <- function(x, u) {
  v <- num(escala(x, u), casas_de(u))
  if (u == "reais") paste0("R$ ", v) else v
}
unidade_rotulo <- function(u) switch(u, pct = "%", mil = "mil pessoas", reais = "R$", razao = "razão", gini = "índice")
com_unidade    <- function(rotulo, u) if (u %in% c("razao", "gini")) rotulo else paste0(rotulo, " (", unidade_rotulo(u), ")")

classe_cv <- function(cv) ifelse(is.na(cv), "—", classificar_cv(cv))

# Marca pelo CV (ou p80 do CV): abaixo do corte do IBGE vale o número, até o
# limite de "regular" leva †, acima some. Limites em R/precisao.R.
marca_pelo_cv <- function(cv) {
  if (cv < LIMITES_CV[["boa"]]) "ok" else if (cv < LIMITES_CV[["regular"]]) "adaga" else "traco"
}

estrelas <- function(p) {
  case_when(is.na(p) ~ "—", p < 0.001 ~ "\\*\\*\\*", p < 0.01 ~ "\\*\\*", p < 0.05 ~ "\\*", TRUE ~ "ns")
}

linha_md <- function(...) paste0("| ", paste(c(...), collapse = " | "), " |")

# Rótulo legível de uma categoria: tira o nome da variável colado na frente.
PREFIXOS_CATEGORIA <- "^(Sexo_pit|Raca_pit|Faixa_Etaria_sidra|Faixa_Etaria_projeto|Instrucao_sidra|Instrucao_projeto|motivo_[a-z_]+?_grupo)"
rotulo_categoria <- function(sub) str_remove(sub, PREFIXOS_CATEGORIA)

# ---- Interpretador ---------------------------------------------------------------

remover_somente_modelo <- function(linhas) {
  ini <- which(str_detect(linhas, fixed("<!-- @somente-modelo -->")))
  fim <- which(str_detect(linhas, fixed("<!-- /@somente-modelo -->")))
  if (length(ini) == 0) return(linhas)
  if (length(ini) != 1 || length(fim) != 1 || fim < ini) stop("Marcadores @somente-modelo malformados no modelo.")
  linhas[-(ini:fim)]
}

# Devolve as linhas com o atributo "redacoes" (os textos pedidos, em ordem).
resolver_redigir <- function(linhas) {
  d <- str_match(linhas, "^\\s*<!--\\s*@redigir:\\s*(.*?)\\s*-->\\s*$")
  achou <- !is.na(d[, 1])
  saida <- ifelse(achou, paste0("> **A REDIGIR** — ", d[, 2]), linhas)
  attr(saida, "redacoes") <- d[achou, 2]
  saida
}

# Argumentos de uma diretiva <!-- @tabela chave=valor ... -->, ou NULL.
ler_diretiva_tabela <- function(linha) {
  d <- str_match(linha, "^\\s*<!--\\s*@tabela\\s+(.*?)\\s*-->\\s*$")
  if (is.na(d[1])) return(NULL)
  pares <- str_match_all(d[2], "([a-z]+)=(\\S+)")[[1]]
  setNames(pares[, 3], pares[, 2])
}

# Troca cada diretiva @tabela pelas linhas de gerar_tabela(argumentos).
resolver_tabelas <- function(linhas, gerar_tabela) {
  unlist(lapply(linhas, function(l) {
    arg <- ler_diretiva_tabela(l)
    if (is.null(arg)) l else gerar_tabela(arg)
  }), use.names = FALSE)
}

# Condicionais {{#tipo args}} corpo {{/se}} (não aninhados). teste_reg(ind,
# recorte) devolve a linha do teste (com p_ajustado) ou NULL.
resolver_condicionais <- function(txt, teste_reg, incluir_situacao) {
  padrao <- regex("\\{\\{#(se-significativo|se-nao-significativo|se-existe|se-situacao|se-nao-situacao)(?:\\s+([^\\}]+?))?\\}\\}(.*?)\\{\\{/se\\}\\}",
                  dotall = TRUE)
  while (str_detect(txt, padrao)) {
    m <- str_match(txt, padrao)
    tipo <- m[2]; args <- str_split(str_trim(m[3]), "\\s+")[[1]]; corpo <- m[4]
    manter <- switch(tipo,
      "se-situacao"          = incluir_situacao,
      "se-nao-situacao"      = !incluir_situacao,
      "se-significativo"     = { r <- teste_reg(args[1], args[2]); !is.null(r) && r$p_ajustado < 0.05 },
      "se-nao-significativo" = { r <- teste_reg(args[1], args[2]); !is.null(r) && r$p_ajustado >= 0.05 },
      "se-existe"            = !is.null(teste_reg(args[1], args[2])))
    txt <- str_replace(txt, padrao, if (manter) corpo else "")
  }
  txt
}

# \{\{ no modelo atravessa o interpretador como texto literal. O marcador usa
# caracteres de controle para não colidir com texto real (antes era "LIT", que
# viraria "{{" se aparecesse no relatório).
MARCADOR_LITERAL <- "\001LIT\001"
proteger_literais  <- function(txt) str_replace_all(txt, "\\\\\\{\\\\\\{", MARCADOR_LITERAL)
restaurar_literais <- function(txt) str_replace_all(txt, fixed(MARCADOR_LITERAL), "{{")

# vapply(): str_replace_all() com função chama uma vez por ocorrência em
# versões antigas do stringr e uma vez para todas nas novas; assim funciona nas duas.
resolver_expressoes <- function(txt, vocabulario) {
  resolver_uma <- function(inteiro) {
    m <- str_match(inteiro, "\\{\\{([a-z_]+)([^\\}]*)\\}\\}")
    args <- str_split(str_trim(m[1, 3]), "\\s+")[[1]]
    args <- args[nzchar(args)]
    fn <- vocabulario[[m[1, 2]]]
    if (is.null(fn)) stop("Expressão desconhecida no modelo: {{", m[1, 2], " ...}}")
    do.call(fn, as.list(args))
  }
  str_replace_all(txt, "\\{\\{([a-z_]+)([^\\}]*)\\}\\}",
                  function(inteiros) vapply(inteiros, resolver_uma, character(1), USE.NAMES = FALSE))
}

# Marcadores que sobraram sem resolver ({{...}} ou {PLACEHOLDER} antigo).
marcadores_nao_resolvidos <- function(txt) {
  str_extract_all(txt, "\\{\\{[^\\}]*\\}\\}|\\{[A-Z_]{2,}[^\\}]*\\}")[[1]]
}

# Acabamento depois da verificação: "—%" vira "—", "$" escapado (o pandoc lê
# "$" como início de fórmula; "R$" sem escape engole tabelas inteiras) e os
# literais \{\{ / \}\} voltam a ser {{ / }}.
finalizar_texto <- function(txt) {
  txt <- str_replace_all(txt, "—%", "—")
  txt <- str_replace_all(txt, "\\$", "\\\\$")
  txt <- restaurar_literais(txt)
  str_replace_all(txt, "\\\\\\}\\\\\\}", "}}")
}

# Pipeline completo do modelo (linhas) ao texto final. Para com erro se
# sobrar marcador. Devolve o texto com o atributo "redacoes".
preencher_modelo <- function(linhas, gerar_tabela, teste_reg, vocabulario, incluir_situacao) {
  linhas <- remover_somente_modelo(linhas)
  linhas <- resolver_redigir(linhas)
  redacoes <- attr(linhas, "redacoes")
  linhas <- resolver_tabelas(linhas, gerar_tabela)
  texto  <- paste(linhas, collapse = "\n")
  texto  <- proteger_literais(texto)
  texto  <- resolver_condicionais(texto, teste_reg, incluir_situacao)
  texto  <- resolver_expressoes(texto, vocabulario)

  sobraram <- marcadores_nao_resolvidos(texto)
  if (length(sobraram) > 0) {
    message("\nMARCADORES NÃO RESOLVIDOS (", length(sobraram), "):")
    for (s in unique(sobraram)) message("  ", str_trunc(s, 100), "   (", sum(sobraram == s), "x)")
    stop("O relatório não foi gravado. Corrija o modelo ou o vocabulário e rode de novo.")
  }
  texto <- finalizar_texto(texto)
  attr(texto, "redacoes") <- redacoes
  texto
}
