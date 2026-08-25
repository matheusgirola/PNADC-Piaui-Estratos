
# ==============================================================================
# SCRIPT 2: ANÁLISE DE CONSISTÊNCIA, QUALIDADE AMOSTRAL E VISUALIZAÇÃO
# ==============================================================================

library(dplyr)
library(readr)
library(ggplot2)
library(tidyr)

# 1. Carregar Dados Consolidados
if(!file.exists("./dados_saida/base_consolidada_total_indicadores.csv")) {
  stop("A base de dados não foi encontrada. Rode o script '01_processamento_serie.R' primeiro.")
}

dados_analise <- read_csv("dados_saida/base_consolidada_total_indicadores.csv") %>%
  mutate(
    Periodo = paste0(Ano, " - ", Trimestre, "T"),
    # Cálculo do Coeficiente de Variação (CV) para medir estabilidade (Critério IBGE: CV > 30% indica alta instabilidade)
    Taxa_Desocupacao_CV = (Taxa_Desocupacao_SE / Taxa_Desocupacao) * 100,
    Renda_Media_CV = (Renda_Media_SE / Renda_Media) * 100
  )

# 2. Teste de Hipótese / Filtro de Confiabilidade
# Marcar estimativas que não possuem precisão amostral recomendada
dados_analise <- dados_analise %>%
  mutate(
    Status_Confianca = case_when(
      is.na(Taxa_Desocupacao) ~ "Sem Amostra",
      Taxa_Desocupacao_CV > 30 ~ "Não Confiável (CV > 30%)",
      .default = "Confiável"
    )
  )

# Salvar relatório com flags de erro
write_csv(dados_analise, "dados_saida/base_com_teste_confiabilidade.csv")

# ==============================================================================
# VISUALIZAÇÕES E GRÁFICOS DE VALIDAÇÃO
# ==============================================================================

# 1. Boxplot: Distribuição do Erro Padrão por Nível Geográfico
# Ajuda a ver quais níveis geográficos sofrem mais com variabilidade extrema
ggplot(dados_analise %>% filter(!is.na(Renda_Media_SE)), aes(x = Nivel_Geografico, y = Renda_Media_SE, fill = Nivel_Geografico)) +
  geom_boxplot(alpha = 0.7, outlier.color = "red") +
  theme_minimal() +
  labs(
    title = "Variabilidade do Erro Padrão da Renda por Estrato",
    subtitle = "Pontos vermelhos indicam subamostragens críticas (Outliers)",
    x = "Nível de Desagregação Geográfica",
    y = "Erro Padrão (SE) da Renda"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave("dados_saida/boxplot_erros_renda.png", width = 8, height = 6)

# 2. Histograma: Distribuição dos Coeficientes de Variação da Desocupação
# Se o histograma acumular muito após a linha de 30, significa que o recorte demográfico cruzado quebrou a amostra
ggplot(dados_analise %>% filter(!is.na(Taxa_Desocupacao_CV)), aes(x = Taxa_Desocupacao_CV)) +
  geom_histogram(binwidth = 5, fill = "cadetblue", color = "white", alpha = 0.8) +
  geom_vline(xintercept = 30, color = "red", linetype = "dashed", size = 1) +
  theme_minimal() +
  labs(
    title = "Distribuição do Coeficiente de Variação (CV%) - Taxa de Desocupação",
    subtitle = "Valores à direita da linha vermelha (30%) possuem qualidade amostral comprometida",
    x = "Coeficiente de Variação (%)",
    y = "Frequência de Cruzamentos Amostrais"
  )
ggsave("dados_saida/histograma_cv_desocupacao.png", width = 8, height = 6)

# 3. Série Temporal: Evolução da Renda Média por Estrato Agregado do Piauí
# Exemplo de linha temporal filtrando apenas cruzamentos válidos por Sexo
df_plot_serie <- dados_analise %>%
  filter(Nivel_Geografico == "Estrato_agregado", Recorte_Demografico == "Sexo")

ggplot(df_plot_serie, aes(x = Periodo, y = Renda_Media, group = interaction(Categoria_Geo, Categoria_Demo), color = Categoria_Geo)) +
  geom_line(size = 1) +
  geom_point(size = 2) +
  facet_wrap(~Categoria_Demo) +
  theme_minimal() +
  labs(
    title = "Série Histórica: Renda Média Mensal por Estrato Agregado (PI)",
    subtitle = "Quebra por Sexo - Série de 4T2025 a 2T2026",
    x = "Trimestre de Referência",
    y = "Renda Média (R$)",
    color = "Região do Piauí"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave("dados_saida/serie_temporal_renda_estratos.png", width = 10, height = 6)

message("Gráficos de validação salvos com sucesso na pasta 'dados_saida/'!")