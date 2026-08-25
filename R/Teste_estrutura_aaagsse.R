# ==============================================================================
# teste_estrutura_aaagsse.R — confere se a estrutura AAAGGSE (Nota Técnica
# 03/2025 do IBGE) bate com as classificações Zona/Estrato_Admin/
# Estrato_agregado que você já validou no crosswalk. Não baixa nada novo —
# só reanalisa o output/crosswalk_estratos.csv que o pipeline_trimestre.R
# já gera.
#
# Lógica do código de 7 dígitos, segundo a Nota Técnica 03/2025:
#   AAA (pos. 1-3) = administrativo (capital/RM/RIDE/demais)
#   GG  (pos. 4-5) = Região Geográfica Imediata/Intermediária
#   S   (pos. 6)   = situação/tipo de área (urbano tradicional x FCU)
#   E   (pos. 7)   = estrato estatístico (faixa de renda do responsável)
#
# Se os 3 primeiros dígitos baterem 1:1 com Estrato_Admin, e os 5 primeiros
# com Estrato_agregado, confirma a hipótese — e me diz que dá pra reagregar
# os setores por esses cortes (3 e 5 dígitos) em vez dos 4 que eu tinha
# usado, e que S/E realmente não são espaciais (não faz sentido buscar
# fronteira geográfica pra eles).
# ==============================================================================

library(dplyr)
library(readr)

crosswalk <- read_csv("output/crosswalk_estratos.csv", show_col_types = FALSE) %>%
  mutate(Estrato = as.character(Estrato))

crosswalk <- crosswalk %>%
  mutate(
    AAA = substr(Estrato, 1, 3),
    GG  = substr(Estrato, 4, 5),
    AAAGG = substr(Estrato, 1, 5),
    S   = substr(Estrato, 6, 6),
    E   = substr(Estrato, 7, 7)
  )

cat("\n--- AAA (3 dígitos) prediz Estrato_Admin? ---\n")
teste_admin <- crosswalk %>%
  group_by(AAA) %>%
  summarise(n_estratos = n(), n_valores_Admin = n_distinct(Estrato_Admin),
            valores = paste(unique(Estrato_Admin), collapse = " | "), .groups = "drop")
print(teste_admin)
cat("Grupos com mais de 1 valor de Estrato_Admin (esperado: nenhum, se a hipótese for certa):",
    sum(teste_admin$n_valores_Admin > 1), "\n")

cat("\n--- AAAGG (5 dígitos) prediz Estrato_agregado? ---\n")
teste_agreg <- crosswalk %>%
  group_by(AAAGG) %>%
  summarise(n_estratos = n(), n_valores_Agreg = n_distinct(Estrato_agregado),
            valores = paste(unique(Estrato_agregado), collapse = " | "), .groups = "drop")
print(teste_agreg)
cat("Grupos com mais de 1 valor de Estrato_agregado (esperado: nenhum, se a hipótese for certa):",
    sum(teste_agreg$n_valores_Agreg > 1), "\n")

cat("\n--- E os 4 dígitos que eu tinha usado antes, pra comparar? ---\n")
crosswalk <- crosswalk %>% mutate(Estrato4 = substr(Estrato, 1, 4))
teste_4d <- crosswalk %>%
  group_by(Estrato4) %>%
  summarise(n_valores_Admin = n_distinct(Estrato_Admin), n_valores_Agreg = n_distinct(Estrato_agregado),
            .groups = "drop")
cat("Grupos de 4 dígitos com Estrato_Admin misto:", sum(teste_4d$n_valores_Admin > 1), "\n")
cat("Grupos de 4 dígitos com Estrato_agregado misto:", sum(teste_4d$n_valores_Agreg > 1), "\n")

cat("\n--- Quantos estratos de 7 dígitos únicos existem por combinação AAAGG (deveria ser >1 se S/E não são espaciais) ---\n")
print(crosswalk %>% count(AAAGG, name = "n_estratos_7digitos_dentro"))