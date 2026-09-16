# ==============================================================================
# validacao_sidra.R — confere os indicadores de mercado de trabalho do
# catálogo (R/indicadores.R) contra os valores oficiais publicados no SIDRA.
#
# Fonte oficial: API de agregados do IBGE (servicodados.ibge.gov.br/api/v3).
# A API do apisidra.ibge.gov.br, usada pelo pacote sidrar, fica atrás de um
# desafio do Cloudflare e devolve HTTP 403 pra requisição automatizada.
#
# Tabelas trimestrais usadas (PNAD Contínua):
#   4093  condição na FT, taxas e níveis, por sexo
#   4094  idem, por grupo de idade
#   4095  idem, por nível de instrução
#   6402  idem, por cor ou raça
#   4097  ocupados por posição na ocupação e categoria do emprego
#   5434  ocupados por grupamento de atividade
#   4099  taxas de desocupação e subutilização
#   4100  pessoas por tipo de medida de subutilização
#
# Critério: diferença dentro do arredondamento do SIDRA — totais publicados
# em mil pessoas inteiras (tolerância 0,5 mil), percentuais com uma casa
# (tolerância 0,05 p.p.). Uma folga de 1e-6 cobre erro de ponto flutuante.
#
# Hoje roda sobre os data/raw/pi_<ano>_<tri>.rds (só Piauí). Quando o cache
# nacional existir (Etapa 2), passa a cobrir Brasil e Nordeste também.
#
# O Gini não tem série trimestral no SIDRA: é conferido contra uma
# implementação independente (diferença média absoluta ponderada).
# ==============================================================================

library(jsonlite)
library(readr)
library(tidyr)

source("R/derivar_variaveis.R", encoding = "UTF-8")
source("R/indicadores.R", encoding = "UTF-8")
source("R/00_config.R", encoding = "UTF-8")  # tabela_salario_minimo

dir.create("data/raw/sidra", recursive = TRUE, showWarnings = FALSE)

# ---- 1. Mapa indicador do catálogo -> série oficial ----------------------------
# escala: fator que leva a estimativa do catálogo à unidade do SIDRA
# (pessoas -> mil pessoas; proporção -> %).

mapa <- tribble(
  ~Indicador,                     ~Subcategoria_Indicador,   ~tabela, ~variavel, ~classificacao, ~categoria, ~escala,
  "Pessoas_Idade_Trabalhar",      "pit",                     4093, 1641, 2, 6794, 1e-3,
  "Pessoas_Forca_Trabalho",       "ft",                      4093, 4088, 2, 6794, 1e-3,
  "Pessoas_Fora_Forca",           "fora_ft",                 4093, 4094, 2, 6794, 1e-3,
  "Pessoas_Ocupadas",             "ocup",                    4093, 4090, 2, 6794, 1e-3,
  "Pessoas_Desocupadas",          "desocup",                 4093, 4092, 2, 6794, 1e-3,
  "Taxa_Participacao",            "ft/pit",                  4093, 4096, 2, 6794, 100,
  "Nivel_Ocupacao",               "ocup/pit",                4093, 4097, 2, 6794, 100,
  "Taxa_Desocupacao",             "desocup/ft",              4093, 4099, 2, 6794, 100,
  "Empregados_Setor_Privado",     "emp_privado",             4097, 4090, 11913, 31721, 1e-3,
  "Empregados_Setor_Publico",     "emp_publico",             4097, 4090, 11913, 31727, 1e-3,
  "Ocupados_Agropecuaria",        "ocup_agro",               5434, 4090, 888, 47947, 1e-3,
  "Pessoas_Subutilizadas",        "subutil",                 4100, 1641, 604, 40286, 1e-3,
  "Taxa_Composta_Subutilizacao",  "subutil/ft_ampliada",     4099, 4118, NA, NA, 100,
  "PIT_por_Sexo",                 "Sexo_pitMasculino",       4093, 1641, 2, 4, 1e-3,
  "PIT_por_Sexo",                 "Sexo_pitFeminino",        4093, 1641, 2, 5, 1e-3,
  "Distribuicao_PIT_por_Sexo",    "Sexo_pitMasculino",       4093, 4104, 2, 4, 100,
  "Distribuicao_PIT_por_Sexo",    "Sexo_pitFeminino",        4093, 4104, 2, 5, 100,
  "PIT_por_Raca",                 "Raca_pitBranca",          6402, 1641, 86, 2776, 1e-3,
  "PIT_por_Raca",                 "Raca_pitPreta",           6402, 1641, 86, 2777, 1e-3,
  "PIT_por_Raca",                 "Raca_pitParda",           6402, 1641, 86, 2779, 1e-3
)

faixas <- c("14 a 17 anos" = 114535, "18 a 24 anos" = 100052, "25 a 39 anos" = 108875,
            "40 a 59 anos" = 99127, "60 anos ou mais" = 3302)
instrucao <- c("Sem instrução e menos de 1 ano de estudo" = 120706,
               "Fundamental incompleto ou equivalente" = 11779,
               "Fundamental completo ou equivalente" = 11628,
               "Médio incompleto ou equivalente" = 11629,
               "Médio completo ou equivalente" = 11630,
               "Superior incompleto ou equivalente" = 11631,
               "Superior completo" = 11632)

mapa <- bind_rows(
  mapa,
  tibble(Indicador = "PIT_por_Faixa_Etaria_SIDRA",
         Subcategoria_Indicador = paste0("Faixa_Etaria_sidra", names(faixas)),
         tabela = 4094, variavel = 1641, classificacao = 58, categoria = faixas, escala = 1e-3),
  tibble(Indicador = "Distribuicao_PIT_por_Faixa_Etaria_SIDRA",
         Subcategoria_Indicador = paste0("Faixa_Etaria_sidra", names(faixas)),
         tabela = 4094, variavel = 4104, classificacao = 58, categoria = faixas, escala = 100),
  tibble(Indicador = "PIT_por_Instrucao_SIDRA",
         Subcategoria_Indicador = paste0("Instrucao_sidra", names(instrucao)),
         tabela = 4095, variavel = 1641, classificacao = 1568, categoria = instrucao, escala = 1e-3)
)

# ---- 2. Valores oficiais (com cache local) -----------------------------------

periodo_sidra <- function(ano, tri) sprintf("%d%02d", ano, tri)

# Uma chamada por tabela: todas as variáveis, categorias e períodos de uma vez.
buscar_sidra <- function(tabela, variaveis, classificacao, periodos, localidade) {
  arquivo <- sprintf("data/raw/sidra/t%d_%s_%s.rds", tabela,
                     gsub("[^0-9A-Za-z]", "", localidade), digest_periodos(periodos))
  if (file.exists(arquivo)) return(readRDS(arquivo))

  url <- sprintf(
    "https://servicodados.ibge.gov.br/api/v3/agregados/%d/periodos/%s/variaveis/%s?localidades=%s%s",
    tabela, paste(periodos, collapse = "|"), paste(unique(variaveis), collapse = "|"),
    localidade,
    if (is.na(classificacao)) "" else sprintf("&classificacao=%d[all]", classificacao)
  )
  json <- fromJSON(URLencode(url), simplifyVector = FALSE)

  linhas <- list()
  for (v in json) {
    for (res in v$resultados) {
      cat_id <- if (length(res$classificacoes) == 0) NA_integer_ else
        as.integer(names(res$classificacoes[[1]]$categoria)[1])
      for (s in res$series) {
        for (p in names(s$serie)) {
          valor <- suppressWarnings(as.numeric(s$serie[[p]]))
          linhas[[length(linhas) + 1]] <- tibble(
            tabela = tabela, variavel = as.integer(v$id), categoria = cat_id,
            localidade = s$localidade$id, periodo = p, oficial = valor)
        }
      }
    }
  }
  out <- bind_rows(linhas)
  saveRDS(out, arquivo)
  out
}

digest_periodos <- function(periodos) paste0(min(periodos), "_", max(periodos), "_", length(periodos))

# ---- 3. Estimativas do catálogo ------------------------------------------------

estimar_catalogo <- function(design, ids) {
  specs <- Filter(function(s) s$id %in% ids, catalogo_indicadores)
  bind_rows(lapply(specs, function(s) {
    extrair_resultados(computar_estimativa(design, s, NULL), s$id, tem_by = FALSE)
  }))
}

# Checagens internas: identidades que valem por construção. Falhar aqui indica
# erro de fórmula, independentemente do SIDRA.
checagens_internas <- function(d) {
  v <- d$variables
  w <- weights(d, "sampling")
  tot <- function(x) sum(w * x)
  tibble(
    checagem = c("ft + fora_ft == pit",
                 "ocup + desocup == ft",
                 "sexo: soma == pit",
                 "faixa SIDRA: soma == pit",
                 "subutil <= ft_ampliada",
                 "taxa desocupação antiga == nova"),
    ok = c(
      isTRUE(all.equal(tot(v$ft + v$fora_ft), tot(v$pit))),
      isTRUE(all.equal(tot(v$ocup + v$desocup), tot(v$ft))),
      isTRUE(all.equal(tot(!is.na(v$Sexo_pit)), tot(v$pit))),
      isTRUE(all.equal(tot(!is.na(v$Faixa_Etaria_sidra)), tot(v$pit))),
      all(v$subutil <= v$ft_ampliada),
      isTRUE(all.equal(
        as.numeric(coef(svyratio(~VD4002 == "Pessoas desocupadas",
                                 ~VD4001 == "Pessoas na força de trabalho",
                                 d, na.rm = TRUE))),
        as.numeric(coef(svyratio(~desocup, ~ft, d)))))
    )
  )
}

# Gini por diferença média absoluta ponderada (fórmula de Gini original):
#   G_pares = sum_i sum_j w_i w_j |x_i - x_j| / (2 W^2 mu)
# O(n^2), mas n de ocupados com rendimento no Piauí é ~5 mil.
#
# O convey::svygini (CalcGini) usa  sum_i (2 C_i - 1) w_i x_i / (W T) - 1,
# enquanto G_pares equivale a     sum_i (2 C_i - w_i) w_i x_i / (W T) - 1
# (C_i = peso acumulado em ordem crescente, T = sum w x). A diferença entre as
# duas convenções é exatamente sum_i w_i (w_i - 1) x_i / (W T) — ~4e-4 no
# Piauí, duas ordens de grandeza abaixo do erro padrão. A conferência soma esse
# termo, pra que a igualdade testada seja exata e não "parecida".
gini_mad <- function(x, w) {
  mu <- sum(w * x) / sum(w)
  sum(outer(w, w) * abs(outer(x, x, "-"))) / (2 * sum(w)^2 * mu)
}

ajuste_convencao_convey <- function(x, w) sum(w * (w - 1) * x) / (sum(w) * sum(w * x))

# ---- 4. Execução ---------------------------------------------------------------

arquivos <- list.files("data/raw", pattern = "^pi_\\d{4}_\\d\\.rds$", full.names = TRUE)
trimestres <- tibble(arquivo = arquivos) %>%
  mutate(ano = as.integer(sub(".*pi_(\\d{4})_\\d\\.rds", "\\1", arquivo)),
         tri = as.integer(sub(".*pi_\\d{4}_(\\d)\\.rds", "\\1", arquivo)),
         periodo = periodo_sidra(ano, tri)) %>%
  arrange(ano, tri)

localidade <- "N3[22]"  # Piauí

oficiais <- mapa %>%
  distinct(tabela, classificacao) %>%
  pmap_dfr(function(tabela, classificacao) {
    vars <- mapa$variavel[mapa$tabela == tabela]
    buscar_sidra(tabela, vars, classificacao, trimestres$periodo, localidade)
  })

ids <- unique(mapa$Indicador)
comparacoes <- list(); internas <- list(); ginis <- list()

for (i in seq_len(nrow(trimestres))) {
  t <- trimestres[i, ]
  message(sprintf("Validando %dT%d...", t$ano, t$tri))
  sm <- tabela_salario_minimo$sm_hora[tabela_salario_minimo$ano == t$ano]
  d  <- derivar_variaveis(readRDS(t$arquivo), sm_hora = sm)

  comparacoes[[i]] <- estimar_catalogo(d, ids) %>%
    mutate(periodo = t$periodo, ano = t$ano, tri = t$tri)

  internas[[i]] <- checagens_internas(d) %>% mutate(ano = t$ano, tri = t$tri)

  spec_gini <- Filter(function(s) s$id == "Gini_Rendimento_Habitual_Trabalho",
                      catalogo_indicadores)[[1]]
  g  <- computar_estimativa(d, spec_gini, NULL)
  dg <- aplicar_subset(d, spec_gini$subset)
  ginis[[i]] <- tibble(ano = t$ano, tri = t$tri,
                       gini_catalogo = as.numeric(coef(g)),
                       cv = 100 * as.numeric(SE(g)) / as.numeric(coef(g)),
                       gini_pares = gini_mad(dg$variables$VD4019, dg$pweights),
                       ajuste_convencao = ajuste_convencao_convey(dg$variables$VD4019, dg$pweights))
}

resultado <- bind_rows(comparacoes) %>%
  inner_join(mapa, by = c("Indicador", "Subcategoria_Indicador")) %>%
  left_join(oficiais %>% mutate(categoria = as.numeric(categoria)),
            by = c("tabela", "variavel", "categoria", "periodo")) %>%
  mutate(
    estimado  = Estimativa * escala,
    diferenca = estimado - oficial,
    tolerancia = ifelse(escala == 100, 0.05, 0.5) + 1e-6,
    ok = abs(diferenca) <= tolerancia,
    CV = 100 * SE / Estimativa
  ) %>%
  select(ano, tri, Indicador, Subcategoria_Indicador, tabela, variavel, categoria,
         estimado, oficial, diferenca, ok, CV)

internas <- bind_rows(internas)
ginis <- bind_rows(ginis) %>%
  mutate(ok = abs(gini_catalogo - (gini_pares + ajuste_convencao)) < 1e-9)

write_csv(resultado, "output/tabelas/validacao_sidra.csv")
write_csv(internas,  "output/tabelas/validacao_checagens_internas.csv")
write_csv(ginis,     "output/tabelas/validacao_gini.csv")

message(sprintf("SIDRA: %d de %d comparações dentro da tolerância; %d sem valor oficial.",
                sum(resultado$ok, na.rm = TRUE), nrow(resultado), sum(is.na(resultado$oficial))))
message(sprintf("Checagens internas: %d de %d ok.", sum(internas$ok), nrow(internas)))
message(sprintf("Gini: %d de %d idênticos à implementação independente.", sum(ginis$ok), nrow(ginis)))
