# ============================================================
# SCRIPT 2
# INDICADORES PNAD CONTÍNUA - ABORDAGEM SURVEY
#
# Versão metodologicamente recomendada
#
# Utiliza:
#   - plano amostral complexo
#   - peso V1028
#   - UPA
#   - Estrato
#   - survey::svyratio()
#   - survey::svymean()
#   - survey::svytotal()
#   - survey::svyby()
#
# Resultado dos indicadores:
#   - estimativa
#   - erro-padrão
#   - CV
#   - IC95%
#
# ============================================================


# ============================================================
# 0. PACOTES
# ============================================================
library(PNADcIBGE)
library(tidyverse)
library(survey)
library(ggplot2)


# ============================================================
# 1. OPÇÕES DO SURVEY
# ============================================================

options(
  survey.lonely.psu = "adjust"
)


# ============================================================
# 2. BASE DO PIAUÍ
# ============================================================

dadosPNADc <- get_pnadc(year=2025, interview = 1)

dadosPI <- dadosPNADc$variables %>%
  filter(
    as.integer(UF) == 22
  )


# ============================================================
# 3. ESTRATO AGREGADO
# ============================================================

dadosPI <- dadosPI %>%
  mutate(
    
    Estrato_agregado = case_when(
      
      as.integer(Estrato) %in% 2210011:2210030 ~
        "Teresina",
      
      as.integer(Estrato) %in% 2220010:2220020 ~
        "Entorno metropolitano de Teresina (PI)",
      
      as.integer(Estrato) %in% 2251011:2251022 ~
        "Centro-Leste do Piauí",
      
      as.integer(Estrato) %in% 2252011:2252022 ~
        "Baixo Parnaíba do Piauí",
      
      as.integer(Estrato) %in% 2253010:2254020 ~
        "Alto Parnaíba e Chapadas Sul do Piauí",
      
      TRUE ~ NA_character_
    ),
    
    Estrato_agregado =
      factor(Estrato_agregado)
  )


# ============================================================
# 4. CRIAR OBJETO SURVEY
# ============================================================

desenhoPI <- dadosPI


# ============================================================
# 5. RECORTES GEOGRÁFICOS
# ============================================================

# ------------------------------------------------------------
# Urbano / Rural
# ------------------------------------------------------------

desenho_urbano_rural <-
  desenhoPI


# ------------------------------------------------------------
# Estrato administrativo
# ------------------------------------------------------------

desenho_administrativo <-
  desenhoPI


# ------------------------------------------------------------
# Estrato agregado
# ------------------------------------------------------------

desenho_estrato_agregado <-
  subset(
    desenhoPI,
    !is.na(Estrato_agregado)
  )


# ============================================================
# 6. FUNÇÃO AUXILIAR PARA RESULTADOS DO SURVEY
# ============================================================

resultado_survey <- function(
    estimativa
) {
  
  est <- coef(estimativa)
  
  erro <- SE(estimativa)
  
  cv <- cv(estimativa)
  
  ic <- confint(
    estimativa,
    level = 0.95
  )
  
  tibble(
    
    estimativa = as.numeric(est),
    
    erro_padrao =
      as.numeric(erro),
    
    CV =
      as.numeric(cv) * 100,
    
    IC95_inferior =
      as.numeric(ic[, 1]),
    
    IC95_superior =
      as.numeric(ic[, 2])
  )
}


# ============================================================
# 7. TAXA DE DESOCUPAÇÃO
# ============================================================

taxa_desocupacao <- function(
    desenho,
    grupo
) {
  
  resultado <- svyby(
    numerator =
      ~I(
        VD4002 ==
          "Pessoas desocupadas"
      ),
    
    denominator =
      ~I(
        VD4001 ==
          "Pessoas na força de trabalho"
      ),
    
    by =
      as.formula(
        paste0(
          "~",
          deparse(
            substitute(grupo)
          )
        )
      ),
    
    design = desenho,
    
    FUN = svyratio,
    
    na.rm = TRUE
  )
  
  resultado
}


# ============================================================
# 8. TAXA DE DESOCUPAÇÃO - URBANO/RURAL
# ============================================================

tx_desocup_urbano_rural <-
  taxa_desocupacao(
    desenho_urbano_rural,
    V1022
  )


# ============================================================
# 9. TAXA DE DESOCUPAÇÃO - ESTRATO ADMINISTRATIVO
# ============================================================

tx_desocup_administrativo <-
  taxa_desocupacao(
    desenho_administrativo,
    V1023
  )


# ============================================================
# 10. TAXA DE DESOCUPAÇÃO - ESTRATO AGREGADO
# ============================================================

tx_desocup_estrato_agregado <-
  taxa_desocupacao(
    desenho_estrato_agregado,
    Estrato_agregado
  )


# ============================================================
# 11. FUNÇÃO GENÉRICA PARA INDICADORES DE TRABALHO
# ============================================================

indicadores_trabalho_survey <- function(
    desenho,
    grupo
) {
  
  grupo_formula <-
    as.formula(
      paste0(
        "~",
        deparse(
          substitute(grupo)
        )
      )
    )
  
  
  # ----------------------------------------------------------
  # Taxa de desocupação
  # ----------------------------------------------------------
  
  tx_desocup <-
    svyby(
      
      ~I(
        VD4002 ==
          "Pessoas desocupadas"
      ),
      
      by = grupo_formula,
      
      denominator =
        ~I(
          VD4001 ==
            "Pessoas na força de trabalho"
        ),
      
      design = desenho,
      
      FUN = svyratio,
      
      na.rm = TRUE
    )
  
  
  # ----------------------------------------------------------
  # Taxa combinada:
  # desocupação + subocupação
  # ----------------------------------------------------------
  
  tx_comb_subocup <-
    svyby(
      
      ~I(
        VD4002 ==
          "Pessoas desocupadas"
      ) +
        I(
          VD4004A ==
            "Pessoas subocupadas"
        ),
      
      by = grupo_formula,
      
      denominator =
        ~I(
          VD4001 ==
            "Pessoas na força de trabalho"
        ),
      
      design = desenho,
      
      FUN = svyratio,
      
      na.rm = TRUE
    )
  
  
  # ----------------------------------------------------------
  # Taxa combinada:
  # desocupação + FTP
  # ----------------------------------------------------------
  
  tx_comb_ftp <-
    svyby(
      
      ~I(
        VD4002 ==
          "Pessoas desocupadas"
      ) +
        I(
          VD4003 ==
            "Pessoas fora da força de trabalho e na força de trabalho potencial"
        ),
      
      by = grupo_formula,
      
      denominator =
        ~I(
          VD4001 ==
            "Pessoas na força de trabalho"
        ) +
        I(
          VD4003 ==
            "Pessoas fora da força de trabalho e na força de trabalho potencial"
        ),
      
      design = desenho,
      
      FUN = svyratio,
      
      na.rm = TRUE
    )
  
  
  # ----------------------------------------------------------
  # Taxa composta de subutilização
  # ----------------------------------------------------------
  
  tx_subutilizacao <-
    svyby(
      
      ~I(
        VD4002 ==
          "Pessoas desocupadas"
      ) +
        I(
          VD4004A ==
            "Pessoas subocupadas"
        ) +
        I(
          VD4003 ==
            "Pessoas fora da força de trabalho e na força de trabalho potencial"
        ),
      
      by = grupo_formula,
      
      denominator =
        ~I(
          VD4001 ==
            "Pessoas na força de trabalho"
        ) +
        I(
          VD4003 ==
            "Pessoas fora da força de trabalho e na força de trabalho potencial"
        ),
      
      design = desenho,
      
      FUN = svyratio,
      
      na.rm = TRUE
    )
  
  
  # ----------------------------------------------------------
  # Transformar cada resultado
  # ----------------------------------------------------------
  
  list(
    
    taxa_desocupacao =
      tx_desocup,
    
    taxa_comb_desocup_subocup =
      tx_comb_subocup,
    
    taxa_comb_desocup_ftp =
      tx_comb_ftp,
    
    taxa_subutilizacao =
      tx_subutilizacao
  )
}


# ============================================================
# 12. EXECUTAR PARA OS TRÊS RECORTES
# ============================================================

trabalho_urbano_rural_survey <-
  indicadores_trabalho_survey(
    desenhoPI,
    V1022
  )


trabalho_administrativo_survey <-
  indicadores_trabalho_survey(
    desenhoPI,
    V1023
  )


trabalho_estrato_agregado_survey <-
  indicadores_trabalho_survey(
    desenho_estrato_agregado,
    Estrato_agregado
  )


# ============================================================
# 13. INDICADORES SOCIAIS COM SURVEY
# ============================================================

indicadores_sociais_survey <- function(
    desenho,
    grupo
) {
  
  grupo_formula <-
    as.formula(
      paste0(
        "~",
        deparse(
          substitute(grupo)
        )
      )
    )
  
  
  # ----------------------------------------------------------
  # Idade
  # ----------------------------------------------------------
  
  idade <-
    svyby(
      
      ~V2009,
      
      by = grupo_formula,
      
      design = desenho,
      
      FUN = svymean,
      
      na.rm = TRUE,
      
      vartype = c(
        "se",
        "cv",
        "ci"
      )
    )
  
  
  # ----------------------------------------------------------
  # Rendimento do trabalho
  # ----------------------------------------------------------
  
  rendimento <-
    svyby(
      
      ~VD4020,
      
      by = grupo_formula,
      
      design = desenho,
      
      FUN = svymean,
      
      na.rm = TRUE,
      
      vartype = c(
        "se",
        "cv",
        "ci"
      )
    )
  
  
  # ----------------------------------------------------------
  # Horas trabalhadas
  # ----------------------------------------------------------
  
  horas <-
    svyby(
      
      ~VD4035,
      
      by = grupo_formula,
      
      design = desenho,
      
      FUN = svymean,
      
      na.rm = TRUE,
      
      vartype = c(
        "se",
        "cv",
        "ci"
      )
    )
  
  
  list(
    
    idade = idade,
    
    rendimento = rendimento,
    
    horas = horas
  )
}


# ============================================================
# 14. INDICADORES SOCIAIS - URBANO/RURAL
# ============================================================

sociais_urbano_rural_survey <-
  indicadores_sociais_survey(
    desenhoPI,
    V1022
  )


# ============================================================
# 15. INDICADORES SOCIAIS - ESTRATO ADMINISTRATIVO
# ============================================================

sociais_administrativo_survey <-
  indicadores_sociais_survey(
    desenhoPI,
    V1023
  )


# ============================================================
# 16. INDICADORES SOCIAIS - ESTRATO AGREGADO
# ============================================================

sociais_estrato_agregado_survey <-
  indicadores_sociais_survey(
    desenho_estrato_agregado,
    Estrato_agregado
  )


# ============================================================
# 17. SEXO
# ============================================================

sexo_survey <- function(
    desenho,
    grupo
) {
  
  grupo_formula <-
    as.formula(
      paste0(
        "~",
        deparse(
          substitute(grupo)
        )
      )
    )
  
  
  svyby(
    
    ~I(
      V2007 ==
        "Homem"
    ),
    
    by = grupo_formula,
    
    design = desenho,
    
    FUN = svymean,
    
    na.rm = TRUE,
    
    vartype = c(
      "se",
      "cv",
      "ci"
    )
  )
}


sexo_urbano_rural_survey <-
  sexo_survey(
    desenhoPI,
    V1022
  )


sexo_administrativo_survey <-
  sexo_survey(
    desenhoPI,
    V1023
  )


sexo_estrato_agregado_survey <-
  sexo_survey(
    desenho_estrato_agregado,
    Estrato_agregado
  )


# ============================================================
# 18. COR / RAÇA
# ============================================================

raca_survey <- function(
    desenho,
    grupo
) {
  
  grupo_formula <-
    as.formula(
      paste0(
        "~",
        deparse(
          substitute(grupo)
        )
      )
    )
  
  
  svyby(
    
    ~V2010,
    
    by = grupo_formula,
    
    design = desenho,
    
    FUN = svymean,
    
    na.rm = TRUE,
    
    vartype = c(
      "se",
      "cv",
      "ci"
    )
  )
}


raca_urbano_rural_survey <-
  raca_survey(
    desenhoPI,
    V1022
  )


raca_administrativo_survey <-
  raca_survey(
    desenhoPI,
    V1023
  )


raca_estrato_agregado_survey <-
  raca_survey(
    desenho_estrato_agregado,
    Estrato_agregado
  )


# ============================================================
# 19. BOXPLOTS
#
# IMPORTANTE:
#
# Boxplot tradicional NÃO incorpora diretamente o plano
# amostral complexo.
#
# Por isso, aqui o objetivo é visualizar a distribuição
# da amostra, enquanto as tabelas acima fornecem as
# estimativas inferenciais pelo survey.
# ============================================================


boxplot_survey <- function(
    data,
    grupo,
    variavel,
    titulo,
    eixo_y
) {
  
  ggplot(
    
    data %>%
      filter(
        !is.na({{ grupo }}),
        !is.na({{ variavel }}),
        {{ variavel }} >= 0
      ),
    
    aes(
      x = {{ grupo }},
      y = {{ variavel }}
    )
    
  ) +
    
    geom_boxplot(
      outlier.alpha = 0.15
    ) +
    
    labs(
      x = NULL,
      y = eixo_y,
      title = titulo
    ) +
    
    theme_minimal() +
    
    theme(
      axis.text.x =
        element_text(
          angle = 45,
          hjust = 1
        )
    )
}


# ============================================================
# 20. BOXPLOTS - URBANO/RURAL
# ============================================================

boxplot_survey(
  dadosPI,
  V1022,
  V2009,
  "Distribuição da idade - Urbano/Rural",
  "Idade (anos)"
)


boxplot_survey(
  dadosPI,
  V1022,
  VD4020,
  "Distribuição do rendimento - Urbano/Rural",
  "Rendimento (R$)"
)


boxplot_survey(
  dadosPI,
  V1022,
  VD4035,
  "Distribuição das horas trabalhadas - Urbano/Rural",
  "Horas"
)


# ============================================================
# 21. BOXPLOTS - ESTRATO ADMINISTRATIVO
# ============================================================

boxplot_survey(
  dadosPI,
  V1023,
  V2009,
  "Distribuição da idade - Estrato administrativo",
  "Idade (anos)"
)


boxplot_survey(
  dadosPI,
  V1023,
  VD4020,
  "Distribuição do rendimento - Estrato administrativo",
  "Rendimento (R$)"
)


boxplot_survey(
  dadosPI,
  V1023,
  VD4035,
  "Distribuição das horas trabalhadas - Estrato administrativo",
  "Horas"
)


# ============================================================
# 22. BOXPLOTS - ESTRATO AGREGADO
# ============================================================

boxplot_survey(
  dadosPI,
  Estrato_agregado,
  V2009,
  "Distribuição da idade - Estrato agregado",
  "Idade (anos)"
)


boxplot_survey(
  dadosPI,
  Estrato_agregado,
  VD4020,
  "Distribuição do rendimento - Estrato agregado",
  "Rendimento (R$)"
)


boxplot_survey(
  dadosPI,
  Estrato_agregado,
  VD4035,
  "Distribuição das horas trabalhadas - Estrato agregado",
  "Horas"
)


# ============================================================
# 23. RESULTADOS
# ============================================================

trabalho_urbano_rural_survey

trabalho_administrativo_survey

trabalho_estrato_agregado_survey

sociais_urbano_rural_survey

sociais_administrativo_survey

sociais_estrato_agregado_survey

sexo_urbano_rural_survey

sexo_administrativo_survey

sexo_estrato_agregado_survey

raca_urbano_rural_survey

raca_administrativo_survey

raca_estrato_agregado_survey