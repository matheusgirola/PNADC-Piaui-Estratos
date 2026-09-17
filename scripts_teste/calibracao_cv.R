# ==============================================================================
# calibracao_cv.R — Etapa 3, passo 1 (CONTEXTO_PROJETO.md §8.5): confere o CV
# do projeto (100 · SE / Estimativa, bootstrap de 200 réplicas do svrepdesign)
# contra o coeficiente de variação publicado pelo IBGE no SIDRA.
#
# Não carrega microdado: usa os SE já gravados pela validação em
# dados_saida/validacao/validacao_<ano>_<tri>.rds (Brasil, Nordeste, Piauí).
# Pode rodar com a série parcial; rodar de novo quando ela terminar.
#
# CV oficial (API v3 de agregados; variável de valor -> variável de CV,
# conferido nos metadados das tabelas em 17/09/2026):
#   1641 PIT -> 4087         4104 distribuição % da PIT -> 4105
#   4088 FT -> 4089          4090 ocupados -> 4091
#   4092 desocupados -> 4093 4094 fora da FT -> 4095
#   4096 participação -> 4100 4097 nível da ocupação -> 4101
#   4099 desocupação -> 4103 4118 taxa composta de subutilização -> 4119
#
# Critério: o SIDRA publica o CV em % com uma casa, logo tolerância 0,05 p.p.
#
# Uso: Rscript scripts_teste/calibracao_cv.R
# Saída: output/tabelas/calibracao_cv.csv + resumo no console.
# ==============================================================================

suppressMessages({library(dplyr); library(tibble); library(purrr); library(jsonlite); library(readr)})

# Mapa indicador -> série oficial e buscador do SIDRA: reaproveitados da validação.
src <- readLines("scripts_teste/validacao_sidra.R", encoding = "UTF-8")
eval(parse(text = src[grep("^mapa <- tribble", src):(grep("^# ---- 3\\. Estimativas", src) - 1)],
           encoding = "UTF-8"))

var_cv <- c("1641" = 4087, "4104" = 4105, "4088" = 4089, "4090" = 4091, "4092" = 4093,
            "4094" = 4095, "4096" = 4100, "4097" = 4101, "4099" = 4103, "4118" = 4119)
mapa_cv <- mapa %>% mutate(variavel_cv = unname(var_cv[as.character(variavel)]))
stopifnot(!anyNA(mapa_cv$variavel_cv))

territorios <- tribble(
  ~territorio, ~localidade,
  "Brasil",    "N1[all]",
  "Nordeste",  "N2[2]",
  "Piauí",     "N3[22]"
)

# Mesma grade de períodos da validação (2016T2–2026T2) — chave de cache estável.
periodos <- unique(sort(unlist(lapply(
  list.files("data/raw/sidra", pattern = "^t4093_N1all_\\d+_\\d+_\\d+\\.rds$"),
  function(f) readRDS(file.path("data/raw/sidra", f))$periodo))))
stopifnot(length(periodos) >= 41)

oficiais_cv <- pmap_dfr(territorios, function(territorio, localidade) {
  mapa_cv %>% distinct(tabela, classificacao) %>%
    pmap_dfr(function(tabela, classificacao) {
      vars <- mapa_cv$variavel_cv[mapa_cv$tabela == tabela]
      buscar_sidra(tabela, vars, classificacao, periodos, localidade, prefixo = "cv_t")
    }) %>%
    mutate(territorio = territorio)
}) %>%
  rename(variavel_cv = variavel, cv_oficial = oficial) %>%
  select(-localidade)

parciais <- list.files("dados_saida/validacao", pattern = "^validacao_\\d{4}_\\d\\.rds$", full.names = TRUE)
nossos <- map_dfr(parciais, function(f) readRDS(f)$comparacoes)

res <- nossos %>%
  inner_join(mapa_cv, by = c("Indicador", "Subcategoria_Indicador")) %>%
  left_join(oficiais_cv, by = c("territorio", "tabela", "variavel_cv", "categoria", "periodo")) %>%
  mutate(cv_projeto = 100 * SE / Estimativa,
         dif = cv_projeto - cv_oficial,
         ok = abs(dif) <= 0.05 + 1e-6) %>%
  select(territorio, periodo, Indicador, Subcategoria_Indicador, tabela, variavel_cv, categoria,
         Estimativa, SE, cv_projeto, cv_oficial, dif, ok) %>%
  arrange(territorio, Indicador, Subcategoria_Indicador, periodo)

dir.create("output/tabelas", recursive = TRUE, showWarnings = FALSE)
write_csv(res, "output/tabelas/calibracao_cv.csv")

cat(sprintf("Trimestres: %d | comparações: %d | ok: %d | fora da tolerância: %d | sem CV oficial: %d\n",
            length(parciais), nrow(res), sum(res$ok, na.rm = TRUE),
            sum(res$ok %in% FALSE), sum(is.na(res$cv_oficial))))
cat("\nPor território e indicador (dif = CV projeto − CV oficial, p.p.):\n")
print(as.data.frame(res %>% filter(!is.na(ok)) %>%
  group_by(territorio, Indicador) %>%
  summarise(n = n(), ok = sum(ok), dif_max = round(max(abs(dif)), 3),
            cv_oficial_mediano = median(cv_oficial), .groups = "drop")), row.names = FALSE)
fora <- filter(res, ok %in% FALSE)
if (nrow(fora)) {
  cat("\nPrimeiras linhas fora da tolerância:\n")
  print(as.data.frame(head(select(fora, territorio, periodo, Subcategoria_Indicador,
                                  cv_projeto, cv_oficial, dif), 20)), row.names = FALSE)
}
