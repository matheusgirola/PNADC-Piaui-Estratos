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
# Roda sobre o cache nacional data/raw/pnadc_br_<ano>_<tri>.rds
# (R/01a_cache_pnadc.R) e valida Brasil (N1), Nordeste (N2[2]) e Piauí (N3[22]).
# Retomável: o resultado de cada trimestre fica em dados_saida/validacao/ e só
# é recalculado se o arquivo for apagado. Para um trimestre só:
#   Rscript scripts_teste/validacao_sidra.R 2026 2
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
source("R/01a_cache_pnadc.R", encoding = "UTF-8")  # enxugar_pnadc()

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
# prefixo: nome do cache local ("t" = valores; a calibração do CV usa "cv_t").
buscar_sidra <- function(tabela, variaveis, classificacao, periodos, localidade, prefixo = "t") {
  arquivo <- sprintf("data/raw/sidra/%s%d_%s_%s.rds", prefixo, tabela,
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
# A soma dupla é O(n^2) — inviável para o Brasil (~200 mil ocupados com
# rendimento). Com x ordenado, sum_j w_j |x_i - x_j| = x_i L_i - S_i^L +
# S_i^R - x_i R_i, onde L/R são o peso abaixo/acima de i e S^L/S^R as somas
# de w x abaixo/acima; empates contribuem |x_i - x_j| = 0 de qualquer lado,
# então a ordem entre eles não importa. Mesma soma, O(n log n).
#
# O convey::svygini (CalcGini) usa  sum_i (2 C_i - 1) w_i x_i / (W T) - 1,
# enquanto G_pares equivale a     sum_i (2 C_i - w_i) w_i x_i / (W T) - 1
# (C_i = peso acumulado em ordem crescente, T = sum w x). A diferença entre as
# duas convenções é exatamente sum_i w_i (w_i - 1) x_i / (W T) — ~4e-4 no
# Piauí, duas ordens de grandeza abaixo do erro padrão. A conferência soma esse
# termo, pra que a igualdade testada seja exata e não "parecida".
gini_mad <- function(x, w) {
  o <- order(x); x <- x[o]; w <- w[o]
  W <- sum(w); T <- sum(w * x)
  C <- cumsum(w); S <- cumsum(w * x)
  L  <- C - w;  SL <- S - w * x      # estritamente antes de i na ordem
  R  <- W - C;  SR <- T - S          # estritamente depois
  soma_dupla <- sum(w * (x * L - SL + SR - x * R))
  soma_dupla / (2 * W^2 * (T / W))
}

ajuste_convencao_convey <- function(x, w) sum(w * (w - 1) * x) / (sum(w) * sum(w * x))

# ---- 4. Execução ---------------------------------------------------------------

# Territórios validados: filtro sobre as derivadas + localidade na API v3.
territorios <- tribble(
  ~territorio, ~localidade, ~id_localidade,
  "Brasil",    "N1[all]",   "1",
  "Nordeste",  "N2[2]",     "2",
  "Piauí",     "N3[22]",    "22"
)
recortar <- function(d, territorio) {
  switch(territorio,
         "Brasil"   = d,
         "Nordeste" = d[d$variables$Regiao == "Nordeste", ],
         "Piauí"    = d[d$variables$UF == "Piauí", ])
}

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
grade <- expand.grid(tri = 1:4, ano = 2016:ANO_REF)
grade <- subset(grade, !(ano == 2016 & tri < 2) & !(ano == ANO_REF & tri > TRIMESTRE_REF))
periodos <- periodo_sidra(grade$ano, grade$tri)
oficiais <- pmap_dfr(territorios, function(territorio, localidade, id_localidade) {
  mapa %>%
    distinct(tabela, classificacao) %>%
    pmap_dfr(function(tabela, classificacao) {
      vars <- mapa$variavel[mapa$tabela == tabela]
      buscar_sidra(tabela, vars, classificacao, periodos, localidade)
    }) %>%
    mutate(territorio = territorio)
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
spec_gini <- Filter(function(s) s$id == "Gini_Rendimento_Habitual_Trabalho",
                    catalogo_indicadores)[[1]]

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
    g  <- computar_estimativa(d, spec_gini, NULL)
    dg <- aplicar_subset(d, spec_gini$subset)
    res$ginis[[terr]] <- tibble(territorio = terr, ano = t$ano, tri = t$tri,
                                gini_catalogo = as.numeric(coef(g)),
                                cv = 100 * as.numeric(SE(g)) / as.numeric(coef(g)),
                                gini_pares = gini_mad(dg$variables$VD4019, dg$pweights),
                                ajuste_convencao = ajuste_convencao_convey(dg$variables$VD4019, dg$pweights))
  }
  saveRDS(lapply(res, bind_rows), parcial)
  rm(d_br, d, dg); gc()
}

# Junta todos os trimestres já validados (não só os desta execução)
parciais <- lapply(list.files(dir_parcial, pattern = "^validacao_\\d{4}_\\d\\.rds$",
                              full.names = TRUE), readRDS)
comparacoes <- bind_rows(lapply(parciais, `[[`, "comparacoes"))
internas    <- bind_rows(lapply(parciais, `[[`, "internas"))
ginis       <- bind_rows(lapply(parciais, `[[`, "ginis"))

resultado <- comparacoes %>%
  inner_join(mapa, by = c("Indicador", "Subcategoria_Indicador")) %>%
  left_join(oficiais %>% mutate(categoria = as.numeric(categoria)) %>% select(-localidade),
            by = c("territorio", "tabela", "variavel", "categoria", "periodo")) %>%
  mutate(
    estimado  = Estimativa * escala,
    diferenca = estimado - oficial,
    tolerancia = ifelse(escala == 100, 0.05, 0.5) + 1e-6,
    ok = abs(diferenca) <= tolerancia,
    CV = 100 * SE / Estimativa
  ) %>%
  select(territorio, ano, tri, Indicador, Subcategoria_Indicador, tabela, variavel, categoria,
         estimado, oficial, diferenca, ok, CV) %>%
  arrange(territorio, ano, tri)

ginis <- ginis %>%
  mutate(ok = abs(gini_catalogo - (gini_pares + ajuste_convencao)) < 1e-9)

write_csv(resultado, "output/tabelas/validacao_sidra.csv")
write_csv(internas,  "output/tabelas/validacao_checagens_internas.csv")
write_csv(ginis,     "output/tabelas/validacao_gini.csv")

message(sprintf("SIDRA: %d de %d comparações dentro da tolerância; %d sem valor oficial.",
                sum(resultado$ok, na.rm = TRUE), nrow(resultado), sum(is.na(resultado$oficial))))
message(sprintf("Checagens internas: %d de %d ok.", sum(internas$ok), nrow(internas)))
message(sprintf("Gini: %d de %d idênticos à implementação independente.", sum(ginis$ok), nrow(ginis)))
