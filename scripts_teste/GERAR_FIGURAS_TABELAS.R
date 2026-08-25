# ==============================================================================
# 03_comparacoes_indicadores.R — tabelas e gráficos comparando o VALOR de
# cada indicador entre as categorias de cada tipo de desagregação:
#   - Geográfica (Zona, Estrato administrativo, Estrato agregado, Agregados
#     nacionais): TABELA + GRÁFICO (estimativa ± IC 95% por categoria)
#   - Demográfica (Sexo, Faixa etária, Instrução): só TABELA, sem gráfico —
#     por pedido explícito, os boxplots ficam restritos ao recorte "Total"
#
# É o "03" que ficou faltando do plano original (o pipeline_trimestre.R
# cobre coleta + indicadores + testes de significância + a confiabilidade
# via CV, mas não essas comparações). Lê a base_<trimestre>.csv já pronta —
# não baixa nada de novo. Se existir testes_significancia_<trimestre>.csv,
# a tabela demográfica sai com o p-valor do teste de diferença anexado.
# ==============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(purrr)
library(ggplot2)

ANO_REF       <- 2026
TRIMESTRE_REF <- 2
sufixo <- sprintf("%dT%d", ANO_REF, TRIMESTRE_REF)

dir.create("output/figuras", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tabelas", recursive = TRUE, showWarnings = FALSE)

base <- read_csv(sprintf("output/base_%s.csv", sufixo), show_col_types = FALSE)

caminho_testes <- sprintf("output/testes_significancia_%s.csv", sufixo)
testes <- if (file.exists(caminho_testes)) read_csv(caminho_testes, show_col_types = FALSE) else NULL

base <- base %>%
  mutate(
    CV     = ifelse(Estimativa != 0, abs(SE / Estimativa) * 100, NA_real_),
    IC_inf = Estimativa - 1.96 * SE,
    IC_sup = Estimativa + 1.96 * SE,
    Tipo_Geo = case_when(
      Regiao_Geografica %in% c("Brasil", "Nordeste", "Piauí", "Teresina") ~ "Agregados nacionais",
      str_starts(Regiao_Geografica, "Zona_")  ~ "Zona",
      str_starts(Regiao_Geografica, "Admin_") ~ "Estrato administrativo",
      str_starts(Regiao_Geografica, "Agreg_") ~ "Estrato agregado",
      TRUE ~ "Outro"
    )
  )

geografias_finas <- base %>%
  filter(!Regiao_Geografica %in% c("Brasil", "Nordeste", "Piauí", "Teresina")) %>%
  pull(Regiao_Geografica) %>% unique()

# ---- 1. Comparação geográfica (Recorte_Demografico == "Total") -------------
# Um indicador pode ter mais de uma "Subcategoria_Indicador" (os de motivo
# têm várias linhas, uma por opção de resposta) — separo por subcategoria
# também pra não misturar coisas diferentes no mesmo gráfico.

geo <- base %>% filter(Recorte_Demografico == "Total")

tabela_geo <- geo %>%
  select(Indicador, Subcategoria_Indicador, Tipo_Geo, Regiao_Geografica,
         Estimativa, SE, CV, IC_inf, IC_sup) %>%
  arrange(Indicador, Tipo_Geo, Regiao_Geografica)
write_csv(tabela_geo, sprintf("output/tabelas/comparacao_geografica_%s.csv", sufixo))

combinacoes_geo <- geo %>% distinct(Indicador, Subcategoria_Indicador)

for (i in seq_len(nrow(combinacoes_geo))) {
  ind <- combinacoes_geo$Indicador[i]
  sub <- combinacoes_geo$Subcategoria_Indicador[i]
  
  d <- geo %>% filter(Indicador == ind, Subcategoria_Indicador == sub, Tipo_Geo != "Outro")
  if (n_distinct(d$Regiao_Geografica) < 2) next
  
  p <- ggplot(d, aes(x = reorder(Regiao_Geografica, Estimativa), y = Estimativa)) +
    geom_pointrange(aes(ymin = IC_inf, ymax = IC_sup), color = "steelblue") +
    coord_flip() +
    facet_wrap(~Tipo_Geo, scales = "free", ncol = 2) +
    labs(title = paste(ind, "—", sufixo),
         subtitle = "Ponto = estimativa; barra = intervalo de confiança de 95%",
         x = NULL, y = "Estimativa") +
    theme_minimal(base_size = 9)
  
  nome_arq <- sprintf("output/figuras/comp_geo_%s.png", make.names(ind))
  ggsave(nome_arq, p, width = 10, height = 7)
}

message("Comparação geográfica: tabela + ", nrow(combinacoes_geo), " gráfico(s) salvos.")

# ---- 2. Comparação demográfica (Sexo / Faixa etária / Instrução) -----------
# Um painel por geografia fina, dentro de cada indicador x recorte.

demo <- base %>% filter(Recorte_Demografico %in% c("Sexo", "Faixa_Etaria_trabalho", "Instrucao"))

tabela_demo <- demo %>%
  select(Indicador, Subcategoria_Indicador, Regiao_Geografica, Recorte_Demografico,
         Categoria_Demografica, Estimativa, SE, CV, IC_inf, IC_sup)

if (!is.null(testes)) {
  tabela_demo <- tabela_demo %>%
    left_join(
      testes %>% select(Indicador, Regiao_Geografica, Recorte_Demografico, p_valor) %>% distinct(),
      by = c("Indicador", "Regiao_Geografica", "Recorte_Demografico")
    )
} else {
  tabela_demo$p_valor <- NA_real_
  message("Aviso: testes_significancia_", sufixo, ".csv não encontrado — tabela demográfica sai sem p-valor.")
}

tabela_demo <- tabela_demo %>% arrange(Indicador, Recorte_Demografico, Regiao_Geografica)
write_csv(tabela_demo, sprintf("output/tabelas/comparacao_demografica_%s.csv", sufixo))

message("Comparação demográfica: só tabela, como pedido (sem gráfico) — ",
        nrow(tabela_demo), " linhas em comparacao_demografica_", sufixo, ".csv")
message("Concluído: tabelas em output/tabelas/, gráficos em output/figuras/")