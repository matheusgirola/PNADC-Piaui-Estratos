<!-- @somente-modelo -->
> **ESTE ARQUIVO É O MODELO — NÃO É UM RELATÓRIO PRONTO.**
> Gera `output/relatorio_trimestral_<AAAAT#>.md` (e o `.docx`) com
> `Rscript R/09_preencher_relatorio.R`, depois do `01`, da triagem (`R/11`) e
> das figuras do panorama (`R/12_graficos_panorama.R`).
>
> Estrutura decidida em 17/09/2026 (`CONTEXTO_PROJETO.md` §8.7): público gestor,
> corpo curto, território em matrizes por dimensão, todo o resto no anexo.
> Figuras 1-4 (seções 2, 4, 5 e 6) adicionadas em 21/09/2026; em 22/09/2026 a
> Figura 2 passou do nível da ocupação para a taxa de participação e entraram
> as Figuras 5 (nem-nem, seção 7) e 6 (pessoas de 14 a 59 anos, seção 8) —
> únicas figuras do corpo; aparecem no `.md` e no `.docx` (o filtro Lua que
> as removia da conversão foi descontinuado em 21/09, a pedido do usuário).
> Figuras 2-6 usam Brasil, Nordeste e os mesmos 8 territórios do corpo
> (grade 5x2: Piauí, Teresina, Entorno metropolitano, Centro-Leste, Baixo
> Parnaíba, Alto Parnaíba e Chapadas, Zona Urbana, Zona Rural).
>
> Construções resolvidas pelo script:
> - `<!-- @tabela tipo=... -->` vira tabela ou lista inteira (destaques, matriz,
>   categorias, pontos-territoriais, pontos-demograficos, anexo-indicadores,
>   anexo-testes, anexo-triagem);
> - `\{\{est Indicador Geografia\}\}` e afins viram números;
> - `<!-- @redigir: ... -->` sai como bloco **A REDIGIR**;
> - `{{sufixo}}` no caminho de uma imagem (ex.: `figuras/panorama_piaui_{{sufixo}}.png`)
>   vira o trimestre atual — o script NÃO confere se o arquivo existe, rode o
>   `R/12` antes se mexer no trimestre de referência.
>
> Regra de redação: o texto só comenta diferença **significativa** (p ajustado)
> **e** com precisão aceitável na série; o resto fica só nas tabelas.
> O script FALHA se sobrar marcador não resolvido.
<!-- /@somente-modelo -->

**VERSÃO AUTOMÁTICA DO RELATÓRIO — REVER OS TEXTOS E REDIGIR AS ANÁLISES**

## 1 Destaques do trimestre

No {{trimestre}}, a taxa de desocupação do Piauí foi de
{{est Taxa_Desocupacao Piauí}}%, ante {{est Taxa_Desocupacao Nordeste}}% no
Nordeste e {{est Taxa_Desocupacao Brasil}}% no Brasil. A taxa de participação
na força de trabalho ficou em {{est Taxa_Participacao Piauí}}%
({{est Taxa_Participacao Brasil}}% no Brasil) e a taxa composta de
subutilização, em {{est Taxa_Composta_Subutilizacao Piauí}}%. O rendimento
médio real habitual do trabalho no estado, de
{{est Rendimento_Medio_Habitual Piauí}}, equivale a
{{pct_de Rendimento_Medio_Habitual Piauí Brasil}}% do nacional.

**Tabela 1** — Indicadores de destaque: Brasil, Nordeste e Piauí — {{trimestre}}

<!-- @tabela tipo=destaques -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Nota: † = precisão regular na série; – = não sustenta leitura. Ver seção 3.

<!-- @redigir: dois ou três parágrafos com a leitura dos destaques do trimestre — Piauí frente a Brasil e Nordeste. -->

## 2 Panorama da série

A Tabela 1 retrata o trimestre corrente; esta seção mostra a trajetória desde
2016T2 dos seis indicadores aprovados na triagem de confiabilidade (Anexo B) —
taxa de desocupação, nível da ocupação, taxa de participação, taxa de
informalidade, subocupação por insuficiência de horas e rendimento médio real
habitual, para o Piauí, com Brasil e Nordeste como referência. A banda sombreada em cada gráfico é o intervalo
de confiança de 95%; a faixa rosa marca a coleta por telefone durante a
pandemia (2020T2–2021T4) e a faixa laranja, a transição em curso do desenho
amostral do Censo 2010 para o Censo 2022 (2025T3 em diante) — dois períodos em
que a leitura da série pede mais cautela.

**Figura 1** — Panorama da série: indicadores-farol do Piauí, do Nordeste e do Brasil, 2016T2–{{trimestre}}

![Panorama da série — Piauí, Nordeste e Brasil](figuras/panorama_piaui_{{sufixo}}.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

<!-- @redigir: leitura da Figura 1 — um ou dois parágrafos sobre a trajetória geral (recuperação pós-pandemia, patamar atual frente ao início da série). -->

## 3 Como ler as tabelas

Todas as estimativas vêm de uma amostra, e por isso cada número tem uma
margem de erro. Três marcas orientam a leitura:

- **Valor sem marca**: o indicador, naquele território, teve coeficiente de
  variação abaixo de 15% em pelo menos 80% dos trimestres desde 2022. É um
  número confiável para acompanhamento trimestral.
- **Valor com †**: precisão regular (coeficiente de variação entre 15% e 30%
  na maior parte da série). Serve como indicação, não como base para decisão.
- **–**: a amostra não sustenta a estimativa naquele território.

Brasil e Nordeste aparecem como referência. Para eles, a marca segue o
coeficiente de variação do próprio trimestre, com os mesmos cortes.

Os **asteriscos** dizem se as diferenças são estatisticamente significativas,
isto é, se não se explicam por acaso amostral: \*\*\* p < 0,001; \*\* p < 0,01;
\* p < 0,05; ns = não significativo. Nas matrizes territoriais, a coluna
"Teste estratos" diz se os cinco estratos diferem entre si{{#se-situacao}}, "Teste zona", se
urbano e rural diferem, e "Teste situação", se rural, urbano tradicional e
Favela/Comunidade Urbana (FCU) diferem entre si{{/se}}{{#se-nao-situacao}} e "Teste zona", se
urbano e rural diferem{{/se}}. Os testes não apontam *qual*
território difere — para isso, compare os valores. Detalhes na nota
metodológica (Anexo A).

## 4 Ocupação e desocupação

**Figura 2** — Taxa de participação na força de trabalho por território, 2016T2–{{trimestre}}

![Taxa de participação na força de trabalho por território](figuras/territorial_participacao_{{sufixo}}.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Tabela 2** — Ocupação e desocupação, por território — {{trimestre}}

<!-- @tabela tipo=matriz dimensao=ocupacao -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

<!-- @redigir: leitura da Tabela 2 — um parágrafo curto, apoiado nos pontos de atenção (seção 9). -->

## 5 Inserção no mercado de trabalho

**Figura 3** — Taxa de informalidade por território, 2016T2–{{trimestre}}

![Taxa de informalidade por território](figuras/territorial_informalidade_{{sufixo}}.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Tabela 3** — Inserção no mercado de trabalho, por território — {{trimestre}}

<!-- @tabela tipo=matriz dimensao=insercao -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

<!-- @redigir: leitura da Tabela 3 — um parágrafo curto. -->

## 6 Rendimento e desigualdade

**Figura 4** — Rendimento médio real habitual por território, 2016T2–{{trimestre}}

![Rendimento médio real habitual por território](figuras/territorial_rendimento_estratos_{{sufixo}}.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Tabela 4** — Rendimento e desigualdade, por território — {{trimestre}}

<!-- @tabela tipo=matriz dimensao=rendimento -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Nota: rendimento médio real habitual de todos os trabalhos, deflacionado pelo
IBGE. O índice de Gini vai de 0 (igualdade total) a 1 (desigualdade máxima).

<!-- @redigir: leitura da Tabela 4 — um parágrafo curto. -->

## 7 Vulnerabilidade

**Figura 5** — Jovens de 14 a 29 anos que não estudam nem trabalham, por território, 2016T2–{{trimestre}}

![Jovens nem-nem por território](figuras/territorial_nem_nem_{{sufixo}}.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Tabela 5** — Desalento, jovens que não estudam nem trabalham e responsáveis pelo domicílio entre os desocupados, por território — {{trimestre}}

<!-- @tabela tipo=matriz dimensao=vulnerabilidade -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

Os motivos declarados só têm amostra suficiente no nível do estado, e por isso
aparecem agrupados e sem recorte territorial.

**Tabela 6** — Motivos declarados por desalentados e jovens nem-nem (distribuição, %) — {{trimestre}}

<!-- @tabela tipo=categorias dimensao=motivos -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

<!-- @redigir: leitura das Tabelas 5 e 6 — um parágrafo curto. -->

## 8 Perfil da população em idade de trabalhar

**Figura 6** — Pessoas de 14 a 59 anos na população total, por território (%), 2016T2–{{trimestre}}

![Pessoas de 14 a 59 anos por território](figuras/territorial_populacao_14_59_{{sufixo}}.png)

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

**Tabela 7** — Composição da população de 14 anos ou mais, por território (%) — {{trimestre}}

<!-- @tabela tipo=matriz dimensao=populacao -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

## 9 Pontos de atenção

Esta seção reúne apenas os resultados estatisticamente significativos e com
precisão suficiente.

**Diferenças entre territórios**

<!-- @tabela tipo=pontos-territoriais -->

O rendimento é onde a diferença territorial mais se sustenta ao longo do
tempo, não só no trimestre corrente — ver a série completa por território na
Figura 4 (seção 6).

**Diferenças por sexo, cor ou raça, idade e instrução**

Esta edição não traz os recortes demográficos por território. Neles, parte das
réplicas bootstrap que estimam a precisão fica sem observação na célula e é
descartada, o que pode subestimar o erro padrão — e é o erro padrão que decide
o que tem precisão suficiente para ser publicado. Enquanto a questão não se
resolve, esses resultados ficam restritos ao anexo metodológico (seção 6.9 e
apêndices A e C), com a ressalva de precisão.

## 10 Considerações finais

<!-- @redigir: síntese em dois ou três parágrafos — Piauí frente a Brasil e Nordeste; Teresina e interior; urbano e rural; o que mudou no tempo. -->

## Anexo A — Nota metodológica

**Fonte e desenho amostral.** Microdados da PNAD Contínua trimestral (IBGE),
com o desenho amostral completo: pesos calibrados e 200 réplicas de bootstrap
fornecidas pelo IBGE. Todas as estimativas, erros-padrão, intervalos de
confiança de 95% e coeficientes de variação (CV = erro-padrão / estimativa)
são calculados sobre esse desenho. Rendimentos em valores reais, deflacionados
pelo deflator do IBGE que acompanha os microdados. As definições dos
indicadores seguem as notas metodológicas da PNAD Contínua e estão validadas
contra as tabelas oficiais do SIDRA para o Piauí.

**Territórios.** Brasil, Nordeste e Piauí; dentro do Piauí, os cinco estratos
agregados da amostra (Teresina, entorno metropolitano, Centro-Leste, Baixo
Parnaíba e Alto Parnaíba e Chapadas do Sul){{#se-situacao}}, a zona do domicílio (urbana ou
rural) e a situação (rural, urbano tradicional ou Favela/Comunidade Urbana —
FCU), um recorte mais fino que a zona simples porque separa a FCU como grupo
próprio — dígito `S` do código de estrato da amostra (AAAGGS, 6 dígitos){{/se}}{{#se-nao-situacao}} e a zona do
domicílio (urbana ou rural){{/se}}. O
estrato administrativo aparece só nos anexos, porque repete informação dos
estratos agregados.

**Confiabilidade (marcas † e –).** A marca de cada número não vem do CV do
trimestre isolado, que é ele próprio sujeito a ruído, mas do comportamento do
mesmo indicador, no mesmo território, de 2022T1 até o trimestre atual. Sem
marca: CV abaixo de 15% em pelo menos 80% dos trimestres. †: nesse mesmo
patamar da série, CV entre 15% e 30%. –: acima de 30% ou instável (CV acima de
30% em algum dos quatro últimos trimestres). Os cortes de 15% e 30% seguem as
faixas de precisão usadas pelo IBGE. Brasil e Nordeste não fazem parte dessa
série e usam o CV do próprio trimestre.

**Indicadores.** A tabela abaixo reúne todos os indicadores que aparecem no
corpo e nos anexos, com a dimensão em que são publicados, a medida e a
definição. As fórmulas completas e as variáveis da PNAD Contínua que as
alimentam estão nos scripts de estimação.

**Tabela A.1** — Indicadores utilizados, por dimensão

<!-- @tabela tipo=definicoes -->

Fonte: IBGE — PNAD Contínua trimestral, notas metodológicas e microdados. Elaboração própria.

**Diferenças entre territórios e grupos.** Testes de razão de verossimilhança
sobre o desenho amostral (`svyglm` com `regTermTest`, método LRT, e
`svychisq` para respostas categóricas). Os p-valores são ajustados para
comparações múltiplas pelo método de Benjamini-Hochberg.

## Anexo B — Resolução territorial de cada indicador

Percentual de categorias do indicador que passam no critério de confiabilidade
(sem marca), por nível territorial, de 2022T1 a {{sufixo}}.

**Tabela B.1** — Aprovação na triagem de confiabilidade, por indicador e nível territorial

<!-- @tabela tipo=anexo-triagem -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

## Anexo C — Testes de diferença entre territórios

**Tabela C.1** — p-valor bruto / p-valor ajustado, por indicador e recorte — {{trimestre}}

<!-- @tabela tipo=anexo-testes -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

## Anexo D — Tabelas completas

<!-- @tabela tipo=anexo-indicadores -->
