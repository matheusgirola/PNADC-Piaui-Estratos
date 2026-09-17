<!-- @somente-modelo -->
> **ESTE ARQUIVO É O MODELO — NÃO É UM RELATÓRIO PRONTO.**
> Gera `output/relatorio_trimestral_<AAAAT#>.md` (e o `.docx`) com
> `Rscript R/09_preencher_relatorio.R`, depois do `01` e da triagem (`R/11`).
>
> Estrutura decidida em 17/09/2026 (`CONTEXTO_PROJETO.md` §8.7): público gestor,
> corpo curto, território em matrizes por dimensão, todo o resto no anexo.
>
> Construções resolvidas pelo script:
> - `<!-- @tabela tipo=... -->` vira tabela ou lista inteira (destaques, matriz,
>   categorias, pontos-temporais, pontos-territoriais, pontos-demograficos,
>   anexo-indicadores, anexo-testes, anexo-triagem);
> - `\{\{est Indicador Geografia\}\}` e afins viram números;
> - `<!-- @redigir: ... -->` sai como bloco **A REDIGIR**.
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

**Tabela 1** — Indicadores de destaque: Brasil, Nordeste e Piauí, e variação do Piauí — {{trimestre}}

<!-- @tabela tipo=destaques -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Nota: variação em pontos percentuais (taxas), reais (rendimento) ou unidades
do índice (Gini). \*\*\* p < 0,001; \*\* p < 0,01; \* p < 0,05; ns = não
significativo (p ajustado). † = precisão regular na série; – = não sustenta
leitura. Ver seção 2.

<!-- @redigir: dois ou três parágrafos com a leitura dos destaques — só o que a Tabela 1 marca como significativo; variação "ns" não é aumento nem queda. -->

## 2 Como ler as tabelas

Todas as estimativas vêm de uma amostra, e por isso cada número tem uma
margem de erro. Três marcas orientam a leitura:

- **Valor sem marca**: o indicador, naquele território, teve coeficiente de
  variação abaixo de 15% em pelo menos 80% dos trimestres desde 2022. É um
  número confiável para acompanhamento trimestral.
- **Valor com †**: precisão regular (coeficiente de variação entre 15% e 30%
  na maior parte da série). Serve como indicação, não como base para decisão.
- **–**: a amostra não sustenta a estimativa naquele território.

Os **asteriscos** dizem se as diferenças são estatisticamente significativas,
isto é, se não se explicam por acaso amostral: \*\*\* p < 0,001; \*\* p < 0,01;
\* p < 0,05; ns = não significativo. Nas matrizes territoriais, a coluna
"Teste estratos" diz se os cinco estratos diferem entre si, e "Teste zona", se
urbano e rural diferem. Os testes não apontam *qual* território difere — para
isso, compare os valores. Detalhes na nota metodológica (Anexo A).

## 3 Ocupação e desocupação

**Tabela 2** — Ocupação e desocupação, por território — {{trimestre}}

<!-- @tabela tipo=matriz dimensao=ocupacao -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

<!-- @redigir: leitura da Tabela 2 — um parágrafo curto, apoiado nos pontos de atenção (seção 8). -->

## 4 Qualidade da ocupação

**Tabela 3** — Qualidade da ocupação, por território — {{trimestre}}

<!-- @tabela tipo=matriz dimensao=qualidade -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

<!-- @redigir: leitura da Tabela 3 — um parágrafo curto. -->

## 5 Rendimento e desigualdade

**Tabela 4** — Rendimento e desigualdade, por território — {{trimestre}}

<!-- @tabela tipo=matriz dimensao=rendimento -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Nota: rendimento médio real habitual de todos os trabalhos, deflacionado pelo
IBGE. O índice de Gini vai de 0 (igualdade total) a 1 (desigualdade máxima).

<!-- @redigir: leitura da Tabela 4 — um parágrafo curto. -->

## 6 Vulnerabilidade

**Tabela 5** — Desalento e jovens que não estudam nem trabalham, por território — {{trimestre}}

<!-- @tabela tipo=matriz dimensao=vulnerabilidade -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

Os motivos declarados só têm amostra suficiente no nível do estado, e por isso
aparecem agrupados e sem recorte territorial.

**Tabela 6** — Motivos declarados por desalentados e jovens nem-nem (distribuição, %) — {{trimestre}}

<!-- @tabela tipo=categorias dimensao=motivos -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.

<!-- @redigir: leitura das Tabelas 5 e 6 — um parágrafo curto. -->

## 7 Perfil da população em idade de trabalhar

**Tabela 7** — Composição da população de 14 anos ou mais (%) — {{trimestre}}

<!-- @tabela tipo=categorias dimensao=populacao -->

Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria.
Nota: a composição por território está no Anexo D.

## 8 Pontos de atenção

Esta seção reúne apenas os resultados estatisticamente significativos e com
precisão suficiente.

**Variações no tempo (Piauí)**

<!-- @tabela tipo=pontos-temporais -->

**Diferenças entre territórios**

<!-- @tabela tipo=pontos-territoriais -->

**Diferenças por sexo, cor ou raça, idade e instrução**

Um recorte demográfico só aparece aqui se, naquele território, a diferença
entre os grupos for significativa e todos os grupos tiverem precisão boa na série.

<!-- @tabela tipo=pontos-demograficos -->

## 9 Considerações finais

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
Parnaíba e Alto Parnaíba e Chapadas do Sul) e a situação do domicílio (urbana
ou rural). O estrato administrativo aparece só nos anexos, porque repete
informação dos estratos agregados.

**Confiabilidade (marcas † e –).** A marca de cada número não vem do CV do
trimestre isolado, que é ele próprio sujeito a ruído, mas do comportamento do
mesmo indicador, no mesmo território, de 2022T1 até o trimestre atual. Sem
marca: CV abaixo de 15% em pelo menos 80% dos trimestres. †: nesse mesmo
patamar da série, CV entre 15% e 30%. –: acima de 30% ou instável (CV acima de
30% em algum dos quatro últimos trimestres). Os cortes de 15% e 30% seguem as
faixas de precisão usadas pelo IBGE. Brasil e Nordeste não fazem parte dessa
série e usam o CV do próprio trimestre.

**Diferenças entre territórios e grupos.** Testes de razão de verossimilhança
sobre o desenho amostral (`svyglm` com `regTermTest`, método LRT, e
`svychisq` para respostas categóricas). Os p-valores são ajustados para
comparações múltiplas pelo método de Benjamini-Hochberg.

**Variações no tempo.** A diferença entre dois trimestres é testada tratando
as amostras como independentes. Como o painel rotativo da PNAD Contínua faz
trimestres próximos compartilharem domicílios, a variância verdadeira da
diferença é menor que a usada no teste: o resultado é conservador, ou seja,
pode deixar de apontar uma variação real, mas não aponta variações que não
existem. Os p-valores são ajustados por Benjamini-Hochberg dentro da Tabela 1.

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
