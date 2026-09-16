# ==============================================================================
# indicadores.R — catálogo de indicadores e motor de estimação.
#
# Tirado do 01_pipeline_trimestral.R (antigas §3 e §5) para que o pipeline e a
# validação contra o SIDRA (scripts_teste/validacao_sidra.R) usem exatamente as
# mesmas fórmulas. Depende das colunas criadas por R/derivar_variaveis.R.
#
# Campos de cada spec:
#   id               nome do indicador
#   formula          variável (ou expressão) estimada
#   denominador      só para svyratio
#   fun              svymean | svyratio | svytotal | convey::svygini
#   subset           universo, aplicado antes de estimar (NULL = todos)
#   so_recorte_total TRUE = não cruza com recortes demográficos
#   testar           FALSE = fica fora das baterias de teste de significância
#
# Totais saem em PESSOAS (o SIDRA publica em mil pessoas; a conversão fica
# para a exibição). Todos passam pelo desenho replicado — SE e CV incluídos.
# ==============================================================================

library(survey)
library(dplyr)
library(purrr)
library(tibble)

# ---- Catálogo -----------------------------------------------------------------

catalogo_original <- list(
  # Reescrita sobre as variáveis 0/1 (antes: ~VD4002 == ... / ~VD4001 == ...).
  # Mesmo número — conferido na validação —, mas sem depender de NA + na.rm.
  list(id = "Taxa_Desocupacao",
       formula = ~desocup, denominador = ~ft,
       fun = svyratio, subset = NULL),

  list(id = "Chefes_Familia_Desocupados",
       formula = ~VD2002 == "Pessoa responsável",
       denominador = ~VD4002 == "Pessoas desocupadas",
       fun = svyratio, subset = ~VD4002 == "Pessoas desocupadas"),

  list(id = "Conribuintes_Desocupados",
       formula = ~contribuinte_renda_domicilio,
       denominador = ~VD4002 == "Pessoas desocupadas",
       fun = svyratio, subset = ~VD4002 == "Pessoas desocupadas"),

  list(id = "Rendimento_Medio_Habitual",
       formula = ~VD4019_real, denominador = NULL, fun = svymean, subset = NULL),

  list(id = "Percentual_Subremuneracao",
       formula = ~subremuneracao, denominador = NULL, fun = svymean, subset = NULL),

  list(id = "Rendimento_Formal",
       formula = ~VD4019_real, denominador = NULL, fun = svymean,
       subset = ~!is.na(informal) & informal == 0,
       so_recorte_total = TRUE),

  list(id = "Rendimento_Informal",
       formula = ~VD4019_real, denominador = NULL, fun = svymean,
       subset = ~!is.na(informal) & informal == 1,
       so_recorte_total = TRUE),

  list(id = "Taxa_Informalidade",
       formula = ~informal, denominador = ~VD4002 == "Pessoas ocupadas",
       fun = svyratio, subset = NULL),

  list(id = "Taxa_Subocupacao",
       formula = ~(!is.na(VD4004A) & VD4004A == "Pessoas subocupadas"),
       denominador = ~VD4002 == "Pessoas ocupadas", fun = svyratio, subset = NULL),

  list(id = "Proporcao_Ocupados_Escolarizados",
       formula = ~(!is.na(medio_completo_ou_mais) & medio_completo_ou_mais == 1),
       denominador = ~VD4002 == "Pessoas ocupadas", fun = svyratio, subset = NULL),

  list(id = "Desalentados_Forca_Ampliada",
       formula = ~(!is.na(VD4005) & VD4005 == "Pessoas desalentadas"),
       denominador = ~ft_ou_desalentada, fun = svyratio, subset = NULL),

  list(id = "Desalentados_Fora_Forca",
       formula = ~(!is.na(VD4005) & VD4005 == "Pessoas desalentadas"),
       denominador = ~VD4003, fun = svyratio, subset = NULL),

  list(id = "Motivo_Desistencia_Desalentado",
       formula = ~V4074A, denominador = NULL, fun = svymean,
       subset = ~VD4005 == "Pessoas desalentadas"),

  list(id = "Taxa_Nem_Nem",
       formula = ~nem_nem, denominador = ~(V2009 >= 14 & V2009 <= 29),
       fun = svyratio, subset = NULL),

  list(id = "Motivo_Nao_Procura_NemNem",
       formula = ~VD4030, denominador = NULL, fun = svymean, subset = ~nem_nem == 1),

  list(id = "Motivo_Nao_Inicio_NemNem",
       formula = ~V4078A, denominador = NULL, fun = svymean, subset = ~nem_nem == 1)
)

# Mercado de trabalho (set/2026). Definições e fontes em R/derivar_variaveis.R
# e no anexo metodológico.
catalogo_mercado_trabalho <- list(
  # Contagens (SIDRA 4093/4097/5434/4100)
  list(id = "Pessoas_Idade_Trabalhar",   formula = ~pit,         fun = svytotal, testar = FALSE),
  list(id = "Pessoas_Forca_Trabalho",    formula = ~ft,          fun = svytotal, testar = FALSE),
  list(id = "Pessoas_Fora_Forca",        formula = ~fora_ft,     fun = svytotal, testar = FALSE),
  list(id = "Pessoas_Ocupadas",          formula = ~ocup,        fun = svytotal, testar = FALSE),
  list(id = "Empregados_Setor_Privado",  formula = ~emp_privado, fun = svytotal, testar = FALSE),
  list(id = "Empregados_Setor_Publico",  formula = ~emp_publico, fun = svytotal, testar = FALSE),
  list(id = "Ocupados_Agropecuaria",     formula = ~ocup_agro,   fun = svytotal, testar = FALSE),
  list(id = "Pessoas_Desocupadas",       formula = ~desocup,     fun = svytotal, testar = FALSE),
  list(id = "Pessoas_Subutilizadas",     formula = ~subutil,     fun = svytotal, testar = FALSE),

  # Taxas (SIDRA 4093/4099)
  list(id = "Nivel_Ocupacao",              formula = ~ocup,    denominador = ~pit,         fun = svyratio),
  list(id = "Taxa_Participacao",           formula = ~ft,      denominador = ~pit,         fun = svyratio),
  list(id = "Taxa_Composta_Subutilizacao", formula = ~subutil, denominador = ~ft_ampliada, fun = svyratio),

  # Desigualdade: ocupados com rendimento habitual positivo. Nominal de
  # propósito — o Gini é invariante à escala, e o deflator é uma constante
  # por trimestre.
  # convey::svygini — Gini ponderado com variância pelas réplicas do desenho
  # (OSIER, 2009; PESSOA et al., pacote convey).
  list(id = "Gini_Rendimento_Habitual_Trabalho", formula = ~VD4019, fun = convey::svygini,
       subset = ~ocup == 1 & !is.na(VD4019) & VD4019 > 0, testar = FALSE)
)

# Composição da PIT: um total (mil pessoas) e uma distribuição (%) por
# dimensão. Só no recorte Total — cruzar sexo por sexo é degenerado.
dimensoes_pit <- c(Sexo = "Sexo_pit", Raca = "Raca_pit",
                   Faixa_Etaria_SIDRA = "Faixa_Etaria_sidra",
                   Faixa_Etaria_Projeto = "Faixa_Etaria_projeto",
                   Instrucao_SIDRA = "Instrucao_sidra",
                   Instrucao_Projeto = "Instrucao_projeto")

catalogo_composicao_pit <- unlist(lapply(names(dimensoes_pit), function(nm) {
  f <- as.formula(paste0("~", dimensoes_pit[[nm]]))
  list(
    list(id = paste0("PIT_por_", nm), formula = f, fun = svytotal,
         subset = ~pit == 1, so_recorte_total = TRUE, testar = FALSE),
    list(id = paste0("Distribuicao_PIT_por_", nm), formula = f, fun = svymean,
         subset = ~pit == 1, so_recorte_total = TRUE, testar = FALSE)
  )
}), recursive = FALSE)

catalogo_indicadores <- c(catalogo_original, catalogo_mercado_trabalho,
                          catalogo_composicao_pit)

recortes_demograficos <- list(
  Total                  = NULL,
  Sexo                   = ~Sexo,
  Raca                   = ~Raca,
  Faixa_Etaria_trabalho  = ~Faixa_Etaria_trabalho,
  Instrucao_agregado     = ~Instrucao,
  Instrucao              = ~VD3004
)

# ---- Motor ---------------------------------------------------------------------

aplicar_subset <- function(design, condicao) {
  if (is.null(condicao)) return(design)
  idx <- as.logical(eval(condicao[[2]], envir = design$variables))
  idx[is.na(idx)] <- FALSE
  design[idx, ]
}

# Universo do denominador de uma razão (usado nos testes de significância).
# Numérico conta como indicador 0/1: entra quem tem valor diferente de zero.
# Antes todo numérico não-NA entrava, o que fazia ~ft_ou_desalentada (0/1)
# selecionar a amostra inteira.
aplicar_subset_denominador <- function(design, condicao) {
  if (is.null(condicao)) return(design)
  valor <- eval(condicao[[2]], envir = design$variables)
  idx <- if (is.logical(valor)) {
    valor
  } else if (is.numeric(valor)) {
    !is.na(valor) & valor != 0
  } else {
    !is.na(valor)
  }
  idx[is.na(idx)] <- FALSE
  design[idx, ]
}

computar_estimativa <- function(design, spec, by_formula) {
  design_usar <- aplicar_subset(design, spec$subset)
  if (nrow(design_usar) == 0) return(NULL)

  argumentos <- list(spec$formula, design = design_usar, na.rm = TRUE)
  if (identical(spec$fun, svyratio)) argumentos$denominator <- spec$denominador

  if (is.null(by_formula)) {
    do.call(spec$fun, argumentos)
  } else {
    argumentos <- c(list(formula = spec$formula), argumentos[-1], list(by = by_formula, FUN = spec$fun))
    do.call(svyby, argumentos)
  }
}

extrair_resultados <- function(resultado, ind_nome, tem_by) {

  if (!tem_by) {
    est <- coef(resultado)
    se  <- SE(resultado)
    nomes <- names(est)
    if (is.null(nomes) || all(nomes == "")) nomes <- ind_nome
    return(tibble(
      Indicador = ind_nome, Subcategoria_Indicador = nomes,
      Estimativa = as.numeric(est), SE = as.numeric(se),
      Categoria_Demografica = "Total"
    ))
  }

  df <- as.data.frame(resultado)
  rownames(df) <- NULL
  df <- df %>% rename(Categoria_Demografica = 1)
  df$Categoria_Demografica <- as.character(df$Categoria_Demografica)

  resto <- df %>% select(-Categoria_Demografica)
  k <- ncol(resto) / 2
  stopifnot(k == floor(k))
  est_cols <- names(resto)[seq_len(k)]
  se_cols  <- names(resto)[(k + 1):(2 * k)]

  map_dfr(seq_len(k), function(j) {
    df %>%
      transmute(
        Indicador = ind_nome, Subcategoria_Indicador = est_cols[j],
        Estimativa = .data[[est_cols[j]]], SE = .data[[se_cols[j]]],
        Categoria_Demografica
      )
  })
}
