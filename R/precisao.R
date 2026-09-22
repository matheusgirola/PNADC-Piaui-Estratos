# ==============================================================================
# precisao.R — CV, IC 95% e classe de precisão de uma estimativa.
#
# Fonte única para o 01, 03, 09, 11 e 12 (antes cada um tinha sua cópia, com
# pequenas diferenças: com/sem abs(), com/sem proteção para estimativa zero).
# Funções vetorizadas, sem dependência de pacote.
#
# CLASSES PELO CV — o IBGE define CV < 15% como o corte de "boa precisão"
# para as estimativas amostrais da PNADC (documentado nas notas técnicas de
# calibração de pesos da pesquisa). Os cortes de 5% e 30% seguem a mesma
# lógica graduada, prática comum em relatórios de estatísticas amostrais (o
# de 30% é o mais citado como limite de "não recomendado" fora do Brasil
# também, ex. convenções do Statistics Canada e do U.S. Census Bureau):
#   CV <  5%          -> excelente
#   5%  <= CV < 15%   -> boa        [15% = corte do IBGE]
#   15% <= CV < 30%   -> regular
#   CV >= 30%         -> baixa
# ==============================================================================

LIMITES_CV <- c(excelente = 5, boa = 15, regular = 30)

CLASSES_PRECISAO <- c("excelente", "boa", "regular", "baixa")

# Quantil normal do IC 95%, arredondado como no resto do projeto (1,96, não
# qnorm(0,975) = 1,959964): trocar mudaria a última casa de IC já publicado.
Z_IC95 <- 1.96

# CV em %, sobre |estimativa|. NA quando a estimativa é zero ou falta — não
# existe CV de estimativa nula (sairia Inf ou NaN).
calcular_cv <- function(estimativa, se) {
  ok <- !is.na(estimativa) & estimativa != 0 & !is.na(se)
  out <- rep(NA_real_, length(ok))
  out[ok] <- 100 * abs(se[ok] / estimativa[ok])
  out
}

# Limites do IC 95% normal. `piso` corta o limite inferior (ex.: 0 para
# quantidades que não podem ser negativas, como taxas e totais).
ic_inferior <- function(estimativa, se, piso = -Inf) pmax(piso, estimativa - Z_IC95 * se)
ic_superior <- function(estimativa, se) estimativa + Z_IC95 * se

# Classe de precisão; NA continua NA.
classificar_cv <- function(cv) {
  classe <- rep(NA_character_, length(cv))
  classe[!is.na(cv)] <- CLASSES_PRECISAO[
    findInterval(cv[!is.na(cv)], LIMITES_CV) + 1
  ]
  classe
}

# CV "aceitável" pelo corte do IBGE (< 15%), usado nas marcas do relatório e
# nos critérios da triagem.
cv_aceitavel <- function(cv) !is.na(cv) & cv < LIMITES_CV[["boa"]]
