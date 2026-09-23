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
# Formatação e interpretador do modelo no módulo R/relatorio_modelo.R; aqui a
# consulta aos dados, o vocabulário e os geradores de tabela.
#
# USO:   Rscript R/09_preencher_relatorio.R   (trimestre de R/00_config.R)
# ENTRADA: output/relatorio_trimestral.md (modelo), output/base_<sufixo>.csv,
#          output/testes_regionais_<sufixo>.csv,
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
source("R/precisao.R", encoding = "UTF-8")   # CV, IC 95%, classes de precisão
source("R/relatorio_modelo.R", encoding = "UTF-8")  # formatação + interpretador do modelo

MODELO <- "./output/relatorio_trimestral.md"
SAIDA  <- sprintf("./output/relatorio_trimestral_%s.md", sufixo)
CONVERTER_DOCX <- TRUE
# Recorte Situação (Urbano tradicional / Rural / FCU + "Teste situação"). Com
# FALSE some do relatório inteiro: colunas das matrizes, pontos de atenção,
# anexos e os trechos do modelo entre {{#se-situacao}} ... {{/se}} (o
# alternativo fica em {{#se-nao-situacao}} ... {{/se}}). Desligado
# em 21/09/2026: por ora não acrescenta informação em relação à Zona.
INCLUIR_SITUACAO <- FALSE

# ---- 1. Leitura ----------------------------------------------------------------

ler <- function(caminho, obrigatorio = TRUE) {
  if (!file.exists(caminho)) {
    if (obrigatorio) stop("Não encontrei ", caminho, ".\nRode o 01 (e o R/11 para a triagem) antes deste script.")
    return(NULL)
  }
  read_csv(caminho, show_col_types = FALSE)
}

base        <- ler(sprintf("output/base_%s.csv", sufixo)) %>% mutate(cv = calcular_cv(Estimativa, SE))
testes_reg  <- ler(sprintf("output/testes_regionais_%s.csv", sufixo))
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
  "Taxa_Informalidade",                  "Taxa de informalidade",                                  "pct",    "insercao",      TRUE,      FALSE,
  "Taxa_Subocupacao",                    "Subocupação por insuficiência de horas",                 "pct",    "insercao",      FALSE,     FALSE,
  "Percentual_Subremuneracao",           "Sub-remuneração (rendimento-hora abaixo do mínimo)",     "pct",    "insercao",      FALSE,     FALSE,
  "Proporcao_Ocupados_Escolarizados",    "Ocupados com ensino médio completo ou mais",             "pct",    "insercao",      FALSE,     FALSE,
  "Empregados_Setor_Privado",            "Empregados no setor privado",                            "mil",    "insercao",      FALSE,     FALSE,
  "Empregados_Setor_Publico",            "Empregados no setor público",                            "mil",    "insercao",      FALSE,     FALSE,
  "Ocupados_Agropecuaria",               "Ocupados na agropecuária",                               "mil",    "insercao",      FALSE,     FALSE,
  "Rendimento_Medio_Habitual",           "Rendimento médio real habitual",                         "reais",  "rendimento",    TRUE,      FALSE,
  "Rendimento_Formal",                   "Rendimento médio dos formais",                           "reais",  "rendimento",    FALSE,     FALSE,
  "Rendimento_Informal",                 "Rendimento médio dos informais",                         "reais",  "rendimento",    FALSE,     FALSE,
  "Desigualdade_Formal_Informal",        "Razão entre rendimento formal e informal",               "razao",  "rendimento",    FALSE,     FALSE,
  "Gini_Rendimento_Habitual_Trabalho",   "Índice de Gini do rendimento do trabalho",               "gini",   "rendimento",    TRUE,      FALSE,
  "Desalentados_Forca_Ampliada",         "Desalentados na força de trabalho ampliada",             "pct",    "vulnerabilidade", FALSE,   FALSE,
  "Desalentados_Fora_Forca",             "Desalentados na força de trabalho potencial",            "pct",    "vulnerabilidade", FALSE,   FALSE,
  "Taxa_Nem_Nem",                        "Jovens de 14 a 29 anos que não estudam nem trabalham",   "pct",    "vulnerabilidade", TRUE,    FALSE,
  "Proporcao_Populacao_14_59",           "Pessoas de 14 a 59 anos na população total",             "pct",    "populacao",     FALSE,     FALSE,
  "Distribuicao_PIT_por_Sexo",           "Sexo",                                                  "pct",    "populacao",     FALSE,     TRUE,
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
# Referências externas nas matrizes, antes da coluna do Piauí.
GEO_REFERENCIA <- c("Brasil" = "Brasil", "Nordeste" = "Nordeste")

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

if (!INCLUIR_SITUACAO) {
  GEO_SITUACAO   <- character(0)
  GEO_ANEXO      <- filter(GEO_ANEXO, recorte != "Situação")
  RECORTES_TESTE <- filter(RECORTES_TESTE, recorte != "Situacao")
}

# Recortes demográficos (Sexo, Raca, Faixa_Etaria_trabalho, Instrucao*) estão
# FORA do relatório desde 23/09/2026 (decisão do usuário): as réplicas bootstrap
# descartadas em célula pequena podem subestimar o erro padrão, e a publicação
# não podia esperar a correção. Ficam no anexo metodológico (§6.9, apêndices A e
# C). O 01 continua estimando e testando esses recortes; o que saiu daqui foi a
# tabela "pontos-demograficos" e a leitura de testes_significancia_<sufixo>.csv.

# ---- 3. Formatação ------------------------------------------------------------------
# num(), formatar(), com_unidade(), marca_pelo_cv(), estrelas(), linha_md(),
# rotulo_categoria()... vêm do R/relatorio_modelo.R.

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
      return(marca_pelo_cv(cv_atual))
    }
    return("traco")
  }
  if (nrow(t) > 1) stop("Triagem ambígua para ", ind, " / ", geo)
  if (isTRUE(t$instavel) || is.na(t$cv_p80)) "traco" else marca_pelo_cv(t$cv_p80)
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
  sprintf("(%s, %s)", formatar(ic_inferior(r$Estimativa, r$SE, piso = 0), u), formatar(ic_superior(r$Estimativa, r$SE), u))
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
    situacao  <- if (INCLUIR_SITUACAO)
      c(map_chr(GEO_SITUACAO, ~ celula(id, .x, sub)), exp_estrelas(id, "Situacao"))
    # Brasil e Nordeste como referência (marca pelo CV do trimestre, ver topo).
    ref       <- map_chr(GEO_REFERENCIA, ~ celula(id, .x, sub))
    linha_md(rotulo, ref, paste0("**", pi, "**"), agreg, exp_estrelas(id, "Estrato_Agregado"),
             zona, exp_estrelas(id, "Zona"), situacao)
  })
  linhas <- linhas[!is.na(linhas)]
  if (length(linhas) == 0) return("*(nenhum indicador desta dimensão passou na triagem no nível do Piauí)*")
  c(linha_md("Indicador", names(GEO_REFERENCIA), "Piauí", names(GEO_AGREG), "Teste estratos",
             names(GEO_ZONA), "Teste zona",
             if (INCLUIR_SITUACAO) c(names(GEO_SITUACAO), "Teste situação")),
    paste0("|---|", strrep("---:|", length(GEO_REFERENCIA) + 1 + length(GEO_AGREG)), ":---:|",
           strrep("---:|", length(GEO_ZONA)), ":---:|",
           if (INCLUIR_SITUACAO) paste0(strrep("---:|", length(GEO_SITUACAO)), ":---:|")),
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
  L <- map_dfr(c("ocupacao", "insercao", "rendimento", "vulnerabilidade"), linhas_da_dimensao) %>%
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
    t_s <- if (INCLUIR_SITUACAO) teste_reg(id, "Situacao")
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
                   sprintf("(%s, %s)", formatar(ic_inferior(r$Estimativa, r$SE, piso = 0), i$unidade),
                           formatar(ic_superior(r$Estimativa, r$SE), i$unidade)),
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
  if (!INCLUIR_SITUACAO) niveis <- niveis[names(niveis) != "Situacao"]
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

# Gerador de cada diretiva <!-- @tabela tipo=... -->; o módulo acha as
# diretivas e chama esta função com os argumentos.
gerar_tabela <- function(arg) {
  switch(arg[["tipo"]],
    destaques            = tabela_destaques(),
    matriz               = tabela_matriz(arg[["dimensao"]]),
    categorias           = tabela_categorias(arg[["dimensao"]]),
    "pontos-territoriais" = pontos_territoriais(),
    "anexo-indicadores"  = tabela_anexo_indicadores(),
    "anexo-testes"       = tabela_anexo_testes(),
    "anexo-triagem"      = tabela_anexo_triagem(),
    stop("Tipo de tabela desconhecido: ", arg[["tipo"]])
  )
}

# ---- 7. Execução ---------------------------------------------------------------------

if (!file.exists(MODELO)) stop("Não encontrei o modelo em ", MODELO)
message("Preenchendo ", MODELO, " para ", sufixo, "...")

# Interpretador (condicionais, expressões, @redigir, @tabela) no
# R/relatorio_modelo.R; para com erro se sobrar marcador não resolvido.
texto <- preencher_modelo(read_lines(MODELO), gerar_tabela, teste_reg, VOCABULARIO,
                          incluir_situacao = INCLUIR_SITUACAO)
redacoes <- attr(texto, "redacoes")

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
if (length(redacoes) > 0) {
  message("\nTRECHOS A REDIGIR (", length(redacoes), ") — procure por \"A REDIGIR\" no arquivo gerado:")
  for (i in seq_along(redacoes)) message("  ", i, ". ", str_trunc(redacoes[i], 90))
}

if (CONVERTER_DOCX) {
  message("Convertendo para .docx")
  arquivo_entrada <- normalizePath(SAIDA, mustWork = TRUE)
  arquivo_saida   <- str_replace(arquivo_entrada, "\\.md$", "_rascunho.docx")
  # As imagens do relatório (R/12_graficos_panorama.R) são referenciadas no
  # .md como "figuras/..." — caminho relativo a output/, de onde o .md é lido
  # normalmente. O pandoc resolve caminho relativo à sua própria pasta de
  # trabalho (a raiz do projeto), não à pasta do arquivo de entrada, então
  # sem --resource-path ele não acha o arquivo e troca a imagem pela
  # descrição (warning "Could not fetch resource", sem falhar a conversão).
  # --columns=10000: sem isso, as tabelas pipe com linha longa ganham largura
  # de coluna fixa (proporcional aos hifens do separador) e saem apertadas;
  # assim o Word ajusta cada coluna ao conteúdo. estilo-tabelas.lua aplica o
  # estilo "Tabela Texto" do reference às células (fonte 9 pt).
  result <- try(pandoc_run(args = c(
    arquivo_entrada, "-o", arquivo_saida,
    paste0("--reference-doc=", normalizePath("custom-reference-notatecnica.docx", mustWork = TRUE)),
    paste0("--resource-path=", dirname(arquivo_entrada)),
    paste0("--lua-filter=", normalizePath("estilo-tabelas.lua", mustWork = TRUE)),
    "--columns=10000",
    "--toc", "--toc-depth=2")))
  if (inherits(result, "try-error")) {
    message("Erro ao rodar o pandoc: confira o pacote, se o .docx de destino está aberto e o custom-reference.docx.")
  } else {
    message("  -> ", arquivo_saida)
  }
}

message("\nConcluído: ", sufixo)
