# ============================================================
# SCRIPT 1
# INDICADORES PNAD CONTÍNUA - ABORDAGEM DESCRITIVA
#
# Autor: 
# Base: dadosPNADc
#
# Este script utiliza:
#   - V1028 como peso amostral
#   - V1022 como urbano/rural
#   - V1023 como estrato administrativo
#   - Estrato_agregado como estrato geográfico agregado
#
# Os resultados são estimativas ponderadas, mas NÃO incorporam
# a variância do plano amostral complexo.
# ============================================================


# ============================================================
# 0. PACOTES
# ============================================================
library(PNADcIBGE)
library(tidyverse)
library(ggplot2)


# ============================================================
# 1. PREPARAÇÃO DA BASE
# ============================================================
dadosPNADc <- get_pnadc(year=2025, quarter = 1, design = FALSE)
dadosPI <- dadosPNADc %>%
  filter(
    as.integer(UF) == 22
  )


# ============================================================
# 2. ESTRATO AGREGADO
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
# 3. VARIÁVEIS DE DIVISÃO GEOGRÁFICA
# ============================================================

dadosPI <- dadosPI %>%
  mutate(
    
    Urbano_Rural = V1022,
    
    Estrato_Administrativo = V1023,
    
    Estrato_Agregado = Estrato_agregado
  )


# ============================================================
# 4. FUNÇÃO DE DESVIO-PADRÃO PONDERADO
# ============================================================

weighted_sd <- function(x, w) {
  
  ok <- !is.na(x) & !is.na(w)
  
  x <- x[ok]
  w <- w[ok]
  
  if (length(x) == 0) {
    return(NA_real_)
  }
  
  media <- weighted.mean(
    x,
    w,
    na.rm = TRUE
  )
  
  sqrt(
    sum(
      w * (x - media)^2
    ) /
      sum(w)
  )
}


# ============================================================
# 5. INDICADORES DE MERCADO DE TRABALHO
# ============================================================

indicadores_trabalho <- function(
    data,
    grupo
) {
  
  data %>%
    
    group_by(
      {{ grupo }}
    ) %>%
    
    summarise(
      
      # Pessoas ocupadas
      ocupados =
        sum(
          V1028[
            VD4002 ==
              "Pessoas ocupadas"
          ],
          na.rm = TRUE
        ),
      
      # Pessoas desocupadas
      desocupados =
        sum(
          V1028[
            VD4002 ==
              "Pessoas desocupadas"
          ],
          na.rm = TRUE
        ),
      
      # Força de trabalho potencial
      ftp =
        sum(
          V1028[
            VD4003 ==
              "Pessoas fora da força de trabalho e na força de trabalho potencial"
          ],
          na.rm = TRUE
        ),
      
      # Fora da força de trabalho e fora da FTP
      fora_ft_ftp =
        sum(
          V1028[
            VD4003 ==
              "Pessoas fora da força de trabalho e fora da força de trabalho potencial"
          ],
          na.rm = TRUE
        ),
      
      # Subocupados
      subocupados =
        sum(
          V1028[
            VD4004A ==
              "Pessoas subocupadas"
          ],
          na.rm = TRUE
        ),
      
      # Desalentados
      desalentados =
        sum(
          V1028[
            VD4005 ==
              "Pessoas desalentadas"
          ],
          na.rm = TRUE
        ),
      
      .groups = "drop"
    ) %>%
    
    mutate(
      
      # ------------------------------------------------------
      # Força de trabalho
      # ------------------------------------------------------
      
      forca_trabalho =
        ocupados +
        desocupados,
      
      # ------------------------------------------------------
      # Força de trabalho ampliada
      # ------------------------------------------------------
      
      forca_trabalho_ampliada =
        ocupados +
        desocupados +
        ftp,
      
      
      # ------------------------------------------------------
      # Taxa de desocupação
      # ------------------------------------------------------
      
      taxa_desocupacao =
        100 *
        desocupados /
        forca_trabalho,
      
      
      # ------------------------------------------------------
      # Taxa combinada de desocupação
      # + subocupação
      # ------------------------------------------------------
      
      taxa_comb_desocup_subocup =
        100 *
        (
          desocupados +
            subocupados
        ) /
        forca_trabalho,
      
      
      # ------------------------------------------------------
      # Taxa combinada de desocupação
      # + força de trabalho potencial
      # ------------------------------------------------------
      
      taxa_comb_desocup_ftp =
        100 *
        (
          desocupados +
            ftp
        ) /
        forca_trabalho_ampliada,
      
      
      # ------------------------------------------------------
      # Taxa composta de subutilização
      # ------------------------------------------------------
      
      taxa_subutilizacao =
        100 *
        (
          desocupados +
            subocupados +
            ftp
        ) /
        forca_trabalho_ampliada,
      
      
      # ------------------------------------------------------
      # Taxa de desalento na força de trabalho ampliada
      # ------------------------------------------------------
      
      taxa_desalento_fta =
        100 *
        desalentados /
        forca_trabalho_ampliada,
      
      
      # ------------------------------------------------------
      # Desalentados na população fora da FT
      # ------------------------------------------------------
      
      pct_desalentados_fora_ft =
        100 *
        desalentados /
        (
          desalentados +
            ftp +
            fora_ft_ftp
        ),
      
      
      # ------------------------------------------------------
      # Desalentados na FTP
      # ------------------------------------------------------
      
      pct_desalentados_ftp =
        100 *
        desalentados /
        ftp
    )
}


# ============================================================
# 6. INDICADORES SOCIAIS QUANTITATIVOS
# ============================================================

indicadores_sociais <- function(
    data,
    grupo
) {
  
  data %>%
    
    group_by(
      {{ grupo }}
    ) %>%
    
    summarise(
      
      # ------------------------------------------------------
      # Idade
      # ------------------------------------------------------
      
      idade_media =
        weighted.mean(
          V2009,
          w = V1028,
          na.rm = TRUE
        ),
      
      idade_desvio_padrao =
        weighted_sd(
          V2009,
          V1028
        ),
      
      
      # ------------------------------------------------------
      # Rendimento do trabalho
      # ------------------------------------------------------
      
      rendimento_medio =
        weighted.mean(
          VD4020,
          w = V1028,
          na.rm = TRUE
        ),
      
      rendimento_desvio_padrao =
        weighted_sd(
          VD4020,
          V1028
        ),
      
      
      # ------------------------------------------------------
      # Horas trabalhadas
      # ------------------------------------------------------
      
      horas_media =
        weighted.mean(
          VD4035,
          w = V1028,
          na.rm = TRUE
        ),
      
      horas_desvio_padrao =
        weighted_sd(
          VD4035,
          V1028
        ),
      
      .groups = "drop"
    )
}


# ============================================================
# 7. EXECUTAR INDICADORES PARA OS 3 RECORTES
# ============================================================


# ------------------------------------------------------------
# 7.1 Urbano / Rural
# ------------------------------------------------------------

trabalho_urbano_rural <-
  indicadores_trabalho(
    dadosPI,
    Urbano_Rural
  )

sociais_urbano_rural <-
  indicadores_sociais(
    dadosPI,
    Urbano_Rural
  )


# ------------------------------------------------------------
# 7.2 Estrato administrativo
# ------------------------------------------------------------

trabalho_administrativo <-
  indicadores_trabalho(
    dadosPI,
    Estrato_Administrativo
  )

sociais_administrativo <-
  indicadores_sociais(
    dadosPI,
    Estrato_Administrativo
  )


# ------------------------------------------------------------
# 7.3 Estrato agregado
# ------------------------------------------------------------

trabalho_estrato_agregado <-
  indicadores_trabalho(
    dadosPI,
    Estrato_Agregado
  )

sociais_estrato_agregado <-
  indicadores_sociais(
    dadosPI,
    Estrato_Agregado
  )


# ============================================================
# 8. INDICADORES CATEGÓRICOS
# ============================================================

indicador_categorico <- function(
    data,
    grupo,
    variavel
) {
  
  data %>%
    
    filter(
      !is.na({{ grupo }}),
      !is.na({{ variavel }})
    ) %>%
    
    group_by(
      {{ grupo }},
      {{ variavel }}
    ) %>%
    
    summarise(
      populacao =
        sum(
          V1028,
          na.rm = TRUE
        ),
      .groups = "drop_last"
    ) %>%
    
    mutate(
      
      percentual =
        100 *
        populacao /
        sum(populacao)
      
    ) %>%
    
    ungroup()
}


# ============================================================
# 9. SEXO
# ============================================================

sexo_urbano_rural <-
  indicador_categorico(
    dadosPI,
    Urbano_Rural,
    V2007
  )

sexo_administrativo <-
  indicador_categorico(
    dadosPI,
    Estrato_Administrativo,
    V2007
  )

sexo_estrato_agregado <-
  indicador_categorico(
    dadosPI,
    Estrato_Agregado,
    V2007
  )


# ============================================================
# 10. COR / RAÇA
# ============================================================

raca_urbano_rural <-
  indicador_categorico(
    dadosPI,
    Urbano_Rural,
    V2010
  )

raca_administrativo <-
  indicador_categorico(
    dadosPI,
    Estrato_Administrativo,
    V2010
  )

raca_estrato_agregado <-
  indicador_categorico(
    dadosPI,
    Estrato_Agregado,
    V2010
  )


# ============================================================
# 11. INDICADORES HABITACIONAIS
# ============================================================

variaveis_habitacao <- c(
  "S01003",
  "S01007",
  "S01012A",
  "S01013",
  "S01023",
  "S01028"
)


indicadores_habitacao <- function(
    data,
    grupo,
    variaveis
) {
  
  map_dfr(
    variaveis,
    function(v) {
      
      data %>%
        
        filter(
          !is.na({{ grupo }}),
          !is.na(.data[[v]])
        ) %>%
        
        group_by(
          {{ grupo }},
          categoria = .data[[v]]
        ) %>%
        
        summarise(
          populacao =
            sum(
              V1028,
              na.rm = TRUE
            ),
          .groups = "drop_last"
        ) %>%
        
        mutate(
          
          percentual =
            100 *
            populacao /
            sum(populacao),
          
          variavel = v
          
        ) %>%
        
        ungroup()
    }
  )
}


habitacao_urbano_rural <-
  indicadores_habitacao(
    dadosPI,
    Urbano_Rural,
    variaveis_habitacao
  )

habitacao_administrativo <-
  indicadores_habitacao(
    dadosPI,
    Estrato_Administrativo,
    variaveis_habitacao
  )

habitacao_estrato_agregado <-
  indicadores_habitacao(
    dadosPI,
    Estrato_Agregado,
    variaveis_habitacao
  )


# ============================================================
# 12. FUNÇÃO PARA BOXPLOTS
# ============================================================

boxplot_pnad <- function(
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
# 13. BOXPLOTS - URBANO/RURAL
# ============================================================

boxplot_pnad(
  dadosPI,
  Urbano_Rural,
  V2009,
  "Distribuição da idade - Urbano/Rural",
  "Idade (anos)"
)


boxplot_pnad(
  dadosPI,
  Urbano_Rural,
  VD4020,
  "Distribuição do rendimento do trabalho - Urbano/Rural",
  "Rendimento (R$)"
)


boxplot_pnad(
  dadosPI,
  Urbano_Rural,
  VD4035,
  "Distribuição das horas trabalhadas - Urbano/Rural",
  "Horas trabalhadas"
)


# ============================================================
# 14. BOXPLOTS - ESTRATO ADMINISTRATIVO
# ============================================================

boxplot_pnad(
  dadosPI,
  Estrato_Administrativo,
  V2009,
  "Distribuição da idade - Estrato administrativo",
  "Idade (anos)"
)


boxplot_pnad(
  dadosPI,
  Estrato_Administrativo,
  VD4020,
  "Distribuição do rendimento do trabalho - Estrato administrativo",
  "Rendimento (R$)"
)


boxplot_pnad(
  dadosPI,
  Estrato_Administrativo,
  VD4035,
  "Distribuição das horas trabalhadas - Estrato administrativo",
  "Horas trabalhadas"
)


# ============================================================
# 15. BOXPLOTS - ESTRATO AGREGADO
# ============================================================

boxplot_pnad(
  dadosPI,
  Estrato_Agregado,
  V2009,
  "Distribuição da idade - Estrato agregado",
  "Idade (anos)"
)


boxplot_pnad(
  dadosPI,
  Estrato_Agregado,
  VD4020,
  "Distribuição do rendimento do trabalho - Estrato agregado",
  "Rendimento (R$)"
)


boxplot_pnad(
  dadosPI,
  Estrato_Agregado,
  VD4035,
  "Distribuição das horas trabalhadas - Estrato agregado",
  "Horas trabalhadas"
)


# ============================================================
# 16. VISUALIZAÇÃO DAS TABELAS
# ============================================================

trabalho_urbano_rural
sociais_urbano_rural

trabalho_administrativo
sociais_administrativo

trabalho_estrato_agregado
sociais_estrato_agregado

sexo_urbano_rural
raca_urbano_rural

sexo_administrativo
raca_administrativo

sexo_estrato_agregado
raca_estrato_agregado

habitacao_urbano_rural
habitacao_administrativo
habitacao_estrato_agregado