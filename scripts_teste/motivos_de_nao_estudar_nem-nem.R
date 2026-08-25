library(PNADcIBGE)
library(survey)
library(dplyr)
library(magrittr)
library(stringr)
library(ggsurvey)
library(tidyr)

# Aqui você seleciona o ano, ele é um parametro pra função logo abaixo  que puxa os dados
ANO = 2025

dadosPNADc <- get_pnadc(year=ANO, topic = 2)


# Aqui eu criei uma variável nova, pra fazer as faixas etárias pois ela não vem criada
dadosPNADc[['variables']][['Faixa_Etaria']] = case_match(dadosPNADc[["variables"]][["V2009"]],
                                                         0:3 ~ "De 0 a 3 anos",
                                                         4:5 ~ "De 4 a 5 anos",
                                                         6:13 ~ "De 6 a 13 anos",
                                                         14:17 ~ "De 14 a 17 anos",
                                                         18:24 ~ "De 18 a 24 anos",
                                                         25:29 ~ "De 25 a 29 anos",
                                                         30:34 ~ "De 30 a 34 anos",
                                                         35:39 ~ "De 35 a 39 anos",
                                                         40:44 ~ "De 40 a 44 anos",
                                                         45:49 ~ "De 45 a 49 anos",
                                                         50:54 ~ "De 50 a 54 anos",
                                                         55:59 ~ "De 55 a 59 anos",
                                                         60:64 ~ "De 60 a 64 anos",
                                                         65:69 ~ "De 65 a 69 anos",
                                                         70:74 ~ "De 70 a 74 anos",
                                                         75:79 ~ "De 75 a 79 anos",
                                                         80:84 ~ "De 80 a 84 anos",
                                                         85:89 ~ "De 85 a 89 anos",
                                                         90:130 ~ "Mais de 90 anos")

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

tmp <- svyby(
  formula = ~V3034B,
  by = ~Estrato_agregado,
  design = subset(dados_processados, nem_nem),
  FUN = svymean,
  na.rm = TRUE
)
View(tmp)
