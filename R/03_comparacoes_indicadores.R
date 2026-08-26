# ==============================================================================
# 03_comparacoes_indicadores.R — tabelas e gráficos comparando o VALOR de
# cada indicador entre as categorias de cada tipo de desagregação, mais as
# tabelas/gráficos dos testes de significância (demográficos e regionais).
#
#   - Geográfica (Zona, Estrato administrativo, Estrato agregado, Agregados
#     nacionais): TABELA + GRÁFICO (estimativa ± IC 95% por categoria)
#   - Demográfica (Sexo, Faixa etária, Instrução): só TABELA, sem gráfico
#   - ANOVA demográfica e regional: TABELA + GRÁFICO dos dois
#
# Lê base_<trimestre>.csv + testes_significancia_<trimestre>.csv +
# testes_regionais_<trimestre>.csv (todos já prontos, gerados pelo
# pipeline_trimestre.R) — não recalcula nada, só organiza pra relatório.
# ==============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(purrr)
library(ggplot2)

# ANO_REF, TRIMESTRE_REF, sufixo e geografias_agregadas vêm do config
# compartilhado com o 01_pipeline_trimestral.R — antes estavam declarados nos dois
# arquivos, e esquecer de atualizar este aqui fazia o script reler a base do
# trimestre anterior sem reclamar de nada.
source("R/00_config.R")

# ==============================================================================
# NOMES PARA EXIBIÇÃO — mexe aqui se quiser mudar como um indicador/recorte
# aparece nas tabelas e gráficos. Qualquer coisa que não estiver nessas
# listas aparece com o nome original (não quebra se você adicionar um
# indicador novo e esquecer de nomear ele aqui).
# ==============================================================================

nomes_indicadores <- c(
  Taxa_Desocupacao                 = "Taxa de Desocupação",
  Chefes_Familia_Desocupados       = "Pessoas Responsáveis pelo Domicílio Desocupadas",
  # O identificador tem erro de digitação no pipeline (falta o "t" de
  # Contribuintes). Corrigi-lo lá renomearia arquivos de figura e quebraria
  # as referências do relatório, então o conserto fica no rótulo de exibição.
  Conribuintes_Desocupados         = "Responsáveis ou Cônjuges Desocupados",
  Rendimento_Medio_Habitual        = "Rendimento Médio Habitual",
  Percentual_Subremuneracao        = "Subremuneração (abaixo do salário-mínimo/hora)",
  Rendimento_Formal                = "Rendimento Médio — Setor Formal",
  Rendimento_Informal              = "Rendimento Médio — Setor Informal",
  Taxa_Informalidade               = "Taxa de Informalidade",
  Taxa_Subocupacao                 = "Subocupação por Insuficiência de Horas",
  Proporcao_Ocupados_Escolarizados = "Ocupados com Ensino Médio Completo ou Mais",
  Desalentados_Forca_Ampliada      = "Desalentados na Força de Trabalho Ampliada",
  Desalentados_Fora_Forca          = "Desalentados Fora da Força de Trabalho",
  Motivo_Desistencia_Desalentado   = "Motivo da Desistência (Desalentados)",
  Taxa_Nem_Nem                     = "Taxa de Nem-Nem (14 a 29 anos)",
  Motivo_Nao_Procura_NemNem        = "Motivo de Não Procurar Trabalho (Nem-Nem)",
  Motivo_Nao_Inicio_NemNem         = "Motivo de Não Iniciar Trabalho (Nem-Nem)",
  Desigualdade_Formal_Informal     = "Desigualdade — Razão Formal/Informal"
)

nomes_recortes <- c(
  Total                    = "Total",
  Sexo                     = "Sexo",
  Raca                     = "Cor ou Raça",
  Faixa_Etaria_trabalho    = "Faixa Etária",
  Instrucao                = "Grau de Instrução (detalhado)",
  Instrucao_agregado       = "Grau de Instrução (dicotomizado)",
  Zona                     = "Zona (Urbana/Rural)",
  Estrato_Administrativo   = "Estrato Administrativo",
  Estrato_Agregado         = "Estrato Agregado/Geográfico",
  Estrato_Micro            = "Estrato de 7 dígitos",
  Teresina_x_Resto_Piaui   = "Teresina x Resto do Piauí"
)

# Overrides manuais pros nomes de geografia que merecem um texto melhor do
# que a limpeza genérica sozinha daria — adiciona mais linhas aqui à
# vontade (ex.: se quiser escrever por extenso o nome de algum estrato).
nomes_geografias_manual <- c(
  Zona_Urbana = "Zona Urbana",
  Zona_Rural  = "Zona Rural"
)

# Limpeza genérica pro resto: tira o prefixo do tipo (Admin_/Agreg_/Zona_) e
# troca "_" por espaço — cobre qualquer categoria nova sem precisar mexer
# nessa lista à mão toda hora.
limpar_nome_geografia <- function(x) {
  x <- str_replace(x, "^(Admin_|Agreg_|Zona_)", "")
  str_replace_all(x, "_", " ")
}

nome_indicador <- function(x) unname(ifelse(x %in% names(nomes_indicadores), nomes_indicadores[x], x))
nome_recorte   <- function(x) unname(ifelse(x %in% names(nomes_recortes), nomes_recortes[x], x))
nome_geografia <- function(x) {
  manual <- nomes_geografias_manual[x]
  ifelse(!is.na(manual), unname(manual), limpar_nome_geografia(x))
}

# ==============================================================================
# CONFIABILIDADE PELO CV — o IBGE define CV < 15% como o corte de "boa
# precisão" pras estimativas amostrais da PNADC (documentado nas notas
# técnicas de calibração de pesos da pesquisa). Os cortes de 5% e 30% que
# você pediu seguem a mesma lógica graduada, prática comum em relatórios de
# estatísticas amostrais (o de 30% é o mais citado como limite de "não
# recomendado" fora do Brasil também, ex. convenções do Statistics Canada e
# do U.S. Census Bureau):
#   CV <  5%          -> Excelente (***)
#   5%  <= CV < 15%    -> Boa       (**)   [15% = corte oficial do IBGE]
#   15% <= CV < 30%    -> Regular   (*)
#   CV >= 30%          -> Baixa     (sem asterisco — usar com cautela)
# ==============================================================================

classificar_cv <- function(cv) {
  case_when(
    is.na(cv) ~ NA_character_,
    cv < 5    ~ "Excelente (***)",
    cv < 15   ~ "Boa (**)",
    cv < 30   ~ "Regular (*)",
    TRUE      ~ "Baixa"
  )
}

# Estrelas de significância pro p-valor das ANOVAs — convenção estatística
# padrão, NÃO confundir com os asteriscos de confiabilidade do CV acima
# (são duas coisas diferentes, por isso ficam em tabelas separadas: uma é
# "quão precisa é a estimativa", a outra é "a diferença entre grupos é
# estatisticamente significativa").
estrelas_p <- function(p) {
  case_when(
    is.na(p) ~ "",
    p < 0.001 ~ "***",
    p < 0.01  ~ "**",
    p < 0.05  ~ "*",
    TRUE      ~ "ns"
  )
}

# ==============================================================================
# PALETA DE CORES — fria/neutra (azuis, cinzas, preto), uma cor por
# geografia, consistente em todos os gráficos do relatório.
# ==============================================================================

gerar_paleta_fria <- function(categorias) {
  categorias <- sort(unique(categorias))
  cores <- colorRampPalette(c("#08306B", "#2171B5", "#6BAED6", "#969696", "#252525"))(length(categorias))
  setNames(cores, categorias)
}

# ==============================================================================
# Leitura dos dados já prontos
# ==============================================================================

base <- read_csv(sprintf("output/base_%s.csv", sufixo), show_col_types = FALSE)

caminho_testes_demo     <- sprintf("output/testes_significancia_%s.csv", sufixo)
caminho_testes_regional <- sprintf("output/testes_regionais_%s.csv", sufixo)
testes_demo     <- if (file.exists(caminho_testes_demo))     read_csv(caminho_testes_demo, show_col_types = FALSE)     else NULL
testes_regional <- if (file.exists(caminho_testes_regional)) read_csv(caminho_testes_regional, show_col_types = FALSE) else NULL

base <- base %>%
  mutate(
    CV     = ifelse(Estimativa != 0, abs(SE / Estimativa) * 100, NA_real_),
    IC_inf = Estimativa - 1.96 * SE,
    IC_sup = Estimativa + 1.96 * SE,
    IC_95  = sprintf("[%.3f — %.3f]", IC_inf, IC_sup),
    Confiabilidade = classificar_cv(CV),
    Tipo_Geo = case_when(
      Regiao_Geografica %in% geografias_agregadas ~ "Agregados nacionais",
      str_starts(Regiao_Geografica, "Zona_")  ~ "Zona",
      str_starts(Regiao_Geografica, "Admin_") ~ "Estrato administrativo",
      str_starts(Regiao_Geografica, "Agreg_") ~ "Estrato agregado",
      TRUE ~ "Outro"
    ),
    Indicador_Nome = nome_indicador(Indicador),
    Geografia_Nome = nome_geografia(Regiao_Geografica),
    Recorte_Nome   = nome_recorte(Recorte_Demografico)
  )

geografias_finas <- base %>%
  filter(!Regiao_Geografica %in% geografias_agregadas) %>%
  pull(Regiao_Geografica) %>% unique()

paleta_geo <- gerar_paleta_fria(base$Regiao_Geografica)

# ---- 1. Comparação geográfica (Recorte_Demografico == "Total") -------------

geo <- base %>% filter(Recorte_Demografico == "Total")

tabela_geo <- geo %>%
  select(Indicador, Indicador_Nome, Subcategoria_Indicador, Tipo_Geo,
         Regiao_Geografica, Geografia_Nome, Estimativa, SE, IC_95, IC_inf, IC_sup,
         CV, Confiabilidade) %>%
  arrange(Indicador, Tipo_Geo, Regiao_Geografica)
write_csv(tabela_geo, sprintf("output/tabelas/comparacao_geografica_%s.csv", sufixo))

combinacoes_geo <- geo %>% distinct(Indicador, Subcategoria_Indicador)

for (i in seq_len(nrow(combinacoes_geo))) {
  ind <- combinacoes_geo$Indicador[i]
  sub <- combinacoes_geo$Subcategoria_Indicador[i]
  
  d <- geo %>% filter(Indicador == ind, Subcategoria_Indicador == sub, Tipo_Geo != "Outro")
  if (n_distinct(d$Regiao_Geografica) < 2) next
  
  p <- ggplot(d, aes(x = reorder(Geografia_Nome, Estimativa), y = Estimativa, color = Regiao_Geografica)) +
    geom_pointrange(aes(ymin = IC_inf, ymax = IC_sup)) +
    scale_color_manual(values = paleta_geo, guide = "none") +
    coord_flip() +
    facet_wrap(~Tipo_Geo, scales = "free", ncol = 1) +  # empilhado na vertical, como pedido
    labs(title = paste0(nome_indicador(ind), if (sub != ind) paste0(" — ", sub) else ""),
         subtitle = paste0(sufixo, " · Ponto = estimativa; barra = intervalo de confiança de 95%"),
         x = NULL, y = "Estimativa") +
    theme_minimal(base_size = 9) +
    theme(strip.text = element_text(face = "bold"))
  
  nome_arq <- sprintf("output/figuras/comp_geo_%s.png", make.names(ind))
  ggsave(nome_arq, p, width = 8, height = 3 + 1.6 * n_distinct(d$Tipo_Geo), bg = "white")
}

message("Comparação geográfica: tabela + ", nrow(combinacoes_geo), " gráfico(s) salvos.")

# ---- 2. Comparação demográfica (Sexo / Faixa etária / Instrução) -----------
# Só tabela, sem gráfico — como combinado.

demo <- base %>% filter(Recorte_Demografico %in% c("Sexo", "Faixa_Etaria_trabalho", "Instrucao"))

tabela_demo <- demo %>%
  select(Indicador, Indicador_Nome, Subcategoria_Indicador, Regiao_Geografica, Geografia_Nome,
         Recorte_Demografico, Recorte_Nome, Categoria_Demografica,
         Estimativa, SE, IC_95, IC_inf, IC_sup, CV, Confiabilidade)
# p_valor, p_ajustado e as duas colunas de significância são anexados logo abaixo

if (!is.null(testes_demo)) {

  # Prepara o de-para dos testes ANTES do join. Se o pipeline que gerou o
  # arquivo for anterior ao ajuste de multiplicidade, a coluna p_ajustado não
  # existe — cria-se vazia para o restante do script não precisar saber disso.
  chaves_testes_demo <- testes_demo %>%
    select(Indicador, Regiao_Geografica, Recorte_Demografico,
           p_valor, any_of("p_ajustado")) %>%
    distinct()
  if (!"p_ajustado" %in% names(chaves_testes_demo)) {
    chaves_testes_demo$p_ajustado <- NA_real_
  }

  tabela_demo <- tabela_demo %>%
    left_join(chaves_testes_demo,
              by = c("Indicador", "Regiao_Geografica", "Recorte_Demografico")) %>%
    mutate(
      Significancia = estrelas_p(p_valor),
      # o ajustado é o que decide o que entra no corpo do relatório; o bruto
      # fica na tabela para quem quiser conferir
      Significancia_ajustada = estrelas_p(p_ajustado)
    )
} else {
  tabela_demo$p_valor <- NA_real_
  tabela_demo$Significancia <- ""
  message("Aviso: ", caminho_testes_demo, " não encontrado — tabela demográfica sai sem p-valor.")
}

tabela_demo <- tabela_demo %>% arrange(Indicador, Recorte_Demografico, Regiao_Geografica)
write_csv(tabela_demo, sprintf("output/tabelas/comparacao_demografica_%s.csv", sufixo))

message("Comparação demográfica: só tabela — ", nrow(tabela_demo), " linhas.")

# ==============================================================================
# 3. ANOVA — tabelas e gráficos
# ==============================================================================

# ---- 3a. ANOVA demográfica (dentro de cada geografia fina) -----------------

if (!is.null(testes_demo)) {
  
  tabela_anova_demo <- testes_demo %>%
    mutate(
      Indicador_Nome = nome_indicador(Indicador),
      Geografia_Nome = nome_geografia(Regiao_Geografica),
      Recorte_Nome   = nome_recorte(Recorte_Demografico),
      Significancia  = estrelas_p(p_valor),
      Significancia_ajustada = if ("p_ajustado" %in% names(testes_demo))
        estrelas_p(p_ajustado) else NA_character_
    ) %>%
    # Variavel_Testada explicita QUAL coluna sustentou o teste — o nome do
    # recorte e a variável não coincidem em Instrucao/Instrucao_agregado.
    # any_of() mantém compatibilidade com bases de trimestres anteriores.
    select(Indicador, Indicador_Nome, Regiao_Geografica, Geografia_Nome,
           Recorte_Demografico, Recorte_Nome,
           any_of("Variavel_Testada"),
           Metodo, Estatistica, GL,
           p_valor, Significancia, any_of(c("p_ajustado", "Significancia_ajustada")), N) %>%
    arrange(p_valor)
  write_csv(tabela_anova_demo, sprintf("output/tabelas/anova_demografica_%s.csv", sufixo))
  
  d <- tabela_anova_demo %>% filter(!is.na(p_valor))
  p_anova_demo <- ggplot(d, aes(x = reorder(paste(Indicador_Nome, Geografia_Nome), -p_valor),
                                y = p_valor, color = p_valor < 0.05)) +
    geom_point(size = 1.6) +
    geom_hline(yintercept = 0.05, linetype = "dashed", color = "#252525") +
    coord_flip() +
    facet_wrap(~Recorte_Nome, ncol = 1, scales = "free_y") +  # empilhado na vertical
    scale_color_manual(values = c("TRUE" = "#08306B", "FALSE" = "#BDBDBD"), guide = "none") +
    labs(title = paste("ANOVA demográfica —", sufixo),
         subtitle = "Cada ponto: indicador x geografia. Azul = diferença significativa (p < 0,05). Linha tracejada: p = 0,05.",
         x = NULL, y = "p-valor") +
    theme_minimal(base_size = 7) +
    theme(strip.text = element_text(face = "bold"), axis.text.y = element_text(size = 5))
  ggsave(sprintf("output/figuras/anova_demografica_%s.png", sufixo), p_anova_demo,
         width = 9, height = 4 + 2.2 * n_distinct(d$Recorte_Nome), bg = "white")
  
  message("ANOVA demográfica: tabela + gráfico salvos (", nrow(tabela_anova_demo), " testes).")
} else {
  message("Aviso: sem testes_significancia_", sufixo, ".csv — pulando ANOVA demográfica.")
}

# ---- 3b. ANOVA regional (entre categorias de um mesmo recorte regional) ----

if (!is.null(testes_regional)) {
  
  tabela_anova_regional <- testes_regional %>%
    mutate(
      Indicador_Nome = nome_indicador(Indicador),
      Recorte_Nome    = nome_recorte(Recorte_Regional),
      Significancia   = estrelas_p(p_valor),
      Significancia_ajustada = if ("p_ajustado" %in% names(testes_regional))
        estrelas_p(p_ajustado) else NA_character_
    ) %>%
    select(Indicador, Indicador_Nome, Recorte_Regional, Recorte_Nome,
           any_of("Variavel_Testada"),
           Metodo, Estatistica, GL, p_valor, Significancia,
           any_of(c("p_ajustado", "Significancia_ajustada")), N) %>%
    arrange(p_valor)
  write_csv(tabela_anova_regional, sprintf("output/tabelas/anova_regional_%s.csv", sufixo))
  
  d <- tabela_anova_regional %>% filter(!is.na(p_valor))
  p_anova_regional <- ggplot(d, aes(x = reorder(Indicador_Nome, -p_valor), y = p_valor,
                                    color = p_valor < 0.05)) +
    geom_point(size = 2) +
    geom_hline(yintercept = 0.05, linetype = "dashed", color = "#252525") +
    coord_flip() +
    facet_wrap(~Recorte_Nome, ncol = 1, scales = "free_y") +  # empilhado na vertical
    scale_color_manual(values = c("TRUE" = "#08306B", "FALSE" = "#BDBDBD"), guide = "none") +
    labs(title = paste("ANOVA regional —", sufixo),
         subtitle = "Azul = diferença significativa entre as categorias regionais (p < 0,05). Linha tracejada: p = 0,05.",
         x = NULL, y = "p-valor") +
    theme_minimal(base_size = 8) +
    theme(strip.text = element_text(face = "bold"))
  ggsave(sprintf("output/figuras/anova_regional_%s.png", sufixo), p_anova_regional,
         width = 8, height = 3 + 2.4 * n_distinct(d$Recorte_Nome), bg = "white")
  
  message("ANOVA regional: tabela + gráfico salvos (", nrow(tabela_anova_regional), " testes).")
} else {
  message("Aviso: sem testes_regionais_", sufixo, ".csv — pulando ANOVA regional.")
}

message("Concluído: tabelas em output/tabelas/, gráficos em output/figuras/")