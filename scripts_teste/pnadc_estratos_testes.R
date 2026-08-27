library(PNADcIBGE)
library(survey)
library(dplyr)
library(magrittr)
library(stringr)
library(ggsurvey)
library(tidyr)

# Aqui você seleciona o ano, ele é um parametro pra função logo abaixo  que puxa os dados
ANO = 2026

dadosPNADc <- get_pnadc(year=ANO, quarter = 2)

# Aqui eu criei uma variável nova, pra fazer as faixas etárias pois ela não vem criada
dadosPNADc[['variables']][['Faixa_Etaria_trabalho']] = case_match(dadosPNADc[["variables"]][["V2009"]],
                                                                  14:29 ~ "Jovens",
                                                                  30:64 ~ "Adulto",
                                                                  65:130 ~ "Idoso")

# Referencia: https://metadadosgeo.ibge.gov.br/geonetwork_ibge/srv/por/catalog.search#/metadata/3c2a67bd-fe50-49aa-823d-ba9636d4d23c
dadosPNADc[['variables']][['Estrato_agregado']] = factor(case_match(as.integer(dadosPNADc[["variables"]][["Estrato"]]),
                                                                    2210011:2210030 ~ "Teresina",
                                                                    2220010:2220020 ~ "Entorno metropolitano de Teresina (PI)",
                                                                    2251011:2251022 ~ "Centro-Leste do Piauí",
                                                                    2252011:2252022 ~ "Baixo Parnaíba do Piauí",
                                                                    2253010:2254020 ~ "Alto Parnaíba e Chapadas Sul do Piauí"))

dadosPNADc[['variables']][['formal_setor_privado']] = factor(case_match(dadosPNADc[["variables"]][["VD4009"]],
                                                                        "Empregado no setor privado com carteira de trabalho assinada" ~1,
                                                                        "Empregado no setor privado sem carteira de trabalho assinada"~0))

dadosPNADc[['variables']][['anos_estudos_11_ou_mais']] = factor(case_match(dadosPNADc[["variables"]][["VD3005"]],
                                                                           "11 anos de estudo" ~1,
                                                                           "12 anos de estudo" ~1,
                                                                           "13 anos de estudo" ~1,
                                                                           "14 anos de estudo" ~1,
                                                                           "15 anos de estudo" ~1,
                                                                           "16 anos ou mais de estudo" ~1))

#na PNAD Contínua é uma regra de exclusão mútua das próprias variáveis do IBGE: 
#A variável VD4002 ("Pessoas desocupadas") só é preenchida para quem está na força de trabalho 
#(VD4001 == "Pessoas na força de trabalho").Quem está fora da força de trabalho (VD4003) tem a variável 
#VD4002 como NA (Não aplicável).Quando você faz um teste lógico simples como VD4002 == "Pessoas desocupadas", 
#o R retorna NA para todas as pessoas que estão fora da força. Ao juntar tudo com o operador | (OR), 
#a presença desses NA faz com que toda a sua expressão vire NA. Como o parâmetro na.rm = TRUE removeu essas linhas, 
#você acabou calculando a razão apenas em um subconjunto onde o numerador e o denominador são exatamente iguais


# 1. Preparar o design com variaveis combinadas tratando os NAs de forma segura
dados_processados <- dadosPNADc %>%
  subset(UF == 'Piauí') %>%
  update(
    # Desocupados OU Força Potencial
    desocup_ou_ftp = as.numeric(
      (!is.na(VD4002) & VD4002 == "Pessoas desocupadas") | 
        (!is.na(VD4003) & VD4003 == "Pessoas fora da força de trabalho e na força de trabalho potencial")
    ),
    
    Regiao = ifelse(UF %in% c('Piauí', 'Maranhão', 'Ceará', 'Rio Grade do Norte', 'Paraíba', 'Pernambco', 'Bahia', 'Alagoas', 'Sergipe'),
                    "Nordeste", "Resto do Brasil"),
    
    # Desocupados OU Subocupados
    desocup_ou_subocup = as.numeric(
      (!is.na(VD4002) & VD4002 == "Pessoas desocupadas") | 
        (!is.na(VD4004A) & VD4004A == "Pessoas subocupadas")
    ),
    
    # Na Força de Trabalho OU Força Potencial
    ft_ou_ftp = as.numeric(
      (!is.na(VD4001) & VD4001 == "Pessoas na força de trabalho") | 
        (!is.na(VD4003) & VD4003 == "Pessoas fora da força de trabalho e na força de trabalho potencial")
    ),
    
    ft_ou_desalentada = as.numeric(
      (!is.na(VD4001) & VD4001 == "Pessoas na força de trabalho") | 
        (!is.na(VD4005) & VD4005 == "Pessoas desalentadas")
    ),
    
    # DESOCUPADOS ouU Força Potencial ou subocupadas
    desocup_ou_ftp_ou_subocup  = as.numeric(
      (!is.na(VD4002) & VD4002 == "Pessoas desocupadas")  | 
        (!is.na(VD4003) & VD4003 == "Pessoas fora da força de trabalho e na força de trabalho potencial") | 
        (!is.na(VD4004A) & VD4004A == "Pessoas subocupadas")
    ),
    # VD4019 é renda habitualmene recebida no trabalho  por -> mes <- enquanto 
    # VD4031 o Valor da hora do trabalho  - são horas habitualmente trabalhadas por -> semana <-, considerando
    # que o mes comercial tem cinco semanas, multiplicamos VD4031 por cinco pra obter o valor da hora mensal
    valor_hora = (VD4019/(5*VD4031)),
    
    # Pessoas que receberam abaixo do valor da hora SEMANAL -AJUSTAR PRO SALARIO MINIMO DE CADA ANO
    subremuneracao = as.numeric(
      (valor_hora < 7.37) 
    ),
    
    # Definição de informais seguindo a tabela 8529 do SIDRA
    informal = as.numeric(
      (!is.na(VD4009) & VD4009 == "Empregado no setor privado sem carteira de trabalho assinada") | 
        (!is.na(VD4009) & VD4009 == "Trabalhador doméstico sem carteira de trabalho assinada") | 
        (!is.na(VD4009) & VD4009 == "Trabalhador familiar auxiliar") |
        ((!is.na(VD4009) & VD4009 == "Empregador") & (!is.na(V4019) & V4019 == "Não")) |
        ((!is.na(VD4009) & VD4009 == "Conta-própria") & (!is.na(V4019) & V4019 == "Não"))
    ),
    
    nem_nem = as.numeric(
      (V2009 >= 14 & V2009 <= 29) &               # Janela de idade dos jovens
        (!is.na(V3002) & V3002 == "Não") & 
        (is.na(VD4002) | VD4002 != "Pessoas ocupadas")
      # Não estuda (2) E está desocupado/fora da força (2)
    )
    
  )

# Vetores para fazer o loop e calcular os dados
# nivel_regional_piaui <- c(V1022, V1023, Estrato_agregado)
# recorte_demografico <- c(Faixa_Etaria_trabalho, V2007, VD3004)


# Aqui o grande bulking o relatorio
# Indicadores mercado de trabalho ------------------------------------------------------------------------
# Taxa combinada de desocupação e de subocupação por insuficiência de horas trabalhadas
tmp <- svyby(
  formula = ~num_var,
  by=~Estrato_agregado,
  denominator = ~den_var,
  design = dados_processados,
  FUN = svyratio,
  na.rm = TRUE
)


tmp <- svyby(
  ~1,
  by=~Estrato_agregado,
  design =dados_processados,
  FUN = svytotal,
  na.rm = F)
View(tmp)

dados_piaui <- subset(dadosPNADc, UF == "22")

# 3. Calcular a população total estimada para o Piauí
pop_total_pi <- svytotal(~1, dados_PIAUI, na.rm = TRUE)
print(pop_total_pi)

# AQUI IMPLEMENTO OS INDICADORES DO LIVRO DO PANORAMA DO MERCADO DE TRABALHO NO RBASIL - P.57 ----------------
# Emprego-----------------------------------------------------------------------------------------------------
# Taxa de desocupação 
tmp <- svyby(
  ~VD4002 == "Pessoas desocupadas",
  by=~Estrato,
  denominator= ~VD4001 == "Pessoas na força de trabalho",
  design =dados_processados,
  FUN = svyratio,
  na.rm = T)
View(tmp)

# V4076 - Percentual de desocupados por tempo de procura de emprego
# Pro segundo trimestre de 2026 essa vari´vel tem 0% em alguns estratos, ver para otros trimestres
tmp <- svyby(
  formula = ~V4076 == "2 anos ou mais",
  by= ~V1023, 
  denominator= ~VD4002 == "Pessoas desocupadas",
  design = dados_processados,
  FUN = svyratio,
  na.rm = TRUE
)
View(tmp)

# Proporção de chefes de famílias entre os desocupados
tmp <-svyby(
  formula = ~VD2002 == "Pessoa responsável",
  by= ~Estrato_agregado, 
  denominator= ~VD4002 == "Pessoas desocupadas",
  design = subset(dados_processados, VD4002 == "Pessoas desocupadas"),
  FUN = svyratio,
  na.rm = TRUE
)
View(tmp)

tmp <-svyby(
  formula = ~VD2002 == "Pessoa responsável",
  by= ~interaction(Estrato_agregado, VD2004), 
  denominator= ~VD4002 == "Pessoas desocupadas",
  design = subset(dados_processados, VD4002 == "Pessoas desocupadas"),
  FUN = svyratio,
  na.rm = TRUE
)
View(tmp)


# variáveis de renda -------------------------------
# Posso escolher outra variavel de renda - talvez a efetivamemte recebida de todas as fontes
tmp <- svyby(
  ~VD4019,
  by= ~Estrato_agregado, 
  design = dados_processados,
  FUN = svymean,
  na.rm = TRUE
)
View(tmp)-
  
  # Percentual de pessoas com subremuneração no trabalho (valor abaixo da hora do salario minimo)
  tmp <- svyby(
    formula = ~subremuneracao,
    by= ~Estrato_agregado, 
    design = dados_processados,
    FUN = svymean,
    na.rm = TRUE
  )
View(tmp)

# Desigualdade de renda entre setor clts e não clts no setor privado
tmp <- svyby(
  formula = ~VD4019,
  by= ~interaction(Estrato_agregado, formal_setor_privado),
  design = dados_processados,
  FUN = svymean,
  na.rm = TRUE
)
View(tmp)

# Indicadores de inserção no mercadod e trabalho ------------------------------
# Taxa de informalidade
tmp <-svyby(
  formula=~informal,
  by= ~Estrato_agregado,
  denominator = ~VD4002 == "Pessoas ocupadas",
  design =dados_processados,
  FUN = svyratio,
  na.rm = T)
View(tmp)

# Taxa de subocupação
tmp <-svyby(
  formula=~(!is.na(VD4004A) & VD4004A == "Pessoas subocupadas"),
  by= ~Estrato_agregado,
  design =dados_processados,
  denominator =  ~VD4002 == "Pessoas ocupadas",
  FUN = svyratio,
  na.rm = T)
View(tmp)

# 11 anos ou mais de estudo
# A tabela sidra que mais se aproxima desse indicador é a 4095 por nivel de instrução
# os valores nao ficam exatamente iguais pois a proporção é feita pelo ultimo curso que a pessoa fez (V3003A E v3006a)
# Mas os valores são proximos ao percentual com pelo menos ensino medio completo/incompleto
svyby(
  formula=~(!is.na(anos_estudos_11_ou_mais) & anos_estudos_11_ou_mais == 1), 
  by= ~Estrato_agregado,
  denominator =  ~VD4002 == "Pessoas ocupadas",
  design =dados_processados,
  FUN = svyratio,
  na.rm = T)

# Indicadores adicionais - exclusão do mercado de trabalho ---------------------
# Percentual de desalentados - tabela 6813 do sidra
tmp <-svyby(
  formula=~(!is.na(VD4005) & VD4005 == "Pessoas desalentadas"),
  by= ~Estrato_agregado,
  design =dados_processados,
  denominator =  ~ft_ou_desalentada,
  FUN = svyratio,
  na.rm = T)
View(tmp)

# Percentual de desalentados na população fora da força de trabalho
tmp <-svyby(
  formula=~(!is.na(VD4005) & VD4005 == "Pessoas desalentadas"),
  by= ~Estrato_agregado,
  design =dados_processados,
  denominator =  ~VD4003,
  FUN = svyratio,
  na.rm = T)
View(tmp)

# O que fez pra conseguir empego =(esse não é tão interessante, posso tirar)
tmp <- svyby(
  formula = ~V4072A,
  by = ~Estrato_agregado,
  design = dados_processados,
  FUN = svymean,
  na.rm = TRUE
)
View(tmp)

# Motivo de ter desistido de procurar emprego
tmp <- svyby(
  formula = ~V4074A,
  by = ~UF,
  design = subset(dados_processados, VD4005 == "Pessoas desalentadas"),
  FUN = svymean,
  na.rm = TRUE
)
View(tmp)

# Jovens nem e nem ----------------------------------------------
# E aqui, os nem e nem 
tmp <- svyby(
  formula = ~nem_nem,
  by = ~Estrato_agregado,
  denominator = ~(V2009 >= 14 & V2009 <= 29),
  design = dados_processados,
  FUN = svyratio,
  na.rm = TRUE
)
View(tmp)

# Motivo de não ter procurado emprego nem e nem
tmp <- svyby(
  formula = ~V4074A,
  by = ~UF,
  design = subset(dados_processados, nem_nem),
  FUN = svymean,
  na.rm = TRUE
)
View(tmp)

# MOitvo por não ter começado a trablhar na semana de refeencia netre os jovems
tmp <- svyby(
  formula = ~V4078A,
  by = ~UF,
  design = subset(dados_processados, nem_nem),
  FUN = svymean,
  na.rm = TRUE
)
View(tmp)


