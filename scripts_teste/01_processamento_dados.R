# ==============================================================================
# SCRIPT 1: PROCESSAMENTO COMPLETO DA SÉRIE HISTÓRICA PNADc (4T2015 a 2T2026)
# ==============================================================================

library(PNADcIBGE)
library(survey)
library(dplyr)
library(tidyr)
library(purrr)
library(readr)

if(!dir.exists("dados_saida")) dir.create("dados_saida")

# 1. Vetor de Salários Mínimos por Ano (Conversão aproximada para Valor/Hora Comercial: SM / 220 horas)
# Fonte histórica de 2015 a 2026 para automatizar a variável 'subremuneracao'
tabela_salario_minimo <- data.frame(
  ano = c(2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026),
  sm_hora = c(3.58, 4.00, 4.26, 4.34, 4.54, 4.75, 5.00, 5.51, 6.00, 6.42, 6.87, 7.37) # Valores de referência por hora
)

# 2. Geração Dinâmica do Cronograma (4T2015 até 2T2026)
cronograma <- data.frame(ano = 2015:2026) %>%
  crossing(trimestre = 1:4) %>%
  filter(
    (ano == 2015 & trimestre == 4) | 
      (ano > 2015 & ano < 2026) | 
      (ano == 2026 & trimestre %in% 1:2)
  ) %>%
  arrange(ano, trimestre)

# 3. Função de Extração e Customização de Variáveis
processar_dados_pnadc <- function(ano_ref, trimestre_ref) {

  # Captura o salário mínimo por hora dinamicamente para o ano corrente
  sm_hora_corrente <- tabela_salario_minimo %>% 
    filter(ano == ano_ref) %>% 
    pull(sm_hora)
  
  # Mudar pra testar uma volta no loop
  dados_brutos <- get_pnadc(year = ano_ref, quarter = trimestre_ref)
  
  dados_brutos[['variables']] <- dados_brutos[['variables']] %>%
    mutate(
      # Estruturação Geográfica e Filtros
      Regiao = ifelse(UF %in% c('Piauí', 'Maranhão', 'Ceará', 'Rio Grade do Norte', 'Paraíba', 'Pernambco', 'Bahia', 'Alagoas', 'Sergipe'),
                          "Nordeste", "Resto do Brasil"),
      UF_Nome = ifelse(UF == "Piauí", "Piauí", 'Outro'),
      Teresina_Flag = ifelse(Estrato %in% 2210011:2210030, "Teresina", "Interior/Outros"),
      
      Estrato_agregado = factor(case_match(as.integer(Estrato),
                                           2210011:2210030 ~ "Teresina",
                                           2220010:2220020 ~ "Entorno metropolitano de Teresina (PI)",
                                           2251011:2251022 ~ "Centro-Leste do Piauí",
                                           2252011:2252022 ~ "Baixo Parnaíba do Piauí",
                                           2253010:2254020 ~ "Alto Parnaíba e Chapadas Sul do Piauí",
                                           .default = "Fora do Escopo")),
      
      Zona = factor(V1022, labels = c("Urbana", "Rural")),
      Estrato_Admin = V1023,
      
      # Recortes Demográficos
      Sexo = factor(V2007, labels = c("Masculino", "Feminino")),
      Faixa_Etaria_trabalho = case_match(V2009, 14:29 ~ "Jovens", 30:64 ~ "Adulto", 65:130 ~ "Idoso", .default = NA_character_),
      Instrucao = VD3004,
      
      # Definição do Setor Privado CLT e Não CLT
      formal_setor_privado = factor(case_match(VD4009,
                                               "Empregado no setor privado com carteira de trabalho assinada" ~ 1,
                                               "Empregado no setor privado sem carteira de trabalho assinada" ~ 0)),
      
      # Regras e Denominadores de Suporte
      anos_estudos_11_ou_mais = factor(case_match(VD3005, 
                                                  c("11 anos de estudo", "12 anos de estudo", "13 anos de estudo", 
                                                    "14 anos de estudo", "15 anos de estudo", "16 anos ou mais de estudo") ~ 1, 
                                                  .default = 0)),
      
      ft_ou_desalentada = as.numeric((!is.na(VD4001) & VD4001 == "Pessoas na força de trabalho") | (!is.na(VD4005) & VD4005 == "Pessoas desalentadas")),
      
      # Variáveis de Renda Ajustadas pelo Mínimo Anual Ponderado
      valor_hora = (VD4019 / (5 * VD4031)),
      subremuneracao = as.numeric(valor_hora < sm_hora_corrente), 
      
      # Definição SIDRA de Informais
      informal = as.numeric(
        (!is.na(VD4009) & VD4009 == "Empregado no setor privado sem carteira de trabalho assinada") | 
          (!is.na(VD4009) & VD4009 == "Trabalhador doméstico sem carteira de trabalho assinada") | 
          (!is.na(VD4009) & VD4009 == "Trabalhador familiar auxiliar") |
          ((!is.na(VD4009) & VD4009 == "Empregador") & (!is.na(V4019) & V4019 == "Não")) |
          ((!is.na(VD4009) & VD4009 == "Conta-própria") & (!is.na(V4019) & V4019 == "Não"))
      ),
      
      nem_nem = as.numeric((V2009 >= 14 & V2009 <= 29) & (!is.na(V3002) & V3002 == "Não") & (is.na(VD4002) | VD4002 != "Pessoas ocupadas"))
    )
  
  return(dados_brutos)
}

# 4. Função Auxiliar para Padronização e Achatamento de Outputs (Suporta taxas, médias e categóricas)
extrair_resultados <- function(obj_svy, ind_nome) {
  df <- as.data.frame(obj_svy)
  df$Subcategoria_Indicador <- rownames(df)
  df$Indicador <- ind_nome
  colnames(df)[1:2] <- c("Estimativa", "SE")
  rownames(df) <- NULL
  return(df %>% select(Indicador, Subcategoria_Indicador, Estimativa, SE))
}

# 5. Loop Consolidado da Série Histórica
acumulador_final <- list()

for (i in 1:nrow(cronograma)) {

  ano_c <- cronograma$ano[i]
  trim_c <- cronograma$trimestre[i]
  
  message(paste("Processando dados:", ano_c, "T", trim_c))
  
  design_trimestre <- tryCatch({
    processar_dados_pnadc(ano_c, trim_c)
  }, error = function(e) {
    message(paste("!!! Erro ao processar período:", ano_c, "T", trim_c, "- Pulando.")); return(NULL)
  })
  
  if(is.null(design_trimestre)) next
  
  # Estruturação Dinâmica de Todas as Geografias do Projeto
  design_pi <- subset(design_trimestre, UF == "Piauí")
  
  lista_geografias <- list(
    "Brasil" = design_trimestre,
    "Nordeste" = subset(design_trimestre, Regiao == "Nordeste"),
    "Piauí" = design_pi,
    "Teresina" = subset(design_pi, Teresina_Flag == "Teresina"),
    "Zona_Urbana" = subset(design_pi, Zona == "Urbana"),
    "Zona_Rural" = subset(design_pi, Zona == "Rural")
  )
  
  # Inclusão dos Estratos Administrativos e Agregados do PI
  estratos_admin <- unique(design_pi[['variables']]$Estrato_Admin); estratos_admin <- estratos_admin[!is.na(estratos_admin)]
  for(e in estratos_admin) lista_geografias[[paste0("Admin_", e)]] <- subset(design_pi, Estrato_Admin == e)
  
  estratos_agreg <- unique(design_pi[['variables']]$Estrato_agregado); estratos_agreg <- estratos_agreg[!is.na(estratos_agreg)]
  for(ea in estratos_agreg) lista_geografias[[paste0("Agreg_", ea)]] <- subset(design_pi, Estrato_agregado == ea)
  
  df_periodo <- data.frame()
  
  for (geo_nome in names(lista_geografias)) {
    design_geo <- lista_geografias[[geo_nome]]
    if(nrow(design_geo) == 0) next
    
    # Cruzamento com os 3 recortes demográficos finos + Célula Geral (Total)
    recortes_demograficos <- list(
      "Total" = data.frame(var = "Total", sub = "Total"),
      "Sexo" = data.frame(var = "Sexo", sub = unique(design_geo[['variables']]$Sexo)),
      "Faixa_Etaria_trabalho" = data.frame(var = "Faixa_Etaria_trabalho", sub = unique(design_geo[['variables']]$Faixa_Etaria_trabalho)),
      "Instrucao" = data.frame(var = "Instrucao", sub = unique(design_geo[['variables']]$Instrucao))
    )
    
    for (demo_nome in names(recortes_demograficos)) {
      subcategorias <- recortes_demograficos[[demo_nome]]
      subcategorias <- subcategorias[!is.na(subcategorias$sub), ]
      
      for (s_cat in subcategorias$sub) {
        message(paste("  Criando indices para:",geo_nome,'-', demo_nome, '-', s_cat))
        
        design_celula <- if(demo_nome == "Total") design_geo else subset(design_geo, design_geo[['variables']][[demo_nome]] == s_cat)
        if(nrow(design_celula) == 0) next
        
        res_celula <- list()
        
        # BLOCO DESOCUPADOS
        
        message(paste("    Começando Bloco de desocupados"))
        
        # 1. Taxa de Desocupação Tradicional
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svyratio(~VD4002 == "Pessoas desocupadas", ~VD4001 == "Pessoas na força de trabalho", design_celula, na.rm=T), "Taxa_Desocupacao") }, error = function(e) NULL)
        
        # 2. Percentual de Desocupados buscando emprego há 2 anos ou mais (V4076)
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svyratio(~V4076 == "2 anos ou mais", ~VD4002 == "Pessoas desocupadas", design_celula, na.rm=T), "Desocupados_Longa_Duracao") }, error = function(e) NULL)
        
        # 3. Proporção de Chefes de Família entre os Desocupados
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svyratio(~VD2002 == "Pessoa responsável", ~VD4002 == "Pessoas desocupadas", subset(design_celula, VD4002 == "Pessoas desocupadas"), na.rm=T), "Chefes_Familia_Desocupados") }, error = function(e) NULL)
        
        message(paste("    Começando Bloco de rendimentos"))
        
        # BLOCO RENDIMENTOS
        
        # 4. Rendimento Médio Habitual (VD4019)
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svymean(~VD4019, design_celula, na.rm=T), "Rendimento_Medio_Habitual") }, error = function(e) NULL)
        
        # 5. Percentual de Pessoas com Subremuneração (Abaixo do Mínimo/Hora Corrente)
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svymean(~subremuneracao, design_celula, na.rm=T), "Percentual_Subremuneracao") }, error = function(e) NULL)
        
        # 6. Desigualdade de Renda: Rendimento Médio por Setor Formal/Informal
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svymean(~VD4019, subset(design_celula, !is.na(formal_setor_privado)), na.rm=T), "Rendimento_por_Formalidade") }, error = function(e) NULL)
        
        message(paste("    Começando Bloco de inserção"))
        
        # BLOCO INSERÇÃO 
        
        # 7. Taxa de Informalidade Geral
        
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svyratio(~informal, ~VD4002 == "Pessoas ocupadas", design_celula, na.rm=T), "Taxa_Informalidade") }, error = function(e) NULL)
        # 8. Taxa de Subocupação por Insuficiência de Horas
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svyratio(~(!is.na(VD4004A) & VD4004A == "Pessoas subocupadas"), ~VD4002 == "Pessoas ocupadas", design_celula, na.rm=T), "Taxa_Subocupacao") }, error = function(e) NULL)
        
        # 9. Proporção Ocupados com 11 anos ou mais de Estudo
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svyratio(~(!is.na(anos_estudos_11_ou_mais) & anos_estudos_11_ou_mais == 1), ~VD4002 == "Pessoas ocupadas", design_celula, na.rm=T), "Proporcao_Ocupados_Escolarizados") }, error = function(e) NULL)
        
        message(paste("    Começando Bloco de desalentados"))
        # BLOCO DESALENTAOS
        
        # 10. Percentual de Desalentados (Sobre a Força Ampliada)
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svyratio(~(!is.na(VD4005) & VD4005 == "Pessoas desalentadas"), ~ft_ou_desalentada, design_celula, na.rm=T), "Desalentados_Forca_Ampliada") }, error = function(e) NULL)
        
        #11. Percentual de Desalentados (Sobre População Fora da Força)
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svyratio(~(!is.na(VD4005) & VD4005 == "Pessoas desalentadas"), ~VD4003, design_celula, na.rm=T), "Desalentados_Fora_Forca") }, error = function(e) NULL)
        
        # 12. Motivo de Desistência dos Desalentados (V4074A)
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svymean(~V4074A, design=subset(design_celula, VD4005 == "Pessoas desalentadas"), na.rm=T), "Motivo_Desistencia_Desalentado") }, error = function(e) NULL)
        
        message(paste("    Começando Bloco de Jovens nem-e-nem"))
        # BLOCO JOVENS NEM - E NEM
        
        #13. Taxa de Jovens Nem-Nem (14 a 29 anos)
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svyratio(~nem_nem, ~(V2009 >= 14 & V2009 <= 29), design_celula, na.rm=T), "Taxa_Nem_Nem") }, error = function(e) NULL)
        
        # 14. Motivo de não procurar emprego entre os Nem-Nem (V4074A)
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svymean(~V4074A, design=subset(design_celula, nem_nem == 1), na.rm=T), "Motivo_Nao_Procura_NemNem") }, error = function(e) NULL)
        #15. Motivo por não ter começado a trabalhar na semana de referência entre os Nem-Nem (V4078A)
        res_celula[[length(res_celula) + 1]] <- tryCatch({ extrair_resultados(svymean(~V4078A, design=subset(design_celula, nem_nem == 1), na.rm=T), "Motivo_Nao_Inicio_NemNem") }, error = function(e) NULL)
        
        message(paste("    Consolidando os resultados do recorte"))
        
        # Consolidação e gravação da célula amostral corrente
        df_celula <- bind_rows(res_celula)
        if(nrow(df_celula) > 0) {df_celula <- df_celula %>% 
          mutate(Ano = ano_c, Trimestre = trim_c, Regiao_Geografica = geo_nome,Recorte_Demografico = demo_nome, Categoria_Demografica = as.character(s_cat))
        df_periodo <- bind_rows(df_periodo, df_celula)
        }
      }
    }
  }
  message(paste("Consolidando os resultados do", ano_c, "T", trim_c))
  acumulador_final[[paste0(ano_c, "_", trim_c)]] <- df_periodorm(design_trimestre, design_pi, lista_geografias)
  gc()
}
