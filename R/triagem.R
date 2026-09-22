# ==============================================================================
# triagem.R — módulo (carregado via source()) com a lógica da triagem de
# confiabilidade do R/11_triagem_confiabilidade.R: janelas, amostragem
# espaçada, resumo do CV por chave e os critérios crit_a/crit_b/crit_c e
# instavel. O 11 só lê a série, chama triar() e grava o CSV. Método e decisões
# no cabeçalho do 11 e em CONTEXTO_PROJETO.md §8.5.
#
# Depende de R/precisao.R (classificar_cv(), cv_aceitavel(), LIMITES_CV),
# carregado por quem usa. Funções puras sobre tibbles — testadas em
# tests/testthat/test-triagem.R com série sintética.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
})

INICIO_PRINCIPAL  <- c(2022, 1)
PANDEMIA          <- list(inicio = c(2020, 2), fim = c(2021, 4))
INICIO_TRANSICAO  <- c(2025, 3)
N_RECENTES        <- 4
PASSO_ESPACADO    <- 5

CHAVES_TRIAGEM <- c("Indicador", "Subcategoria_Indicador", "Regiao_Geografica",
                    "Recorte_Demografico", "Categoria_Demografica")

idx_tri <- function(ano, tri) ano * 4 + (tri - 1)   # índice contínuo de trimestre
idx_de  <- function(v) idx_tri(v[1], v[2])
rotulo_idx <- function(i) sprintf("%dT%d", i %/% 4, i %% 4 + 1)

# Trimestres de 2016T2 até o último que faltam na série (índices).
trimestres_faltando <- function(todos_idx) {
  setdiff(seq(idx_tri(2016, 2), max(todos_idx)), todos_idx)
}

# Grade completa chave x trimestre: trimestre ausente vira linha com CV NA.
montar_grade <- function(serie, todos_idx, chaves = CHAVES_TRIAGEM) {
  serie %>%
    distinct(across(all_of(chaves))) %>%
    cross_join(tibble(idx = todos_idx)) %>%
    left_join(serie %>% select(all_of(chaves), idx, CV), by = c(chaves, "idx"))
}

# Trimestres de PASSO_ESPACADO em PASSO_ESPACADO, contados do mais recente.
trimestres_espacados <- function(todos_idx, passo = PASSO_ESPACADO) {
  todos_idx[(max(todos_idx) - todos_idx) %% passo == 0]
}

na_pandemia <- function(i) i >= idx_de(PANDEMIA$inicio) & i <= idx_de(PANDEMIA$fim)

definir_janelas <- function(todos_idx) {
  list(
    principal    = todos_idx[todos_idx >= idx_de(INICIO_PRINCIPAL)],
    serie_toda   = todos_idx,
    sem_pandemia = todos_idx[!na_pandemia(todos_idx)]
  )
}

definir_amostragens <- function(todos_idx) {
  list(todos = todos_idx, espacado_5 = trimestres_espacados(todos_idx))
}

# Resumo dos CVs de uma chave numa janela. NA = trimestre sem estimativa: entra
# no denominador dos pct_*, não na mediana/p80/máximo.
resumir <- function(cv) {
  n  <- length(cv)
  ok <- cv[!is.na(cv)]
  classe <- classificar_cv(ok)
  tibble(
    n_trimestres       = n,
    n_com_estimativa   = length(ok),
    cv_mediano         = if (length(ok)) median(ok) else NA_real_,
    cv_p80             = if (length(ok)) unname(quantile(ok, 0.8)) else NA_real_,
    cv_max             = if (length(ok)) max(ok) else NA_real_,
    pct_excelente      = 100 * sum(classe == "excelente") / n,
    pct_boa            = 100 * sum(classe == "boa") / n,
    pct_regular        = 100 * sum(classe == "regular") / n,
    pct_baixa          = 100 * sum(classe == "baixa") / n,
    pct_sem_estimativa = 100 * (n - length(ok)) / n
  )
}

# Por chave, independente da janela: CV mediano antes/durante a transição de
# desenho e o CV máximo dos N_RECENTES últimos trimestres.
resumir_por_chave <- function(grade, todos_idx, chaves = CHAVES_TRIAGEM) {
  recentes <- tail(todos_idx, N_RECENTES)
  grade %>%
    group_by(across(all_of(chaves))) %>%
    summarise(
      cv_mediano_pre_transicao = median(CV[idx >= idx_de(INICIO_PRINCIPAL) & idx < idx_de(INICIO_TRANSICAO)], na.rm = TRUE),
      cv_mediano_transicao     = median(CV[idx >= idx_de(INICIO_TRANSICAO)], na.rm = TRUE),
      cv_max_recentes          = suppressWarnings(max(CV[idx %in% recentes], na.rm = TRUE)),
      .groups = "drop"
    ) %>%
    mutate(across(where(is.numeric), ~ ifelse(is.finite(.x), .x, NA_real_)),
           razao_cv_transicao = cv_mediano_transicao / cv_mediano_pre_transicao)
}

nivel_geografico <- function(regiao, geografias_agregadas) {
  case_when(
    regiao %in% geografias_agregadas ~ "Agregado",
    startsWith(regiao, "Zona_")      ~ "Zona",
    startsWith(regiao, "Situacao_")  ~ "Situacao",
    startsWith(regiao, "Admin_")     ~ "Estrato_Admin",
    startsWith(regiao, "Agreg_")     ~ "Estrato_Agregado",
    TRUE ~ "Outro"
  )
}

# (a) >= 80% dos trimestres com CV < 15%; (b) CV mediano < 15%; (c) p80 < 15%;
# instavel: passa em (b) mas teve CV >= 30% em algum trimestre recente.
aplicar_criterios <- function(tab) {
  mutate(tab,
    crit_a   = (pct_excelente + pct_boa) >= 80,
    crit_b   = cv_aceitavel(cv_mediano),
    crit_c   = cv_aceitavel(cv_p80),
    instavel = crit_b & !is.na(cv_max_recentes) & cv_max_recentes >= LIMITES_CV[["regular"]]
  )
}

# Triagem completa. `serie`: base da série com Indicador..Categoria_Demografica,
# idx (idx_tri(Ano, Trimestre)) e CV (calcular_cv()).
triar <- function(serie, geografias_agregadas, chaves = CHAVES_TRIAGEM) {
  todos_idx <- sort(unique(serie$idx))
  grade <- montar_grade(serie, todos_idx, chaves)

  triagem <- imap_dfr(definir_janelas(todos_idx), function(idx_jan, nome_jan) {
    imap_dfr(definir_amostragens(todos_idx), function(idx_amo, nome_amo) {
      usar <- intersect(idx_jan, idx_amo)
      grade %>%
        filter(idx %in% usar) %>%
        group_by(across(all_of(chaves))) %>%
        summarise(resumir(CV), .groups = "drop") %>%
        mutate(janela = nome_jan, amostragem = nome_amo,
               periodo = paste0(rotulo_idx(min(usar)), "-", rotulo_idx(max(usar))),
               .before = 1)
    })
  })

  triagem %>%
    left_join(resumir_por_chave(grade, todos_idx, chaves), by = chaves) %>%
    mutate(Nivel_Geografico = nivel_geografico(Regiao_Geografica, geografias_agregadas)) %>%
    aplicar_criterios() %>%
    relocate(Nivel_Geografico, .after = Regiao_Geografica) %>%
    arrange(Indicador, Subcategoria_Indicador, Nivel_Geografico, Regiao_Geografica,
            Recorte_Demografico, Categoria_Demografica, janela, amostragem)
}
