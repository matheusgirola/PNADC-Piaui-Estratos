# ==============================================================================
# 00_config.R — parâmetros compartilhados do pipeline trimestral.
#
# POR QUE ISSO EXISTE
# -------------------
# ANO_REF e TRIMESTRE_REF estavam declarados em DOIS arquivos
# (pipeline_trimestral.R e 03_comparacoes_indicadores.R). Como os nomes de
# arquivo de saída são sufixados por trimestre, as bases antigas continuam em
# disco — então esquecer de atualizar um dos dois não dava erro: o 03
# simplesmente relia a base do trimestre anterior e regravava as tabelas
# daquele trimestre. O relatório saía com a cara de novo e os números velhos.
#
# Agora os dois arquivos dão source() aqui. Mudar o trimestre é mexer em UM
# lugar só.
#
# USO: no topo de cada script do pipeline,
#   source("R/00_config.R")
#
# Os caminhos são relativos à RAIZ do projeto (é de lá que os scripts rodam,
# porque todos gravam em "output/..."). Se você abre o .Rproj, o diretório de
# trabalho já é a raiz e não há nada a fazer.
# ==============================================================================

library(dplyr)
library(tibble)

# ---- Trimestre de referência -------------------------------------------------
# É AQUI que se muda o trimestre. Mais nada.

ANO_REF       <- 2026
TRIMESTRE_REF <- 2

sufixo <- sprintf("%dT%d", ANO_REF, TRIMESTRE_REF)

# ---- Salário mínimo por hora, por ano ----------------------------------------
# Base do corte de subremuneração (rendimento/hora abaixo do mínimo/hora).
# ACRESCENTE A LINHA DO ANO NOVO quando virar o ano.

tabela_salario_minimo <- tibble(
  ano     = 2015:2026,
  sm_hora = c(3.58, 4.00, 4.26, 4.34, 4.54, 4.75, 5.00, 5.51, 6.00, 6.42, 6.87, 7.37)
)

sm_hora_corrente <- tabela_salario_minimo %>% filter(ano == ANO_REF) %>% pull(sm_hora)

# Falha explícita e cedo. Sem isso, o erro só apareceria lá na frente, dentro
# de um mutate(), com a mensagem obscura "must be size N or 1, not 0" — que não
# diz a coisa mais útil, que é "faltou cadastrar o salário mínimo do ano".
if (length(sm_hora_corrente) != 1) {
  stop("Não há salário mínimo cadastrado para ", ANO_REF,
       " em tabela_salario_minimo (R/00_config.R). Acrescente a linha do ano ",
       "antes de rodar o pipeline.")
}

# ---- Geografias agregadas ----------------------------------------------------
# Os níveis que NÃO são estratos do Piauí. Usado para decidir quais recortes
# demográficos se aplicam (no pipeline) e para classificar Tipo_Geo (no 03) —
# outra constante que estava duplicada entre os dois arquivos.

geografias_agregadas <- c("Brasil", "Nordeste", "Piauí", "Teresina")

# ---- Pastas de saída ---------------------------------------------------------

dir.create("output/figuras", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tabelas", recursive = TRUE, showWarnings = FALSE)

message("00_config.R: trimestre de referência ", sufixo,
        " | salário mínimo/hora R$ ", format(sm_hora_corrente, nsmall = 2))
