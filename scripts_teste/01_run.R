# ==============================================================================
# 01_run.R — Série histórica de indicadores PNADC (IBGE)
#
# Geografias:
#   Nível 1 (agregados, desenho nacional completo, só recorte "Total"):
#     Brasil, Nordeste, Piauí, Teresina
#   Nível 2 (estratos finos do Piauí, desenho subset UF == "Piauí"):
#     Zona_Urbana, Zona_Rural, Admin_<estrato>, Agreg_<estrato>
#     -> só o Nível 2 é cruzado com os recortes demográficos (Sexo, Faixa
#        etária, Instrução), conforme combinado. Se você também queria os
#        agregados (Brasil/Nordeste/Piauí/Teresina) quebrados por sexo/idade/
#        instrução, é só remover essas 4 strings do vetor
#        `geografias_agregadas` abaixo.
#
# Trimestres: processados em ordem reversa, 2026T2 -> 2015T4 (script
# retomável: se já existir linha para um trimestre no CSV de saída, ele é
# pulado — então dá pra parar e continuar depois sem perder trabalho nem
# reprocessar o que já foi feito).
#
# MODO_TESTE (abaixo) começa em TRUE e roda só os 2 trimestres mais recentes,
# pra você validar o resultado antes de soltar o histórico completo (que
# envolve baixar e processar 44 trimestres).
# ==============================================================================

library(PNADcIBGE)
library(survey)
library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(tibble)

# ---- 0. Pastas e arquivos de saída ------------------------------------------

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
dir.create("output", recursive = TRUE, showWarnings = FALSE)

arquivo_saida <- "output/base_consolidada.csv"
arquivo_log   <- "output/log_falhas.csv"

MODO_TESTE <- TRUE  # TRUE = só os 2 trimestres mais recentes. Mude pra FALSE
# quando já tiver validado o resultado do teste.

# ---- 1. Salário mínimo por hora, por ano ------------------------------------
# (SM mensal / 220h). Conferido contra os valores oficiais de 2025 (R$1.518)
# e 2026 (R$1.621): 1518/220 = 6.90 e 1621/220 = 7.37 — bate com a tabela.

tabela_salario_minimo <- tibble(
  ano     = 2015:2026,
  sm_hora = c(3.58, 4.00, 4.26, 4.34, 4.54, 4.75, 5.00, 5.51, 6.00, 6.42, 6.87, 7.37)
)

# ---- 2. Cronograma dos trimestres -------------------------------------------

cronograma <- data.frame(ano = 2015:2026) %>%
  crossing(trimestre = 1:4) %>%
  filter(
    (ano == 2015 & trimestre == 4) |
      (ano > 2015 & ano < 2026) |
      (ano == 2026 & trimestre %in% 1:2)
  ) %>%
  arrange(desc(ano), desc(trimestre))

if (MODO_TESTE) {
  cronograma <- head(cronograma, 2)
  message(">>> MODO_TESTE ligado: processando só ", nrow(cronograma), " trimestre(s).")
}

# Retomada: pula trimestre que já tenha linha na base consolidada
if (file.exists(arquivo_saida)) {
  ja_feito <- read_csv(arquivo_saida, col_select = c(Ano, Trimestre),
                       show_col_types = FALSE) %>%
    distinct()
  antes <- nrow(cronograma)
  cronograma <- cronograma %>%
    anti_join(ja_feito, by = c("ano" = "Ano", "trimestre" = "Trimestre"))
  if (nrow(cronograma) < antes) {
    message(">>> Retomando: ", antes - nrow(cronograma),
            " trimestre(s) já estavam no CSV de saída e foram pulados.")
  }
}

# ---- 3. Preparação das variáveis derivadas ----------------------------------
# Reaproduz a lógica de 01_processamento_dados.R (já validada), com dois
# ajustes de digitação nos nomes de UF do Nordeste que faziam Rio Grande do
# Norte e Pernambuco caírem em "Resto do Brasil" por engano.
#
# Renda real: pra microdados TRIMESTRAIS a PNADC usa um único arquivo de
# deflator pra série histórica inteira, sempre a preços médios do último
# trimestre civil divulgado (confirmado na documentação oficial do IBGE,
# PNADcIBGE_Deflator_Trimestral.pdf) — por isso defyear/defperiod não se
# aplicam aqui (são só pra microdados anuais) e foram tirados do
# get_pnadc(); passá-los só gera aquele aviso "will be ignored for this
# type of microdata", sem efeito nenhum. O "Habitual" já vem pronto,
# referenciado ao trimestre mais recente disponível na hora do download —
# é exatamente a comparabilidade que eu queria simular com defyear fixo.
#
# CUIDADO: como o arquivo de deflator é atualizado a cada novo trimestre
# publicado pelo IBGE, se essa rodada ficar em aberto por semanas e o IBGE
# soltar um trimestre novo no meio do caminho, a referência "mais recente"
# muda — os trimestres baixados antes e depois desse lançamento ficariam
# com bases ligeiramente diferentes. Pra uma rodada de dias isso não deve
# pesar, mas vale rodar o histórico completo num intervalo curto, ou
# recomeçar do zero (apagando output/ e data/raw/) se atravessar um
# lançamento do IBGE no meio.
preparar_desenho <- function(ano_ref, trimestre_ref) {
  
  sm_hora_corrente <- tabela_salario_minimo %>%
    filter(ano == ano_ref) %>%
    pull(sm_hora)
  
  dados_brutos <- get_pnadc(year = ano_ref, quarter = trimestre_ref, deflator = TRUE)
  
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
      Faixa_Etaria_trabalho  = case_match(V2009,
                                          14:29   ~ "Jovens",
                                          30:64   ~ "Adulto",
                                          65:130  ~ "Idoso",
                                          .default = NA_character_
      ),
      Instrucao = VD3004,
      
      formal_setor_privado = factor(case_match(VD4009,
                                               "Empregado no setor privado com carteira de trabalho assinada" ~ "Com carteira",
                                               "Empregado no setor privado sem carteira de trabalho assinada" ~ "Sem carteira"
      )),
      
      anos_estudos_11_ou_mais = factor(case_match(VD3005,
                                                  c("11 anos de estudo", "12 anos de estudo", "13 anos de estudo",
                                                    "14 anos de estudo", "15 anos de estudo", "16 anos ou mais de estudo") ~ 1,
                                                  .default = 0
      )),
      
      ft_ou_desalentada = as.numeric(
        (!is.na(VD4001) & VD4001 == "Pessoas na força de trabalho") |
          (!is.na(VD4005) & VD4005 == "Pessoas desalentadas")
      ),
      
      valor_hora      = VD4019 / (5 * VD4031),
      subremuneracao  = as.numeric(valor_hora < sm_hora_corrente),
      
      # Renda a preços de 2026T2 (ver BASE_DEFLATOR_* acima) — só pra uso em
      # indicadores de nível de renda; a subremuneração acima usa VD4019
      # nominal de propósito.
      VD4019_real = VD4019 * Habitual,
      
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
      )
    )
  
  dados_brutos
}

# ---- 4. Catálogo de indicadores ---------------------------------------------
# Cada indicador é uma linha: fórmula, denominador (NULL se for svymean),
# a função (svyratio ou svymean) e um subset opcional aplicado antes de
# calcular. Fórmulas idênticas às validadas em pnadc_estratos_testes.R /
# 01_processamento_dados.R — não mexi em nenhuma delas.

catalogo_indicadores <- list(
  list(id = "Taxa_Desocupacao",
       formula = ~VD4002 == "Pessoas desocupadas",
       denominador = ~VD4001 == "Pessoas na força de trabalho",
       fun = svyratio, subset = NULL),
  
  list(id = "Desocupados_Longa_Duracao",
       formula = ~V4076 == "2 anos ou mais",
       denominador = ~VD4002 == "Pessoas desocupadas",
       fun = svyratio, subset = NULL),
  
  list(id = "Chefes_Familia_Desocupados",
       formula = ~VD2002 == "Pessoa responsável",
       denominador = ~VD4002 == "Pessoas desocupadas",
       fun = svyratio, subset = ~VD4002 == "Pessoas desocupadas"),
  
  list(id = "Rendimento_Medio_Habitual",
       formula = ~VD4019_real, denominador = NULL, fun = svymean, subset = NULL),
  
  list(id = "Percentual_Subremuneracao",
       formula = ~subremuneracao, denominador = NULL, fun = svymean, subset = NULL),
  
  # Reproduz o contraste do pnadc_estratos_testes.R original
  # (by = interaction(Estrato_agregado, formal_setor_privado)): a geografia já
  # vem do design_geo do loop, então aqui só precisamos cruzar por
  # formal_setor_privado. `by_override` substitui o recorte demográfico da
  # passada atual e `so_recorte_total = TRUE` faz esse indicador rodar uma
  # única vez por geografia (na passada "Total"), em vez de uma vez por
  # recorte demográfico — senão sairia repetido e idêntico 4x.
  list(id = "Rendimento_por_Formalidade",
       formula = ~VD4019_real, denominador = NULL, fun = svymean,
       subset = ~!is.na(formal_setor_privado),
       by_override = ~formal_setor_privado,
       so_recorte_total = TRUE),
  
  list(id = "Taxa_Informalidade",
       formula = ~informal, denominador = ~VD4002 == "Pessoas ocupadas",
       fun = svyratio, subset = NULL),
  
  list(id = "Taxa_Subocupacao",
       formula = ~(!is.na(VD4004A) & VD4004A == "Pessoas subocupadas"),
       denominador = ~VD4002 == "Pessoas ocupadas", fun = svyratio, subset = NULL),
  
  list(id = "Proporcao_Ocupados_Escolarizados",
       formula = ~(!is.na(anos_estudos_11_ou_mais) & anos_estudos_11_ou_mais == 1),
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
       formula = ~V4074A, denominador = NULL, fun = svymean, subset = ~nem_nem == 1),
  
  list(id = "Motivo_Nao_Inicio_NemNem",
       formula = ~V4078A, denominador = NULL, fun = svymean, subset = ~nem_nem == 1)
)

# ---- 5. Recortes demográficos e geografias que os recebem -------------------

recortes_demograficos <- list(
  Total                  = NULL,
  Sexo                   = ~Sexo,
  Faixa_Etaria_trabalho  = ~Faixa_Etaria_trabalho,
  Instrucao              = ~Instrucao
)

geografias_agregadas <- c("Brasil", "Nordeste", "Piauí", "Teresina")

# ---- 6. Funções auxiliares de cálculo e extração ----------------------------

# Aplica um subset guardado como fórmula de um lado só (~condicao) sem
# depender de NSE dentro de um loop — avalia a condição direto em
# design$variables e indexa o desenho.
aplicar_subset <- function(design, condicao) {
  if (is.null(condicao)) return(design)
  idx <- eval(condicao[[2]], envir = design$variables)
  idx[is.na(idx)] <- FALSE
  design[idx, ]
}

# Roda svyratio/svymean direto (recorte "Total") ou via svyby (quando há
# by_formula) — um único ponto que decide qual chamar.
#
# A fórmula entra como primeiro elemento SEM NOME na lista de argumentos de
# propósito: svyratio() chama esse parâmetro de "formula", mas svymean()
# chama de "x" — nomeando errado, um dos dois quebra com "argument x is
# missing". Deixando sem nome, o R casa por posição com o que sobrar em
# cada função, então funciona pras duas.
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

# Converte o resultado numa tabela longa.
# - Sem by (svyratio()/svymean() direto): as.data.frame() não tem método
#   pra objeto "svyratio" (dá erro de coerção) e é frágil pra "svystat"
#   também — coef()/SE() funcionam igual pras duas classes, então uso elas
#   aqui em vez de as.data.frame().
# - Com by (resultado de svyby()): as.data.frame() funciona bem; a ordem
#   das colunas é [by, k colunas de estimativa, k colunas de SE].
extrair_resultados <- function(resultado, ind_nome, tem_by) {
  
  if (!tem_by) {
    est <- coef(resultado)
    se  <- SE(resultado)
    nomes <- names(est)
    if (is.null(nomes) || all(nomes == "")) nomes <- ind_nome
    return(tibble(
      Indicador               = ind_nome,
      Subcategoria_Indicador  = nomes,
      Estimativa              = as.numeric(est),
      SE                      = as.numeric(se),
      Categoria_Demografica   = "Total"
    ))
  }
  
  df <- as.data.frame(resultado)
  rownames(df) <- NULL
  
  df <- df %>% rename(Categoria_Demografica = 1)
  df$Categoria_Demografica <- as.character(df$Categoria_Demografica)
  
  resto <- df %>% select(-Categoria_Demografica)
  k <- ncol(resto) / 2
  stopifnot(k == floor(k))  # se falhar aqui, o svyby devolveu um layout inesperado
  est_cols <- names(resto)[seq_len(k)]
  se_cols  <- names(resto)[(k + 1):(2 * k)]
  
  map_dfr(seq_len(k), function(j) {
    df %>%
      transmute(
        Indicador               = ind_nome,
        Subcategoria_Indicador  = est_cols[j],
        Estimativa              = .data[[est_cols[j]]],
        SE                      = .data[[se_cols[j]]],
        Categoria_Demografica
      )
  })
}

# ---- 7. Loop principal -------------------------------------------------------

for (i in seq_len(nrow(cronograma))) {
  
  ano_c  <- cronograma$ano[i]
  trim_c <- cronograma$trimestre[i]
  message(sprintf("=== Processando %dT%d (%d de %d) ===", ano_c, trim_c, i, nrow(cronograma)))
  
  design_trimestre <- tryCatch(
    preparar_desenho(ano_c, trim_c),
    error = function(e) {
      message("  !!! Erro ao baixar/preparar ", ano_c, "T", trim_c, ": ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(design_trimestre)) next
  
  design_pi <- design_trimestre[design_trimestre$variables$UF == "Piauí", ]
  
  # Cache do desenho de Piauí (com as variáveis derivadas) pro script de
  # testes de significância reaproveitar sem precisar baixar de novo.
  saveRDS(design_pi, sprintf("data/raw/pi_%d_%d.rds", ano_c, trim_c))
  
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
  
  linhas_trimestre <- list()
  falhas_trimestre <- list()
  
  for (geo_nome in names(lista_geografias)) {
    design_geo <- lista_geografias[[geo_nome]]
    if (nrow(design_geo) == 0) next
    
    recortes_desta_geo <- if (geo_nome %in% geografias_agregadas) {
      "Total"
    } else {
      names(recortes_demograficos)
    }
    
    for (recorte_nome in recortes_desta_geo) {
      by_formula <- recortes_demograficos[[recorte_nome]]
      
      for (spec in catalogo_indicadores) {
        
        # Indicadores com by_override (ex.: Rendimento_por_Formalidade) usam
        # seu próprio cruzamento em vez do recorte demográfico da passada, e
        # só rodam uma vez por geografia (na passada "Total") pra não sair
        # repetido em Sexo/Faixa_Etaria_trabalho/Instrucao.
        if (isTRUE(spec$so_recorte_total) && recorte_nome != "Total") next
        
        by_usar       <- if (!is.null(spec$by_override)) spec$by_override else by_formula
        recorte_saida <- if (!is.null(spec$by_override)) "Formalidade" else recorte_nome
        
        message(sprintf("  %s | %s | %s", geo_nome, recorte_saida, spec$id))
        
        resultado <- tryCatch(
          computar_estimativa(design_geo, spec, by_usar),
          error = function(e) {
            falhas_trimestre[[length(falhas_trimestre) + 1]] <<- tibble(
              Ano = ano_c, Trimestre = trim_c, Regiao_Geografica = geo_nome,
              Recorte_Demografico = recorte_saida, Indicador = spec$id,
              Erro = conditionMessage(e)
            )
            NULL
          }
        )
        if (is.null(resultado)) next
        
        linha <- tryCatch(
          extrair_resultados(resultado, spec$id, tem_by = !is.null(by_usar)) %>%
            mutate(Ano = ano_c, Trimestre = trim_c, Regiao_Geografica = geo_nome,
                   Recorte_Demografico = recorte_saida),
          error = function(e) {
            falhas_trimestre[[length(falhas_trimestre) + 1]] <<- tibble(
              Ano = ano_c, Trimestre = trim_c, Regiao_Geografica = geo_nome,
              Recorte_Demografico = recorte_saida, Indicador = spec$id,
              Erro = paste("Falha ao extrair resultado:", conditionMessage(e))
            )
            NULL
          }
        )
        if (!is.null(linha)) linhas_trimestre[[length(linhas_trimestre) + 1]] <- linha
      }
    }
  }
  
  df_trimestre <- bind_rows(linhas_trimestre) %>%
    select(Indicador, Subcategoria_Indicador, Estimativa, SE, Ano, Trimestre,
           Regiao_Geografica, Recorte_Demografico, Categoria_Demografica)
  
  write_csv(df_trimestre, arquivo_saida, append = file.exists(arquivo_saida))
  
  if (length(falhas_trimestre) > 0) {
    df_falhas <- bind_rows(falhas_trimestre)
    write_csv(df_falhas, arquivo_log, append = file.exists(arquivo_log))
    message("  -> ", nrow(df_falhas), " falha(s) neste trimestre (ver ", arquivo_log, ")")
  }
  
  message("  -> ", nrow(df_trimestre), " linhas gravadas para ", ano_c, "T", trim_c)
  
  rm(design_trimestre, design_pi, lista_geografias)
  gc()
}

message("Concluído.")