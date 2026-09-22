# CLAUDE.md

Instruções para trabalhar neste repositório.

**Leia primeiro o [CONTEXTO_PROJETO.md](CONTEXTO_PROJETO.md)** — é a fonte de
verdade viva sobre o que o projeto faz, as decisões metodológicas já tomadas e
o que está em aberto. Este arquivo cobre arquitetura e regras de código; o
`CONTEXTO_PROJETO.md` cobre conteúdo estatístico e decisões do relatório.

> Duas partes deliberadamente separadas: **o que existe hoje** (seção 1) e
> **para onde o projeto pode migrar no futuro** (seção 2, roadmap, nada
> implementado ainda). Confie na seção 1 pra saber o que de fato está no
> repositório agora.

---

## 1. Estado atual do projeto

### 1.1 Arquitetura real

Não é um pacote R, não usa `targets`, não tem suíte de testes automatizada.
É uma sequência de **scripts numerados em `R/`**, rodados em ordem manual —
`00_config.R`, `01_pipeline_trimestral.R`, `03_comparacoes_indicadores.R`,
`04_mapas_estratos_piaui.R`, `05_setores_censitarios_piaui.R`,
`06_upas_piaui.R`, `07_estrato_estatistico.R`, `08_mapa_aaagsse.R`,
`09_preencher_relatorio.R`, `10_serie_confiabilidade.R` e `11_triagem_confiabilidade.R` (série e triagem de confiabilidade, `CONTEXTO_PROJETO.md` §8.5),
`12_graficos_panorama.R` (gráficos de linha do relatório) e
`13_serie_brasil_nordeste.R` (série de Brasil/Nordeste só dos 6 indicadores
dos gráficos, recorte Total — roda antes do `12`), mais `Teste_estrutura_aaagsse.R` (validação, fora
do fluxo de produção). Não há `02` — normal, não é lacuna a preencher. O que
cada um faz está em `CONTEXTO_PROJETO.md` §4 — **essa tabela está
desatualizada** em alguns nomes/arquivos (ver nota no fim deste documento);
confirme contra o `ls R/` real se precisar.

Dois arquivos não numerados são **módulos carregados via `source()`**, não
passos do fluxo: `R/derivar_variaveis.R` (variáveis derivadas) e
`R/indicadores.R` (catálogo + motor de estimação). O `01` e o
`scripts_teste/validacao_sidra.R` carregam os dois — mudar uma fórmula é
mexer só neles e rodar a validação de novo.

**Versão do R: 4.5.2** (`C:\Users\matheus.barbosa\AppData\Local\Programs\R\R-4.5.2`).
O R 4.1.2 em `C:\Program Files\R` não deve ser usado (não tem `survey`
recente nem `convey`).

**Geração do relatório**: `09_preencher_relatorio.R` monta
`output/relatorio_trimestral_<trimestre>.md` a partir de templates + outputs
do pipeline, e converte pra `.docx` chamando `pandoc_run()` do pacote
`pandoc` (usando `custom-reference-notatecnica.docx`, com `--columns=10000`
pra largura automática das colunas e o filtro `estilo-tabelas.lua`, que aplica
às células o estilo de parágrafo "Tabela Texto" do reference). As figuras do corpo
(painel da série, gráficos territoriais — `R/12_graficos_panorama.R`) passam
pra o `.docx` normalmente desde 21/09/2026 (antes, um filtro Lua as removia
na conversão — descontinuado a pedido do usuário). A saída de rascunho é
`output/relatorio_trimestral_<trimestre>_rascunho.docx`. **Não usa Quarto.**

**Cache em `.rds` por trimestre (Brasil inteiro, 2016T2+).** `R/01a_cache_pnadc.R`
(módulo) define `carregar_pnadc(ano, tri)`: lê `data/raw/pnadc_br_<ano>_<tri>.rds`
se existir, senão baixa com `get_pnadc(deflator = TRUE)` e grava o desenho
bruto (sem derivadas). Rodado como script, pré-carrega os trimestres que
faltam. O `01` usa `carregar_pnadc()`. ~400 MB por arquivo; ler um custa
~2,3 GB de RAM — use `enxugar_pnadc()` e recorte o território antes de
derivar/estimar (estimar sobre o Brasil inteiro chega a ~9 GB).

**Testes unitários (início, 22/09/2026):** `tests/testthat/` cobre só
`R/derivar_variaveis.R`, sobre microdado sintético (`helper-derivar.R` monta
um `svrepdesign` pequeno com `pessoa(...)`; não usa o cache). Rodar da raiz:
`testthat::test_dir("tests/testthat")`. Não é pacote — o helper faz
`source()` do módulo. `R/indicadores.R` e a validação SIDRA ainda não têm
teste. Fora isso, validações são manuais e pontuais,
registradas como decisão em `CONTEXTO_PROJETO.md` (ex.: campo de p-valor do
`regTermTest()` confirmado como `$p` rodando com dado real). Ampliar a
cobertura de `testthat` não depende da migração da seção 2.

**Dados fora do versionamento** — já real hoje via `.gitignore`: brutos
(`data/raw/`) e saídas pesadas regeneráveis (`dados_saida/`, `*.gpkg`,
`base_*.csv`, `renda_individual_*.csv`, `comparacao_demografica_*.csv`).

### 1.2 Regras que já valem hoje, independente de arquitetura

- **Domínio em português** (`Estrato_agregado`, `desenho_amostral`,
  `Taxa_Desocupacao`...) — convenção já usada nos scripts e no catálogo de
  indicadores.
- **Toda fórmula cita a fonte**: cada variável bruta da PNADC cita seu código
  e o dicionário da rodada; cada indicador cita a definição oficial (nota
  técnica do IBGE, ou referência acadêmica se não for oficial) — como já faz
  `output/anexo_metodologico.md`.
- **Estimativa sempre via desenho amostral.** Nenhuma estimativa pontual sai
  de `mean()`/`summarise()` cru sobre o microdado — sempre a partir do objeto
  `svrepdesign` de `PNADcIBGE::get_pnadc()`, via `survey::svymean()` /
  `svyby()` / `svyglm()`. É o erro mais fácil de cometer aqui e o mais
  silencioso — o número sai, só que errado.
- **Toda estimativa carrega sua precisão junto**: IC 95%, CV e classificação
  de precisão (excelente/boa/regular/baixa) na mesma linha, sempre.
- **Testes de significância usam `method = "LRT"`, não Wald** (`svyglm()` +
  `regTermTest()` pra respostas numéricas/binárias; `svychisq()` pra
  categóricas). Não é estilo: o anexo metodológico mostra por simulação que
  o Wald fica descalibrado nos recortes finos daqui (>50% de falso positivo).
  Não trocar de volta sem reabrir essa discussão.

### 1.3 Armadilhas conhecidas

- **Peso calibrado, não o preliminar.** O desenho de `get_pnadc()` já traz os
  200 pesos replicados de bootstrap (`V1028001`–`V1028200`) via
  `svrepdesign(type = "bootstrap")` — não reconstrua na mão. Nomes de
  peso/estrato/UPA podem mudar entre trimestres e entre base básica e bases
  com módulos suplementares; confira o dicionário da rodada, não assuma
  esquema fixo.
- **Painel rotativo** (esquema 1-2-5) — um trimestre não é amostra
  independente do anterior. Empilhar trimestres sem tratar isso conta o
  mesmo domicílio como observações independentes; importa em especial se a
  triagem de confiabilidade sobre a série histórica (`CONTEXTO_PROJETO.md`,
  "Evolução do escopo") for implementada.
- **Rendimento nominal não é comparável entre trimestres** sem o deflator que
  `get_pnadc(..., deflator = TRUE)` já aplica.
- **Quebra de desenho amostral em curso: Censo 2010 → Censo 2022** (renovação
  gradual até 3T2026) — trimestres desse período misturam duas safras.
  Contamina qualquer triagem de confiabilidade que compare CV entre
  trimestres de desenhos diferentes sem isolar a quebra.
- **Dicionário de variáveis muda entre rodadas.** Não assuma que um nome
  válido num trimestre continua válido no próximo sem checar.
- **Download grande, FTP do IBGE instável** — use sempre `carregar_pnadc()`
  (cache), nunca `get_pnadc()` direto. O deflator é referenciado à data do
  download (gravada no `.json` ao lado do `.rds`).

---

## 2. Arquitetura-alvo (roadmap — nada disto existe ainda)

**Sem gatilho de migração definido.** Não iniciar sem decisão explícita — o
trabalho recente do projeto tem ido na direção de **simplificar o escopo do
relatório** (menos recortes, triagem de indicadores confiáveis — ver
`CONTEXTO_PROJETO.md`), não de sofisticar a arquitetura. Tratar como
prioridades independentes; nada aqui é descrição do repositório atual (isso
é a seção 1).

Ideia, se um dia justificar o custo: migrar pra um **pacote R formal com
pipeline `targets`** — o pacote dá `testthat`/`roxygen2`/`R CMD check` de
graça, o `targets` dá cache automático e um DAG que só recalcula o que
mudou (resolvendo o problema de recache manual da seção 1.1). Forma
pretendida: `R/ingest/` (download + objeto de desenho, cacheado por
trimestre), `R/stats/` (núcleo agnóstico ao indicador — desenho, precisão,
descritiva), `R/indicadores/` (uma spec S7 por indicador + um `engine.R`
único que a interpreta — adicionar indicador = só escrever a spec, sem
tocar no motor), `R/viz/` (mapas e gráficos), `R/report/` (planilha +
relatório), com `tests/testthat/` cobrindo núcleo, indicadores, contratos
das specs, ponta-a-ponta (snapshot) e um `tests/acceptance/` contra valor
oficial do Sidra/IBGE.

Quando (e se) isso começar de fato, vale redetalhar as regras de tooling
(`rlang::check_*`, `checkmate::assert_*`, convenções de teste) a partir do
que estiver corrente na época, em vez de reviver o que está descrito aqui.
