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
# desenho). CV, classes e limites em R/precisao.R: Excelente < 5,
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
# Lógica (janelas, resumo, critérios) no módulo R/triagem.R; aqui só leitura
# e gravação.
#   Rscript R/11_triagem_confiabilidade.R
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(purrr)
})

source("R/00_config.R", encoding = "UTF-8")  # geografias_agregadas
source("R/precisao.R", encoding = "UTF-8")   # calcular_cv(), LIMITES_CV
source("R/triagem.R", encoding = "UTF-8")    # triar(), janelas e critérios

arquivos <- list.files("dados_saida/serie", pattern = "^base_\\d{4}T\\d\\.rds$", full.names = TRUE)
if (length(arquivos) == 0) stop("Nenhum dados_saida/serie/base_*.rds — rode o R/10 antes.")

serie <- map_dfr(arquivos, ~ readRDS(.x)$base) %>%
  mutate(idx = idx_tri(Ano, Trimestre),
         CV  = calcular_cv(Estimativa, SE))

todos_idx <- sort(unique(serie$idx))
faltando  <- trimestres_faltando(todos_idx)
if (length(faltando) > 0) {
  message("ATENÇÃO: série incompleta — faltam ", length(faltando), " trimestre(s): ",
          paste(rotulo_idx(faltando), collapse = ", "))
}

triagem <- triar(serie, geografias_agregadas)

dir.create("output/tabelas", recursive = TRUE, showWarnings = FALSE)
write_csv(triagem, "output/tabelas/triagem_confiabilidade.csv")

p <- filter(triagem, janela == "principal", amostragem == "todos")
message(sprintf("Triagem: %d trimestres (%s), %d chaves, %d linhas -> output/tabelas/triagem_confiabilidade.csv",
                length(todos_idx), p$periodo[1], nrow(p), nrow(triagem)))
message(sprintf("Janela principal: crit_a %d | crit_b %d | crit_c %d | instável %d",
                sum(p$crit_a), sum(p$crit_b), sum(p$crit_c), sum(p$instavel)))
