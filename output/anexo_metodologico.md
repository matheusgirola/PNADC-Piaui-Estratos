# ANEXO METODOLÓGICO: ESTIMAÇÃO DE INDICADORES DE TRABALHO E RENDIMENTO POR ESTRATO GEOGRÁFICO NO PIAUÍ

**Resumo** — Este anexo descreve o arcabouço teórico, as definições
operacionais e as formulações matemáticas empregadas na estimação dos
indicadores de ocupação, rendimento e educação por estrato geográfico do Piauí
a partir dos microdados trimestrais da Pesquisa Nacional por Amostra de
Domicílios Contínua (PNADC). Detalham-se os estimadores sob plano amostral
complexo, a estimação de variância por replicação *bootstrap*, a construção e
a interpretação do coeficiente de variação, os testes de hipótese adequados a
dados amostrais ponderados e conglomerados, e o procedimento de reconstrução da
geografia dos estratos amostrais — incluindo a formação das Unidades Primárias
de Amostragem (UPAs) e a estimação do estrato estatístico de renda. Encerra-se
com o quadro consolidado de parâmetros, as limitações do desenho e os
resultados completos por recorte demográfico.

**Palavras-chave:** Amostragem complexa. PNAD Contínua. Coeficiente de
variação. Estratificação ótima. Unidades primárias de amostragem. Piauí.

---

## 1 INTRODUÇÃO

O relatório ao qual este anexo se vincula compara indicadores de trabalho e
rendimento entre recortes territoriais do Piauí. A comparação não é trivial por
uma razão que precede qualquer resultado: os números comparados não são
contagens, são **estimativas** produzidas por uma amostra probabilística de
desenho complexo. Ignorar esse fato produz três erros previsíveis — médias
enviesadas, intervalos de confiança estreitos demais e testes de hipótese que
rejeitam a hipótese nula com frequência muito maior que o nível nominal.

Este documento explicita as decisões que evitam esses erros. O objetivo não é
descrever o código, mas tornar os resultados replicáveis e criticáveis. Ele se
destina, nas palavras do relatório principal, aos puros de coração.

Um segundo bloco do anexo trata de um problema distinto: o IBGE publica o
**código** do estrato amostral nos microdados, mas não a **fronteira** completa
desses estratos. A seção 7 descreve como essa geografia foi reconstruída, o que
permite localizar no território os recortes que o relatório compara.

---

## 2 FUNDAMENTAÇÃO: INFERÊNCIA SOB PLANO AMOSTRAL COMPLEXO

### 2.1 Por que a estatística clássica não se aplica diretamente

A quase totalidade dos procedimentos estatísticos de uso corrente — média
aritmética simples, desvio-padrão amostral, teste *t*, ANOVA, regressão por
mínimos quadrados ordinários — repousa sobre o pressuposto de que as
observações são independentes e identicamente distribuídas (i.i.d.), o que
equivale a supor amostragem aleatória simples com reposição.

A PNADC viola esse pressuposto de três maneiras simultâneas (SILVA; PESSOA;
LILA, 2002; PESSOA; SILVA, 1998):

a) **probabilidades desiguais de seleção** — nem todo domicílio tem a mesma
chance de entrar na amostra, e a calibração posterior dos pesos para totais
populacionais conhecidos acentua a desigualdade;

b) **conglomeração** — os domicílios não são sorteados individualmente, mas em
UPAs, conjuntos de setores censitários contíguos. Pessoas da mesma UPA se
parecem mais entre si do que pessoas de UPAs distintas, o que reduz a
informação efetiva contida na amostra;

c) **estratificação** — a amostra é distribuída por estratos definidos *a
priori*, o que, ao contrário dos dois efeitos anteriores, tende a **aumentar** a
precisão.

Ignorar (a) enviesa a estimativa pontual. Ignorar (b) e (c) enviesa a variância
— em direções opostas, sendo o efeito da conglomeração usualmente dominante,
de modo que a variância ingênua **subestima** a incerteza real.

### 2.2 O efeito do plano amostral

A magnitude dessa distorção é sintetizada pelo *design effect* (KISH, 1965):

$$
\operatorname{deff}(\hat\theta) \;=\; \frac{\hat{V}_{\text{plano}}(\hat\theta)}{\hat{V}_{\text{AAS}}(\hat\theta)}
\tag{1}
$$

razão entre a variância sob o plano efetivamente utilizado e a variância que se
obteria sob amostragem aleatória simples de mesmo tamanho. Valores de deff
superiores a 1 — a regra em pesquisas domiciliares — indicam que a amostra
complexa carrega menos informação que uma amostra simples de igual tamanho
nominal. O **tamanho efetivo de amostra** é, por consequência,

$$
n_{\text{ef}} \;=\; \frac{n}{\operatorname{deff}}
\tag{2}
$$

Esta é a razão substantiva pela qual estimativas para estratos finos do Piauí
exigem cautela: o *n* nominal de uma sub-região pode parecer confortável e
corresponder a um *n* efetivo consideravelmente menor.

### 2.3 Consequência operacional

Toda a estimação deste trabalho é realizada com o objeto de desenho amostral
declarado — no pacote `survey` (LUMLEY, 2004; 2010), por meio da estrutura
devolvida por `PNADcIBGE::get_pnadc()`, que já incorpora estrato, UPA e pesos
calibrados. Nenhuma estatística é calculada sobre os microdados "crus".

---

## 3 FONTE DE DADOS E DESENHO DA PNADC

### 3.1 A pesquisa

A PNAD Contínua é uma pesquisa domiciliar por amostragem probabilística em
**dois estágios com estratificação das unidades de primeiro estágio**. No
primeiro estágio sorteiam-se UPAs; no segundo, domicílios dentro das UPAs
selecionadas. A pesquisa opera em painel rotativo com esquema 1-2-5: o
domicílio é entrevistado por um trimestre, sai por dois, e assim por cinco
entrevistas ao todo.

Utilizam-se os microdados trimestrais, com deflatores oficiais aplicados aos
rendimentos (`deflator = TRUE`), de modo que os valores monetários são
comparáveis ao longo da série.

**Pesos replicados.** A partir do momento em que os microdados passaram a
trazer os 200 pesos replicados de *bootstrap* distribuídos pelo IBGE
(`V1028001` a `V1028200`), o objeto de desenho deixa de ser construído por
`svydesign` com pós-estratificação e passa a ser um `svrepdesign` do tipo
`bootstrap`. A troca é feita pelo próprio pacote `PNADcIBGE`, que testa a
presença dessas colunas e escolhe o caminho — não é uma opção do analista:

```r
if (!(FALSE %in% (sprintf("V1028%03d", seq(1:200)) %in% names(data_pnadc)))) {
  survey::svrepdesign(data = data_pnadc, weight = ~V1028, type = "bootstrap",
                      repweights = "V1028[0-9]+", mse = TRUE, ...)
}
```

A consequência é metodológica e percorre todo o restante deste anexo: a
variância não é mais estimada por linearização, e sim por replicação (seção
5.1), e os graus de liberdade dos testes passam a ser governados pelo número de
réplicas, não pela contagem de UPAs (seção 6.3).

No 2º trimestre de 2026, o recorte do Piauí reúne **12.926 pessoas em 369 UPAs
distribuídas por 26 estratos**, com 4.633 domicílios e população expandida de
3.390.985 pessoas. O menor estrato do estado contém 3 UPAs.

### 3.2 A estrutura do estrato: `AAAGGSE`

A variável `Estrato` dos microdados é um código de sete dígitos com estrutura
hierárquica (IBGE, 2022; IBGE, 2025):

| Posição | Componente | Conteúdo |
|---|---|---|
| `AAA` (1–3) | Estratificação administrativa | capital, resto da região metropolitana, resto da RIDE, resto da UF |
| `GG` (4–5) | Estratificação geográfica | agrupamentos de regiões geográficas imediatas/intermediárias |
| `S` (6) | Situação e tipo de área | rural, urbano tradicional, Favelas e Comunidades Urbanas (FCU) |
| `E` (7) | Estrato estatístico | faixa de renda do responsável pelo domicílio |

No Piauí observam-se **26 estratos distintos**. Registre-se, por ser fonte
recorrente de confusão, que embora `AAA` admita quatro categorias no plano
nacional, **apenas três ocorrem no estado**: Teresina é sede de uma RIDE — a
RIDE Grande Teresina — e não de uma região metropolitana, de modo que a
categoria "resto da RM" não é observada no Piauí.

### 3.3 Os recortes analisados

| Recorte | Origem | Categorias |
|---|---|---|
| Agregados nacionais | `UF`, `Regiao` | Brasil, Nordeste, Piauí, Teresina |
| Zona | `V1022` | urbana, rural |
| Estrato administrativo | `V1023` (≡ `AAA`) | 3 no Piauí |
| Estrato agregado | `Estrato` (5 primeiros dígitos) | 5 |
| Estrato fino | `Estrato` (7 dígitos) | 26 |

Os recortes demográficos são sexo (`V2007`), cor ou raça (`V2010`, cinco
categorias), faixa etária (`V2009`, agregada em 14–29, 30–64 e 65 ou mais) e
grau de instrução (`VD3004`, em versão detalhada e em versão dicotomizada).

---

## 4 ESTIMADORES

Seja $s$ a amostra, $w_i$ o peso calibrado da pessoa $i$ e $y_i$ a variável de
interesse.

### 4.1 Totais e médias

O estimador de total é o de Horvitz-Thompson (HORVITZ; THOMPSON, 1952):

$$
\hat{Y} \;=\; \sum_{i \in s} w_i\, y_i
\tag{3}
$$

Como o total populacional de pessoas não é conhecido sem erro em cada
subdomínio, a média é estimada pela razão de Hájek (HÁJEK, 1971):

$$
\hat{\bar{Y}} \;=\; \frac{\sum_{i \in s} w_i\, y_i}{\sum_{i \in s} w_i}
\tag{4}
$$

É esta a forma usada, por exemplo, para o **rendimento médio real habitual**,
com $y_i$ igual ao rendimento habitual de todos os trabalhos multiplicado pelo
deflator.

### 4.2 Razões e proporções

Todos os indicadores expressos em percentual são razões de dois totais
estimados sobre subdomínios distintos:

$$
\hat{R} \;=\; \frac{\hat{Y}}{\hat{X}} \;=\; \frac{\sum_{i \in s} w_i\, y_i}{\sum_{i \in s} w_i\, x_i}
\tag{5}
$$

em que $y_i$ é a indicadora do numerador e $x_i$ a do denominador. A tabela
abaixo explicita cada indicador nessa forma:

| Indicador | Numerador $y_i$ | Denominador $x_i$ |
|---|---|---|
| Taxa de desocupação | pessoa desocupada | pessoa na força de trabalho |
| Responsáveis desocupados | responsável pelo domicílio | pessoa desocupada |
| Responsáveis ou cônjuges desocupados | responsável ou cônjuge | pessoa desocupada |
| Taxa de informalidade | ocupado informal | pessoa ocupada |
| Sub-ocupação | subocupado por insuficiência de horas | pessoa ocupada |
| Ocupados com médio completo ou mais | médio completo, superior incompleto ou completo | pessoa ocupada |
| Desalentados (força ampliada) | pessoa desalentada | força de trabalho ampliada |
| Desalentados (fora da força) | pessoa desalentada | pessoa fora da força de trabalho |
| Jovens nem-nem | 14–29 anos, não estuda e não ocupado | 14–29 anos |

A **força de trabalho ampliada** é definida como a união das pessoas na força
de trabalho com as pessoas desalentadas.

### 4.3 Indicadores derivados

Dois indicadores exigem construção prévia de variável ao nível da pessoa.

**Sub-remuneração.** Calcula-se o rendimento por hora efetivamente trabalhada
e compara-se ao salário mínimo horário vigente no ano de referência:

$$
\text{valor\_hora}_i \;=\; \frac{\text{rendimento habitual}_i}{5 \times \text{horas habituais}_i},
\qquad
\text{subremunerado}_i \;=\; \mathbb{1}\!\left[\text{valor\_hora}_i < \text{sm}_{\text{hora}}\right]
\tag{6}
$$

O fator 5 converte a jornada semanal declarada em jornada mensal aproximada,
compatibilizando-a com o rendimento, que é mensal. O parâmetro
$\text{sm}_{\text{hora}}$ é tabelado por ano em `R/00_config.R`.

**Informalidade.** Segue a definição operacional do IBGE, agregando cinco
condições: empregado do setor privado sem carteira; trabalhador doméstico sem
carteira; trabalhador familiar auxiliar; empregador sem CNPJ; e conta-própria
sem CNPJ.

### 4.4 Razão entre dois estimadores: a desigualdade formal/informal

O indicador de desigualdade é a razão entre o rendimento médio dos ocupados
formais e o dos informais:

$$
\hat{D} \;=\; \frac{\hat{\bar{Y}}_{F}}{\hat{\bar{Y}}_{I}}
\tag{7}
$$

A estimativa pontual é imediata, mas **sua variância não é**. Como
$\hat{\bar{Y}}_{F}$ e $\hat{\bar{Y}}_{I}$ são estimados sobre a mesma amostra —
compartilhando UPAs e estratos —, elas são correlacionadas, e a variância da
razão exige o termo de covariância. Pelo método delta:

$$
\hat{V}(\hat{D}) \;\approx\; \hat{D}^{2}\left[
\frac{\hat{V}(\hat{\bar{Y}}_{F})}{\hat{\bar{Y}}_{F}^{2}}
+ \frac{\hat{V}(\hat{\bar{Y}}_{I})}{\hat{\bar{Y}}_{I}^{2}}
- 2\,\frac{\widehat{\operatorname{Cov}}(\hat{\bar{Y}}_{F},\, \hat{\bar{Y}}_{I})}{\hat{\bar{Y}}_{F}\,\hat{\bar{Y}}_{I}}
\right]
\tag{8}
$$

Dividir uma estimativa pela outra e reportar o resultado sem intervalo de
confiança é aceitável como leitura descritiva; combinar os dois erros padrão
como se fossem independentes **não é**, e produz intervalos incorretos em
direção imprevisível (o sinal do viés depende do sinal da covariância).

**Implementação.** As duas médias são estimadas em um único objeto, com a
matriz de covariância retida (`svyby(..., covmat = TRUE)`), e o contraste é
avaliado na escala logarítmica:

$$
\hat{\lambda} \;=\; \log \hat{\bar{Y}}_{F} \;-\; \log \hat{\bar{Y}}_{I},
\qquad
\hat{D} = e^{\hat{\lambda}},
\qquad
\text{IC}_{95\%}(D) = \left[\, e^{\hat{\lambda} - 1{,}96\,\operatorname{EP}(\hat\lambda)},\;\;
e^{\hat{\lambda} + 1{,}96\,\operatorname{EP}(\hat\lambda)} \,\right]
\tag{9}
$$

com $\operatorname{EP}(\hat\lambda)$ obtido por linearização a partir da
matriz de covariância completa. Trabalhar em logaritmo traz três vantagens
sobre operar diretamente na razão:

a) o intervalo resultante é **assimétrico** na escala da razão e nunca inclui
valores negativos — propriedade necessária, já que uma razão de rendimentos é
positiva por construção;

b) a distribuição amostral de $\hat\lambda$ aproxima-se da normal muito mais
rapidamente que a de $\hat{D}$, o que torna a aproximação de (13) mais
confiável em subdomínios pequenos;

c) o erro padrão do logaritmo **é**, por construção, o coeficiente de variação
da razão:

$$
\operatorname{CV}(\hat{D}) \;=\; 100 \times \operatorname{EP}(\hat\lambda)
\tag{10}
$$

de modo que a classificação de precisão da seção 5.3 se aplica ao indicador sem
qualquer adaptação.

**Magnitude do erro que se evita.** Em desenho sintético reproduzindo a
estrutura da PNADC — estratos, UPAs dentro de estratos e pesos desiguais —, o
erro padrão calculado ignorando a covariância resultou **34% maior** que o
correto. O sinal do desvio não é previsível *a priori*: covariância positiva
entre as duas médias produz intervalo largo demais (conservador), covariância
negativa produz intervalo estreito demais — este último levando a declarar
diferenças que os dados não sustentam.

**Saída.** O indicador é gravado em
`output/desigualdade_formal_informal_<sufixo>.csv`, com os dois rendimentos
componentes, a razão, o intervalo assimétrico e o CV, e é também incorporado à
`base_<sufixo>.csv` sob o identificador `Desigualdade_Formal_Informal`, com
erro padrão convertido para a escala natural pelo método delta
($\operatorname{EP}(\hat D) = \hat D \cdot \operatorname{EP}(\hat\lambda)$),
de modo a atravessar sem modificação a maquinaria de CV e classificação de
precisão. Os indicadores `Rendimento_Formal` e `Rendimento_Informal`
permanecem sendo estimados separadamente: a razão acrescenta, não substitui.

**Limitação remanescente.** O indicador não integra a bateria de testes da
seção 6, porque comparar razões entre estratos exige um contraste de segunda
ordem (razão de razões) que o arranjo atual não produz. As diferenças de
desigualdade entre territórios devem, por ora, ser lidas pela sobreposição dos
intervalos de confiança, e não por teste formal.

---

## 5 PRECISÃO DAS ESTIMATIVAS

### 5.1 Estimação da variância

A variância é estimada por **replicação** *bootstrap* (WOLTER, 2007; RAO;
WU, 1988), com os 200 conjuntos de pesos replicados publicados pelo IBGE. Cada
conjunto $r$ reproduz uma reamostragem das UPAs dentro dos estratos; o
indicador é **recalculado por inteiro** com cada um deles, e a variância é a
dispersão dos 200 resultados em torno da estimativa de amostra cheia:

$$
\hat{V}(\hat\theta) \;=\; \frac{1}{R-1}\sum_{r=1}^{R}\left(\hat\theta_{(r)} - \hat\theta\right)^{2},
\qquad R = 200
\tag{11}
$$

O centro da soma é $\hat\theta$, a estimativa de amostra cheia, e não a média
das réplicas — é o que a opção `mse = TRUE` determina, e é a escolha
conservadora, pois incorpora eventual viés das réplicas à variância.

A vantagem prática da replicação é dispensar a linearização: para um estimador
não linear como a razão (5), não é preciso derivar variável linearizada
alguma, porque cada réplica recalcula a razão inteira. A exceção é o contraste
da seção 4.4, que continua aplicando o método delta — só que sobre a matriz de
covariância vinda das réplicas.

**Por que a UPA continua governando a precisão.** A replicação estima a mesma
quantidade que a linearização estimaria. Sob amostragem estratificada com
conglomerados de primeiro estágio, essa quantidade assume a forma

$$
\hat{V}(\hat{R}) \;=\; \sum_{h=1}^{H} \frac{n_h}{n_h - 1}\sum_{a=1}^{n_h}\left(t_{ha} - \bar{t}_h\right)^{2},
\qquad
t_{ha} = \sum_{i \in \text{UPA}_{ha}} w_i\, u_i,
\qquad
\bar{t}_h = \frac{1}{n_h}\sum_{a=1}^{n_h} t_{ha}
\tag{12}
$$

em que $h$ indexa estratos e $a$ indexa UPAs dentro do estrato, e $u_i$ é a
variável linearizada do estimador. A expressão não é a que o cálculo executa,
mas deixa explícito por que a **UPA** é a unidade que governa a precisão: a
soma interna percorre UPAs, não pessoas. Dobrar o número de entrevistas dentro
das mesmas UPAs reduz pouco a variância; dobrar o número de UPAs reduz muito.
É também o que a reamostragem das réplicas reproduz, já que ela sorteia UPAs,
não indivíduos.

Note-se ainda a exigência de $n_h \ge 2$ UPAs por estrato para que a expressão
seja computável — condição que o desenho da PNADC garante por construção, e que
motiva o piso de 150 UPAs por estrato estatístico discutido na seção 7. No
desenho replicado essa exigência não produz erro explícito: um estrato com
poucas UPAs simplesmente gera réplicas instáveis, problema tratado na seção
6.5.

### 5.2 Erro padrão e intervalo de confiança

$$
\operatorname{EP}(\hat\theta) \;=\; \sqrt{\hat{V}(\hat\theta)},
\qquad
\text{IC}_{95\%} \;=\; \hat\theta \;\pm\; 1{,}96 \times \operatorname{EP}(\hat\theta)
\tag{13}
$$

O intervalo é simétrico e baseado na aproximação normal. Para proporções
próximas de 0 ou de 1, e para estimativas com poucos graus de liberdade, o
limite inferior pode resultar negativo — sinal de que a aproximação está
operando fora de sua região de validade e de que a estimativa deve ser tratada
como pouco informativa.

### 5.3 Coeficiente de variação

O coeficiente de variação de uma estimativa é a razão percentual entre seu erro
padrão e seu valor:

$$
\operatorname{CV}(\hat\theta) \;=\; 100 \times \frac{\operatorname{EP}(\hat\theta)}{\left|\hat\theta\right|}
\tag{14}
$$

**É essencial não confundir esta grandeza com o coeficiente de variação
descritivo** $s/\bar{x}$, que mede a dispersão dos dados em torno da média. A
expressão (14) mede a **incerteza da estimativa**, não a heterogeneidade da
população: uma variável muito dispersa pode ter CV de estimador baixo se a
amostra for grande, e uma variável homogênea pode ter CV alto se a amostra for
pequena. O que a expressão (14) responde é "quanto este número oscilaria se a
amostra fosse outra", e é isso que interessa para decidir se ele suporta uma
afirmação.

Adotam-se os limiares:

| Faixa de CV | Classificação | Uso recomendado |
|---|---|---|
| CV < 5% | Excelente | uso irrestrito |
| 5% ≤ CV < 15% | Boa | uso irrestrito |
| 15% ≤ CV < 30% | Regular | uso com cautela explícita |
| CV ≥ 30% | Baixa | não sustenta conclusão |

O corte de 15% é o adotado pelo IBGE como referência de boa precisão nas
estatísticas da PNADC. Os cortes de 5% e 30% seguem convenção corrente em
relatórios de estatísticas amostrais, sendo o de 30% o limite mais citado
internacionalmente para "não divulgar" ou "divulgar com ressalva" (STATISTICS
CANADA, 2010).

**Regra de inclusão no corpo do relatório.** Um recorte demográfico só é
comentado no texto principal se, naquele recorte geográfico, a diferença for
estatisticamente significativa **pelo p-valor ajustado** (seção 6.8) **e** o CV
for inferior a 15% em **todas** as células — todas as categorias demográficas, em todas as categorias geográficas
do recorte. Formalmente, para o recorte demográfico $d$ dentro do recorte
geográfico $g$:

$$
\text{incluir}(d, g) \;\iff\;
p^{\text{aj}}_{d,g} < 0{,}05
\;\wedge\;
\max_{c \in \mathcal{C}_d}\;\max_{r \in \mathcal{R}_g}\; \operatorname{CV}(\hat\theta_{c,r}) < 15\%
\tag{15}
$$

A regra é deliberadamente conservadora. Comentar uma diferença que se sustenta
em metade dos estratos e desaparece na outra metade por imprecisão amostral
induziria o leitor a generalizar um padrão que os dados não suportam. Os
resultados que não passam por (15) não são descartados: constam integralmente
do Apêndice A.

### 5.4 Distribuição empírica dos coeficientes de variação

![Distribuição do coeficiente de variação](figuras/hist_cv_{SUFIXO}.png)

**Figura A.1** — Distribuição do coeficiente de variação das estimativas —
{TRIMESTRE_REF}. A linha tracejada marca CV = 30%.

![CV por nível geográfico](figuras/boxplot_cv_nivel_{SUFIXO}.png)

**Figura A.2** — Coeficiente de variação por nível geográfico —
{TRIMESTRE_REF}.

A Figura A.2 é a evidência direta do argumento da seção 2.2: o CV cresce
monotonicamente à medida que o recorte territorial se estreita. Dos
{N_ESTIMATIVAS} valores estimados neste trimestre, {N_BOA} (%) enquadram-se nas
classes *excelente* ou *boa*, {N_REGULAR} em *regular* e {N_BAIXA} em *baixa*.

---

## 6 TESTES DE HIPÓTESE

### 6.1 O problema

Testar se um indicador difere entre categorias — entre estratos, ou entre
homens e mulheres — exige procedimentos que respeitem o plano amostral. O
teste *t* de comparação de médias e a ANOVA clássica pressupõem observações
independentes e igualmente ponderadas; aplicados a dados da PNADC, produzem
estatísticas infladas e rejeitam a hipótese nula com frequência muito superior
ao nível nominal declarado.

Adotam-se, por isso, duas famílias de testes, escolhidas conforme a natureza da
variável resposta.

### 6.2 Respostas categóricas: qui-quadrado de Rao-Scott

Para variáveis resposta categóricas — os motivos declarados de desistência,
por exemplo — emprega-se o teste de independência de Rao-Scott (RAO; SCOTT,
1981; 1984), implementado em `svychisq()`. Trata-se do qui-quadrado de Pearson
corrigido pelo efeito do plano amostral:

$$
X^{2}_{\text{RS}} \;=\; \frac{X^{2}_{\text{Pearson}}}{\bar{\delta}},
\qquad
\bar{\delta} \;=\; \frac{1}{(r-1)(c-1)}\sum_{k} \delta_{k}
\tag{16}
$$

em que $\delta_k$ são os autovalores da matriz de efeitos de plano
generalizados. A correção reduz a estatística na proporção em que a
conglomeração reduziu a informação efetiva.

### 6.3 Respostas numéricas e binárias: teste de Wald

Para variáveis resposta numéricas (rendimento) ou binárias (indicadoras de
desocupação, informalidade, desalento), ajusta-se um modelo linear generalizado
ponderado e testa-se a nulidade conjunta dos coeficientes do fator de interesse:

$$
g\!\left(\mathbb{E}[y_i]\right) \;=\; \beta_0 + \sum_{c=2}^{C} \beta_c\, \mathbb{1}[\text{categoria}_i = c]
\tag{17}
$$

com $g$ a identidade e família gaussiana para respostas contínuas, e $g$ o
logito com família **quasi**binomial para respostas 0/1. A escolha da
quasi-verossimilhança é necessária: a binomial ordinária pressupõe variância
igual à média e ensaios independentes, o que a ponderação e a conglomeração
violam; a quasibinomial estima o parâmetro de dispersão a partir dos dados.

A hipótese $H_0: \beta_2 = \dots = \beta_C = 0$ é avaliada por
`regTermTest`, com a razão de verossimilhanças de trabalho de Rao-Scott
(`method = "LRT"`) e graus de liberdade do desenho. A escolha desse teste em
detrimento do teste de Wald é justificada na seção 6.4 e não é de detalhe: sob
o Wald, os recortes com muitas categorias rejeitavam a hipótese nula em metade
das vezes em que ela era verdadeira.

Para referência, a estatística de Wald — a alternativa descartada — tem a
forma:

$$
F \;=\; \frac{1}{q}\left(\hat{\boldsymbol\beta} - \boldsymbol\beta_0\right)^{\!\top}
\hat{V}\!\left(\hat{\boldsymbol\beta}\right)^{-1}
\left(\hat{\boldsymbol\beta} - \boldsymbol\beta_0\right)
\tag{18}
$$

com $q = C - 1$ graus de liberdade no numerador e, no denominador, os graus de
liberdade do desenho, obtidos por `degf(design)`.

**De onde vem esse número.** Em desenho estratificado por conglomerados, seria
o número de UPAs menos o número de estratos — no Piauí do 2º trimestre de 2026,
$369 - 26 = 343$. No desenho replicado que o `PNADcIBGE` de fato constrói, ele
é o número de réplicas menos um: **199**, qualquer que seja o domínio. As duas
contas não coincidem, e a segunda é a que vale aqui.

Esse ponto merece ênfase por dois motivos. O primeiro é que **os graus de
liberdade não são governados pelo número de pessoas entrevistadas**: um estrato
com dez mil entrevistas distribuídas em poucas UPAs tem pouca informação
efetiva sobre a variabilidade entre grupos.

O segundo é uma ressalva do desenho replicado, e é desfavorável: como o valor
199 vem das réplicas, **ele não encolhe em domínio pequeno**. O estrato
`2252022`, com 3 UPAs, recebe os mesmos 199 graus de liberdade que o Piauí
inteiro. A distribuição de referência é, portanto, otimista justamente onde a
amostra é mais frágil. É mais uma razão para o teste conservador da seção 6.4,
para a guarda da seção 6.5 e para o ajuste de multiplicidade da seção 6.8 — e
não uma razão para relaxar nenhum dos três.

### 6.4 Calibração dos testes

Um teste está **calibrado** quando rejeita a hipótese nula na frequência que
declara: um teste a 5% deve produzir falsos positivos em 5% das vezes em que a
hipótese nula é verdadeira. Calibração não é o mesmo que poder — um teste pode
ser calibrado e fraco, ou descalibrado e aparentemente sensível.

Há motivo teórico para desconfiar do teste de Wald neste desenho. A estatística
(18) depende da inversa da matriz de covariância estimada. Quando o número de
parâmetros testados $q$ cresce em relação aos graus de liberdade do desenho,
essa matriz é estimada com poucos graus de liberdade e sua inversa amplifica o
ruído, inflando a estatística. O problema é conhecido na literatura de
amostragem complexa (THOMAS; RAO, 1987; KORN; GRAUBARD, 1990) e é severo
justamente na configuração dos recortes finos: muitas categorias, poucas UPAs
por categoria.

**Verificação por simulação.** Geraram-se 400 conjuntos de dados sob hipótese
nula estrita — nenhuma diferença entre grupos —, replicando a estrutura do
desenho: grupos coincidindo com estratos, UPAs aninhadas nos grupos,
correlação intraclasse induzida por efeito aleatório de UPA e pesos desiguais.
A tabela reporta a proporção de rejeições a 5%; o valor ideal é 0,050.

A simulação foi conduzida sobre desenho estratificado por conglomerados, em que
os graus de liberdade acompanham a contagem de UPAs — daí a coluna "GL do
desenho" variar entre as linhas. No desenho replicado da produção esse valor é
fixo em 199 (seção 6.3), o que **agrava** o quadro em vez de aliviá-lo: a
referência fica mais permissiva exatamente nas configurações finas. A
conclusão qualitativa — o Wald é inutilizável no recorte fino, o LRT não é —
vale com folga maior.

| Configuração | Parâmetros | GL do desenho | Wald | **LRT** | ANOVA clássica |
|---|---:|---:|---:|---:|---:|
| 5 grupos, 12 UPAs cada *(≈ estrato agregado)* | 4 | 55 | 0,050 | **0,037** | 0,573 |
| 20 grupos, 4 UPAs cada *(≈ estrato fino)* | 19 | 60 | 0,505 | **0,035** | 0,993 |
| 26 grupos, 3 UPAs cada *(≈ pior caso)* | 25 | 52 | 0,797 | **0,028** | 0,993 |

A leitura é direta. Com poucas categorias e muitas UPAs, o Wald é
perfeitamente calibrado. No recorte fino, ele rejeita a hipótese nula em **mais
da metade das vezes em que ela é verdadeira** — dez vezes o nível nominal
declarado. No pior caso, quatro em cada cinco testes produziriam um falso
positivo. A última coluna mostra por que a ANOVA clássica não é alternativa:
ignorar o plano amostral leva a taxas de erro entre 57% e 99%.

**O LRT é conservador, não impotente.** A objeção natural a um teste
conservador é que ele deixe de detectar diferenças reais. Repetindo a simulação
sob hipóteses alternativas, na configuração de 20 grupos:

| Efeito (em desvios-padrão) | Wald | **LRT** |
|---|---:|---:|
| 0,00 *(nulo)* | 0,535 | **0,035** |
| 0,15 | 0,677 | **0,102** |
| 0,30 | 0,907 | **0,415** |
| 0,50 | 0,998 | **0,945** |
| 0,80 | 1,000 | **1,000** |

O LRT detecta 94,5% dos efeitos de meio desvio-padrão e a totalidade dos
efeitos de 0,8 — poder adequado para as diferenças que interessam
substantivamente. A aparente superioridade do Wald em efeitos pequenos é
ilusória: com taxa de falsos positivos de 53,5% na linha nula, quase toda a
"detecção" a 0,15 é ruído.

**Decisão.** Adota-se `method = "LRT"` com `df = degf(design)` em todos os
testes de resposta numérica e binária. O custo computacional é idêntico ao do
Wald.

Registre-se que o teste de Rao-Scott da seção 6.2, usado para respostas
categóricas, já incorpora correção de segunda ordem com referência $F$ e não
sofre do problema de calibração descrito aqui. Ele tem, porém, um modo de
falha próprio — inversão de matriz singular quando a tabela é esparsa — tratado
na seção seguinte.

### 6.5 Degeneração da variância replicada e a guarda de posto

O desenho replicado introduz um modo de falha que não existe sob linearização,
e que só se manifesta no recorte fino.

**O mecanismo.** A variância de um coeficiente é a dispersão dele entre as 200
réplicas (equação 11). Num recorte com muitas categorias, uma réplica pode
ficar sem nenhuma observação de determinada célula. No ajuste quasibinomial
isso configura **separação completa**: a verossimilhança é maximizada com o
coeficiente tendendo ao infinito, e o algoritmo para em torno de $10^{15}$.
Como a variância é a dispersão entre réplicas, **uma única réplica nessa
condição domina a matriz inteira**.

O caso mais visível no 2º trimestre de 2026 é o teste central do relatório — a
taxa de desocupação entre os 26 estratos finos. O modelo de amostra cheia
converge sem incidente: os 26 coeficientes são finitos e o maior tem valor
absoluto 2,43. Ainda assim,

$$
\operatorname{posto}\left[\hat{V}(\hat{\boldsymbol\beta})\right] \;=\; 1
\quad\text{de}\quad 25,
\qquad
\max_{jk}\left|\hat{V}_{jk}\right| \;=\; 1{,}2\times10^{28}
$$

porque 26 das 200 réplicas produziram coeficientes da ordem de $10^{15}$.

O sintoma final é obscuro e vale registrar, porque não sugere a causa: com
$\hat{V}$ degenerada, os autovalores de $\hat{V}_0^{-1}\hat{V}$ — usados pelo
`regTermTest` para a aproximação de soma de qui-quadrados — saem **complexos**,
e a rotina `pFsum` do pacote `survey` interrompe com a mensagem
`Non-numeric argument to mathematical function`. Um erro de aritmética
denunciando um problema amostral.

**A extensão do problema.** Sobre os 2.236 modelos `svyglm` da bateria
demográfica do trimestre:

| Diagnóstico | Modelos |
|---|---:|
| Ao menos uma réplica divergente (critério invariante de escala) | 137 (6,1%) |
| Matriz de covariância de posto deficiente | 380 |
| — destes, com réplica divergente | 129 |
| — destes, **sem** réplica divergente | 251 |

A divergência explica apenas um terço da degeneração; o restante é
quase-separação que não chega a estourar numericamente. **Por isso a guarda
adotada é o posto da matriz, e não um limiar sobre a magnitude do
coeficiente**: é mais abrangente e não depende de constante arbitrária.

**Por que não basta ignorar.** Entre os testes que concluíram, a taxa de
rejeição a 5% foi de **32,2% com posto completo e 42,2% com posto deficiente**.
Variância degenerada subestima o erro padrão em alguma direção do espaço de
parâmetros, e o teste rejeita em excesso. O viés é sistemático e aponta para
onde mais atrapalha: inventar significância.

**O risco é previsível.** Ele é governado pelo tamanho da menor célula do
recorte, não pelo tamanho total da amostra:

| Menor célula do recorte | Modelos | Posto deficiente |
|---|---:|---:|
| até 5 observações | 591 | 37,9% |
| 6 a 10 | 224 | 20,1% |
| 11 a 25 | 301 | 16,3% |
| 26 a 50 | 271 | 7,4% |
| 51 a 100 | 301 | 3,3% |
| acima de 100 | 519 | 0,6% |

Por recorte, a assimetria é a esperada: o grau de instrução detalhado
(`VD3004`, sete níveis) produz 49,5% de posto deficiente, contra 2,2% do sexo.

**O caso categórico.** Para respostas categóricas o caminho é o `svychisq`, que
inverte a covariância das proporções de célula; a raiz é a mesma — célula
vazia tem variância nula — mas o sintoma é a singularidade explícita. As seis
estatísticas disponíveis (`F`, `Chisq`, `Wald`, `adjWald`, `lincom`,
`saddlepoint`) falham igualmente: não há escolha de estatística que contorne
uma matriz singular. Varrendo 387 combinações de indicador de motivo × recorte
× geografia, a fração de células vazias separa bem os casos:

| Células vazias na tabela | Combinações | Falhas |
|---|---:|---:|
| até 20% | 124 | 0 |
| 20 a 30% | 74 | 2 |
| 30 a 40% | 67 | 14 |
| acima de 40% | 122 | 74 |

**A guarda adotada.** O teste é **recusado** — não substituído — quando:

- a resposta é numérica ou binária e
  $\operatorname{posto}[\hat{V}] < \dim[\hat{V}]$; ou
- a resposta é categórica e a tabela tem mais de 20% de células vazias.

A recusa é registrada no log de falhas com o motivo e com remissão ao recorte
agregado onde a mesma pergunta é respondida em resolução menor.

**Por que recusar em vez de cair para o recorte agregado.** A alternativa
natural seria, barrado o recorte fino, repetir o teste no agregado
correspondente. Ela foi descartada porque **o recorte agregado já é uma linha
da bateria**, por decisão de desenho do estudo: `Instrucao_agregado` acompanha
`Instrucao`, e `Estrato_Agregado` acompanha `Estrato_Micro`. A substituição
produziria uma linha idêntica à existente — mesmo domínio, mesma variável,
mesmo p-valor — com duas consequências indesejáveis: a tabela sugeriria duas
evidências onde há uma, e o procedimento de Benjamini-Hochberg (seção 6.8)
contaria o mesmo teste duas vezes na família, distorcendo o controle de taxa de
falsas descobertas exatamente nos indicadores que mais dependem dele.

Nas dimensões sem versão agregada — sexo, cor ou raça, faixa etária, todas já
curtas — a recusa é definitiva e aparece no log, nunca como p-valor.

**O que foi recusado.** Descartar as réplicas divergentes e seguir adiante
resolveria o problema numérico: no caso da taxa de desocupação o posto volta a
25 de 25 e o erro padrão do primeiro coeficiente passa de 0,3858 para 0,3513.
A opção foi descartada porque altera o estimador por conveniência
computacional, sem fundamento amostral que a sustente.

Registre-se, por fim, o alcance limitado do problema: ele atinge **apenas os
testes**. As estimativas pontuais e os coeficientes de variação da seção 5 vêm
de `svymean` e `svyratio`, que não envolvem ajuste iterativo e não podem
divergir. Os números das tabelas de resultados não são afetados.

### 6.6 Dois conjuntos de testes

**Testes demográficos.** Dentro de cada recorte geográfico, verificam se o
indicador difere entre categorias de sexo, cor/raça, faixa etária e instrução.
Respondem à pergunta "há desigualdade social *dentro* deste território?".

**Testes regionais.** Verificam se o indicador difere entre as categorias de um
mesmo recorte territorial — urbano × rural, entre estratos administrativos,
entre estratos agregados, entre estratos finos. Respondem à pergunta "há
desigualdade territorial *no estado*?".

### 6.7 Uma advertência sobre a comparação Teresina × Piauí

Comparar Teresina ao Piauí, literalmente, não é um teste válido: Teresina é um
**subconjunto** do Piauí, e todo residente da capital também é piauiense. Um
teste de diferença entre dois grupos pressupõe grupos disjuntos; aplicá-lo a um
conjunto e ao seu superconjunto produz uma estatística sem interpretação, além
de subestimar a diferença, já que o próprio peso de Teresina puxa a média
estadual em sua direção.

A comparação implementada é, portanto, **Teresina × resto do Piauí**, com a
capital excluída do segundo grupo. É esta que responde à pergunta de interesse
substantivo: a capital difere do restante do estado?

### 6.8 Comparações múltiplas

O conjunto de testes realizados a cada trimestre é numeroso — cada indicador é
confrontado com o mesmo recorte demográfico em dezenas de geografias. Sob a
hipótese nula global, cerca de 5% desses testes resultariam significativos por
acaso: com aproximadamente 36 geografias por indicador, isso equivale a quase
duas "descobertas" espúrias por linha da tabela.

**Ordem das correções.** Registre-se, porque a sequência importa: o ajuste para
multiplicidade só faz sentido depois de resolvida a calibração da seção 6.4.
Corrigir p-valores produzidos por um teste que rejeita a hipótese nula em 50%
das vezes em que ela é verdadeira não recupera a inferência — apenas redistribui
valores que já não significam o que declaram. Primeiro se conserta o teste,
depois se corrige a multiplicidade.

**Procedimento adotado.** Aplica-se o controle da taxa de falsas descobertas de
Benjamini-Hochberg (BENJAMINI; HOCHBERG, 1995). Ordenados os $M$ p-valores da
família, $p_{(1)} \le \dots \le p_{(M)}$, rejeita-se $H_{0}$ para todo
$i \le k$, onde

$$
k \;=\; \max\left\{ i \;:\; p_{(i)} \le \frac{i}{M}\,\alpha \right\}
\tag{19}
$$

O p-valor ajustado reportado é $p^{\text{aj}}_{(i)} = \min_{j \ge i}
\left\{ \min\left( \frac{M}{j} p_{(j)},\, 1 \right) \right\}$, de modo que a
comparação direta com $\alpha = 0{,}05$ reproduz o procedimento.

**Definição das famílias.** A escolha da família é a decisão substantiva do
ajuste, e não uma tecnicalidade: ela define sobre qual conjunto de perguntas se
controla o erro.

| Bateria | Família adotada | Justificativa |
|---|---|---|
| Testes demográficos | indicador × recorte demográfico, ajustando ao longo das geografias | corresponde à pergunta efetivamente formulada: "em quais territórios este indicador difere por sexo?" |
| Testes regionais | a bateria inteira | é pequena (poucos recortes × indicadores) e a tabela de síntese é lida como um todo |

Ajustar os testes demográficos ao longo dos *indicadores* misturaria perguntas
distintas — se a desocupação difere por sexo nada informa sobre se o rendimento
difere por idade — e diluiria o controle sem ganho interpretativo.

**Por que Benjamini-Hochberg e não Bonferroni.** O procedimento de Bonferroni
controla a probabilidade de ocorrer *qualquer* falso positivo na família
(*family-wise error rate*). É a garantia adequada quando uma única conclusão
errada compromete a decisão — um ensaio clínico, por exemplo. Este relatório é
um levantamento descritivo, em que o custo de um falso positivo isolado é
baixo e o de apagar diferenças territoriais reais é alto. O controle da taxa de
falsas descobertas responde à pergunta pertinente: *entre os resultados que
declaro significativos, que proporção deve ser falsa?* Com $\alpha = 0{,}05$,
espera-se que no máximo 5% das diferenças apontadas sejam espúrias.

**Reporte.** As duas colunas coexistem nas saídas: `p_valor` é o bruto e
`p_ajustado` é o corrigido, acompanhados de `n_testes_familia`, que explicita o
tamanho da família sobre a qual o ajuste foi calculado. O corpo do relatório
usa o ajustado; o Apêndice C publica ambos, de modo que o leitor possa refazer
o julgamento sob outro critério.

---

## 7 RECONSTRUÇÃO DA GEOGRAFIA DOS ESTRATOS

### 7.1 O problema

O relatório compara estratos amostrais. Para mapeá-los — e para verificar o que
cada código de sete dígitos representa no território — é preciso conhecer suas
fronteiras. O IBGE publica os polígonos apenas no nível agregado de cinco
dígitos (`AAAGG`); os dígitos `S` e `E` não têm fronteira divulgada.

O dígito `S` é recuperável diretamente dos atributos do setor censitário. O
dígito `E` — o estrato estatístico de renda — não é, e sua reconstrução é o
objeto desta seção. A especificação do IBGE é sucinta:

> "Para cada estrato geográfico, serão definidos de 2 a 5 estratos
> estatísticos, garantido que cada um tenha pelo menos 150 UPAs. O objetivo é
> minimizar a variância do estimador da renda do responsável pelo domicílio."

Como o critério é enunciado em **UPAs**, e não em setores, a reconstrução exige
duas etapas: formar as UPAs e, sobre elas, estratificar.

### 7.2 Formação das UPAs

**Critérios.** Conforme a especificação atualizada para o Censo 2022, uma UPA é
um conjunto de setores censitários **contíguos**, respeitada a situação e o
tipo de área, com mínimo de 60 domicílios particulares permanentes ocupados
(DPPO) em áreas rurais e 90 em áreas urbanas, dentro e fora de FCU. Admite-se
UPA constituída por um único setor quando este já atende ao mínimo.

**Formalização.** Seja $\mathcal{S}$ o conjunto de setores censitários do
Piauí. Define-se a partição em células

$$
c(s) \;=\; \left(\text{município}(s),\; S(s)\right)
\tag{20}
$$

com $S(s) \in \{1, 2, 3\}$ indicando urbano tradicional, rural e FCU. O
município entra como barreira porque a UPA é unidade operacional de campo: um
entrevistador não cobre duas prefeituras.

Dentro de cada célula $c$ constrói-se o grafo de contiguidade
$G_c = (V_c, E_c)$, com

$$
E_c \;=\; \left\{ (s, s') \in V_c \times V_c \;:\; s \neq s',\; \partial A_s \cap \partial A_{s'} \neq \varnothing \right\}
\tag{21}
$$

em que $\partial A_s$ denota a fronteira do polígono do setor $s$. Adota-se
contiguidade tipo *queen* — vizinhança por qualquer ponto de fronteira comum,
aresta ou vértice — convenção usual em malhas irregulares, nas quais
imprecisões de digitalização podem converter arestas curtas em vértices.

Uma UPA é um subconjunto $u \subseteq V_c$ que satisfaz duas condições:

$$
\text{(i) } G_c[u] \text{ é conexo}
\qquad\qquad
\text{(ii) } \sum_{s \in u} D_s \;\ge\; m_{S(c)}
\tag{22}
$$

com $D_s$ o número de DPPO do setor e

$$
m_{S} =
\begin{cases}
60, & S = 2 \quad (\text{rural})\\
90, & S \in \{1, 3\} \quad (\text{urbano tradicional e FCU})
\end{cases}
\tag{23}
$$

**A variável de capacidade.** $D_s$ é obtido da variável `V06001` dos Agregados
por Setores do Censo 2022 — "pessoas responsáveis em domicílios particulares
permanentes ocupados". Como todo DPPO tem exatamente uma pessoa responsável,
`V06001` **é** a contagem de DPPO do setor.

**Algoritmo.** A partição que satisfaz (22) não é única, e o problema de
encontrar a partição de cardinalidade máxima sob restrição de conexidade é
NP-difícil. Adota-se heurística gulosa de crescimento de regiões: partindo de
cada setor como unidade isolada, enquanto existir unidade $u$ com
$\sum_{s\in u} D_s < m$ e com ao menos um vizinho disponível, seleciona-se a
unidade de menor carga e funde-se com **o vizinho de menor carga**:

$$
u^{*} = \arg\min_{u\,:\,\text{carga}(u) < m} \text{carga}(u),
\qquad
v^{*} = \arg\min_{v \in N(u^{*})} \text{carga}(v)
\tag{24}
$$

A escolha do vizinho de *menor* carga, e não do maior ou do mais próximo,
distribui a massa em vez de concentrá-la: fundir sempre com o vizinho maior
produziria poucas UPAs muito grandes e muitas ainda deficitárias.

Setores isolados que permaneçam abaixo do mínimo sem vizinho contíguo — ilhas,
enclaves — são fundidos à unidade mais próxima da mesma célula por distância
entre centroides. A UPA resultante deixa de ser contígua, mas continua
respeitando município e situação, que são as restrições enunciadas
explicitamente pelo IBGE.

**Resultado.** O procedimento produz **5.949 UPAs** a partir de 7.331 setores
censitários do Piauí, nenhuma abaixo do mínimo.

### 7.3 Estimação do estrato estatístico

**O problema.** Trata-se do problema clássico de estratificação ótima
univariada: dada uma variável auxiliar contínua — aqui, o rendimento médio do
responsável pelo domicílio agregado à UPA —, particioná-la em $k$ faixas que
minimizem a variância do estimador da média sob alocação ótima.

Sob alocação de Neyman (NEYMAN, 1934), a variância do estimador estratificado
da média é, a menos de termos de correção para população finita,

$$
V\!\left(\hat{\bar{Y}}_{\text{st}}\right) \;\approx\; \frac{1}{n}\left(\sum_{h=1}^{k} W_h S_h\right)^{2}
\tag{25}
$$

com $W_h = N_h / N$ a fração da população no estrato $h$ e $S_h$ o
desvio-padrão da variável dentro do estrato. Minimizar a variância equivale,
portanto, a minimizar

$$
\Phi \;=\; \sum_{h=1}^{k} W_h S_h \;=\; \frac{1}{N}\sum_{h=1}^{k} N_h S_h
\tag{26}
$$

sujeito à restrição de capacidade da especificação:

$$
N_h \;\ge\; 150 \quad \text{para todo } h
\tag{27}
$$

**Solução exata.** Em estratificação univariada os estratos ótimos são sempre
**intervalos contíguos** da variável ordenada — não faz sentido um estrato
"pular" uma faixa de renda. Ordenando as UPAs por rendimento,
$x_{(1)} \le \dots \le x_{(n)}$, o problema reduz-se a escolher $k-1$ pontos de
corte. Como cada parcela $N_h S_h$ em (26) depende apenas dos elementos daquele
estrato, o objetivo é **separável**, e admite solução por programação dinâmica:

$$
f_h(j) \;=\; \min_{\,(h-1)\cdot 150\;\le\; i \;\le\; j - 150}
\Big\{\, f_{h-1}(i) \;+\; c(i+1,\, j) \,\Big\},
\qquad
c(a,b) = (b-a+1)\, S_{[a,b]}
\tag{28}
$$

com $f_1(j) = c(1,j)$ para $j \ge 150$, e a solução ótima em $f_k(n)$. Os
limites do índice $i$ impõem simultaneamente a restrição (27) ao estrato
corrente e a viabilidade dos $h-1$ estratos anteriores. As somas acumuladas de
$x$ e $x^2$ permitem avaliar $c(a,b)$ em tempo constante, de modo que a
complexidade é $O(k\,n^{2})$ — com $n \le 929$ no Piauí, menos de um segundo, e
**ótimo global**, não aproximação.

**Verificação por heurísticas.** A especificação do IBGE menciona "método de
otimização linear e algoritmos estocásticos". Como conferência, o procedimento
executa também as duas alternativas clássicas: a regra cum-$\sqrt{f}$
(DALENIUS; HODGES, 1959), que corta o eixo da variável em pontos igualmente
espaçados do acumulado de $\sqrt{f}$, e uma busca aleatória com perturbação de
fronteiras no espírito de Kozak (2004). A busca estocástica converge ao mesmo
valor da programação dinâmica em todas as células estratificadas — evidência de
que a solução está no ótimo — e a cum-$\sqrt{f}$ é inferior em todas.

**Escolha de $k$.** A especificação prescreve "de 2 a 5" estratos sem
estabelecer o critério de escolha. Testando as regras candidatas contra o
conjunto de códigos efetivamente observado nos microdados, obtém-se:

| Regra | Células acertadas |
|---|---|
| $k = \lfloor n_{\text{UPA}}/150 \rfloor$, limitado a 5 | 7 de 13 |
| $k = 3$ se $n_{\text{UPA}} \ge 450$, senão 1 | **13 de 13** |

Conclui-se que, no Piauí, o IBGE **não maximiza** o número de estratos: adota
três sempre que houver UPAs para sustentar $3 \times 150 = 450$, e estrato
único caso contrário. O caso discriminante é o estrato de FCU de Teresina, com
300 UPAs: comportaria dois estratos, mas permaneceu com um — como a regra dos
450 prevê e a regra de maximização não.

Ressalve-se que este é um ajuste sobre 13 células de uma única unidade da
federação. Ele explica integralmente o Piauí, mas não autoriza afirmar que três
seja política nacional: é possível que o estado simplesmente nunca disponha de
UPAs suficientes para quatro ou cinco estratos.

### 7.4 Validação

O número de estratos estatísticos reconstruídos coincide com o observado nos
microdados em **11 de 11 células geográficas**. Dos 26 estratos do estado, 25
possuem contrapartida reconstruída em correspondência unívoca.

Duas ressalvas subsistem, ambas com explicação candidata associada à
substituição progressiva da amostra mestra em curso (renovação de 20% no 3º
trimestre de 2025 até 100% no 3º trimestre de 2026), que faz o conjunto de
códigos observado misturar duas safras de desenho amostral:

a) o estrato `2254020` não é reconstruído, porque o código `2254` não existe
entre os polígonos publicados pelo IBGE — possivelmente por ser resíduo do
desenho anterior;

b) a numeração do dígito `E` é inconsistente entre células (ora $\{1,2,3\}$,
ora $\{0,1,2\}$), o que pode refletir duas convenções coexistindo.

Ambas geram previsão falseável: com a amostra 100% renovada, `2254020` deve
desaparecer dos microdados e a numeração deve uniformizar-se. O detalhamento
completo consta de `output/reconstrucao_estratos.md`.

---

## 8 QUADRO DE PARÂMETROS CONSOLIDADOS

| Parâmetro | Valor adotado |
|---|---|
| Fonte dos indicadores | PNAD Contínua trimestral, microdados |
| Deflacionamento | deflatores oficiais do IBGE (`deflator = TRUE`) |
| Estimador de média | razão de Hájek |
| Objeto de desenho | `svrepdesign` *bootstrap*, montado pelo `PNADcIBGE` a partir dos 200 pesos replicados do IBGE |
| Estimação de variância | replicação *bootstrap*, 200 réplicas, `mse = TRUE`; UPA como unidade de reamostragem |
| Nível de confiança | 95% (aproximação normal, $z = 1{,}96$) |
| Limiar de precisão para o corpo do texto | CV < 15% |
| Classes de CV | < 5% excelente; 5–15% boa; 15–30% regular; ≥ 30% baixa |
| Razão formal/informal | contraste `log` via `svyby(covmat = TRUE)` + `svycontrast` |
| Teste — resposta categórica | qui-quadrado de Rao-Scott (`svychisq`) |
| Teste — resposta numérica | Rao-Scott LRT sobre `svyglm` gaussiano (`regTermTest(method = "LRT")`) |
| Teste — resposta binária | Rao-Scott LRT sobre `svyglm` quasibinomial |
| Graus de liberdade dos testes | `degf(design)` = 199 (nº de réplicas − 1), fixo em todos os domínios |
| Guarda — resposta numérica/binária | recusa se `qr(vcov)$rank < ncol(vcov)` |
| Guarda — resposta categórica | recusa se mais de 20% das células da tabela estiverem vazias |
| Ação sobre teste barrado | recusa registrada em log, sem substituição pelo recorte agregado |
| Nível de significância | p < 0,05 sobre o p-valor ajustado |
| Correção para multiplicidade | Benjamini-Hochberg (FDR) |
| Família — testes demográficos | indicador × recorte demográfico, ao longo das geografias |
| Família — testes regionais | a bateria inteira do trimestre |
| Malha territorial | setores censitários do Censo 2022, Piauí |
| Sistema de referência | SIRGAS 2000 (EPSG:4674) |
| Contiguidade para UPAs | tipo *queen* (`sf::st_touches`) |
| Mínimo de DPPO por UPA | 60 (rural); 90 (urbano e FCU) |
| Variável de capacidade | `V06001` (Agregados por Setores, Censo 2022) |
| Variável de estratificação | rendimento médio do responsável (`V06004`), ponderado por `V06001` |
| Mínimo de UPAs por estrato estatístico | 150 |
| Número-alvo de estratos estatísticos | 3, quando $n_{\text{UPA}} \ge 450$ |
| Método de estratificação | programação dinâmica (ótimo exato) |
| Verificação | cum-$\sqrt{f}$ e busca estocástica tipo Kozak |
| Semente aleatória | 20260825 |

---

## 9 LIMITAÇÕES

**Estatísticas experimentais.** As estimativas por estrato dentro de unidades
da federação são classificadas pelo próprio IBGE como experimentais. O desenho
amostral da PNADC foi dimensionado para produzir estimativas de precisão
adequada em nível de UF e de capital, não de sub-região. As estimativas por
estrato fino são, portanto, um uso do dado além do propósito para o qual foi
dimensionado — legítimo, mas que exige a leitura sistemática do CV.

**Precisão decrescente com o refinamento.** Como demonstra a Figura A.2, os
recortes finos concentram os CVs elevados. Parcela relevante das estimativas
por estrato de sete dígitos, especialmente cruzadas com recortes demográficos,
não atinge precisão utilizável.

**Rotatividade do painel.** O esquema 1-2-5 implica sobreposição amostral entre
trimestres consecutivos. Comparações trimestre a trimestre não envolvem
amostras independentes, e a variância da *diferença* entre dois trimestres não
é a soma das variâncias. Este relatório não realiza testes de variação
temporal; caso venham a ser incorporados, exigirão tratamento específico da
covariância induzida pelo painel.

**Substituição da amostra mestra.** A transição em curso do desenho baseado no
Censo 2010 para o baseado no Censo 2022 faz com que os estratos observados
misturem duas safras até o 3º trimestre de 2026. Séries que atravessem esse
período devem tratar a mudança como quebra metodológica, não como variação
conjuntural.

**Reconstrução, não replicação.** O dígito `E` reconstruído reproduz o número
de estratos e as faixas de renda, mas a atribuição UPA a UPA não é verificável,
porque o IBGE não publica as UPAs. Trata-se de uma reconstrução estatisticamente
equivalente, não do estrato oficial.

**Peso da renda na estratificação.** A variável `V06004` é o rendimento médio
dos responsáveis **com** rendimento, enquanto `V06001` conta **todos** os
responsáveis. O peso correto para a agregação ao nível da UPA seria o número de
responsáveis com rendimento, que os Agregados por Setores não publicam.

**Graus de liberdade insensíveis ao tamanho do domínio.** Como o desenho é
replicado, `degf` vale 199 em qualquer recorte — do estado inteiro ao estrato
de 3 UPAs. A distribuição de referência dos testes é, portanto, otimista onde a
amostra é mais frágil. As guardas da seção 6.5 e o ajuste da seção 6.8
compensam parcialmente, mas não eliminam a ressalva: no estrato de sete
dígitos, um p-valor próximo do limiar deve ser lido como indício, não como
conclusão.

**Testes recusados por degeneração da variância.** Parte dos cruzamentos entre
indicador, geografia e recorte demográfico não produz teste algum, por decisão
metodológica e não por falha: quando a matriz de covariância replicada perde
posto, o resultado é registrado no log em vez de publicado. Isso concentra as
ausências nos recortes de muitas categorias dentro de estratos pequenos —
exatamente onde a estimativa também seria imprecisa. A tabela de resultados
demográficos completos do Apêndice A é, nesses casos, mais esparsa que a de
estimativas.

**Desigualdade sem teste formal entre territórios.** Conforme a seção 4.4, a
razão formal/informal dispõe de intervalo de confiança correto, mas não integra
a bateria de testes da seção 6: comparar razões entre estratos exigiria um
contraste de segunda ordem ainda não implementado.

---

## REFERÊNCIAS

BENJAMINI, Yoav; HOCHBERG, Yosef. Controlling the false discovery rate: a
practical and powerful approach to multiple testing. **Journal of the Royal
Statistical Society**: Series B (Methodological), Londres, v. 57, n. 1,
p. 289-300, 1995.

COCHRAN, William G. **Sampling techniques**. 3. ed. New York: John Wiley &
Sons, 1977.

DALENIUS, Tore; HODGES, Joseph L. Minimum variance stratification. **Journal of
the American Statistical Association**, v. 54, n. 285, p. 88-101, 1959.

HÁJEK, Jaroslav. Comment on "An essay on the logical foundations of survey
sampling" by D. Basu. In: GODAMBE, V. P.; SPROTT, D. A. (org.). **Foundations
of statistical inference**. Toronto: Holt, Rinehart and Winston, 1971.

HORVITZ, Daniel G.; THOMPSON, Donovan J. A generalization of sampling without
replacement from a finite universe. **Journal of the American Statistical
Association**, v. 47, n. 260, p. 663-685, 1952.

INSTITUTO BRASILEIRO DE GEOGRAFIA E ESTATÍSTICA (IBGE). **Pesquisa Nacional por
Amostra de Domicílios Contínua**: notas metodológicas. Rio de Janeiro: IBGE.

INSTITUTO BRASILEIRO DE GEOGRAFIA E ESTATÍSTICA (IBGE). **Nota Técnica
01/2022**: divulgação de resultados por estratos da PNAD Contínua. Rio de
Janeiro: IBGE, 2022.

INSTITUTO BRASILEIRO DE GEOGRAFIA E ESTATÍSTICA (IBGE). **Nota Técnica
03/2025**: atualização do desenho amostral da PNAD Contínua com base no Censo
Demográfico 2022. Rio de Janeiro: IBGE, 2025.

INSTITUTO BRASILEIRO DE GEOGRAFIA E ESTATÍSTICA (IBGE). **Censo Demográfico
2022**: agregados por setores censitários. Rio de Janeiro: IBGE, 2023.

KISH, Leslie. **Survey sampling**. New York: John Wiley & Sons, 1965.

KOZAK, Marcin. Optimal stratification using random search method in agricultural
surveys. **Statistics in Transition**, v. 6, n. 5, p. 797-806, 2004.

KORN, Edward L.; GRAUBARD, Barry I. Simultaneous testing of regression
coefficients with complex survey data: use of Bonferroni t statistics. **The
American Statistician**, v. 44, n. 4, p. 270-276, 1990.

LAVALLÉE, Pierre; HIDIROGLOU, Michael. On the stratification of skewed
populations. **Survey Methodology**, v. 14, n. 1, p. 33-43, 1988.

LUMLEY, Thomas. Analysis of complex survey samples. **Journal of Statistical
Software**, v. 9, n. 8, p. 1-19, 2004.

LUMLEY, Thomas. **Complex surveys**: a guide to analysis using R. Hoboken:
John Wiley & Sons, 2010.

NEYMAN, Jerzy. On the two different aspects of the representative method.
**Journal of the Royal Statistical Society**, v. 97, n. 4, p. 558-625, 1934.

PESSOA, Djalma G. C.; SILVA, Pedro L. N. **Análise de dados amostrais
complexos**. São Paulo: Associação Brasileira de Estatística, 1998.

RAO, J. N. K.; SCOTT, A. J. The analysis of categorical data from complex
sample surveys: chi-squared tests for goodness of fit and independence in
two-way tables. **Journal of the American Statistical Association**, v. 76,
n. 374, p. 221-230, 1981.

RAO, J. N. K.; SCOTT, A. J. On chi-squared tests for multiway contingency
tables with cell proportions estimated from survey data. **The Annals of
Statistics**, v. 12, n. 1, p. 46-60, 1984.

RAO, J. N. K.; WU, C. F. J. Resampling inference with complex survey data.
**Journal of the American Statistical Association**, v. 83, n. 401,
p. 231-241, 1988.

SÄRNDAL, Carl-Erik; SWENSSON, Bengt; WRETMAN, Jan. **Model assisted survey
sampling**. New York: Springer, 1992.

SILVA, Pedro Luis do Nascimento; PESSOA, Djalma Galvão Carneiro; LILA, Maurício
Franca. Análise estatística de dados da PNAD: incorporando a estrutura do plano
amostral. **Ciência & Saúde Coletiva**, Rio de Janeiro, v. 7, n. 4, p. 659-670,
2002. *(referência indicada como fonte dos critérios de formação de UPAs;
confirmar os dados completos antes da publicação)*

STATISTICS CANADA. **Survey methods and practices**. Ottawa: Statistics Canada,
2010. (Catalogue no. 12-587-X).

THOMAS, D. Roland; RAO, J. N. K. Small-sample comparisons of level and power
for simple goodness-of-fit statistics under cluster sampling. **Journal of the
American Statistical Association**, v. 82, n. 398, p. 630-636, 1987.

WOLTER, Kirk M. **Introduction to variance estimation**. 2. ed. New York:
Springer, 2007.

---

## APÊNDICE A — RESULTADOS COMPLETOS POR RECORTE DEMOGRÁFICO

Este apêndice apresenta **todas** as estimativas por recorte demográfico,
independentemente do coeficiente de variação, cumprindo o compromisso assumido
no corpo do relatório de que os resultados filtrados pela regra (15) não são
descartados, apenas deslocados.

**Leia com a coluna de precisão à vista.** Diferentemente do corpo do
relatório, aqui constam estimativas classificadas como *regular* e *baixa*. As
primeiras devem ser usadas com ressalva explícita; as segundas não sustentam
conclusão e são publicadas apenas para transparência e para permitir o
acompanhamento da precisão ao longo dos trimestres.

Fonte dos dados: `output/tabelas/comparacao_demografica_{SUFIXO}.csv`.

### A.1 Por sexo

**Tabela A.1** — Indicadores por sexo, segundo recorte geográfico —
{TRIMESTRE_REF}

| Indicador | Recorte geográfico | Categoria | Sexo | Estimativa | IC 95% | CV (%) | Precisão | p-valor |
|---|---|---|---|---:|:---:|---:|---|---:|
| {IND} | {RECORTE} | {CATEG} | Masculino | {EST} | {IC} | {CV} | {PREC} | {P} |
| {IND} | {RECORTE} | {CATEG} | Feminino | {EST} | {IC} | {CV} | {PREC} | {P} |
| … | … | … | … | … | … | … | … | … |

### A.2 Por cor ou raça

**Tabela A.2** — Indicadores por cor ou raça, segundo recorte geográfico —
{TRIMESTRE_REF}

<!-- Mesma estrutura da Tabela A.1, com as cinco categorias de V2010:
     branca, preta, amarela, parda e indígena. -->

### A.3 Por faixa etária

**Tabela A.3** — Indicadores por faixa etária, segundo recorte geográfico —
{TRIMESTRE_REF}

<!-- Mesma estrutura, com as categorias 14 a 29, 30 a 64 e 65 ou mais anos. -->

### A.4 Por grau de instrução

**Tabela A.4** — Indicadores por grau de instrução (agregado), segundo recorte
geográfico — {TRIMESTRE_REF}

<!-- Mesma estrutura, com as categorias "até fundamental completo" e
     "acima de fundamental completo". -->

**Tabela A.5** — Indicadores por grau de instrução (detalhado), segundo recorte
geográfico — {TRIMESTRE_REF}

<!-- Mesma estrutura, com as categorias originais de VD3004. -->

### A.6 Síntese da precisão

**Tabela A.6** — Distribuição das estimativas por classe de precisão e recorte
— {TRIMESTRE_REF}

| Recorte | Excelente | Boa | Regular | Baixa | Total |
|---|---:|---:|---:|---:|---:|
| Total (sem recorte demográfico) | {N} | {N} | {N} | {N} | {N} |
| Sexo | {N} | {N} | {N} | {N} | {N} |
| Cor ou raça | {N} | {N} | {N} | {N} | {N} |
| Faixa etária | {N} | {N} | {N} | {N} | {N} |
| Grau de instrução | {N} | {N} | {N} | {N} | {N} |

---

## APÊNDICE B — DISTRIBUIÇÃO DOS RENDIMENTOS

As médias apresentadas no corpo do relatório resumem distribuições que podem
ser bastante assimétricas. Este apêndice apresenta a distribuição completa,
permitindo avaliar se a média representa a maioria ou é deslocada pela cauda
superior.

![Distribuição da renda habitual real](figuras/renda_total_{SUFIXO}.png)

**Figura B.1** — Distribuição da renda habitual real por recorte geográfico —
{TRIMESTRE_REF}. Excluídos os valores acima do percentil 99, calculado sobre o
Brasil, para preservar a legibilidade da escala.

![Distribuição da renda por setor](figuras/renda_setor_{SUFIXO}.png)

**Figura B.2** — Distribuição da renda habitual real, administração pública ×
demais setores, por recorte geográfico — {TRIMESTRE_REF}.

A Figura B.2 tem interesse específico para o Piauí: em territórios onde o
emprego público responde por parcela expressiva da ocupação formal, a
distribuição de rendimentos tende a apresentar duas modas — uma associada ao
funcionalismo, outra ao setor privado —, e a média situa-se entre as duas, sem
descrever bem nenhuma delas. {INTERPRETACAO}

---

## APÊNDICE C — TESTES DE DIFERENÇA ENTRE CATEGORIAS DEMOGRÁFICAS

![ANOVA demográfica](figuras/anova_demografica_{SUFIXO}.png)

**Figura C.1** — p-valores dos testes de diferença entre categorias
demográficas, por indicador e recorte geográfico — {TRIMESTRE_REF}. Cada ponto
é uma combinação de indicador e geografia; em azul, as diferenças
significativas a 5%.

**Tabela C.1** — Testes de diferença entre categorias demográficas —
{TRIMESTRE_REF}

| Indicador | Recorte geográfico | Recorte demográfico | Método | Estatística | GL | p-valor | Significância | N |
|---|---|---|---|---:|---|---:|:---:|---:|
| {IND} | {GEO} | {DEMO} | {METODO} | {EST} | {GL} | {P} | {SIG} | {N} |
| … | … | … | … | … | … | … | … | … |

Fonte: `output/tabelas/anova_demografica_{SUFIXO}.csv`.

A tabela traz as duas colunas de p-valor. `p_valor` é o bruto; `p_ajustado`
aplica o controle de falsas descobertas descrito na seção 6.8, sobre a família
formada por indicador × recorte demográfico. São {N_TESTES_DEMO} testes no
total, e a diferença entre as duas colunas mede quanto da significância bruta
era atribuível ao volume de comparações.

Mesmo com o ajuste, padrões que se repetem entre indicadores e entre trimestres
continuam sendo mais informativos do que qualquer resultado isolado — o
controle de FDR reduz os falsos positivos, não os elimina.

---

**Dois pontos a validar antes de circular o documento:**

1. **Corte de horas da subocupação (§4.2).** O relatório principal descreve a
   subocupação por insuficiência de horas com corte em 44 horas semanais; a
   definição da PNADC usa 40 horas. Confirmar no glossário do IBGE e
   uniformizar os dois documentos.

2. **Referência Silva, Pessoa e Lila (2002).** Foi indicada como fonte dos
   critérios de formação das UPAs. Os dados bibliográficos completos —
   volume, número e paginação — devem ser conferidos na fonte antes da
   publicação.
