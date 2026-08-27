# ==============================================================================
# 09_preencher_relatorio.R — preenche o modelo do relatório com os números do
# trimestre.
#
# POR QUE ISSO EXISTE
# -------------------
# O modelo em output/relatorio_trimestral.md tinha cerca de 340 marcadores do
# tipo {EST}, {CV}, {IC}, {SIG}. Preenchê-los à mão a cada trimestre é caro e,
# pior, é o tipo de tarefa em que um erro passa despercebido: trocar duas
# linhas de uma tabela de dezesseis não deixa rastro visível.
#
# O problema de fundo era que {SIG} aparecia 61 vezes sem dizer a que se
# referia. Um marcador sem endereço não é preenchível por máquina. Este script
# resolve isso com duas construções:
#
#   1. DIRETIVAS DE TABELA — uma linha de comentário HTML no lugar da tabela
#      inteira. O script gera cabeçalho, linhas e rodapé:
#
#          <!-- @tabela tipo=geografica indicador=Taxa_Desocupacao -->
#
#      Dez das tabelas do modelo estavam elípticas ("Mesma estrutura da Tabela
#      2"). Gerar em vez de preencher resolve as duas coisas de uma vez.
#
#   2. EXPRESSÕES ENDEREÇADAS — para o texto corrido, onde não há tabela que
#      dê contexto:
#
#          O Piauí registrou {{est Taxa_Desocupacao Piauí}}% ...
#
# E uma terceira construção para os trechos condicionais que o modelo já
# previa em prosa:
#
#          {{#se-significativo Taxa_Desocupacao Teresina_x_Resto_Piaui}}
#          ... texto usado quando dá significativo ...
#          {{/se}}
#
# REGRA DE OURO: o script FALHA se sobrar qualquer marcador não resolvido.
# Um relatório meio preenchido publicado por engano é pior que nenhum.
#
# USO:
#   source("R/00_config.R")   # já feito aqui dentro
#   Rscript R/09_preencher_relatorio.R
#
# ENTRADA : output/relatorio_trimestral.md          (o modelo, versionado)
# SAÍDA   : output/relatorio_trimestral_<AAAAT#>.md (a edição do trimestre)
#
# O modelo NÃO é sobrescrito — ele é o ativo que se reusa todo trimestre.
# ==============================================================================

library(dplyr)
library(readr)
library(stringr)
library(tibble)
library(purrr)
library(pandoc)

source("R/00_config.R")

MODELO <- "./output/relatorio_trimestral.md"
SAIDA  <- sprintf("./output/relatorio_trimestral_%s.md", sufixo)
CONVERTER_DOCX = TRUE

# ---- 1. Leitura das saídas do pipeline ---------------------------------------

ler <- function(caminho, obrigatorio = TRUE) {
  if (!file.exists(caminho)) {
    if (obrigatorio) {
      stop("Não encontrei ", caminho, ".\nRode R/01_pipeline_trimestral.R antes deste script.")
    }
    return(NULL)
  }
  read_csv(caminho, show_col_types = FALSE)
}

base        <- ler(sprintf("output/base_%s.csv", sufixo))
testes_reg  <- ler(sprintf("output/testes_regionais_%s.csv", sufixo))
testes_demo <- ler(sprintf("output/testes_significancia_%s.csv", sufixo))
desig       <- ler(sprintf("output/desigualdade_formal_informal_%s.csv", sufixo), obrigatorio = FALSE)

# ---- 2. Unidades e formatação ------------------------------------------------
# A escala de exibição depende do indicador: proporção vira porcentagem,
# rendimento fica em reais, razão fica adimensional. O CV não depende disso —
# é invariante a fator de escala —, mas a estimativa e o IC dependem.

UNIDADE <- c(
  Taxa_Desocupacao                 = "pct",
  Chefes_Familia_Desocupados       = "pct",
  Conribuintes_Desocupados         = "pct",
  Percentual_Subremuneracao        = "pct",
  Taxa_Informalidade               = "pct",
  Taxa_Subocupacao                 = "pct",
  Proporcao_Ocupados_Escolarizados = "pct",
  Desalentados_Forca_Ampliada      = "pct",
  Desalentados_Fora_Forca          = "pct",
  Taxa_Nem_Nem                     = "pct",
  Motivo_Desistencia_Desalentado   = "pct",
  Motivo_Nao_Procura_NemNem        = "pct",
  Motivo_Nao_Inicio_NemNem         = "pct",
  Rendimento_Medio_Habitual        = "reais",
  Rendimento_Formal                = "reais",
  Rendimento_Informal              = "reais",
  Desigualdade_Formal_Informal     = "razao"
)

unidade_de <- function(ind) if (ind %in% names(UNIDADE)) UNIDADE[[ind]] else "pct"
fator_de   <- function(ind) if (unidade_de(ind) == "pct") 100 else 1

# Números em português: vírgula decimal, ponto de milhar.
num <- function(x, casas = 1) {
  ifelse(is.na(x), "—",
         formatC(x, format = "f", digits = casas, big.mark = ".", decimal.mark = ","))
}

formatar_valor <- function(x, ind) {
  u <- unidade_de(ind)
  if (u == "reais") paste0("R$ ", num(x, 0)) else num(x, if (u == "razao") 2 else 1)
}

# Classificação de precisão pelo CV — os cortes são os do IBGE (anexo, §5.3).
classe_cv <- function(cv) {
  case_when(is.na(cv)  ~ "—",
            cv <  5    ~ "excelente",
            cv < 15    ~ "boa",
            cv < 30    ~ "regular",
            TRUE       ~ "baixa")
}

estrelas <- function(p) {
  case_when(is.na(p)   ~ "—",
            p < 0.001  ~ "\\*\\*\\*",
            p < 0.01   ~ "\\*\\*",
            p < 0.05   ~ "\\*",
            TRUE       ~ "ns")
}

# ---- 3. Consulta à base ------------------------------------------------------
# Um único ponto de acesso, para que toda expressão do modelo resolva pelo
# mesmo caminho e as inconsistências apareçam num lugar só.

linha_de <- function(ind, geo, recorte = "Total", categoria = "Total") {
  r <- base %>%
    filter(Indicador == ind, Regiao_Geografica == geo,
           Recorte_Demografico == recorte, Categoria_Demografica == categoria)
  if (nrow(r) == 0) return(NULL)
  if (nrow(r) > 1) {
    stop("Consulta ambígua: ", ind, " / ", geo, " / ", recorte, " / ", categoria,
         " devolveu ", nrow(r), " linhas. Se o indicador tem subcategorias ",
         "(os de motivo têm), use tipo=motivos na diretiva de tabela.")
  }
  mutate(r, cv = 100 * SE / Estimativa)
}

# Registro do que não foi encontrado — vira relatório no fim da execução em vez
# de erro solto no meio.
ausentes <- new.env(parent = emptyenv())
ausentes$itens <- character(0)
registrar_ausente <- function(msg) {
  ausentes$itens <- c(ausentes$itens, msg)
  invisible(NULL)
}

# ---- 4. Vocabulário das expressões {{ }} -------------------------------------

exp_est <- function(ind, geo, ...) {
  r <- linha_de(ind, geo, ...)
  if (is.null(r)) { registrar_ausente(paste("estimativa", ind, "em", geo)); return("—") }
  formatar_valor(r$Estimativa * fator_de(ind), ind)
}

exp_ic <- function(ind, geo, ...) {
  r <- linha_de(ind, geo, ...)
  if (is.null(r)) { registrar_ausente(paste("IC", ind, "em", geo)); return("—") }
  f <- fator_de(ind)
  # Truncado em zero: proporção não tem limite inferior negativo. O anexo
  # (§5.2) registra que o limite negativo é sinal de aproximação normal fora
  # de sua região de validade — exibir "-2,1%" seria pior que truncar.
  inf <- max(0, (r$Estimativa - 1.96 * r$SE) * f)
  sup <- (r$Estimativa + 1.96 * r$SE) * f
  sprintf("[%s; %s]", formatar_valor(inf, ind), formatar_valor(sup, ind))
}

exp_cv <- function(ind, geo, ...) {
  r <- linha_de(ind, geo, ...)
  if (is.null(r)) { registrar_ausente(paste("CV", ind, "em", geo)); return("—") }
  num(r$cv, 1)
}

exp_prec <- function(ind, geo, ...) {
  r <- linha_de(ind, geo, ...)
  if (is.null(r)) return("—")
  classe_cv(r$cv)
}

# Extremos entre os estratos de 7 dígitos.
#
# POR QUE HÁ UM TETO DE CV AQUI
# -----------------------------
# Tomar o mínimo e o máximo pelo valor pontual, sem olhar a precisão, produz
# frases erradas. No 2026T2 o menor valor da taxa de desocupação caía no
# estrato 2252022: estimativa de 3,7%, intervalo [0,0; 35,7], CV de 444,8%.
# Não é uma taxa baixa — é uma estimativa que não distingue 3,7% de 35%. Usá-la
# como extremo faria o relatório anunciar uma amplitude de 15,7 pontos que é
# inteiramente ruído amostral.
#
# O corte de 30% é o limite da classe "regular" do IBGE (anexo §5.3): acima
# disso a estimativa não sustenta leitura, e o extremo é buscado entre as que
# sustentam. Se nenhuma passar no corte, o filtro é abandonado — melhor um
# extremo impreciso, com o CV visível ao lado na tabela, do que nenhum.
CV_MAXIMO_EXTREMO <- 30

extremos_micro <- function(ind) {
  todos <- base %>%
    filter(Indicador == ind, Recorte_Demografico == "Total",
           str_starts(Regiao_Geografica, "Micro_")) %>%
    mutate(cv = 100 * SE / Estimativa,
           codigo = str_remove(Regiao_Geografica, "^Micro_")) %>%
    arrange(desc(Estimativa))

  utilizaveis <- filter(todos, is.finite(cv), cv < CV_MAXIMO_EXTREMO)
  if (nrow(utilizaveis) >= 2) utilizaveis else todos
}

exp_extremo <- function(ind, qual, campo) {
  e <- extremos_micro(ind)
  if (nrow(e) == 0) { registrar_ausente(paste("extremos de", ind)); return("—") }
  r <- if (qual == "max") slice_head(e, n = 1) else slice_tail(e, n = 1)
  switch(campo,
         rotulo = paste("estrato", r$codigo),
         codigo = r$codigo,
         valor  = formatar_valor(r$Estimativa * fator_de(ind), ind),
         cv     = num(r$cv, 1),
         stop("campo desconhecido em {{extremo}}: ", campo))
}

exp_amplitude <- function(ind) {
  e <- extremos_micro(ind)
  if (nrow(e) < 2) { registrar_ausente(paste("amplitude de", ind)); return("—") }
  formatar_valor((max(e$Estimativa) - min(e$Estimativa)) * fator_de(ind), ind)
}

exp_n_estratos <- function() {
  as.character(n_distinct(extremos_micro("Taxa_Desocupacao")$codigo))
}

# Testes regionais.
teste_reg <- function(ind, recorte) {
  r <- testes_reg %>% filter(Indicador == ind, Recorte_Regional == recorte)
  if (nrow(r) == 0) NULL else r
}

exp_p <- function(ind, recorte, qual = "ajustado") {
  r <- teste_reg(ind, recorte)
  # Ausência aqui não é falta de dado: é a guarda de variância tendo recusado
  # o teste (anexo §6.5). O travessão é a informação correta.
  if (is.null(r)) return("—")
  p <- if (qual == "bruto") r$p_valor else r$p_ajustado
  if (p < 0.001) "< 0,001" else num(p, 3)
}

exp_sig <- function(ind, recorte) {
  r <- teste_reg(ind, recorte)
  if (is.null(r)) return("—")
  if (r$p_ajustado < 0.05) "sim" else "não"
}

exp_estrelas <- function(ind, recorte) {
  r <- teste_reg(ind, recorte)
  if (is.null(r)) return("—")
  estrelas(r$p_ajustado)
}

# Desigualdade formal/informal.
linha_desig <- function(geo) {
  if (is.null(desig)) return(NULL)
  r <- desig %>% filter(Regiao_Geografica == geo)
  if (nrow(r) == 0) NULL else r
}

exp_desig <- function(geo, campo) {
  r <- linha_desig(geo)
  if (is.null(r)) { registrar_ausente(paste("desigualdade em", geo)); return("—") }
  switch(campo,
         razao    = num(r$razao, 2),
         formal   = paste0("R$ ", num(r$rendimento_formal, 0)),
         informal = paste0("R$ ", num(r$rendimento_informal, 0)),
         ic       = sprintf("[%s; %s]", num(r$ic_inf, 2), num(r$ic_sup, 2)),
         cv       = num(r$cv, 1),
         prec     = classe_cv(r$cv),
         stop("campo desconhecido em {{desigualdade}}: ", campo))
}

exp_trimestre <- function() {
  sprintf("%dº trimestre de %d", TRIMESTRE_REF, ANO_REF)
}


# Diferença entre duas geografias, na unidade do indicador. Serve às frases do
# tipo "a diferença entre urbana e rural foi de X pontos".
exp_dif <- function(ind, geo_a, geo_b) {
  a <- linha_de(ind, geo_a); b <- linha_de(ind, geo_b)
  if (is.null(a) || is.null(b)) {
    registrar_ausente(paste("diferença", ind, "entre", geo_a, "e", geo_b)); return("—")
  }
  formatar_valor(abs(a$Estimativa - b$Estimativa) * fator_de(ind), ind)
}

# Uma geografia como porcentagem de outra ("o Piauí equivale a X% do Brasil").
exp_pct_de <- function(ind, geo, referencia) {
  a <- linha_de(ind, geo); r <- linha_de(ind, referencia)
  if (is.null(a) || is.null(r)) {
    registrar_ausente(paste(ind, "de", geo, "como % de", referencia)); return("—")
  }
  num(100 * a$Estimativa / r$Estimativa, 1)
}

exp_razao_extremos <- function(ind) {
  e <- extremos_micro(ind)
  if (nrow(e) < 2) return("—")
  num(max(e$Estimativa) / min(e$Estimativa), 2)
}

# Extremos da tabela de desigualdade, que vive num CSV próprio.
exp_desig_extremo <- function(qual, campo) {
  if (is.null(desig)) return("—")
  d <- desig %>% filter(str_starts(Regiao_Geografica, "Micro_")) %>% arrange(desc(razao))
  if (nrow(d) == 0) return("—")
  r <- if (qual == "max") slice_head(d, n = 1) else slice_tail(d, n = 1)
  switch(campo,
         rotulo = paste("estrato", str_remove(r$Regiao_Geografica, "^Micro_")),
         valor  = num(r$razao, 2),
         stop("campo desconhecido em {{desig_extremo}}: ", campo))
}

# Quanto o formal ganha a mais que o informal, em pontos percentuais.
exp_pct_a_mais <- function(geo) {
  r <- linha_desig(geo)
  if (is.null(r)) return("—")
  num(100 * (r$razao - 1), 0)
}

exp_sm_hora <- function() num(sm_hora_corrente, 2)

VOCABULARIO <- list(
  est        = exp_est,
  ic         = exp_ic,
  cv         = exp_cv,
  prec       = exp_prec,
  extremo    = exp_extremo,
  amplitude  = exp_amplitude,
  n_estratos = exp_n_estratos,
  p          = exp_p,
  sig        = exp_sig,
  estrelas   = exp_estrelas,
  desigualdade = exp_desig,
  trimestre  = exp_trimestre,
  sufixo     = function() sufixo,
  dif        = exp_dif,
  pct_de     = exp_pct_de,
  razao_extremos = exp_razao_extremos,
  desig_extremo  = exp_desig_extremo,
  pct_a_mais = exp_pct_a_mais,
  sm_hora    = exp_sm_hora
)

# ---- 5. Tabelas geradas por diretiva -----------------------------------------
# A ordem e os rótulos das linhas ficam AQUI, num lugar só, e não repetidos em
# dez tabelas do modelo. Mudar a lista muda todas as tabelas de uma vez.

LINHAS_GEOGRAFICAS <- tribble(
  ~recorte,               ~categoria,                     ~geografia,
  "Agregados",            "Brasil",                       "Brasil",
  "Agregados",            "Nordeste",                     "Nordeste",
  "Agregados",            "Piauí",                        "Piauí",
  "Agregados",            "Teresina",                     "Teresina",
  "Zona",                 "Urbana",                       "Zona_Urbana",
  "Zona",                 "Rural",                        "Zona_Rural",
  "Administrativo",       "Capital",                      "Admin_Capital",
  "Administrativo",       "Resto da RIDE",                "Admin_Resto da RIDE (Região Integrada de Desenvolvimento Econômico, excluindo a capital)",
  "Administrativo",       "Resto da UF",                  "Admin_Resto da UF  (Unidade da Federação, excluindo a região metropolitana e a RIDE)",
  "Estrato agregado",     "Teresina",                     "Agreg_Teresina",
  "Estrato agregado",     "Entorno metropolitano",        "Agreg_Entorno metropolitano de Teresina (PI)",
  "Estrato agregado",     "Centro-Leste",                 "Agreg_Centro-Leste do Piauí",
  "Estrato agregado",     "Baixo Parnaíba",               "Agreg_Baixo Parnaíba do Piauí",
  "Estrato agregado",     "Alto Parnaíba e Chapadas Sul", "Agreg_Alto Parnaíba e Chapadas Sul do Piauí"
)

# Os recortes regionais da tabela de testes, na ordem em que aparecem.
LINHAS_TESTES <- tribble(
  ~rotulo,                        ~recorte,
  "Zona (urbana × rural)",        "Zona",
  "Estrato administrativo",       "Estrato_Administrativo",
  "Estrato agregado",             "Estrato_Agregado",
  "Estrato (7 dígitos)",          "Estrato_Micro",
  "Teresina × resto do Piauí",    "Teresina_x_Resto_Piaui"
)

linha_md <- function(...) paste0("| ", paste(c(...), collapse = " | "), " |")

tabela_geografica <- function(ind) {
  u <- unidade_de(ind)
  col_est <- if (u == "reais") "Estimativa (R$)" else if (u == "razao") "Razão" else "Estimativa (%)"

  linhas <- LINHAS_GEOGRAFICAS %>%
    # Brasil e Nordeste só entram se tiverem sido estimados: quando o pipeline
    # roda sobre um desenho já recortado no Piauí, essas linhas não existem, e
    # exibi-las vazias sugeriria dado faltante em vez de escopo diferente.
    filter(geografia %in% base$Regiao_Geografica) %>%
    pmap_chr(function(recorte, categoria, geografia) {
      linha_md(recorte, categoria,
               exp_est(ind, geografia), exp_ic(ind, geografia),
               exp_cv(ind, geografia), exp_prec(ind, geografia))
    })

  e <- extremos_micro(ind)
  linhas_micro <- character(0)
  if (nrow(e) >= 2) {
    topo <- slice_head(e, n = 1); base_ <- slice_tail(e, n = 1)
    linhas_micro <- c(
      linha_md("Estrato (7 dígitos)", paste0("maior: ", topo$codigo),
               formatar_valor(topo$Estimativa * fator_de(ind), ind),
               exp_ic(ind, topo$Regiao_Geografica), num(topo$cv, 1), classe_cv(topo$cv)),
      linha_md("Estrato (7 dígitos)", paste0("menor: ", base_$codigo),
               formatar_valor(base_$Estimativa * fator_de(ind), ind),
               exp_ic(ind, base_$Regiao_Geografica), num(base_$cv, 1), classe_cv(base_$cv))
    )
  }

  c(linha_md("Recorte", "Categoria", col_est, "IC 95%", "CV (%)", "Precisão"),
    "|---|---|---:|:---:|---:|---|",
    linhas, linhas_micro)
}

tabela_testes <- function(ind) {
  linhas <- LINHAS_TESTES %>% pmap_chr(function(rotulo, recorte) {
    linha_md(rotulo, exp_p(ind, recorte, "bruto"), exp_p(ind, recorte), exp_sig(ind, recorte))
  })
  c(linha_md("Recorte", "p-valor", "p ajustado", "Significativo a 5%?"),
    "|---|---:|---:|:---:|", linhas)
}

tabela_formalidade <- function() {
  if (is.null(desig)) return("*(desigualdade formal/informal não disponível neste trimestre)*")
  linhas <- LINHAS_GEOGRAFICAS %>%
    filter(geografia %in% desig$Regiao_Geografica) %>%
    pmap_chr(function(recorte, categoria, geografia) {
      linha_md(recorte, categoria,
               exp_desig(geografia, "formal"),   exp_desig(geografia, "informal"),
               exp_desig(geografia, "razao"),    exp_desig(geografia, "ic"),
               exp_desig(geografia, "cv"),       exp_desig(geografia, "prec"))
    })
  c(linha_md("Recorte", "Categoria", "Formais (R$)", "Informais (R$)",
             "Razão", "IC 95% da razão", "CV (%)", "Precisão"),
    "|---|---|---:|---:|---:|:---:|---:|---|", linhas)
}

# O svymean nomeia cada célula com a VARIÁVEL colada na categoria
# ("VD4030Estava estudando"), não com o id do indicador. É o prefixo da
# variável que precisa sair. O sufixo de letra da variável (V4074A, VD4004A)
# só é consumido quando NÃO for a inicial do rótulo: "VD4030Tinha que cuidar"
# tem o T do rótulo colado no nome da variável, e um [A-Z]? ganancioso comeria
# essa letra.
rotulo_motivo <- function(cat) {
  r <- str_remove(cat, "^~?V[D]?[0-9]{4}[A-Z](?![:lower:])|^~?V[D]?[0-9]{4}")
  str_trim(str_remove_all(r, '^[~"]+|"$'))
}

# RESTRIÇÃO A UM SUBCONJUNTO DE CATEGORIAS
# -----------------------------------------
# Pedido explícito: a Tabela 13 (motivo de não ter procurado trabalho, VD4030,
# indicador Motivo_Nao_Procura_NemNem) mostra só as seis categorias abaixo —
# os códigos IBGE 03, 04, 05, 06, 07 e 09 do dicionário de VD4030 — mesmo que
# alguma delas tenha CV alto. As demais categorias de VD4030 ("Por outro
# motivo", "Por não querer trabalhar", "Por ser muito jovem ou muito idoso
# para trabalhar" etc., códigos 01, 02, 08 e outros) ficam de fora.
#
# O casamento é por PREFIXO do rótulo, não por igualdade exata: o rótulo que
# sai do svymean (via pnadc_labeller) pode ser uma versão abreviada da
# descrição oficial do dicionário — "Estava estudando" em vez de "Estava
# estudando (curso de qualquer tipo ou por conta própria)" — e casar pelo
# início evita que uma pontuação diferente derrube o filtro inteiro.
#
# Chave por INDICADOR, não por dimensão: só Motivo_Nao_Procura_NemNem é
# restrito. Motivo_Desistencia_Desalentado e Motivo_Nao_Inicio_NemNem (que no
# modelo aparecem só como figura, sem tabela) continuam completos caso um dia
# ganhem uma diretiva @tabela.
MOTIVOS_INCLUIR <- list(
  Motivo_Nao_Procura_NemNem = c(
    "Não conseguia trabalho adequado",
    "Não tinha experiência profissional ou qualificação",
    "Não havia trabalho na localidade",
    "Tinha que cuidar dos afazeres domésticos",
    "Estava estudando",
    "Por problema de saúde ou gravidez"
  )
)

# Indicadores de motivo: a resposta é categórica, então a "tabela geográfica"
# não se aplica — o que interessa é a distribuição das categorias.
tabela_motivos <- function(ind, geo) {
  d <- base %>%
    filter(Indicador == ind, Regiao_Geografica == geo, Recorte_Demografico == "Total") %>%
    mutate(cv = 100 * SE / Estimativa, rotulo = map_chr(Subcategoria_Indicador, rotulo_motivo)) %>%
    arrange(desc(Estimativa))
  if (nrow(d) == 0) {
    registrar_ausente(paste("motivos de", ind, "em", geo))
    return("*(sem dados para este indicador neste trimestre)*")
  }

  incluir <- MOTIVOS_INCLUIR[[ind]]
  if (!is.null(incluir)) {
    total_antes <- nrow(d)
    d <- filter(d, map_lgl(rotulo, ~ any(str_starts(.x, fixed(incluir)))))
    # Independente do CV, por pedido — mas se NENHUMA das categorias-alvo
    # aparecer (rótulo mudou, indicador mudou de variável), é bug silencioso
    # esperando para acontecer. Aqui vira aviso, não silêncio.
    if (nrow(d) == 0) {
      registrar_ausente(paste0(
        "nenhuma das categorias de MOTIVOS_INCLUIR bateu com os rótulos de ",
        ind, " em ", geo, " (", total_antes, " categorias disponíveis — ",
        "confira se o rótulo do IBGE mudou de texto)"))
      return("*(nenhuma das categorias selecionadas está disponível para este indicador/geografia)*")
    }
    if (nrow(d) < length(incluir)) {
      registrar_ausente(sprintf(
        "%s em %s: só %d de %d categorias solicitadas apareceram na amostra",
        ind, geo, nrow(d), length(incluir)))
    }
  }

  linhas <- pmap_chr(list(d$rotulo, d$Estimativa, d$SE, d$cv),
    function(rotulo, est, se, cv) {
      linha_md(rotulo, num(est * 100, 1),
               sprintf("[%s; %s]", num(max(0, est - 1.96*se) * 100, 1), num((est + 1.96*se) * 100, 1)),
               num(cv, 1), classe_cv(cv))
    })
  c(linha_md("Motivo declarado", "Participação (%)", "IC 95%", "CV (%)", "Precisão"),
    "|---|---:|:---:|---:|---|", linhas)
}

# TABELA GEOGRÁFICA DE UM SUBCONJUNTO DE MOTIVOS
# -----------------------------------------------
# Pedido explícito: além da Tabela de motivos por categoria (Piauí sozinho,
# acima), duas tabelas com a mesma estrutura geográfica das seções 3.2 a 3.4
# (Agregados, Zona, Administrativo, Estrato agregado, extremos do estrato de 7
# dígitos) — só que para indicadores de MOTIVO, que são categóricos. Como cada
# indicador de motivo tem várias categorias por geografia, a tabela empilha um
# bloco de linhas geográficas por motivo selecionado, com uma coluna "Motivo"
# identificando qual bloco é qual.
#
# Chave por indicador: cada indicador de motivo pode pedir um subconjunto
# diferente de categorias.
MOTIVOS_TABELA_GEOGRAFICA <- list(
  Motivo_Desistencia_Desalentado = c(
    "Não havia trabalho na localidade",
    "Tinha que cuidar dos afazeres domésticos",
    "Não conseguia trabalho adequado"
  ),
  Motivo_Nao_Inicio_NemNem = c(
    "Por não querer trabalhar",
    "Tinha que cuidar dos afazeres domésticos",
    "Por problema de saúde ou gravidez"
  )
)

# Busca UMA linha (indicador x geografia x motivo). Diferente de linha_de(): lá
# a consulta é ambígua de propósito quando há mais de uma categoria (indicador
# não é de motivo); aqui a categoria é parte da chave de busca.
linha_motivo_geografico <- function(ind, geo, motivo_prefixo) {
  r <- base %>%
    filter(Indicador == ind, Regiao_Geografica == geo, Recorte_Demografico == "Total") %>%
    mutate(rotulo = map_chr(Subcategoria_Indicador, rotulo_motivo)) %>%
    filter(str_starts(rotulo, fixed(motivo_prefixo)))
  if (nrow(r) == 0) return(NULL)
  if (nrow(r) > 1) {
    # Dois rótulos batendo no mesmo prefixo seria coincidência rara demais
    # para ignorar em silêncio, mas não impede a tabela de sair.
    registrar_ausente(sprintf(
      "%s em %s: %d categorias casaram com o prefixo \"%s\" — usando a primeira",
      ind, geo, nrow(r), motivo_prefixo))
    r <- slice(r, 1)
  }
  mutate(r, cv = 100 * SE / Estimativa)
}

# Extremos entre estratos de 7 dígitos, restritos a UM motivo — análogo a
# extremos_micro(), mas filtrando a categoria antes de ordenar por tamanho.
extremos_micro_motivo <- function(ind, motivo_prefixo) {
  todos <- base %>%
    filter(Indicador == ind, Recorte_Demografico == "Total",
           str_starts(Regiao_Geografica, "Micro_")) %>%
    mutate(rotulo = map_chr(Subcategoria_Indicador, rotulo_motivo)) %>%
    filter(str_starts(rotulo, fixed(motivo_prefixo))) %>%
    mutate(cv = 100 * SE / Estimativa, codigo = str_remove(Regiao_Geografica, "^Micro_")) %>%
    arrange(desc(Estimativa))
  utilizaveis <- filter(todos, is.finite(cv), cv < CV_MAXIMO_EXTREMO)
  if (nrow(utilizaveis) >= 2) utilizaveis else todos
}

linha_percentual_ic <- function(recorte, categoria, motivo, r) {
  if (is.null(r)) {
    return(linha_md(recorte, categoria, motivo, "—", "—", "—", "—"))
  }
  linha_md(recorte, categoria, motivo,
           num(r$Estimativa * 100, 1),
           sprintf("[%s; %s]", num(max(0, r$Estimativa - 1.96 * r$SE) * 100, 1),
                   num((r$Estimativa + 1.96 * r$SE) * 100, 1)),
           num(r$cv, 1), classe_cv(r$cv))
}

tabela_motivos_geografico <- function(ind) {
  motivos <- MOTIVOS_TABELA_GEOGRAFICA[[ind]]
  if (is.null(motivos)) {
    stop("Nenhum motivo configurado em MOTIVOS_TABELA_GEOGRAFICA para ", ind,
         " — adicione uma entrada antes de usar tipo=motivos-geografico.")
  }

  linhas <- character(0)
  for (motivo in motivos) {
    bloco <- LINHAS_GEOGRAFICAS %>%
      filter(geografia %in% base$Regiao_Geografica) %>%
      pmap_chr(function(recorte, categoria, geografia) {
        r <- linha_motivo_geografico(ind, geografia, motivo)
        if (is.null(r)) registrar_ausente(paste(ind, "-", motivo, "- ausente em", geografia))
        linha_percentual_ic(recorte, categoria, motivo, r)
      })

    ex <- extremos_micro_motivo(ind, motivo)
    linhas_micro <- character(0)
    if (nrow(ex) >= 2) {
      topo <- slice_head(ex, n = 1); fundo <- slice_tail(ex, n = 1)
      linhas_micro <- c(
        linha_percentual_ic("Estrato (7 dígitos)", paste0("maior: ", topo$codigo), motivo, topo),
        linha_percentual_ic("Estrato (7 dígitos)", paste0("menor: ", fundo$codigo), motivo, fundo)
      )
    } else {
      registrar_ausente(paste(ind, "-", motivo, "- sem estratos finos suficientes para extremos"))
    }

    linhas <- c(linhas, bloco, linhas_micro)
  }

  c(linha_md("Recorte", "Categoria", "Motivo", "Estimativa (%)", "IC 95%", "CV (%)", "Precisão"),
    "|---|---|---|---:|:---:|---:|---|", linhas)
}

# A tabela-síntese da subseção 3.6: indicadores nas linhas, recortes nas colunas.
INDICADORES_SINTESE <- tribble(
  ~id,                                ~rotulo,
  "Taxa_Desocupacao",                 "Taxa de desocupação",
  "Chefes_Familia_Desocupados",       "Responsáveis desocupados",
  "Conribuintes_Desocupados",         "Responsáveis ou cônjuges desocupados",
  "Rendimento_Medio_Habitual",        "Rendimento médio habitual",
  "Percentual_Subremuneracao",        "Sub-remuneração",
  "Taxa_Informalidade",               "Taxa de informalidade",
  "Taxa_Subocupacao",                 "Sub-ocupação",
  "Proporcao_Ocupados_Escolarizados", "Ocupados com médio completo ou mais",
  "Desalentados_Forca_Ampliada",      "Desalentados (força ampliada)",
  "Desalentados_Fora_Forca",          "Desalentados (fora da força)",
  "Taxa_Nem_Nem",                     "Jovens nem-nem"
)

tabela_sintese <- function() {
  linhas <- pmap_chr(list(INDICADORES_SINTESE$id, INDICADORES_SINTESE$rotulo),
    function(id, rotulo) {
      celulas <- map_chr(LINHAS_TESTES$recorte, function(rec) exp_estrelas(id, rec))
      paste0("| ", rotulo, " | ", paste(celulas, collapse = " | "), " |")
    })
  c(linha_md("Indicador", "Zona", "Estrato administrativo", "Estrato agregado",
             "Estrato (7 díg.)", "Teresina × resto"),
    "|---|:---:|:---:|:---:|:---:|:---:|", linhas)
}

# ---- 6. O interpretador ------------------------------------------------------

# 6a. Blocos condicionais. Precisam vir ANTES das expressões: um bloco
# descartado não deve ter suas expressões internas resolvidas (resolver o que
# vai ser jogado fora produziria falsos "ausentes" no relatório final).
resolver_condicionais <- function(txt) {
  padrao <- regex("\\{\\{#(se-significativo|se-nao-significativo|se-existe)\\s+([^\\}]+?)\\}\\}(.*?)\\{\\{/se\\}\\}",
                  dotall = TRUE)
  while (str_detect(txt, padrao)) {
    m <- str_match(txt, padrao)
    tipo <- m[2]; args <- str_split(str_trim(m[3]), "\\s+")[[1]]; corpo <- m[4]

    manter <- switch(tipo,
      "se-significativo" = {
        r <- teste_reg(args[1], args[2]); !is.null(r) && r$p_ajustado < 0.05
      },
      "se-nao-significativo" = {
        r <- teste_reg(args[1], args[2]); !is.null(r) && r$p_ajustado >= 0.05
      },
      # se-existe cobre o caso da guarda: o teste pode simplesmente não existir,
      # e aí NENHUM dos dois textos acima serve — é preciso um terceiro.
      "se-existe" = !is.null(teste_reg(args[1], args[2]))
    )

    txt <- str_replace(txt, padrao, if (manter) str_replace_all(corpo, "\\$", "\\\\$") else "")
  }
  txt
}

# 6b. Expressões {{funcao arg arg}}.
#
# O modelo precisa poder FALAR sobre a própria sintaxe — o cabeçalho explica ao
# leitor como escrever uma expressão, e essa explicação não pode ser executada.
# A escapatória é a barra invertida: \{\{est ...\}\} atravessa o interpretador
# e sai como texto literal.
proteger_literais <- function(txt) str_replace_all(txt, "\\\\\\{\\\\\\{", "\u0001LIT\u0001")
restaurar_literais <- function(txt) str_replace_all(txt, "\u0001LIT\u0001", "{{")

# POR QUE vapply() AQUI E NÃO A FUNÇÃO DIRETO EM str_replace_all()
# -----------------------------------------------------------------
# str_replace_all(string, pattern, function) não tem contrato fixo de
# chamada entre versões do stringr: em 1.5.1 (o que roda aqui) a função é
# chamada UMA VEZ POR OCORRÊNCIA, com um vetor escalar — foi assim que este
# código foi escrito e testado. Em versões mais novas (confirmado com R
# 4.5.2/stringr atual), ela é chamada UMA VEZ PARA TODAS as ocorrências do
# texto inteiro, passando um vetor com todas de uma vez.
#
# O código original indexava o resultado de str_match() com m[2]/m[3], que só
# está correto quando m é uma matriz de UMA linha. Com várias ocorrências, m
# vira uma matriz de N linhas, e m[2] deixa de ser "grupo 2 da linha 1" — vira
# o segundo elemento em ordem de coluna, ou seja, o TEXTO INTEIRO da segunda
# ocorrência. Foi exatamente esse deslocamento que produziu o
# "{{{{trimestre}} ...}}" do erro: o nome da expressão virou o texto bruto de
# outra expressão do documento.
#
# vapply() torna a função explicitamente elemento-a-elemento e devolve sempre
# um vetor do mesmo tamanho da entrada — o contrato que str_replace_all()
# exige — então funciona da mesma forma em qualquer versão do stringr,
# chamada a função uma vez por ocorrência ou todas de uma vez.
resolver_expressoes <- function(txt) {
  resolver_uma <- function(inteiro) {
    m <- str_match(inteiro, "\\{\\{([a-z_]+)([^\\}]*)\\}\\}")
    nome <- m[1, 2]
    args <- str_split(str_trim(m[1, 3]), "\\s+")[[1]]
    args <- args[nzchar(args)]
    fn <- VOCABULARIO[[nome]]
    if (is.null(fn)) stop("Expressão desconhecida no modelo: {{", nome, " ...}}")
    valor <- do.call(fn, as.list(args))
    # $ é metacaractere de substituição no stringr; escapar evita corromper
    # valores em reais.
    str_replace_all(valor, "\\$", "\\\\$")
  }
  str_replace_all(txt, "\\{\\{([a-z_]+)([^\\}]*)\\}\\}",
                  function(inteiros) vapply(inteiros, resolver_uma, character(1), USE.NAMES = FALSE))
}

# 6c. Trechos que dependem de leitura humana.
# Nem todo vazio do modelo é preenchível por máquina: a interpretação de um
# resultado, a leitura conjunta de dois indicadores, a decisão de incluir um
# bloco demográfico. Marcá-los como erro faria o script falhar sempre; deixá-los
# invisíveis faria o relatório sair com buracos silenciosos. A saída é gerar um
# marcador impossível de não ver, e contá-los no fim.
redacoes <- new.env(parent = emptyenv())
redacoes$itens <- character(0)

resolver_redigir <- function(linhas) {
  map_chr(linhas, function(l) {
    d <- str_match(l, "^\\s*<!--\\s*@redigir:\\s*(.*?)\\s*-->\\s*$")
    if (is.na(d[1])) return(l)
    redacoes$itens <- c(redacoes$itens, d[2])
    paste0("> **A REDIGIR** — ", d[2])
  })
}

# 6d. Diretivas de tabela: a linha inteira é trocada pela tabela gerada.
resolver_tabelas <- function(linhas) {
  saida <- character(0)
  for (l in linhas) {
    d <- str_match(l, "^\\s*<!--\\s*@tabela\\s+(.*?)\\s*-->\\s*$")
    if (is.na(d[1])) { saida <- c(saida, l); next }

    pares <- str_match_all(d[2], "([a-z]+)=(\\S+)")[[1]]
    arg <- setNames(pares[, 3], pares[, 2])
    tipo <- arg[["tipo"]]

    tabela <- switch(tipo,
      geografica  = tabela_geografica(arg[["indicador"]]),
      testes      = tabela_testes(arg[["indicador"]]),
      formalidade = tabela_formalidade(),
      motivos     = tabela_motivos(arg[["indicador"]],
                                   if ("geografia" %in% names(arg)) arg[["geografia"]] else "Piauí"),
      "motivos-geografico" = tabela_motivos_geografico(arg[["indicador"]]),
      sintese     = tabela_sintese(),
      stop("Tipo de tabela desconhecido: ", tipo)
    )
    saida <- c(saida, tabela)
  }
  saida
}

# ---- 7. Execução -------------------------------------------------------------

if (!file.exists(MODELO)) stop("Não encontrei o modelo em ", MODELO)

message("Preenchendo ", MODELO, " para ", sufixo, "...")

linhas <- read_lines(MODELO)

# As "Notas de revisão do texto atual" são andaime de trabalho, não parte da
# publicação: ficam no modelo e saem da edição gerada.
corte <- which(str_detect(linhas, "^## Notas de revisão do texto atual"))
if (length(corte) == 1) {
  message("  -> removendo as notas de revisão (linha ", corte, " em diante)")
  linhas <- linhas[seq_len(corte - 1)]
  while (length(linhas) && str_trim(tail(linhas, 1)) %in% c("", "---")) {
    linhas <- head(linhas, -1)
  }
}

# O banner "isto é o modelo, não o relatório" só faz sentido para quem abre
# output/relatorio_trimestral.md. Na edição gerada ele é ruído — e pior,
# ficaria mentindo, já que o próprio arquivo deixaria de ser o modelo.
remover_somente_modelo <- function(linhas) {
  ini <- which(str_detect(linhas, fixed("<!-- @somente-modelo -->")))
  fim <- which(str_detect(linhas, fixed("<!-- /@somente-modelo -->")))
  if (length(ini) == 0) return(linhas)
  if (length(ini) != 1 || length(fim) != 1 || fim < ini) {
    stop("Marcadores @somente-modelo malformados no modelo (abertura e ",
         "fechamento devem aparecer uma vez cada, na ordem certa).")
  }
  linhas[-(ini:fim)]
}
linhas <- remover_somente_modelo(linhas)

linhas <- resolver_redigir(linhas)
linhas <- resolver_tabelas(linhas)
texto  <- paste(linhas, collapse = "\n")
texto  <- proteger_literais(texto)
texto  <- resolver_condicionais(texto)
texto  <- resolver_expressoes(texto)

# ---- 8. Verificação ----------------------------------------------------------
# Nada sai daqui pela metade. Um marcador esquecido é erro, não aviso.

sobraram <- str_extract_all(texto, "\\{\\{[^\\}]*\\}\\}|\\{[A-Z_]{2,}[^\\}]*\\}")[[1]]
if (length(sobraram) > 0) {
  message("\nMARCADORES NÃO RESOLVIDOS (", length(sobraram), "):")
  for (s in unique(sobraram)) {
    message("  ", str_trunc(s, 100), "   (", sum(sobraram == s), "x)")
  }
  stop("O relatório não foi gravado. Corrija o modelo ou o vocabulário e rode de novo.")
}

# Quando um valor não existe na base, a expressão vira travessão — e o "%" que
# o modelo escreveu logo depois fica órfão ("—%"). Limpar aqui é mais simples
# que condicionar cada unidade no modelo.
texto <- str_replace_all(texto, "—%", "—")

# Só agora os literais escapados voltam a ser chaves: se voltassem antes, a
# verificação acima os acusaria como marcadores esquecidos.
texto <- restaurar_literais(texto)
texto <- str_replace_all(texto, "\\\\\\}\\\\\\}", "}}")

# Cabeçalho invisível na renderização (comentário HTML), visível em qualquer
# listagem de arquivo, diff ou "raw view". Existe para que ninguém confunda
# esta edição com o modelo — ou uma edição velha com a mais recente — só de
# olhar o arquivo errado no navegador do repositório.
cabecalho <- sprintf(
  "<!-- GERADO AUTOMATICAMENTE por R/09_preencher_relatorio.R a partir de %s. Trimestre: %s. Não editar à mão — a próxima rodada sobrescreve sem aviso. -->\n\n",
  MODELO, sufixo
)
texto <- paste0(cabecalho, texto)

write_lines(texto, SAIDA)

message("  -> ", SAIDA, " (", format(nchar(texto), big.mark = "."), " caracteres)")

if (length(ausentes$itens) > 0) {
  message("\nValores ausentes na base, exibidos como travessão (", length(ausentes$itens), "):")
  for (a in unique(ausentes$itens)) message("  ", a)
  message("\nIsso é esperado quando o pipeline roda sobre um desenho recortado ",
          "(sem Brasil/Nordeste) ou quando a guarda de variância recusou o teste.")
}

if (length(redacoes$itens) > 0) {
  message("\nTRECHOS A REDIGIR (", length(redacoes$itens), ") — procure por ",
          "\"A REDIGIR\" no arquivo gerado:")
  for (i in seq_along(redacoes$itens)) {
    message("  ", i, ". ", str_trunc(redacoes$itens[i], 90))
  }
}


# Convert a file using the high-level wrapper
if (CONVERTER_DOCX){
  message("Convertendo arquivo markdown para documento word")
  
  # Usa um custom-refence.docx pra formatar mais bonitinho no word e publicar
  result <- try(pandoc_run(args = c(SAIDA, "-o", str_replace(SAIDA, "md", "docx"), 
                                    "--reference-doc = custom-reference.docx --trace")) )
  
  if (inherits(result, "try-error")) {
    message("Erro ao rodar o pandoc, verifique se o pacote está instalado, se o arquivo de destino",
    "está em execução ou se existe o custom-reference.docx")
  } else if (length(result) == 0){
    message("Conversão rodada com sucesso")
  }
  
}

message("\nConcluído: ", sufixo)
