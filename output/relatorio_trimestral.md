<!-- @somente-modelo -->
> ⚠️ **ESTE ARQUIVO É O MODELO — NÃO É UM RELATÓRIO PRONTO.** Se você está
> vendo `{{chaves duplas}}` no meio do texto, você abriu o arquivo errado; isso
> é esperado *aqui*, e só aqui. A edição de cada trimestre, sem nenhuma chave
> visível, fica em `output/relatorio_trimestral_<AAAAT#>.md` (ex.:
> `relatorio_trimestral_2026T2.md`) — **é esse outro arquivo que se lê, se
> publica e se distribui.**
>
> **Como gerar a edição.** Rode `Rscript R/09_preencher_relatorio.R`, que lê
> as saídas do pipeline (`R/01_pipeline_trimestral.R` e
> `R/03_comparacoes_indicadores.R` já executados) e grava o arquivo acima.
> Este modelo aqui nunca é sobrescrito — é o mesmo texto-base reaproveitado a
> cada trimestre. Este aviso em si some na edição gerada; o resto do arquivo é
> o texto-base que vale para qualquer trimestre.
<!-- /@somente-modelo -->

# Ocupação e rendimento nos estratos do Piauí — {{trimestre}}

> Duas construções são resolvidas pelo script: as diretivas
> `<!-- @tabela ... -->`, que viram tabelas inteiras, e as expressões
> `\{\{est Indicador Geografia\}\}`, que viram números. Uma terceira,
> `<!-- @redigir: ... -->`, marca o que depende de leitura humana e sai no
> arquivo gerado como um bloco **A REDIGIR** — são os trechos de
> interpretação, que nenhuma consulta a CSV resolve.
>
> O script FALHA se sobrar qualquer marcador não resolvido, de propósito: um
> relatório meio preenchido publicado por engano é pior que nenhum.
>
> **Regra que decide o que entra no corpo do texto:** um recorte demográfico
> só é comentado aqui se, *naquele recorte geográfico*, a diferença for
> significativa **pelo p-valor ajustado** (coluna `p_ajustado`, que corrige o
> volume de comparações) **e** o CV ficar abaixo de 15% em **todas** as
> categorias demográficas e em **todas** as categorias geográficas do recorte.
> Basta uma célula acima de 15% para o recorte inteiro sair do corpo do texto e
> ir para o anexo metodológico. A regra é conservadora de propósito: comentar
> uma diferença entre homens e mulheres que só aparece em metade dos estratos —
> e some na outra metade por imprecisão amostral — é pior do que não comentar.

---

## 1 Introdução

<!-- Manter o texto atual do relatorio.docx (§1). Ver "Notas de revisão do
     texto atual" ao final deste arquivo: há correções de redação e uma
     divergência de numeração de seções a resolver. -->

**Tabela 1** — Indicadores de trabalho e rendimento — Brasil, Nordeste, Piauí e
Teresina — até {{trimestre}}

<!-- @redigir: manter a Tabela 1 do relatorio.docx (série histórica de Brasil, Nordeste, Piauí e Teresina), acrescentando a coluna do trimestre corrente. Ela não é gerada pelo pipeline, que estima um trimestre por vez. -->

Fonte: IBGE — Pesquisa Nacional por Amostra de Domicílios Contínua trimestral.
Elaboração própria.

---

## 2 Metodologia

<!-- Manter o texto atual do relatorio.docx (§2.1 a §2.4), com as correções
     listadas em "Notas de revisão do texto atual". -->

### 2.1 Dimensões e indicadores analisados
### 2.2 Recortes geográficos
### 2.3 Recortes demográficos
### 2.4 Robustez dos indicadores estimados
### 2.5 Comparações entre os recortes

---

## 3 Análise dos resultados

### 3.1 Como ler esta seção

As quatro subseções a seguir seguem a mesma estrutura: um indicador principal,
que responde à pergunta central da dimensão, e indicadores auxiliares, que
qualificam a resposta. Cada uma traz uma tabela com as estimativas por recorte
geográfico, um gráfico com os intervalos de confiança e um texto que aponta as
diferenças relevantes.

Três chaves de leitura ajudam a interpretar os números:

**O intervalo importa mais que o ponto.** Toda estimativa aqui vem de uma
amostra, não de um censo. Quando os intervalos de confiança de dois estratos se
sobrepõem, a diferença entre eles pode ser apenas ruído amostral — mesmo que os
valores centrais pareçam distantes. Por isso o gráfico mostra a barra inteira,
e não só o ponto.

**Nem toda estimativa tem o mesmo peso.** A coluna de precisão classifica cada
número pelo coeficiente de variação: quanto menor, mais confiável. Estimativas
marcadas como *regular* devem ser lidas com cautela; as marcadas como *baixa*
aparecem na tabela por completude, mas não sustentam conclusão. Isso é
esperado — quanto mais fino o recorte territorial, menos pessoas da amostra
caem dentro dele.

**Diferença visível não é diferença comprovada.** A última linha de cada
tabela traz o teste que responde se as diferenças entre as categorias daquele
recorte são estatisticamente significativas. É esse teste, e não a inspeção
visual da tabela, que autoriza afirmar que dois estratos são diferentes. O
p-valor usado é o **ajustado**: como o relatório faz centenas de comparações
por trimestre, algumas sairiam significativas por puro acaso, e a correção
desconta esse efeito.

---

### 3.2 Desocupação

Esta dimensão responde à pergunta mais direta que se pode fazer sobre um
mercado de trabalho: quem procura emprego está conseguindo encontrar? A taxa de
desocupação mede isso para a população em geral. Os dois indicadores auxiliares
deslocam a pergunta para onde a resposta dói mais — o orçamento doméstico:
quando quem está sem trabalho é a pessoa responsável pelo domicílio, ou quem
divide com ela o sustento da casa, o desemprego deixa de ser um problema
individual e vira um problema familiar.

#### 3.2.1 Taxa de desocupação

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

O Piauí registrou taxa de desocupação de {{est Taxa_Desocupacao Piauí}}%, ante
{{est Taxa_Desocupacao Nordeste}}% no Nordeste e {{est Taxa_Desocupacao Brasil}}%
no Brasil. Dentro do estado, a distância entre o estrato com maior e menor
desocupação foi de {{amplitude Taxa_Desocupacao}} pontos percentuais, separando
{{extremo Taxa_Desocupacao max rotulo}} ({{extremo Taxa_Desocupacao max valor}}%)
de {{extremo Taxa_Desocupacao min rotulo}} ({{extremo Taxa_Desocupacao min valor}}%).

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
desocupação rural costuma ser estruturalmente mais baixa por um motivo que não
é positivo: parte da população ocupada na agricultura familiar não procura
trabalho no sentido que a pesquisa capta, e por isso não é contada como
desocupada. Neste trimestre a diferença foi de {{dif Taxa_Desocupacao Zona_Urbana Zona_Rural}}
pontos ({{estrelas Taxa_Desocupacao Zona}}).

<!-- @redigir: bloco demográfico da desocupação — incluir só se o recorte for significativo E o CV ficar abaixo de 15% em TODAS as subdivisões de cada corte geográfico (ver anexo §5.3). Consultar output/tabelas/comparacao_demografica_<sufixo>.csv. -->

#### 3.2.2 Desocupação da pessoa responsável pelo domicílio

Este indicador mede quanto dos desocupados são pessoas responsáveis pelo
domicílio. Uma taxa de desocupação alta concentrada em jovens que moram com os
pais tem um significado social muito diferente da mesma taxa concentrada em
quem sustenta a casa — e é essa distinção que o indicador captura.

**Tabela 3** — Pessoas responsáveis pelo domicílio entre os desocupados, por
recorte geográfico — {{trimestre}}

<!-- @tabela tipo=geografica indicador=Chefes_Familia_Desocupados -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Chefes_Familia_Desocupados -->

![Responsáveis pelo domicílio entre os desocupados](./output/figuras/comp_geo_Chefes_Familia_Desocupados.png)

**Figura 2** — Pessoas responsáveis pelo domicílio entre os desocupados —
{{trimestre}}

Em {{extremo Chefes_Familia_Desocupados max rotulo}},
{{extremo Chefes_Familia_Desocupados max valor}}% dos desocupados eram
responsáveis pelo domicílio, contra {{extremo Chefes_Familia_Desocupados min valor}}%
em {{extremo Chefes_Familia_Desocupados min rotulo}}.

<!-- @redigir: uma ou duas frases interpretando o contraste acima — o que significa, para o orçamento das famílias daquele estrato, essa concentração. -->

#### 3.2.3 Desocupação de quem contribui para a renda do domicílio

Amplia o indicador anterior para incluir o cônjuge ou companheiro(a), captando
não apenas quem é formalmente o responsável pelo domicílio mas o conjunto de
adultos de quem a renda da casa depende diretamente.

**Tabela 4** — Responsáveis ou cônjuges entre os desocupados, por recorte
geográfico — {{trimestre}}

<!-- @tabela tipo=geografica indicador=Conribuintes_Desocupados -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Conribuintes_Desocupados -->

![Responsáveis ou cônjuges entre os desocupados](./output/figuras/comp_geo_Conribuintes_Desocupados.png)

**Figura 3** — Responsáveis ou cônjuges entre os desocupados — {{trimestre}}

No Piauí, {{est Conribuintes_Desocupados Piauí}}% dos desocupados eram
responsáveis pelo domicílio ou cônjuges, contra
{{est Chefes_Familia_Desocupados Piauí}}% apenas de responsáveis — a diferença
corresponde aos cônjuges desocupados.

<!-- @redigir: o que essa diferença diz sobre o arranjo de sustento das famílias do estado. -->

---

### 3.3 Rendimento

Se a dimensão anterior pergunta quem tem trabalho, esta pergunta quanto esse
trabalho paga. O rendimento médio habitual é o indicador principal: mede o que
a pessoa recebe de forma regular, e não o que recebeu excepcionalmente naquele
mês, o que o torna mais adequado para comparar territórios. Os auxiliares
tratam do piso e da dispersão: quantos ganham abaixo do mínimo por hora, e
quanto a formalidade separa os rendimentos.

#### 3.3.1 Rendimento médio real habitual

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

O rendimento médio no Piauí foi de {{est Rendimento_Medio_Habitual Piauí}},
equivalente a {{pct_de Rendimento_Medio_Habitual Piauí Brasil}}% da média
nacional. Dentro do estado, {{extremo Rendimento_Medio_Habitual max rotulo}}
apresentou o maior rendimento médio ({{extremo Rendimento_Medio_Habitual max valor}})
e {{extremo Rendimento_Medio_Habitual min rotulo}} o menor
({{extremo Rendimento_Medio_Habitual min valor}}) — uma razão de
{{razao_extremos Rendimento_Medio_Habitual}} entre os extremos.

Vale registrar o que uma média de rendimento não mostra: ela é sensível a
valores muito altos e, em territórios pequenos, um punhado de rendimentos
elevados desloca o resultado inteiro. A distribuição completa dos rendimentos
por estrato está no anexo metodológico, e é ela que revela se a média
representa a maioria ou é puxada pela cauda.

<!-- @redigir: bloco demográfico do rendimento médio — incluir só se significativo E com CV abaixo de 15% em todas as subdivisões de cada corte geográfico. -->

#### 3.3.2 Sub-remuneração

Mede o percentual de ocupados que, dividido o que recebem pelas horas que
trabalham, ganham menos que o salário mínimo por hora — hoje R$ {{sm_hora}}.
É um indicador de precariedade que a taxa de desocupação não alcança: trata-se
de gente trabalhando, e trabalhando por menos do que o piso legal equivalente.

**Tabela 6** — Sub-remuneração por hora trabalhada, por recorte geográfico —
{{trimestre}}

<!-- @tabela tipo=geografica indicador=Percentual_Subremuneracao -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Percentual_Subremuneracao -->

![Sub-remuneração por recorte geográfico](./output/figuras/comp_geo_Percentual_Subremuneracao.png)

**Figura 5** — Percentual de ocupados com rendimento-hora abaixo do salário
mínimo horário — {{trimestre}}

{{est Percentual_Subremuneracao Piauí}}% dos ocupados do Piauí recebiam abaixo
do mínimo por hora. A incidência foi de
{{extremo Percentual_Subremuneracao max valor}}% em
{{extremo Percentual_Subremuneracao max rotulo}} e
{{extremo Percentual_Subremuneracao min valor}}% em
{{extremo Percentual_Subremuneracao min rotulo}}.

<!-- @redigir: o que a distância entre esses dois extremos sugere sobre a estrutura produtiva dos territórios envolvidos. -->

#### 3.3.3 Desigualdade entre formais e informais

O indicador é a razão entre o rendimento médio dos ocupados formais e o dos
informais. Um valor de 2,0 significa que o trabalhador formal ganha, em média,
o dobro do informal. Quanto mais alta a razão, mais a carteira assinada — e não
o esforço ou a jornada — determina quanto se ganha.

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

A razão formal/informal no Piauí foi de {{desigualdade Piauí razao}} — ou seja,
o trabalhador com carteira ganhou, em média, {{pct_a_mais Piauí}}% a mais que o
informal: {{desigualdade Piauí formal}} contra {{desigualdade Piauí informal}}.
Entre os estratos, a razão foi mais alta em {{desig_extremo max rotulo}}
({{desig_extremo max valor}}) e mais baixa em {{desig_extremo min rotulo}}
({{desig_extremo min valor}}).

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

---

### 3.4 Inserção no mercado de trabalho

As duas dimensões anteriores tratam de ter trabalho e de quanto ele paga. Esta
trata da qualidade do vínculo: com ou sem carteira, com jornada suficiente ou
não, com qual escolaridade. São as condições que determinam acesso a
previdência, seguro-desemprego, licenças e estabilidade — e que separam um
mercado de trabalho que protege de um que apenas ocupa.

#### 3.4.1 Taxa de informalidade

**Tabela 8** — Taxa de informalidade, por recorte geográfico — {{trimestre}}

<!-- @tabela tipo=geografica indicador=Taxa_Informalidade -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Taxa_Informalidade -->

![Taxa de informalidade por recorte geográfico](./output/figuras/comp_geo_Taxa_Informalidade.png)

**Figura 8** — Taxa de informalidade por recorte geográfico — {{trimestre}}

A informalidade no Piauí atingiu {{est Taxa_Informalidade Piauí}}% dos
ocupados, contra {{est Taxa_Informalidade Nordeste}}% no Nordeste e
{{est Taxa_Informalidade Brasil}}% no Brasil. A variação interna ao estado foi
de {{amplitude Taxa_Informalidade}} pontos, de
{{extremo Taxa_Informalidade min valor}}% em
{{extremo Taxa_Informalidade min rotulo}} a
{{extremo Taxa_Informalidade max valor}}% em
{{extremo Taxa_Informalidade max rotulo}}.

O contraste entre zona urbana e rural tende a ser o mais acentuado deste
indicador, e por razão estrutural: a produção agrícola familiar e o trabalho
por conta própria no campo são majoritariamente informais por natureza da
atividade, não por escolha do trabalhador. Neste trimestre a diferença foi de
{{dif Taxa_Informalidade Zona_Urbana Zona_Rural}} pontos
({{estrelas Taxa_Informalidade Zona}}).

<!-- @redigir: bloco demográfico da informalidade — incluir só se significativo E com CV abaixo de 15% em todas as subdivisões de cada corte geográfico. -->

#### 3.4.2 Sub-ocupação por insuficiência de horas

Capta quem está trabalhando menos horas do que gostaria e poderia. É o
indicador que revela a ociosidade escondida dentro da ocupação: a pessoa é
contada como ocupada, mas sua capacidade de trabalho está sendo subutilizada.

**Tabela 9** — Sub-ocupação por insuficiência de horas, por recorte geográfico
— {{trimestre}}

<!-- @tabela tipo=geografica indicador=Taxa_Subocupacao -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Taxa_Subocupacao -->

![Sub-ocupação por recorte geográfico](./output/figuras/comp_geo_Taxa_Subocupacao.png)

**Figura 9** — Percentual de ocupados subocupados por insuficiência de horas —
{{trimestre}}

{{est Taxa_Subocupacao Piauí}}% dos ocupados do Piauí estavam subocupados, com
{{extremo Taxa_Subocupacao max valor}}% em {{extremo Taxa_Subocupacao max rotulo}}
e {{extremo Taxa_Subocupacao min valor}}% em {{extremo Taxa_Subocupacao min rotulo}}.

<!-- @redigir: relacionar a subocupação com a informalidade do mesmo território — jornada insuficiente e vínculo precário costumam andar juntos, mas nem sempre. -->

#### 3.4.3 Escolaridade dos ocupados

Mede o percentual de ocupados com ensino médio completo ou mais. Funciona como
aproximação da qualificação da mão de obra empregada e, indiretamente, do tipo
de posto de trabalho que cada território oferece.

**Tabela 10** — Ocupados com ensino médio completo ou mais, por recorte
geográfico — {{trimestre}}

<!-- @tabela tipo=geografica indicador=Proporcao_Ocupados_Escolarizados -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Proporcao_Ocupados_Escolarizados -->

![Ocupados com médio completo ou mais](./output/figuras/comp_geo_Proporcao_Ocupados_Escolarizados.png)

**Figura 10** — Percentual de ocupados com ensino médio completo ou mais —
{{trimestre}}

{{extremo Proporcao_Ocupados_Escolarizados max valor}}% em
{{extremo Proporcao_Ocupados_Escolarizados max rotulo}} e
{{extremo Proporcao_Ocupados_Escolarizados min valor}}% em
{{extremo Proporcao_Ocupados_Escolarizados min rotulo}} — uma diferença de
{{amplitude Proporcao_Ocupados_Escolarizados}} pontos. Cabe uma cautela de leitura: este indicador mede a
escolaridade de quem *está ocupado*, não a da população. Um estrato pode
aparecer com escolaridade alta simplesmente porque os menos escolarizados não
encontraram trabalho, e não porque a população seja mais escolarizada.

---

### 3.5 Desalento

O desalento é a face do desemprego que as estatísticas convencionais não
capturam. Uma pessoa desalentada gostaria de trabalhar, está disponível para
isso, mas deixou de procurar por acreditar que não encontraria vaga. Como não
procurou, não é contada como desocupada — sai da força de trabalho e some da
taxa de desocupação. É por isso que um território pode ter desemprego em queda
e mercado de trabalho piorando ao mesmo tempo.

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

O desalento atingiu {{est Desalentados_Forca_Ampliada Piauí}}% da força de
trabalho ampliada do Piauí, com {{extremo Desalentados_Forca_Ampliada max valor}}%
em {{extremo Desalentados_Forca_Ampliada max rotulo}} e
{{extremo Desalentados_Forca_Ampliada min valor}}% em
{{extremo Desalentados_Forca_Ampliada min rotulo}}. Entre as pessoas fora da
força de trabalho, os desalentados foram
{{est Desalentados_Fora_Forca Piauí}}% no estado.

A leitura conjunta com a taxa de desocupação é o que dá sentido ao indicador.

<!-- @redigir: comparar a lista de estratos com maior desalento com a de maior desocupação (Tabelas 2 e 11) e dizer se coincidem. Quando desalento alto convive com desocupação baixa, a taxa de desemprego daquele território está subestimando o problema. -->

#### 3.5.2 Jovens que não trabalham nem estudam

**Tabela 12** — Jovens de 14 a 29 anos que não trabalham nem estudam, por
recorte geográfico — {{trimestre}}

<!-- @tabela tipo=geografica indicador=Taxa_Nem_Nem -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Diferença entre as categorias de cada recorte**

<!-- @tabela tipo=testes indicador=Taxa_Nem_Nem -->

![Taxa de jovens nem-nem](./output/figuras/comp_geo_Taxa_Nem_Nem.png)

**Figura 13** — Percentual de jovens de 14 a 29 anos que não trabalham nem
estudam — {{trimestre}}

{{est Taxa_Nem_Nem Piauí}}% dos jovens piauienses de 14 a 29 anos não
trabalhavam nem estudavam. A incidência variou de
{{extremo Taxa_Nem_Nem min valor}}% em {{extremo Taxa_Nem_Nem min rotulo}} a
{{extremo Taxa_Nem_Nem max valor}}% em {{extremo Taxa_Nem_Nem max rotulo}}.

Este é o indicador com maior conteúdo prospectivo do relatório: ele não mede o
mercado de trabalho de hoje, mas a formação — ou a não formação — da força de
trabalho da próxima década.

<!-- @redigir: o que a amplitude entre os estratos extremos significa para a próxima década de oferta de trabalho no estado. -->

<!-- @redigir: bloco demográfico dos nem-nem — é o recorte em que a diferença por sexo costuma ser mais acentuada, por conta do trabalho doméstico e de cuidado não remunerado. Incluir só se significativo E com CV abaixo de 15% em todas as subdivisões. -->

#### 3.5.3 Motivos para não procurar trabalho

Os indicadores anteriores dizem quantos desistiram. Este diz por quê — e é o
que separa um diagnóstico de falta de vagas de um diagnóstico de
incompatibilidade entre a mão de obra disponível e as vagas existentes. Os dois
pedem políticas públicas diferentes.

![Motivo da desistência entre os desalentados](./output/figuras/comp_geo_Motivo_Desistencia_Desalentado.png)

**Figura 14** — Motivo declarado da desistência, entre os desalentados —
{{trimestre}}

![Motivo de não procurar trabalho entre os nem-nem](./output/figuras/comp_geo_Motivo_Nao_Procura_NemNem.png)

**Figura 15** — Motivo de não ter procurado trabalho, entre os jovens nem-nem —
{{trimestre}}

![Motivo de não iniciar trabalho entre os nem-nem](./output/figuras/comp_geo_Motivo_Nao_Inicio_NemNem.png)

**Figura 16** — Motivo de não ter iniciado trabalho, entre os jovens nem-nem —
{{trimestre}}

**Tabela 13** — Distribuição dos motivos declarados — {{trimestre}}

<!-- @tabela tipo=motivos indicador=Motivo_Nao_Procura_NemNem geografia=Piauí -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

<!-- @redigir: nomear o motivo mais frequente da tabela acima e dizer que política pública ele aponta — falta de vaga pede uma coisa, incompatibilidade de qualificação pede outra. -->

Estes são os indicadores mais frágeis do relatório em termos de precisão: são
proporções calculadas sobre um subconjunto já pequeno — os desalentados, ou os
jovens nem-nem — e depois repartidas entre várias categorias de resposta. É
normal que a maioria das células apareça com CV alto nos estratos mais finos, e
elas devem ser lidas como indicativas, não conclusivas.

---

### 3.6 Síntese: onde as diferenças são estatisticamente significativas

Esta subseção reúne, em um único quadro, o resultado dos testes aplicados ao
longo da seção. A pergunta que ela responde é: para cada indicador, quais
recortes territoriais produzem diferenças que não se explicam por acaso
amostral?

**Tabela 14** — Testes de diferença entre categorias, por indicador e recorte
geográfico — 2º trimestre de 2026

<!-- @tabela tipo=sintese -->

Legenda: \*\*\* p < 0,001; \*\* p < 0,01; \* p < 0,05; ns = não significativo;
— = o teste não se sustenta nessa resolução (ver adiante). Os símbolos
referem-se ao **p-valor ajustado** para multiplicidade; a tabela completa, com
os p-valores brutos ao lado, está no anexo metodológico.

**Como ler a tabela.** Duas leituras saltam.

A primeira: **quase tudo difere entre territórios**. Nas quatro colunas em que
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

**Sobre a coluna do estrato de 7 dígitos.** Três indicadores trazem "—". Não
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

Duas observações que a leitura desta tabela exige.

**Significância estatística não é relevância prática.** Uma diferença pode ser
estatisticamente sólida e pequena demais para orientar política pública; e um
recorte com poucas observações pode não atingir significância diante de uma
diferença real e grande, por falta de amostra. O teste responde "isto é
distinguível do acaso?", não "isto importa?".

**Os p-valores desta edição passaram por duas correções.** A primeira é de
calibração: o teste usado é a razão de verossimilhanças de Rao-Scott, e não o
teste de Wald, porque este último rejeitava a hipótese nula em metade das
vezes em que ela era verdadeira nos recortes com muitas categorias. A segunda
é de multiplicidade: com centenas de comparações por trimestre, parte da
significância bruta seria produto do volume de testes, e o ajuste desconta esse
efeito. Há ainda uma terceira, de natureza diferente: alguns cruzamentos **não
produzem teste algum**. Quando a matriz de covariância do modelo perde posto —
o que acontece em recortes de muitas categorias dentro de estratos pequenos —
o p-valor que sairia dali seria enviesado na direção de encontrar diferença.
Nesses casos o teste é refeito no recorte agregado, e se ainda assim não
sustentar, a célula fica vazia. Uma lacuna honesta vale mais que um asterisco
inventado. O anexo metodológico (seções 6.4, 6.5 e 6.8) documenta as três, com
as simulações e os diagnósticos que as motivaram.

---

## 4 Considerações finais

<!-- @redigir: síntese geral em três a cinco parágrafos, retomando (i) o quadro do Piauí frente a Brasil e Nordeste; (ii) o eixo capital-interior; (iii) o eixo urbano-rural; (iv) as dimensões em que o estado é mais homogêneo; (v) o que mudou em relação ao trimestre anterior. -->

<!-- @redigir: ressalvas de encerramento — repetir que as estatísticas por estrato são experimentais e que estimativas com CV acima de 15% não sustentam conclusão. -->

---

## Notas de revisão do texto atual

Levantamento feito sobre o `relatorio.docx` na pasta `output/`. Estão separadas
em três grupos: o que corrige um erro de conteúdo, o que resolve uma pendência
deixada no texto e o que melhora a redação.

### Correções de conteúdo

**§2.1 — a faixa etária dos nem-nem diverge do código.** O texto diz "pessoas
de 15 a 29 anos"; o `01_pipeline_trimestral.R` usa `V2009 >= 14 & V2009 <= 29`,
ou seja, 14 a 29 anos — o mesmo corte da categoria "Jovens" em
`Faixa_Etaria_trabalho`. Os dois precisam concordar. Recomendo ajustar o texto
para 14 a 29 anos, que é o corte que o IBGE usa na força de trabalho.

**§2.1 — o indicador de escolaridade mede "médio completo ou mais".** O texto
e a lista de indicadores dizem "percentual de ocupados com ensino médio
completo". A variável `medio_completo_ou_mais` inclui também superior
incompleto e superior completo. Sem o "ou mais" o leitor entende uma categoria
fechada.

**§2.1 — o corte de horas da sub-ocupação descreve outra coisa.** O texto fala
em "trabalhadores com menos de 44 horas semanais", tomando as 44 horas do teto
constitucional. O teto está certo como referência de jornada legal, mas não é
o que este indicador mede: o pipeline usa `VD4004A`, uma variável **derivada
pelo próprio IBGE**, cujo corte de subocupação por insuficiência de horas é
fixado pelo Instituto — e não por nós. Ou seja, o número no texto não é uma
escolha metodológica nossa; é a descrição de um critério alheio.

Enquanto o texto disser 44 horas e a variável usar o corte do IBGE, o relatório
descreve incorretamente o dado. Duas saídas: (i) conferir o corte vigente no
glossário da PNADC e usá-lo no texto; ou (ii) abandonar `VD4004A` e construir o
indicador à mão com o corte de 44 horas — o que é defensável, mas passa a ser
um indicador nosso, não o de subocupação do IBGE, e deve ser renomeado para não
confundir quem compare com as publicações oficiais.

**§2.3 — a fórmula do CV está imprecisa.** O texto define
`CV = s/x̄ × 100`, com *s* sendo o desvio-padrão amostral. O que se calcula
aqui — e o que o pipeline calcula — é o CV do **estimador**, que usa o erro
padrão da estimativa, não o desvio-padrão dos dados:
`CV(θ̂) = 100 × EP(θ̂)/|θ̂|`. A diferença não é de detalhe: o desvio-padrão
descreve a dispersão da população, o erro padrão descreve a incerteza da
estimativa. O anexo metodológico traz a formulação completa.

**§2.4 — os testes descritos não são os aplicados.** O texto diz "teste-t de
comparação de médias e proporções e ANOVAs". O pipeline usa, para respostas
categóricas, o qui-quadrado de Rao-Scott (`svychisq`) e, para respostas
numéricas e binárias, um teste de Wald sobre modelo linear generalizado
ponderado (`svyglm` + `regTermTest`). Nenhum teste-t clássico é aplicado, e
nem poderia: a PNADC tem plano amostral complexo, e o teste-t comum pressupõe
observações independentes e igualmente ponderadas. O anexo metodológico
descreve o que é de fato usado.

**§2.2 — a pendência sobre o "overlap" entre RM e RIDE tem resposta.** O texto
traz a anotação *"(As duas categorias do meio parecem ter um overlap,
verificar isso)"*. Não há sobreposição, e a razão é simples: a variável
`V1023` tem quatro categorias no Brasil (capital; resto da região
metropolitana; resto da RIDE; resto da UF), mas **no Piauí apenas três
ocorrem**. Teresina é sede de uma RIDE — a RIDE Grande Teresina — e não de uma
região metropolitana, então a categoria "resto da RM" simplesmente não é
observada no estado. O `output/crosswalk_estratos.csv` confirma: os únicos
valores presentes são *Capital*, *Resto da RIDE* e *Resto da UF*. O texto deve
falar em **três** estratos administrativos no Piauí, explicando que o quarto
existe na variável nacional mas não se aplica ao estado.

### Pendências deixadas no texto

**§2.1 — remover a anotação "(ESTOU VENDO O NEGOCIO DO CASAL)".** A pendência
está resolvida: o indicador de responsáveis *ou cônjuges* desocupados existe no
pipeline (`Conribuintes_Desocupados`) e está incorporado como item 3.2.3 deste
relatório. A dimensão passa a ter três indicadores, não dois.

**§1 — "o relatório contém X seções".** Preencher. Com a estrutura atual são
quatro seções mais o anexo metodológico. O parágrafo também descreve "na
primeira, especificaremos os estratos" referindo-se ao que hoje é a seção 2 —
a numeração do texto e a dos títulos não batem.

**§2.2 — a dúvida sobre a ordem de apresentação dos recortes.** O texto traz
*"(TALVEZ COMEÇAR DESSE – MAIS DESAGREGADO PRO MAIS DESAGREGADO?)"*. Recomendo
manter a ordem atual, do mais agregado para o mais desagregado. O relatório é
voltado ao público geral, e a ordem atual leva o leitor do que ele já conhece
(Brasil, Nordeste, Piauí) para o que é novidade (os estratos de 7 dígitos).
Começar pelo recorte mais fino exigiria explicar a estrutura `AAAGGSE` antes de
o leitor saber por que ela importa. (A frase, aliás, repete "desagregado" nas
duas pontas.)

**§2.3 — a lista de categorias de cor/raça está incompleta.** O texto cita
"brancos, pretos e pardos". A variável `V2010` da PNADC tem cinco categorias:
branca, preta, amarela, parda e indígena — e o pipeline usa a variável inteira,
sem agregação. Ou o texto lista as cinco, ou explicita que amarelos e indígenas
foram omitidos da análise por insuficiência amostral.

### Redação

| Trecho | Sugestão |
|---|---|
| §1 "Não precisamos a fundo na literatura" | "Não precisamos ir a fundo na literatura" |
| §1 "só disponibilizada nos seus microdados" | "só disponibilizava nos seus microdados" |
| §1 "vamos explica-los mais a frente" | "vamos explicá-los mais adiante" |
| §1 "uma analisada desagregada" | "uma análise desagregada" |
| §2.1 "Tomou-se como base as dimensões" | "Tomaram-se como base as dimensões" |
| §2.2 "que quatro estratos" | "que tem três estratos no Piauí" (ver correção acima) |
| §2.2 "já são utilizamos no relatório" | "já são utilizados no relatório" |
| §2.2 "entre o sul. Centro-leste e norte" | "entre o sul, o centro-leste e o norte" |
| §2.3 "uma media de dispersão" | "uma medida de dispersão" |
| §2.4 "com CV classificado como regularemos" | "com CV classificado como regular" |
| §2.4 "compração de médias e proporçõese ANOVAS" | ver correção de conteúdo acima |
| §2.1 "Sub-remuneração", "Sub-ocupação" | o IBGE grafa sem hífen: "subremuneração", "subocupação" |

Uma sugestão de estilo, não de correção: o texto atual usa primeira pessoa do
plural com frequência ("utilizaremos", "compararemos", "vamos explicá-los").
Funciona bem e dá fluidez, mas convém uniformizar — hoje alterna com construções
impessoais ("computa-se", "adotou-se") às vezes no mesmo parágrafo.

### Revisão das figuras

Revisão visual das figuras geradas em {{sufixo}}. Nenhuma é reprovada; as
correções abaixo são de legibilidade, e todas ficam no
`03_comparacoes_indicadores.R` e no `01_pipeline_trimestral.R`.

**O recorte de 7 dígitos não aparece em nenhuma figura `comp_geo_*`.** Este é o
achado mais substantivo da revisão. Em `03_comparacoes_indicadores.R`, a
variável `Tipo_Geo` classifica as geografias com prefixo `Micro_` como
`"Outro"`, e o gráfico filtra `Tipo_Geo != "Outro"`. O resultado é que o quarto
recorte geográfico do relatório — o mais fino, e a principal novidade do
trabalho — não tem representação gráfica alguma. Basta acrescentar
`str_starts(Regiao_Geografica, "Micro_") ~ "Estrato fino"` ao `case_when`.

**O título das figuras vaza a fórmula interna.** A Figura de desocupação sai
como *"Taxa de Desocupação — VD4002 == "Pessoas desocupadas""*, e ainda cortada
na margem. A causa é a condição `if (sub != ind)`, que anexa a
`Subcategoria_Indicador` ao título: para os indicadores de razão, essa coluna
guarda o texto da fórmula. O sufixo só faz sentido nos indicadores de motivo,
que de fato têm subcategorias; nos demais deve ser suprimido.

**Os rótulos longos consomem a largura útil.** *"Resto da RIDE (Região
Integrada de Desenvolvimento Econômico, excluindo a capital)"* empurra a área
de plotagem para a direita e deixa cerca de 60% da figura em branco. Convém
acrescentar as versões curtas a `nomes_geografias_manual` — "Resto da RIDE" e
"Resto da UF" bastam, já que a explicação está no texto.

**As proporções aparecem como decimais.** O eixo mostra 0,06 / 0,07 / 0,08 em
vez de 6% / 7% / 8%. Para um relatório de público geral, vale
`scale_y_continuous(labels = scales::percent)` nos indicadores que são razões.

**A cor não carrega informação.** As figuras usam uma cor por geografia, com a
legenda desligada — o leitor vê tons diferentes que não significam nada.
Colorir por `Confiabilidade` (a classe de CV) aproveitaria o mesmo espaço
visual para dizer quais estimativas são sólidas e quais não são.

**No boxplot de CV, três rótulos atrapalham.** A categoria `"Outro"` é, na
verdade, o estrato de 7 dígitos e deveria ser nomeada; `"Agregado_Geografico"`
aparece com sublinhado e sem acento; e `"Agregado"` versus
`"Agregado_Geografico"` são nomes quase idênticos para coisas distintas
(agregados nacionais × estratos agregados). Além disso, a escala vai até cerca
de 500% por causa de poucos casos extremos, o que comprime justamente a faixa
de 0 a 50% onde está a informação — um `coord_cartesian(ylim = c(0, 100))` com
nota de rodapé resolve. Como o limiar operacional do relatório é 15%, vale
traçar as duas linhas de referência, e não só a de 30%.

**A ANOVA demográfica é ilegível.** O arquivo tem 4,8 MB, e o motivo está no
código: o eixo usa `paste(Indicador_Nome, Geografia_Nome)`, o que produz até 36
geografias × 14 indicadores ≈ 500 rótulos por faceta, a 5 pt, em cinco facetas
empilhadas — uma altura de 15 polegadas de texto sobreposto. Nenhum ajuste de
fonte salva essa figura; ela precisa de outra forma. A sugestão é um mapa de
calor de indicador × recorte demográfico, com a cor indicando a proporção de
geografias em que a diferença foi significativa.

**Nos histogramas de renda, os títulos das facetas vazam os nomes internos.**
Aparecem `Zona_Urbana`, `Admin_Capital`, `Agreg_Teresina`, `Micro_2210011`, e
vários cortados pela metade (*"gião Integrada de Desenvolvimento Econômic"*). O
`01_pipeline_trimestral.R` monta esse gráfico com os nomes brutos da lista de
geografias, sem aplicar a limpeza de rótulos que o `03` já tem em
`nome_geografia()`. Reaproveitar aquela função resolve. O eixo vertical também
sai em notação científica (2.0e+07) no painel do Brasil.

**Transversal e corrigido: todas as figuras saíam com fundo transparente.**
Só apareceu ao renderizar as figuras desta execução. `ggsave()` com
`theme_minimal()` grava PNG com canal alfa zerado — medi 0,00 nas cinco
figuras testadas. Sobre página branca não se nota; sobre fundo escuro (modo
noturno do Word, GitHub em tema escuro, PDF com fundo colorido) o texto cinza
desaparece e a figura fica ilegível. A `anova_regional` chegava a sair
inteiramente preta. Corrigido com `bg = "white"` nos sete `ggsave()` do
projeto — as figuras regeneradas agora saem com três canais, sem alfa.

**Corrigido: dois rótulos apareciam com o nome interno da variável.** O painel
do estrato de sete dígitos exibia `Estrato_Micro`, e o indicador de
responsáveis ou cônjuges desocupados exibia `Conribuintes_Desocupados` — com o
erro de digitação e tudo. Faltavam nas tabelas `nomes_recortes` e
`nomes_indicadores` do `03`, então caíam no identificador cru. Acrescentei
esses dois mais `Raca` e `Instrucao_agregado`, que tinham o mesmo problema. O
erro de digitação no identificador **não** foi corrigido no pipeline, de
propósito: renomeá-lo mudaria os nomes dos arquivos de figura e quebraria as
referências deste relatório. O conserto está só no rótulo exibido.

**Transversal: a fonte sai monoespaçada.** Todas as figuras são renderizadas em
fonte de largura fixa, o que dá aparência de saída de terminal em vez de figura
de relatório. É o R caindo para uma família padrão na ausência da fonte
esperada. Definir `base_family` no tema — ou instalar a fonte desejada —
uniformiza o conjunto.

### O que a primeira execução com dados reais mudou

Até esta rodada, as decisões metodológicas descritas acima haviam sido testadas
apenas em desenho sintético. A execução do pipeline sobre os microdados do 2º
trimestre de 2026 confirmou parte delas, refutou uma e revelou um problema que
a simulação não alcançava.

**O desenho amostral não é o que o anexo descrevia.** Desde que o IBGE passou a
distribuir os 200 pesos replicados de *bootstrap*, o `PNADcIBGE` deixa de
montar um desenho de linearização de Taylor e monta um `svrepdesign`. A troca é
automática — o pacote testa a presença das colunas `V1028001`–`V1028200` e
decide sozinho. A consequência é que os graus de liberdade dos testes valem
**199 em qualquer domínio**, e não o número de UPAs menos o de estratos (343,
no Piauí). O anexo foi corrigido nas seções 3.1, 5.1, 6.3, 8 e 9.

**Três erros do log anterior desapareceram.** As 575 falhas do recorte
`Instrucao_agregado`, as 18 de `$ operator is invalid for atomic vectors` e as
mensagens de estrato com uma única UPA não ocorrem mais. As primeiras eram o
bug de mapeamento entre o nome do recorte e a coluna testada — pior do que
parecia, porque o recorte `Instrucao` não falhava: testava silenciosamente a
variável errada. As últimas eram impossíveis desde o início, já que desenho
replicado não expõe PSU na estimação.

**Uma expectativa minha estava errada.** Eu esperava que a troca do teste de
Wald pelo LRT eliminasse as falhas de matriz singular. Não eliminou, e não
poderia: as 97 ocorrências estão concentradas nos três indicadores de motivo
(`Motivo_Nao_Procura_NemNem`, `Motivo_Nao_Inicio_NemNem`,
`Motivo_Desistencia_Desalentado`), que têm resposta categórica e por isso vão
pelo `svychisq` — **nunca foram testes de Wald**. A causa é tabela esparsa, e
nenhuma das seis estatísticas disponíveis no `svychisq` contorna matriz
singular.

**O problema novo é o mais sério.** Em recorte fino, réplicas *bootstrap*
individuais podem ficar sem observação em alguma célula, o que provoca
separação completa no ajuste e coeficientes da ordem de 10¹⁵. Como a variância
replicada é a dispersão entre réplicas, uma única réplica assim degenera a
matriz inteira. Ocorreu em 380 dos 2.236 modelos, e o efeito não é neutro: a
taxa de rejeição sobe de 32,2% para 42,2% quando o posto é deficiente. O
pipeline passou a recusar esses testes, registrando o motivo no log em vez de
publicar o p-valor. Optou-se por não substituí-los pelo recorte agregado: esse
recorte já é uma linha da bateria, e a substituição duplicaria o mesmo teste,
distorcendo o ajuste de multiplicidade. A seção 6.5 do anexo documenta o
diagnóstico completo.

Vale sublinhar o alcance: **nada disso afeta as estimativas**. Médias, razões e
coeficientes de variação vêm de `svymean` e `svyratio`, que não têm ajuste
iterativo e não podem divergir. O que estava em risco eram os testes.

**Nota de ambiente.** A execução exigiu `LC_ALL` em UTF-8. Em locale `POSIX` as
comparações com literais acentuados — `UF == "Piauí"`, os rótulos de
`Estrato_agregado` — falham silenciosamente ou param o script. Não é problema
do código, mas convém registrar para quem for reproduzir em servidor Linux
recém-provisionado.

### Uma questão de infraestrutura, não de texto

As figuras `comp_geo_*.png` são gravadas **sem sufixo de trimestre**, ao
contrário das demais saídas — cada edição sobrescreve os gráficos da anterior.
Decidiu-se manter assim: as figuras são regeneráveis rodando o pipeline de
novo, e versioná-las por trimestre multiplicaria o peso do repositório sem
ganho proporcional. Fica o registro de que reproduzir uma edição antiga exige
rodar o pipeline com aquele trimestre, não apenas abrir o arquivo publicado.

No mesmo script, o identificador `Conribuintes_Desocupados` está com erro de
digitação (falta o "t" de *Contribuintes*), o que se propaga para o nome do
arquivo `comp_geo_Conribuintes_Desocupados.png`. Se for corrigido, os nomes de
figura mudam junto — e as referências deste relatório também.
