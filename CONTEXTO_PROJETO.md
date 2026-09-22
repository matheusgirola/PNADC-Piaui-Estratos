# Pipeline de Indicadores PNADC — Piauí

Documentação de contexto do projeto: o que ele faz, como está organizado, as decisões metodológicas tomadas ao longo do caminho e o que ainda está em aberto. Serve como ponto de partida pra qualquer pessoa (incluindo você, daqui a alguns meses) que precise entender ou retomar o trabalho.

## 1. Objetivo

Encontrar e calcular indicadores socioeconômicos a partir dos microdados da PNAD Contínua (IBGE), para um relatório que é **atualizado a cada trimestre**, cobrindo:

- **Níveis geográficos agregados**: Brasil, Nordeste, Piauí, Teresina.
- **Níveis geográficos finos** (dentro do Piauí): Zona (Urbana/Rural), Estrato Administrativo (Capital/Resto da RIDE/Resto da UF), Estrato Agregado (Teresina, Entorno Metropolitano, Centro-Leste, Baixo Parnaíba, Alto Parnaíba e Chapadas do Sul).
- **Recortes demográficos** (cruzados só com os níveis finos): Sexo, Faixa Etária, Grau de Instrução.

O projeto também inclui testes de significância (a "ANOVA" mencionada nas conversas — na prática, `svyglm`+`regTermTest`/`svychisq`, adequados ao desenho amostral complexo), gráficos de confiabilidade, uma análise de distribuição de renda, e mapas dos subestratos do Piauí.

O objetivo é bem sucedido ao encontrarmos indicadores que tenham o maior número possível de trimestres com CV de nível excelente ou bom. Esses indicadores serão sempre reaproveitados para relatórios futuros.

### Evolução do escopo

O projeto começou como uma **série histórica** (4ºT/2015 a 2ºT/2026, processada em ordem reversa por causa do tempo de download). Depois de identificar que a maioria dos indicadores só precisa do trimestre mais recente pro relatório, o foco migrou pra um **pipeline de trimestre único** (`pipeline_trimestre.R`), reprocessado a cada atualização. Os scripts da série histórica (`01_run.R`, `02_testes_significancia.R`) continuam existindo e funcionam, mas não são mais o fluxo principal.

**Segunda mudança de rumo (set/2026), motivada pela revisão do relatório 2T2026 — em andamento, várias partes ainda não implementadas:**

- **O objetivo deixa de ser "cobrir o máximo de indicadores possível" e passa a ser encontrar os indicadores (e a resolução geográfica) confiáveis o suficiente pra sustentar acompanhamento trimestral contínuo** — ver a frase de sucesso na seção 1. Isso exige voltar a rodar a **série histórica**, porque a confiabilidade de um indicador não se avalia num único trimestre: o CV de um trimestre isolado é ele mesmo uma estimativa sujeita a ruído amostral. Olhar a distribuição do CV de cada par indicador×recorte ao longo de vários trimestres é o que dá base estatística sólida pra essa triagem.
  - A confiabilidade não é uma propriedade só do indicador: é do par indicador×recorte geográfico. O resultado dessa triagem deveria ser algo como "cada indicador + a resolução mais fina em que ele é utilizável", não uma lista binária de indicadores aprovados/reprovados — isso evita descartar de vez indicadores de alto interesse (desalento, motivos de não-procura) só porque não sobrevivem no recorte mais fino, quando ainda podem ser ótimos no estrato agregado.
- **O recorte de estrato fino (7 dígitos, AAAGGSE completo) sai do relatório.** Além de concentrar as estimativas de pior precisão e os testes que mais falham por posto degenerado (ver seção 6.5 do anexo metodológico), ele nunca foi um recorte totalmente geográfico: o último dígito (`E`, renda) não é mapeável, só aproximado estatisticamente (seção 2 abaixo) — misturar um dígito não-espacial dentro de um "recorte geográfico" sempre foi conceitualmente estranho. Os recortes geográficos restantes (Zona, Estrato Administrativo, Estrato Agregado, Teresina × resto) cobrem a análise territorial com boa precisão e continuam mapeáveis por inteiro.
- **Recorte intermediário baseado só no dígito `S`** (Situação — rural / urbano tradicional / Favela e Comunidade Urbana, ou seja, `AAAGGS`, 6 dígitos): **decidido adotar (18/09/2026)** como recorte de comparação de indicadores, ao lado de Zona e Estrato Agregado. Ao contrário do `E`, o `S` é mapeável a partir do tipo de setor censitário (seção 2) e já tem mapa pronto (`output/figuras/mapa_setores_situacao.png`, gerado pelo `05_setores_censitarios_piaui.R`) — faltava só entrar como recorte nas tabelas de indicadores. Ele dá uma categoria a mais que a Zona simples (urbana/rural), separando FCU como grupo próprio, sem herdar o problema de confiabilidade do recorte de 7 dígitos. **Threading implementado no `01`/`03`/`09` em 18/09/2026** (item (b) de §8.8) — falta rodar o `01` de novo (item (c)) pra gerar os dados de fato; até lá as colunas de Situação saem em branco (–/—). **Desligado no relatório em 21/09/2026** (`INCLUIR_SITUACAO <- FALSE` no `09`): por ora não acrescenta informação em relação à Zona. Com `FALSE`, some das matrizes, dos pontos de atenção, dos anexos e dos trechos do modelo marcados com `{{#se-situacao}}`/`{{#se-nao-situacao}}`. O `01` continua estimando o recorte; para voltar, basta trocar para `TRUE`.
- **Este primeiro relatório (2T2026) não é a edição trimestral acompanhada que o projeto pretende produzir depois — é um relatório de seleção/justificativa dos indicadores** (decidido 18/09/2026, revisão pós-primeira-leitura). Por isso a comparação "Piauí neste trimestre × trimestre anterior × mesmo trimestre do ano anterior" (Tabela 1 e a seção "Variações no tempo" dos Pontos de Atenção) sai do corpo desta edição — não é o que o relatório está tentando responder agora. Isso **não afeta** a série de confiabilidade (2022T1+) que sustenta a triagem e as marcas †/– (Anexo B): são mecanismos diferentes — a série mede estabilidade do CV ao longo do tempo, não "o indicador subiu ou caiu". Ver §8.8.

## 2. A estrutura do código de Estrato (AAAGGSE)

Achado importante que resolveu várias dúvidas de arquitetura: o código de 7 dígitos do `Estrato` nos microdados da PNADC segue a estrutura **AAAGGSE**, confirmada pela Nota Técnica 03/2025 do IBGE ("Renovação da Amostra Mestra do SIPD — 2025") e validada empiricamente contra o crosswalk do projeto:

| Posição | Significado | Confirmado como |
|---|---|---|
| `AAA` (1-3) | Estratificação Administrativa (capital / RM / RIDE / demais municípios) | bate 100% com `Estrato_Admin` |
| `GG` (4-5) | Região Geográfica Imediata/Intermediária | `AAAGG` (5 dígitos) bate 100% com `Estrato_agregado` |
| `S` (6) | Situação e tipo de área (urbano tradicional x Favela/Comunidade Urbana — FCU) | **espacial** — dá pra mapear a partir do tipo de setor censitário |
| `E` (7) | Estrato Estatístico (faixa de renda média do responsável pelo domicílio) | **não espacial** — varia domicílio a domicílio dentro da mesma área; não delimita território |

Isso significa: **6 dos 7 dígitos do Estrato são mapeáveis geograficamente**; o último (renda) não é, e só dá pra aproximar estatisticamente (ver seção 5).

Curiosidade que gerou confusão no meio do caminho: o polígono de estratos publicado no GeoServer do IBGE (`v_ibge_estpnadc_trimestral_poligono`) só tem o código em **4 dígitos** (ex.: `2210`, `2251`), não os 7 dos microdados. Funciona como proxy de `AAAGG` só porque, no Piauí, o 2º dígito de `GG` é sempre "0" — não é regra geral.

## 3. Catálogo de indicadores

15 indicadores originais, com duas mudanças feitas durante o projeto:

- **Removido**: `Desocupados_Longa_Duracao` (tempo de desemprego) — não media o que o usuário queria.
- **Alterado**: `Proporcao_Ocupados_Escolarizados` passou de "11 anos ou mais de estudo" (VD3005) pra "ensino médio completo ou mais" (VD3004).
- **Corrigido (22/09/2026)**: o numerador de `Proporcao_Ocupados_Escolarizados` não era restrito a ocupados — o `na.rm` do `svyratio` só tirava quem está fora da força, então os desocupados com médio completo entravam no numerador sem estar no denominador (valor inflado; ex.: 2026T2 saiu 0,733 Brasil / 0,670 Piauí). Numerador agora é `ocup == 1 & medio_completo_ou_mais == 1`. Achado pelos testes unitários (`tests/testthat/test-indicadores.R`). **Outputs precisam ser regerados**: `01` (base de 2026T2 e relatório) e, se a triagem desse indicador importar, a série do `10` (usa o catálogo inteiro) + `11`.
- **Dividido**: `Rendimento_por_Formalidade` (que cruzava por `formal_setor_privado` via `svyby`, causando células desagregadas demais) virou dois indicadores independentes — `Rendimento_Formal` e `Rendimento_Informal` — cada um seu próprio `svymean`, baseados na variável `informal` (mais abrangente que `formal_setor_privado`).

Indicadores atuais: `Taxa_Desocupacao`, `Chefes_Familia_Desocupados`, `Rendimento_Medio_Habitual`, `Percentual_Subremuneracao`, `Rendimento_Formal`, `Rendimento_Informal`, `Taxa_Informalidade`, `Taxa_Subocupacao`, `Proporcao_Ocupados_Escolarizados`, `Desalentados_Forca_Ampliada`, `Desalentados_Fora_Forca`, `Motivo_Desistencia_Desalentado`, `Taxa_Nem_Nem`, `Motivo_Nao_Procura_NemNem`, `Motivo_Nao_Inicio_NemNem`.

**Ampliação (set/2026) — mercado de trabalho, composição da PIT e desigualdade** (definições no anexo metodológico, seção 4.5):
- Contagens: `Pessoas_Idade_Trabalhar`, `Pessoas_Forca_Trabalho`, `Pessoas_Fora_Forca`, `Pessoas_Ocupadas`, `Empregados_Setor_Privado`, `Empregados_Setor_Publico`, `Ocupados_Agropecuaria`, `Pessoas_Desocupadas`, `Pessoas_Subutilizadas`.
- Taxas: `Nivel_Ocupacao`, `Taxa_Participacao`, `Taxa_Composta_Subutilizacao` (e `Taxa_Desocupacao`, reescrita sobre as mesmas variáveis 0/1, com resultado idêntico).
- Composição da PIT (total + distribuição): `PIT_por_Sexo`, `PIT_por_Raca`, `PIT_por_Faixa_Etaria_SIDRA`/`_Projeto`, `PIT_por_Instrucao_SIDRA`/`_Projeto`, e os respectivos `Distribuicao_PIT_por_*`.
- `Gini_Rendimento_Habitual_Trabalho` (`convey::svygini`).
- **Validados contra o SIDRA** para o Piauí, de 2022T3 a 2026T2: 592/592 dentro do arredondamento oficial (`scripts_teste/validacao_sidra.R`). Brasil/Nordeste e 2016T2–2022T2 ficam para depois do cache nacional.

O catálogo completo (fórmula, denominador, subset, função) está em `R/indicadores.R`; as variáveis derivadas, em `R/derivar_variaveis.R`. Os dois são carregados pelo `01` e pela validação — a fórmula validada é a mesma publicada.

## 4. Inventário de scripts

**Atualizado em set/2026 — confira contra `ls R/` se parecer desatualizado de novo.**
Nada disto é pacote R nem `targets` (ver `CLAUDE.md` seção 1 pra arquitetura);
são scripts numerados em `R/`, rodados em ordem manual.

| Arquivo | O que faz |
|---|---|
| `00_config.R` | Parâmetros compartilhados (ano/trimestre de referência, caminhos, salário mínimo por hora — hard-coded, precisa atualizar todo ano). Alimenta o `01` e o `03` — rodar o `03` sem atualizar isso primeiro é a armadilha clássica (pega o trimestre antigo, sem erro). |
| `01_pipeline_trimestral.R` | **Principal.** Baixa o trimestre via `PNADcIBGE::get_pnadc()`, calcula os indicadores em todas as geografias x recortes, roda os testes de significância demográficos e regionais, gera gráficos de confiabilidade (CV) e a análise de distribuição de renda. Irmão do par `01_run.R`/`02_testes_significancia.R` (série histórica, hoje em `scripts_teste/` — ver abaixo): mesmas fórmulas de indicador, sem loop de trimestres nem cache em disco. |
| `derivar_variaveis.R` | Fonte única das variáveis derivadas (`derivar_variaveis(design, sm_hora)`), com checagem que para a execução se algum rótulo esperado do dicionário não existir na rodada. Termina com `convey_prep()`. |
| `indicadores.R` | Catálogo de indicadores + motor (`computar_estimativa`, `extrair_resultados`, `aplicar_subset*`). Spec com `testar = FALSE` fica fora dos testes de significância. |
| `03_comparacoes_indicadores.R` | Tabelas e gráficos comparando cada indicador entre categorias — geográfico com gráfico, demográfico só tabela. CV classificado com asteriscos de confiabilidade, tabelas + gráficos das duas baterias de teste (demográfica e regional). |
| `04_mapas_estratos_piaui.R` | Mapa dos subestratos lado a lado (zona, estrato administrativo, estrato agregado, código bruto do estrato) a partir do polígono oficial do IBGE (GeoServer WFS, resolução 4 dígitos) + o crosswalk `Estrato -> Zona/Estrato_Admin/Estrato_agregado` exportado pelo `01`. Pré-requisito: já ter rodado o `01` ao menos uma vez (grava `output/crosswalk_estratos.csv`). |
| `05_setores_censitarios_piaui.R` | Mapa na resolução do setor censitário (Censo 2022) — 4 painéis: Zona e Estrato Administrativo, Estrato Agregado (junção espacial contra o `04`), e Situação (rural/urbano tradicional/FCU — 6 dos 7 dígitos do Estrato). Grade 2x2 + os 4 mapas individuais. |
| `06_upas_piaui.R` | Constrói as UPAs do Piauí a partir dos setores censitários do Censo 2022 (setores contíguos, respeitando situação/tipo de área, mínimo de 60 domicílios rurais / 90 urbanos por UPA). Pré-requisito do `07` — o dígito `E` do Estrato é definido pelo IBGE em termos de UPA, não de setor. |
| `07_estrato_estatistico.R` | Estima o dígito `E` (estrato estatístico de renda) sobre as UPAs do `06` — estratificação ótima univariada resolvida de forma **exata** por programação dinâmica (a escala do Piauí permite isso, ao contrário do Brasil inteiro, que é por onde o IBGE usa heurística). **Substitui** os antigos `dalenius_hodges.py`/`aproximar_estrato_e.py` citados em versões anteriores deste documento — esses dois arquivos `.py` não existem mais no repositório. |
| `08_mapa_aaagsse.R` | Mapa dos estratos com os 7 dígitos completos do AAAGGSE, na resolução do setor censitário — o `E` (renda) finalmente espacializável porque `06`+`07` reconstroem a UPA que o define (no `05` ele ficava de fora, por não ser mapeável sem essa reconstrução). Pré-requisito: `06` e `07`. Gera `output/figuras/mapa_aaagsse_piaui.png` + um `.png` por painel. |
| `09_preencher_relatorio.R` | Preenche `output/relatorio_trimestral.md` (modelo versionado) com os números do trimestre → `output/relatorio_trimestral_<trimestre>.md`, e opcionalmente converte pra `.docx` via `pandoc_run()` do pacote `pandoc` (não Quarto — ver `CLAUDE.md`). Falha de propósito se sobrar marcador não resolvido no modelo: relatório meio preenchido publicado por engano é pior que nenhum. |
| `scripts_teste/validacao_sidra.R` | Confere os indicadores de mercado de trabalho contra o SIDRA (API `servicodados.ibge.gov.br/api/v3` — a `apisidra`, usada pelo `sidrar`, devolve 403 do Cloudflare). Guarda as respostas em `data/raw/sidra/`. Saídas: `output/tabelas/validacao_sidra.csv`, `validacao_checagens_internas.csv` e `validacao_gini.csv`. |
| `Teste_estrutura_aaagsse.R` | Script de validação (fora do pipeline de produção) que confirmou a estrutura AAAGGSE reanalisando o crosswalk já calculado. |
| `scripts_teste/01_run.R` + `02_testes_significancia.R` | Série histórica (2015-2026, ordem reversa, retomável, cache de designs em `.rds`). **Não ficam mais em `R/`** — foram movidos pra `scripts_teste/` junto de outros scripts exploratórios/legados. Não são o fluxo principal hoje, mas voltam a ser relevantes se a triagem de confiabilidade via série histórica (seção "Evolução do escopo") for implementada. |

## 5. Decisões metodológicas

- **Renda real**: `VD4019_real = VD4019 * Habitual`. O deflator trimestral da PNADC é um arquivo único pra toda a série histórica, sempre a preços do trimestre mais recente divulgado — não precisa (e não aceita) `defyear`/`defperiod` como nos microdados anuais.
- **Subremuneração**: comparação **nominal** contra o salário mínimo nominal do próprio período (não deflacionada) — é a comparação metodologicamente correta pra essa pergunta específica.
- **Testes de significância**: rigor amostral (decisão explícita, em vez de um teste simplificado a partir do CSV final) — `svyglm()`+`regTermTest()` pra respostas binárias/contínuas, `svychisq()` pra respostas categóricas com 3+ níveis (os indicadores de "Motivo"). Dois tipos: demográfico (dentro de cada geografia fina) e regional (entre categorias de um mesmo recorte regional).
- **Confiabilidade (CV)**: classificação em 4 níveis — Excelente (<5%, `***`), Boa (5-15%, `**`), Regular (15-30%, `*`), Baixa (≥30%). O corte de 15% é o oficial do IBGE pra "boa precisão"; os outros dois seguem a mesma lógica graduada.
- **Grau de instrução** (recorte demográfico `Instrucao`): agregado em só 2 categorias ("Até fundamental completo" / "Acima de fundamental completo") — o VD3004 original (7 níveis) deixava as células finas pequenas demais.
- **Indicadores de mercado de trabalho (set/2026)**: definições do IBGE, com universo PIT (14+) para as composições; faixa etária e instrução nas duas versões (SIDRA e projeto), para a triagem de confiabilidade decidir; setor privado sem trabalhador doméstico; setor público incluindo militar/estatutário; agropecuária = todos os ocupados do grupamento (não só empregados). Gini sobre ocupados com `VD4019 > 0`, em valor nominal.
- **R 4.5.2** é a versão usada no projeto (o R 4.1.2 também instalado na máquina não tem `survey` recente nem `convey`).
- **RIDE Grande Teresina**: lista de municípios conforme Decreto nº 10.129/2019 (12 municípios) — algumas fontes mais recentes também incluem Nazária e Pau D'Arco; conferir contra a definição real do V1023 se a precisão exata importar.

## 6. Limitações conhecidas / itens em aberto

- **Triagem de confiabilidade por indicador×recorte (nova direção, set/2026)** ainda não implementada — precisa: (i) reprocessar a série histórica com o pipeline atual de indicadores (hoje só o trimestre único roda por padrão); (ii) decidir a métrica de triagem (ex.: % de trimestres com CV bom/excelente, ou CV mediano, por par indicador×recorte); (iii) isolar ou tratar separadamente a quebra de desenho amostral Censo 2010 → Censo 2022 antes de comparar CVs entre trimestres de períodos diferentes — sem isso a triagem fica enviesada pelo desenho, não pelo indicador.
- **Cache nacional 2016T2+ implementado e completo (17/09/2026)**, validação da série em curso — ver §8.4. Os `data/raw/pi_*.rds` (2022T3–2026T2, só Piauí, 20/08/2026) **só poderão ser apagados depois que essa validação passar** (avisar o usuário; não apagar por conta própria).
- **Recorte de estrato fino (7 dígitos) removido do escopo do relatório (set/2026)**, mas os scripts (`pipeline_trimestre.R`, `03_comparacoes_indicadores.R`) ainda o calculam e exibem — falta atualizá-los pra parar de gerar esse recorte nas tabelas/gráficos do relatório principal (pode continuar existindo no anexo, se decidido manter lá).
- **Recorte "Situação" (dígito `S`, `AAAGGS`, 6 dígitos: rural/urbano tradicional/FCU) — adotado (18/09/2026) como recorte de comparação de indicadores, threading implementado (18/09/2026)**: `derivar_variaveis()` deriva `Situacao` a partir de `(Estrato %/% 10) %% 10` (mapeamento 1/2/3 confirmado no `08_mapa_aaagsse.R`, restrito a `UF == "Piauí"`); `montar_geografias()` gera `Situacao_<categoria>`; `01` inclui no crosswalk e nos testes regionais; `03` classifica em `Tipo_Geo`/`nomes_recortes`; `09` tem colunas extras (Piauí + Situação + teste) nas matrizes do corpo, ao lado de Zona e Estrato Agregado, mais entradas em Pontos de Atenção e Anexo D. **Falta rodar o `01` de novo** para a Situação aparecer com dado de verdade nas tabelas (testado com `data/raw/pi_2026_2.rds` — divisão Rural/Urbano tradicional/FCU bate 100% com Zona, sem erros no motor de estimação). Ver §8.8.
- **`aproximar_estrato_e.py`** ainda não rodou com dado real — falta o CSV da tabela V06 (renda por setor) do Censo 2022. A aproximação por Dalenius-Hodges não reproduz exatamente o método do IBGE (que combina "otimização linear e algoritmos estocásticos" com restrição de capacidade mínima de 150 UPAs — aqui uso setor como proxy de UPA).
- **Zona/Estrato Administrativo no `04`**: nessa resolução (4 dígitos), Zona e Estrato Administrativo podem misturar categorias dentro do mesmo grupo — o script agora detecta e avisa isso, mas a versão confiável desses dois mapas é a do `05` (resolução de setor censitário).
- **Coluna de tipo de setor/aglomerado subnormal** (usada pra separar FCU no `05`): a detecção automática tenta `TIPO`, `CD_TIPO`, `TIPO_SETOR`, `NM_TIPO_SETOR`, `SUBNORMAL`, `AGSN` — ainda não confirmado qual (se algum) existe no shapefile real.
- **Campo de p-valor do `regTermTest()`**: confirmado como `$p` (validado rodando com dado real — 330 de 330 linhas de `svyglm+regTermTest` vieram com p-valor preenchido).

## 7. Fontes de dados

- **Microdados PNADC**: pacote R `PNADcIBGE`, `get_pnadc(year, quarter, deflator=TRUE)`.
- **Polígono de estratos (resolução 4 dígitos)**: GeoServer do IBGE, `https://geoservicos.ibge.gov.br/geoserver/PNADC/wfs`, camada `v_ibge_estpnadc_trimestral_poligono`. O "baixar" do catálogo de metadados do IBGE (GeoNetwork) só exporta o XML de metadados — a geometria de verdade só sai via WFS.
- **Setores censitários (Censo 2022)**: malha por UF, `https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_de_setores_censitarios__divisoes_intramunicipais/censo_2022/setores/shp/UF/PI_setores_CD2022.zip`.
- **Renda por setor censitário (Censo 2022)**: tabela "Agregados por Setores Censitários", variáveis V06001-V06006 (SIDRA/downloads do Censo).
- **Metodologia da estratificação**: Nota Técnica 03/2025, "Renovação da Amostra Mestra do Sistema Integrado de Pesquisas Domiciliares — 2025" (biblioteca IBGE).

## 8. Trabalho em andamento — ampliação de indicadores e série 2016T2+ (set/2026)

Seção de passagem de bastão: o que já foi feito, o que falta e o que foi aprendido no caminho. Atualize ao fim de cada etapa.

### 8.1 Objetivo desta frente
Ampliar o catálogo com 18 indicadores pedidos (PIT, FT, fora da FT, ocupados, empregados no setor privado/público, ocupados na agropecuária, nível da ocupação, desocupados, taxa de desocupação, subutilizados, taxa composta de subutilização, PIT por sexo/raça/faixa etária/instrução, taxa de participação, Gini do rendimento habitual do trabalho) e processar a série **desde 2016T2**, com cache em `.rds`, para a triagem de confiabilidade (§1, "Evolução do escopo"). O primeiro relatório vai definir quais indicadores seguem nos relatórios futuros.

### 8.2 Decisões do usuário (não reabrir sem perguntar)
- Cache do **Brasil inteiro**, um `.rds` por trimestre, desde 2016T2.
- Composições por sexo/raça/idade/instrução sobre a **PIT (14+)**.
- Faixa etária e instrução **nas duas versões**: SIDRA (14–17, 18–24, 25–39, 40–59, 60+; VD3004 em 7 níveis) e projeto (14–29/30–64/65+; 2 grupos). A triagem decide qual fica.
- Setor privado/público/agropecuária pela **definição do IBGE** (ver §5).
- **Avisar o usuário** quando os `data/raw/pi_*.rds` antigos puderem ser apagados — **só depois** que a validação com o cache nacional passar. Nunca apagar por conta própria.
- Trabalhar em **etapas curtas**, com logs em arquivo e só o resumo na conversa.

### 8.3 Etapa 1 — fórmulas: CONCLUÍDA
- `R/derivar_variaveis.R` e `R/indicadores.R` criados; `01_pipeline_trimestral.R` passou a carregá-los (§2, §3 e §5 do `01` agora são `source()`), e os laços de teste pulam as specs com `testar = FALSE`.
- Validação (`scripts_teste/validacao_sidra.R`, Piauí, 2022T3–2026T2): **592/592** comparações com o SIDRA dentro do arredondamento; **96/96** checagens internas; Gini **16/16** igual à implementação independente.
- Regressão: os 15 indicadores antigos, recalculados com os módulos novos sobre `pi_2026_2.rds`, ficaram idênticos ao `output/base_2026T2.csv` (diferença ~1e-15), inclusive `Taxa_Desocupacao` reescrita.
- Correção lateral: `aplicar_subset_denominador()` tratava denominador numérico 0/1 como "todo não-NA" → o teste de `Desalentados_Forca_Ampliada` rodava sobre a amostra inteira. Corrigido; **o p-valor desse teste vai mudar** na próxima rodada do `01` (a estimativa não).
- O `01` completo **não** foi rodado depois da refatoração (ele baixa o Brasil) — rodar na Etapa 2.

### 8.4 Etapa 2 — cache nacional: CONCLUÍDA (16–17/09/2026)

**Andamento:**
- Passo 1 feito: `R/01a_cache_pnadc.R` (gravação atômica via `.tmp`; rodado como script faz a pré-carga do mais recente para o mais antigo). Primeiro arquivo: `pnadc_br_2026_2.rds`, 521.730 linhas, **430 MB** → série inteira ≈ 18 GB.
- Passo 2: **CONCLUÍDO (17/09)** — 41/41 trimestres (2016T2–2026T2) em `data/raw/pnadc_br_*.rds`, ~15 GB, sem falhas; ~5 min por trimestre, ~380–430 MB cada.
- Passo 4: **CONCLUÍDO (17/09, 09:10).** Série 2016T2–2026T2 validada **só para o Piauí** (decisão do usuário; Brasil/Nordeste validados em 2016T2, 2016T3, 2016T4 e 2026T2, todos ok): SIDRA 1483/1739 dentro da tolerância e **0 falhas** (256 sem valor oficial — a lacuna 2020T2–2022T1 abaixo), checagens internas 282/282, Gini 47/47. Saídas em `output/tabelas/validacao_*.csv`; parciais em `dados_saida/validacao/`. Rodar de novo: `Rscript scripts_teste/validacao_sidra.R` (retoma; ~11 s por trimestre só com o Piauí). Pré-carga de trimestre novo: `Rscript R/01a_cache_pnadc.R`.
- Passo 3: **CONCLUÍDO (16/09).** `01` usa `carregar_pnadc()` e rodou completo para 2026T2 a partir do cache. Regressão contra as saídas anteriores (guardadas em `dados_saida/regressao_01/antes_01/`, scripts `comparar_chave.R` e `conferir_resto.R` na mesma pasta):
  - `base_2026T2.csv`: as 16.033 linhas antigas iguais (inclusive `Taxa_Desocupacao`, cuja subcategoria passou a se chamar `desocup/ft`; dif ≤ 1e-16); +10.687 linhas dos indicadores novos.
  - Testes (`testes_significancia`, `testes_regionais`): fora de `Desalentados_Forca_Ampliada`, estatística, GL, p-valor e N idênticos. `Desalentados_Forca_Ampliada` mudou (N caiu, ex. 8.516 → 4.117) — é a correção do denominador (§8.3). `n_testes_familia`/`p_ajustado` mudaram porque as famílias de testes ganharam os indicadores novos.
  - Logs de falha: iguais, exceto o texto do erro do R, que agora sai em português (idioma da sessão), e as falhas do `Desalentados`.
- **Validação 2026T2 (nacional): 111/111 SIDRA, 18/18 checagens internas, Gini 3/3** — Brasil, Nordeste e Piauí.
- Passo 4: `validacao_sidra.R` reescrita para Brasil/Nordeste/Piauí sobre o cache nacional; resultado parcial por trimestre em `dados_saida/validacao/` (retomável); `Rscript scripts_teste/validacao_sidra.R 2026 2` valida um trimestre só; `... sidra` só pré-busca os oficiais. O Gini independente passou a usar a forma ordenada O(n log n) da diferença média absoluta (a O(n²) não cabe para o Brasil); conferida contra a soma dupla em exemplo pequeno.
- **Achado do SIDRA (série 2016T2–2026T2 já baixada em `data/raw/sidra/`):** Brasil completo. Para **Nordeste e Piauí, 2020T2–2022T1 (8 trimestres)**, as tabelas 4093, 4094, 4095 e 6402 vêm sem valor (`...`) — nesse intervalo PIT/FT/ocupados/taxas por sexo, idade, instrução e raça não têm referência oficial regional. As tabelas 4097, 4099, 4100 e 5434 têm valor nesse período. Na validação essas linhas aparecem como "sem valor oficial", não como falha. Causa não investigada.

**Pendências da Etapa 2:** usuário avisado (17/09) de que os `data/raw/pi_*.rds` (16 arquivos, 139 MB) já podem ser apagados — **aguardando decisão dele; não apagar por conta própria**. `CLAUDE.md` §1.1 atualizado (cache existe).

**Plano original:**
1. Criar `R/01a_cache_pnadc.R` com `carregar_pnadc(ano, tri)`: se `data/raw/pnadc_br_<ano>_<tri>.rds` existir, lê o arquivo; senão, `get_pnadc(year, quarter, deflator = TRUE)` com até 3 tentativas e grava o `.rds` **bruto** (sem derivadas — elas sempre vêm de `derivar_variaveis()`). Gravar junto um `.json` com a data do download (o deflator `Habitual` é referenciado ao último trimestre disponível na data do download).
2. Laço de pré-carga retomável, de 2016T2 ao último trimestre (~41 trimestres; estimativa de 200–400 MB cada, ~15 GB; havia 104 GB livres). Rodar em segundo plano com log em arquivo — são horas.
3. `01_pipeline_trimestral.R` §2: trocar o `get_pnadc()` direto por `carregar_pnadc()`, e rodar o `01` completo para 2026T2 como teste de regressão.
4. Generalizar `validacao_sidra.R` para ler o cache nacional e validar Brasil (`N1[all]`), Nordeste (`N2[2]`) e Piauí (`N3[22]`) de 2016T2 em diante. Atenção: os trimestres anteriores a 2022T3 podem ter rótulos diferentes no dicionário — o `checar_rotulos()` vai acusar; ajuste `ROTULOS` em vez de contornar.
5. Quando tudo passar: **avisar o usuário** sobre a limpeza dos `pi_*.rds` (§8.2) e atualizar `CLAUDE.md` §1.1, onde ainda diz "sem cache".

### 8.5 Etapa 3 — triagem de confiabilidade: PLANO (17/09/2026; janela decidida, métrica a decidir no passo 5)

**ONDE PARAMOS (17/09, 12:20) — ler isto primeiro ao retomar:**
- Passos 1–4 da Etapa 3 **concluídos**. Série: 41/41 em `dados_saida/serie/` (travou às 10:10 no 2024T2 e foi relançada às 10:30; saída do relançamento em `dados_saida/serie/relancamento_1030.out`, o `serie.log` não registrou essa segunda parte). Todos os trimestres com 17 estratos, nenhum sem classificação. Triagem gerada: `output/tabelas/triagem_confiabilidade.csv` (58.470 linhas = 9.745 chaves × 3 janelas × 2 amostragens).
- Primeiro resumo (janela principal, todos os trimestres): crit_c (p80 < 15%) aprova 3.008/9.745; crit_a 2.687 (todas contidas em c); crit_b 3.509 (contém c). Sensibilidade do crit_c: 373 chaves mudam com a amostragem espaçada e 365 com a série toda (~4%). 74 instáveis. **Teresina reprova em rendimento médio/formal, subocupação, desalento e chefes desocupados** (CV mediano de 13–16%), apesar de ter passado no 2T2026.
- Passo 5 **concluído**: critério, regra de célula e agrupamento dos motivos decididos e implementados (§8.7); triagem refeita. Estrutura do relatório implementada no `09` (§8.7). **Próximo:** rodar o `01` para 2026T2 (com OK do usuário) e gerar o relatório de novo; redigir os blocos A REDIGIR. Commit do usuário 3e514c6 inclui os scripts dos passos 1–4; CLAUDE.md e este arquivo têm ajustes não commitados.
- Uso de memória (medido em 2026T2): ler um `pnadc_br_*.rds` custa ~2,3 GB; estimar sobre o Brasil inteiro levava o pico a ~8,8 GB; recortando o território logo após a leitura o pico fica em ~2,3 GB (Piauí, < 1 min) ou ~2,9 GB (Nordeste, ~2 min). **Regra para o passo 3: `enxugar_pnadc()` + recorte territorial antes de `derivar_variaveis()`.** Brasil/Nordeste na série só se o usuário pedir. A máquina tem 16 GB.

Meta (§1): para cada indicador, **a resolução mais fina em que ele sustenta acompanhamento trimestral** (não aprovado/reprovado).

**Fatos já verificados (17/09):**
- Classificação de estratos estável: 17 estratos no Piauí até 2025T2 (conferido de 2022T3 em diante nos `pi_*.rds`), 25 em 2025T3 e 26 a partir de 2025T4. Os 17 antigos são subconjunto dos 26, **nenhum muda de Zona/Estrato Admin/Estrato Agregado**, e os 9 novos caem nas categorias já existentes — as 2 Zonas, os 3 Estratos Admin e os 5 Estratos Agregados existem nos dois desenhos. Logo, as séries por recorte geográfico são comparáveis em *categoria*; o que muda com a quebra é a *amostra* dentro delas. Falta confirmar 2016T2–2022T2 (o script da série deve parar se aparecer estrato sem classificação).
- CV oficial na API v3: 4093 (v4087 PIT, v4089 FT, v4091 ocupados, v4093 desocupados, v4095 fora da FT, v4100 participação, v4101 nível da ocupação; v4105–v4113 distribuições), 4099 (v4103 desocupação, v4119 taxa composta). Só Brasil/Grandes Regiões/UF — calibra o nosso CV nos níveis agregados, não nos finos.
- Lacuna SIDRA Nordeste/Piauí 2020T2–2022T1 (§8.4) — afeta só a validação, não o cálculo da série.

**Andamento (17/09):**
- Passo 1 **CONCLUÍDO** (`scripts_teste/calibracao_cv.R` → `output/tabelas/calibracao_cv.csv`; CVs oficiais em cache `data/raw/sidra/cv_t*.rds`). Série toda (Piauí 41 trimestres, 1261 comparações; Brasil 96 e Nordeste 111 dos parciais antigos): diferença CV projeto − CV oficial entre −0,048 e +0,068 p.p., mediana ~0, **nenhuma acima de 0,1 p.p.** — sem viés. (Com 4 trimestres: 318 comparações, −0,048 a +0,062.) 149 passam de 0,05 p.p. por pouco (arredondamento do IBGE provavelmente feito sobre estimativa/SE arredondados; não é truncamento — testado). Trocar `mse` do desenho não muda (teste no `pi_2026_2`: máx. 0,056). **Conclusão: CV do projeto referendado**, tolerância prática 0,1 p.p. (irrelevante para cortes de 15%/30%). 
- Passo 2 **CONCLUÍDO (17/09)**: `R/indicadores.R` ganhou `montar_geografias(design, design_pi, incluir_brasil_nordeste, incluir_micro)` e `estimar_trimestre(lista_geografias, geografias_agregadas, ano, tri)` → `list(base, desigualdade, falhas)`; `calcular_desigualdade()` mudou do `01` para lá. O `01` §4–6 agora só chama as duas funções (testes, gráficos e renda seguem no `01`). Regressão no 2026T2 **só com o Nordeste** (decisão do usuário, memória: `enxugar_pnadc()` + recorte do Nordeste antes de derivar; pico ~3,4 GB, 8,8 min) contra `output/*_2026T2.csv` de 16/09 sem a linha Brasil: base 26.623 linhas , desigualdade 39 e log de falhas 352 linhas **idênticos** (dif. máx. 0, textos e NAs iguais). Script em scratch (`regressao_motor.R`), não versionado. O `01` completo não foi rodado de novo (faz o Brasil inteiro, ~9 GB).
- Passo 3 (17/09): `R/10_serie_confiabilidade.R` criado — por trimestre (mais recente primeiro): `enxugar_pnadc()` + recorte do Piauí → `derivar_variaveis()` → para se algum estrato vier sem Zona/Admin/Agregado → `montar_geografias(incluir_brasil_nordeste = FALSE, incluir_micro = FALSE)` → `estimar_trimestre()`. Grava `dados_saida/serie/base_<ano>T<tri>.rds` = list(base, desigualdade, falhas, crosswalk); log em `dados_saida/serie/serie.log`. 2026T2: 3,5 min, 8.332 linhas, **idênticas** às do Piauí em `output/base_2026T2.csv` (dif. 0). Série completa disparada às ~09:50 (~2,3 h).
- Passo 4 (17/09): `R/11_triagem_confiabilidade.R` lê `dados_saida/serie/base_*.rds` e grava `output/tabelas/triagem_confiabilidade.csv`, uma linha por chave (indicador × subcategoria × geografia × recorte × categoria) × janela (`principal` 2022T1+, `serie_toda`, `sem_pandemia`) × amostragem (`todos`, `espacado_5` = de 5 em 5 a partir do mais recente, sem domicílio em comum). Colunas: n de trimestres e com estimativa, CV mediano/p80/máx, % por classe (Excelente <5, Boa <15, Regular <30, Baixa, sem estimativa — ausente conta no denominador), `crit_a/b/c` (as três métricas propostas, com corte < 15%), CV mediano antes/durante a transição (2022T1–2025T2 × 2025T3+) e razão, `instavel` (mediana < 15% e CV ≥ 30% em algum dos 4 últimos trimestres). **Não escolhe critério** (passo 5). Avisa se a série estiver incompleta. Conferido à mão numa chave (Taxa_Desocupacao, Agreg_Teresina, Sexo) com 4 trimestres: mediana, p80 e classes iguais.
- Memória: `enxugar_pnadc()` em `R/01a_cache_pnadc.R` mantém só as colunas usadas (438 → 39; `$variables` do Piauí 36 → 2,9 MB, resultados de catálogo e checagens internas idênticos). Ligado no `validacao_sidra.R`: trimestre de 2016 caiu de ~12 para ~8,5 min, mas o pico de RAM continuou ~8,8 GB — o pico vem da estimação sobre as ~520 mil linhas do Brasil, não das colunas.
- **Decisão do usuário (17/09): a validação da série é só do Piauí** (Brasil/Nordeste já passaram em 2016T2 e 2026T2; os parciais antigos com três territórios ficam). O script recorta o Piauí logo após carregar (`TERRITORIOS_SERIE`): pico ~2,3 GB (a leitura do `.rds`) e < 1 min por trimestre; resultado do Piauí em 2016T4 idêntico ao do recorte tardio. **Lição para o passo 3: recortar o território antes de derivar/estimar.** A calibração do CV da série toda fica, portanto, só no Piauí. O `01` ainda não usa `enxugar_pnadc()`.

**Passos propostos:**
1. **Calibração do CV (barato, sem microdado novo):** os parciais de `dados_saida/validacao/` já têm SE de Brasil/Nordeste/Piauí para todos os trimestres. Buscar os CVs oficiais acima e comparar com `100·SE/Estimativa`. Esperado: iguais no arredondamento (mesmo bootstrap de 200 réplicas). Se bater, o CV do projeto está referendado pelo IBGE; se não, parar e entender antes da triagem.
2. **Motor único:** extrair o laço de estimação do `01` (§4, geografias × recortes × catálogo) para uma função em `R/indicadores.R` (`estimar_trimestre(design_br)`), usada pelo `01` e pela série. Regressão: `01` do 2026T2 igual ao atual.
3. **Série `R/10_serie_confiabilidade.R`:** para cada `pnadc_br_*.rds`, `estimar_trimestre()` **sem o estrato fino (Micro)** (fora do escopo, §1) e **sem testes de significância**; grava `dados_saida/serie/base_<ano>T<tri>.rds`, retomável. Rodar depois da validação (memória). Tempo a medir no 2026T2 antes de disparar tudo.
4. **Tabela de triagem** `output/tabelas/triagem_confiabilidade.csv`: uma linha por indicador × geografia × recorte demográfico × categoria, com CV mediano, p80 do CV, % de trimestres em cada classe (Excelente/Boa/Regular/Baixa) e nº de trimestres com estimativa — **por janela** (ver decisões). A partir dela, "resolução mais fina utilizável" por indicador.
5. **Relatório de apoio curto** com as métricas lado a lado e exemplos da própria série, para o usuário escolher o critério.

**Decisões para o usuário (propostas):**
- **Métrica** — opções a comparar no passo 5: (a) ≥ 80% dos trimestres com CV ≤ 15%; (b) CV mediano ≤ 15%; (c) p80 do CV ≤ 15% (equivale a (a), mas dá o número em vez do %). Proposta: (c) como critério, (b) como informação. Categoria com CV ≤ 15% na mediana e > 30% em algum trimestre recente vira "instável", não "boa".
- **Janela / quebra de desenho** — **DECIDIDO pelo usuário (17/09): janela principal de 2022T1 a 2026T2 (18 trimestres; cresce a cada trimestre novo)**; a série toda (2016T2+) só como checagem de estabilidade. Marcar os trimestres de transição (2025T3–3T2026) e comparar o CV neles com os anteriores. Uma janela só com o desenho novo ainda não existe (a troca termina no 3T2026).
- **Pandemia** — 2020T2–2021T4 teve coleta por telefone e perda de amostra (CV inflado). Fica fora da janela principal (que começa em 2022T1); na série toda, informar com e sem esse período.
- **Painel rotativo** — trimestres vizinhos compartilham até 4/5 dos domicílios, então 41 CVs não são 41 observações independentes (grosso modo, ~8 amostras disjuntas). Consequência prática: não usar teste binomial/IC sobre "% de trimestres"; como sensibilidade, calcular a métrica só com trimestres espaçados de 5 em 5 (amostras sem sobreposição).
- **Recortes na triagem** — geografias: Brasil, Nordeste, Piauí, Teresina, Zona, Estrato Admin, Estrato Agregado; demográficos só nas finas, como no `01`. Recorte "Situação" (dígito S) fica para depois (§6).

### 8.7 Estrutura do relatório final: DECIDIDA e IMPLEMENTADA no `09` (17/09/2026)

Público: **gestor**. Meta: corpo enxuto (~10 páginas + crescimento da matriz), tudo o mais em anexo. Implementar no `09` depois da triagem (Etapa 3, passo 5).

**Decisões do usuário (não reabrir sem perguntar):**
- **Organizar por pergunta, não por indicador.** O território fica concentrado numa **matriz territorial** (linhas = indicadores, colunas = territórios), uma por dimensão, e não numa tabela e num gráfico por indicador.
- **Máximo de indicadores:** todo indicador aprovado na triagem entra em todo trimestre (sem tema rotativo); a matriz cresce.
- **Colunas do corpo:** Piauí, 5 estratos agregados, Zona urbana/rural. Estrato administrativo e "Teresina × resto" são redundantes no corpo (Capital = Agreg Teresina; Resto da RIDE = Entorno; Resto da UF = soma dos outros 3 agregados) → só nos testes e no anexo. O estrato de 7 dígitos sai.
- **Precisão na célula:** a triagem filtra; CV de 15% a 30% leva **"†"** (nada de itálico/formatação de fonte); célula reprovada ou de CV baixo fica "–". A matriz não mostra IC/CV; cada célula tem sua linha completa (IC 95%, CV, precisão) nas tabelas do anexo.
- **Significância:** o **teste global já existente** por recorte (`svyglm`+`regTermTest` LRT / `svychisq`, p ajustado), sem teste novo por célula. Asteriscos no **cabeçalho do grupo de colunas** ("Estratos agregados\*\*\*", "Zona\*"), legenda da Tabela 26: \*\*\* p < 0,001; \*\* p < 0,01; \* p < 0,05; ns. Na matriz o asterisco significa só significância; a escala de CV com asteriscos do `03` fica restrita às tabelas do anexo, onde o CV tem coluna própria.
- **Regra de redação:** o texto só comenta diferença significativa e com precisão aceitável; o restante fica só na matriz.

**Esboço do corpo (proposto, ajustável):** destaques (cartões Piauí × Nordeste × Brasil, com variação trimestral e anual) → panorama (tabela curta + gráficos pequenos da série 2016T2+ com IC, sombreando pandemia e transição de desenho) → território (matrizes por dimensão + mapas dos estratos agregados) → pontos de atenção (achados significativos, em tópicos) → considerações. Anexos: metodologia, tabelas completas, todos os testes, triagem.

**Decisões do passo 5 (17/09, usuário):**
- **Critério de triagem: (c)** — p80 do CV < 15% na janela principal (2022T1+, todos os trimestres); CV mediano (b) só como informação.
- **Regra de célula da matriz, pela série (não pelo CV do trimestre corrente):** valor normal se p80 do CV < 15%; **"†"** se 15% ≤ p80 < 30%; **"–"** se p80 ≥ 30% ou `instavel`.
- **Motivos: só nos níveis agregados (Brasil/Nordeste/Piauí), com categorias agrupadas — IMPLEMENTADO (17/09).** Desistência do desalentado (V4074A): "Não havia trabalho na localidade" × "Outros motivos". Não procura do nem-nem (VD4030): "Afazeres domésticos ou cuidado de parentes" × "Problema de saúde ou gravidez" × "Outros motivos". **`Motivo_Nao_Inicio_NemNem` (V4078A) saiu do catálogo** (repetia o VD4030). Derivadas `motivo_desistencia_grupo`/`motivo_nao_procura_grupo` em `R/derivar_variaveis.R` (rótulos em `ROTULOS`, iguais nos 41 trimestres); specs com o campo novo `geografias` (respeitado por `estimar_trimestre()`), `so_recorte_total = TRUE`, `testar = FALSE`. As linhas de motivo dos 41 `dados_saida/serie/base_*.rds` foram trocadas pelas agrupadas (script de scratch, não versionado; marca `$motivos_agrupados = TRUE`; demais linhas conferidas idênticas no 2026T2) e a triagem foi refeita (33.312 linhas). Janela principal, Piauí: todas as 5 categorias passam no crit_c (p80 de 6,7% a 13,6%). **Pendente:** `09` (tabelas de motivos com listas de categorias antigas e `Motivo_Nao_Inicio_NemNem`) e rótulo no `03` — reescrever junto com a estrutura nova do relatório.

**Implementação (17/09):** `R/09_preencher_relatorio.R` e o modelo `output/relatorio_trimestral.md` reescritos (versão anterior no git, commit 3e514c6). Corpo: 1 Destaques (Tabela 1: BR × NE × PI + variação do Piauí sobre o trimestre anterior e o mesmo trimestre do ano anterior, vindas de `dados_saida/serie/`) → 2 Como ler → 3–6 matrizes por dimensão (ocupação, qualidade, rendimento, vulnerabilidade) + motivos (BR/NE/PI) → 7 composição da PIT (BR/NE/PI) → 8 Pontos de atenção (temporais, territoriais e demográficos, gerados automaticamente) → 9 Considerações. Anexos: A nota metodológica, B triagem por nível, C testes regionais, D tabelas completas (IC, CV, precisão, p80 da série, marca). Ordem, rótulos, unidades e dimensões dos indicadores ficam no `CATALOGO` do `09`.
- **Desvio da decisão, forçado pela estrutura:** cada linha da matriz é um indicador com o seu próprio teste, então os asteriscos não cabem no cabeçalho do grupo — ficam nas colunas "Teste estratos" e "Teste zona", logo após cada grupo.
- **Pontos territoriais:** maior/menor entre os estratos consideram células com † (exibidas com a marca) e excluem só "–"; sem isso, o rendimento apontava Alto Parnaíba como maior, com Teresina (R$ 3.690 †) fora.
- **Pontos demográficos:** entram se p ajustado < 0,05 no território E todas as categorias do recorte, naquele território, estão sem marca na série. No 2T2026 foram 27 linhas.
- Variação temporal: independência + BH dentro da Tabela 1 (proposta abaixo, implementada; no 2T2026 nenhuma variação foi significativa).
- Figuras: o modelo novo não tem figuras (o `remover-figuras.lua` já as tira do `.docx`). Gráficos da série e mapas ficam para depois, se o usuário quiser. **Superado em 21/09/2026** — ver §8.9: figuras adicionadas ao corpo e o filtro descontinuado, então passam a aparecer no `.docx` também.
- **Pendente: rodar o `01` de novo para 2026T2.** O `output/base_2026T2.csv` e os testes são anteriores ao agrupamento dos motivos; o `09` acusa isso e a Tabela 6 sai vazia até lá. O `01` estima o Brasil inteiro (~9 GB) — rodar só com o OK do usuário.

**Em aberto:** comparação entre trimestres — proposta: tratar trimestres como independentes (conservador sob o painel rotativo, que induz covariância positiva), documentado na metodologia. Composição da PIT: amarela e indígena com CV 37–47% no 2T2026 → agrupar em "outras".

### 8.8 Revisão do relatório após 1ª leitura (18/09/2026)

O usuário leu a primeira versão do `output/relatorio_trimestral_2026T2.md` (gerada em 17/09,
§8.7) e trouxe três observações. Decisões tomadas na conversa; item (a) da ordem sugerida
**implementado em 18/09/2026**, itens (b)–(d) ainda em aberto.

**1. Propósito do relatório redefinido** (ver §1, "Evolução do escopo"): esta primeira edição
não é a edição trimestral acompanhada — é um relatório de seleção/justificativa dos
indicadores. Consequência: a comparação temporal do Piauí (trimestre anterior / mesmo
trimestre do ano anterior) sai do corpo. **Implementado no `09` (18/09/2026):**
- Tabela 1: colunas "Piauí: variação sobre 2026T1" e "Piauí: variação sobre 2025T2" removidas
  (`tabela_destaques()` só monta Brasil/Nordeste/Piauí).
- Pontos de Atenção: bloco "Variações no tempo (Piauí)" removido do modelo.
- Anexo A (nota metodológica): parágrafo "Variações no tempo" removido (não descrevia mais
  nenhum cálculo do relatório).
- Código morto removido do `09`: `ler_serie()`, `comparacoes_temporais()`/`COMP_TEMPORAIS`,
  `formatar_delta()`, `pontos_temporais()`, `sinal()`, `unidade_delta()`, vocabulário
  `trimestre_anterior`/`trimestre_ano_anterior`.
- **Não mexeu** na série de confiabilidade (2022T1+), no Anexo B nem nas marcas †/– — é outro
  mecanismo (estabilidade do CV ao longo do tempo, não "subiu ou desceu").

**2. Indicadores demográficos sem comparação por estrato no corpo — RESOLVIDO (18/09/2026).**
A Tabela 7 (perfil da PIT: sexo, raça, faixa etária, instrução) tinha só colunas
Brasil/Nordeste/Piauí; a quebra por território já existia (Tabelas D.28–D.46 do Anexo D), só
não estava na matriz do corpo como as Tabelas 2–6. Reformulada como matriz única (mesmos 4
indicadores `Distribuicao_PIT_por_*`, que já eram `multiplo` no catálogo) — bastou trocar
`<!-- @tabela tipo=categorias dimensao=populacao -->` por `tipo=matriz dimensao=populacao`
no modelo, reaproveitando `tabela_matriz()` sem tocar no motor. Colunas "Teste estratos" e
"Teste zona" saem como "—" para essas linhas porque `testes_regionais_2026T2.csv` não tem
testes de significância regional para os indicadores de composição — não é bug, só não foi
calculado (ficaria para uma iteração futura se fizer falta).

**3. Tabela 6 (motivos agregados) veio vazia** — causa já registrada em §8.7: o
`output/base_2026T2.csv` usado para montar o relatório é anterior ao agrupamento dos
motivos (`motivo_desistencia_grupo`/`motivo_nao_procura_grupo`). **Precisa rodar o
`01_pipeline_trimestral.R` de novo para 2026T2** (Brasil inteiro, ~9 GB, alguns minutos).
**Usuário pediu para não rodar agora** — só depois de fechar os ajustes estruturais acima
(18/09/2026). Rodar só com OK explícito na conversa, como sempre para o `01` completo.

**4. Recorte "Situação" (dígito `S`) adotado como recorte de comparação — threading
RESOLVIDO (18/09/2026)** (ver §1 e §6):
- `R/derivar_variaveis.R`: `Situacao` derivada de `(as.integer(Estrato) %/% 10) %% 10`
  (1/2/3 -> Urbano tradicional/Rural/FCU, mapeamento confirmado em `08_mapa_aaagsse.R`),
  `NA` fora do Piauí.
- `R/indicadores.R` (`montar_geografias()`): loop sobre `niveis("Situacao")` gera
  `Situacao_<categoria>`, mesmo padrão de `Agreg_`/`Admin_`.
- `01_pipeline_trimestral.R`: `Situacao` entra no crosswalk exportado, em
  `recortes_regionais` (testes regionais) e em `Nivel_Geografico` (gráfico de CV).
- `03_comparacoes_indicadores.R`: prefixo `Situacao_` reconhecido em `Tipo_Geo` e
  `limpar_nome_geografia()`; `nomes_recortes` ganhou a entrada.
- `09_preencher_relatorio.R`: `GEO_SITUACAO` (3 categorias) vira 3 colunas + 1 coluna de
  teste em `tabela_matriz()` (Tabelas 2–7, ao lado de Zona e Estrato Agregado); entra em
  `pontos_territoriais()` (maior/menor por situação), `pontos_demograficos()` (território
  candidato) e `tabela_anexo_triagem()`/`GEO_ANEXO` (Anexo B/D). Modelo (`.md`) atualizado:
  título da Tabela 1 nota, §2 "Como ler as tabelas" e Anexo A ("Territórios").
- `R/11_triagem_confiabilidade.R`: `Nivel_Geografico` reconhece `Situacao_` (código morto
  até a série 2022T1+ ser reprocessada com essa geografia — não é parte do escopo 01/03/09).
- **Validado** contra `data/raw/pi_2026_2.rds`: `Situacao` × `Zona` bate 100% (FCU e Urbano
  tradicional só em Urbana, Rural só em Rural); `montar_geografias()` produz os 3
  subconjuntos com N esperado; `svymean` de teste roda sem erro nos três. `09` e `03`
  rodados de ponta a ponta sem falhar — as colunas de Situação saem em branco (–/—) porque
  `output/base_2026T2.csv`/`testes_regionais_2026T2.csv` são de antes dessa mudança.
- **Falta**: rodar o `01` de novo (item (c) abaixo) pra essas colunas terem dado de
  verdade. A série histórica (R/10, usada na triagem de confiabilidade) também precisaria
  ser reprocessada para a Situação ganhar marcas †/– de verdade — não estava no escopo
  pedido (01/03/09) e fica para quando/se a série for reprocessada por outro motivo.

**Ordem sugerida:** ~~(a) ajustes só de apresentação no `09` que não dependem de recalcular
nada — remover colunas de variação, reformular Tabela 7 a partir do que já existe em Anexo
D~~ **feito (18/09/2026)**; ~~(b) threading do recorte Situação em `01`/`03`/`09`~~ **feito
(18/09/2026)**; (c) rodar o `01` completo para 2026T2 (com OK do usuário) e regerar o `.md`;
(d) revisar o `.md` de novo antes de cogitar `.docx` (que também precisa de OK explícito,
`CLAUDE.md`).

### 8.9 Gráficos de linha com IC no corpo do relatório (21/09/2026)

Pedido do usuário: prototipar gráficos de linha da série com banda de IC 95%
pra inserir no relatório. Cinco opções de layout foram esboçadas antes de
mexer no pipeline (gráfico único, grade de pequenos múltiplos, comparação
territorial sobreposta, comparação territorial em grade, sparklines nos
destaques) — o usuário aprovou a direção geral (grade de pequenos múltiplos
pro panorama + apoio territorial nas seções de dimensão). Depois, pediu mais
3 figuras específicas abrindo as seções 4/5/6 — e, numa segunda rodada,
corrigiu o recorte: **um único conjunto de 8 territórios** (não dois recortes
separados) e **removeu** a figura de apoio que tinha ficado em Pontos de
Atenção, redundante com a nova Figura 4.

**Implementado — `R/12_graficos_panorama.R`** (script novo, roda depois do
`R/10` e não depende do `09`/`11`; lê `dados_saida/serie/base_*.rds`, gera 4
figuras em `output/figuras/`, todas sombreando a pandemia, 2020T2–2021T4, e a
transição amostral Censo 2010→2022, 2025T3 em diante — datas fixas do §8.5):

| Figura | Arquivo | Indicador | Territórios | Seção |
|---|---|---|---|---|
| 1 | `panorama_piaui_<sufixo>.png` | 6 indicadores-farol (Desocupação, Ocupação, Participação, Informalidade, Subocupação, Rendimento) | Piauí | 2 (Panorama) |
| 2 | `territorial_participacao_<sufixo>.png` | Taxa de Participação (até 21/09: Nível da Ocupação, `territorial_ocupacao_`) | os 8 territórios do corpo | 4 (Ocupação) |
| 3 | `territorial_informalidade_<sufixo>.png` | Taxa de Informalidade | idem | 5 (Qualidade) |
| 4 | `territorial_rendimento_estratos_<sufixo>.png` | Rendimento Médio Habitual | idem | 6 (Rendimento) |
| 5 | `territorial_nem_nem_<sufixo>.png` | Taxa Nem-Nem (14 a 29 anos) | idem | 7 (Vulnerabilidade) |
| 6 | `territorial_populacao_14_59_<sufixo>.png` | `Proporcao_Populacao_14_59` (novo): pessoas de 14 a 59 anos / população total | idem | 8 (Perfil da PIT) |

**Atualização (22/09/2026, pedido do usuário):** Figura 2 trocada para a taxa
de participação; entraram as Figuras 5 e 6. O indicador da Figura 6 é novo no
catálogo (`catalogo_demografia` em `R/indicadores.R`); base = população de
todas as idades — interpretação adotada de "percentual de pessoas com mais de
14 e menos de 60 anos"; se a intenção for a parcela *dentro da PIT*, basta
trocar o denominador (é 100% menos a faixa "60 anos ou mais" da Tabela 7).
Série: Piauí via `R/10b_atualizar_serie_indicador.R`, Brasil/Nordeste via
`R/13` (agora incremental, com `Taxa_Nem_Nem` e o indicador novo). Ainda fora
do `CATALOGO` do `09`, então não aparece nas tabelas.

**Atualização (21/09/2026, pedido do usuário): Brasil e Nordeste voltaram** —
nas matrizes do `09` (colunas antes do Piauí, marca pelo CV do trimestre) e
nos gráficos: Figura 1 com Piauí + Nordeste + Brasil como linhas de
comparação; Figuras 2–4 com Brasil e Nordeste como os dois primeiros painéis
(grade 5x2). A série deles vem de `R/13_serie_brasil_nordeste.R` (mesmo
motor, só os 6 indicadores dos gráficos, recorte Total, sem desigualdade;
~2 min/trimestre, Brasil inteiro sem recorte prévio) →
`dados_saida/serie_br_ne/base_*.rds`. 2026T2 conferido contra
`output/base_2026T2.csv`: idêntico (dif. relativa < 1e-15). **Não entra na
triagem (R/11)**. O texto abaixo descreve a versão anterior, só com o Piauí.

Figuras 2–4 usam os mesmos **8 territórios** do corpo do relatório — Piauí,
Teresina, Entorno metropolitano, Centro-Leste, Baixo Parnaíba, Alto Parnaíba
e Chapadas, Zona Urbana, Zona Rural —, grade 4x2, cada painel com sua própria
banda de IC 95% (função `grafico_territorial()` no `12`, genérica: indicador
+ título + arquivo → PNG, geografia fixa nas 4 chamadas). A versão anterior,
com um recorte de 4 territórios por figura (3 figuras "estratos do interior"
+ 1 figura "Teresina/Zona" em Pontos de Atenção), foi descartada — o `12`
apaga o PNG antigo (`territorial_rendimento_<sufixo>.png`) se encontrar.

- `output/relatorio_trimestral.md` (modelo): nova seção **2 Panorama da
  série** (Figura 1, logo após Destaques) — empurrou "Como ler" e as seções
  seguintes uma casa adiante (3 a 10; Anexos A–D não mudam de letra). Figuras
  2, 3 e 4 abrem as seções 4, 5 e 6, antes da respectiva Tabela. Seção 9
  (Pontos de Atenção) não tem mais figura própria — o bullet automático de
  rendimento aponta pra Figura 4 (seção 6) em vez de repetir o gráfico com
  outro recorte territorial. Caminho de cada imagem usa `{{sufixo}}` (macro
  já existente no vocabulário do `09`), sem marcador novo — mas o script `09`
  FALHA sem avisar se a imagem não existe, então rodar o `12` antes do `09`
  sempre que o trimestre de referência mudar.
- `output/relatorio_trimestral_2026T2.md` regerado com as 4 figuras (rodado
  com `CONVERTER_DOCX` temporariamente `FALSE`, sem gerar `.docx` — regra do
  `CLAUDE.md`, nunca converter sem OK explícito na conversa).
- **`remover-figuras.lua` removido do `09` e do repositório (21/09/2026,
  reabrindo a decisão do §8.7)** — o usuário tentou converter pra `.docx` por
  conta própria e as figuras sumiram; causa era esse filtro Lua, que apagava
  todo parágrafo com imagem (+ legenda "Figura N" acima e "Fonte:" abaixo),
  incondicionalmente. Pedido explícito do usuário pra deixar as figuras
  passarem: tirei o argumento `--lua-filter=` do `pandoc_run()` e apaguei o
  arquivo (nada mais o referenciava). Nota: o `09` também mudou por fora
  desta conversa — saída agora é `..._rascunho.docx` (não mais
  `..._<sufixo>.docx`) contra `custom-reference-notatecnica.docx` (não mais
  `custom-reference.docx`); não mexi nisso, só documento o estado atual.
- **Segundo bug, mesmo sintoma (21/09/2026):** removido o filtro Lua, as
  figuras *ainda* sumiam — warning do pandoc: `Could not fetch resource
  figuras/panorama_piaui_<sufixo>.png: replacing image with description`.
  Causa: o `.md` fica em `output/` e referencia as imagens como
  `figuras/...` (relativo à própria pasta — é assim que qualquer visualizador
  de Markdown abre o arquivo, ex. GitHub, VS Code), mas o `pandoc_run()` é
  chamado a partir da raiz do projeto, e o pandoc resolve caminho relativo de
  imagem contra a sua própria pasta de trabalho, não contra a pasta do
  arquivo de entrada — foi procurar `<raiz>/figuras/...` em vez de
  `<raiz>/output/figuras/...`. Sem `--resource-path`, ele silenciosamente
  troca a imagem pela descrição textual em vez de falhar (por isso o
  `.docx` gerava normalmente, sem erro, só sem figura nenhuma). Corrigido
  com `--resource-path=<pasta do .md de saída>` no `pandoc_run()` — testado
  no 2T2026: sem warnings, `.docx` gerado com os 4 PNGs em `word/media/`
  (conferido abrindo o `.docx` como zip). Não mudou o caminho das imagens no
  `.md` (continua portátil pra quem abre fora do pandoc).
- **`CLAUDE.md` não exige mais permissão explícita pra gerar `.docx`** —
  regra removida a pedido do usuário nesta mesma conversa.

**Pendente:** só o `<!-- @redigir -->` da Figura 1 (seção 2), ainda não
escrito. O `.docx` com as 4 figuras já está confirmado gerando certo pro
2T2026 — o item (d) do §8.8 (revisão do `.md` antes do `.docx`) segue de pé
como próximo passo de conteúdo, não mais como bloqueio técnico.

### 8.6 Lições práticas do ambiente
- **`get_pnadc()` não apaga o que baixa**: zip + `.txt` extraído (~2 GB por trimestre) ficam em `savedir` (padrão `tempdir()`). A primeira pré-carga acumulou 72 GB num `Rtmp*` e, morta pelo fim da sessão, não limpou na saída (apagada com OK do usuário em 17/09). `carregar_pnadc()` agora usa uma subpasta por trimestre, apagada após gravar o `.rds`. Sessões antigas do RStudio também deixaram `Rtmp*` com `PNADC_*.txt` em `%TEMP%` (341 pastas, ~59 GB) — apagadas com OK do usuário em 17/09. Vale limpar `%TEMP%\Rtmp*` de vez em quando, com nenhum R aberto.
- **Usar o R 4.5.2** (`C:\Users\matheus.barbosa\AppData\Local\Programs\R\R-4.5.2\bin\Rscript.exe`). O R 4.1.2 em `C:\Program Files\R` tem `survey` 4.1 e não instala o `convey`.
- Chamar o `Rscript` pela **ferramenta PowerShell**: pelo Git Bash o `R_LIBS` não é o mesmo e os pacotes "não existem".
- **SIDRA:** o `apisidra.ibge.gov.br` (pacote `sidrar`) devolve 403 do Cloudflare. Usar `https://servicodados.ibge.gov.br/api/v3/agregados/<tabela>/periodos/<AAAATT>/variaveis/<v>?localidades=N3[22]&classificacao=<c>[all]`. As respostas ficam em `data/raw/sidra/` (apagar para forçar nova busca).
- Tabelas/códigos já confirmados: 4093 (v1641 PIT, v4088 FT, v4090 ocupados, v4092 desocupados, v4094 fora, v4096 participação, v4097 nível da ocupação, v4099 desocupação, v4104 distribuição %; sexo c2: 6794 total, 4 homens, 5 mulheres); 4094 (idade c58); 4095 (instrução c1568); 6402 (raça c86: 2776/2777/2779); 4097 (c11913: 31721 privado sem doméstico, 31727 público); 5434 (c888: 47947 agropecuária); 4099 (v4118 taxa composta); 4100 (c604: 40286 subutilizados).
- O `convey::svygini` usa `(2C_i − 1)`, e não `(2C_i − w_i)`: diferença de ~4e-4 em relação à fórmula de pares, já documentada no anexo §4.5. Não é bug.
- O `svyrep.design` dos `.rds` exige `convey_prep()` antes de qualquer subset — já está no fim de `derivar_variaveis()`.
- Os `data/raw/pi_*.rds` trazem derivadas antigas (ex.: `anos_estudos_11_ou_mais`), que são sobrescritas por `derivar_variaveis()`. Nunca usar derivadas do arquivo.
