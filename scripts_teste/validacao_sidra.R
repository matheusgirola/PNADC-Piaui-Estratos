# ==============================================================================
# validacao_sidra.R — confere os indicadores de mercado de trabalho do
# catálogo (R/indicadores.R) contra os valores oficiais publicados no SIDRA.
# Mapa, tolerâncias e conferências ficam no módulo R/sidra.R, compartilhado
# com o teste de aceitação tests/acceptance/test-sidra.R (um trimestre).
#
# Roda sobre o cache nacional data/raw/pnadc_br_<ano>_<tri>.rds
# (R/01a_cache_pnadc.R) e valida Brasil (N1), Nordeste (N2[2]) e Piauí (N3[22]).
# Retomável: o resultado de cada trimestre fica em dados_saida/validacao/ e só
# é recalculado se o arquivo for apagado. Para um trimestre só:
#   Rscript scripts_teste/validacao_sidra.R 2026 2
# ==============================================================================

library(readr)
library(tidyr)

source("R/derivar_variaveis.R", encoding = "UTF-8")
source("R/indicadores.R", encoding = "UTF-8")
source("R/sidra.R", encoding = "UTF-8")
source("R/00_config.R", encoding = "UTF-8")  # tabela_salario_minimo
source("R/01a_cache_pnadc.R", encoding = "UTF-8")  # enxugar_pnadc()

# ---- Execução ------------------------------------------------------------------

arquivos <- list.files("data/raw", pattern = "^pnadc_br_\\d{4}_\\d\\.rds$", full.names = TRUE)
trimestres <- tibble(arquivo = arquivos) %>%
  mutate(ano = as.integer(sub(".*pnadc_br_(\\d{4})_\\d\\.rds", "\\1", arquivo)),
         tri = as.integer(sub(".*pnadc_br_\\d{4}_(\\d)\\.rds", "\\1", arquivo)),
         periodo = periodo_sidra(ano, tri)) %>%
  arrange(ano, tri)

# Valores oficiais da série inteira (2016T2 até o trimestre de R/00_config.R),
# buscados ANTES do laço pesado: um problema na API ou uma categoria que não
# existe nos trimestres antigos aparece em segundos, não depois de horas.
# Chave de cache fixa (série inteira), independente de quais .rds já existem.
periodos <- periodos_serie(ANO_REF, TRIMESTRE_REF)
oficiais <- pmap_dfr(territorios, function(territorio, localidade, id_localidade) {
  buscar_oficiais(territorio, localidade, periodos)
})
message(sprintf("SIDRA: %d valores oficiais (%d NA) para %d períodos.",
                nrow(oficiais), sum(is.na(oficiais$oficial)), length(periodos)))

args <- commandArgs(trailingOnly = TRUE)
if (identical(args, "sidra")) quit(save = "no")  # só pré-busca do SIDRA
if (length(args) == 2) {
  trimestres <- filter(trimestres, ano == as.integer(args[1]), tri == as.integer(args[2]))
}
if (nrow(trimestres) == 0) stop("Nenhum data/raw/pnadc_br_*.rds encontrado para validar.")

dir_parcial <- "dados_saida/validacao"
dir.create(dir_parcial, recursive = TRUE, showWarnings = FALSE)
dir.create("output/tabelas", recursive = TRUE, showWarnings = FALSE)

ids <- unique(mapa$Indicador)

# Territórios recalculados por trimestre; os oficiais acima continuam os três,
# para o resumo final ler também os parciais antigos (Brasil/Nordeste).
TERRITORIOS_SERIE <- "Piauí"

for (i in seq_len(nrow(trimestres))) {
  t <- trimestres[i, ]
  parcial <- file.path(dir_parcial, sprintf("validacao_%d_%d.rds", t$ano, t$tri))
  if (file.exists(parcial)) next
  message(sprintf("[%s] Validando %dT%d...", format(Sys.time(), "%H:%M:%S"), t$ano, t$tri))
  sm <- tabela_salario_minimo$sm_hora[tabela_salario_minimo$ano == t$ano]
  # Decisão de 17/09/2026: a série valida só o Piauí (Brasil e Nordeste já
  # passaram em 2016T2 e 2026T2; os parciais com os três territórios ficam).
  # Recorta ANTES de derivar e estimar: o cálculo com os 200 pesos replicados
  # sobre as ~520 mil linhas do Brasil é o que levava a RAM a ~9 GB. Resultado
  # do Piauí idêntico ao do recorte feito depois (conferido em 2016T4).
  bruto <- enxugar_pnadc(readRDS(t$arquivo))  # só as colunas usadas (R/01a_cache_pnadc.R)
  if (identical(TERRITORIOS_SERIE, "Piauí")) bruto <- bruto[bruto$variables$UF == "Piauí", ]
  gc()
  d_br <- derivar_variaveis(bruto, sm_hora = sm)
  rm(bruto)

  res <- list(comparacoes = list(), internas = list(), ginis = list())
  for (terr in TERRITORIOS_SERIE) {
    d <- recortar(d_br, terr)
    res$comparacoes[[terr]] <- estimar_catalogo(d, ids) %>%
      mutate(territorio = terr, periodo = t$periodo, ano = t$ano, tri = t$tri)
    res$internas[[terr]] <- checagens_internas(d) %>%
      mutate(territorio = terr, ano = t$ano, tri = t$tri)
    res$ginis[[terr]] <- conferir_gini(d) %>%
      mutate(territorio = terr, ano = t$ano, tri = t$tri, .before = 1)
  }
  saveRDS(lapply(res, bind_rows), parcial)
  rm(d_br, d); gc()
}

# Junta todos os trimestres já validados (não só os desta execução)
parciais <- lapply(list.files(dir_parcial, pattern = "^validacao_\\d{4}_\\d\\.rds$",
                              full.names = TRUE), readRDS)
comparacoes <- bind_rows(lapply(parciais, `[[`, "comparacoes"))
internas    <- bind_rows(lapply(parciais, `[[`, "internas"))
ginis       <- bind_rows(lapply(parciais, `[[`, "ginis"))

resultado <- comparar_com_sidra(comparacoes, oficiais) %>%
  select(territorio, ano, tri, Indicador, Subcategoria_Indicador, tabela, variavel, categoria,
         estimado, oficial, diferenca, ok, CV) %>%
  arrange(territorio, ano, tri)

ginis <- ginis %>%
  mutate(ok = gini_confere(.))

write_csv(resultado, "output/tabelas/validacao_sidra.csv")
write_csv(internas,  "output/tabelas/validacao_checagens_internas.csv")
write_csv(ginis,     "output/tabelas/validacao_gini.csv")

message(sprintf("SIDRA: %d de %d comparações dentro da tolerância; %d sem valor oficial.",
                sum(resultado$ok, na.rm = TRUE), nrow(resultado), sum(is.na(resultado$oficial))))
message(sprintf("Checagens internas: %d de %d ok.", sum(internas$ok), nrow(internas)))
message(sprintf("Gini: %d de %d idênticos à implementação independente.", sum(ginis$ok), nrow(ginis)))
