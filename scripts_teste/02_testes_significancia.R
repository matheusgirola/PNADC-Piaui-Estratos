# ==============================================================================
# 02_testes_significancia.R — testa se as médias/proporções diferem entre as
# categorias de cada recorte demográfico (Sexo, Faixa_Etaria_trabalho,
# Instrucao), dentro de cada um dos estratos finos do Piauí.
#
# Só faz sentido testar onde existe mais de um grupo pra comparar — por isso
# este script cobre SÓ Zona_Urbana/Rural, Admin_* e Agreg_* (os mesmos que
# recebem recorte demográfico no 01_run.R). Brasil/Nordeste/Piauí/Teresina
# ficam de fora: lá só existe a categoria "Total", não há o que comparar.
#
# Método (rigor amostral, conforme combinado): svyglm() + regTermTest() pra
# variáveis binárias/contínuas (taxas e rendimento — o teste é o análogo,
# no desenho complexo, de uma ANOVA/teste F); svychisq() pra indicadores
# cuja resposta é uma categórica com mais de 2 níveis (os "Motivo_*").
#
# Lê os .rds cacheados pelo 01_run.R em data/raw/pi_<ano>_<trimestre>.rds —
# não baixa nada de novo. Roda só sobre os trimestres que já foram
# processados por lá.
#
# ATENÇÃO — um ponto que eu não consegui validar sem rodar: o nome exato do
# campo de p-valor dentro do objeto que regTermTest() devolve. Pela
# documentação do pacote survey eu tenho bastante confiança que é `$p`, e
# botei um fallback tentando `$p.value` também, mas se a coluna p_valor sair
# NA pra TODAS as linhas de método "svyglm+regTermTest" (e não só pras que
# falharam), é esse o primeiro lugar a olhar — me manda o log que eu ajusto.
# ==============================================================================

library(survey)
library(dplyr)
library(purrr)
library(readr)
library(tibble)
library(stringr)

dir.create("output", recursive = TRUE, showWarnings = FALSE)

arquivo_saida <- "output/testes_significancia.csv"
arquivo_log   <- "output/log_falhas_testes.csv"

# ---- 1. Catálogo de indicadores ---------------------------------------------
# Mesma definição do 01_run.R (mantida em sincronia manualmente por enquanto
# — se você pedir pra mexer num indicador, é preciso replicar a mudança nos
# dois scripts; posso juntar isso num arquivo só compartilhado se preferir).

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

recortes_demograficos <- c("Sexo", "Faixa_Etaria_trabalho", "Instrucao")

# ---- 2. Funções auxiliares --------------------------------------------------

aplicar_subset <- function(design, condicao) {
  if (is.null(condicao)) return(design)
  idx <- as.logical(eval(condicao[[2]], envir = design$variables))
  idx[is.na(idx)] <- FALSE
  design[idx, ]
}

# Pega o p-valor de regTermTest() tentando os nomes de campo mais prováveis
# (ver aviso no topo do arquivo).
extrair_p_valor <- function(teste) {
  for (campo in c("p", "p.value")) {
    if (!is.null(teste[[campo]])) return(as.numeric(teste[[campo]])[1])
  }
  NA_real_
}

# Roda o teste de associação entre a resposta do indicador e uma variável de
# recorte, dentro do design já restrito à população elegível. Decide
# automaticamente entre svyglm+regTermTest (resposta binária/contínua) e
# svychisq (resposta categórica com 3+ níveis, como os "Motivo_*").
rodar_teste <- function(design_geo, spec, var_recorte) {
  
  design_usar <- aplicar_subset(design_geo, spec$subset)
  if (identical(spec$fun, svyratio) && !is.null(spec$denominador)) {
    design_usar <- aplicar_subset(design_usar, spec$denominador)
  }
  if (nrow(design_usar) == 0) return(NULL)
  
  design_usar$variables[[var_recorte]] <- droplevels(as.factor(design_usar$variables[[var_recorte]]))
  if (nlevels(design_usar$variables[[var_recorte]]) < 2) return(NULL)
  
  resposta <- eval(spec$formula[[2]], envir = design_usar$variables)
  
  if (is.factor(resposta) || is.character(resposta)) {
    # resposta categórica com várias categorias (os indicadores de motivo) —
    # teste de associação ajustado ao desenho, não faz sentido um svyglm
    # binário aqui.
    design_usar$variables$.resposta <- droplevels(factor(resposta))
    if (nlevels(design_usar$variables$.resposta) < 2) return(NULL)
    
    formula_teste <- as.formula(paste0("~.resposta + ", var_recorte))
    teste <- tryCatch(svychisq(formula_teste, design = design_usar), error = function(e) e)
    if (inherits(teste, "error")) return(list(erro = conditionMessage(teste)))
    
    return(list(
      metodo = "svychisq", estatistica = unname(teste$statistic[1]),
      gl = paste(teste$parameter, collapse = ", "), p_valor = teste$p.value,
      n = nrow(design_usar)
    ))
  }
  
  design_usar$variables$.resposta <- as.numeric(resposta)
  valores <- unique(na.omit(design_usar$variables$.resposta))
  if (length(valores) < 2) return(NULL)
  familia <- if (all(valores %in% c(0, 1))) quasibinomial() else gaussian()
  
  formula_modelo <- as.formula(paste0(".resposta ~ ", var_recorte))
  modelo <- tryCatch(svyglm(formula_modelo, design = design_usar, family = familia),
                     error = function(e) e)
  if (inherits(modelo, "error")) return(list(erro = conditionMessage(modelo)))
  
  teste <- tryCatch(regTermTest(modelo, as.formula(paste0("~", var_recorte))),
                    error = function(e) e)
  if (inherits(teste, "error")) return(list(erro = conditionMessage(teste)))
  
  list(
    metodo = "svyglm+regTermTest",
    estatistica = unname(if (!is.null(teste$Ftest)) teste$Ftest[1] else teste$chisq[1]),
    gl = paste(unlist(teste[c("df", "ddf")]), collapse = ", "),
    p_valor = extrair_p_valor(teste),
    n = nrow(design_usar)
  )
}

# Reconstrói só as geografias finas (as que recebem recorte demográfico) a
# partir do design_pi cacheado — mesma lógica do 01_run.R.
construir_geografias_finas <- function(design_pi) {
  lista <- list(
    "Zona_Urbana" = subset(design_pi, Zona == "Urbana"),
    "Zona_Rural"  = subset(design_pi, Zona == "Rural")
  )
  
  estratos_admin <- unique(design_pi$variables$Estrato_Admin)
  estratos_admin <- estratos_admin[!is.na(estratos_admin)]
  for (e in estratos_admin) {
    lista[[paste0("Admin_", e)]] <- subset(design_pi, Estrato_Admin == e)
  }
  
  estratos_agreg <- unique(design_pi$variables$Estrato_agregado)
  estratos_agreg <- estratos_agreg[!is.na(estratos_agreg)]
  for (ea in estratos_agreg) {
    lista[[paste0("Agreg_", ea)]] <- subset(design_pi, Estrato_agregado == ea)
  }
  
  lista
}

# ---- 3. Trimestres já cacheados pelo 01_run.R -------------------------------

arquivos_rds <- list.files("data/raw", pattern = "^pi_\\d{4}_\\d\\.rds$", full.names = TRUE)
if (length(arquivos_rds) == 0) {
  stop("Nenhum .rds encontrado em data/raw/. Rode o 01_run.R primeiro.")
}

info_trimestres <- tibble(arquivo = arquivos_rds) %>%
  mutate(
    base   = basename(arquivo),
    ano    = as.integer(str_match(base, "^pi_(\\d{4})_(\\d)\\.rds$")[, 2]),
    trimestre = as.integer(str_match(base, "^pi_(\\d{4})_(\\d)\\.rds$")[, 3])
  ) %>%
  arrange(desc(ano), desc(trimestre))

if (file.exists(arquivo_saida)) {
  ja_feito <- read_csv(arquivo_saida, col_select = c(Ano, Trimestre),
                       show_col_types = FALSE) %>%
    distinct()
  antes <- nrow(info_trimestres)
  info_trimestres <- info_trimestres %>%
    anti_join(ja_feito, by = c("ano" = "Ano", "trimestre" = "Trimestre"))
  if (nrow(info_trimestres) < antes) {
    message(">>> Retomando: ", antes - nrow(info_trimestres),
            " trimestre(s) já estavam no CSV de saída e foram pulados.")
  }
}

# ---- 4. Loop principal -------------------------------------------------------

for (i in seq_len(nrow(info_trimestres))) {
  
  ano_c  <- info_trimestres$ano[i]
  trim_c <- info_trimestres$trimestre[i]
  message(sprintf("=== Testes: %dT%d (%d de %d) ===", ano_c, trim_c, i, nrow(info_trimestres)))
  
  design_pi <- readRDS(info_trimestres$arquivo[i])
  lista_geografias <- construir_geografias_finas(design_pi)
  
  linhas_trimestre <- list()
  falhas_trimestre <- list()
  
  for (geo_nome in names(lista_geografias)) {
    design_geo <- lista_geografias[[geo_nome]]
    if (nrow(design_geo) == 0) next
    
    for (spec in catalogo_indicadores) {
      
      recortes_a_testar <- if (!is.null(spec$by_override)) {
        all.vars(spec$by_override)
      } else {
        recortes_demograficos
      }
      
      for (var_recorte in recortes_a_testar) {
        message(sprintf("  %s | %s | %s", geo_nome, var_recorte, spec$id))
        
        resultado <- tryCatch(
          rodar_teste(design_geo, spec, var_recorte),
          error = function(e) list(erro = conditionMessage(e))
        )
        
        if (is.null(resultado)) next  # sem grupos suficientes pra testar, sem erro
        
        if (!is.null(resultado$erro)) {
          falhas_trimestre[[length(falhas_trimestre) + 1]] <- tibble(
            Ano = ano_c, Trimestre = trim_c, Regiao_Geografica = geo_nome,
            Recorte_Demografico = var_recorte, Indicador = spec$id,
            Erro = resultado$erro
          )
          next
        }
        
        linhas_trimestre[[length(linhas_trimestre) + 1]] <- tibble(
          Indicador = spec$id, Regiao_Geografica = geo_nome,
          Recorte_Demografico = var_recorte, Metodo = resultado$metodo,
          Estatistica = resultado$estatistica, GL = resultado$gl,
          p_valor = resultado$p_valor, N = resultado$n,
          Ano = ano_c, Trimestre = trim_c
        )
      }
    }
  }
  
  df_trimestre <- bind_rows(linhas_trimestre)
  write_csv(df_trimestre, arquivo_saida, append = file.exists(arquivo_saida))
  
  if (length(falhas_trimestre) > 0) {
    df_falhas <- bind_rows(falhas_trimestre)
    write_csv(df_falhas, arquivo_log, append = file.exists(arquivo_log))
    message("  -> ", nrow(df_falhas), " falha(s) neste trimestre (ver ", arquivo_log, ")")
  }
  
  message("  -> ", nrow(df_trimestre), " testes gravados para ", ano_c, "T", trim_c)
  
  rm(design_pi, lista_geografias)
  gc()
}

message("Concluído.")