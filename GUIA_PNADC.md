# Guia prático da PNAD Contínua: dificuldades e atalhos

Lições acumuladas no projeto **PNADC-Piauí desagregada** (ago–set/2026), escritas
para servirem de ponto de partida em **qualquer projeto novo com a PNADC
trimestral**. Nada aqui depende do Piauí, exceto onde isso está indicado.

Cada item segue o mesmo formato: **o problema**, **por que ele engana** e **o que
fazer**. As armadilhas mais caras são as que **não dão erro**: o número sai,
só que errado. Elas estão marcadas com ⚠️.

---

## 0. Resumo em 15 regras

1. Use o **R 4.5.2**, chamado pelo **PowerShell** (pelo Git Bash o `R_LIBS` muda e os pacotes "somem").
2. **Nunca chame `get_pnadc()` direto.** Use um cache em `.rds` por trimestre, com retentativas e gravação atômica (§2).
3. Baixe com `deflator = TRUE` e **registre a data do download**, porque o deflator é referenciado a ela.
4. Use `savedir` próprio por trimestre e apague essa pasta depois. O `get_pnadc()` deixa cerca de 2 GB de lixo por trimestre.
5. **Enxugue as colunas e recorte o território logo após ler**, antes de derivar e estimar. Sem isso o pico de RAM passa de 9 GB; com isso fica em 2–3 GB.
6. Rode `convey_prep()` **antes de qualquer subset**.
7. ⚠️ Rótulos do dicionário mudam: **valide os rótulos exatos** de que as fórmulas dependem e **pare a execução** se algum sumir.
8. ⚠️ Comparação de fator com `NA` devolve `NA`, e o `na.rm = TRUE` descarta a linha em silêncio. **Indicadores como 0/1 numérico, com universo explícito.**
9. ⚠️ Toda estimativa sai do **desenho replicado** (`svymean`/`svyratio`/`svytotal`/`svyby`). Nunca de `mean()`/`summarise()`.
10. Toda estimativa leva **SE, IC 95%, CV e classe de precisão** na mesma linha.
11. ⚠️ Testes com `svyglm` + `regTermTest(method = "LRT")`, **não Wald**. Recuse o teste quando o posto da matriz de covariância for deficiente (§7).
12. Confiabilidade é do **par indicador × recorte** e se avalia **na série** (p80 do CV), não num trimestre isolado.
13. Valide contra o **SIDRA pela API v3** (`servicodados.ibge.gov.br`). O `sidrar`/`apisidra` devolve 403.
14. Separe as **derivadas** e o **catálogo de indicadores** em módulos únicos, usados tanto pelo pipeline quanto pela validação.
15. Trabalhe em **etapas curtas**, com logs em arquivo e regressão contra a saída anterior a cada refatoração.

---

## 1. Ambiente (Windows desta máquina)

| Tema | Situação | O que fazer |
|---|---|---|
| Versão do R | Há dois instalados. O 4.1.2 (`C:\Program Files\R`) tem `survey` antigo e não instala o `convey` | Usar `C:\Users\matheus.barbosa\AppData\Local\Programs\R\R-4.5.2\bin\Rscript.exe` |
| Shell | Pelo Git Bash o `R_LIBS` é outro, e os pacotes "não existem" | Chamar o `Rscript` pela **ferramenta PowerShell** |
| RAM | 16 GB. Um trimestre do Brasil lido custa ~2,3 GB, e estimar sobre o Brasil inteiro chega a ~9 GB | Recorte o território antes de estimar (§3) |
| Disco temporário | O `get_pnadc()` deixa o zip e o `.txt` (~2 GB/trimestre) no `tempdir()`. Chegou a acumular **72 GB** num `Rtmp*`, e sessões antigas do RStudio deixaram outros **59 GB** em `%TEMP%` | Usar `savedir` próprio (§2). Limpar `%TEMP%\Rtmp*` de vez em quando, com nenhum R aberto |
| Idioma | As mensagens de erro do R saem em português (idioma da sessão) | Não comparar logs de erro por texto entre máquinas ou sessões |
| ⚠️ Testes com `testthat` sem pacote (sem DESCRIPTION) | Pelo `Rscript -e "testthat::test_dir(...)"` não existe `NOT_CRAN`, e aí `expect_snapshot()` e `skip_if_offline()` (que chama `skip_on_cran()`) viram **SKIP sem falhar**. No `pnadc_longitudinal` o snapshot ponta a ponta nunca tinha rodado (constatado em 25/09/2026) | No teste do snapshot: `local_edition(3)` + `withr::local_envvar(NOT_CRAN = "true")`. Para rede, checagem própria (`url()` + `readLines()` num `tryCatch`) em vez de `skip_if_offline()`. Ao rodar a suíte, confira que o resumo diz **SKIP 0** |
| Processos longos | Download da série: horas. Série de estimação: ~2 h | Rodar em segundo plano, com log em arquivo, **retomável** (pula o que já existe) |

---

## 2. Obter os microdados

### Dificuldades
- **O FTP do IBGE é instável.** Às vezes o `get_pnadc()` não lança erro: só emite `message()` e **devolve `NULL`**. Um `tryCatch` sozinho não pega esse caso.
- **Download interrompido** deixa um `.rds` truncado, que parece válido na execução seguinte.
- **Custo:** cerca de 5 min e 380–430 MB por trimestre (Brasil, `.rds`). A série 2016T2–2026T2 (41 trimestres) ocupa ~15 GB.
- ⚠️ **Deflator:** `Habitual`/`Efetivo` são um arquivo único para toda a série, **a preços do último trimestre divulgado na data do download**. Dois `.rds` baixados em datas diferentes **não estão na mesma base real**. O trimestral não aceita `defyear`/`defperiod` (isso é só do anual).

### Atalho: função de cache (copiar de `R/01a_cache_pnadc.R`)
```r
carregar_pnadc <- function(ano, tri, tentativas = 3) {
  arquivo <- sprintf("data/raw/pnadc_br_%d_%d.rds", ano, tri)
  if (file.exists(arquivo)) return(readRDS(arquivo))

  dir_download <- file.path(tempdir(), sprintf("pnadc_%d_%d", ano, tri))
  dir.create(dir_download, showWarnings = FALSE)
  on.exit(unlink(dir_download, recursive = TRUE), add = TRUE)   # evita os 72 GB de lixo

  for (i in seq_len(tentativas)) {
    d <- tryCatch(get_pnadc(year = ano, quarter = tri, deflator = TRUE,
                            savedir = dir_download),
                  error = function(e) NULL)
    if (inherits(d, "svyrep.design")) break      # o NULL silencioso também cai aqui
    d <- NULL
    if (i < tentativas) Sys.sleep(60 * i)
  }
  if (is.null(d)) stop("Falha ao baixar ", ano, "T", tri)

  tmp <- paste0(arquivo, ".tmp"); saveRDS(d, tmp); file.rename(tmp, arquivo)  # gravação atômica
  writeLines(sprintf('{"ano": %d, "trimestre": %d, "data_download": "%s"}',
                     ano, tri, format(Sys.time())), sub("\\.rds$", ".json", arquivo))
  d
}
```
- **Grave o desenho bruto**, sem derivadas. Derivadas guardadas em `.rds` antigos (ex.: `anos_estudos_11_ou_mais`) ficam desatualizadas quando a definição muda. **Sempre recalcule.**
- **Cache do Brasil inteiro** (não só da UF): serve para validar Brasil e Nordeste e para qualquer projeto futuro de outra UF.
- Pré-carga do **mais recente para o mais antigo**: o trimestre corrente fica disponível primeiro.
- Os dados brutos ficam fora do git (`.gitignore`: `data/raw/`, saídas pesadas).

---

## 3. Memória

| Situação | Pico de RAM | Tempo |
|---|---|---|
| Estimar sobre o Brasil inteiro (~520 mil linhas) | ~8,8 GB | ~12 min/trimestre |
| Enxugar colunas + recortar o Piauí antes de derivar | ~2,3 GB (é o custo da leitura) | < 1 min |
| Enxugar colunas + recortar o Nordeste | ~2,9–3,4 GB | ~2–9 min |

**Atalho:**
```r
d <- carregar_pnadc(2026, 2)
d <- enxugar_pnadc(d)                 # ~440 → ~40 colunas; os pesos replicados ficam em $repweights, intactos
d <- subset(d, UF == "Piauí")         # recorta ANTES de derivar e estimar
d <- derivar_variaveis(d, sm_hora)    # termina com convey::convey_prep()
```
- O `enxugar_pnadc()` mantém uma lista explícita de colunas. **Uma variável bruta nova tem que entrar nessa lista.** Se ficar de fora, o R para com "objeto não encontrado", o que é uma falha ruidosa e desejável.
- Só enxugar colunas não baixa o pico. O pico vem de **estimar sobre muitas linhas**, então o recorte territorial é o que resolve.
- Chame `gc()` entre trimestres nos laços.

---

## 4. Dicionário e variáveis

### ⚠️ Rótulos mudam entre rodadas, e a falha é silenciosa
Se um rótulo deixa de existir, a condição `VD4002 == "Pessoas ocupadas"` vira `FALSE` para todo mundo e o indicador sai **zerado, sem erro**.
**Atalho:** declare os rótulos exatos numa lista e pare a execução se algum sumir:
```r
ROTULOS <- list(
  VD4001 = c(ft = "Pessoas na força de trabalho", fora = "Pessoas fora da força de trabalho"),
  VD4002 = c(ocup = "Pessoas ocupadas", desocup = "Pessoas desocupadas"),
  ...)
checar_rotulos <- function(v) { ... stop("Rótulos esperados não encontrados (dicionário mudou?)") }
```
Quando o `checar_rotulos()` acusar, **ajuste `ROTULOS`**. Não contorne. Os rótulos usados no projeto foram iguais de 2016T2 a 2026T2.

### ⚠️ NA + `na.rm = TRUE` muda o universo
`fator == "x"` com `NA` devolve `NA`, e o `na.rm = TRUE` das funções do `survey` **descarta a linha sem avisar**. O universo do indicador vira outro.
**Atalho:** indicadores de mercado de trabalho como **0/1 numérico, sem NA**, com o universo definido de forma explícita:
```r
flag <- function(x) as.numeric(!is.na(x) & x)
ocup    = flag(VD4002 == "Pessoas ocupadas")
desocup = flag(VD4002 == "Pessoas desocupadas")
ft      = flag(VD4001 == "Pessoas na força de trabalho")
# Taxa de desocupação = svyratio(~desocup, ~ft)
```
Bug real que isso causou: um subset de denominador tratava uma variável 0/1 como "todo valor não-NA entra". O teste de desalento rodava sobre a amostra inteira (N de 8.516 em vez de 4.117). Regra: **numérico no subset conta como indicador: entra quem tem valor ≠ 0.**

### Variáveis-chave (confirmadas contra o SIDRA)
| Conceito | Variável / definição |
|---|---|
| PIT (idade de trabalhar) | `V2009 >= 14` (equivale a `!is.na(VD4001)`) |
| Força de trabalho / fora dela | `VD4001` |
| Ocupado / desocupado | `VD4002` |
| Força de trabalho potencial | `VD4003` |
| Subocupado por insuficiência de horas | `VD4004A` |
| Desalentado | `VD4005 == "Pessoas desalentadas"` |
| Posição na ocupação | `VD4009` (setor privado **sem** doméstico = com + sem carteira; público = com + sem carteira + militar/estatutário) |
| Grupamento de atividade | `VD4010` (agropecuária = **todos** os ocupados do grupamento, não só os empregados) |
| Rendimento habitual (todos os trabalhos) | `VD4019`; horas `VD4031`; real = `VD4019 * Habitual` |
| Subutilização | subocupado por horas + desocupado + FTP (disjuntos por construção) |
| Informal | sem carteira (privado/doméstico) + familiar auxiliar + empregador/conta-própria sem CNPJ (`V4019 == "Não"`) |
| Instrução | `VD3004` (7 níveis; em recorte fino, agrupar) |
| Sexo / idade / cor | `V2007` / `V2009` / `V2010` (excluir "Ignorado") |
| Frequenta escola | `V3002` |
| Condição no domicílio | `VD2002` |
| Motivos | `V4074A` (desistência do desalentado), `VD4030` (não procura). `V4078A` repete o `VD4030` |
| Zona / estrato administrativo | `V1022` / `V1023` |
| Capital, RM/RIDE | `Capital`, `RM_RIDE` |

### Estrutura do `Estrato` (7 dígitos = `AAAGGSE`, Nota Técnica IBGE 03/2025)
| Dígitos | Significado | Mapeável? |
|---|---|---|
| `AAA` | Estratificação administrativa (capital / RM / RIDE / demais municípios) | sim |
| `GG` | Região geográfica imediata/intermediária (`AAAGG` = estrato agregado) | sim |
| `S` | Situação: 1 urbano tradicional, 2 rural, 3 Favela/Comunidade Urbana (FCU) | sim, pelo tipo de setor censitário (confirmado **só no Piauí**) |
| `E` | Estrato estatístico de **renda** | **não**: varia domicílio a domicílio. Só com a reconstrução das UPAs |

- Extrair o `S`: `(as.integer(Estrato) %/% 10) %% 10`.
- O **polígono de estratos do GeoServer tem só 4 dígitos**. Funciona como proxy de `AAAGG` apenas onde o 2º dígito de `GG` é sempre 0 (como no Piauí). Não é regra geral.
- **O número de estratos muda com a renovação da amostra:** no Piauí eram 17 até 2025T2, 25 em 2025T3 e 26 a partir de 2025T4. Os 9 novos caíram nas categorias agregadas já existentes. Em qualquer série, **pare a execução se aparecer estrato sem classificação.**

---

## 5. Estimação

- O objeto do `get_pnadc()` já é um `svyrep.design` com **200 pesos bootstrap** (`V1028001`–`V1028200`). **Não reconstrua na mão.** Trocar o `mse` não muda o CV de forma relevante (≤ 0,06 p.p.).
- **Subset:** filtre com `design[idx, ]` (com `idx[is.na(idx)] <- FALSE`), nunca filtrando `$variables`. Assim a variância continua correta.
- **Taxas = `svyratio(~num, ~den)`**; médias = `svymean`; contagens = `svytotal` (em **pessoas**; o SIDRA publica em **mil pessoas**, então converta só na exibição).
- **Cruzamentos:** `svyby(~x, ~grupo, design, FUN)`.
- ⚠️ **Razão ou diferença entre duas estimativas da mesma amostra** (ex.: rendimento formal ÷ informal): **não combine os SEs como se fossem independentes.** As duas estimativas compartilham UPAs e estratos, e a covariância é positiva (no teste, o SE ingênuo saiu 34% maior). Estime as duas no mesmo `svyby(..., covmat = TRUE)` e aplique `svycontrast(m, quote(log(a) - log(b)))`, depois exponencie. O SE do log é o próprio CV da razão, e o IC fica assimétrico, como deve ser.
- **Gini:** `convey::svygini`. Exige `convey_prep()` **antes de qualquer subset**. O `convey` usa `(2C_i − 1)` em vez de `(2C_i − w_i)`, o que dá diferença de ~4e-4 em relação à fórmula de pares. Não é bug. No projeto: ocupados com `VD4019 > 0`, valor nominal.
- **Subremuneração:** compare o rendimento/hora **nominal** com o salário mínimo/hora **nominal do mesmo ano** (SM ÷ 220 h). A tabela de SM é *hard-coded* e **precisa ganhar uma linha a cada ano**. O script deve falhar se o ano não existir.
- **Rendimento entre trimestres:** só com o deflator e com arquivos baixados na mesma data (§2).

---

## 6. Precisão e confiabilidade

- **Classes de CV:** Excelente < 5%, Boa 5–15% (15% é o corte oficial do IBGE), Regular 15–30%, Baixa ≥ 30%.
- **O CV calculado pelo desenho replicado bate com o CV oficial do IBGE** (diferença entre −0,05 e +0,07 p.p. em 1.468 comparações, sem viés). Pode ser usado com confiança. O CV oficial está na API v3 (§8), mas só para Brasil, Grandes Regiões e UF.
- **O CV de um trimestre é ele mesmo ruidoso.** Para decidir se um indicador "sustenta acompanhamento trimestral", use a **série**: o critério adotado foi **p80 do CV < 15%** numa janela (ex.: 2022T1+). Na matriz do relatório: valor normal se p80 < 15%, **"†"** se 15% ≤ p80 < 30%, **"–"** se p80 ≥ 30% ou se a série for instável.
- **A confiabilidade é do par indicador × recorte**, não do indicador. O resultado útil é "a resolução mais fina em que o indicador funciona", não um aprovado/reprovado.
- **Painel rotativo (1-2-5):** trimestres vizinhos compartilham até 4/5 dos domicílios. 41 trimestres equivalem a ~8 amostras disjuntas. Não use binomial/IC sobre "% de trimestres bons". Como sensibilidade, use **trimestres espaçados de 5 em 5**.
- **Pandemia (2020T2–2021T4):** coleta por telefone e perda de amostra, com CV inflado. Deixe fora da janela principal ou mostre com e sem esse período.
- **Quebra de desenho Censo 2010 → 2022** (renovação gradual de 2025T3 a 2026T3). **Isto NÃO é motivo para evitar o período, e já custou uma decisão errada** (pnadc_longitudinal, decisão 3.2, revista em 24/09/2026). O IBGE incorpora o ajuste ao próprio microdado, e diz isso explicitamente na nota sobre a nova metodologia: *"os usuários de microdados não precisarão realizar nenhuma alteração em seus procedimentos de análise [...] os pesos amostrais e as variáveis do plano amostral que definem estratos e UPAs já foram cuidadosamente ajustados e incorporados diretamente na base de dados [...] durante o período de transição, a única diferença relevante estará na base utilizada para a calibração, que continuará com 77 pós-estratos. A mudança para 79 pós-estratos geográficos será adotada somente após a conclusão da transição."* Na prática:
  - **análise transversal:** nada muda. Não recorte a série nem descarte trimestres por causa disso;
  - **calibração:** os 77 pós-estratos e as margens `V1029`/`V1033` continuam valendo durante toda a transição. Os 79 só valem depois, e também já virão nos pesos;
  - **o que ainda vale fazer:** comparar o CV antes e durante (ele pode subir) e sombrear o período nos gráficos, junto com a pandemia;
  - ⚠️ **uso LONGITUDINAL é o único caso que a nota não cobre.** Ela trata de estimação transversal; não diz se os domicílios da amostra antiga completam as cinco visitas do rodízio 1-2(5) durante a renovação. Se o projeto segue o mesmo domicílio entre ocasiões, **meça a taxa de pareamento dos trimestres da janela** antes de concluir qualquer coisa — é uma conta de minutos e substitui a especulação. **Medido em 24/09/2026** (`pnadc_longitudinal/scripts_teste/conferir_transicao.R`, 1,6 min): parear 2024 (1ª visita) com 2025 (5ª visita) dá 70,3% / 71,7% / **72,6%** / **71,9%** em T1-T4, ou seja, **os dois trimestres da janela de renovação são os de MAIOR pareamento**, e o par inteiro pareia melhor (71,6%) que 2017-2018 (67,3%). Os 77 pós-estratos e a identidade `sum(V1029) == sum(V1028)` valem nos oito trimestres.
- **Células pequenas:** agrupe categorias. Instrução em 7 níveis ou "motivos" detalhados não sustentam CV < 15% em recorte fino. Amarela e indígena ficam com CV de 37–47% numa UF do Nordeste, então agrupe em "outras".

---

## 7. Testes de significância

- **Respostas binárias/numéricas:** `svyglm()` + `regTermTest(..., method = "LRT")`. O p-valor está em **`$p`**.
- **Respostas categóricas (3+ níveis):** `svychisq()` (Rao-Scott).
- ⚠️ **Não use Wald.** Por simulação, nos recortes com muitas categorias o Wald rejeitava H0 em mais de 50% dos casos sob H0 verdadeira. O LRT é calibrado.
- ⚠️ **Degeneração da variância replicada.** Em recorte fino, alguma réplica bootstrap fica sem observações numa célula, o que gera separação completa, coeficiente da ordem de 1e15 e **matriz de covariância de posto deficiente**. O teste rejeita em excesso (42% contra 32%). Sintoma enganoso: `regTermTest` para com **`Non-numeric argument to mathematical function`** (autovalores complexos em `pFsum`).
  - **Guarda:** recuse o teste (registre em log, não troque por outro) quando `posto(V) < dim(V)`, ou, no `svychisq`, quando **> 20% das células estiverem vazias**.
  - O risco depende da **menor célula** do recorte: ≤ 5 observações → 38% de posto deficiente; > 100 → 0,6%.
  - Não descarte réplicas divergentes para "consertar": isso altera o estimador.
- **Comparações múltiplas:** Benjamini-Hochberg dentro de cada família (não Bonferroni, porque o estudo é descritivo). Não duplique o mesmo teste na família.
- **Comparação entre trimestres:** tratar como independentes é conservador, porque o painel induz covariância positiva. Documente isso.

---

## 8. Validação contra o SIDRA

- ⚠️ **`sidrar` / `apisidra.ibge.gov.br` devolvem 403 (Cloudflare).** Use a API v3:
  ```
  https://servicodados.ibge.gov.br/api/v3/agregados/<tabela>/periodos/<AAAATT>/variaveis/<v>?localidades=N3[22]&classificacao=<c>[all]
  ```
  Localidades: Brasil `N1[all]`, Nordeste `N2[2]`, UF `N3[<código>]` (Piauí = 22). Guarde as respostas em disco (`data/raw/sidra/`) e apague para forçar nova busca.
- **Tabelas e códigos confirmados:**
  | Tabela | Conteúdo / códigos |
  |---|---|
  | 4093 | v1641 PIT, v4088 FT, v4090 ocupados, v4092 desocupados, v4094 fora, v4096 participação, v4097 nível da ocupação, v4099 desocupação, v4104 distribuição %; sexo c2 (6794 total, 4 homens, 5 mulheres). **CV:** v4087, v4089, v4091, v4093, v4095, v4100, v4101, v4105–v4113 |
  | 4094 | idade (c58) |
  | 4095 | instrução (c1568) |
  | 6402 | cor ou raça (c86: 2776/2777/2779) |
  | 4097 | c11913: 31721 privado sem doméstico, 31727 público |
  | 5434 | c888: 47947 agropecuária |
  | 4099 | v4118 taxa composta de subutilização; **CV:** v4103 desocupação, v4119 taxa composta |
  | 4100 | c604: 40286 subutilizados |
- **Lacuna oficial:** para **Nordeste e UFs, 2020T2–2022T1**, as tabelas 4093/4094/4095/6402 vêm com `...`. Trate como "sem valor oficial", não como falha.
- **Tolerância:** compare dentro do arredondamento oficial. No CV, ~0,1 p.p. (o IBGE arredonda sobre estimativa e SE já arredondados).
- Resultado de referência deste projeto: **592/592** (Piauí, 2022T3–2026T2) e **0 falhas** na série 2016T2–2026T2. Ou seja, as fórmulas de `R/derivar_variaveis.R` e `R/indicadores.R` **podem ser reaproveitadas como estão**.
- Faça também **checagens internas** (ex.: FT + fora = PIT; ocupados + desocupados = FT) e uma **implementação independente** do Gini (forma ordenada O(n log n); a O(n²) não cabe no Brasil).

---

## 9. Geografia e mapas

- **Polígono de estratos (4 dígitos):** WFS `https://geoservicos.ibge.gov.br/geoserver/PNADC/wfs`, camada `v_ibge_estpnadc_trimestral_poligono`. O "baixar" do catálogo GeoNetwork **só entrega o XML de metadados**, não a geometria.
- **Setores censitários 2022 por UF:** `https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_de_setores_censitarios__divisoes_intramunicipais/censo_2022/setores/shp/UF/<UF>_setores_CD2022.zip`.
- Em resolução de 4 dígitos, Zona e Estrato Administrativo podem misturar categorias. A versão confiável é a de setor censitário.
- Para espacializar o dígito `E`, é preciso **reconstruir as UPAs** (setores contíguos, mínimo de 60 domicílios rurais / 90 urbanos) e estratificar por renda (V06001–V06006 do Censo). O IBGE define `E` por UPA, não por setor.
- **Composição de RM/RIDE:** confirme contra o `V1023` real, porque decretos e fontes divergem (ex.: RIDE Grande Teresina, com ou sem Nazária e Pau D'Arco).

---

## 10. Do número ao relatório (.md → .docx)

- Modelo `.md` versionado com marcadores + script que preenche. **O script falha se sobrar marcador não resolvido**: relatório meio preenchido é pior que nenhum.
- Conversão com o pacote `pandoc` (`pandoc_run()`), sem Quarto:
  - `--reference-doc=<modelo>.docx` para os estilos;
  - `--columns=10000` para o Word ajustar a largura das colunas das tabelas;
  - filtro Lua para aplicar às células o estilo de parágrafo de tabela do modelo;
  - ⚠️ **`--resource-path=<pasta do .md>`**. Sem isso, imagens com caminho relativo não são encontradas (o pandoc resolve contra a pasta de trabalho, não a do arquivo) e **são trocadas em silêncio pela descrição**. O `.docx` sai sem figura e sem erro. Para conferir, abra o `.docx` como zip e veja `word/media/`.
  - Um filtro Lua antigo que removia figuras já causou o mesmo sintoma. Desconfie de filtros herdados.
- Gere as figuras **antes** de preencher o relatório sempre que o trimestre mudar.
- Parâmetros de referência (ano, trimestre, SM) ficam num `00_config.R` único. Rodar um script depois sem atualizar o config pega o trimestre antigo **sem erro**.
- **Estrutura que funcionou para gestor:** organizar por pergunta, com **matrizes territoriais** (linhas = indicadores, colunas = territórios), marcas †/– na célula, IC e CV completos só no anexo, e significância numa coluna de teste. O texto só comenta diferença significativa **e** precisa.

---

## 11. Como trabalhamos bem juntos

- **Um arquivo vivo de contexto** (`CONTEXTO_PROJETO.md`) com as decisões, o "onde paramos" e o que está em aberto, atualizado ao fim de cada etapa, e um `CLAUDE.md` curto com arquitetura e regras.
- **Etapas curtas**, com logs em arquivo, só o resumo na conversa, e parada em checkpoints naturais (ex.: antes de um download de horas).
- **Módulos únicos** para derivadas e catálogo, usados pelo pipeline e pela validação: indicador validado e indicador publicado não podem divergir.
- **Catálogo como lista de specs** (`id`, `formula`, `denominador`, `fun`, `subset`, `so_recorte_total`, `testar`, `geografias`) e um único motor que interpreta. Adicionar um indicador = escrever uma spec.
- **Regressão a cada refatoração:** guarde a saída anterior e compare linha a linha (diferença esperada ~1e-15).
- **Nunca apagar dados ou rodar o Brasil inteiro sem OK explícito.** Avisar quando algo puder ser apagado, e esperar.
- **Toda fórmula cita a fonte** (código da variável + dicionário da rodada; nota técnica do IBGE ou referência acadêmica).
- Confira o inventário de scripts contra o `ls` real: documentação de inventário envelhece rápido.

---

## 12. Checklist para um projeto novo com a PNADC

1. [ ] `CLAUDE.md` + `CONTEXTO_PROJETO.md` criados; R 4.5.2 via PowerShell.
2. [ ] `.gitignore` com `data/raw/` e saídas pesadas.
3. [ ] Copiar `R/01a_cache_pnadc.R` (e o **cache nacional já existente em `data/raw/pnadc_br_*.rds` deste projeto**, que pode ser reaproveitado ou apontado, sem novo download de 15 GB).
4. [ ] Copiar `R/derivar_variaveis.R` e `R/indicadores.R` (já validados) e ajustar `ROTULOS`, as geografias e `COLUNAS_PNADC_USADAS`.
5. [ ] `00_config.R` com ano/trimestre e tabela de SM atualizada.
6. [ ] Recortar o território **antes** de derivar; `convey_prep()` antes de qualquer subset.
7. [ ] Validar contra o SIDRA (API v3) antes de publicar qualquer número. Copiar `scripts_teste/validacao_sidra.R`.
8. [ ] Definir o critério de confiabilidade (p80 do CV na série) e os recortes.
9. [ ] Testes com LRT + guarda de posto + BH.
9b. [ ] Suíte de testes rodando com **SKIP 0** (ver §1, testthat sem DESCRIPTION).
10. [ ] Relatório `.md` → `.docx` com `--resource-path`, conferindo as imagens no `.docx`.

### Arquivos deste repositório que valem como modelo
| Arquivo | Para quê |
|---|---|
| `R/01a_cache_pnadc.R` | cache, retentativas, gravação atômica, `enxugar_pnadc()` |
| `R/derivar_variaveis.R` | `ROTULOS` + `checar_rotulos()`, `flag()`, todas as derivadas de mercado de trabalho |
| `R/indicadores.R` | catálogo em specs, motor, `svycontrast` para razão entre estimadores, `montar_geografias()`, `estimar_trimestre()` |
| `scripts_teste/validacao_sidra.R` | validação contra a API v3, retomável |
| `scripts_teste/calibracao_cv.R` | CV do projeto × CV oficial |
| `R/10_serie_confiabilidade.R` + `R/11_triagem_confiabilidade.R` | série retomável e triagem por p80 do CV |
| `R/12_graficos_panorama.R` | gráficos de linha com IC e sombreamento de pandemia/transição |
| `R/09_preencher_relatorio.R` | modelo `.md` + marcadores + pandoc |
| `output/anexo_metodologico.md` | fundamentação (plano complexo, CV, LRT × Wald, guarda de posto, BH) para citar ou adaptar |

---

## 13. Uso longitudinal (seguir a mesma pessoa entre visitas)

Lições do `pnadc_longitudinal` (set/2026), que reproduz os pesos longitudinais
do Ipea (*Mercado de Trabalho* nº 67, out./2019) e a matriz de fluxo
Ocupado/Desocupado/Inativo entre a 1ª e a 5ª visita. Detalhes e números em
`pnadc_longitudinal/CONTEXTO_PROJETO.md` §4.4, §4.7, §4.15 e
`docs/divergencias.md`.

- **Não precisa baixar o anual por visita.** Parear pelo **cache trimestral**
  selecionando `V1016` (1ª visita no ano de origem, 5ª quatro trimestres
  depois) dá **exatamente** o mesmo pareamento do anual por visita, pessoa a
  pessoa: 457.992 registros de origem e 308.123 pares nas duas rotas, mesma
  situação, mesmo critério e mesmos estados (2017-2018, Brasil). O Ipea
  autoriza essa via (p. 80).
- **Os nomes de peso da literatura são do anual.** `V1031`/`V1032` (e as
  margens `V1030`/`V1034`) **não existem no trimestral**; lá o peso calibrado é
  `V1028`, com as margens `V1029` (pós-estrato, 77 valores) e `V1033` (sexo ×
  idade, 34 valores). Idem `VD2004` e `VD5*`: só no anual.
- ⚠️ **A calibração por sexo × idade que a literatura acrescenta ao peso é hoje
  um no-op.** O `V1028` do trimestral já fecha `V1029` e `V1033` (desvio
  2e-11), e o **`V1032` do anual por visita de hoje já fecha `V1030` e
  `V1034`** (fator 1,000000 em todas as linhas, dp 1e-11). O fator médio de
  1,17 e o CV de 12,4% do Ipea nº 67 não são reproduzíveis com arquivo nenhum
  distribuído hoje — o IBGE passou a calibrar nas duas margens depois de 2019.
  Não é bug do seu código se a etapa não mexer em nada.
- ⚠️ **Tabela 3 do Ipea nº 67 (modelo de propensão): a coluna de razões de
  chances está deslocada uma linha para cima** no PDF. O 1,50 do topo é
  exp(0,405), o intercepto; o 0,62 que parece órfão é o de domicílio
  composto. **Leia pelos coeficientes**, que estão alinhados (os 22 foram
  reproduzidos a menos de 1 EP publicado). Na mesma nota, a coluna "máximo"
  da Tabela 1 tem UF e pós-estrato trocados entre as linhas (a ordem
  publicada é logicamente impossível).
- **~13% dos registros de 1ª visita não têm data de nascimento**
  (`V20082 == "9999"`) e nunca pareiam pelos critérios da fonte. É o teto do
  pareamento; não imputar. Taxa de pareamento: ~67% (2017-2018), ~72%
  (2024-2025).
- **Precisão numa UF do porte do Piauí (~6.300 pessoas no universo fechado,
  2024-2025), medida, não estimada:** a matriz 3x3 da UF fica com CV < 15%
  em quase todas as células (Desocupado → Desocupado, n = 46, chega a 15,6%).
  **Por sexo**, a linha Ocupado segura (permanência CV 1,5%, → Inativo < 10%)
  e só as transições pequenas passam de 15% (Ocupado → Desocupado 16-19%;
  linha Desocupado 10-23%, nenhuma acima de 30%). Faixa etária e
  escolaridade em 4 classes já deixam células com n < 10 e CV de 30-75%
  (60+ desocupado: n = 5). Em 3 faixas (14-29, 30-59, 60+), jovem e adulto
  ficam como o recorte por sexo (CV de 15-29% nas transições pequenas); o idoso
  só sustenta a linha Ocupado. A previsão de planejamento "~40-60 obs e CV > 30%"
  valia para os recortes finos, não para sexo — meça antes de descartar.
