# ANEXO METODOLÓGICO: ESTIMAÇÃO DE INDICADORES DE TRABALHO E RENDIMENTO POR ESTRATO GEOGRÁFICO NO PIAUÍ

**Resumo** — Este anexo descreve o arcabouço teórico, as definições
operacionais e as formulações matemáticas empregadas na estimação dos
indicadores de ocupação, rendimento e educação por estrato geográfico do Piauí
a partir dos microdados trimestrais da Pesquisa Nacional por Amostra de
Domicílios Contínua (PNADC). Detalham-se os estimadores sob plano amostral
complexo, a estimação de variância por linearização de Taylor, a construção e
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

A variância é estimada por **linearização de Taylor** (WOLTER, 2007;
SÄRNDAL; SWENSSON; WRETMAN, 1992). Para um estimador não linear como a razão
(5), define-se a variável linearizada

$$
u_i \;=\; \frac{y_i - \hat{R}\,x_i}{\hat{X}}
\tag{11}
$$

e a variância de $\hat{R}$ é aproximada pela variância do total estimado de
$u_i$. Sob amostragem estratificada com conglomerados de primeiro estágio, esta
assume a forma

$$
\hat{V}(\hat{R}) \;=\; \sum_{h=1}^{H} \frac{n_h}{n_h - 1}\sum_{a=1}^{n_h}\left(t_{ha} - \bar{t}_h\right)^{2},
\qquad
t_{ha} = \sum_{i \in \text{UPA}_{ha}} w_i\, u_i,
\qquad
\bar{t}_h = \frac{1}{n_h}\sum_{a=1}^{n_h} t_{ha}
\tag{12}
$$

em que $h$ indexa estratos e $a$ indexa UPAs dentro do estrato. A expressão
deixa explícito por que a **UPA** é a unidade que governa a precisão: a soma
interna percorre UPAs, não pessoas. Dobrar o número de entrevistas dentro das
mesmas UPAs reduz pouco a variância; dobrar o número de UPAs reduz muito.

Note-se ainda a exigência de $n_h \ge 2$ UPAs por estrato para que (12) seja
computável — condição que o desenho da PNADC garante por construção, e que
motiva o piso de 150 UPAs por estrato estatístico discutido na seção 7.

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
estatisticamente significativa **e** o CV for inferior a 15% em **todas** as
células — todas as categorias demográficas, em todas as categorias geográficas
do recorte. Formalmente, para o recorte demográfico $d$ dentro do recorte
geográfico $g$:

$$
\text{incluir}(d, g) \;\iff\;
p_{d,g} < 0{,}05
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

A hipótese $H_0: \beta_2 = \dots = \beta_C = 0$ é avaliada pelo teste de Wald
com variância robusta ao plano amostral (`regTermTest`):

$$
F \;=\; \frac{1}{q}\left(\hat{\boldsymbol\beta} - \boldsymbol\beta_0\right)^{\!\top}
\hat{V}\!\left(\hat{\boldsymbol\beta}\right)^{-1}
\left(\hat{\boldsymbol\beta} - \boldsymbol\beta_0\right)
\tag{18}
$$

com $q = C - 1$ graus de liberdade no numerador e graus de liberdade do
denominador determinados pelo número de UPAs menos o número de estratos.

Esse último ponto merece ênfase: **os graus de liberdade do teste são
governados pelo número de UPAs, não pelo número de pessoas entrevistadas**. Um
estrato com dez mil entrevistas distribuídas em poucas UPAs tem poder de teste
modesto. É a razão pela qual diferenças visualmente grandes entre estratos
finos frequentemente não alcançam significância.

### 6.4 Dois conjuntos de testes

**Testes demográficos.** Dentro de cada recorte geográfico, verificam se o
indicador difere entre categorias de sexo, cor/raça, faixa etária e instrução.
Respondem à pergunta "há desigualdade social *dentro* deste território?".

**Testes regionais.** Verificam se o indicador difere entre as categorias de um
mesmo recorte territorial — urbano × rural, entre estratos administrativos,
entre estratos agregados, entre estratos finos. Respondem à pergunta "há
desigualdade territorial *no estado*?".

### 6.5 Uma advertência sobre a comparação Teresina × Piauí

Comparar Teresina ao Piauí, literalmente, não é um teste válido: Teresina é um
**subconjunto** do Piauí, e todo residente da capital também é piauiense. Um
teste de diferença entre dois grupos pressupõe grupos disjuntos; aplicá-lo a um
conjunto e ao seu superconjunto produz uma estatística sem interpretação, além
de subestimar a diferença, já que o próprio peso de Teresina puxa a média
estadual em sua direção.

A comparação implementada é, portanto, **Teresina × resto do Piauí**, com a
capital excluída do segundo grupo. É esta que responde à pergunta de interesse
substantivo: a capital difere do restante do estado?

### 6.6 Comparações múltiplas

O conjunto de testes realizados a cada trimestre é numeroso — dezenas de
indicadores por dezenas de combinações de recorte. Sob a hipótese nula global,
espera-se que aproximadamente 5% dos testes resultem significativos por acaso.

Optou-se pelo limiar convencional de 5% **sem correção** para multiplicidade,
em coerência com o caráter descritivo e exploratório do relatório: os
resultados são apresentados como um panorama territorial, não como um conjunto
de hipóteses confirmatórias pré-registradas. A interpretação substantiva
prioriza, por consequência, padrões que se repetem entre indicadores e entre
trimestres, e não achados isolados marginalmente significativos. Havendo
interesse em uso confirmatório, recomenda-se o controle da taxa de falsas
descobertas (BENJAMINI; HOCHBERG, 1995) sobre a família de testes pertinente.

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
\tag{19}
$$

com $S(s) \in \{1, 2, 3\}$ indicando urbano tradicional, rural e FCU. O
município entra como barreira porque a UPA é unidade operacional de campo: um
entrevistador não cobre duas prefeituras.

Dentro de cada célula $c$ constrói-se o grafo de contiguidade
$G_c = (V_c, E_c)$, com

$$
E_c \;=\; \left\{ (s, s') \in V_c \times V_c \;:\; s \neq s',\; \partial A_s \cap \partial A_{s'} \neq \varnothing \right\}
\tag{20}
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
\tag{21}
$$

com $D_s$ o número de DPPO do setor e

$$
m_{S} =
\begin{cases}
60, & S = 2 \quad (\text{rural})\\
90, & S \in \{1, 3\} \quad (\text{urbano tradicional e FCU})
\end{cases}
\tag{22}
$$

**A variável de capacidade.** $D_s$ é obtido da variável `V06001` dos Agregados
por Setores do Censo 2022 — "pessoas responsáveis em domicílios particulares
permanentes ocupados". Como todo DPPO tem exatamente uma pessoa responsável,
`V06001` **é** a contagem de DPPO do setor.

**Algoritmo.** A partição que satisfaz (21) não é única, e o problema de
encontrar a partição de cardinalidade máxima sob restrição de conexidade é
NP-difícil. Adota-se heurística gulosa de crescimento de regiões: partindo de
cada setor como unidade isolada, enquanto existir unidade $u$ com
$\sum_{s\in u} D_s < m$ e com ao menos um vizinho disponível, seleciona-se a
unidade de menor carga e funde-se com **o vizinho de menor carga**:

$$
u^{*} = \arg\min_{u\,:\,\text{carga}(u) < m} \text{carga}(u),
\qquad
v^{*} = \arg\min_{v \in N(u^{*})} \text{carga}(v)
\tag{23}
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
\tag{24}
$$

com $W_h = N_h / N$ a fração da população no estrato $h$ e $S_h$ o
desvio-padrão da variável dentro do estrato. Minimizar a variância equivale,
portanto, a minimizar

$$
\Phi \;=\; \sum_{h=1}^{k} W_h S_h \;=\; \frac{1}{N}\sum_{h=1}^{k} N_h S_h
\tag{25}
$$

sujeito à restrição de capacidade da especificação:

$$
N_h \;\ge\; 150 \quad \text{para todo } h
\tag{26}
$$

**Solução exata.** Em estratificação univariada os estratos ótimos são sempre
**intervalos contíguos** da variável ordenada — não faz sentido um estrato
"pular" uma faixa de renda. Ordenando as UPAs por rendimento,
$x_{(1)} \le \dots \le x_{(n)}$, o problema reduz-se a escolher $k-1$ pontos de
corte. Como cada parcela $N_h S_h$ em (25) depende apenas dos elementos daquele
estrato, o objetivo é **separável**, e admite solução por programação dinâmica:

$$
f_h(j) \;=\; \min_{\,(h-1)\cdot 150\;\le\; i \;\le\; j - 150}
\Big\{\, f_{h-1}(i) \;+\; c(i+1,\, j) \,\Big\},
\qquad
c(a,b) = (b-a+1)\, S_{[a,b]}
\tag{27}
$$

com $f_1(j) = c(1,j)$ para $j \ge 150$, e a solução ótima em $f_k(n)$. Os
limites do índice $i$ impõem simultaneamente a restrição (26) ao estrato
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
| Estimação de variância | linearização de Taylor, UPA como unidade de conglomeração |
| Nível de confiança | 95% (aproximação normal, $z = 1{,}96$) |
| Limiar de precisão para o corpo do texto | CV < 15% |
| Classes de CV | < 5% excelente; 5–15% boa; 15–30% regular; ≥ 30% baixa |
| Razão formal/informal | contraste `log` via `svyby(covmat = TRUE)` + `svycontrast` |
| Teste — resposta categórica | qui-quadrado de Rao-Scott (`svychisq`) |
| Teste — resposta numérica | Wald sobre `svyglm` gaussiano (`regTermTest`) |
| Teste — resposta binária | Wald sobre `svyglm` quasibinomial |
| Nível de significância | p < 0,05, sem correção para multiplicidade |
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

SÄRNDAL, Carl-Erik; SWENSSON, Bengt; WRETMAN, Jan. **Model assisted survey
sampling**. New York: Springer, 1992.

SILVA, Pedro Luis do Nascimento; PESSOA, Djalma Galvão Carneiro; LILA, Maurício
Franca. Análise estatística de dados da PNAD: incorporando a estrutura do plano
amostral. **Ciência & Saúde Coletiva**, Rio de Janeiro, v. 7, n. 4, p. 659-670,
2002. *(referência indicada como fonte dos critérios de formação de UPAs;
confirmar os dados completos antes da publicação)*

STATISTICS CANADA. **Survey methods and practices**. Ottawa: Statistics Canada,
2010. (Catalogue no. 12-587-X).

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

Ao ler esta tabela, tenha presente a advertência da seção 6.6: são
{N_TESTES_DEMO} testes, dos quais se espera que cerca de 5% resultem
significativos por acaso sob a hipótese nula. Padrões que se repetem entre
indicadores e entre trimestres são muito mais informativos do que qualquer
resultado isolado.

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
