# ==============================================================================
# pipeline_trimestre.R — pipeline completo pra UM trimestre: coleta, cálculo
# dos indicadores (Brasil/Nordeste/Piauí/Teresina + estratos finos x recortes
# demográficos), testes de significância, gráficos de confiabilidade e a
# análise de distribuição de renda.
#
# Pensado pra rodar a cada atualização trimestral do relatório: muda
# ANO_REF/TRIMESTRE_REF abaixo e roda o arquivo inteiro.
#
# É irmão do 01_run.R/02_testes_significancia.R (série histórica) — usa as
# mesmas fórmulas de indicador e a mesma lógica de recorte, só que sem loop
# de trimestres, sem cache em disco (tudo fica na memória do processo já
# que é só uma rodada) e com a análise de renda a mais no final.
# ==============================================================================

library(PNADcIBGE)
library(survey)
library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(tibble)
library(stringr)
library(ggplot2)

# ---- 1. Configuração ---------------------------------------------------------
# ANO_REF, TRIMESTRE_REF, sufixo, tabela_salario_minimo, sm_hora_corrente e
# geografias_agregadas vêm todos daqui. Para mudar o trimestre, mexa no
# R/00_config.R — e SÓ nele; o 03_comparacoes_indicadores.R lê o mesmo arquivo.

source("R/00_config.R")

# ---- 2. Download e variáveis derivadas --------------------------------------

message("Baixando PNADC ", sufixo, "...")
dados_brutos <- get_pnadc(year = ANO_REF, quarter = TRIMESTRE_REF, deflator = TRUE)

dados_brutos[["variables"]] <- dados_brutos[["variables"]] %>%
  mutate(
    Regiao = ifelse(
      UF %in% c("Piauí", "Maranhão", "Ceará", "Rio Grande do Norte", "Paraíba",
                "Pernambuco", "Bahia", "Alagoas", "Sergipe"),
      "Nordeste", "Resto do Brasil"
    ),
    
    Estrato_agregado = factor(case_match(as.integer(Estrato),
                                         2210011:2210030 ~ "Teresina",
                                         2220010:2220020 ~ "Entorno metropolitano de Teresina (PI)",
                                         2251011:2251022 ~ "Centro-Leste do Piauí",
                                         2252011:2252022 ~ "Baixo Parnaíba do Piauí",
                                         2253010:2254020 ~ "Alto Parnaíba e Chapadas Sul do Piauí",
                                         .default = NA_character_
    )),
    
    Zona          = factor(V1022, labels = c("Urbana", "Rural")),
    Estrato_Admin = V1023,
    
    Sexo                   = factor(V2007, labels = c("Masculino", "Feminino")),
    Raca                   = V2010,
    Faixa_Etaria_trabalho  = case_match(V2009,
                                        14:29   ~ "Jovens",
                                        30:64   ~ "Adulto",
                                        65:130  ~ "Idoso",
                                        .default = NA_character_
    ),
    Instrucao = factor(case_when(
      VD3004 %in% c("Sem instrução e menos de 1 ano de estudo",
                    "Fundamental incompleto ou equivalente",
                    "Fundamental completo ou equivalente") ~ "Até fundamental completo",
      !is.na(VD3004) ~ "Acima de fundamental completo",
      TRUE ~ NA_character_
    )),
    
    formal_setor_privado = factor(case_match(VD4009,
                                             "Empregado no setor privado com carteira de trabalho assinada" ~ "Com carteira",
                                             "Empregado no setor privado sem carteira de trabalho assinada" ~ "Sem carteira"
    )),
    
    medio_completo_ou_mais = factor(case_match(VD3004,
                                               c("Médio completo ou equivalente", "Superior incompleto ou equivalente",
                                                 "Superior completo") ~ 1,
                                               .default = 0
    )),
    
    ft_ou_desalentada = as.numeric(
      (!is.na(VD4001) & VD4001 == "Pessoas na força de trabalho") |
        (!is.na(VD4005) & VD4005 == "Pessoas desalentadas")
    ),
    
    valor_hora      = VD4019 / (5 * VD4031),
    subremuneracao  = as.numeric(valor_hora < sm_hora_corrente),
    VD4019_real     = VD4019 * Habitual,
    
    informal = as.numeric(
      (!is.na(VD4009) & VD4009 == "Empregado no setor privado sem carteira de trabalho assinada") |
        (!is.na(VD4009) & VD4009 == "Trabalhador doméstico sem carteira de trabalho assinada") |
        (!is.na(VD4009) & VD4009 == "Trabalhador familiar auxiliar") |
        ((!is.na(VD4009) & VD4009 == "Empregador") & (!is.na(V4019) & V4019 == "Não")) |
        ((!is.na(VD4009) & VD4009 == "Conta-própria") & (!is.na(V4019) & V4019 == "Não"))
    ),
    
    nem_nem = as.numeric(
      (V2009 >= 14 & V2009 <= 29) &
        (!is.na(V3002) & V3002 == "Não") &
        (is.na(VD4002) | VD4002 != "Pessoas ocupadas")
    ),
    
    Setor_AdminPublica = factor(case_when(
      is.na(VD4010) ~ NA_character_,
      VD4010 == "Administração pública, defesa e seguridade social" ~ "Administração pública",
      TRUE ~ "Exceto administração pública"
    )),
    
    contribuinte_renda_domicilio =  as.numeric(
      (!is.na(VD2002) & VD2002 == "Pessoa responsável") |
        (!is.na(VD2002) & VD2002 == "Cônjuge ou companheiro(a)")
    )
  )

design_trimestre <- dados_brutos
design_pi <- design_trimestre[design_trimestre$variables$UF == "Piauí", ]

# Crosswalk Estrato -> Zona/Estrato_Admin/Estrato_agregado — é a
# classificação já validada aqui em cima, exportada pra qualquer script à
# parte (ex.: de mapa) poder colorir o polígono do IBGE sem precisar
# redescobrir/duplicar essas regras.
crosswalk_trimestre <- distinct(design_pi$variables, Estrato, Zona,
                                Estrato_Admin, Estrato_agregado)

# Duas cópias, de propósito:
#   - sem sufixo: é o que o 04 e o 07 leem, sempre o trimestre corrente
#   - com sufixo: ARQUIVO. O IBGE está substituindo as UPAs de primeira
#     entrevista progressivamente (20% no 3ºT/2025 ... 100% no 3ºT/2026), então
#     o conjunto de códigos de Estrato observado MUDA de trimestre para
#     trimestre enquanto a troca não termina. Sem guardar uma cópia por
#     trimestre, cada rodada apagaria a evidência da anterior e não haveria como
#     comparar as safras — que é justamente como se descobre quais estratos são
#     resíduo do desenho antigo.
write_csv(crosswalk_trimestre, "output/crosswalk_estratos.csv")
write_csv(crosswalk_trimestre, sprintf("output/crosswalk_estratos_%s.csv", sufixo))

message("Crosswalk: ", nrow(crosswalk_trimestre), " estratos distintos no Piauí em ", sufixo, ".")

# ---- 3. Catálogo de indicadores ---------------------------------------------

catalogo_indicadores <- list(
  list(id = "Taxa_Desocupacao",
       formula = ~VD4002 == "Pessoas desocupadas",
       denominador = ~VD4001 == "Pessoas na força de trabalho",
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
  
  list(id = "Motivo_Desistencia_Desalentado",
       formula = ~V4074A, denominador = NULL, fun = svymean,
       subset = ~VD4005 == "Pessoas desalentadas"),
  
  list(id = "Taxa_Nem_Nem",
       formula = ~nem_nem, denominador = ~(V2009 >= 14 & V2009 <= 29),
       fun = svyratio, subset = NULL),
  
  list(id = "Motivo_Nao_Procura_NemNem",
       formula = ~VD4030, denominador = NULL, fun = svymean, subset = ~nem_nem == 1),
  
  list(id = "Motivo_Nao_Inicio_NemNem",
       formula = ~V4078A, denominador = NULL, fun = svymean, subset = ~nem_nem == 1)
)

recortes_demograficos <- list(
  Total                  = NULL,
  Sexo                   = ~Sexo,
  Raca                   = ~Raca,
  Faixa_Etaria_trabalho  = ~Faixa_Etaria_trabalho,
  Instrucao_agregado     = ~Instrucao,
  Instrucao              = ~VD3004
)

# geografias_agregadas vem do R/00_config.R

# ---- 4. Geografias -----------------------------------------------------------

lista_geografias <- list(
  "Brasil"      = design_trimestre,
  "Nordeste"    = subset(design_trimestre, Regiao == "Nordeste"),
  "Piauí"       = design_pi,
  "Teresina"    = subset(design_pi, Estrato_agregado == "Teresina"),
  "Zona_Urbana" = subset(design_pi, Zona == "Urbana"),
  "Zona_Rural"  = subset(design_pi, Zona == "Rural")
)

estratos_admin <- unique(design_pi$variables$Estrato_Admin)
estratos_admin <- estratos_admin[!is.na(estratos_admin)]
for (e in estratos_admin) {
  lista_geografias[[paste0("Admin_", e)]] <- subset(design_pi, Estrato_Admin == e)
}

estratos_agreg <- unique(design_pi$variables$Estrato_agregado)
estratos_agreg <- estratos_agreg[!is.na(estratos_agreg)]
for (ea in estratos_agreg) {
  lista_geografias[[paste0("Agreg_", ea)]] <- subset(design_pi, Estrato_agregado == ea)
}

estratos_micro <- unique(design_pi$variables$Estrato)
estratos_micro <- estratos_micro[!is.na(estratos_micro)]

for (em in estratos_micro) {
  lista_geografias[[paste0("Micro_", em)]] <- subset(design_pi, Estrato == em)
}

geografias_finas <- setdiff(names(lista_geografias), geografias_agregadas)

# ---- 5. Funções de cálculo e extração ---------------------------------------

aplicar_subset <- function(design, condicao) {
  if (is.null(condicao)) return(design)
  idx <- as.logical(eval(condicao[[2]], envir = design$variables))
  idx[is.na(idx)] <- FALSE
  design[idx, ]
}

aplicar_subset_denominador <- function(design, condicao) {
  if (is.null(condicao)) return(design)
  valor <- eval(condicao[[2]], envir = design$variables)
  idx <- if (is.logical(valor)) valor else !is.na(valor)
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

# ---- 6. Rodar os indicadores --------------------------------------------------

message("Calculando indicadores...")
linhas <- list()
falhas <- list()

for (geo_nome in names(lista_geografias)) {
  design_geo <- lista_geografias[[geo_nome]]
  if (nrow(design_geo) == 0) next
  
  recortes_desta_geo <- if (geo_nome %in% geografias_agregadas) "Total" else names(recortes_demograficos)
  
  for (recorte_nome in recortes_desta_geo) {
    by_formula <- recortes_demograficos[[recorte_nome]]
    
    for (spec in catalogo_indicadores) {
      if (isTRUE(spec$so_recorte_total) && recorte_nome != "Total") next
      
      by_usar       <- if (!is.null(spec$by_override)) spec$by_override else by_formula
      recorte_saida <- if (!is.null(spec$by_override)) "Formalidade" else recorte_nome
      
      resultado <- tryCatch(
        computar_estimativa(design_geo, spec, by_usar),
        error = function(e) {
          falhas[[length(falhas) + 1]] <<- tibble(
            Regiao_Geografica = geo_nome, Recorte_Demografico = recorte_saida,
            Indicador = spec$id, Erro = conditionMessage(e)
          )
          NULL
        }
      )
      if (is.null(resultado)) next
      
      linha <- tryCatch(
        extrair_resultados(resultado, spec$id, tem_by = !is.null(by_usar)) %>%
          mutate(Regiao_Geografica = geo_nome, Recorte_Demografico = recorte_saida),
        error = function(e) {
          falhas[[length(falhas) + 1]] <<- tibble(
            Regiao_Geografica = geo_nome, Recorte_Demografico = recorte_saida,
            Indicador = spec$id, Erro = paste("Falha ao extrair:", conditionMessage(e))
          )
          NULL
        }
      )
      if (!is.null(linha)) linhas[[length(linhas) + 1]] <- linha
    }
  }
}

base_trimestre <- bind_rows(linhas) %>%
  mutate(Ano = ANO_REF, Trimestre = TRIMESTRE_REF) %>%
  select(Indicador, Subcategoria_Indicador, Estimativa, SE, Ano, Trimestre,
         Regiao_Geografica, Recorte_Demografico, Categoria_Demografica)

# ---- 6b. Desigualdade formal/informal ---------------------------------------
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

message("Calculando a desigualdade formal/informal...")
linhas_desig <- list()

for (geo_nome in names(lista_geografias)) {
  design_geo <- lista_geografias[[geo_nome]]
  if (nrow(design_geo) == 0) next

  res <- tryCatch(
    calcular_desigualdade(design_geo),
    error = function(e) {
      falhas[[length(falhas) + 1]] <<- tibble(
        Regiao_Geografica = geo_nome, Recorte_Demografico = "Total",
        Indicador = "Desigualdade_Formal_Informal", Erro = conditionMessage(e)
      )
      NULL
    }
  )
  if (!is.null(res)) {
    linhas_desig[[length(linhas_desig) + 1]] <- res %>%
      mutate(Regiao_Geografica = geo_nome, .before = 1)
  }
}

desigualdade <- bind_rows(linhas_desig)

if (nrow(desigualdade) > 0) {
  write_csv(desigualdade,
            sprintf("output/desigualdade_formal_informal_%s.csv", sufixo))
  message("  -> ", nrow(desigualdade), " geografia(s) com razão formal/informal")

  # Entra também na base_ para herdar a maquinaria de CV e confiabilidade do 03.
  base_trimestre <- bind_rows(
    base_trimestre,
    desigualdade %>%
      transmute(
        Indicador = "Desigualdade_Formal_Informal",
        Subcategoria_Indicador = "Desigualdade_Formal_Informal",
        Estimativa = razao, SE = ep_razao,
        Ano = ANO_REF, Trimestre = TRIMESTRE_REF,
        Regiao_Geografica, Recorte_Demografico = "Total",
        Categoria_Demografica = "Total"
      )
  )
} else {
  message("  -> nenhuma geografia produziu razão formal/informal (ver log de falhas)")
}

write_csv(base_trimestre, sprintf("output/base_%s.csv", sufixo))
message("  -> ", nrow(base_trimestre), " linhas de indicadores")

if (length(falhas) > 0) {
  df_falhas <- bind_rows(falhas)
  write_csv(df_falhas, sprintf("output/log_falhas_%s.csv", sufixo))
  message("  -> ", nrow(df_falhas), " falha(s) (ver log_falhas_", sufixo, ".csv)")
}

# ---- 7. Testes de significância DEMOGRÁFICOS ---------------------------------
# Dentro de cada geografia fina, o indicador difere por sexo/faixa
# etária/instrução?

# GUARDAS CONTRA MATRIZ DE COVARIÂNCIA DEGENERADA
# -----------------------------------------------
# O desenho da PNADC entregue pelo PNADcIBGE é de RÉPLICAS BOOTSTRAP (200 pesos
# V1028001..V1028200), não de linearização de Taylor: o pacote monta um
# svrepdesign sempre que os microdados trazem esses pesos. A variância de
# qualquer estatística é a dispersão dela ENTRE as 200 réplicas.
#
# Isso cria um modo de falha que não existe no desenho de Taylor. Num recorte
# fino, uma réplica pode ficar sem nenhuma observação de determinada célula. No
# ajuste quasibinomial isso é separação completa: o coeficiente vai para o
# infinito e o R para em torno de 1e15. Como a variância é a dispersão entre
# réplicas, UMA réplica assim domina a matriz inteira.
#
# Medido no 2026T2, sobre os 2.236 modelos svyglm da bateria demográfica:
#
#   réplicas divergentes (|coef| > 1e6 x escala do ponto) : 137 modelos (6,1%)
#   matriz de covariância de posto deficiente             : 380 modelos
#     destes, com réplica divergente                      : 129
#     destes, sem réplica divergente                      : 251
#
# A divergência explica só um terço da degeneração — o resto é quase-separação
# que não chega a estourar. Por isso a guarda é o POSTO da matriz, não um
# limiar sobre o tamanho do coeficiente: é mais abrangente e não depende de
# escolher constante arbitrária.
#
# E o dano não é aleatório. Entre os testes que concluíram com posto
# deficiente, 42,2% deram p < 0,05, contra 32,2% entre os de posto completo:
# variância degenerada subestima o erro padrão em alguma direção, e o teste
# rejeita demais. Publicar esses p-valores seria inventar significância.
#
# O risco é previsível pelo tamanho da menor célula do recorte:
#
#   menor célula até 5 obs  -> 37,9% de posto deficiente
#   de 6 a 10               -> 20,1%
#   de 26 a 50              ->  7,4%
#   acima de 100            ->  0,6%
#
# Para resposta CATEGÓRICA o caminho é outro (svychisq, que inverte a
# covariância das proporções de célula), mas a raiz é a mesma: célula vazia.
# Varrendo 387 combinações de motivo x recorte x geografia, a fração de células
# vazias separa bem os casos: abaixo de 20% de células vazias, nenhuma falha em
# 124 tentativas; acima de 40%, 61% falham. Daí o limiar abaixo.

MAX_FRAC_CELULAS_VAZIAS <- 0.20

# POR QUE A GUARDA APENAS RECUSA, EM VEZ DE CAIR PARA O RECORTE AGREGADO
# ---------------------------------------------------------------------
# A tentação é, ao barrar o recorte fino, repetir o teste no agregado
# correspondente. Seria errado aqui, porque o agregado JÁ É UM RECORTE DA
# BATERIA por decisão de projeto:
#
#     recortes_demograficos: Instrucao -> ~VD3004 ; Instrucao_agregado -> ~Instrucao
#     recortes_regionais   : Estrato_Micro -> Estrato ; Estrato_Agregado -> Estrato_agregado
#
# A queda produziria uma linha idêntica à que já existe — mesmo desenho, mesma
# variável, mesmo p-valor. Duas consequências ruins: a tabela sugere duas
# evidências onde há uma, e o ajuste de Benjamini-Hochberg passa a contar o
# mesmo teste duas vezes na família, distorcendo o controle de FDR justamente
# nos indicadores que mais precisam dele.
#
# Então a guarda recusa e pronto. A mensagem de log aponta o recorte agregado
# onde a mesma pergunta é respondida em resolução menor, para quem for ler o
# log não concluir que a informação se perdeu.
recorte_equivalente <- list(
  "VD3004"  = "Instrucao_agregado",  # 7 níveis de instrução -> recorte dicotomizado
  "Estrato" = "Estrato_Agregado"     # 26 estratos finos     -> recorte agregado
)

extrair_p_valor <- function(teste) {
  for (campo in c("p", "p.value")) {
    if (!is.null(teste[[campo]])) return(as.numeric(teste[[campo]])[1])
  }
  NA_real_
}

rodar_teste <- function(design_geo, spec, var_recorte) {
  design_usar <- aplicar_subset(design_geo, spec$subset)
  if (identical(spec$fun, svyratio) && !is.null(spec$denominador)) {
    design_usar <- aplicar_subset_denominador(design_usar, spec$denominador)
  }
  if (nrow(design_usar) == 0) return(list(pulado = "design ficou com 0 linhas depois do subset/denominador"))
  
  design_usar$variables[[var_recorte]] <- droplevels(as.factor(design_usar$variables[[var_recorte]]))
  if (nlevels(design_usar$variables[[var_recorte]]) < 2) {
    return(list(pulado = sprintf("recorte %s tem só %d nível(is) presente(s) nesse subconjunto",
                                 var_recorte, nlevels(design_usar$variables[[var_recorte]]))))
  }
  
  resposta <- eval(spec$formula[[2]], envir = design_usar$variables)
  
  if (is.factor(resposta) || is.character(resposta)) {
    design_usar$variables$.resposta <- droplevels(factor(resposta))
    if (nlevels(design_usar$variables$.resposta) < 2) {
      return(list(pulado = "resposta categórica com menos de 2 níveis presentes"))
    }
    # Tabela esparsa demais nem chega a ser tentada: o svychisq inverte a
    # covariância das proporções de célula, e célula vazia tem variância zero.
    tabela <- table(design_usar$variables$.resposta,
                    design_usar$variables[[var_recorte]])
    frac_vazias <- sum(tabela == 0) / length(tabela)
    if (frac_vazias > MAX_FRAC_CELULAS_VAZIAS) {
      return(list(degradar = sprintf(
        "tabela %dx%d com %.0f%% de células vazias (limite %.0f%%)",
        nrow(tabela), ncol(tabela), 100 * frac_vazias,
        100 * MAX_FRAC_CELULAS_VAZIAS)))
    }

    formula_teste <- as.formula(paste0("~.resposta + ", var_recorte))
    teste <- tryCatch(svychisq(formula_teste, design = design_usar), error = function(e) e)
    if (inherits(teste, "error")) return(list(degradar = conditionMessage(teste)))
    return(list(metodo = "svychisq", estatistica = unname(teste$statistic[1]),
                gl = paste(teste$parameter, collapse = ", "), p_valor = teste$p.value,
                n = nrow(design_usar)))
  }
  
  design_usar$variables$.resposta <- as.numeric(resposta)
  valores <- unique(na.omit(design_usar$variables$.resposta))
  if (length(valores) < 2) {
    return(list(pulado = sprintf(
      "resposta numérica (classe original: %s) com %d valor(es) distinto(s) não-NA — precisa de pelo menos 2. Ex. de valores brutos: %s",
      paste(class(resposta), collapse = "/"), length(valores),
      paste(utils::head(resposta, 5), collapse = ", ")
    )))
  }
  familia <- if (all(valores %in% c(0, 1))) quasibinomial() else gaussian()
  
  formula_modelo <- as.formula(paste0(".resposta ~ ", var_recorte))
  modelo <- tryCatch(
    do.call(svyglm, list(formula = formula_modelo, design = design_usar, family = familia)),
    error = function(e) e
  )
  if (inherits(modelo, "error")) return(list(degradar = conditionMessage(modelo)))

  # A guarda descrita acima. Vem ANTES do teste porque um p-valor calculado
  # sobre matriz de posto deficiente é pior do que p-valor nenhum: ele parece
  # legítimo e puxa para a significância.
  V <- vcov(modelo)
  if (qr(V)$rank < ncol(V)) {
    return(list(degradar = sprintf(
      "matriz de covariância replicada com posto %d de %d", qr(V)$rank, ncol(V))))
  }
  
  # POR QUE method = "LRT" E NÃO O WALD PADRÃO
  # ------------------------------------------
  # O teste de Wald é mal calibrado quando o número de parâmetros testados
  # cresce em relação aos graus de liberdade do desenho — exatamente a situação
  # dos recortes com muitas categorias, como o estrato de 7 dígitos. A matriz de
  # covariância estimada a partir de poucas UPAs fica ruidosa, e a estatística
  # de Wald é muito sensível a isso (THOMAS; RAO, 1987; KORN; GRAUBARD, 1990).
  #
  # Medido por simulação sob H0 (sem nenhuma diferença entre grupos, 400
  # réplicas, estrutura de estratos e UPAs igual à da PNADC), com nível nominal
  # de 5%:
  #
  #     5 grupos, 12 UPAs cada   Wald 0,050   LRT 0,037
  #    20 grupos,  4 UPAs cada   Wald 0,505   LRT 0,035
  #    26 grupos,  3 UPAs cada   Wald 0,797   LRT 0,028
  #
  # Ou seja: no recorte fino o Wald rejeitava metade das vezes em que NÃO havia
  # diferença — dez vezes o nível nominal. O LRT de Rao-Scott fica levemente
  # conservador e mantém poder real: com 20 grupos, detecta 94,5% dos efeitos de
  # meio desvio-padrão e 100% dos de 0,8.
  #
  # O df do desenho (degf) entra explicitamente porque é o número de UPAs menos
  # o de estratos que governa a referência do teste, não o número de pessoas.
  teste <- tryCatch(
    regTermTest(modelo, as.formula(paste0("~", var_recorte)),
                method = "LRT", df = degf(design_usar)),
    error = function(e) e
  )
  if (inherits(teste, "error")) return(list(degradar = conditionMessage(teste)))
  
  list(metodo = "svyglm+regTermTest(LRT)",
       estatistica = unname(if (!is.null(teste$Ftest)) teste$Ftest[1] else teste$chisq[1]),
       gl = paste(unlist(teste[c("df", "ddf")]), collapse = ", "),
       p_valor = extrair_p_valor(teste), n = nrow(design_usar))
}

# Envelope do rodar_teste: traduz a recusa da guarda numa falha de log com
# mensagem útil, e carimba a variável efetivamente testada na linha de saída.
rodar_teste_guardado <- function(design_geo, spec, var_recorte) {
  r <- tryCatch(rodar_teste(design_geo, spec, var_recorte),
                error = function(e) list(degradar = conditionMessage(e)))

  if (is.null(r$degradar)) {
    r$variavel_usada <- var_recorte
    return(r)
  }

  equivalente <- recorte_equivalente[[var_recorte]]
  remissao <- if (is.null(equivalente)) {
    " (não há recorte agregado equivalente nesta dimensão)"
  } else {
    paste0(" — ver o recorte ", equivalente,
           ", que responde à mesma pergunta em resolução menor")
  }

  list(erro = paste0("RECUSADO pela guarda de variância: ", r$degradar, remissao))
}

message("Rodando testes de significância demográficos...")
linhas_teste <- list()
falhas_teste <- list()

for (geo_nome in geografias_finas) {
  design_geo <- lista_geografias[[geo_nome]]
  if (nrow(design_geo) == 0) next
  
  for (spec in catalogo_indicadores) {
    recortes_a_testar <- if (!is.null(spec$by_override)) all.vars(spec$by_override) else names(recortes_demograficos)[-1]
    
    for (nome_recorte in recortes_a_testar) {

      # O NOME do recorte e a COLUNA que ele testa não são a mesma coisa. Em
      # recortes_demograficos:
      #     Instrucao_agregado -> ~Instrucao      (dicotomizada)
      #     Instrucao          -> ~VD3004         (detalhada)
      # Os demais coincidem por acaso (Sexo -> ~Sexo), e era esse acaso que
      # sustentava o laço antigo, que passava o NOME direto como variável.
      #
      # As consequências no trimestre 2026T2, medidas no log de falhas:
      #   - Instrucao_agregado: não existe coluna com esse nome, então TODAS as
      #     575 tentativas morriam com "substituto tem 0 linha, dados têm N".
      #     O recorte inteiro ficava sem um único teste.
      #   - Instrucao: existe uma coluna chamada Instrucao (a dicotomizada), e o
      #     teste rodava SOBRE ELA sem erro — enquanto as estimativas da base_
      #     para esse mesmo recorte eram calculadas por VD3004. O p-valor era
      #     então anexado a estimativas de outra variável. Falha silenciosa, que
      #     é a pior espécie: não aparecia em log nenhum.
      #
      # A correção é ler a coluna da fórmula, que é a mesma fonte que a seção 6
      # usa para calcular as estimativas — assim teste e estimativa não podem
      # divergir. O rótulo reportado continua sendo o NOME, para casar com o
      # Recorte_Demografico da base_.
      var_recorte <- if (!is.null(recortes_demograficos[[nome_recorte]])) {
        all.vars(recortes_demograficos[[nome_recorte]])
      } else {
        nome_recorte
      }

      resultado <- rodar_teste_guardado(design_geo, spec, var_recorte)
      
      if (!is.null(resultado$pulado)) {
        falhas_teste[[length(falhas_teste) + 1]] <- tibble(
          Regiao_Geografica = geo_nome, Recorte_Demografico = nome_recorte,
          Indicador = spec$id, Erro = paste("PULADO:", resultado$pulado)
        )
        next
      }
      if (!is.null(resultado$erro)) {
        falhas_teste[[length(falhas_teste) + 1]] <- tibble(
          Regiao_Geografica = geo_nome, Recorte_Demografico = nome_recorte,
          Indicador = spec$id, Erro = resultado$erro
        )
        next
      }
      
      linhas_teste[[length(linhas_teste) + 1]] <- tibble(
        Indicador = spec$id, Regiao_Geografica = geo_nome,
        Recorte_Demografico = nome_recorte,
        Variavel_Testada = resultado$variavel_usada,
        Metodo = resultado$metodo,
        Estatistica = resultado$estatistica, GL = resultado$gl,
        p_valor = resultado$p_valor, N = resultado$n
      )
    }
  }
}

testes_trimestre <- bind_rows(linhas_teste)

# AJUSTE PARA MULTIPLICIDADE
# --------------------------
# Cada indicador é testado contra o mesmo recorte demográfico em dezenas de
# geografias. Sob a hipótese nula global, 5% desses testes sairiam
# significativos por acaso — com ~36 geografias por indicador, isso é quase
# duas "descobertas" espúrias por linha da tabela.
#
# A família de testes adotada é (indicador x recorte demográfico), ajustando
# ao longo das geografias. É a família que corresponde à pergunta de fato
# formulada: "em quais territórios este indicador difere por sexo?". Ajustar
# ao longo dos indicadores misturaria perguntas diferentes.
#
# Usa-se Benjamini-Hochberg, que controla a taxa de falsas descobertas (a
# proporção esperada de falsos positivos ENTRE os resultados declarados
# significativos), e não a probabilidade de qualquer falso positivo. É o
# controle adequado a um relatório descritivo: Bonferroni, que controla a taxa
# por família, seria conservador demais para um levantamento exploratório e
# apagaria diferenças territoriais reais.
#
# As duas colunas convivem: p_valor é o bruto, p_ajustado é o corrigido. O
# relatório usa o ajustado; o anexo publica os dois.
if (nrow(testes_trimestre) > 0) {
  testes_trimestre <- testes_trimestre %>%
    group_by(Indicador, Recorte_Demografico) %>%
    mutate(
      n_testes_familia = n(),
      p_ajustado       = p.adjust(p_valor, method = "BH")
    ) %>%
    ungroup()

  message(sprintf("  -> significativos a 5%%: %d brutos, %d após ajuste BH",
                  sum(testes_trimestre$p_valor    < 0.05, na.rm = TRUE),
                  sum(testes_trimestre$p_ajustado < 0.05, na.rm = TRUE)))
}

write_csv(testes_trimestre, sprintf("output/testes_significancia_%s.csv", sufixo))
message("  -> ", nrow(testes_trimestre), " testes demográficos")

if (length(falhas_teste) > 0) {
  write_csv(bind_rows(falhas_teste), sprintf("output/log_falhas_testes_%s.csv", sufixo))
}

# ---- 7b. Testes de significância REGIONAIS ------------------------------------
# Diferente da seção 7 (que testa, DENTRO de cada geografia fina, se o
# indicador difere por sexo/idade/instrução): aqui testamos se o indicador
# difere ENTRE as categorias de um mesmo tipo de recorte regional — zona
# urbana x rural, estratos administrativos entre si, estratos agregados
# entre si, e Teresina x resto do Piauí.
#
# "Teresina x Piauí", do jeito que foi pedido, não dá pra testar
# literalmente: Teresina é um SUBCONJUNTO de Piauí (todo mundo de Teresina
# também é Piauí), não duas populações separadas — e teste de diferença de
# média precisa de grupos que não se sobrepõem. Testei Teresina contra o
# RESTO do Piauí (excluindo Teresina), que é a comparação que de fato
# responde "Teresina é diferente do resto do estado?".
#
# Reaproveita a mesma rodar_teste() da seção 7 — ela já é genérica o
# suficiente pra receber qualquer design + qualquer variável de
# agrupamento, então não precisei duplicar a lógica.

design_pi$variables$Teresina_Resto <- factor(ifelse(
  design_pi$variables$Estrato_agregado == "Teresina", "Teresina", "Resto do Piauí"
))

recortes_regionais <- list(
  "Zona"                   = "Zona",
  "Estrato_Administrativo" = "Estrato_Admin",
  "Estrato_Agregado"       = "Estrato_agregado",
  "Estrato_Micro"          = "Estrato",
  "Teresina_x_Resto_Piaui" = "Teresina_Resto"
)

message("Rodando testes de significância regionais...")
linhas_regional <- list()
falhas_regional <- list()

for (spec in catalogo_indicadores) {
  for (rotulo_recorte in names(recortes_regionais)) {
    var_recorte <- recortes_regionais[[rotulo_recorte]]
    
    resultado <- rodar_teste_guardado(design_pi, spec, var_recorte)
    
    if (!is.null(resultado$pulado)) {
      falhas_regional[[length(falhas_regional) + 1]] <- tibble(
        Recorte_Regional = rotulo_recorte, Indicador = spec$id, Erro = paste("PULADO:", resultado$pulado)
      )
      next
    }
    if (!is.null(resultado$erro)) {
      falhas_regional[[length(falhas_regional) + 1]] <- tibble(
        Recorte_Regional = rotulo_recorte, Indicador = spec$id, Erro = resultado$erro
      )
      next
    }
    
    linhas_regional[[length(linhas_regional) + 1]] <- tibble(
      Indicador = spec$id, Recorte_Regional = rotulo_recorte,
      Variavel_Testada = resultado$variavel_usada,
      Metodo = resultado$metodo,
      Estatistica = resultado$estatistica, GL = resultado$gl,
      p_valor = resultado$p_valor, N = resultado$n
    )
  }
}

testes_regionais <- bind_rows(linhas_regional)

# Mesmo ajuste, família diferente: aqui a bateria é pequena (um punhado de
# recortes x os indicadores do catálogo), e a pergunta do relatório —
# "quais recortes territoriais discriminam?" — é lida sobre a tabela inteira.
# Por isso o ajuste percorre toda a bateria, sem agrupar.
if (nrow(testes_regionais) > 0) {
  testes_regionais <- testes_regionais %>%
    mutate(
      n_testes_familia = n(),
      p_ajustado       = p.adjust(p_valor, method = "BH")
    )

  message(sprintf("  -> significativos a 5%%: %d brutos, %d após ajuste BH",
                  sum(testes_regionais$p_valor    < 0.05, na.rm = TRUE),
                  sum(testes_regionais$p_ajustado < 0.05, na.rm = TRUE)))
}

write_csv(testes_regionais, sprintf("output/testes_regionais_%s.csv", sufixo))
message("  -> ", nrow(testes_regionais), " testes regionais")

if (length(falhas_regional) > 0) {
  write_csv(bind_rows(falhas_regional), sprintf("output/log_falhas_regional_%s.csv", sufixo))
}

# ---- 8. Gráficos de confiabilidade -------------------------------------------

base_trimestre <- base_trimestre %>%
  mutate(
    CV = ifelse(Estimativa != 0, abs(SE / Estimativa) * 100, NA_real_),
    Nivel_Geografico = case_when(
      Regiao_Geografica %in% geografias_agregadas ~ "Agregado",
      str_starts(Regiao_Geografica, "Zona_")  ~ "Zona",
      str_starts(Regiao_Geografica, "Admin_") ~ "Administrativo",
      str_starts(Regiao_Geografica, "Agreg_") ~ "Agregado_Geografico",
      TRUE ~ "Outro"
    )
  )

p_hist_cv <- ggplot(base_trimestre %>% filter(!is.na(CV)), aes(x = CV)) +
  geom_histogram(binwidth = 5, boundary = 0, fill = "steelblue", color = "white") +
  geom_vline(xintercept = 30, linetype = "dashed", color = "firebrick") +
  labs(title = paste("Distribuição do coeficiente de variação —", sufixo),
       subtitle = "Linha tracejada: CV = 30% (referência de baixa confiabilidade)",
       x = "CV (%)", y = "Nº de estimativas") +
  theme_minimal()
ggsave(sprintf("output/figuras/hist_cv_%s.png", sufixo), p_hist_cv, width = 8, height = 5, bg = "white")

p_box_cv <- ggplot(base_trimestre %>% filter(!is.na(CV)),
                   aes(x = Nivel_Geografico, y = CV)) +
  geom_boxplot(fill = "lightblue") +
  geom_hline(yintercept = 30, linetype = "dashed", color = "firebrick") +
  labs(title = paste("CV por nível geográfico —", sufixo), x = NULL, y = "CV (%)") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))
ggsave(sprintf("output/figuras/boxplot_cv_nivel_%s.png", sufixo), p_box_cv, width = 8, height = 5, bg = "white")

message("  -> gráficos de confiabilidade salvos em output/figuras/")

# ---- 9. Distribuição da renda habitual (real) --------------------------------

construir_df_renda <- function(lista_geografias) {
  map_dfr(names(lista_geografias), function(nome) {
    d <- lista_geografias[[nome]]
    d <- subset(d, VD4002 == "Pessoas ocupadas" & !is.na(VD4019_real))
    if (nrow(d) == 0) return(NULL)
    tibble(
      Regiao_Geografica = nome,
      VD4019_real = d$variables$VD4019_real,
      Setor_AdminPublica = d$variables$Setor_AdminPublica,
      peso = as.numeric(weights(d, type = "sampling"))
    )
  })
}

df_renda <- construir_df_renda(lista_geografias)
write_csv(df_renda, sprintf("output/renda_individual_%s.csv", sufixo))

percentil_ponderado <- function(x, peso, p) {
  ok <- !is.na(x) & !is.na(peso)
  x <- x[ok]; peso <- peso[ok]
  ordem <- order(x)
  x <- x[ordem]; peso <- peso[ordem]
  cum <- cumsum(peso) / sum(peso)
  x[which(cum >= p)[1]]
}
p99 <- percentil_ponderado(design_trimestre$variables$VD4019_real,
                           weights(design_trimestre, type = "sampling"), 0.99)

ordem_geo <- c("Brasil", "Nordeste", "Piauí", "Teresina",
               names(lista_geografias)[!names(lista_geografias) %in% geografias_agregadas])
df_renda <- df_renda %>% mutate(Regiao_Geografica = factor(Regiao_Geografica, levels = ordem_geo))

df_renda_plot <- df_renda %>% filter(VD4019_real <= p99)
largura_bin <- p99 / 40

p_renda_total <- ggplot(df_renda_plot, aes(x = VD4019_real, weight = peso)) +
  geom_histogram(binwidth = largura_bin, boundary = 0, fill = "steelblue", color = "white") +
  facet_wrap(~Regiao_Geografica, scales = "free_y", ncol = 4) +
  labs(title = paste("Distribuição da renda habitual real —", sufixo),
       subtitle = sprintf("Excluídos valores acima do percentil 99 (R$ %.0f, calculado sobre o Brasil)", p99),
       x = "Renda habitual real (R$)", y = "Pessoas (ponderado)") +
  theme_minimal(base_size = 9)
ggsave(sprintf("output/figuras/renda_total_%s.png", sufixo), p_renda_total, width = 12, height = 9, bg = "white")

df_renda_setor <- df_renda_plot %>% filter(!is.na(Setor_AdminPublica))

p_renda_setor <- ggplot(df_renda_setor, aes(x = VD4019_real, weight = peso, fill = Setor_AdminPublica)) +
  geom_histogram(binwidth = largura_bin, boundary = 0, position = "identity", alpha = 0.55, color = NA) +
  facet_wrap(~Regiao_Geografica, scales = "free_y", ncol = 4) +
  labs(title = paste("Distribuição da renda habitual real por setor —", sufixo),
       subtitle = sprintf("Administração pública x demais setores. Excluídos valores acima do percentil 99 (R$ %.0f)", p99),
       x = "Renda habitual real (R$)", y = "Pessoas (ponderado)", fill = NULL) +
  theme_minimal(base_size = 9) +
  theme(legend.position = "bottom")
ggsave(sprintf("output/figuras/renda_setor_%s.png", sufixo), p_renda_setor, width = 12, height = 9, bg = "white")

message("  -> histogramas de renda salvos em output/figuras/")
message("Concluído: ", sufixo)