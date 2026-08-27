<!-- @somente-modelo -->
> **ESTE ARQUIVO É O MODELO — NÃO É UM RELATÓRIO PRONTO.** 
> Ele serve para gerar o relatório dos resultados em `output/relatorio_trimestral_<AAAAT#>.md` (ex.:
> `relatorio_trimestral_2026T2.md`) 
>
> **Como gerar a edição por trimestre.** 
> Rode `Rscript R/09_preencher_relatorio.R`, que lê
> as saídas do pipeline (`R/01_pipeline_trimestral.R` e
> `R/03_comparacoes_indicadores.R` já executados) e grava o arquivo acima.
> Este modelo aqui nunca é sobrescrito — é o mesmo texto-base reaproveitado a
> cada trimestre. Este aviso em si some na edição gerada; o resto do arquivo é
> o texto-base que vale para qualquer trimestre.
>
> Duas construções são resolvidas pelo script: as diretivas
> `<!-- @tabela ... -->`, que viram tabelas inteiras, e as expressões
> `\{\{est Indicador Geografia\}\}`, que viram números. Uma terceira,
> `<!-- @redigir: ... -->`, marca o que depende da interpretação do autor (você) e sai no
> arquivo gerado como um bloco **A REDIGIR**.
>
> Atualmente. O script FALHA se sobrar qualquer marcador não resolvido, de propósito.
>
> **Regra que decide o que entra no corpo do texto para um recorte demográfico** 
> Um recorte demográfico só inserio no corpo do texto se:
> - *naquele recorte geográfico* a diferença for significativa **pelo p-valor ajustado** (coluna `p_ajustado` que corrige o volume de comparações); e
> -  o CV ficar abaixo de 15% em **todas** as categorias demográficas e em **todas** as categorias geográficas do recorte.
>
> Basta uma célula acima de 15% para o recorte inteiro sair do corpo do texto e
> ir para o anexo metodológico. A regra é conservadora de propósito: comentar
> uma diferença entre homens e mulheres que só aparece em metade dos estratos —
> e some na outra metade por imprecisão amostral — leva a interpretações imprecisas.


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

O Piauí registrou taxa de desocupação de {{est Taxa_Desocupacao Piauí}}%, ante
{{est Taxa_Desocupacao Nordeste}}% no Nordeste e {{est Taxa_Desocupacao Brasil}}%
no Brasil. Dentro do estado, a distância entre o estrato com maior e menor
desocupação foi de {{amplitude Taxa_Desocupacao}} pontos percentuais, separando
{{extremo Taxa_Desocupacao max rotulo}} ({{extremo Taxa_Desocupacao max valor}}%)
de {{extremo Taxa_Desocupacao min rotulo}} ({{extremo Taxa_Desocupacao min valor}}%).

**Tabela 2** — Taxa de desocupação, por recorte geográfico — {{trimestre}}

<!-- @tabela tipo=geografica indicador=Taxa_Desocupacao -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Nota: os {{n_estratos}} estratos de 7 dígitos aparecem na íntegra no anexo
metodológico; aqui são exibidos apenas os extremos.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Taxa_Desocupacao -->

![Taxa de desocupação por recorte geográfico](./output/figuras/comp_geo_Taxa_Desocupacao.png)

**Figura 1** — Taxa de desocupação por recorte geográfico, com intervalo de
confiança de 95% — {{trimestre}}

{{#se-significativo Taxa_Desocupacao Teresina_x_Resto_Piaui}}A diferença entre
Teresina e o restante do estado é estatisticamente significativa (p ajustado =
{{p Taxa_Desocupacao Teresina_x_Resto_Piaui}}), o que confirma, para este
trimestre, a leitura já apresentada na introdução: a capital opera em um
patamar distinto do resto do Piauí.{{/se}}
{{#se-nao-significativo Taxa_Desocupacao Teresina_x_Resto_Piaui}}A diferença
entre Teresina e o restante do estado não alcançou significância estatística
neste trimestre (p ajustado = {{p Taxa_Desocupacao Teresina_x_Resto_Piaui}}), o
que recomenda cautela antes de tratá-la como um padrão consolidado.{{/se}}

A comparação entre zona urbana e rural merece atenção específica, porque a
desocupação rural costuma ser estruturalmente mais baixa: parte da população ocupada na agricultura familiar não procura, e muitas vezes se ocupam mais com produção por subsistência (verificar esse mecanismo)
trabalho no sentido que a pesquisa capta, e por isso não é contada como
desocupada. Neste trimestre a diferença foi de {{dif Taxa_Desocupacao Zona_Urbana Zona_Rural}}
pontos ({{estrelas Taxa_Desocupacao Zona}}).

<!-- @redigir: bloco demográfico da desocupação — incluir só se o recorte for significativo E o CV ficar abaixo de 15% em TODAS as subdivisões de cada corte geográfico (ver anexo §5.3). Consultar output/tabelas/comparacao_demografica_<sufixo>.csv. -->

#### 3.2.2 Desocupação da pessoa responsável pelo domicílio

Este indicador mede quanto dos desocupados são pessoas responsáveis pelo
domicílio. Uma taxa de desocupação alta concentrada em jovens que moram com os
pais tem um significado social muito diferente da mesma taxa concentrada em
quem sustenta a casa.

Em {{extremo Chefes_Familia_Desocupados max rotulo}},
{{extremo Chefes_Familia_Desocupados max valor}}% dos desocupados eram
responsáveis pelo domicílio, contra {{extremo Chefes_Familia_Desocupados min valor}}%
em {{extremo Chefes_Familia_Desocupados min rotulo}}.

**Tabela 3** — Pessoas responsáveis pelo domicílio entre os desocupados, por
recorte geográfico — {{trimestre}}

<!-- @tabela tipo=geografica indicador=Chefes_Familia_Desocupados -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Chefes_Familia_Desocupados -->

![Responsáveis pelo domicílio entre os desocupados](./output/figuras/comp_geo_Chefes_Familia_Desocupados.png)

**Figura 2** — Pessoas responsáveis pelo domicílio entre os desocupados —
{{trimestre}}

<!-- @redigir: uma ou duas frases interpretando o contraste acima — o que significa, para o orçamento das famílias daquele estrato, essa concentração. -->

#### 3.2.3 Desocupação de quem contribui para a renda do domicílio

Amplia o indicador anterior para incluir o cônjuge ou companheiro(a), captando
não apenas quem é formalmente o responsável pelo domicílio mas o conjunto de
adultos de quem a renda da casa depende diretamente.

No Piauí, {{est Conribuintes_Desocupados Piauí}}% dos desocupados eram
responsáveis pelo domicílio ou cônjuges, contra
{{est Chefes_Familia_Desocupados Piauí}}% apenas de responsáveis — a diferença
corresponde aos cônjuges desocupados.

**Tabela 4** — Responsáveis ou cônjuges entre os desocupados, por recorte
geográfico — {{trimestre}}

<!-- @tabela tipo=geografica indicador=Conribuintes_Desocupados -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Conribuintes_Desocupados -->

![Responsáveis ou cônjuges entre os desocupados](./output/figuras/comp_geo_Conribuintes_Desocupados.png)

**Figura 3** — Responsáveis ou cônjuges entre os desocupados — {{trimestre}}

<!-- @redigir: o que essa diferença diz sobre o arranjo de sustento das famílias do estado. -->

### 3.3 Rendimento

#### 3.3.1 Rendimento médio real habitual

No Piauí, {{est Conribuintes_Desocupados Piauí}}% dos desocupados eram
responsáveis pelo domicílio ou cônjuges, contra
{{est Chefes_Familia_Desocupados Piauí}}% apenas de responsáveis — a diferença
corresponde aos cônjuges desocupados.

**Tabela 5** — Rendimento médio real habitualmente recebido em todos os
trabalhos, por recorte geográfico — {{trimestre}}

<!-- @tabela tipo=geografica indicador=Rendimento_Medio_Habitual -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Nota: valores deflacionados para reais do último trimestre da série.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Rendimento_Medio_Habitual -->

![Rendimento médio habitual por recorte geográfico](./output/figuras/comp_geo_Rendimento_Medio_Habitual.png)

**Figura 4** — Rendimento médio real habitual por recorte geográfico —
{{trimestre}}

Ressalta-se que a média de rendimento  é sensível a valores muito altos e, em territórios pequenos, um punhado de rendimentos
elevados desloca o resultado inteiro. A distribuição completa dos rendimentos
por estrato está no anexo metodológico, e é ela que revela se a média
representa a maioria ou é puxada pela cauda.

<!-- @redigir: bloco demográfico do rendimento médio — incluir só se significativo E com CV abaixo de 15% em todas as subdivisões de cada corte geográfico. -->

#### 3.3.2 Sub-remuneração

Mede o percentual de ocupados que, dividido o que recebem pelas horas que
trabalham, ganham menos que o salário mínimo por hora — hoje R$ {{sm_hora}}.
{{est Percentual_Subremuneracao Piauí}}% dos ocupados do Piauí recebiam abaixo
do mínimo por hora. A incidência foi de
{{extremo Percentual_Subremuneracao max valor}}% em
{{extremo Percentual_Subremuneracao max rotulo}} e
{{extremo Percentual_Subremuneracao min valor}}% em
{{extremo Percentual_Subremuneracao min rotulo}}.

**Tabela 6** — Sub-remuneração por hora trabalhada, por recorte geográfico —
{{trimestre}}

<!-- @tabela tipo=geografica indicador=Percentual_Subremuneracao -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Percentual_Subremuneracao -->

![Sub-remuneração por recorte geográfico](./output/figuras/comp_geo_Percentual_Subremuneracao.png)

**Figura 5** — Percentual de ocupados com rendimento-hora abaixo do salário
mínimo horário — {{trimestre}}

<!-- @redigir: o que a distância entre esses dois extremos sugere sobre a estrutura produtiva dos territórios envolvidos. -->

#### 3.3.3 Desigualdade entre formais e informais

O indicador é a razão entre o rendimento médio dos ocupados formais e o dos
informais. Um valor de 2,0 significa que o trabalhador formal ganha, em média,
o dobro do informal. A razão formal/informal no Piauí foi de {{desigualdade Piauí razao}} — ou seja,
o trabalhador com carteira ganhou, em média, {{pct_a_mais Piauí}}% a mais que o
informal: {{desigualdade Piauí formal}} contra {{desigualdade Piauí informal}}.
Entre os estratos, a razão foi mais alta em {{desig_extremo max rotulo}}
({{desig_extremo max valor}}) e mais baixa em {{desig_extremo min rotulo}}
({{desig_extremo min valor}}).

**Tabela 7** — Rendimento médio por situação de formalidade e razão
formal/informal, por recorte geográfico — {{trimestre}}

<!-- @tabela tipo=formalidade -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Dados: `output/desigualdade_formal_informal_{{sufixo}}.csv`.

Nota de leitura sobre o intervalo desta tabela: ao contrário dos demais, ele é
**assimétrico** em torno da estimativa. Isso é intencional e correto — uma
razão não pode ser negativa, e o intervalo é construído na escala logarítmica
antes de voltar à escala da razão. O anexo metodológico (§4.4) detalha o
procedimento.

![Rendimento no setor formal](./output/figuras/comp_geo_Rendimento_Formal.png)

**Figura 6** — Rendimento médio dos ocupados formais — {{trimestre}}

![Rendimento no setor informal](./output/figuras/comp_geo_Rendimento_Informal.png)

**Figura 7** — Rendimento médio dos ocupados informais — {{trimestre}}

Vale contrastar com a capital: em Teresina a razão foi de
{{desigualdade Teresina razao}}, a mais baixa entre os recortes agregados — não
porque o formal pague pouco ali, mas porque o informal teresinense ganha
{{desigualdade Teresina informal}}, bem acima do informal do interior.

Duas leituras opostas produzem o mesmo número baixo, e vale distingui-las. Uma
razão próxima de 1 pode significar que o mercado formal daquele território não
paga muito melhor que o informal — o que é má notícia, e costuma indicar que a
formalização se concentra em ocupações de baixa remuneração. Mas pode também
significar que o mercado informal ali é relativamente bem pago, o que muda o
diagnóstico por completo. A comparação com os rendimentos absolutos das Figuras
6 e 7 é o que separa os dois casos.

<!-- @redigir: dizer qual dos dois casos se aplica aos estratos de razão mais baixa deste trimestre, olhando os rendimentos absolutos das Figuras 6 e 7. -->

### 3.4 Inserção no mercado de trabalho

#### 3.4.1 Taxa de informalidade

A informalidade no Piauí atingiu {{est Taxa_Informalidade Piauí}}% dos
ocupados, contra {{est Taxa_Informalidade Nordeste}}% no Nordeste e
{{est Taxa_Informalidade Brasil}}% no Brasil. A variação interna ao estado foi
de {{amplitude Taxa_Informalidade}} pontos, de
{{extremo Taxa_Informalidade min valor}}% em
{{extremo Taxa_Informalidade min rotulo}} a
{{extremo Taxa_Informalidade max valor}}% em
{{extremo Taxa_Informalidade max rotulo}}.

**Tabela 8** — Taxa de informalidade, por recorte geográfico — {{trimestre}}

<!-- @tabela tipo=geografica indicador=Taxa_Informalidade -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Taxa_Informalidade -->

![Taxa de informalidade por recorte geográfico](./output/figuras/comp_geo_Taxa_Informalidade.png)

**Figura 8** — Taxa de informalidade por recorte geográfico — {{trimestre}}

O contraste entre zona urbana e rural tende a ser o mais acentuado deste
indicador, e por razão estrutural: a produção agrícola familiar e o trabalho
por conta própria no campo são majoritariamente informais por natureza da
atividade, não por escolha do trabalhador. Neste trimestre a diferença foi de
{{dif Taxa_Informalidade Zona_Urbana Zona_Rural}} pontos
({{estrelas Taxa_Informalidade Zona}}).

<!-- @redigir: bloco demográfico da informalidade — incluir só se significativo E com CV abaixo de 15% em todas as subdivisões de cada corte geográfico. -->

#### 3.4.2 Sub-ocupação por insuficiência de horas

{{est Taxa_Subocupacao Piauí}}% dos ocupados do Piauí estavam subocupados, com
{{extremo Taxa_Subocupacao max valor}}% em {{extremo Taxa_Subocupacao max rotulo}}
e {{extremo Taxa_Subocupacao min valor}}% em {{extremo Taxa_Subocupacao min rotulo}}.

**Tabela 9** — Sub-ocupação por insuficiência de horas, por recorte geográfico
— {{trimestre}}

<!-- @tabela tipo=geografica indicador=Taxa_Subocupacao -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Taxa_Subocupacao -->

![Sub-ocupação por recorte geográfico](./output/figuras/comp_geo_Taxa_Subocupacao.png)

**Figura 9** — Percentual de ocupados subocupados por insuficiência de horas —
{{trimestre}}


<!-- @redigir: relacionar a subocupação com a informalidade do mesmo território — jornada insuficiente e vínculo precário costumam andar juntos, mas nem sempre. -->

#### 3.4.3 Escolaridade dos ocupados

{{extremo Proporcao_Ocupados_Escolarizados max valor}}% em
{{extremo Proporcao_Ocupados_Escolarizados max rotulo}} e
{{extremo Proporcao_Ocupados_Escolarizados min valor}}% em
{{extremo Proporcao_Ocupados_Escolarizados min rotulo}} — uma diferença de
{{amplitude Proporcao_Ocupados_Escolarizados}} pontos. Cabe uma cautela de leitura: este indicador mede a
escolaridade de quem *está ocupado*, não a da população. Um estrato pode
aparecer com escolaridade alta simplesmente porque os menos escolarizados não
encontraram trabalho, e não porque a população seja mais escolarizada.
**Tabela 10** — Ocupados com ensino médio completo ou mais, por recorte
geográfico — {{trimestre}}

<!-- @tabela tipo=geografica indicador=Proporcao_Ocupados_Escolarizados -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Proporcao_Ocupados_Escolarizados -->

![Ocupados com médio completo ou mais](./output/figuras/comp_geo_Proporcao_Ocupados_Escolarizados.png)

**Figura 10** — Percentual de ocupados com ensino médio completo ou mais —
{{trimestre}}

### 3.5 Desalento

O desalento atingiu {{est Desalentados_Forca_Ampliada Piauí}}% da força de
trabalho ampliada do Piauí, com {{extremo Desalentados_Forca_Ampliada max valor}}%
em {{extremo Desalentados_Forca_Ampliada max rotulo}} e
{{extremo Desalentados_Forca_Ampliada min valor}}% em
{{extremo Desalentados_Forca_Ampliada min rotulo}}. Entre as pessoas fora da
força de trabalho, os desalentados foram
{{est Desalentados_Fora_Forca Piauí}}% no estado.

#### 3.5.1 Percentual de desalentados

**Tabela 11** — Desalentados na força de trabalho ampliada, por recorte
geográfico — {{trimestre}}

<!-- @tabela tipo=geografica indicador=Desalentados_Forca_Ampliada -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Desalentados_Forca_Ampliada -->

![Desalentados na força ampliada](./output/figuras/comp_geo_Desalentados_Forca_Ampliada.png)

**Figura 11** — Percentual de desalentados na força de trabalho ampliada —
{{trimestre}}

![Desalentados fora da força de trabalho](./output/figuras/comp_geo_Desalentados_Fora_Forca.png)

**Figura 12** — Desalentados como percentual das pessoas fora da força de
trabalho — {{trimestre}}



A leitura conjunta com a taxa de desocupação é o que dá sentido ao indicador.

<!-- @redigir: comparar a lista de estratos com maior desalento com a de maior desocupação (Tabelas 2 e 11) e dizer se coincidem. Quando desalento alto convive com desocupação baixa, a taxa de desemprego daquele território está subestimando o problema. -->

#### 3.5.2 Jovens que não trabalham nem estudam

{{est Taxa_Nem_Nem Piauí}}% dos jovens piauienses de 14 a 29 anos não
trabalhavam nem estudavam. A incidência variou de
{{extremo Taxa_Nem_Nem min valor}}% em {{extremo Taxa_Nem_Nem min rotulo}} a
{{extremo Taxa_Nem_Nem max valor}}% em {{extremo Taxa_Nem_Nem max rotulo}}.

**Tabela 12** — Jovens de 14 a 29 anos que não trabalham nem estudam, por
recorte geográfico — {{trimestre}}

<!-- @tabela tipo=geografica indicador=Taxa_Nem_Nem -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Taxa_Nem_Nem -->

![Taxa de jovens nem-nem](./output/figuras/comp_geo_Taxa_Nem_Nem.png)

**Figura 13** — Percentual de jovens de 14 a 29 anos que não trabalham nem
estudam — {{trimestre}}

<!-- @redigir: o que a amplitude entre os estratos extremos significa para a próxima década de oferta de trabalho no estado. -->

<!-- @redigir: bloco demográfico dos nem-nem — é o recorte em que a diferença por sexo costuma ser mais acentuada, por conta do trabalho doméstico e de cuidado não remunerado. Incluir só se significativo E com CV abaixo de 15% em todas as subdivisões. -->

#### 3.5.3 Motivos para não procurar trabalho

Estes são os indicadores mais frágeis do relatório em termos de precisão: são
proporções calculadas sobre um subconjunto já pequeno — os desalentados, ou os
jovens nem-nem — e depois repartidas entre várias categorias de resposta. É
normal que a maioria das células apareça com CV alto nos estratos mais finos, e
elas devem ser lidas como indicativas, não conclusivas. Incluimos elas pois são importantissimos
para distinguir quem desistiu de procurar emprego por baixar perspectivas de emprego na região, por obrigações domésticas ou por apenas desinteresse.

![Motivo da desistência entre os desalentados](./output/figuras/comp_geo_Motivo_Desistencia_Desalentado.png)

**Figura 14** — Motivo declarado da desistência, entre os desalentados —
{{trimestre}}

![Motivo de não procurar trabalho entre os nem-nem](./output/figuras/comp_geo_Motivo_Nao_Procura_NemNem.png)

**Figura 15** — Motivo de não ter procurado trabalho, entre os jovens nem-nem —
{{trimestre}}

![Motivo de não iniciar trabalho entre os nem-nem](./output/figuras/comp_geo_Motivo_Nao_Inicio_NemNem.png)

**Figura 16** — Motivo de não ter iniciado trabalho, entre os jovens nem-nem —
{{trimestre}}

**Tabela 13** — Motivo da desistência entre os desalentados, por recorte
geográfico — {{trimestre}}

<!-- @tabela tipo=motivos-geografico indicador=Motivo_Desistencia_Desalentado -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Nota: mostra apenas as categorias "Não havia trabalho na localidade", "Tinha
que cuidar dos afazeres domésticos, do(s) filho(s) ou de outro(s) parente(s)"
e "Não conseguia trabalho adequado", independentemente do CV — as demais
categorias de V4074A não entram nesta tabela.

<!-- @redigir: comparar o peso das três categorias entre os territórios — "não havia trabalho na localidade" e "não conseguia trabalho adequado" são causas do lado da oferta (falta de vaga, ou vaga incompatível), enquanto "tinha que cuidar dos afazeres domésticos" é do lado da demanda por cuidado; são diagnósticos que pedem políticas diferentes. -->

**Tabela 14** — Distribuição dos motivos declarados, jovens que não procuraram
trabalho — {{trimestre}}

<!-- @tabela tipo=motivos indicador=Motivo_Nao_Procura_NemNem geografia=Piauí -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

<!-- @redigir: nomear o motivo mais frequente da tabela acima e dizer que política pública ele aponta — falta de vaga pede uma coisa, incompatibilidade de qualificação pede outra. -->

**Tabela 15** — Motivo de não ter iniciado trabalho entre os jovens nem-nem,
por recorte geográfico — {{trimestre}}

<!-- @tabela tipo=motivos-geografico indicador=Motivo_Nao_Inicio_NemNem -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Nota: mostra apenas as categorias "Por não querer trabalhar", "Tinha que
cuidar dos afazeres domésticos, do(s) filho(s) ou de outro(s) parente(s)" e
"Por problema de saúde ou gravidez", independentemente do CV — as demais
categorias de V4078A não entram nesta tabela.

<!-- @redigir: comparar o peso das três categorias entre os territórios — "tinha que cuidar dos afazeres domésticos" e "por problema de saúde ou gravidez" são impedimentos, enquanto "não queria trabalhar" é desinteresse declarado; tratar as duas primeiras como a mesma coisa que "não queria trabalhar" seria um erro de leitura. -->

### 3.6 Síntese: onde as diferenças são estatisticamente significativas

Esta subseção reúne, em um único quadro, o resultado dos testes aplicados ao
longo da seção. A pergunta que ela responde é: para cada indicador, quais
recortes territoriais produzem diferenças que não se explicam por acaso
amostral?

**Tabela 16** — Testes de diferença entre categorias, por indicador e recorte
geográfico — 2º trimestre de 2026

<!-- @tabela tipo=sintese -->

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
Fonte: `output/tabelas/anova_regional_{{sufixo}}.csv`. Elaboração própria.

![ANOVA regional](./output/figuras/anova_regional_{{sufixo}}.png)

**Figura 17** — p-valores dos testes de diferença entre categorias, por
indicador e recorte regional — {{trimestre}}

<!-- @redigir: dizer quantos testes regionais foram realizados, quantos deram significativos pelo p-valor bruto e quantos sobreviveram ao ajuste (os três números saem no console ao rodar o pipeline), e indicar quais recortes discriminam mais e quais indicadores são mais homogêneos no território. -->

Duas observações que a leitura desta tabela exige. A significância estatística não é relevância prática.** Uma diferença pode ser estatisticamente sólida e pequena demais para orientar política pública; e um
recorte com poucas observações pode não atingir significância diante de uma
diferença real e grande, por falta de amostra.

## 4 Considerações finais

<!-- @redigir: síntese geral em três a cinco parágrafos, retomando (i) o quadro do Piauí frente a Brasil e Nordeste; (ii) o eixo capital-interior; (iii) o eixo urbano-rural; (iv) as dimensões em que o estado é mais homogêneo; (v) o que mudou em relação ao trimestre anterior. -->

<!-- @redigir: ressalvas de encerramento — repetir que as estatísticas por estrato são experimentais e que estimativas com CV acima de 15% não sustentam conclusão. -->
