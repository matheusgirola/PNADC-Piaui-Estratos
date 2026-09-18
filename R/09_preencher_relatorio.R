# ==============================================================================
# 09_preencher_relatorio.R — preenche o modelo do relatório com os números do
# trimestre.
#
# Estrutura do relatório (decisões de 17/09/2026, CONTEXTO_PROJETO.md §8.7):
# público gestor, corpo curto, organizado por pergunta e não por indicador.
# O território fica numa MATRIZ por dimensão (linhas = indicadores, colunas =
# Piauí, 5 estratos agregados e zona urbana/rural). Tudo o mais vai para o anexo.
#
# Marca de cada célula — vem da SÉRIE (triagem de confiabilidade, R/11), não do
# CV do trimestre corrente:
#   valor         p80 do CV < 15% na janela principal (critério c)
#   valor †       15% <= p80 < 30%
#   –             p80 >= 30%, instável, ou sem série para a combinação
# Brasil e Nordeste não entram na série (só Piauí); para eles vale o CV do
# trimestre, com os mesmos cortes.
#
# Significância: o teste global que o 01 já produz (svyglm + regTermTest LRT /
# svychisq, p ajustado por BH). Como cada linha da matriz é um indicador com o
# seu teste, os asteriscos ficam numa coluna logo depois do grupo testado.
#
# AVISO: o script FALHA se sobrar qualquer marcador não resolvido.
#
# USO:   Rscript R/09_preencher_relatorio.R   (trimestre de R/00_config.R)
# ENTRADA: output/relatorio_trimestral.md (modelo), output/base_<sufixo>.csv,
#          output/testes_regionais_<sufixo>.csv, output/testes_significancia_<sufixo>.csv,
#          output/tabelas/triagem_confiabilidade.csv
# SAÍDA:   output/relatorio_trimestral_<sufixo>.md (+ .docx se CONVERTER_DOCX)
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
CONVERTER_DOCX <- TRUE

# ---- 1. Leitura ----------------------------------------------------------------

ler <- function(caminho, obrigatorio = TRUE) {
  if (!file.exists(caminho)) {
    if (obrigatorio) stop("Não encontrei ", caminho, ".\nRode o 01 (e o R/11 para a triagem) antes deste script.")
    return(NULL)
  }
  read_csv(caminho, show_col_types = FALSE)
}

base        <- ler(sprintf("output/base_%s.csv", sufixo)) %>% mutate(cv = 100 * SE / Estimativa)
testes_reg  <- ler(sprintf("output/testes_regionais_%s.csv", sufixo))
testes_demo <- ler(sprintf("output/testes_significancia_%s.csv", sufixo))
triagem     <- ler("output/tabelas/triagem_confiabilidade.csv") %>%
  filter(janela == "principal", amostragem == "todos")

CHAVE <- c("Indicador", "Subcategoria_Indicador", "Regiao_Geografica",
           "Recorte_Demografico", "Categoria_Demografica")

ausentes <- new.env(parent = emptyenv())
ausentes$itens <- character(0)
registrar_ausente <- function(msg) { ausentes$itens <- c(ausentes$itens, msg); invisible(NULL) }

# ---- 2. Catálogo do relatório -----------------------------------------------------
# Ordem, rótulo, unidade e dimensão de cada indicador — num lugar só. `destaque`
# marca o núcleo que vai para a tabela de destaques. Indicadores com várias
# categorias (composição da PIT, motivos) têm `multiplo = TRUE`: cada categoria
# vira uma linha.

CATALOGO <- tribble(
  ~id,                                   ~rotulo,                                                  ~unidade, ~dimensao,       ~destaque, ~multiplo,
  "Taxa_Participacao",                   "Taxa de participação na força de trabalho",              "pct",    "ocupacao",      TRUE,      FALSE,
  "Nivel_Ocupacao",                      "Nível da ocupação",                                      "pct",    "ocupacao",      TRUE,      FALSE,
  "Taxa_Desocupacao",                    "Taxa de desocupação",                                    "pct",    "ocupacao",      TRUE,      FALSE,
  "Taxa_Composta_Subutilizacao",         "Taxa composta de subutilização",                         "pct",    "ocupacao",      TRUE,      FALSE,
  "Chefes_Familia_Desocupados",          "Responsáveis pelo domicílio entre os desocupados",       "pct",    "ocupacao",      FALSE,     FALSE,
  "Conribuintes_Desocupados",            "Responsáveis ou cônjuges entre os desocupados",          "pct",    "ocupacao",      FALSE,     FALSE,
  "Pessoas_Idade_Trabalhar",             "Pessoas em idade de trabalhar",                          "mil",    "ocupacao",      FALSE,     FALSE,
  "Pessoas_Forca_Trabalho",              "Pessoas na força de trabalho",                           "mil",    "ocupacao",      FALSE,     FALSE,
  "Pessoas_Fora_Forca",                  "Pessoas fora da força de trabalho",                      "mil",    "ocupacao",      FALSE,     FALSE,
  "Pessoas_Ocupadas",                    "Pessoas ocupadas",                                       "mil",    "ocupacao",      FALSE,     FALSE,
  "Pessoas_Desocupadas",                 "Pessoas desocupadas",                                    "mil",    "ocupacao",      FALSE,     FALSE,
  "Pessoas_Subutilizadas",               "Pessoas subutilizadas",                                  "mil",    "ocupacao",      FALSE,     FALSE,
  "Taxa_Informalidade",                  "Taxa de informalidade",                                  "pct",    "qualidade",     TRUE,      FALSE,
  "Taxa_Subocupacao",                    "Subocupação por insuficiência de horas",                 "pct",    "qualidade",     FALSE,     FALSE,
  "Percentual_Subremuneracao",           "Sub-remuneração (rendimento-hora abaixo do mínimo)",     "pct",    "qualidade",     FALSE,     FALSE,
  "Proporcao_Ocupados_Escolarizados",    "Ocupados com ensino médio completo ou mais",             "pct",    "qualidade",     FALSE,     FALSE,
  "Empregados_Setor_Privado",            "Empregados no setor privado",                            "mil",    "qualidade",     FALSE,     FALSE,
  "Empregados_Setor_Publico",            "Empregados no setor público",                            "mil",    "qualidade",     FALSE,     FALSE,
  "Ocupados_Agropecuaria",               "Ocupados na agropecuária",                               "mil",    "qualidade",     FALSE,     FALSE,
  "Rendimento_Medio_Habitual",           "Rendimento médio real habitual",                         "reais",  "rendimento",    TRUE,      FALSE,
  "Rendimento_Formal",                   "Rendimento médio dos formais",                           "reais",  "rendimento",    FALSE,     FALSE,
  "Rendimento_Informal",                 "Rendimento médio dos informais",                         "reais",  "rendimento",    FALSE,     FALSE,
  "Desigualdade_Formal_Informal",        "Razão entre rendimento formal e informal",               "razao",  "rendimento",    FALSE,     FALSE,
  "Gini_Rendimento_Habitual_Trabalho",   "Índice de Gini do rendimento do trabalho",               "gini",   "rendimento",    TRUE,      FALSE,
  "Desalentados_Forca_Ampliada",         "Desalentados na força de trabalho ampliada",             "pct",    "vulnerabilidade", FALSE,   FALSE,
  "Desalentados_Fora_Forca",             "Desalentados na força de trabalho potencial",            "pct",    "vulnerabilidade", FALSE,   FALSE,
  "Taxa_Nem_Nem",                        "Jovens de 14 a 29 anos que não estudam nem trabalham",   "pct",    "vulnerabilidade", TRUE,    FALSE,
  "Distribuicao_PIT_por_Sexo",           "Sexo",                                                   "pct",    "populacao",     FALSE,     TRUE,
  "Distribuicao_PIT_por_Raca",           "Cor ou raça",                                            "pct",    "populacao",     FALSE,     TRUE,
  "Distribuicao_PIT_por_Faixa_Etaria_SIDRA", "Faixa etária",                                       "pct",    "populacao",     FALSE,     TRUE,
  "Distribuicao_PIT_por_Instrucao_SIDRA", "Nível de instrução",                                    "pct",    "populacao",     FALSE,     TRUE,
  "Motivo_Desistencia_Desalentado",      "Por que o desalentado desistiu de procurar",             "pct",    "motivos",       FALSE,     TRUE,
  "Motivo_Nao_Procura_NemNem",           "Por que o jovem nem-nem não procurou trabalho",          "pct",    "motivos",       FALSE,     TRUE
)

info <- function(id) {
  r <- CATALOGO[CATALOGO$id == id, ]
  if (nrow(r) != 1) stop("Indicador fora do CATALOGO do 09: ", id)
  r
}

# Colunas da matriz territorial. Estrato administrativo e "Teresina × resto"
# ficam fora do corpo: Capital = Agreg_Teresina, Resto da RIDE = Entorno, Resto
# da UF = soma dos outros três agregados (§8.7).
GEO_AGREG <- c(
  "Teresina"                   = "Agreg_Teresina",
  "Entorno metropolitano"      = "Agreg_Entorno metropolitano de Teresina (PI)",
  "Centro-Leste"               = "Agreg_Centro-Leste do Piauí",
  "Baixo Parnaíba"             = "Agreg_Baixo Parnaíba do Piauí",
  "Alto Parnaíba e Chapadas"   = "Agreg_Alto Parnaíba e Chapadas Sul do Piauí"
)
GEO_ZONA <- c("Urbana" = "Zona_Urbana", "Rural" = "Zona_Rural")

# Situação (dígito S do Estrato, AAAGGS): recorte de comparação adotado em
# 18/09/2026 ao lado de Zona e Estrato Agregado — CONTEXTO_PROJETO.md §1 e §8.8.
GEO_SITUACAO <- c("Urbano tradicional" = "Situacao_Urbano tradicional",
                  "Rural"              = "Situacao_Rural",
                  "FCU"                = "Situacao_FCU")

# Geografias do anexo (tabela completa por indicador).
GEO_ANEXO <- tribble(
  ~recorte,           ~categoria,              ~geografia,
  "Agregados",        "Brasil",                "Brasil",
  "Agregados",        "Nordeste",              "Nordeste",
  "Agregados",        "Piauí",                 "Piauí",
  "Agregados",        "Teresina",              "Teresina",
  "Zona",             "Urbana",                "Zona_Urbana",
  "Zona",             "Rural",                 "Zona_Rural",
  "Situação",         "Urbano tradicional",    "Situacao_Urbano tradicional",
  "Situação",         "Rural",                 "Situacao_Rural",
  "Situação",         "FCU",                   "Situacao_FCU",
  "Administrativo",   "Capital",               "Admin_Capital",
  "Administrativo",   "Resto da RIDE",         "Admin_Resto da RIDE (Região Integrada de Desenvolvimento Econômico, excluindo a capital)",
  "Administrativo",   "Resto da UF",           "Admin_Resto da UF  (Unidade da Federação, excluindo a região metropolitana e a RIDE)",
  "Estrato agregado", "Teresina",              "Agreg_Teresina",
  "Estrato agregado", "Entorno metropolitano", "Agreg_Entorno metropolitano de Teresina (PI)",
  "Estrato agregado", "Centro-Leste",          "Agreg_Centro-Leste do Piauí",
  "Estrato agregado", "Baixo Parnaíba",        "Agreg_Baixo Parnaíba do Piauí",
  "Estrato agregado", "Alto Parnaíba e Chapadas Sul", "Agreg_Alto Parnaíba e Chapadas Sul do Piauí"
)

RECORTES_TESTE <- tribble(
  ~rotulo,                              ~recorte,
  "Zona (urbana × rural)",              "Zona",
  "Situação (rural × urbano × FCU)",    "Situacao",
  "Estrato administrativo",             "Estrato_Administrativo",
  "Estrato agregado",                   "Estrato_Agregado",
  "Teresina × resto do Piauí",          "Teresina_x_Resto_Piaui"
)

RECORTES_DEMO <- c(Sexo = "Sexo", Raca = "Cor ou raça", Faixa_Etaria_trabalho = "Faixa etária",
                   Instrucao_agregado = "Instrução (2 grupos)", Instrucao = "Instrução (7 níveis)")

# ---- 3. Formatação ------------------------------------------------------------------

num <- function(x, casas = 1) {
  ifelse(is.na(x), "—", formatC(x, format = "f", digits = casas, big.mark = ".", decimal.mark = ","))
}

# Valor na unidade de exibição (sem símbolo) e com símbolo.
escala <- function(x, u) switch(u, pct = 100 * x, mil = x / 1000, x)
casas_de <- function(u) switch(u, pct = 1, mil = 0, reais = 0, razao = 2, gini = 3)
formatar <- function(x, u) {
  v <- num(escala(x, u), casas_de(u))
  if (u == "reais") paste0("R$ ", v) else v
}
unidade_rotulo <- function(u) switch(u, pct = "%", mil = "mil pessoas", reais = "R$", razao = "razão", gini = "índice")
com_unidade    <- function(rotulo, u) if (u %in% c("razao", "gini")) rotulo else paste0(rotulo, " (", unidade_rotulo(u), ")")

classe_cv <- function(cv) {
  case_when(is.na(cv) ~ "—", cv < 5 ~ "excelente", cv < 15 ~ "boa", cv < 30 ~ "regular", TRUE ~ "baixa")
}

estrelas <- function(p) {
  case_when(is.na(p) ~ "—", p < 0.001 ~ "\\*\\*\\*", p < 0.01 ~ "\\*\\*", p < 0.05 ~ "\\*", TRUE ~ "ns")
}

linha_md <- function(...) paste0("| ", paste(c(...), collapse = " | "), " |")

# Rótulo legível de uma categoria: tira o nome da variável colado na frente.
PREFIXOS_CATEGORIA <- "^(Sexo_pit|Raca_pit|Faixa_Etaria_sidra|Faixa_Etaria_projeto|Instrucao_sidra|Instrucao_projeto|motivo_[a-z_]+?_grupo)"
rotulo_categoria <- function(sub) str_remove(sub, PREFIXOS_CATEGORIA)

# ---- 4. Consulta -----------------------------------------------------------------------

linhas_base <- function(ind, geo, recorte = "Total", categoria = "Total", dados = base) {
  dados %>% filter(Indicador == ind, Regiao_Geografica == geo,
                   Recorte_Demografico == recorte, Categoria_Demografica == categoria)
}

linha_de <- function(ind, geo, recorte = "Total", categoria = "Total", sub = NULL, dados = base) {
  r <- linhas_base(ind, geo, recorte, categoria, dados)
  if (!is.null(sub)) r <- filter(r, Subcategoria_Indicador == sub)
  if (nrow(r) == 0) return(NULL)
  if (nrow(r) > 1) stop("Consulta ambígua: ", ind, " / ", geo, " devolveu ", nrow(r), " linhas (indicador com categorias?).")
  r
}

# Marca da célula pela série: "ok", "adaga" ou "traco".
marca_de <- function(ind, sub, geo, recorte = "Total", categoria = "Total", cv_atual = NA_real_) {
  t <- triagem %>% filter(Indicador == ind, Subcategoria_Indicador == sub, Regiao_Geografica == geo,
                          Recorte_Demografico == recorte, Categoria_Demografica == categoria)
  if (nrow(t) == 0) {
    # Brasil/Nordeste (fora da série): CV do trimestre.
    if (geo %in% c("Brasil", "Nordeste") && !is.na(cv_atual)) {
      return(if (cv_atual < 15) "ok" else if (cv_atual < 30) "adaga" else "traco")
    }
    return("traco")
  }
  if (nrow(t) > 1) stop("Triagem ambígua para ", ind, " / ", geo)
  if (isTRUE(t$instavel) || is.na(t$cv_p80) || t$cv_p80 >= 30) "traco"
  else if (t$cv_p80 >= 15) "adaga" else "ok"
}

celula <- function(ind, geo, sub = NULL, recorte = "Total", categoria = "Total") {
  u <- info(ind)$unidade
  r <- linha_de(ind, geo, recorte, categoria, sub)
  if (is.null(r)) { registrar_ausente(paste(ind, sub %||% "", "em", geo)); return("—") }
  m <- marca_de(ind, r$Subcategoria_Indicador, geo, recorte, categoria, r$cv)
  switch(m, ok = formatar(r$Estimativa, u), adaga = paste0(formatar(r$Estimativa, u), " †"), traco = "–")
}

subcategorias <- function(ind, geo = "Piauí") {
  subs <- unique(linhas_base(ind, geo)$Subcategoria_Indicador)
  if (isTRUE(info(ind)$multiplo)) {
    # Categoria sem o prefixo esperado vem de uma base gravada antes da
    # mudança no catálogo (ex.: motivos antes do agrupamento de 17/09/2026).
    velhas <- subs[!str_detect(subs, PREFIXOS_CATEGORIA)]
    if (length(velhas) > 0) {
      registrar_ausente(sprintf("%s: %d categoria(s) fora do catálogo atual na base (base antiga? rode o 01 de novo)",
                                ind, length(velhas)))
    }
    subs <- setdiff(subs, velhas)
  }
  subs
}


teste_reg <- function(ind, recorte) {
  r <- testes_reg %>% filter(Indicador == ind, Recorte_Regional == recorte)
  if (nrow(r) == 0) NULL else r
}

# ---- 5. Vocabulário das expressões {{ }} --------------------------------------------

exp_est <- function(ind, geo) {
  r <- linha_de(ind, geo)
  if (is.null(r)) { registrar_ausente(paste("estimativa", ind, "em", geo)); return("—") }
  formatar(r$Estimativa, info(ind)$unidade)
}

exp_ic <- function(ind, geo) {
  r <- linha_de(ind, geo)
  if (is.null(r)) { registrar_ausente(paste("IC", ind, "em", geo)); return("—") }
  u <- info(ind)$unidade
  sprintf("(%s, %s)", formatar(max(0, r$Estimativa - 1.96 * r$SE), u), formatar(r$Estimativa + 1.96 * r$SE, u))
}

exp_cv <- function(ind, geo) {
  r <- linha_de(ind, geo)
  if (is.null(r)) return("—")
  num(r$cv, 1)
}

exp_p <- function(ind, recorte) {
  r <- teste_reg(ind, recorte)
  if (is.null(r)) return("—")
  if (r$p_ajustado < 0.001) "< 0,001" else num(r$p_ajustado, 3)
}

exp_estrelas <- function(ind, recorte) {
  r <- teste_reg(ind, recorte)
  if (is.null(r)) return("—")
  estrelas(r$p_ajustado)
}

exp_dif <- function(ind, geo_a, geo_b) {
  a <- linha_de(ind, geo_a); b <- linha_de(ind, geo_b)
  if (is.null(a) || is.null(b)) { registrar_ausente(paste("diferença", ind, geo_a, geo_b)); return("—") }
  formatar(abs(a$Estimativa - b$Estimativa), info(ind)$unidade)
}

exp_pct_de <- function(ind, geo, referencia) {
  a <- linha_de(ind, geo); r <- linha_de(ind, referencia)
  if (is.null(a) || is.null(r)) { registrar_ausente(paste(ind, geo, "como % de", referencia)); return("—") }
  num(100 * a$Estimativa / r$Estimativa, 1)
}

VOCABULARIO <- list(
  est       = exp_est,
  ic        = exp_ic,
  cv        = exp_cv,
  p         = exp_p,
  estrelas  = exp_estrelas,
  dif       = exp_dif,
  pct_de    = exp_pct_de,
  trimestre = function() sprintf("%dº trimestre de %d", TRIMESTRE_REF, ANO_REF),
  sufixo    = function() sufixo,
  sm_hora   = function() num(sm_hora_corrente, 2)
)

# ---- 6. Tabelas geradas por diretiva ------------------------------------------------

# 6a. Destaques: Brasil × Nordeste × Piauí.
tabela_destaques <- function() {
  linhas <- CATALOGO %>% filter(destaque) %>% pmap_chr(function(id, rotulo, unidade, ...) {
    linha_md(com_unidade(rotulo, unidade),
             celula(id, "Brasil"), celula(id, "Nordeste"), paste0("**", celula(id, "Piauí"), "**"))
  })
  c(linha_md("Indicador", "Brasil", "Nordeste", "Piauí"), "|---|---:|---:|---:|", linhas)
}

# 6b. Matriz territorial de uma dimensão. Linha só entra no corpo se o Piauí
# passar na triagem (marca "ok" ou "†"); as demais ficam no anexo.
linhas_da_dimensao <- function(dim) {
  CATALOGO %>% filter(dimensao == dim) %>%
    pmap_dfr(function(id, rotulo, unidade, multiplo, ...) {
      subs <- subcategorias(id)
      if (length(subs) == 0) { registrar_ausente(paste(id, "sem linhas no Piauí")); return(tibble()) }
      tibble(id = id, sub = subs,
             rotulo = if (multiplo) paste0(rotulo, ": ", rotulo_categoria(subs))
                      else com_unidade(rotulo, unidade))
    })
}

tabela_matriz <- function(dim) {
  L <- linhas_da_dimensao(dim)
  linhas <- pmap_chr(L, function(id, sub, rotulo) {
    pi <- celula(id, "Piauí", sub)
    if (pi == "–") return(NA_character_)
    agreg     <- map_chr(GEO_AGREG,     ~ celula(id, .x, sub))
    zona      <- map_chr(GEO_ZONA,      ~ celula(id, .x, sub))
    situacao  <- map_chr(GEO_SITUACAO,  ~ celula(id, .x, sub))
    linha_md(rotulo, pi, agreg, exp_estrelas(id, "Estrato_Agregado"),
             zona, exp_estrelas(id, "Zona"),
             situacao, exp_estrelas(id, "Situacao"))
  })
  linhas <- linhas[!is.na(linhas)]
  if (length(linhas) == 0) return("*(nenhum indicador desta dimensão passou na triagem no nível do Piauí)*")
  c(linha_md("Indicador", "Piauí", names(GEO_AGREG), "Teste estratos",
             names(GEO_ZONA), "Teste zona", names(GEO_SITUACAO), "Teste situação"),
    paste0("|---|", strrep("---:|", 1 + length(GEO_AGREG)), ":---:|",
           strrep("---:|", length(GEO_ZONA)), ":---:|",
           strrep("---:|", length(GEO_SITUACAO)), ":---:|"),
    linhas)
}

# 6c. Composição da PIT e motivos: Brasil × Nordeste × Piauí, uma linha por
# categoria.
tabela_categorias <- function(dim) {
  L <- linhas_da_dimensao(dim)
  if (nrow(L) == 0) return("*(sem dados desta tabela na base do trimestre)*")
  linhas <- pmap_chr(L, function(id, sub, rotulo) {
    linha_md(rotulo, celula(id, "Brasil", sub), celula(id, "Nordeste", sub), celula(id, "Piauí", sub))
  })
  c(linha_md("Categoria", "Brasil (%)", "Nordeste (%)", "Piauí (%)"), "|---|---:|---:|---:|", linhas)
}

# 6d. Pontos de atenção — gerados só a partir do que é significativo E passa
# na triagem (regra de redação, §8.7). Tudo em tópicos.
pontos_territoriais <- function() {
  L <- map_dfr(c("ocupacao", "qualidade", "rendimento", "vulnerabilidade"), linhas_da_dimensao) %>%
    filter(!str_detect(id, "^(Distribuicao|Motivo)"))
  out <- pmap_chr(L, function(id, sub, rotulo) {
    u <- info(id)$unidade
    partes <- character(0)
    t_est <- teste_reg(id, "Estrato_Agregado")
    if (!is.null(t_est) && t_est$p_ajustado < 0.05) {
      # Células "–" ficam de fora; as com † entram, com a marca — excluí-las
      # faria apontar como maior um estrato que não é (ex.: rendimento de
      # Teresina, † na série).
      v <- map_dfr(names(GEO_AGREG), function(nm) {
        tibble(nome = nm, txt = celula(id, GEO_AGREG[[nm]], sub),
               est = linha_de(id, GEO_AGREG[[nm]], sub = sub)$Estimativa %||% NA_real_)
      }) %>% filter(txt != "–", txt != "—")
      if (nrow(v) >= 2) {
        mx <- v[which.max(v$est), ]; mn <- v[which.min(v$est), ]
        partes <- c(partes, sprintf("entre os estratos, maior em %s (%s) e menor em %s (%s) %s",
                                    mx$nome, mx$txt, mn$nome, mn$txt, estrelas(t_est$p_ajustado)))
      }
    }
    t_z <- teste_reg(id, "Zona")
    if (!is.null(t_z) && t_z$p_ajustado < 0.05) {
      ur <- linha_de(id, "Zona_Urbana", sub = sub); ru <- linha_de(id, "Zona_Rural", sub = sub)
      cu <- celula(id, "Zona_Urbana", sub); cr <- celula(id, "Zona_Rural", sub)
      if (!is.null(ur) && !is.null(ru) && !cu %in% c("–", "—") && !cr %in% c("–", "—")) {
        partes <- c(partes, sprintf("urbana %s × rural %s %s", cu, cr, estrelas(t_z$p_ajustado)))
      }
    }
    t_s <- teste_reg(id, "Situacao")
    if (!is.null(t_s) && t_s$p_ajustado < 0.05) {
      v <- map_dfr(names(GEO_SITUACAO), function(nm) {
        tibble(nome = nm, txt = celula(id, GEO_SITUACAO[[nm]], sub),
               est = linha_de(id, GEO_SITUACAO[[nm]], sub = sub)$Estimativa %||% NA_real_)
      }) %>% filter(txt != "–", txt != "—")
      if (nrow(v) >= 2) {
        mx <- v[which.max(v$est), ]; mn <- v[which.min(v$est), ]
        partes <- c(partes, sprintf("por situação, maior em %s (%s) e menor em %s (%s) %s",
                                    mx$nome, mx$txt, mn$nome, mn$txt, estrelas(t_s$p_ajustado)))
      }
    }
    if (length(partes) == 0) NA_character_ else sprintf("- **%s**: %s.", rotulo, paste(partes, collapse = "; "))
  })
  out <- out[!is.na(out)]
  if (length(out) == 0) "- Nenhuma diferença territorial significativa com precisão suficiente neste trimestre." else out
}

# Recortes demográficos: entram só se a diferença é significativa naquele
# território (p ajustado) E todas as categorias do recorte, naquele território,
# passam na triagem.
pontos_demograficos <- function() {
  geos <- c(setNames(GEO_AGREG, names(GEO_AGREG)),
            setNames(GEO_ZONA, paste("Zona", tolower(names(GEO_ZONA)))),
            setNames(GEO_SITUACAO, paste("Situação", tolower(names(GEO_SITUACAO)))))
  cand <- testes_demo %>%
    filter(Regiao_Geografica %in% geos, Recorte_Demografico %in% names(RECORTES_DEMO),
           Indicador %in% CATALOGO$id, !is.na(p_ajustado), p_ajustado < 0.05)
  if (nrow(cand) == 0) return("*(nenhum recorte demográfico passou na regra neste trimestre)*")
  ok <- pmap_lgl(cand %>% select(Indicador, Regiao_Geografica, Recorte_Demografico),
    function(Indicador, Regiao_Geografica, Recorte_Demografico) {
      cel <- base %>% filter(Indicador == !!Indicador, Regiao_Geografica == !!Regiao_Geografica,
                             Recorte_Demografico == !!Recorte_Demografico)
      nrow(cel) >= 2 && all(pmap_chr(cel %>% select(Subcategoria_Indicador, Categoria_Demografica),
        function(Subcategoria_Indicador, Categoria_Demografica)
          marca_de(Indicador, Subcategoria_Indicador, Regiao_Geografica, Recorte_Demografico, Categoria_Demografica)) == "ok")
    })
  sel <- cand[ok, ] %>%
    mutate(territorio = names(geos)[match(Regiao_Geografica, geos)],
           rotulo = map_chr(Indicador, ~ info(.x)$rotulo),
           recorte = RECORTES_DEMO[Recorte_Demografico]) %>%
    group_by(rotulo, recorte, ordem = match(Indicador, CATALOGO$id)) %>%
    summarise(territorios = paste(territorio, collapse = ", "), .groups = "drop") %>%
    arrange(ordem, recorte)
  if (nrow(sel) == 0) return("*(nenhum recorte demográfico passou na regra neste trimestre)*")
  c(linha_md("Indicador", "Recorte", "Territórios onde a diferença é significativa e confiável"),
    "|---|---|---|", pmap_chr(sel, function(rotulo, recorte, ordem, territorios) linha_md(rotulo, recorte, territorios)))
}

# 6e. Anexos.
tabela_anexo_indicadores <- function() {
  out <- character(0); n <- 0
  for (k in seq_len(nrow(CATALOGO))) {
    i <- CATALOGO[k, ]
    subs <- if (i$multiplo) subcategorias(i$id) else
      unique(base$Subcategoria_Indicador[base$Indicador == i$id & base$Recorte_Demografico == "Total"])
    if (length(subs) == 0) { registrar_ausente(paste("anexo:", i$id, "sem linhas")); next }
    for (sub in subs) {
      n <- n + 1
      titulo <- if (i$multiplo) paste0(i$rotulo, ": ", rotulo_categoria(sub)) else i$rotulo
      linhas <- GEO_ANEXO %>% filter(geografia %in% base$Regiao_Geografica) %>%
        pmap_chr(function(recorte, categoria, geografia) {
          r <- linha_de(i$id, geografia, sub = sub)
          if (is.null(r)) return(linha_md(recorte, categoria, "—", "—", "—", "—", "—", "—"))
          t <- triagem %>% filter(Indicador == i$id, Subcategoria_Indicador == sub, Regiao_Geografica == geografia,
                                  Recorte_Demografico == "Total")
          p80 <- if (nrow(t) == 1) num(t$cv_p80, 1) else "—"
          marca <- switch(marca_de(i$id, sub, geografia, cv_atual = r$cv), ok = "", adaga = "†", traco = "–")
          linha_md(recorte, categoria, formatar(r$Estimativa, i$unidade),
                   sprintf("(%s, %s)", formatar(max(0, r$Estimativa - 1.96 * r$SE), i$unidade),
                           formatar(r$Estimativa + 1.96 * r$SE, i$unidade)),
                   num(r$cv, 1), classe_cv(r$cv), p80, marca)
        })
      out <- c(out, "",
               sprintf("**Tabela D.%d** — %s, por recorte geográfico — %s", n,
                       com_unidade(titulo, i$unidade), VOCABULARIO$trimestre()),
               "",
               linha_md("Recorte", "Categoria", "Estimativa", "IC 95%", "CV (%)", "Precisão", "p80 do CV na série (%)", "Marca"),
               "|---|---|---:|:---:|---:|---|---:|:---:|", linhas, "",
               "Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.")
    }
  }
  out
}

tabela_anexo_testes <- function() {
  ids <- CATALOGO$id[CATALOGO$id %in% testes_reg$Indicador & !CATALOGO$multiplo]
  linhas <- map_chr(ids, function(id) {
    cel <- map_chr(RECORTES_TESTE$recorte, function(rec) {
      r <- teste_reg(id, rec)
      if (is.null(r)) "—" else sprintf("%s / %s %s", if (r$p_valor < 0.001) "< 0,001" else num(r$p_valor, 3),
                                        if (r$p_ajustado < 0.001) "< 0,001" else num(r$p_ajustado, 3), estrelas(r$p_ajustado))
    })
    linha_md(info(id)$rotulo, cel)
  })
  c(linha_md("Indicador", RECORTES_TESTE$rotulo), paste0("|---|", strrep(":---:|", nrow(RECORTES_TESTE))), linhas)
}

tabela_anexo_triagem <- function() {
  niveis <- c(Agregado = "Piauí e Teresina", Zona = "Zona", Situacao = "Situação",
              Estrato_Admin = "Estrato administrativo", Estrato_Agregado = "Estrato agregado")
  resumo <- triagem %>%
    filter(Recorte_Demografico == "Total", Indicador %in% CATALOGO$id) %>%
    group_by(Indicador, Nivel_Geografico) %>%
    summarise(aprov = mean(crit_c & !instavel, na.rm = TRUE), .groups = "drop")
  linhas <- map_chr(CATALOGO$id[CATALOGO$id %in% resumo$Indicador], function(id) {
    r <- resumo %>% filter(Indicador == id)
    cel <- map_chr(names(niveis), function(nv) {
      v <- r$aprov[r$Nivel_Geografico == nv]
      if (length(v) == 0) "—" else paste0(num(100 * v, 0), "%")
    })
    linha_md(info(id)$rotulo, cel)
  })
  c(linha_md("Indicador", niveis), paste0("|---|", strrep("---:|", length(niveis))), linhas)
}

resolver_tabelas <- function(linhas) {
  saida <- character(0)
  for (l in linhas) {
    d <- str_match(l, "^\\s*<!--\\s*@tabela\\s+(.*?)\\s*-->\\s*$")
    if (is.na(d[1])) { saida <- c(saida, l); next }
    pares <- str_match_all(d[2], "([a-z]+)=(\\S+)")[[1]]
    arg <- setNames(pares[, 3], pares[, 2])
    tabela <- switch(arg[["tipo"]],
      destaques            = tabela_destaques(),
      matriz               = tabela_matriz(arg[["dimensao"]]),
      categorias           = tabela_categorias(arg[["dimensao"]]),
      "pontos-territoriais" = pontos_territoriais(),
      "pontos-demograficos" = pontos_demograficos(),
      "anexo-indicadores"  = tabela_anexo_indicadores(),
      "anexo-testes"       = tabela_anexo_testes(),
      "anexo-triagem"      = tabela_anexo_triagem(),
      stop("Tipo de tabela desconhecido: ", arg[["tipo"]])
    )
    saida <- c(saida, tabela)
  }
  saida
}

# ---- 7. Interpretador ----------------------------------------------------------------

resolver_condicionais <- function(txt) {
  padrao <- regex("\\{\\{#(se-significativo|se-nao-significativo|se-existe)\\s+([^\\}]+?)\\}\\}(.*?)\\{\\{/se\\}\\}",
                  dotall = TRUE)
  while (str_detect(txt, padrao)) {
    m <- str_match(txt, padrao)
    tipo <- m[2]; args <- str_split(str_trim(m[3]), "\\s+")[[1]]; corpo <- m[4]
    manter <- switch(tipo,
      "se-significativo"     = { r <- teste_reg(args[1], args[2]); !is.null(r) && r$p_ajustado < 0.05 },
      "se-nao-significativo" = { r <- teste_reg(args[1], args[2]); !is.null(r) && r$p_ajustado >= 0.05 },
      "se-existe"            = !is.null(teste_reg(args[1], args[2])))
    txt <- str_replace(txt, padrao, if (manter) corpo else "")
  }
  txt
}

# \{\{ no modelo atravessa o interpretador como texto literal.
proteger_literais  <- function(txt) str_replace_all(txt, "\\\\\\{\\\\\\{", "LIT")
restaurar_literais <- function(txt) str_replace_all(txt, "LIT", "{{")

# vapply(): str_replace_all() com função chama uma vez por ocorrência em
# versões antigas do stringr e uma vez para todas nas novas; assim funciona nas duas.
resolver_expressoes <- function(txt) {
  resolver_uma <- function(inteiro) {
    m <- str_match(inteiro, "\\{\\{([a-z_]+)([^\\}]*)\\}\\}")
    args <- str_split(str_trim(m[1, 3]), "\\s+")[[1]]
    args <- args[nzchar(args)]
    fn <- VOCABULARIO[[m[1, 2]]]
    if (is.null(fn)) stop("Expressão desconhecida no modelo: {{", m[1, 2], " ...}}")
    do.call(fn, as.list(args))
  }
  str_replace_all(txt, "\\{\\{([a-z_]+)([^\\}]*)\\}\\}",
                  function(inteiros) vapply(inteiros, resolver_uma, character(1), USE.NAMES = FALSE))
}

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

remover_somente_modelo <- function(linhas) {
  ini <- which(str_detect(linhas, fixed("<!-- @somente-modelo -->")))
  fim <- which(str_detect(linhas, fixed("<!-- /@somente-modelo -->")))
  if (length(ini) == 0) return(linhas)
  if (length(ini) != 1 || length(fim) != 1 || fim < ini) stop("Marcadores @somente-modelo malformados no modelo.")
  linhas[-(ini:fim)]
}

# ---- 8. Execução ---------------------------------------------------------------------

if (!file.exists(MODELO)) stop("Não encontrei o modelo em ", MODELO)
message("Preenchendo ", MODELO, " para ", sufixo, "...")

linhas <- read_lines(MODELO)
linhas <- remover_somente_modelo(linhas)
linhas <- resolver_redigir(linhas)
linhas <- resolver_tabelas(linhas)
texto  <- paste(linhas, collapse = "\n")
texto  <- proteger_literais(texto)
texto  <- resolver_condicionais(texto)
texto  <- resolver_expressoes(texto)

# ---- 9. Verificação --------------------------------------------------------------------

sobraram <- str_extract_all(texto, "\\{\\{[^\\}]*\\}\\}|\\{[A-Z_]{2,}[^\\}]*\\}")[[1]]
if (length(sobraram) > 0) {
  message("\nMARCADORES NÃO RESOLVIDOS (", length(sobraram), "):")
  for (s in unique(sobraram)) message("  ", str_trunc(s, 100), "   (", sum(sobraram == s), "x)")
  stop("O relatório não foi gravado. Corrija o modelo ou o vocabulário e rode de novo.")
}

texto <- str_replace_all(texto, "—%", "—")
# O pandoc lê "$" como início de fórmula; "R$" sem escape engole tabelas inteiras.
texto <- str_replace_all(texto, "\\$", "\\\\$")
texto <- restaurar_literais(texto)
texto <- str_replace_all(texto, "\\\\\\}\\\\\\}", "}}")

cabecalho <- sprintf(
  "<!-- GERADO AUTOMATICAMENTE por R/09_preencher_relatorio.R a partir de %s. Trimestre: %s. Não editar à mão — a próxima rodada sobrescreve sem aviso. -->\n\n",
  MODELO, sufixo)
texto <- paste0(cabecalho, texto)
write_lines(texto, SAIDA)
message("  -> ", SAIDA, " (", formatC(nchar(texto), big.mark = ".", format = "d"), " caracteres)")

if (length(ausentes$itens) > 0) {
  message("\nValores ausentes, exibidos como travessão (", length(unique(ausentes$itens)), "):")
  for (a in unique(ausentes$itens)) message("  ", a)
}
if (length(redacoes$itens) > 0) {
  message("\nTRECHOS A REDIGIR (", length(redacoes$itens), ") — procure por \"A REDIGIR\" no arquivo gerado:")
  for (i in seq_along(redacoes$itens)) message("  ", i, ". ", str_trunc(redacoes$itens[i], 90))
}

if (CONVERTER_DOCX) {
  message("Convertendo para .docx")
  arquivo_entrada <- normalizePath(SAIDA, mustWork = TRUE)
  arquivo_saida   <- str_replace(arquivo_entrada, "\\.md$", ".docx")
  result <- try(pandoc_run(args = c(
    arquivo_entrada, "-o", arquivo_saida,
    paste0("--reference-doc=", normalizePath("custom-reference.docx", mustWork = TRUE)),
    paste0("--lua-filter=", normalizePath("remover-figuras.lua", mustWork = TRUE)),
    "--toc", "--toc-depth=2")))
  if (inherits(result, "try-error")) {
    message("Erro ao rodar o pandoc: confira o pacote, se o .docx de destino está aberto e o custom-reference.docx.")
  } else {
    message("  -> ", arquivo_saida)
  }
}

message("\nConcluído: ", sufixo)
