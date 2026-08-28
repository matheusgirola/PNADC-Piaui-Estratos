<!-- GERADO AUTOMATICAMENTE por R/09_preencher_relatorio.R a partir de ./output/relatorio_trimestral.md. Trimestre: 2026T2. Não editar à mão — a próxima rodada sobrescreve sem aviso. -->


**VERSÃO AUTOMATÓTICA DO RELATÓRIO - REVER OS TEXTOS E REDIGIR AS ANÁLISES RESTANTE**

<!-- TO-DO: Ver o que já deixo na 1 e 2 seção pré-preenchido pra próximas edições -->
## 1 Introdução
## 2 Metodologia
### 2.1 Dimensões e indicadores analisados
### 2.2 Recortes geográficos
### 2.3 Recortes demográficos
### 2.4 Robustez dos indicadores estimados
### 2.5 Comparações entre os recortes


## 3 Análise dos resultados

As quatro subseções a seguir seguem a mesma estrutura: um indicador principal,
que responde à pergunta central da dimensão, e indicadores auxiliares, que
qualificam a resposta. Cada uma traz as estimativas por recorte
geográfico e um texto que aponta as diferenças relevantes.

Três chaves de leitura ajudam a interpretar os números: Primeiro, o intervalo importa mais que o ponto. Toda estimativa aqui vem de uma amostra. Quando os intervalos de confiança das estimativas de dois estratos se
sobrepõem, a diferença entre eles pode ser apenas ruído amostral, mesmo que os
valores centrais pareçam distantes.

Segundo, Nem toda estimativa tem o mesmo peso. A coluna de precisão classifica cada
número pelo coeficiente de variação: quanto menor, mais confiável. Estimativas
marcadas como *regular* devem ser lidas com cautela; as marcadas como *baixa*
aparecem na tabela por completude, mas não sustentam conclusão. Isso é
esperado — quanto mais fino o recorte territorial, menos pessoas da amostra
caem dentro dele.

Por fim, a  última linha de cada
tabela traz o teste que responde se as diferenças entre as categorias daquele
recorte são estatisticamente significativas - os testes descritos na seção 2.5. É esse teste, e não a inspeção
visual da tabela, que autoriza afirmar que dois estratos são diferentes. O
p-valor usado é o **ajustado**: como o relatório faz centenas de comparações
por trimestre, algumas sairiam significativas por puro acaso, e a correção
desconta esse efeito.

### 3.2 Desocupação

#### 3.2.1 Taxa de desocupação

O Piauí registrou taxa de desocupação de 8,3%, ante
7,6% no Nordeste e 5,4%
no Brasil. Dentro do estado, a distância entre o estrato com maior e menor
desocupação foi de 14,5 pontos percentuais, separando
estrato 2220020 (19,3%)
de estrato 2210013 (4,8%).

**Tabela 2** — Taxa de desocupação, por recorte geográfico — 2º trimestre de 2026

| Recorte | Categoria | Estimativa (%) | IC 95% | CV (%) | Precisão |
|---|---|---:|:---:|---:|---|
| Agregados | Brasil | 5,4 | [5,2; 5,5] | 1,4 | excelente |
| Agregados | Nordeste | 7,6 | [7,3; 7,9] | 2,1 | excelente |
| Agregados | Piauí | 8,3 | [7,1; 9,5] | 7,5 | boa |
| Agregados | Teresina | 7,1 | [5,8; 8,5] | 9,5 | boa |
| Zona | Urbana | 7,5 | [6,3; 8,7] | 8,2 | boa |
| Zona | Rural | 10,9 | [8,2; 13,6] | 12,7 | boa |
| Administrativo | Capital | 7,1 | [5,8; 8,5] | 9,5 | boa |
| Administrativo | Resto da RIDE | 16,4 | [11,8; 20,9] | 14,3 | boa |
| Administrativo | Resto da UF | 8,1 | [6,4; 9,7] | 10,3 | boa |
| Estrato agregado | Teresina | 7,1 | [5,8; 8,5] | 9,5 | boa |
| Estrato agregado | Entorno metropolitano | 16,4 | [11,8; 20,9] | 14,3 | boa |
| Estrato agregado | Centro-Leste | 8,2 | [6,1; 10,3] | 13,2 | boa |
| Estrato agregado | Baixo Parnaíba | 6,7 | [4,0; 9,3] | 20,4 | regular |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | 10,0 | [6,5; 13,4] | 17,7 | regular |
| Estrato (7 dígitos) | maior: 2220020 | 19,3 | [12,3; 26,3] | 18,5 | regular |
| Estrato (7 dígitos) | menor: 2210013 | 4,8 | [2,2; 7,4] | 27,3 | regular |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Nota: os 13 estratos de 7 dígitos aparecem na íntegra no anexo
metodológico; aqui são exibidos apenas os extremos.

**Tabela 3** — Taxa de desocupação, diferença entre as categorias de cada recorte - 2º trimestre de 2026

| Recorte | p-valor | p ajustado | Significativo a 5%? |
|---|---:|---:|:---:|
| Zona (urbana × rural) | 0,010 | 0,012 | sim |
| Estrato administrativo | < 0,001 | < 0,001 | sim |
| Estrato agregado | 0,007 | 0,010 | sim |
| Estrato (7 dígitos) | — | — | — |
| Teresina × resto do Piauí | 0,057 | 0,064 | não |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Figura 1** — Taxa de desocupação por recorte geográfico, com intervalo de
confiança de 95% — 2º trimestre de 2026

![](./output/figuras/comp_geo_Taxa_Desocupacao.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.


A diferença
entre Teresina e o restante do estado não alcançou significância estatística
neste trimestre (p ajustado = 0,064), o
que recomenda cautela antes de tratá-la como um padrão consolidado.

A comparação entre zona urbana e rural merece atenção específica, porque a
desocupação rural costuma ser estruturalmente mais baixa: parte da população ocupada na agricultura familiar não procura, e muitas vezes se ocupam mais com produção por subsistência (verificar esse mecanismo)
trabalho no sentido que a pesquisa capta, e por isso não é contada como
desocupada. Neste trimestre a diferença foi de 3,4
pontos (\*).

> **A REDIGIR** — bloco demográfico da desocupação — incluir só se o recorte for significativo E o CV ficar abaixo de 15% em TODAS as subdivisões de cada corte geográfico (ver anexo §5.3). Consultar output/tabelas/comparacao_demografica_<sufixo>.csv.

#### 3.2.2 Desocupação da pessoa responsável pelo domicílio

Este indicador mede quanto dos desocupados são pessoas responsáveis pelo
domicílio. Uma taxa de desocupação alta concentrada em jovens que moram com os
pais tem um significado social muito diferente da mesma taxa concentrada em
quem sustenta a casa.

Em estrato 2251012,
58,6% dos desocupados eram
responsáveis pelo domicílio, contra 26,1%
em estrato 2210030.

**Tabela 4** — Pessoas responsáveis pelo domicílio entre os desocupados, por
recorte geográfico — 2º trimestre de 2026

| Recorte | Categoria | Estimativa (%) | IC 95% | CV (%) | Precisão |
|---|---|---:|:---:|---:|---|
| Agregados | Brasil | 36,4 | [35,2; 37,5] | 1,7 | excelente |
| Agregados | Nordeste | 37,9 | [36,1; 39,7] | 2,4 | excelente |
| Agregados | Piauí | 37,9 | [31,8; 44,0] | 8,2 | boa |
| Agregados | Teresina | 27,7 | [20,4; 35,1] | 13,5 | boa |
| Zona | Urbana | 36,6 | [29,1; 44,0] | 10,4 | boa |
| Zona | Rural | 40,9 | [31,8; 50,0] | 11,4 | boa |
| Administrativo | Capital | 27,7 | [20,4; 35,1] | 13,5 | boa |
| Administrativo | Resto da RIDE | 38,4 | [23,3; 53,5] | 20,0 | regular |
| Administrativo | Resto da UF | 42,5 | [34,0; 50,9] | 10,2 | boa |
| Estrato agregado | Teresina | 27,7 | [20,4; 35,1] | 13,5 | boa |
| Estrato agregado | Entorno metropolitano | 38,4 | [23,3; 53,5] | 20,0 | regular |
| Estrato agregado | Centro-Leste | 47,0 | [34,2; 59,9] | 13,9 | boa |
| Estrato agregado | Baixo Parnaíba | 28,5 | [13,9; 43,1] | 26,1 | regular |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | 51,1 | [35,3; 66,9] | 15,8 | regular |
| Estrato (7 dígitos) | maior: 2251012 | 58,6 | [29,3; 88,0] | 25,6 | regular |
| Estrato (7 dígitos) | menor: 2210030 | 26,1 | [10,9; 41,2] | 29,7 | regular |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Tabela 5** — Pessoas responsáveis pelo domicílio entre os desocupados, 
diferença entre as categorias de cada recorte — 2º trimestre de 2026

| Recorte | p-valor | p ajustado | Significativo a 5%? |
|---|---:|---:|:---:|
| Zona (urbana × rural) | 0,460 | 0,480 | não |
| Estrato administrativo | 0,044 | 0,051 | não |
| Estrato agregado | 0,037 | 0,045 | sim |
| Estrato (7 dígitos) | — | — | — |
| Teresina × resto do Piauí | 0,011 | 0,014 | sim |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Figura 2** — Pessoas responsáveis pelo domicílio entre os desocupados —
2º trimestre de 2026

![](./output/figuras/comp_geo_Chefes_Familia_Desocupados.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.


> **A REDIGIR** — uma ou duas frases interpretando o contraste acima — o que significa, para o orçamento das famílias daquele estrato, essa concentração.

#### 3.2.3 Desocupação de quem contribui para a renda do domicílio

Amplia o indicador anterior para incluir o cônjuge ou companheiro(a), captando
não apenas quem é formalmente o responsável pelo domicílio mas o conjunto de
adultos de quem a renda da casa depende diretamente.

No Piauí, 55,6% dos desocupados eram
responsáveis pelo domicílio ou cônjuges, contra
37,9% apenas de responsáveis — a diferença
corresponde aos cônjuges desocupados.

**Tabela 6** — Responsáveis ou cônjuges entre os desocupados, por recorte
geográfico — 2º trimestre de 2026

| Recorte | Categoria | Estimativa (%) | IC 95% | CV (%) | Precisão |
|---|---|---:|:---:|---:|---|
| Agregados | Brasil | 52,8 | [51,4; 54,1] | 1,3 | excelente |
| Agregados | Nordeste | 54,6 | [52,7; 56,4] | 1,7 | excelente |
| Agregados | Piauí | 55,6 | [49,2; 62,1] | 5,9 | boa |
| Agregados | Teresina | 41,4 | [33,3; 49,5] | 10,0 | boa |
| Zona | Urbana | 53,5 | [46,3; 60,6] | 6,8 | boa |
| Zona | Rural | 60,6 | [49,4; 71,7] | 9,4 | boa |
| Administrativo | Capital | 41,4 | [33,3; 49,5] | 10,0 | boa |
| Administrativo | Resto da RIDE | 54,4 | [42,8; 65,9] | 10,8 | boa |
| Administrativo | Resto da UF | 62,5 | [53,5; 71,5] | 7,3 | boa |
| Estrato agregado | Teresina | 41,4 | [33,3; 49,5] | 10,0 | boa |
| Estrato agregado | Entorno metropolitano | 54,4 | [42,8; 65,9] | 10,8 | boa |
| Estrato agregado | Centro-Leste | 66,4 | [55,2; 77,5] | 8,6 | boa |
| Estrato agregado | Baixo Parnaíba | 54,9 | [33,0; 76,8] | 20,3 | regular |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | 65,8 | [53,7; 77,8] | 9,4 | boa |
| Estrato (7 dígitos) | maior: 2253011 | 72,7 | [42,6; 102,8] | 21,1 | regular |
| Estrato (7 dígitos) | menor: 2210011 | 44,5 | [33,4; 55,5] | 12,7 | boa |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Tabela 7** — Responsáveis ou cônjuges entre os desocupados, diferença entre as categorias de cada recorte — 2º trimestre de 2026

| Recorte | p-valor | p ajustado | Significativo a 5%? |
|---|---:|---:|:---:|
| Zona (urbana × rural) | 0,268 | 0,283 | não |
| Estrato administrativo | 0,002 | 0,003 | sim |
| Estrato agregado | 0,056 | 0,064 | não |
| Estrato (7 dígitos) | — | — | — |
| Teresina × resto do Piauí | < 0,001 | < 0,001 | sim |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Figura 3** — Responsáveis ou cônjuges entre os desocupados — 2º trimestre de 2026

![](./output/figuras/comp_geo_Conribuintes_Desocupados.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

> **A REDIGIR** — o que essa diferença diz sobre o arranjo de sustento das famílias do estado.

### 3.3 Rendimento

#### 3.3.1 Rendimento médio real habitual

No Piauí, 55,6% dos desocupados eram
responsáveis pelo domicílio ou cônjuges, contra
37,9% apenas de responsáveis — a diferença
corresponde aos cônjuges desocupados.


**Tabela 8** — Rendimento médio real habitualmente recebido em todos os
trabalhos, por recorte geográfico — 2º trimestre de 2026

| Recorte | Categoria | Estimativa (R$) | IC 95% | CV (%) | Precisão |
|---|---|---:|:---:|---:|---|
| Agregados | Brasil | R$ 3.738 | [R$ 3.679; R$ 3.798] | 0,8 | excelente |
| Agregados | Nordeste | R$ 2.645 | [R$ 2.564; R$ 2.725] | 1,6 | excelente |
| Agregados | Piauí | R$ 2.547 | [R$ 2.356; R$ 2.738] | 3,8 | excelente |
| Agregados | Teresina | R$ 3.690 | [R$ 3.207; R$ 4.173] | 6,7 | boa |
| Zona | Urbana | R$ 2.902 | [R$ 2.658; R$ 3.146] | 4,3 | excelente |
| Zona | Rural | R$ 1.310 | [R$ 1.194; R$ 1.425] | 4,5 | excelente |
| Administrativo | Capital | R$ 3.690 | [R$ 3.207; R$ 4.173] | 6,7 | boa |
| Administrativo | Resto da RIDE | R$ 1.900 | [R$ 1.645; R$ 2.156] | 6,9 | boa |
| Administrativo | Resto da UF | R$ 1.992 | [R$ 1.817; R$ 2.167] | 4,5 | excelente |
| Estrato agregado | Teresina | R$ 3.690 | [R$ 3.207; R$ 4.173] | 6,7 | boa |
| Estrato agregado | Entorno metropolitano | R$ 1.900 | [R$ 1.645; R$ 2.156] | 6,9 | boa |
| Estrato agregado | Centro-Leste | R$ 1.991 | [R$ 1.569; R$ 2.412] | 10,8 | boa |
| Estrato agregado | Baixo Parnaíba | R$ 1.678 | [R$ 1.505; R$ 1.850] | 5,3 | boa |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | R$ 2.463 | [R$ 2.152; R$ 2.774] | 6,4 | boa |
| Estrato (7 dígitos) | maior: 2210013 | R$ 6.034 | [R$ 4.434; R$ 7.635] | 13,5 | boa |
| Estrato (7 dígitos) | menor: 2252020 | R$ 1.113 | [R$ 986; R$ 1.239] | 5,8 | boa |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria. Nota: valores deflacionados para reais do último trimestre da série.

**Tabela 9** — Rendimento médio real habitualmente recebido em todos os
trabalhos, diferença entre as categorias de cada recorte — 2º trimestre de 2026

| Recorte | p-valor | p ajustado | Significativo a 5%? |
|---|---:|---:|:---:|
| Zona (urbana × rural) | < 0,001 | < 0,001 | sim |
| Estrato administrativo | < 0,001 | < 0,001 | sim |
| Estrato agregado | < 0,001 | < 0,001 | sim |
| Estrato (7 dígitos) | < 0,001 | < 0,001 | sim |
| Teresina × resto do Piauí | < 0,001 | < 0,001 | sim |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Figura 4** — Rendimento médio real habitual por recorte geográfico —
2º trimestre de 2026

![](./output/figuras/comp_geo_Rendimento_Medio_Habitual.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

Ressalta-se que a média de rendimento  é sensível a valores muito altos e, em territórios pequenos, um punhado de rendimentos elevados desloca o resultado inteiro. A distribuição completa dos rendimentos
por estrato está no anexo metodológico, e é ela que revela se a média
representa a maioria ou é puxada pela cauda.

> **A REDIGIR** — bloco demográfico do rendimento médio — incluir só se significativo E com CV abaixo de 15% em todas as subdivisões de cada corte geográfico.

#### 3.3.2 Sub-remuneração

Mede o percentual de ocupados que, dividido o que recebem pelas horas que
trabalham, ganham menos que o salário mínimo por hora — hoje R$ 7,37.
38,2% dos ocupados do Piauí recebiam abaixo
do mínimo por hora. A incidência foi de
67,4% em
estrato 2252021 e
17,7% em
estrato 2210012.

**Tabela 10** — Sub-remuneração por hora trabalhada, por recorte geográfico —
2º trimestre de 2026

| Recorte | Categoria | Estimativa (%) | IC 95% | CV (%) | Precisão |
|---|---|---:|:---:|---:|---|
| Agregados | Brasil | 18,7 | [18,5; 19,0] | 0,7 | excelente |
| Agregados | Nordeste | 35,7 | [35,1; 36,3] | 0,9 | excelente |
| Agregados | Piauí | 38,2 | [35,8; 40,5] | 3,1 | excelente |
| Agregados | Teresina | 25,7 | [22,2; 29,3] | 7,0 | boa |
| Zona | Urbana | 32,9 | [30,1; 35,7] | 4,3 | excelente |
| Zona | Rural | 56,5 | [52,1; 61,0] | 4,0 | excelente |
| Administrativo | Capital | 25,7 | [22,2; 29,3] | 7,0 | boa |
| Administrativo | Resto da RIDE | 41,0 | [34,5; 47,6] | 8,1 | boa |
| Administrativo | Resto da UF | 44,6 | [41,4; 47,8] | 3,7 | excelente |
| Estrato agregado | Teresina | 25,7 | [22,2; 29,3] | 7,0 | boa |
| Estrato agregado | Entorno metropolitano | 41,0 | [34,5; 47,6] | 8,1 | boa |
| Estrato agregado | Centro-Leste | 42,9 | [37,8; 47,9] | 6,0 | boa |
| Estrato agregado | Baixo Parnaíba | 53,0 | [47,8; 58,3] | 5,1 | boa |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | 34,4 | [28,8; 39,9] | 8,3 | boa |
| Estrato (7 dígitos) | maior: 2252021 | 67,4 | [50,0; 84,8] | 13,2 | boa |
| Estrato (7 dígitos) | menor: 2210012 | 17,7 | [11,6; 23,9] | 17,7 | regular |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Tabela 11** — Sub-remuneração por hora trabalhada, diferença entre as categorias de cada recorte —
2º trimestre de 2026

| Recorte | p-valor | p ajustado | Significativo a 5%? |
|---|---:|---:|:---:|
| Zona (urbana × rural) | < 0,001 | < 0,001 | sim |
| Estrato administrativo | < 0,001 | < 0,001 | sim |
| Estrato agregado | < 0,001 | < 0,001 | sim |
| Estrato (7 dígitos) | 0,089 | 0,098 | não |
| Teresina × resto do Piauí | < 0,001 | < 0,001 | sim |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Figura 5** — Percentual de ocupados com rendimento-hora abaixo do salário
mínimo horário — 2º trimestre de 2026

![](./output/figuras/comp_geo_Percentual_Subremuneracao.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

> **A REDIGIR** — o que a distância entre esses dois extremos sugere sobre a estrutura produtiva dos territórios envolvidos.

#### 3.3.3 Desigualdade entre formais e informais

O indicador é a razão entre o rendimento médio dos ocupados formais e o dos
informais. Um valor de 2,0 significa que o trabalhador formal ganha, em média,
o dobro do informal. A razão formal/informal no Piauí foi de 2,72 — ou seja,
o trabalhador com carteira ganhou, em média, 172% a mais que o
informal: R\$ 3.675 contra R\$ 1.353.
Entre os estratos, a razão foi mais alta em estrato 2253020
(3,63) e mais baixa em estrato 2253022
(1,35).

**Tabela 12** — Rendimento médio por situação de formalidade e razão
formal/informal, por recorte geográfico — 2º trimestre de 2026

| Recorte | Categoria | Formais (R$) | Informais (R$) | Razão | IC 95% da razão | CV (%) | Precisão |
|---|---|---:|---:|---:|:---:|---:|---|
| Agregados | Brasil | R$ 4.513 | R$ 2.399 | 1,88 | [1,85; 1,92] | 0,9 | excelente |
| Agregados | Nordeste | R$ 3.650 | R$ 1.549 | 2,36 | [2,28; 2,44] | 1,8 | excelente |
| Agregados | Piauí | R$ 3.675 | R$ 1.353 | 2,72 | [2,52; 2,93] | 3,8 | excelente |
| Agregados | Teresina | R$ 4.548 | R$ 2.142 | 2,12 | [1,88; 2,39] | 6,2 | boa |
| Zona | Urbana | R$ 3.917 | R$ 1.573 | 2,49 | [2,30; 2,70] | 4,0 | excelente |
| Zona | Rural | R$ 2.226 | R$ 855 | 2,60 | [2,30; 2,94] | 6,3 | boa |
| Administrativo | Capital | R$ 4.548 | R$ 2.142 | 2,12 | [1,88; 2,39] | 6,2 | boa |
| Administrativo | Resto da RIDE | R$ 2.675 | R$ 1.276 | 2,10 | [1,60; 2,74] | 13,6 | boa |
| Administrativo | Resto da UF | R$ 3.097 | R$ 1.083 | 2,86 | [2,60; 3,14] | 4,8 | excelente |
| Estrato agregado | Teresina | R$ 4.548 | R$ 2.142 | 2,12 | [1,88; 2,39] | 6,2 | boa |
| Estrato agregado | Entorno metropolitano | R$ 2.675 | R$ 1.276 | 2,10 | [1,60; 2,74] | 13,6 | boa |
| Estrato agregado | Centro-Leste | R$ 3.050 | R$ 1.142 | 2,67 | [2,19; 3,25] | 10,1 | boa |
| Estrato agregado | Baixo Parnaíba | R$ 2.781 | R$ 932 | 2,98 | [2,65; 3,36] | 6,0 | boa |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | R$ 3.509 | R$ 1.277 | 2,75 | [2,35; 3,22] | 8,1 | boa |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Dados: `output/desigualdade_formal_informal_2026T2.csv`.

Nota de leitura sobre o intervalo desta tabela: ao contrário dos demais, ele é
**assimétrico** em torno da estimativa. Isso é intencional e correto — uma
razão não pode ser negativa, e o intervalo é construído na escala logarítmica
antes de voltar à escala da razão. O anexo metodológico (§4.4) detalha o
procedimento.

**Figura 6** — Rendimento médio dos ocupados formais — 2º trimestre de 2026

![](./output/figuras/comp_geo_Rendimento_Formal.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Figura 7** — Rendimento médio dos ocupados informais — 2º trimestre de 2026

![](./output/figuras/comp_geo_Rendimento_Informal.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

Vale contrastar com a capital: em Teresina a razão foi de
2,12, a mais baixa entre os recortes agregados — não
porque o formal pague pouco ali, mas porque o informal teresinense ganha
R\$ 2.142, bem acima do informal do interior.

Duas leituras opostas produzem o mesmo número baixo, e vale distingui-las. Uma
razão próxima de 1 pode significar que o mercado formal daquele território não
paga muito melhor que o informal — o que é má notícia, e costuma indicar que a
formalização se concentra em ocupações de baixa remuneração. Mas pode também
significar que o mercado informal ali é relativamente bem pago, o que muda o
diagnóstico por completo. A comparação com os rendimentos absolutos das Figuras
6 e 7 é o que separa os dois casos.

> **A REDIGIR** — dizer qual dos dois casos se aplica aos estratos de razão mais baixa deste trimestre, olhando os rendimentos absolutos das Figuras 6 e 7.

### 3.4 Inserção no mercado de trabalho

#### 3.4.1 Taxa de informalidade

A informalidade no Piauí atingiu 49,5% dos
ocupados, contra 48,7% no Nordeste e
37,4% no Brasil. A variação interna ao estado foi
de 46,8 pontos, de
30,3% em
estrato 2210012 a
77,1% em
estrato 2252021.

**Tabela 13** — Taxa de informalidade, por recorte geográfico — 2º trimestre de 2026

| Recorte | Categoria | Estimativa (%) | IC 95% | CV (%) | Precisão |
|---|---|---:|:---:|---:|---|
| Agregados | Brasil | 37,4 | [37,1; 37,8] | 0,5 | excelente |
| Agregados | Nordeste | 48,7 | [48,1; 49,4] | 0,7 | excelente |
| Agregados | Piauí | 49,5 | [47,4; 51,6] | 2,2 | excelente |
| Agregados | Teresina | 35,7 | [32,3; 39,2] | 4,9 | excelente |
| Zona | Urbana | 44,0 | [41,5; 46,5] | 2,9 | excelente |
| Zona | Rural | 68,1 | [64,1; 72,2] | 3,0 | excelente |
| Administrativo | Capital | 35,7 | [32,3; 39,2] | 4,9 | excelente |
| Administrativo | Resto da RIDE | 55,9 | [48,0; 63,7] | 7,2 | boa |
| Administrativo | Resto da UF | 56,1 | [53,5; 58,7] | 2,4 | excelente |
| Estrato agregado | Teresina | 35,7 | [32,3; 39,2] | 4,9 | excelente |
| Estrato agregado | Entorno metropolitano | 55,9 | [48,0; 63,7] | 7,2 | boa |
| Estrato agregado | Centro-Leste | 56,9 | [52,0; 61,7] | 4,4 | excelente |
| Estrato agregado | Baixo Parnaíba | 60,8 | [56,4; 65,1] | 3,6 | excelente |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | 48,0 | [42,4; 53,7] | 6,0 | boa |
| Estrato (7 dígitos) | maior: 2252021 | 77,1 | [57,9; 96,4] | 12,7 | boa |
| Estrato (7 dígitos) | menor: 2210012 | 30,3 | [22,2; 38,4] | 13,6 | boa |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Tabela 14** — Taxa de informalidade, diferença entre as categorias de cada recorte — 2º trimestre de 2026

| Recorte | p-valor | p ajustado | Significativo a 5%? |
|---|---:|---:|:---:|
| Zona (urbana × rural) | < 0,001 | < 0,001 | sim |
| Estrato administrativo | < 0,001 | < 0,001 | sim |
| Estrato agregado | < 0,001 | < 0,001 | sim |
| Estrato (7 dígitos) | 0,145 | 0,155 | não |
| Teresina × resto do Piauí | < 0,001 | < 0,001 | sim |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Figura 8** — Taxa de informalidade por recorte geográfico — 2º trimestre de 2026

![](./output/figuras/comp_geo_Taxa_Informalidade.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

O contraste entre zona urbana e rural tende a ser o mais acentuado deste
indicador, e por razão estrutural: a produção agrícola familiar e o trabalho
por conta própria no campo são majoritariamente informais por natureza da
atividade, não por escolha do trabalhador. Neste trimestre a diferença foi de
24,1 pontos
(\*\*\*).

> **A REDIGIR** — bloco demográfico da informalidade — incluir só se significativo E com CV abaixo de 15% em todas as subdivisões de cada corte geográfico.

#### 3.4.2 Sub-ocupação por insuficiência de horas

11,2% dos ocupados do Piauí estavam subocupados, com
27,5% em estrato 2251020
e 7,8% em estrato 2253012.

**Tabela 15** — Sub-ocupação por insuficiência de horas, por recorte geográfico
— 2º trimestre de 2026

| Recorte | Categoria | Estimativa (%) | IC 95% | CV (%) | Precisão |
|---|---|---:|:---:|---:|---|
| Agregados | Brasil | 4,0 | [3,8; 4,1] | 1,7 | excelente |
| Agregados | Nordeste | 7,3 | [7,0; 7,7] | 2,4 | excelente |
| Agregados | Piauí | 11,2 | [9,8; 12,5] | 6,1 | boa |
| Agregados | Teresina | 1,3 | [0,7; 1,9] | 22,3 | regular |
| Zona | Urbana | 8,7 | [7,3; 10,2] | 8,3 | boa |
| Zona | Rural | 19,4 | [16,0; 22,7] | 8,8 | boa |
| Administrativo | Capital | 1,3 | [0,7; 1,9] | 22,3 | regular |
| Administrativo | Resto da RIDE | 6,4 | [2,7; 10,1] | 29,1 | regular |
| Administrativo | Resto da UF | 16,8 | [14,6; 19,0] | 6,6 | boa |
| Estrato agregado | Teresina | 1,3 | [0,7; 1,9] | 22,3 | regular |
| Estrato agregado | Entorno metropolitano | 6,4 | [2,7; 10,1] | 29,1 | regular |
| Estrato agregado | Centro-Leste | 21,3 | [17,8; 24,9] | 8,6 | boa |
| Estrato agregado | Baixo Parnaíba | 13,8 | [9,7; 17,9] | 15,1 | regular |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | 15,3 | [11,5; 19,1] | 12,7 | boa |
| Estrato (7 dígitos) | maior: 2251020 | 27,5 | [20,0; 34,9] | 13,8 | boa |
| Estrato (7 dígitos) | menor: 2253012 | 7,8 | [3,5; 12,0] | 27,7 | regular |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Tabela 16** — Sub-ocupação por insuficiência de horas, diferença entre as categorias de cada recorteo
— 2º trimestre de 2026

| Recorte | p-valor | p ajustado | Significativo a 5%? |
|---|---:|---:|:---:|
| Zona (urbana × rural) | < 0,001 | < 0,001 | sim |
| Estrato administrativo | < 0,001 | < 0,001 | sim |
| Estrato agregado | < 0,001 | < 0,001 | sim |
| Estrato (7 dígitos) | 0,108 | 0,118 | não |
| Teresina × resto do Piauí | < 0,001 | < 0,001 | sim |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Figura 9** — Percentual de ocupados subocupados por insuficiência de horas —
2º trimestre de 2026

![](./output/figuras/comp_geo_Taxa_Subocupacao.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

> **A REDIGIR** — relacionar a subocupação com a informalidade do mesmo território — jornada insuficiente e vínculo precário costumam andar juntos, mas nem sempre.

#### 3.4.3 Escolaridade dos ocupados

91,4% em
estrato 2210013 e
32,2% em
estrato 2254020 — uma diferença de
59,2 pontos. Cabe uma cautela de leitura: este indicador mede a
escolaridade de quem *está ocupado*, não a da população. Um estrato pode
aparecer com escolaridade alta simplesmente porque os menos escolarizados não
encontraram trabalho, e não porque a população seja mais escolarizada.

**Tabela 17** — Ocupados com ensino médio completo ou mais, por recorte
geográfico — 2º trimestre de 2026

| Recorte | Categoria | Estimativa (%) | IC 95% | CV (%) | Precisão |
|---|---|---:|:---:|---:|---|
| Agregados | Brasil | 73,3 | [72,9; 73,6] | 0,2 | excelente |
| Agregados | Nordeste | 69,4 | [68,7; 70,1] | 0,5 | excelente |
| Agregados | Piauí | 67,0 | [65,0; 69,0] | 1,5 | excelente |
| Agregados | Teresina | 84,1 | [81,5; 86,7] | 1,6 | excelente |
| Zona | Urbana | 74,6 | [72,4; 76,8] | 1,5 | excelente |
| Zona | Rural | 41,2 | [37,4; 45,1] | 4,8 | excelente |
| Administrativo | Capital | 84,1 | [81,5; 86,7] | 1,6 | excelente |
| Administrativo | Resto da RIDE | 72,0 | [67,1; 76,9] | 3,4 | excelente |
| Administrativo | Resto da UF | 57,5 | [54,6; 60,4] | 2,6 | excelente |
| Estrato agregado | Teresina | 84,1 | [81,5; 86,7] | 1,6 | excelente |
| Estrato agregado | Entorno metropolitano | 72,0 | [67,1; 76,9] | 3,4 | excelente |
| Estrato agregado | Centro-Leste | 58,7 | [54,1; 63,3] | 4,0 | excelente |
| Estrato agregado | Baixo Parnaíba | 54,2 | [48,9; 59,4] | 4,9 | excelente |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | 60,9 | [55,9; 65,9] | 4,2 | excelente |
| Estrato (7 dígitos) | maior: 2210013 | 91,4 | [86,7; 96,1] | 2,6 | excelente |
| Estrato (7 dígitos) | menor: 2254020 | 32,2 | [21,6; 42,8] | 16,8 | regular |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Tabela 18** — Ocupados com ensino médio completo ou mais, diferença entre as categorias de cada recorte — 2º trimestre de 2026

| Recorte | p-valor | p ajustado | Significativo a 5%? |
|---|---:|---:|:---:|
| Zona (urbana × rural) | < 0,001 | < 0,001 | sim |
| Estrato administrativo | < 0,001 | < 0,001 | sim |
| Estrato agregado | < 0,001 | < 0,001 | sim |
| Estrato (7 dígitos) | 0,036 | 0,044 | sim |
| Teresina × resto do Piauí | < 0,001 | < 0,001 | sim |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.


**Figura 10** — Percentual de ocupados com ensino médio completo ou mais —
2º trimestre de 2026

![](./output/figuras/comp_geo_Proporcao_Ocupados_Escolarizados.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.


### 3.5 Desalento

O desalento atingiu 7,0% da força de
trabalho ampliada do Piauí, com 23,2%
em estrato 2251022 e
7,2% em
estrato 2251011. Entre as pessoas fora da
força de trabalho, os desalentados foram
68,4% no estado.

#### 3.5.1 Percentual de desalentados

**Tabela 19** — Desalentados na força de trabalho ampliada, por recorte
geográfico — 2º trimestre de 2026

| Recorte | Categoria | Estimativa (%) | IC 95% | CV (%) | Precisão |
|---|---|---:|:---:|---:|---|
| Agregados | Brasil | 2,1 | [2,0; 2,1] | 2,2 | excelente |
| Agregados | Nordeste | 5,3 | [5,0; 5,6] | 2,7 | excelente |
| Agregados | Piauí | 7,0 | [5,7; 8,3] | 9,4 | boa |
| Agregados | Teresina | 0,7 | [0,3; 1,0] | 26,5 | regular |
| Zona | Urbana | 3,7 | [2,4; 4,9] | 17,9 | regular |
| Zona | Rural | 16,6 | [13,0; 20,1] | 10,9 | boa |
| Administrativo | Capital | 0,7 | [0,3; 1,0] | 26,5 | regular |
| Administrativo | Resto da RIDE | 3,3 | [1,2; 5,4] | 32,1 | baixa |
| Administrativo | Resto da UF | 10,4 | [8,4; 12,4] | 9,8 | boa |
| Estrato agregado | Teresina | 0,7 | [0,3; 1,0] | 26,5 | regular |
| Estrato agregado | Entorno metropolitano | 3,3 | [1,2; 5,4] | 32,1 | baixa |
| Estrato agregado | Centro-Leste | 13,5 | [10,0; 16,9] | 13,1 | boa |
| Estrato agregado | Baixo Parnaíba | 7,8 | [4,7; 10,9] | 20,4 | regular |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | 9,8 | [5,0; 14,7] | 25,0 | regular |
| Estrato (7 dígitos) | maior: 2251022 | 23,2 | [10,0; 36,5] | 29,1 | regular |
| Estrato (7 dígitos) | menor: 2251011 | 7,2 | [4,3; 10,2] | 20,8 | regular |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.


**Tabela 20** — Desalentados na força de trabalho ampliada, diferença entre as categorias de cada recorte — 2º trimestre de 2026

| Recorte | p-valor | p ajustado | Significativo a 5%? |
|---|---:|---:|:---:|
| Zona (urbana × rural) | < 0,001 | < 0,001 | sim |
| Estrato administrativo | < 0,001 | < 0,001 | sim |
| Estrato agregado | < 0,001 | < 0,001 | sim |
| Estrato (7 dígitos) | 0,662 | 0,671 | não |
| Teresina × resto do Piauí | < 0,001 | < 0,001 | sim |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Figura 11** — Percentual de desalentados na força de trabalho ampliada —
2º trimestre de 2026

![](./output/figuras/comp_geo_Desalentados_Forca_Ampliada.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

![](./output/figuras/comp_geo_Desalentados_Fora_Forca.png)

**Figura 12** — Desalentados como percentual das pessoas fora da força de
trabalho — 2º trimestre de 2026

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

A leitura conjunta com a taxa de desocupação é o que dá sentido ao indicador.

> **A REDIGIR** — comparar a lista de estratos com maior desalento com a de maior desocupação (Tabelas 2 e 11) e dizer se coincidem. Quando desalento alto convive com desocupação baixa, a taxa de desemprego daquele território está subestimando o problema.

#### 3.5.2 Jovens que não trabalham nem estudam

24,3% dos jovens piauienses de 14 a 29 anos não
trabalhavam nem estudavam. A incidência variou de
13,5% em estrato 2210012 a
49,8% em estrato 2251022.

**Tabela 21** — Jovens de 14 a 29 anos que não trabalham nem estudam, por
recorte geográfico — 2º trimestre de 2026

| Recorte | Categoria | Estimativa (%) | IC 95% | CV (%) | Precisão |
|---|---|---:|:---:|---:|---|
| Agregados | Brasil | 17,9 | [17,6; 18,2] | 0,9 | excelente |
| Agregados | Nordeste | 24,5 | [23,9; 25,1] | 1,3 | excelente |
| Agregados | Piauí | 24,3 | [22,3; 26,2] | 4,1 | excelente |
| Agregados | Teresina | 17,7 | [14,5; 20,9] | 9,2 | boa |
| Zona | Urbana | 20,6 | [18,4; 22,9] | 5,6 | boa |
| Zona | Rural | 33,4 | [29,7; 37,1] | 5,7 | boa |
| Administrativo | Capital | 17,7 | [14,5; 20,9] | 9,2 | boa |
| Administrativo | Resto da RIDE | 31,5 | [26,1; 37,0] | 8,8 | boa |
| Administrativo | Resto da UF | 26,2 | [23,7; 28,7] | 4,9 | excelente |
| Estrato agregado | Teresina | 17,7 | [14,5; 20,9] | 9,2 | boa |
| Estrato agregado | Entorno metropolitano | 31,5 | [26,1; 37,0] | 8,8 | boa |
| Estrato agregado | Centro-Leste | 25,6 | [22,2; 29,0] | 6,7 | boa |
| Estrato agregado | Baixo Parnaíba | 24,5 | [20,9; 28,0] | 7,3 | boa |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | 30,2 | [23,1; 37,3] | 12,0 | boa |
| Estrato (7 dígitos) | maior: 2251022 | 49,8 | [35,5; 64,1] | 14,7 | boa |
| Estrato (7 dígitos) | menor: 2210012 | 13,5 | [6,9; 20,1] | 24,9 | regular |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Tabela 22** — Jovens de 14 a 29 anos que não trabalham nem estudam, diferença entre as categorias de cada recorte — 2º trimestre de 2026

| Recorte | p-valor | p ajustado | Significativo a 5%? |
|---|---:|---:|:---:|
| Zona (urbana × rural) | < 0,001 | < 0,001 | sim |
| Estrato administrativo | < 0,001 | < 0,001 | sim |
| Estrato agregado | < 0,001 | 0,001 | sim |
| Estrato (7 dígitos) | 0,540 | 0,555 | não |
| Teresina × resto do Piauí | < 0,001 | < 0,001 | sim |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Figura 13** — Percentual de jovens de 14 a 29 anos que não trabalham nem
estudam — 2º trimestre de 2026

![](./output/figuras/comp_geo_Taxa_Nem_Nem.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

> **A REDIGIR** — o que a amplitude entre os estratos extremos significa para a próxima década de oferta de trabalho no estado.

> **A REDIGIR** — bloco demográfico dos nem-nem — é o recorte em que a diferença por sexo costuma ser mais acentuada, por conta do trabalho doméstico e de cuidado não remunerado. Incluir só se significativo E com CV abaixo de 15% em todas as subdivisões.

#### 3.5.3 Motivos para não procurar trabalho

Estes são os indicadores mais frágeis do relatório em termos de precisão: são
proporções calculadas sobre um subconjunto já pequeno — os desalentados, ou os
jovens nem-nem — e depois repartidas entre várias categorias de resposta. É
normal que a maioria das células apareça com CV alto nos estratos mais finos, e
elas devem ser lidas como indicativas, não conclusivas. Incluimos elas pois são importantissimos
para distinguir quem desistiu de procurar emprego por baixar perspectivas de emprego na região, por obrigações domésticas ou por apenas desinteresse.

**Figura 14** — Motivo declarado da desistência, entre os desalentados —
2º trimestre de 2026

![](./output/figuras/comp_geo_Motivo_Desistencia_Desalentado.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Figura 15** — Motivo de não ter procurado trabalho, entre os jovens nem-nem —
2º trimestre de 2026

![](./output/figuras/comp_geo_Motivo_Nao_Procura_NemNem.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Figura 16** — Motivo de não ter iniciado trabalho, entre os jovens nem-nem —
2º trimestre de 2026

![](./output/figuras/comp_geo_Motivo_Nao_Inicio_NemNem.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Tabela 23** — Motivo da desistência entre os desalentados, por recorte
geográfico — 2º trimestre de 2026

| Recorte | Categoria | Motivo | Estimativa (%) | IC 95% | CV (%) | Precisão |
|---|---|---|---:|:---:|---:|---|
| Agregados | Brasil | Não havia trabalho na localidade | 55,8 | ( 53,8, 57,8 ) | 1,8 | excelente |
| Agregados | Nordeste | Não havia trabalho na localidade | 67,5 | ( 65,2, 69,7 ) | 1,7 | excelente |
| Agregados | Piauí | Não havia trabalho na localidade | 73,1 | ( 64,8, 81,5 ) | 5,8 | boa |
| Agregados | Teresina | Não havia trabalho na localidade | 42,1 | ( 21,9, 62,3 ) | 24,5 | regular |
| Zona | Urbana | Não havia trabalho na localidade | 54,9 | ( 36,9, 72,9 ) | 16,7 | regular |
| Zona | Rural | Não havia trabalho na localidade | 84,6 | ( 78,2, 90,9 ) | 3,8 | excelente |
| Administrativo | Capital | Não havia trabalho na localidade | 42,1 | ( 21,9, 62,3 ) | 24,5 | regular |
| Administrativo | Resto da RIDE | Não havia trabalho na localidade | 57,4 | ( 0,9, 113,8 ) | 50,2 | baixa |
| Administrativo | Resto da UF | Não havia trabalho na localidade | 74,6 | ( 66,1, 83,0 ) | 5,8 | boa |
| Estrato agregado | Teresina | Não havia trabalho na localidade | 42,1 | ( 21,9, 62,3 ) | 24,5 | regular |
| Estrato agregado | Entorno metropolitano | Não havia trabalho na localidade | 57,4 | ( 0,9, 113,8 ) | 50,2 | baixa |
| Estrato agregado | Centro-Leste | Não havia trabalho na localidade | 79,7 | ( 70,5, 88,9 ) | 5,9 | boa |
| Estrato agregado | Baixo Parnaíba | Não havia trabalho na localidade | 56,2 | ( 37,0, 75,4 ) | 17,5 | regular |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | Não havia trabalho na localidade | 85,7 | ( 72,4, 98,9 ) | 7,9 | boa |
| Estrato (7 dígitos) | maior: 2220020 | Não havia trabalho na localidade | 100,0 | ( 100,0, 100,0 ) | 0,0 | excelente |
| Estrato (7 dígitos) | menor: 2252022 | Não havia trabalho na localidade | 32,2 | ( 31,5, 32,9 ) | 1,2 | excelente |
| Agregados | Brasil | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Agregados | Nordeste | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Agregados | Piauí | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Agregados | Teresina | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Zona | Urbana | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Zona | Rural | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Administrativo | Capital | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Administrativo | Resto da RIDE | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Administrativo | Resto da UF | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Estrato agregado | Teresina | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Estrato agregado | Entorno metropolitano | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Estrato agregado | Centro-Leste | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Estrato agregado | Baixo Parnaíba | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Estrato (7 dígitos) | maior: 2210011 | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Estrato (7 dígitos) | menor: 2254020 | Tinha que cuidar dos afazeres domésticos | 0,0 | ( 0,0, 0,0 ) | — | — |
| Agregados | Brasil | Não conseguia trabalho adequado | 28,2 | ( 26,4, 30,0 ) | 3,2 | excelente |
| Agregados | Nordeste | Não conseguia trabalho adequado | 23,2 | ( 21,1, 25,2 ) | 4,5 | excelente |
| Agregados | Piauí | Não conseguia trabalho adequado | 21,8 | ( 13,5, 30,1 ) | 19,4 | regular |
| Agregados | Teresina | Não conseguia trabalho adequado | 29,2 | ( 9,3, 49,1 ) | 34,7 | baixa |
| Zona | Urbana | Não conseguia trabalho adequado | 37,1 | ( 19,0, 55,2 ) | 24,9 | regular |
| Zona | Rural | Não conseguia trabalho adequado | 12,2 | ( 6,2, 18,2 ) | 25,1 | regular |
| Administrativo | Capital | Não conseguia trabalho adequado | 29,2 | ( 9,3, 49,1 ) | 34,7 | baixa |
| Administrativo | Resto da RIDE | Não conseguia trabalho adequado | 42,6 | ( 0,0, 99,1 ) | 67,6 | baixa |
| Administrativo | Resto da UF | Não conseguia trabalho adequado | 20,9 | ( 12,6, 29,2 ) | 20,3 | regular |
| Estrato agregado | Teresina | Não conseguia trabalho adequado | 29,2 | ( 9,3, 49,1 ) | 34,7 | baixa |
| Estrato agregado | Entorno metropolitano | Não conseguia trabalho adequado | 42,6 | ( 0,0, 99,1 ) | 67,6 | baixa |
| Estrato agregado | Centro-Leste | Não conseguia trabalho adequado | 18,3 | ( 9,4, 27,2 ) | 24,7 | regular |
| Estrato agregado | Baixo Parnaíba | Não conseguia trabalho adequado | 34,5 | ( 13,8, 55,3 ) | 30,6 | baixa |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | Não conseguia trabalho adequado | 10,3 | ( 0,0, 21,2 ) | 53,5 | baixa |
| Estrato (7 dígitos) | maior: 2252011 | Não conseguia trabalho adequado | 72,3 | ( 31,0, 113,7 ) | 29,1 | regular |
| Estrato (7 dígitos) | menor: 2210020 | Não conseguia trabalho adequado | 65,9 | ( 31,2, 100,6 ) | 26,9 | regular |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Nota: mostra apenas as categorias "Não havia trabalho na localidade", "Tinha
que cuidar dos afazeres domésticos, do(s) filho(s) ou de outro(s) parente(s)"
e "Não conseguia trabalho adequado", independentemente do CV — as demais
categorias de V4074A não entram nesta tabela.

> **A REDIGIR** — comparar o peso das três categorias entre os territórios — "não havia trabalho na localidade" e "não conseguia trabalho adequado" são causas do lado da oferta (falta de vaga, ou vaga incompatível), enquanto "tinha que cuidar dos afazeres domésticos" é do lado da demanda por cuidado; são diagnósticos que pedem políticas diferentes.

**Tabela 24** — Distribuição dos motivos declarados, jovens que não procuraram
trabalho — 2º trimestre de 2026

| Motivo declarado | Participação (%) | IC 95% | CV (%) | Precisão |
|---|---:|:---:|---:|---|
| Tinha que cuidar dos afazeres domésticos, do(s) filho(s) ou de outro(s) parente(s) | 43,2 | [ 37,6, 48,9 ) | 6,7 | boa |
| Por problema de saúde ou gravidez | 18,5 | [ 14,7, 22,3 ) | 10,5 | boa |
| Estava estudando | 6,9 | [ 4,7, 9,0 ) | 16,0 | regular |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

> **A REDIGIR** — nomear o motivo mais frequente da tabela acima e dizer que política pública ele aponta — falta de vaga pede uma coisa, incompatibilidade de qualificação pede outra.

**Tabela 25** — Motivo de não ter iniciado trabalho entre os jovens nem-nem,
por recorte geográfico — 2º trimestre de 2026

| Recorte | Categoria | Motivo | Estimativa (%) | IC 95% | CV (%) | Precisão |
|---|---|---|---:|:---:|---:|---|
| Agregados | Brasil | Por não querer trabalhar | 13,7 | ( 12,8, 14,6 ) | 3,3 | excelente |
| Agregados | Nordeste | Por não querer trabalhar | 12,3 | ( 10,9, 13,7 ) | 5,7 | boa |
| Agregados | Piauí | Por não querer trabalhar | 7,6 | ( 4,2, 11,0 ) | 22,8 | regular |
| Agregados | Teresina | Por não querer trabalhar | 4,7 | ( 0,0, 11,8 ) | 77,7 | baixa |
| Zona | Urbana | Por não querer trabalhar | 8,0 | ( 3,4, 12,5 ) | 29,1 | regular |
| Zona | Rural | Por não querer trabalhar | 6,9 | ( 2,5, 11,4 ) | 32,7 | baixa |
| Administrativo | Capital | Por não querer trabalhar | 4,7 | ( 0,0, 11,8 ) | 77,7 | baixa |
| Administrativo | Resto da RIDE | Por não querer trabalhar | 11,4 | ( 0,5, 22,2 ) | 48,8 | baixa |
| Administrativo | Resto da UF | Por não querer trabalhar | 8,1 | ( 4,2, 12,1 ) | 24,9 | regular |
| Estrato agregado | Teresina | Por não querer trabalhar | 4,7 | ( 0,0, 11,8 ) | 77,7 | baixa |
| Estrato agregado | Entorno metropolitano | Por não querer trabalhar | 11,4 | ( 0,5, 22,2 ) | 48,8 | baixa |
| Estrato agregado | Centro-Leste | Por não querer trabalhar | 10,0 | ( 2,1, 17,9 ) | 40,3 | baixa |
| Estrato agregado | Baixo Parnaíba | Por não querer trabalhar | 6,6 | ( 1,4, 11,7 ) | 40,2 | baixa |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | Por não querer trabalhar | 8,7 | ( 0,0, 19,9 ) | 66,1 | baixa |
| Estrato (7 dígitos) | maior: 2210013 | Por não querer trabalhar | 60,6 | ( 0,0, 136,1 ) | 63,5 | baixa |
| Estrato (7 dígitos) | menor: 2254020 | Por não querer trabalhar | 0,0 | ( 0,0, 0,0 ) | — | — |
| Agregados | Brasil | Tinha que cuidar dos afazeres domésticos | 47,3 | ( 46,1, 48,4 ) | 1,2 | excelente |
| Agregados | Nordeste | Tinha que cuidar dos afazeres domésticos | 51,4 | ( 49,7, 53,2 ) | 1,8 | excelente |
| Agregados | Piauí | Tinha que cuidar dos afazeres domésticos | 56,5 | ( 49,9, 63,1 ) | 6,0 | boa |
| Agregados | Teresina | Tinha que cuidar dos afazeres domésticos | 49,6 | ( 39,2, 60,0 ) | 10,7 | boa |
| Zona | Urbana | Tinha que cuidar dos afazeres domésticos | 52,2 | ( 44,2, 60,2 ) | 7,8 | boa |
| Zona | Rural | Tinha que cuidar dos afazeres domésticos | 63,5 | ( 52,2, 74,8 ) | 9,1 | boa |
| Administrativo | Capital | Tinha que cuidar dos afazeres domésticos | 49,6 | ( 39,2, 60,0 ) | 10,7 | boa |
| Administrativo | Resto da RIDE | Tinha que cuidar dos afazeres domésticos | 60,3 | ( 39,4, 81,2 ) | 17,7 | regular |
| Administrativo | Resto da UF | Tinha que cuidar dos afazeres domésticos | 58,4 | ( 49,8, 66,9 ) | 7,5 | boa |
| Estrato agregado | Teresina | Tinha que cuidar dos afazeres domésticos | 49,6 | ( 39,2, 60,0 ) | 10,7 | boa |
| Estrato agregado | Entorno metropolitano | Tinha que cuidar dos afazeres domésticos | 60,3 | ( 39,4, 81,2 ) | 17,7 | regular |
| Estrato agregado | Centro-Leste | Tinha que cuidar dos afazeres domésticos | 51,6 | ( 36,8, 66,4 ) | 14,6 | boa |
| Estrato agregado | Baixo Parnaíba | Tinha que cuidar dos afazeres domésticos | 57,0 | ( 43,8, 70,2 ) | 11,8 | boa |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | Tinha que cuidar dos afazeres domésticos | 69,8 | ( 55,3, 84,3 ) | 10,6 | boa |
| Estrato (7 dígitos) | maior: 2251022 | Tinha que cuidar dos afazeres domésticos | 100,0 | ( 100,0, 100,0 ) | 0,0 | excelente |
| Estrato (7 dígitos) | menor: 2252011 | Tinha que cuidar dos afazeres domésticos | 50,5 | ( 26,1, 74,8 ) | 24,6 | regular |
| Agregados | Brasil | Por problema de saúde ou gravidez | 20,5 | ( 19,4, 21,5 ) | 2,7 | excelente |
| Agregados | Nordeste | Por problema de saúde ou gravidez | 20,1 | ( 18,9, 21,4 ) | 3,1 | excelente |
| Agregados | Piauí | Por problema de saúde ou gravidez | 26,3 | ( 21,1, 31,4 ) | 10,0 | boa |
| Agregados | Teresina | Por problema de saúde ou gravidez | 20,6 | ( 13,1, 28,1 ) | 18,6 | regular |
| Zona | Urbana | Por problema de saúde ou gravidez | 26,5 | ( 20,0, 33,0 ) | 12,5 | boa |
| Zona | Rural | Por problema de saúde ou gravidez | 25,8 | ( 17,1, 34,6 ) | 17,3 | regular |
| Administrativo | Capital | Por problema de saúde ou gravidez | 20,6 | ( 13,1, 28,1 ) | 18,6 | regular |
| Administrativo | Resto da RIDE | Por problema de saúde ou gravidez | 20,1 | ( 4,9, 35,2 ) | 38,5 | baixa |
| Administrativo | Resto da UF | Por problema de saúde ou gravidez | 28,6 | ( 22,0, 35,2 ) | 11,8 | boa |
| Estrato agregado | Teresina | Por problema de saúde ou gravidez | 20,6 | ( 13,1, 28,1 ) | 18,6 | regular |
| Estrato agregado | Entorno metropolitano | Por problema de saúde ou gravidez | 20,1 | ( 4,9, 35,2 ) | 38,5 | baixa |
| Estrato agregado | Centro-Leste | Por problema de saúde ou gravidez | 34,7 | ( 22,8, 46,6 ) | 17,5 | regular |
| Estrato agregado | Baixo Parnaíba | Por problema de saúde ou gravidez | 30,9 | ( 19,4, 42,3 ) | 19,0 | regular |
| Estrato agregado | Alto Parnaíba e Chapadas Sul | Por problema de saúde ou gravidez | 16,4 | ( 4,8, 28,0 ) | 36,0 | baixa |
| Estrato (7 dígitos) | maior: 2252011 | Por problema de saúde ou gravidez | 46,4 | ( 22,0, 70,8 ) | 26,8 | regular |
| Estrato (7 dígitos) | menor: 2210011 | Por problema de saúde ou gravidez | 20,9 | ( 10,7, 31,2 ) | 25,0 | regular |

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Nota: mostra apenas as categorias "Por não querer trabalhar", "Tinha que
cuidar dos afazeres domésticos, do(s) filho(s) ou de outro(s) parente(s)" e
"Por problema de saúde ou gravidez", independentemente do CV — as demais
categorias de V4078A não entram nesta tabela.

> **A REDIGIR** — comparar o peso das três categorias entre os territórios — "tinha que cuidar dos afazeres domésticos" e "por problema de saúde ou gravidez" são impedimentos, enquanto "não queria trabalhar" é desinteresse declarado; tratar as duas primeiras como a mesma coisa que "não queria trabalhar" seria um erro de leitura.

### 3.6 Síntese: onde as diferenças são estatisticamente significativas

Esta subseção reúne, em um único quadro, o resultado dos testes aplicados ao
longo da seção. A pergunta que ela responde é: para cada indicador, quais
recortes territoriais produzem diferenças que não se explicam por acaso
amostral?

**Tabela 26** — Testes de diferença entre categorias, por indicador e recorte
geográfico — 2º trimestre de 2026

| Indicador | Zona | Estrato administrativo | Estrato agregado | Estrato (7 díg.) | Teresina × resto |
|---|:---:|:---:|:---:|:---:|:---:|
| Taxa de desocupação | \* | \*\*\* | \*\* | — | ns |
| Responsáveis desocupados | ns | ns | \* | — | \* |
| Responsáveis ou cônjuges desocupados | ns | \*\* | ns | — | \*\*\* |
| Rendimento médio habitual | \*\*\* | \*\*\* | \*\*\* | \*\*\* | \*\*\* |
| Sub-remuneração | \*\*\* | \*\*\* | \*\*\* | ns | \*\*\* |
| Taxa de informalidade | \*\*\* | \*\*\* | \*\*\* | ns | \*\*\* |
| Sub-ocupação | \*\*\* | \*\*\* | \*\*\* | ns | \*\*\* |
| Ocupados com médio completo ou mais | \*\*\* | \*\*\* | \*\*\* | \* | \*\*\* |
| Desalentados (força ampliada) | \*\*\* | \*\*\* | \*\*\* | ns | \*\*\* |
| Desalentados (fora da força) | \*\*\* | \*\*\* | \*\*\* | ns | \*\*\* |
| Jovens nem-nem | \*\*\* | \*\*\* | \*\* | ns | \*\*\* |

Legenda: \*\*\* p < 0,001; \*\* p < 0,01; \* p < 0,05; ns = não significativo;
— = o teste não se sustenta nessa resolução (ver adiante). Os símbolos
referem-se ao **p-valor ajustado** para multiplicidade; a tabela completa, com
os p-valores brutos ao lado, está no anexo metodológico.

Duas leituras saltam da tabela. A primeira: **quase tudo difere entre territórios**. Nas quatro colunas em que
o teste se sustenta, a esmagadora maioria das células traz três asteriscos. O
Piauí não é homogêneo em praticamente nenhuma das dimensões medidas — e a
coluna "Teresina × resto" mostra que a capital se destaca do estado em dez dos
onze indicadores.

A segunda é mais sutil e diz respeito ao **tipo** de indicador. Os três
primeiros — desocupação e suas variantes por posição no domicílio — são os
únicos que oscilam entre significativo e não significativo conforme o recorte.
Todos os demais, ligados a **renda, informalidade e escolaridade**, são
significativos em todos os cortes territoriais disponíveis. A diferença é
substantiva: estar desempregado é uma condição relativamente distribuída pelo
estado, enquanto *quanto se ganha e sob que vínculo* depende fortemente de onde
se mora.

Em relação a coluna do estrato de 7 dígitos.** Três indicadores trazem "—". Não
são resultados omitidos por conveniência: nesse recorte, com 26 categorias e
estratos de até 3 UPAs, a matriz de covariância replicada perde posto e o
p-valor que sairia dali seria enviesado para encontrar diferença (seção 6.5 do
anexo). No caso da taxa de desocupação o posto cai para 1 de 26 — o teste
simplesmente não existe. A leitura desses três indicadores no nível mais fino
deve se apoiar nos intervalos de confiança das tabelas anteriores, não em
teste de hipótese. Onde o teste se sustenta no recorte fino, ele é conservador:
apenas rendimento médio e escolaridade dos ocupados discriminam entre os 26
estratos.

**Figura 17** — p-valores dos testes de diferença entre categorias, por
indicador e recorte regional — 2º trimestre de 2026

![](./output/figuras/anova_regional_2026T2.png)

Fonte: `output/tabelas/anova_regional_2026T2.csv`. Elaboração própria.


> **A REDIGIR** — dizer quantos testes regionais foram realizados, quantos deram significativos pelo p-valor bruto e quantos sobreviveram ao ajuste (os três números saem no console ao rodar o pipeline), e indicar quais recortes discriminam mais e quais indicadores são mais homogêneos no território.

Duas observações que a leitura desta tabela exige. A significância estatística não é relevância prática.** Uma diferença pode ser estatisticamente sólida e pequena demais para orientar política pública; e um
recorte com poucas observações pode não atingir significância diante de uma
diferença real e grande, por falta de amostra.

## 4 Considerações finais

> **A REDIGIR** — síntese geral em três a cinco parágrafos, retomando (i) o quadro do Piauí frente a Brasil e Nordeste; (ii) o eixo capital-interior; (iii) o eixo urbano-rural; (iv) as dimensões em que o estado é mais homogêneo; (v) o que mudou em relação ao trimestre anterior.

> **A REDIGIR** — ressalvas de encerramento — repetir que as estatísticas por estrato são experimentais e que estimativas com CV acima de 15% não sustentam conclusão.
