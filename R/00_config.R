# ==============================================================================
# 00_config.R — parâmetros compartilhados do pipeline trimestral.
#
# Atualizar esse arquivo para Ano/Trimestre - ele alimenta o 01 e o 03
# se rodar o 03 sem atualizar esse pode dá bug direto e sem erro viu palhaço, Ele dá a doida e pegar 
# o antigo
#
# A cada ano tem que atualizar o salario minimo por hora, é hard-coded


library(dplyr)
library(tibble)

# ---- Trimestre de referência -------------------------------------------------
# É AQUI que se muda o ano e trimestre. Mais nada.

ANO_REF       <- 2026
TRIMESTRE_REF <- 2

sufixo <- sprintf("%dT%d", ANO_REF, TRIMESTRE_REF)

# ---- Salário mínimo por hora SEMANAL, por ano ----------------------------------------
# Base do corte de subremuneração (rendimento/hora abaixo do mínimo/hora).
# ACRESCENTE A LINHA DO ANO NOVO quando virar o ano.
# Pra calcular: (Salario minimo)/220h -> 220h pois o mes comercial em 5 semanas e cada uma tem 44h semanais

tabela_salario_minimo <- tibble(
  ano     = 2015:2026,
  sm_hora = c(3.58, 4.00, 4.26, 4.34, 4.54, 4.75, 5.00, 5.51, 6.00, 6.42, 6.87, 7.37)
)

sm_hora_corrente <- tabela_salario_minimo %>% filter(ano == ANO_REF) %>% pull(sm_hora)

# Condição que retorna erro caso não tenha o salário pro ano
if (length(sm_hora_corrente) != 1) {
  stop("Não há salário mínimo cadastrado para ", ANO_REF,
       " em tabela_salario_minimo (R/00_config.R). Acrescente a linha do ano ",
       "antes de rodar o pipeline.")
}

# ---- Geografias agregadas ---------------------------------------------
# Os níveis que NÃO são estratos do Piauí. Usado para decidir quais recortes
# demográficos se aplicam (no pipeline) e para classificar Tipo_Geo (no 03) —
# mais coisas que repetem no 01 e 03

geografias_agregadas <- c("Brasil", "Nordeste", "Piauí", "Teresina")

# ---- Pastas de saída --------------------------------------------

dir.create("output/figuras", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tabelas", recursive = TRUE, showWarnings = FALSE)

message("00_config.R: trimestre de referência ", sufixo,
        " | salário mínimo/hora R$ ", format(sm_hora_corrente, nsmall = 2))
