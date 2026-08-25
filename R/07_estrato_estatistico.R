# ==============================================================================
# 07_estrato_estatistico.R — estima o "E" do AAAGGSE: o estrato estatístico
# (7º dígito), a faixa de renda do responsável pelo domicílio.
#
# O QUE A ESPECIFICAÇÃO DO IBGE PEDE
# ----------------------------------
#   "Para cada estrato geográfico, serão definidos de 2 a 5 estratos
#    estatísticos, garantido que cada um tenha pelo menos 150 UPAs. O objetivo
#    é minimizar a variância do estimador da renda do responsável pelo
#    domicílio. [...] Utilizou-se duas abordagens heurísticas específicas [...]
#    combinando método de otimização linear e algoritmos estocásticos."
#
# Isso é o problema clássico de estratificação ótima univariada (Dalenius &
# Hodges, 1959; Lavallée & Hidiroglou, 1988; Kozak, 2004): dada uma variável
# auxiliar contínua, cortar a população em h faixas que minimizem a variância
# do estimador da média sob alocação de Neyman.
#
# COMO EU RESOLVO — E POR QUE NÃO USO HEURÍSTICA
# ----------------------------------------------
# O IBGE precisa de heurística porque resolve o Brasil inteiro de uma vez.
# Na escala do Piauí o problema é pequeno o bastante para ser resolvido de
# forma EXATA, e é isso que faço aqui.
#
# A chave é que, num problema de estratificação univariada, os estratos ótimos
# são sempre intervalos contíguos da variável ordenada — não faz sentido um
# estrato "pular" uma faixa de renda. Então basta escolher os k-1 pontos de
# corte no vetor ordenado, e isso é um problema de programação dinâmica:
#
#   f[h][j] = min sobre i de { f[h-1][i-1] + custo(i, j) }
#
# com custo(i,j) = N_h * S_h do segmento i..j e a restrição de que todo
# segmento tenha >= 150 UPAs. Custa O(k*n^2); com n <= 929 no Piauí, roda em
# menos de um segundo e devolve o ÓTIMO GLOBAL, não uma aproximação.
#
# Rodo também as duas alternativas para conferência:
#   - cum-raiz-f (Dalenius-Hodges): a solução clássica aproximada
#   - busca aleatória tipo Kozak: o "algoritmo estocástico" da especificação
# Se as três concordam (ou se a DP ganha das outras duas), a solução está no
# ótimo. O resultado dessa comparação vai para output/tabelas/.
#
# QUANTOS ESTRATOS? A REGRA VEIO DOS DADOS
# ----------------------------------------
# A especificação diz "de 2 a 5" mas não diz como escolher. Testei as regras
# candidatas contra o crosswalk real da PNADC no Piauí (as 13 células AAAGGS
# observadas) e o resultado é inequívoco:
#
#   k = floor(n_UPAs / 150), capado em 5   ->  acerta  7 de 13
#   k = 3 se n_UPAs >= 450, senão 1        ->  acerta 13 de 13
#
# Ou seja: no Piauí o IBGE não maximiza o número de estratos. Ele mira em 3
# estratos estatísticos e só abre mão quando não há UPAs suficientes para
# sustentar 3 x 150 = 450. O caso que separa as duas regras é Teresina-FCU
# (300 UPAs): comportaria 2 estratos, mas o IBGE deixou 1 — como a regra dos
# 450 prevê.
#
# RESSALVA IMPORTANTE: isso é um ajuste sobre 13 células de UMA UF. Explica o
# Piauí inteiro, mas não dá para afirmar que 3 é política nacional — pode ser
# que o Piauí simplesmente nunca tenha tido UPAs para 4 ou 5. Por isso a regra
# está parametrizada em K_ALVO abaixo, e não fixa no código.
#
# ENTRADA:  output/upas_piaui.csv                     (do 06_upas_piaui.R)
# SAÍDAS:   output/upas_com_estrato_estatistico.csv   UPA -> E + código 7 dígitos
#           output/setores_com_estrato_completo.gpkg  setor -> AAAGGSE
#           output/tabelas/estratificacao_diagnostico.csv
#           output/tabelas/comparacao_metodos_estratificacao.csv
#           output/tabelas/validacao_contra_crosswalk.csv
# ==============================================================================

library(dplyr)
library(readr)
library(sf)
library(stringr)

dir.create("output/tabelas", recursive = TRUE, showWarnings = FALSE)
set.seed(20260825)   # a busca estocástica precisa ser reproduzível

MIN_UPAS_POR_ESTRATO <- 150   # restrição dura da especificação
K_ALVO               <- 3     # nº de estratos desejado (ver nota acima)
K_MAX                <- 5     # teto da especificação ("de 2 a 5")

# AAA/GG/S/estrato_geografico são CÓDIGOS, não números: lidos como double eles
# perdem zero à esquerda ("00" vira 0) e param de casar com o crosswalk.
upas <- read_csv(
  "output/upas_piaui.csv",
  col_types = cols(
    UPA = col_character(), CD_MUN = col_character(), AAA = col_character(),
    GG = col_character(), S = col_character(), estrato_geografico = col_character(),
    .default = col_guess()
  )
)

# ==============================================================================
# FUNÇÕES DE ESTRATIFICAÇÃO
# ==============================================================================

# Objetivo de Neyman: minimizar sum_h W_h * S_h, onde W_h = N_h/N e S_h é o
# desvio-padrão da renda dentro do estrato h. É o termo dominante da variância
# do estimador da média sob alocação ótima — exatamente "minimizar a variância
# do estimador da renda do responsável" da especificação.
#
# Como sum_h W_h*S_h = (1/N) * sum_h N_h*S_h, e cada N_h*S_h depende SÓ dos
# elementos daquele estrato, o objetivo é separável por estrato — que é a
# propriedade que torna a programação dinâmica aplicável.

objetivo_neyman <- function(x, cortes) {
  grupos <- cut(seq_along(x), breaks = c(0, cortes, length(x)), labels = FALSE)
  sum(vapply(split(x, grupos), function(v) length(v) * sd_pop(v), numeric(1))) / length(x)
}

sd_pop <- function(v) {
  m <- length(v)
  if (m <= 1) return(0)
  sqrt(max(mean(v^2) - mean(v)^2, 0))
}

# ---- (a) Solução EXATA por programação dinâmica ------------------------------

estratificar_dp <- function(x, k, min_n) {
  n <- length(x)
  if (k <= 1 || n < k * min_n) return(NULL)

  # Somas acumuladas: permitem calcular N_h*S_h de qualquer segmento em O(1).
  P0 <- c(0, seq_len(n))
  P1 <- c(0, cumsum(x))
  P2 <- c(0, cumsum(x^2))

  # custo(i, j) = N_h * S_h do segmento fechado [i, j]
  custo <- function(i, j) {
    m  <- j - i + 1
    s1 <- P1[j + 1] - P1[i]
    s2 <- P2[j + 1] - P2[i]
    m * sqrt(pmax(s2 / m - (s1 / m)^2, 0))
  }

  INF <- Inf
  f    <- matrix(INF, nrow = k, ncol = n)   # f[h, j] = custo ótimo de 1..j com h estratos
  back <- matrix(NA_integer_, nrow = k, ncol = n)

  # h = 1: um único estrato cobrindo 1..j
  for (j in seq(min_n, n)) f[1, j] <- custo(1, j)

  for (h in 2:k) {
    # j precisa comportar h estratos de min_n
    for (j in seq(h * min_n, n)) {
      # `is` percorre o ÚLTIMO índice do estrato h-1; logo o estrato h é o
      # segmento (is+1)..j, de tamanho j - is. Para respeitar o mínimo é
      # preciso j - is >= min_n, ou seja is <= j - min_n. (Escrever
      # `j - min_n + 1` aqui deixa passar um estrato com min_n - 1 UPAs.)
      is <- seq((h - 1) * min_n, j - min_n)
      if (length(is) == 0) next
      cand <- f[h - 1, is] + custo(is + 1, j)
      w <- which.min(cand)
      if (is.finite(cand[w])) {
        f[h, j]    <- cand[w]
        back[h, j] <- is[w]
      }
    }
  }

  if (!is.finite(f[k, n])) return(NULL)

  # reconstrói os cortes
  cortes <- integer(0)
  j <- n
  for (h in seq(k, 2)) {
    i <- back[h, j]
    cortes <- c(i, cortes)
    j <- i
  }
  list(cortes = cortes, objetivo = f[k, n] / n)
}

# ---- (b) cum-raiz-f (Dalenius-Hodges) — a aproximação clássica ---------------
# Divide o eixo da variável em classes, acumula a raiz da frequência e corta
# em pontos igualmente espaçados desse acumulado.

estratificar_cumsqrtf <- function(x, k, min_n, n_classes = 50) {
  n <- length(x)
  if (k <= 1 || n < k * min_n) return(NULL)
  brk <- seq(min(x), max(x), length.out = n_classes + 1)
  fr  <- table(cut(x, breaks = brk, include.lowest = TRUE))
  cum <- cumsum(sqrt(as.numeric(fr)))
  alvos <- seq_len(k - 1) * max(cum) / k
  # limite superior de renda de cada corte -> converte para índice no vetor ordenado
  lim <- vapply(alvos, function(a) brk[which(cum >= a)[1] + 1], numeric(1))
  cortes <- vapply(lim, function(l) sum(x <= l), integer(1))
  cortes <- ajustar_viabilidade(unique(cortes), n, k, min_n)
  if (is.null(cortes)) return(NULL)
  list(cortes = cortes, objetivo = objetivo_neyman(x, cortes))
}

# Empurra cortes inviáveis (estrato com menos de min_n) para dentro da região
# viável, preservando a ordem.
ajustar_viabilidade <- function(cortes, n, k, min_n) {
  if (length(cortes) != k - 1) return(NULL)
  cortes <- sort(cortes)
  for (h in seq_along(cortes)) cortes[h] <- max(cortes[h], h * min_n)
  for (h in seq(length(cortes), 1)) cortes[h] <- min(cortes[h], n - (k - h) * min_n)
  if (any(diff(c(0, cortes, n)) < min_n)) return(NULL)
  cortes
}

# ---- (c) Busca aleatória tipo Kozak — o "algoritmo estocástico" -------------
# Perturba os cortes aleatoriamente e aceita o que melhora. É a heurística que
# a especificação do IBGE descreve; aqui ela serve de conferência da DP.

estratificar_kozak <- function(x, k, min_n, iteracoes = 20000) {
  n <- length(x)
  if (k <= 1 || n < k * min_n) return(NULL)
  atual <- ajustar_viabilidade(round(seq_len(k - 1) * n / k), n, k, min_n)
  if (is.null(atual)) return(NULL)
  melhor <- atual
  obj_melhor <- objetivo_neyman(x, atual)

  for (it in seq_len(iteracoes)) {
    cand <- melhor
    h <- sample(seq_along(cand), 1)
    cand[h] <- cand[h] + sample(c(-20:-1, 1:20), 1)
    cand <- sort(cand)
    if (any(diff(c(0, cand, n)) < min_n)) next
    obj <- objetivo_neyman(x, cand)
    if (obj < obj_melhor) { melhor <- cand; obj_melhor <- obj }
  }
  list(cortes = melhor, objetivo = obj_melhor)
}

# ==============================================================================
# APLICAÇÃO POR ESTRATO GEOGRÁFICO
# ==============================================================================

# Absorção de células FCU pequenas demais para virar estrato próprio.
# No Piauí existem 372 setores de FCU, mas 369 estão em Teresina; sobram um
# setor em Parnaíba e dois em Picos, que viram 1 UPA cada. Uma "célula" de 1
# UPA não é um estrato — e o crosswalk oficial confirma: o único estrato com
# S=3 no estado é o 2210030 (Teresina). Ou seja, o IBGE também absorve essas
# pontas. Como FCU é um subtipo de área urbana, a absorção natural é para o
# estrato urbano (S=1) da mesma célula geográfica.
#
# O limite é o próprio piso da especificação: sem 150 UPAs a célula não
# sustenta nem um estrato. Note que isso NÃO afeta células rurais pequenas —
# Teresina rural tem 104 UPAs e é um estrato de verdade (2210020) porque
# rural não tem para onde ser absorvido; FCU tem.
LIMITE_ABSORCAO_FCU <- MIN_UPAS_POR_ESTRATO

tamanho_celula <- upas %>% count(estrato_geografico, name = "n_upas")

celulas_absorvidas <- upas %>%
  left_join(tamanho_celula, by = "estrato_geografico") %>%
  filter(S == "3", n_upas < LIMITE_ABSORCAO_FCU) %>%
  distinct(estrato_geografico, n_upas)

if (nrow(celulas_absorvidas) > 0) {
  message("Células FCU absorvidas pelo estrato urbano da mesma célula geográfica:")
  print(as.data.frame(celulas_absorvidas), row.names = FALSE)

  upas <- upas %>%
    left_join(tamanho_celula, by = "estrato_geografico") %>%
    mutate(
      absorvida_de = ifelse(S == "3" & n_upas < LIMITE_ABSORCAO_FCU,
                            estrato_geografico, NA_character_),
      estrato_geografico = ifelse(S == "3" & n_upas < LIMITE_ABSORCAO_FCU,
                                  paste0(AAA, GG, "1"), estrato_geografico)
    ) %>%
    select(-n_upas)
}

celulas <- sort(unique(upas$estrato_geografico))
resultado  <- list()
comparacao <- list()
diagnostico <- list()

for (cel in celulas) {

  bloco <- upas %>% filter(estrato_geografico == cel) %>% arrange(renda_media)
  n <- nrow(bloco)

  # Quantos estratos essa célula comporta
  k_viavel <- min(K_MAX, floor(n / MIN_UPAS_POR_ESTRATO))
  k <- if (n >= K_ALVO * MIN_UPAS_POR_ESTRATO) K_ALVO else 1L

  if (k <= 1) {
    bloco$E <- 0L
    resultado[[cel]] <- bloco
    diagnostico[[cel]] <- tibble(
      estrato_geografico = cel, n_UPAs = n, k_viavel = k_viavel, k_usado = 1L,
      metodo = "estrato único", objetivo = NA_real_,
      reducao_variancia_pct = NA_real_,
      motivo = sprintf("n=%d < %d UPAs (%d x %d) exigidas para %d estratos",
                       n, K_ALVO * MIN_UPAS_POR_ESTRATO, K_ALVO,
                       MIN_UPAS_POR_ESTRATO, K_ALVO)
    )
    next
  }

  x <- bloco$renda_media

  r_dp     <- estratificar_dp(x, k, MIN_UPAS_POR_ESTRATO)
  r_cum    <- estratificar_cumsqrtf(x, k, MIN_UPAS_POR_ESTRATO)
  r_kozak  <- estratificar_kozak(x, k, MIN_UPAS_POR_ESTRATO)

  comparacao[[cel]] <- tibble(
    estrato_geografico = cel, n_UPAs = n, k = k,
    obj_DP        = r_dp$objetivo,
    obj_cumsqrtf  = if (is.null(r_cum))   NA_real_ else r_cum$objetivo,
    obj_kozak     = if (is.null(r_kozak)) NA_real_ else r_kozak$objetivo,
    cortes_DP     = paste(r_dp$cortes, collapse = "|"),
    DP_e_melhor   = all(r_dp$objetivo <= c(r_cum$objetivo, r_kozak$objetivo) + 1e-9)
  )

  cortes <- r_dp$cortes
  bloco$E <- as.integer(cut(seq_len(n), breaks = c(0, cortes, n), labels = FALSE))

  # Ganho em relação a não estratificar: a variância do estimador cai de
  # S (desvio-padrão global) para sum_h W_h*S_h.
  obj0 <- sd_pop(x)
  resultado[[cel]] <- bloco
  diagnostico[[cel]] <- tibble(
    estrato_geografico = cel, n_UPAs = n, k_viavel = k_viavel, k_usado = k,
    metodo = "programação dinâmica (ótimo exato)", objetivo = r_dp$objetivo,
    reducao_variancia_pct = 100 * (1 - (r_dp$objetivo / obj0)^2),
    motivo = sprintf("n=%d UPAs comporta até %d estratos; usados %d (K_ALVO)",
                     n, k_viavel, k)
  )
}

upas_e <- bind_rows(resultado) %>%
  mutate(Estrato_reconstruido = paste0(estrato_geografico, E))

diag_df <- bind_rows(diagnostico) %>% arrange(estrato_geografico)
comp_df <- bind_rows(comparacao)

message("\n--- Estratificação por estrato geográfico ---")
print(as.data.frame(diag_df %>% select(-motivo)), row.names = FALSE)

message("\n--- DP x cum-raiz-f x Kozak (valores menores = melhor) ---")
print(as.data.frame(comp_df %>% select(-cortes_DP)), row.names = FALSE)

# ==============================================================================
# VALIDAÇÃO CONTRA O CROSSWALK OFICIAL DA PNADC
# ==============================================================================

crosswalk <- read_csv("output/crosswalk_estratos.csv", show_col_types = FALSE) %>%
  mutate(Estrato = as.character(Estrato),
         celula = substr(Estrato, 1, 6),
         E_obs  = substr(Estrato, 7, 7))

k_observado <- crosswalk %>%
  group_by(celula) %>%
  summarise(k_IBGE = n_distinct(E_obs),
            E_IBGE = paste(sort(unique(E_obs)), collapse = ","), .groups = "drop")

validacao <- diag_df %>%
  select(estrato_geografico, n_UPAs, k_usado) %>%
  left_join(k_observado, by = c("estrato_geografico" = "celula")) %>%
  mutate(
    k_IBGE  = ifelse(is.na(k_IBGE), 0L, k_IBGE),
    confere = k_usado == pmax(k_IBGE, 1L)
  )

message("\n--- Validação: k reconstruído x k do crosswalk oficial ---")
print(as.data.frame(validacao), row.names = FALSE)
message(sprintf("\nCélulas com o mesmo número de estratos: %d de %d.",
                sum(validacao$confere), nrow(validacao)))

# ---- Equivalência entre o código reconstruído e o código oficial -------------
# O IBGE não numera o E de forma consistente: em umas células usa {1,2,3} e em
# outras {0,1,2} para o mesmo número de estratos. Eu numero sempre 1..k em
# ordem crescente de renda. Onde o k confere, a correspondência é então direta:
# basta parear meu E ordenado com o E oficial ordenado. Isso produz um
# de-para utilizável para juntar a reconstrução aos microdados da PNADC.
equivalencia <- crosswalk %>%
  group_by(celula) %>%
  arrange(E_obs, .by_group = TRUE) %>%
  mutate(posicao = row_number()) %>%
  ungroup() %>%
  select(celula, posicao, Estrato_oficial = Estrato, E_oficial = E_obs) %>%
  right_join(
    upas_e %>%
      distinct(estrato_geografico, E, Estrato_reconstruido) %>%
      mutate(posicao = ifelse(E == 0L, 1L, E)),
    by = c("celula" = "estrato_geografico", "posicao")
  ) %>%
  arrange(Estrato_reconstruido) %>%
  select(Estrato_reconstruido, E_reconstruido = E, Estrato_oficial, E_oficial)

n_iguais <- sum(equivalencia$Estrato_reconstruido == equivalencia$Estrato_oficial,
                na.rm = TRUE)
sem_reconstrucao <- setdiff(crosswalk$Estrato, equivalencia$Estrato_oficial)

message(sprintf(paste0("\nDe-para com o código oficial: %d de %d estratos reconstruídos ",
                       "são idênticos ao oficial;\n%d têm a MESMA partição mas rótulo ",
                       "diferente (o IBGE numera o E ora 1..k, ora 0..k-1)."),
                n_iguais, nrow(equivalencia),
                sum(!is.na(equivalencia$Estrato_oficial)) - n_iguais))

# Atenção: comparar os dois conjuntos de códigos como texto engana. Alguns
# códigos coincidem por acaso (meu 2251021 é a faixa de renda MAIS BAIXA;
# o 2251021 oficial é a do MEIO, porque naquela célula o IBGE numerou de 0 a
# 2). Só o pareamento por posição na ordem de renda, feito acima, é honesto.
if (length(sem_reconstrucao) > 0) {
  message("\nEstratos oficiais SEM contrapartida reconstruída: ",
          paste(sem_reconstrucao, collapse = ", "),
          "\n  -> a camada do GeoServer não define o código 2254: ele não existe entre ",
          "os polígonos\n     publicados, então o território dele vem aglutinado dentro ",
          "do 2253 e não há como\n     separar os dois a partir dessa fonte. ",
          "Não é perda de processamento — a fronteira não é pública.")
}

write_csv(equivalencia, "output/tabelas/equivalencia_estratos.csv")

# ==============================================================================
# SAÍDAS
# ==============================================================================

write_csv(upas_e,   "output/upas_com_estrato_estatistico.csv")
write_csv(diag_df,  "output/tabelas/estratificacao_diagnostico.csv")
write_csv(comp_df,  "output/tabelas/comparacao_metodos_estratificacao.csv")
write_csv(validacao,"output/tabelas/validacao_contra_crosswalk.csv")

# Leva o E de volta para o setor censitário, fechando os 7 dígitos.
# estrato_geografico vem de upas_e, NÃO de paste0(AAA, GG, S): as células FCU
# absorvidas acima têm S = 3 no setor (é atributo do setor, e continua certo)
# mas pertencem ao estrato urbano — recalcular aqui desfaria a absorção.
setores <- st_read("output/setores_com_upa_piaui.gpkg", quiet = TRUE) %>%
  left_join(upas_e %>% select(UPA, E, estrato_geografico, Estrato_reconstruido),
            by = "UPA")

st_write(setores, "output/setores_com_estrato_completo.gpkg", delete_dsn = TRUE, quiet = TRUE)

message("\nSaídas: output/upas_com_estrato_estatistico.csv, ",
        "output/setores_com_estrato_completo.gpkg e 3 tabelas em output/tabelas/")
