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
- **Cogita-se adicionar um recorte intermediário baseado só no dígito `S`** (Situação — rural / urbano tradicional / Favela e Comunidade Urbana, ou seja, `AAAGGS`, 6 dígitos) como parte do que se perde ao remover o recorte fino. Ao contrário do `E`, o `S` é mapeável a partir do tipo de setor censitário (seção 2) — e já é usado no mapa do `05_setores_censitarios_piaui.R`, só não como recorte de comparação de indicadores. Ele dá uma categoria a mais que a Zona simples (urbana/rural), separando FCU como grupo próprio, sem herdar o problema de confiabilidade do recorte de 7 dígitos. **Ainda não decidido definitivamente nem implementado** — ver seção 6.

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
- **Cache nacional 2016T2+ ainda não implementado** (Etapa 2 do plano de set/2026): `carregar_pnadc()` gravando `data/raw/pnadc_br_<ano>_<tri>.rds` (Brasil inteiro, bruto) + data do download (o deflator `Habitual` depende dela). Os `data/raw/pi_*.rds` atuais (2022T3–2026T2, só Piauí, gravados em 20/08/2026) servem para a validação do Piauí; **só poderão ser apagados depois que a validação com o cache nacional passar**.
- **Recorte de estrato fino (7 dígitos) removido do escopo do relatório (set/2026)**, mas os scripts (`pipeline_trimestre.R`, `03_comparacoes_indicadores.R`) ainda o calculam e exibem — falta atualizá-los pra parar de gerar esse recorte nas tabelas/gráficos do relatório principal (pode continuar existindo no anexo, se decidido manter lá).
- **Recorte "Situação" (dígito `S`, `AAAGGS`, 6 dígitos: rural/urbano tradicional/FCU) como possível novo recorte de comparação de indicadores** — hoje o `S` só é usado no mapa (`05_setores_censitarios_piaui.R`), não como recorte no pipeline de indicadores. Decisão de adotar (ou não) ainda em aberto; se adotado, precisa entrar no `pipeline_trimestre.R` e no `03_comparacoes_indicadores.R` como um recorte geográfico novo.
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

### 8.4 Etapa 2 — cache nacional: EM ANDAMENTO (iniciada em 16/09/2026)

**Andamento:**
- Passo 1 feito: `R/01a_cache_pnadc.R` (gravação atômica via `.tmp`; rodado como script faz a pré-carga do mais recente para o mais antigo). Primeiro arquivo: `pnadc_br_2026_2.rds`, 521.730 linhas, **430 MB** → série inteira ≈ 18 GB.
- Passo 2: **CONCLUÍDO (17/09)** — 41/41 trimestres (2016T2–2026T2) em `data/raw/pnadc_br_*.rds`, ~15 GB, sem falhas; ~5 min por trimestre, ~380–430 MB cada.
- Passo 4 em curso (17/09, início 08:14): validação da série toda, ~11,5 min por trimestre (~8 h no total). 2016T2 já passou: 111/111 SIDRA, 18/18 internas, Gini 3/3 — os rótulos do dicionário valem desde 2016T2. Para ver os trimestres já concluídos sem esperar o fim: `Rscript dados_saida/validacao/espiar_parcial.R`. Se interrompida, rodar de novo (retoma). **Para retomar** (pula o que já existe; um `.tmp` que sobrar de interrupção pode ser apagado):
  `Rscript R/01a_cache_pnadc.R` (com o R 4.5.2, pela PowerShell, log em arquivo). Checar no fim a linha `PRÉ-CARGA FIM. Falhas: ...`.
- Passo 3: **CONCLUÍDO (16/09).** `01` usa `carregar_pnadc()` e rodou completo para 2026T2 a partir do cache. Regressão contra as saídas anteriores (guardadas em `dados_saida/regressao_01/antes_01/`, scripts `comparar_chave.R` e `conferir_resto.R` na mesma pasta):
  - `base_2026T2.csv`: as 16.033 linhas antigas iguais (inclusive `Taxa_Desocupacao`, cuja subcategoria passou a se chamar `desocup/ft`; dif ≤ 1e-16); +10.687 linhas dos indicadores novos.
  - Testes (`testes_significancia`, `testes_regionais`): fora de `Desalentados_Forca_Ampliada`, estatística, GL, p-valor e N idênticos. `Desalentados_Forca_Ampliada` mudou (N caiu, ex. 8.516 → 4.117) — é a correção do denominador (§8.3). `n_testes_familia`/`p_ajustado` mudaram porque as famílias de testes ganharam os indicadores novos.
  - Logs de falha: iguais, exceto o texto do erro do R, que agora sai em português (idioma da sessão), e as falhas do `Desalentados`.
- **Validação 2026T2 (nacional): 111/111 SIDRA, 18/18 checagens internas, Gini 3/3** — Brasil, Nordeste e Piauí.
- Passo 4: `validacao_sidra.R` reescrita para Brasil/Nordeste/Piauí sobre o cache nacional; resultado parcial por trimestre em `dados_saida/validacao/` (retomável); `Rscript scripts_teste/validacao_sidra.R 2026 2` valida um trimestre só; `... sidra` só pré-busca os oficiais. O Gini independente passou a usar a forma ordenada O(n log n) da diferença média absoluta (a O(n²) não cabe para o Brasil); conferida contra a soma dupla em exemplo pequeno.
- **Achado do SIDRA (série 2016T2–2026T2 já baixada em `data/raw/sidra/`):** Brasil completo. Para **Nordeste e Piauí, 2020T2–2022T1 (8 trimestres)**, as tabelas 4093, 4094, 4095 e 6402 vêm sem valor (`...`) — nesse intervalo PIT/FT/ocupados/taxas por sexo, idade, instrução e raça não têm referência oficial regional. As tabelas 4097, 4099, 4100 e 5434 têm valor nesse período. Na validação essas linhas aparecem como "sem valor oficial", não como falha. Causa não investigada.

**Próximos passos ao retomar:** (a) concluir a pré-carga; (b) rodar `Rscript scripts_teste/validacao_sidra.R` sem argumentos (série toda, retomável; ~horas; o 2026T2 já está em `dados_saida/validacao/`) e tratar falhas de rótulo em trimestres antigos via `ROTULOS`; (c) só então avisar sobre a limpeza dos `pi_*.rds` e atualizar `CLAUDE.md` §1.1.

**Plano original:**
1. Criar `R/01a_cache_pnadc.R` com `carregar_pnadc(ano, tri)`: se `data/raw/pnadc_br_<ano>_<tri>.rds` existir, lê o arquivo; senão, `get_pnadc(year, quarter, deflator = TRUE)` com até 3 tentativas e grava o `.rds` **bruto** (sem derivadas — elas sempre vêm de `derivar_variaveis()`). Gravar junto um `.json` com a data do download (o deflator `Habitual` é referenciado ao último trimestre disponível na data do download).
2. Laço de pré-carga retomável, de 2016T2 ao último trimestre (~41 trimestres; estimativa de 200–400 MB cada, ~15 GB; havia 104 GB livres). Rodar em segundo plano com log em arquivo — são horas.
3. `01_pipeline_trimestral.R` §2: trocar o `get_pnadc()` direto por `carregar_pnadc()`, e rodar o `01` completo para 2026T2 como teste de regressão.
4. Generalizar `validacao_sidra.R` para ler o cache nacional e validar Brasil (`N1[all]`), Nordeste (`N2[2]`) e Piauí (`N3[22]`) de 2016T2 em diante. Atenção: os trimestres anteriores a 2022T3 podem ter rótulos diferentes no dicionário — o `checar_rotulos()` vai acusar; ajuste `ROTULOS` em vez de contornar.
5. Quando tudo passar: **avisar o usuário** sobre a limpeza dos `pi_*.rds` (§8.2) e atualizar `CLAUDE.md` §1.1, onde ainda diz "sem cache".

### 8.5 Etapa 3 — depois (plano próprio)
Rodar a série histórica com o catálogo ampliado → triagem de confiabilidade indicador × recorte (§6), tratando a quebra de desenho Censo 2010 → 2022 e o painel rotativo. A API v3 também publica o **CV oficial** (ex.: v4103 para a taxa de desocupação), que pode ser usado para calibrar a triagem.

### 8.6 Lições práticas do ambiente
- **`get_pnadc()` não apaga o que baixa**: zip + `.txt` extraído (~2 GB por trimestre) ficam em `savedir` (padrão `tempdir()`). A primeira pré-carga acumulou 72 GB num `Rtmp*` e, morta pelo fim da sessão, não limpou na saída (apagada com OK do usuário em 17/09). `carregar_pnadc()` agora usa uma subpasta por trimestre, apagada após gravar o `.rds`. Sessões antigas do RStudio também deixaram `Rtmp*` com `PNADC_*.txt` em `%TEMP%` (341 pastas, ~59 GB) — apagadas com OK do usuário em 17/09. Vale limpar `%TEMP%\Rtmp*` de vez em quando, com nenhum R aberto.
- **Usar o R 4.5.2** (`C:\Users\matheus.barbosa\AppData\Local\Programs\R\R-4.5.2\bin\Rscript.exe`). O R 4.1.2 em `C:\Program Files\R` tem `survey` 4.1 e não instala o `convey`.
- Chamar o `Rscript` pela **ferramenta PowerShell**: pelo Git Bash o `R_LIBS` não é o mesmo e os pacotes "não existem".
- **SIDRA:** o `apisidra.ibge.gov.br` (pacote `sidrar`) devolve 403 do Cloudflare. Usar `https://servicodados.ibge.gov.br/api/v3/agregados/<tabela>/periodos/<AAAATT>/variaveis/<v>?localidades=N3[22]&classificacao=<c>[all]`. As respostas ficam em `data/raw/sidra/` (apagar para forçar nova busca).
- Tabelas/códigos já confirmados: 4093 (v1641 PIT, v4088 FT, v4090 ocupados, v4092 desocupados, v4094 fora, v4096 participação, v4097 nível da ocupação, v4099 desocupação, v4104 distribuição %; sexo c2: 6794 total, 4 homens, 5 mulheres); 4094 (idade c58); 4095 (instrução c1568); 6402 (raça c86: 2776/2777/2779); 4097 (c11913: 31721 privado sem doméstico, 31727 público); 5434 (c888: 47947 agropecuária); 4099 (v4118 taxa composta); 4100 (c604: 40286 subutilizados).
- O `convey::svygini` usa `(2C_i − 1)`, e não `(2C_i − w_i)`: diferença de ~4e-4 em relação à fórmula de pares, já documentada no anexo §4.5. Não é bug.
- O `svyrep.design` dos `.rds` exige `convey_prep()` antes de qualquer subset — já está no fim de `derivar_variaveis()`.
- Os `data/raw/pi_*.rds` trazem derivadas antigas (ex.: `anos_estudos_11_ou_mais`), que são sobrescritas por `derivar_variaveis()`. Nunca usar derivadas do arquivo.
