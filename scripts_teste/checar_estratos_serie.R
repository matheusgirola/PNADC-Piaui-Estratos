# Checagem (17/09/2026): classificação dos estratos do Piauí ao longo dos trimestres
# (Zona/Estrato_Admin/Estrato_agregado). Resultado registrado em CONTEXTO_PROJETO.md §8.5.
# Roda sobre os pi_*.rds (2022T3+); para 2016T2+ trocar pelo cache nacional.
suppressMessages({library(dplyr); library(survey)})
source("R/derivar_variaveis.R", encoding = "UTF-8")
res <- list()
for (f in sort(list.files("data/raw", pattern = "^pi_\\d{4}_\\d\\.rds$", full.names = TRUE))) {
  d <- suppressMessages(derivar_variaveis(readRDS(f), sm_hora = 7))
  v <- d$variables
  res[[basename(f)]] <- tibble(arq = basename(f), Estrato = as.character(v$Estrato),
                               Zona = v$Zona, Admin = v$Estrato_Admin, Agreg = v$Estrato_agregado) %>%
    distinct()
}
r <- bind_rows(res)
cat("Estratos distintos por trimestre e NAs de classificação:\n")
print(as.data.frame(r %>% group_by(arq) %>% summarise(n_estr = n_distinct(Estrato), na_zona = sum(is.na(Zona)),
        na_admin = sum(is.na(Admin)), na_agreg = sum(is.na(Agreg)), .groups = "drop")))
todos <- r %>% distinct(Estrato, Zona, Admin, Agreg)
cat("\nEstrato com classificação diferente entre trimestres:", sum(duplicated(todos$Estrato)), "\n")
ult <- unique(r$Estrato[r$arq == "pi_2026_2.rds"]); pri <- unique(r$Estrato[r$arq == "pi_2022_3.rds"])
cat("Estratos em 2022T3 e não em 2026T2:", paste(setdiff(pri, ult), collapse = " "), "\n")
cat("Estratos em 2026T2 e não em 2022T3:", paste(setdiff(ult, pri), collapse = " "), "\n")
cat("\nCategorias por trimestre (antigo x novo):\n")
for (a in c("pi_2025_2.rds", "pi_2026_2.rds")) {
  x <- r[r$arq == a, ]
  cat(a, "| Agreg:", paste(sort(unique(x$Agreg)), collapse = "; "), "| Admin:", paste(sort(unique(x$Admin)), collapse = "; "), "| Zona:", paste(sort(unique(x$Zona)), collapse = "; "), "\n")
}
cat("\nEstratos novos -> classificação:\n"); print(as.data.frame(todos[todos$Estrato %in% setdiff(ult, pri), ]))
