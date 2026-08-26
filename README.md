# Indicadores socioeconômicos dos estratos do Piauí — PNAD Contínua

Acompanhamento de **renda, educação e mercado de trabalho** nos estratos
geográficos do Piauí, a partir dos microdados trimestrais da PNAD Contínua
do IBGE.

Esta é a **nota técnica de lançamento**. A cada nova edição trimestral da
PNADC o pipeline é reexecutado e a nota é atualizada.

O que distingue este projeto de um acompanhamento estadual comum é a
desagregação: em vez de parar no total do Piauí, os indicadores são
estimados **por estrato amostral da própria pesquisa** — incluindo os
estratos de 7 dígitos, o nível mais fino que o desenho da PNADC permite.

---

## Como o projeto está organizado

São duas metades que se encontram no `Estrato`:

**A. Estimação dos indicadores** (`01_pipeline_trimestral.R`, `03_`) — baixa os
microdados, calcula os indicadores em cada nível geográfico e recorte
demográfico, roda os testes de significância e monta as tabelas e figuras
comparativas.

**B. Geografia dos estratos** (`04_` a `08_`) — descobre *onde ficam* os
estratos que a metade A usa como recorte, na resolução do setor censitário.
Isso não é trivial: o IBGE publica o código do estrato nos microdados, mas
não a fronteira completa. Os detalhes estão em
[`output/reconstrucao_estratos.md`](output/reconstrucao_estratos.md).

A metade B só precisa rodar de novo quando o IBGE muda o desenho amostral
(nova amostra mestra) ou a malha de setores — **não a cada trimestre**.

---

## Sequência dos scripts

```
R/00_config.R                    ANO_REF, TRIMESTRE_REF, salário mínimo,
│                                geografias agregadas  ← mexa só aqui
│
├──▶ R/01_pipeline_trimestral.R
│   PNADcIBGE::get_pnadc(ano, trimestre)  →  baixa os microdados
│   (desenho de réplicas bootstrap: o pacote monta svrepdesign sempre que os
│    microdados trazem os 200 pesos V1028001..V1028200)
│   ├─ output/base_<AAAAT#>.csv                 indicadores x geografia x recorte
│   ├─ output/testes_significancia_<AAAAT#>.csv ANOVA demográfica
│   ├─ output/testes_regionais_<AAAAT#>.csv     ANOVA entre estratos
│   ├─ output/renda_individual_<AAAAT#>.csv     renda individual ponderada
│   ├─ output/crosswalk_estratos.csv            Estrato → Zona/Admin/Agregado
│   ├─ output/crosswalk_estratos_<AAAAT#>.csv   idem, arquivado por trimestre
│   ├─ output/desigualdade_formal_informal_<AAAAT#>.csv  razão formal/informal
│   ├─ output/log_falhas_<AAAAT#>.csv           o que não foi estimado, e por quê
│   ├─ output/log_falhas_testes_<AAAAT#>.csv    o que não foi testado, e por quê
│   └─ output/figuras/  hist_cv, boxplot_cv_nivel, renda_total, renda_setor
│
├──▶ R/03_comparacoes_indicadores.R
│       source("R/00_config.R") ;  lê base_ + testes_ ;  não recalcula nada
│       ├─ output/tabelas/  comparacao_geografica, comparacao_demografica,
│       │                   anova_demografica, anova_regional
│       └─ output/figuras/  comp_geo_<indicador>, anova_demografica, anova_regional
│
├──▶ R/09_preencher_relatorio.R
│       lê o modelo output/relatorio_trimestral.md + as saídas acima
│       └─ output/relatorio_trimestral_<AAAAT#>.md   a edição do trimestre
│
└──▶ R/Teste_estrutura_aaagsse.R
        confere a hipótese AAA|GG|S|E contra o crosswalk (só imprime, não grava)


R/04_mapas_estratos_piaui.R
│   WFS do GeoServer do IBGE + crosswalk_estratos.csv
│   ├─ output/estratos_piaui.gpkg          ← insumo de 05, 06 e 08
│   └─ output/figuras/mapa_estratos_piaui.png
│
├──▶ R/05_setores_censitarios_piaui.R
│       malha de setores 2022 + estratos_piaui.gpkg
│       ├─ output/setores_censitarios_piaui_classificados.gpkg
│       └─ output/figuras/  mapa_setores_zona, _estrato_admin,
│                           _estrato_agregado, _situacao, _4painéis
│
└──▶ R/06_upas_piaui.R
     │   malha de setores + renda do responsável (Censo 2022) + estratos_piaui.gpkg
     │   ├─ output/upas_piaui.csv               5.949 UPAs reconstruídas
     │   ├─ output/setores_com_upa_piaui.gpkg
     │   └─ output/tabelas/diagnostico_upas.csv
     │
     └──▶ R/07_estrato_estatistico.R
          │   estratificação ótima da renda → o 7º dígito (E)
          │   ├─ output/upas_com_estrato_estatistico.csv
          │   ├─ output/setores_com_estrato_completo.gpkg
          │   └─ output/tabelas/  estratificacao_diagnostico,
          │                       validacao_contra_crosswalk,
          │                       equivalencia_estratos,
          │                       comparacao_metodos_estratificacao
          │
          └──▶ R/08_mapa_aaagsse.R
                  output/figuras/mapa_aaagsse_piaui.png  (+ 6 painéis avulsos)
```

`output/estratos_piaui.gpkg` **não é versionado** (está no `.gitignore`). Num
clone novo, rode o `04_` antes de qualquer coisa da metade B.

---

## Atualizar para um novo trimestre

1. `R/00_config.R` — ajuste `ANO_REF` e `TRIMESTRE_REF`. **É o único lugar.**
   Os dois scripts do pipeline dão `source()` nesse arquivo.
2. Se virou o ano, acrescente a linha do ano novo em `tabela_salario_minimo`,
   também no `00_config.R` — é o que define o corte de subremuneração. Sem
   isso o script **para com erro nomeando o problema**, antes de baixar
   qualquer coisa; não há risco de gerar relatório silenciosamente errado.
3. Rode, nesta ordem, `01_pipeline_trimestral.R`,
   `03_comparacoes_indicadores.R` e `09_preencher_relatorio.R`.

O `09_` monta a edição do trimestre a partir de
[`output/relatorio_trimestral.md`](output/relatorio_trimestral.md), que é o
**modelo** — reaproveitado a cada rodada, nunca sobrescrito. Ele resolve três
construções:

| No modelo | Vira |
|---|---|
| `<!-- @tabela tipo=geografica indicador=X -->` | a tabela inteira, com estimativa, IC, CV e classe de precisão |
| `{{est Taxa_Desocupacao Piauí}}` | o número, já formatado em português |
| `<!-- @redigir: ... -->` | um bloco **A REDIGIR** no arquivo gerado |

O terceiro existe porque nem todo vazio é preenchível por máquina: interpretar
um contraste, decidir se um bloco demográfico entra, escrever a síntese final.
O script lista esses trechos no console ao terminar — nesta edição são 16.

E ele **falha** se sobrar qualquer marcador não resolvido. Um relatório meio
preenchido publicado por engano é pior que nenhum.

Os scripts `04_` a `08_` não precisam ser reexecutados a cada trimestre —
**com uma ressalva importante, descrita abaixo.**

### A substituição das UPAs em curso

O IBGE está trocando a amostra mestra de forma progressiva, substituindo as
UPAs de primeira entrevista a cada trimestre: 20% no 3º/2025, 40% no 4º/2025,
60% no 1º/2026, 80% no 2º/2026 e 100% no 3º/2026.

Enquanto a troca não termina, o conjunto de códigos de `Estrato` observado nos
microdados é uma **mistura de duas safras** — parte no desenho antigo (base
Censo 2010), parte no novo (base Censo 2022). Por isso o
`01_pipeline_trimestral.R` grava o crosswalk em duas cópias: a corrente
(`crosswalk_estratos.csv`, que o `04_` e o `07_` leem) e uma **arquivada por
trimestre** (`crosswalk_estratos_<AAAAT#>.csv`). Sem a segunda, cada rodada
apagaria a evidência da anterior e não haveria como comparar as safras.

A partir do 3º trimestre de 2026 a amostra estará 100% renovada, e a
reconstrução dos estratos deve ser reexecutada e revalidada contra esse
crosswalk — é quando as ressalvas em
[`output/reconstrucao_estratos.md`](output/reconstrucao_estratos.md) podem ser
fechadas em definitivo.

---

## O que é estimado

**Mercado de trabalho** — taxa de desocupação, informalidade, subocupação por
insuficiência de horas, desalento (na força ampliada e fora da força),
responsáveis pelo domicílio desocupados, nem-nem (14 a 29 anos) e os motivos
declarados.

**Renda** — rendimento médio habitual real, rendimento no setor formal e no
informal, subremuneração (abaixo do salário mínimo/hora), distribuição da
renda por geografia e por setor público/privado.

**Educação** — ocupados com médio completo ou mais, grau de instrução como
recorte de todos os indicadores, motivos de não estudar entre os nem-nem.

Cada indicador é estimado em:

| Nível | Categorias |
|---|---|
| Agregados | Brasil, Nordeste, Piauí, Teresina |
| Zona | urbana, rural |
| Estrato administrativo | capital, resto da RIDE, resto da UF |
| Estrato agregado | os 5 agrupamentos geográficos do estado |
| Estrato (7 dígitos) | os 26 estratos amostrais do Piauí |

Cruzado com os recortes de sexo, cor/raça, faixa etária e grau de instrução —
com teste de significância acompanhando cada comparação, e classificação de
confiabilidade pelo coeficiente de variação (corte de 15% do IBGE).

---

## Dados necessários (não versionados)

| Caminho | Fonte |
|---|---|
| — (baixado em tempo de execução) | PNADC trimestral, via `PNADcIBGE::get_pnadc()` |
| `data/raw/setores/PI_setores_CD2022.shp` | malhas de setores censitários, Censo 2022 |
| `data/raw/renda/Agregados_por_setores_renda_responsavel_BR.xlsx` | Agregados por Setores — renda do responsável |
| — (baixado em tempo de execução) | polígonos dos estratos, GeoServer do IBGE |

O `06_` filtra o Piauí da planilha nacional uma vez e guarda o recorte em
`data/raw/renda/renda_responsavel_PI.csv`, para não reler o arquivo inteiro
a cada rodada.

---

## Estrutura de pastas

```
R/              pipeline em produção (00_config.R concentra os parâmetros)
scripts_teste/  validações independentes e código herdado (ver abaixo)
output/         tabelas, figuras e a nota técnica
data/raw/       insumos externos (ignorado pelo git)
```

### `scripts_teste/`

Nem tudo aqui é código morto:

- **`pnadc_estratos_testes.R`** e **`motivos_de_nao_estudar_nem-nem.R`** são
  implementações independentes dos indicadores, escritas à parte para
  conferir se as estimativas do pipeline estavam certas. Servem de
  contraprova — não apague.
- **`GERAR_FIGURAS_TABELAS.R`** é uma versão anterior do
  `03_comparacoes_indicadores.R`. Está aqui, e não em `R/`, porque grava nos
  mesmos caminhos do `03` e sobrescreveria as saídas dele em silêncio.
- O restante (`01_run.R`, `01_processamento_dados.R`,
  `02_testes_significancia.R`, `02_analise_consistencia.R`,
  `pnadc_estratosv1.R`, `pnadc_estratosv2.R`, `tentativa_cruzamento.R`) vem
  da versão que montava a série histórica dos indicadores, hoje fora do
  escopo imediato.

---

## Principais resultados da reconstrução dos estratos

- **5.949 UPAs** reconstruídas a partir de 7.331 setores censitários,
  nenhuma abaixo do mínimo do Censo 2022 (60 domicílios rurais / 90 urbanos).
- O número de estratos estatísticos **confere com o crosswalk oficial da
  PNADC em 11 de 11 células geográficas**; 25 dos 26 estratos do estado têm
  correspondência 1:1.
- A estratificação é resolvida de forma **exata** (programação dinâmica), e
  não por heurística: na escala do Piauí o problema é pequeno o bastante.
- Redução de variância entre 75% e 90%, conforme a célula.

Método, validação e ressalvas em
[`output/reconstrucao_estratos.md`](output/reconstrucao_estratos.md).

![Estratos AAAGGSE do Piauí](output/figuras/mapa_aaagsse_piaui.png)

---

## Próximos passos

- Série histórica trimestral dos indicadores (o código herdado em
  `scripts_teste/` é o ponto de partida).
- Incorporação da PNADC anual.

---

## Requisitos

R com `PNADcIBGE`, `survey`, `dplyr`, `tidyr`, `purrr`, `readr`, `tibble`,
`stringr`, `ggplot2`, `sf`, `patchwork`, `igraph` e `readxl`.
