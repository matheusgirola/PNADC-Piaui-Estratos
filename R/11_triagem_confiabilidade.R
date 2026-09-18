# ==============================================================================
# 11_triagem_confiabilidade.R — tabela de triagem de confiabilidade a partir da
# série do 10 (dados_saida/serie/base_<ano>T<tri>.rds). CONTEXTO_PROJETO.md
# §8.5, passo 4.
#
# Uma linha por indicador x subcategoria x geografia x recorte demográfico x
# categoria x janela x amostragem. NÃO escolhe critério — calcula as três
# métricas propostas lado a lado para o usuário decidir (passo 5):
#   (a) >= 80% dos trimestres da janela com CV < 15%   (crit_a)
#   (b) CV mediano < 15%                               (crit_b)
#   (c) p80 do CV < 15%                                (crit_c)
#
# CV = 100 * SE / |Estimativa| (o SE vem das 200 réplicas bootstrap do
# desenho). Classes do 03_comparacoes_indicadores.R: Excelente < 5,
# Boa < 15 (corte do IBGE), Regular < 30, Baixa >= 30.
#
# Janelas (decisão do usuário, 17/09/2026):
#   principal    2022T1 até o último trimestre — critério
#   serie_toda   2016T2 em diante — checagem de estabilidade
#   sem_pandemia serie_toda sem 2020T2–2021T4 (coleta por telefone, CV inflado)
# Amostragem:
#   todos        todos os trimestres da janela
#   espacado_5   só trimestres de 5 em 5, contados a partir do mais recente.
#                Painel rotativo 1-2-5: trimestres a 5 de distância não têm
#                domicílio em comum, então os CVs são de amostras disjuntas.
#                Por isso não se faz teste/IC sobre "% de trimestres" com todos.
#
# Trimestre sem estimativa (categoria ausente, falha, estimativa 0) conta no
# denominador dos percentuais como "sem estimativa" — para (a) é um trimestre
# que não atende; mediana e p80 usam só os CVs existentes (ver n_com_estimativa).
#
# Transição de desenho (Censo 2010 -> 2022, 2025T3 a 2026T3): CV mediano antes
# (2022T1–2025T2) e durante (2025T3+), por chave, repetidos em todas as linhas.
# instavel: CV mediano < 15% na janela, mas >= 30% em algum dos últimos
# N_RECENTES trimestres.
#
#   Rscript R/11_triagem_confiabilidade.R
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(purrr)
})

source("R/00_config.R", encoding = "UTF-8")  # geografias_agregadas

INICIO_PRINCIPAL  <- c(2022, 1)
PANDEMIA          <- list(inicio = c(2020, 2), fim = c(2021, 4))
INICIO_TRANSICAO  <- c(2025, 3)
N_RECENTES        <- 4
PASSO_ESPACADO    <- 5

idx_tri <- function(ano, tri) ano * 4 + (tri - 1)   # índice contínuo de trimestre
idx_de  <- function(v) idx_tri(v[1], v[2])

arquivos <- list.files("dados_saida/serie", pattern = "^base_\\d{4}T\\d\\.rds$", full.names = TRUE)
if (length(arquivos) == 0) stop("Nenhum dados_saida/serie/base_*.rds — rode o R/10 antes.")

serie <- map_dfr(arquivos, ~ readRDS(.x)$base) %>%
  mutate(idx = idx_tri(Ano, Trimestre),
         CV  = ifelse(!is.na(Estimativa) & Estimativa != 0 & !is.na(SE),
                      100 * SE / abs(Estimativa), NA_real_))

todos_idx <- sort(unique(serie$idx))
ultimo    <- max(todos_idx)
esperado  <- seq(idx_tri(2016, 2), ultimo)
faltando  <- setdiff(esperado, todos_idx)
if (length(faltando) > 0) {
  message("ATENÇÃO: série incompleta — faltam ", length(faltando), " trimestre(s): ",
          paste(sprintf("%dT%d", faltando %/% 4, faltando %% 4 + 1), collapse = ", "))
}

chaves <- c("Indicador", "Subcategoria_Indicador", "Regiao_Geografica",
            "Recorte_Demografico", "Categoria_Demografica")

# Grade completa chave x trimestre: trimestre ausente vira linha com CV NA.
grade <- serie %>%
  distinct(across(all_of(chaves))) %>%
  cross_join(tibble(idx = todos_idx)) %>%
  left_join(serie %>% select(all_of(chaves), idx, CV), by = c(chaves, "idx"))

espacados <- todos_idx[(ultimo - todos_idx) %% PASSO_ESPACADO == 0]
na_pandemia <- function(i) i >= idx_de(PANDEMIA$inicio) & i <= idx_de(PANDEMIA$fim)

janelas <- list(
  principal    = todos_idx[todos_idx >= idx_de(INICIO_PRINCIPAL)],
  serie_toda   = todos_idx,
  sem_pandemia = todos_idx[!na_pandemia(todos_idx)]
)
amostragens <- list(todos = todos_idx, espacado_5 = espacados)

resumir <- function(cv) {
  n  <- length(cv)
  ok <- cv[!is.na(cv)]
  tibble(
    n_trimestres       = n,
    n_com_estimativa   = length(ok),
    cv_mediano         = if (length(ok)) median(ok) else NA_real_,
    cv_p80             = if (length(ok)) unname(quantile(ok, 0.8)) else NA_real_,
    cv_max             = if (length(ok)) max(ok) else NA_real_,
    pct_excelente      = 100 * sum(ok < 5) / n,
    pct_boa            = 100 * sum(ok >= 5 & ok < 15) / n,
    pct_regular        = 100 * sum(ok >= 15 & ok < 30) / n,
    pct_baixa          = 100 * sum(ok >= 30) / n,
    pct_sem_estimativa = 100 * (n - length(ok)) / n
  )
}

triagem <- imap_dfr(janelas, function(idx_jan, nome_jan) {
  imap_dfr(amostragens, function(idx_amo, nome_amo) {
    usar <- intersect(idx_jan, idx_amo)
    grade %>%
      filter(idx %in% usar) %>%
      group_by(across(all_of(chaves))) %>%
      summarise(resumir(CV), .groups = "drop") %>%
      mutate(janela = nome_jan, amostragem = nome_amo,
             periodo = sprintf("%dT%d-%dT%d", min(usar) %/% 4, min(usar) %% 4 + 1,
                               max(usar) %/% 4, max(usar) %% 4 + 1),
             .before = 1)
  })
})

# Por chave, independente da janela: transição de desenho e instabilidade recente.
recentes <- tail(todos_idx, N_RECENTES)
por_chave <- grade %>%
  group_by(across(all_of(chaves))) %>%
  summarise(
    cv_mediano_pre_transicao = median(CV[idx >= idx_de(INICIO_PRINCIPAL) & idx < idx_de(INICIO_TRANSICAO)], na.rm = TRUE),
    cv_mediano_transicao     = median(CV[idx >= idx_de(INICIO_TRANSICAO)], na.rm = TRUE),
    cv_max_recentes          = suppressWarnings(max(CV[idx %in% recentes], na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  mutate(across(where(is.numeric), ~ ifelse(is.finite(.x), .x, NA_real_)),
         razao_cv_transicao = cv_mediano_transicao / cv_mediano_pre_transicao)

triagem <- triagem %>%
  left_join(por_chave, by = chaves) %>%
  mutate(
    Nivel_Geografico = case_when(
      Regiao_Geografica %in% geografias_agregadas ~ "Agregado",
      startsWith(Regiao_Geografica, "Zona_")     ~ "Zona",
      startsWith(Regiao_Geografica, "Situacao_") ~ "Situacao",
      startsWith(Regiao_Geografica, "Admin_")    ~ "Estrato_Admin",
      startsWith(Regiao_Geografica, "Agreg_")    ~ "Estrato_Agregado",
      TRUE ~ "Outro"
    ),
    crit_a   = (pct_excelente + pct_boa) >= 80,
    crit_b   = !is.na(cv_mediano) & cv_mediano < 15,
    crit_c   = !is.na(cv_p80) & cv_p80 < 15,
    instavel = crit_b & !is.na(cv_max_recentes) & cv_max_recentes >= 30
  ) %>%
  relocate(Nivel_Geografico, .after = Regiao_Geografica) %>%
  arrange(Indicador, Subcategoria_Indicador, Nivel_Geografico, Regiao_Geografica,
          Recorte_Demografico, Categoria_Demografica, janela, amostragem)

dir.create("output/tabelas", recursive = TRUE, showWarnings = FALSE)
write_csv(triagem, "output/tabelas/triagem_confiabilidade.csv")

p <- filter(triagem, janela == "principal", amostragem == "todos")
message(sprintf("Triagem: %d trimestres (%s), %d chaves, %d linhas -> output/tabelas/triagem_confiabilidade.csv",
                length(todos_idx), p$periodo[1], nrow(p), nrow(triagem)))
message(sprintf("Janela principal: crit_a %d | crit_b %d | crit_c %d | instável %d",
                sum(p$crit_a), sum(p$crit_b), sum(p$crit_c), sum(p$instavel)))
