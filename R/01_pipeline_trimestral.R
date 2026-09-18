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
source("R/derivar_variaveis.R", encoding = "UTF-8")

# ---- 2. Download e variáveis derivadas --------------------------------------

# Cache em data/raw/pnadc_br_<ano>_<tri>.rds (R/01a_cache_pnadc.R): só baixa
# do FTP do IBGE se o arquivo do trimestre ainda não existir.
source("R/01a_cache_pnadc.R", encoding = "UTF-8")
message("Carregando PNADC ", sufixo, "...")
dados_brutos <- carregar_pnadc(ANO_REF, TRIMESTRE_REF)

# Variáveis derivadas: R/derivar_variaveis.R (fonte única, também usada na
# validação contra o SIDRA). Já devolve o desenho com convey_prep() aplicado.
dados_brutos <- derivar_variaveis(dados_brutos, sm_hora = sm_hora_corrente)

design_trimestre <- dados_brutos
design_pi <- design_trimestre[design_trimestre$variables$UF == "Piauí", ]

# Crosswalk Estrato -> Zona/Estrato_Admin/Estrato_agregado/Situacao — é a
# classificação já validada aqui em cima, exportada pra qualquer script à
# parte (ex.: de mapa) poder colorir o polígono do IBGE sem precisar
# redescobrir/duplicar essas regras.
crosswalk_trimestre <- distinct(design_pi$variables, Estrato, Zona,
                                Estrato_Admin, Estrato_agregado, Situacao)

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
# catalogo_indicadores e recortes_demograficos ficam em R/indicadores.R — o
# mesmo arquivo usado pela validação contra o SIDRA (scripts_teste/validacao_sidra.R).

source("R/indicadores.R", encoding = "UTF-8")

# geografias_agregadas vem do R/00_config.R

# ---- 4. Geografias -----------------------------------------------------------
# montar_geografias() e estimar_trimestre() vêm do R/indicadores.R — o mesmo
# motor usado pela série de confiabilidade (R/10_serie_confiabilidade.R).

lista_geografias <- montar_geografias(design_trimestre, design_pi)
geografias_finas <- setdiff(names(lista_geografias), geografias_agregadas)

# ---- 5/6. Indicadores e desigualdade formal/informal ---------------------------

res_trimestre  <- estimar_trimestre(lista_geografias, geografias_agregadas,
                                    ANO_REF, TRIMESTRE_REF)
base_trimestre <- res_trimestre$base
desigualdade   <- res_trimestre$desigualdade
falhas         <- res_trimestre$falhas

if (nrow(desigualdade) > 0) {
  write_csv(desigualdade,
            sprintf("output/desigualdade_formal_informal_%s.csv", sufixo))
  message("  -> ", nrow(desigualdade), " geografia(s) com razão formal/informal")
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
    # Totais, composição da PIT e Gini ficam fora dos testes (ver R/indicadores.R).
    if (isFALSE(spec$testar)) next
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
  "Situacao"               = "Situacao",
  "Estrato_Administrativo" = "Estrato_Admin",
  "Estrato_Agregado"       = "Estrato_agregado",
  "Estrato_Micro"          = "Estrato",
  "Teresina_x_Resto_Piaui" = "Teresina_Resto"
)

message("Rodando testes de significância regionais...")
linhas_regional <- list()
falhas_regional <- list()

for (spec in catalogo_indicadores) {
  if (isFALSE(spec$testar)) next
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
      str_starts(Regiao_Geografica, "Zona_")     ~ "Zona",
      str_starts(Regiao_Geografica, "Situacao_") ~ "Situacao",
      str_starts(Regiao_Geografica, "Admin_")    ~ "Administrativo",
      str_starts(Regiao_Geografica, "Agreg_")    ~ "Agregado_Geografico",
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