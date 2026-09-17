# ==============================================================================
# indicadores.R — catálogo de indicadores e motor de estimação.
#
# Tirado do 01_pipeline_trimestral.R (antigas §3 e §5) para que o pipeline e a
# validação contra o SIDRA (scripts_teste/validacao_sidra.R) usem exatamente as
# mesmas fórmulas. Depende das colunas criadas por R/derivar_variaveis.R.
#
# estimar_trimestre() (fim do arquivo) é o laço geografias x recortes x
# catálogo, compartilhado pelo 01 e pela série de confiabilidade.
#
# Campos de cada spec:
#   id               nome do indicador
#   formula          variável (ou expressão) estimada
#   denominador      só para svyratio
#   fun              svymean | svyratio | svytotal | convey::svygini
#   subset           universo, aplicado antes de estimar (NULL = todos)
#   so_recorte_total TRUE = não cruza com recortes demográficos
#   testar           FALSE = fica fora das baterias de teste de significância
#   geografias       nomes das geografias em que o indicador é estimado
#                    (NULL = todas)
#
# Totais saem em PESSOAS (o SIDRA publica em mil pessoas; a conversão fica
# para a exibição). Todos passam pelo desenho replicado — SE e CV incluídos.
# ==============================================================================

library(survey)
library(dplyr)
library(purrr)
library(tibble)

# ---- Catálogo -----------------------------------------------------------------

catalogo_original <- list(
  # Reescrita sobre as variáveis 0/1 (antes: ~VD4002 == ... / ~VD4001 == ...).
  # Mesmo número — conferido na validação —, mas sem depender de NA + na.rm.
  list(id = "Taxa_Desocupacao",
       formula = ~desocup, denominador = ~ft,
       fun = svyratio, subset = NULL),

  list(id = "Chefes_Familia_Desocupados",
       formula = ~VD2002 == "Pessoa responsável",
       denominador = ~VD4002 == "Pessoas desocupadas",
       fun = svyratio, subset = ~VD4002 == "Pessoas desocupadas"),

  list(id = "Conribuintes_Desocupados",
       formula = ~contribuinte_renda_domicilio,
       denominador = ~VD4002 == "Pessoas desocupadas",
       fun = svyratio, subset = ~VD4002 == "Pessoas desocupadas"),

  list(id = "Rendimento_Medio_Habitual",
       formula = ~VD4019_real, denominador = NULL, fun = svymean, subset = NULL),

  list(id = "Percentual_Subremuneracao",
       formula = ~subremuneracao, denominador = NULL, fun = svymean, subset = NULL),

  list(id = "Rendimento_Formal",
       formula = ~VD4019_real, denominador = NULL, fun = svymean,
       subset = ~!is.na(informal) & informal == 0,
       so_recorte_total = TRUE),

  list(id = "Rendimento_Informal",
       formula = ~VD4019_real, denominador = NULL, fun = svymean,
       subset = ~!is.na(informal) & informal == 1,
       so_recorte_total = TRUE),

  list(id = "Taxa_Informalidade",
       formula = ~informal, denominador = ~VD4002 == "Pessoas ocupadas",
       fun = svyratio, subset = NULL),

  list(id = "Taxa_Subocupacao",
       formula = ~(!is.na(VD4004A) & VD4004A == "Pessoas subocupadas"),
       denominador = ~VD4002 == "Pessoas ocupadas", fun = svyratio, subset = NULL),

  list(id = "Proporcao_Ocupados_Escolarizados",
       formula = ~(!is.na(medio_completo_ou_mais) & medio_completo_ou_mais == 1),
       denominador = ~VD4002 == "Pessoas ocupadas", fun = svyratio, subset = NULL),

  list(id = "Desalentados_Forca_Ampliada",
       formula = ~(!is.na(VD4005) & VD4005 == "Pessoas desalentadas"),
       denominador = ~ft_ou_desalentada, fun = svyratio, subset = NULL),

  list(id = "Desalentados_Fora_Forca",
       formula = ~(!is.na(VD4005) & VD4005 == "Pessoas desalentadas"),
       denominador = ~VD4003, fun = svyratio, subset = NULL),

  # Motivos: categorias agrupadas e só nos níveis agregados (decisão de
  # 17/09/2026, CONTEXTO_PROJETO.md §8.7) — nos recortes finos não passam na
  # triagem. O antigo Motivo_Nao_Inicio_NemNem (V4078A) saiu: repetia o
  # VD4030, que é a derivada oficial do IBGE.
  list(id = "Motivo_Desistencia_Desalentado",
       formula = ~motivo_desistencia_grupo, denominador = NULL, fun = svymean,
       subset = ~VD4005 == "Pessoas desalentadas",
       so_recorte_total = TRUE, testar = FALSE,
       geografias = c("Brasil", "Nordeste", "Piauí")),

  list(id = "Taxa_Nem_Nem",
       formula = ~nem_nem, denominador = ~(V2009 >= 14 & V2009 <= 29),
       fun = svyratio, subset = NULL),

  list(id = "Motivo_Nao_Procura_NemNem",
       formula = ~motivo_nao_procura_grupo, denominador = NULL, fun = svymean,
       subset = ~nem_nem == 1,
       so_recorte_total = TRUE, testar = FALSE,
       geografias = c("Brasil", "Nordeste", "Piauí"))
)

# Mercado de trabalho (set/2026). Definições e fontes em R/derivar_variaveis.R
# e no anexo metodológico.
catalogo_mercado_trabalho <- list(
  # Contagens (SIDRA 4093/4097/5434/4100)
  list(id = "Pessoas_Idade_Trabalhar",   formula = ~pit,         fun = svytotal, testar = FALSE),
  list(id = "Pessoas_Forca_Trabalho",    formula = ~ft,          fun = svytotal, testar = FALSE),
  list(id = "Pessoas_Fora_Forca",        formula = ~fora_ft,     fun = svytotal, testar = FALSE),
  list(id = "Pessoas_Ocupadas",          formula = ~ocup,        fun = svytotal, testar = FALSE),
  list(id = "Empregados_Setor_Privado",  formula = ~emp_privado, fun = svytotal, testar = FALSE),
  list(id = "Empregados_Setor_Publico",  formula = ~emp_publico, fun = svytotal, testar = FALSE),
  list(id = "Ocupados_Agropecuaria",     formula = ~ocup_agro,   fun = svytotal, testar = FALSE),
  list(id = "Pessoas_Desocupadas",       formula = ~desocup,     fun = svytotal, testar = FALSE),
  list(id = "Pessoas_Subutilizadas",     formula = ~subutil,     fun = svytotal, testar = FALSE),

  # Taxas (SIDRA 4093/4099)
  list(id = "Nivel_Ocupacao",              formula = ~ocup,    denominador = ~pit,         fun = svyratio),
  list(id = "Taxa_Participacao",           formula = ~ft,      denominador = ~pit,         fun = svyratio),
  list(id = "Taxa_Composta_Subutilizacao", formula = ~subutil, denominador = ~ft_ampliada, fun = svyratio),

  # Desigualdade: ocupados com rendimento habitual positivo. Nominal de
  # propósito — o Gini é invariante à escala, e o deflator é uma constante
  # por trimestre.
  # convey::svygini — Gini ponderado com variância pelas réplicas do desenho
  # (OSIER, 2009; PESSOA et al., pacote convey).
  list(id = "Gini_Rendimento_Habitual_Trabalho", formula = ~VD4019, fun = convey::svygini,
       subset = ~ocup == 1 & !is.na(VD4019) & VD4019 > 0, testar = FALSE)
)

# Composição da PIT: um total (mil pessoas) e uma distribuição (%) por
# dimensão. Só no recorte Total — cruzar sexo por sexo é degenerado.
dimensoes_pit <- c(Sexo = "Sexo_pit", Raca = "Raca_pit",
                   Faixa_Etaria_SIDRA = "Faixa_Etaria_sidra",
                   Faixa_Etaria_Projeto = "Faixa_Etaria_projeto",
                   Instrucao_SIDRA = "Instrucao_sidra",
                   Instrucao_Projeto = "Instrucao_projeto")

catalogo_composicao_pit <- unlist(lapply(names(dimensoes_pit), function(nm) {
  f <- as.formula(paste0("~", dimensoes_pit[[nm]]))
  list(
    list(id = paste0("PIT_por_", nm), formula = f, fun = svytotal,
         subset = ~pit == 1, so_recorte_total = TRUE, testar = FALSE),
    list(id = paste0("Distribuicao_PIT_por_", nm), formula = f, fun = svymean,
         subset = ~pit == 1, so_recorte_total = TRUE, testar = FALSE)
  )
}), recursive = FALSE)

catalogo_indicadores <- c(catalogo_original, catalogo_mercado_trabalho,
                          catalogo_composicao_pit)

recortes_demograficos <- list(
  Total                  = NULL,
  Sexo                   = ~Sexo,
  Raca                   = ~Raca,
  Faixa_Etaria_trabalho  = ~Faixa_Etaria_trabalho,
  Instrucao_agregado     = ~Instrucao,
  Instrucao              = ~VD3004
)

# ---- Motor ---------------------------------------------------------------------

aplicar_subset <- function(design, condicao) {
  if (is.null(condicao)) return(design)
  idx <- as.logical(eval(condicao[[2]], envir = design$variables))
  idx[is.na(idx)] <- FALSE
  design[idx, ]
}

# Universo do denominador de uma razão (usado nos testes de significância).
# Numérico conta como indicador 0/1: entra quem tem valor diferente de zero.
# Antes todo numérico não-NA entrava, o que fazia ~ft_ou_desalentada (0/1)
# selecionar a amostra inteira.
aplicar_subset_denominador <- function(design, condicao) {
  if (is.null(condicao)) return(design)
  valor <- eval(condicao[[2]], envir = design$variables)
  idx <- if (is.logical(valor)) {
    valor
  } else if (is.numeric(valor)) {
    !is.na(valor) & valor != 0
  } else {
    !is.na(valor)
  }
  idx[is.na(idx)] <- FALSE
  design[idx, ]
}

computar_estimativa <- function(design, spec, by_formula) {
  design_usar <- aplicar_subset(design, spec$subset)
  if (nrow(design_usar) == 0) return(NULL)

  argumentos <- list(spec$formula, design = design_usar, na.rm = TRUE)
  if (identical(spec$fun, svyratio)) argumentos$denominator <- spec$denominador

  if (is.null(by_formula)) {
    do.call(spec$fun, argumentos)
  } else {
    argumentos <- c(list(formula = spec$formula), argumentos[-1], list(by = by_formula, FUN = spec$fun))
    do.call(svyby, argumentos)
  }
}

extrair_resultados <- function(resultado, ind_nome, tem_by) {

  if (!tem_by) {
    est <- coef(resultado)
    se  <- SE(resultado)
    nomes <- names(est)
    if (is.null(nomes) || all(nomes == "")) nomes <- ind_nome
    return(tibble(
      Indicador = ind_nome, Subcategoria_Indicador = nomes,
      Estimativa = as.numeric(est), SE = as.numeric(se),
      Categoria_Demografica = "Total"
    ))
  }

  df <- as.data.frame(resultado)
  rownames(df) <- NULL
  df <- df %>% rename(Categoria_Demografica = 1)
  df$Categoria_Demografica <- as.character(df$Categoria_Demografica)

  resto <- df %>% select(-Categoria_Demografica)
  k <- ncol(resto) / 2
  stopifnot(k == floor(k))
  est_cols <- names(resto)[seq_len(k)]
  se_cols  <- names(resto)[(k + 1):(2 * k)]

  map_dfr(seq_len(k), function(j) {
    df %>%
      transmute(
        Indicador = ind_nome, Subcategoria_Indicador = est_cols[j],
        Estimativa = .data[[est_cols[j]]], SE = .data[[se_cols[j]]],
        Categoria_Demografica
      )
  })
}

# ---- Desigualdade formal/informal ----------------------------------------------
# A razão entre o rendimento médio dos ocupados formais e o dos informais.
#
# POR QUE NÃO ESTÁ NO catalogo_indicadores: aquele framework calcula UM
# estimador por vez (svymean ou svyratio). Esta métrica é a razão entre DOIS
# estimadores, e o problema não é obter o ponto — é obter o erro padrão.
#
# Rendimento_Formal e Rendimento_Informal são estimados sobre a MESMA amostra:
# compartilham UPAs e estratos, logo são correlacionados. Combinar os dois
# erros padrão como se fossem independentes ignora a covariância e produz um
# intervalo errado — em desenho sintético com a estrutura da PNADC, o erro
# padrão ingênuo saiu 34% maior que o correto (a covariância é positiva, então
# o ingênuo é largo demais; com covariância negativa seria estreito demais, o
# que é pior).
#
# O tratamento correto: estimar as duas médias em UM objeto (svyby com
# covmat = TRUE, que guarda a matriz de covariância) e aplicar svycontrast()
# sobre a diferença de logaritmos. O svycontrast lineariza pelo método delta
# usando a covariância de verdade. Exponenciando, volta-se à razão.
#
# Trabalhar em log tem duas vantagens: o intervalo resultante é assimétrico na
# escala da razão (como deve ser, já que razão é positiva e não pode ter limite
# inferior negativo), e o erro padrão do log é, ele próprio, o CV da razão.
#
# Os indicadores Rendimento_Formal e Rendimento_Informal continuam sendo
# calculados separadamente pelo catálogo — esta seção acrescenta, não substitui.

calcular_desigualdade <- function(design_geo) {

  d <- aplicar_subset(
    design_geo,
    ~ VD4002 == "Pessoas ocupadas" & !is.na(informal) & !is.na(VD4019_real)
  )
  if (nrow(d) < 2) return(NULL)

  d$variables$.formalidade <- factor(
    ifelse(d$variables$informal == 1, "informal", "formal"),
    levels = c("formal", "informal")
  )
  # Estrato com só um dos dois grupos não tem razão a estimar.
  if (nlevels(droplevels(d$variables$.formalidade)) < 2) return(NULL)

  medias <- svyby(~VD4019_real, ~.formalidade, d, svymean,
                  na.rm = TRUE, covmat = TRUE)

  m <- coef(medias)
  if (length(m) < 2 || any(!is.finite(m)) || any(m <= 0)) return(NULL)

  contraste <- svycontrast(medias, quote(log(formal) - log(informal)))
  log_razao <- as.numeric(coef(contraste))
  ep_log    <- as.numeric(SE(contraste))
  if (!is.finite(log_razao) || !is.finite(ep_log)) return(NULL)

  razao <- exp(log_razao)

  tibble(
    rendimento_formal   = unname(m[["formal"]]),
    rendimento_informal = unname(m[["informal"]]),
    razao               = razao,
    ep_log              = ep_log,
    # método delta na escala natural, para a base_ manter o mesmo esquema
    ep_razao            = razao * ep_log,
    # intervalo construído no log e exponenciado: assimétrico e sempre positivo
    ic_inf              = exp(log_razao - 1.96 * ep_log),
    ic_sup              = exp(log_razao + 1.96 * ep_log),
    # CV de uma razão é, por construção, o erro padrão do seu log
    cv                  = 100 * ep_log
  )
}

# ---- Geografias ------------------------------------------------------------------
# Lista nomeada de desenhos, na ordem de saída da base_. `design` é o desenho
# derivado (derivar_variaveis()); `design_pi`, o recorte do Piauí.
#   incluir_brasil_nordeste = FALSE quando `design` já veio recortado no Piauí
#     (série de confiabilidade: recortar antes de derivar poupa ~6 GB de RAM).
#   incluir_micro = FALSE tira os estratos de 7 dígitos (fora do escopo da
#     triagem, CONTEXTO_PROJETO.md §1).
montar_geografias <- function(design,
                              design_pi = design[design$variables$UF == "Piauí", ],
                              incluir_brasil_nordeste = TRUE,
                              incluir_micro = TRUE) {
  lista <- list()
  if (incluir_brasil_nordeste) {
    lista[["Brasil"]]   <- design
    lista[["Nordeste"]] <- subset(design, Regiao == "Nordeste")
  }
  lista[["Piauí"]]       <- design_pi
  lista[["Teresina"]]    <- subset(design_pi, Estrato_agregado == "Teresina")
  lista[["Zona_Urbana"]] <- subset(design_pi, Zona == "Urbana")
  lista[["Zona_Rural"]]  <- subset(design_pi, Zona == "Rural")

  niveis <- function(v) { u <- unique(design_pi$variables[[v]]); u[!is.na(u)] }
  for (e in niveis("Estrato_Admin")) {
    lista[[paste0("Admin_", e)]] <- subset(design_pi, Estrato_Admin == e)
  }
  for (ea in niveis("Estrato_agregado")) {
    lista[[paste0("Agreg_", ea)]] <- subset(design_pi, Estrato_agregado == ea)
  }
  if (incluir_micro) {
    for (em in niveis("Estrato")) {
      lista[[paste0("Micro_", em)]] <- subset(design_pi, Estrato == em)
    }
  }
  lista
}

# ---- Estimação de um trimestre -----------------------------------------------------
# Catálogo x geografias x recortes demográficos (as geografias agregadas só no
# recorte Total), mais a razão formal/informal. Sem testes de significância —
# esses ficam no 01. Devolve list(base, desigualdade, falhas); `falhas` é uma
# lista de tibbles (Regiao_Geografica, Recorte_Demografico, Indicador, Erro).
estimar_trimestre <- function(lista_geografias, geografias_agregadas, ano, tri,
                              catalogo = catalogo_indicadores,
                              recortes = recortes_demograficos,
                              incluir_desigualdade = TRUE) {
  linhas <- list()
  falhas <- list()
  registrar_falha <- function(geo, recorte, ind, erro) {
    falhas[[length(falhas) + 1]] <<- tibble(
      Regiao_Geografica = geo, Recorte_Demografico = recorte,
      Indicador = ind, Erro = erro
    )
  }

  for (geo_nome in names(lista_geografias)) {
    design_geo <- lista_geografias[[geo_nome]]
    if (nrow(design_geo) == 0) next

    recortes_desta_geo <- if (geo_nome %in% geografias_agregadas) "Total" else names(recortes)

    for (recorte_nome in recortes_desta_geo) {
      by_formula <- recortes[[recorte_nome]]

      for (spec in catalogo) {
        if (isTRUE(spec$so_recorte_total) && recorte_nome != "Total") next
        if (!is.null(spec$geografias) && !geo_nome %in% spec$geografias) next

        by_usar       <- if (!is.null(spec$by_override)) spec$by_override else by_formula
        recorte_saida <- if (!is.null(spec$by_override)) "Formalidade" else recorte_nome

        resultado <- tryCatch(
          computar_estimativa(design_geo, spec, by_usar),
          error = function(e) {
            registrar_falha(geo_nome, recorte_saida, spec$id, conditionMessage(e))
            NULL
          }
        )
        if (is.null(resultado)) next

        linha <- tryCatch(
          extrair_resultados(resultado, spec$id, tem_by = !is.null(by_usar)) %>%
            mutate(Regiao_Geografica = geo_nome, Recorte_Demografico = recorte_saida),
          error = function(e) {
            registrar_falha(geo_nome, recorte_saida, spec$id,
                            paste("Falha ao extrair:", conditionMessage(e)))
            NULL
          }
        )
        if (!is.null(linha)) linhas[[length(linhas) + 1]] <- linha
      }
    }
  }

  base <- bind_rows(linhas) %>%
    mutate(Ano = ano, Trimestre = tri) %>%
    select(Indicador, Subcategoria_Indicador, Estimativa, SE, Ano, Trimestre,
           Regiao_Geografica, Recorte_Demografico, Categoria_Demografica)

  desigualdade <- tibble()
  if (incluir_desigualdade) {
    linhas_desig <- list()
    for (geo_nome in names(lista_geografias)) {
      design_geo <- lista_geografias[[geo_nome]]
      if (nrow(design_geo) == 0) next

      res <- tryCatch(
        calcular_desigualdade(design_geo),
        error = function(e) {
          registrar_falha(geo_nome, "Total", "Desigualdade_Formal_Informal", conditionMessage(e))
          NULL
        }
      )
      if (!is.null(res)) {
        linhas_desig[[length(linhas_desig) + 1]] <- res %>%
          mutate(Regiao_Geografica = geo_nome, .before = 1)
      }
    }
    desigualdade <- bind_rows(linhas_desig)

    # Entra também na base_ para herdar a maquinaria de CV e confiabilidade do 03.
    if (nrow(desigualdade) > 0) {
      base <- bind_rows(
        base,
        desigualdade %>%
          transmute(
            Indicador = "Desigualdade_Formal_Informal",
            Subcategoria_Indicador = "Desigualdade_Formal_Informal",
            Estimativa = razao, SE = ep_razao,
            Ano = ano, Trimestre = tri,
            Regiao_Geografica, Recorte_Demografico = "Total",
            Categoria_Demografica = "Total"
          )
      )
    }
  }

  list(base = base, desigualdade = desigualdade, falhas = falhas)
}
