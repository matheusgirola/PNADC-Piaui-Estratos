# ==============================================================================
# 12_graficos_panorama.R — gráficos de linha da série 2016T2+ com banda de IC
# 95%, para a seção "Panorama da série" e para o abre-seção das seções 4-6 do
# relatório (R/09_preencher_relatorio.R + output/relatorio_trimestral.md).
#
# Decisão de layout (conversa de 18-21/09/2026, ver CONTEXTO_PROJETO.md §8.7 e
# §8.9): em vez de 1 figura por indicador (poderia passar de 20 combinações),
# quatro gráficos:
#   - painel_piaui: pequenos múltiplos (facet) com os 6 indicadores-farol,
#     Piauí com Brasil e Nordeste como referência (linhas de comparação,
#     pedido do usuário, 21/09/2026) — abre a seção Panorama sem inflar a
#     contagem de figuras.
#   - territorial_ocupacao / territorial_informalidade / territorial_rendimento_estratos:
#     1 indicador cada (Nível da Ocupação, Taxa de Informalidade, Rendimento
#     Médio Habitual — o indicador-farol de cada dimensão), TODOS os 8
#     territórios do corpo do relatório (Piauí, Teresina, Entorno
#     metropolitano, Centro-Leste, Baixo Parnaíba, Alto Parnaíba e Chapadas,
#     Zona Urbana, Zona Rural), mais Brasil e Nordeste na frente (21/09/2026,
#     mesma ordem das colunas das matrizes do 09) — grade 5x2, em pequenos múltiplos por
#     território — abrem as seções 4, 5 e 6, respectivamente (pedido do
#     usuário, 21/09/2026, revisado no mesmo dia pra unificar num só conjunto
#     de territórios em vez de dois recortes separados).
# Todos sombreiam a pandemia (2020T2-2021T4, coleta por telefone) e a
# transição amostral Censo 2010->2022 (2025T3 em diante, ainda em curso).
#
# Lê dados_saida/serie/base_<ano>T<tri>.rds (R/10_serie_confiabilidade.R, Piauí)
# e dados_saida/serie_br_ne/base_<ano>T<tri>.rds (R/13_serie_brasil_nordeste.R)
# — não recalcula nada. Roda depois do 10 e do 13; não depende do 11 nem do 09.
#   Rscript R/12_graficos_panorama.R
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(ggplot2)
})

source("R/00_config.R", encoding = "UTF-8")  # sufixo, ANO_REF, TRIMESTRE_REF
source("R/precisao.R", encoding = "UTF-8")   # ic_inferior(), ic_superior()

# ---- 1. Consolida a série -----------------------------------------------------

INDICADORES_PAINEL <- c("Taxa_Desocupacao", "Nivel_Ocupacao", "Taxa_Participacao",
                        "Taxa_Informalidade", "Taxa_Subocupacao", "Rendimento_Medio_Habitual")

# Os territórios do corpo do relatório (GEO_REFERENCIA + Piauí + GEO_AGREG +
# GEO_ZONA no 09_preencher_relatorio.R), nesta ordem — preenche a grade 5x2
# linha a linha: Brasil/Nordeste, Piauí/Teresina, Entorno/Centro-Leste, Baixo
# Parnaíba/Alto Parnaíba, Urbana/Rural.
GEOGRAFIAS_REFERENCIA <- c("Brasil", "Nordeste")
GEOGRAFIAS <- c(GEOGRAFIAS_REFERENCIA, "Piauí", "Teresina",
                "Agreg_Entorno metropolitano de Teresina (PI)", "Agreg_Centro-Leste do Piauí",
                "Agreg_Baixo Parnaíba do Piauí", "Agreg_Alto Parnaíba e Chapadas Sul do Piauí",
                "Zona_Urbana", "Zona_Rural")

arquivos <- list.files("dados_saida/serie", pattern = "^base_\\d{4}T\\d\\.rds$", full.names = TRUE)
if (length(arquivos) == 0) stop("Nenhum dados_saida/serie/base_*.rds encontrado — rode R/10_serie_confiabilidade.R antes.")
arquivos_br_ne <- list.files("dados_saida/serie_br_ne", pattern = "^base_\\d{4}T\\d\\.rds$", full.names = TRUE)
faltam_br_ne <- setdiff(basename(arquivos), basename(arquivos_br_ne))
if (length(faltam_br_ne) > 0) {
  stop("Brasil/Nordeste sem série para ", length(faltam_br_ne), " trimestre(s) (",
       paste(head(faltam_br_ne, 3), collapse = ", "), "...) — rode R/13_serie_brasil_nordeste.R antes.")
}

ler_um <- function(f) {
  x <- readRDS(f)
  x$base %>%
    filter(Indicador %in% INDICADORES_PAINEL,
           Regiao_Geografica %in% GEOGRAFIAS, Recorte_Demografico == "Total") %>%
    select(Indicador, Estimativa, SE, Ano, Trimestre, Regiao_Geografica)
}

# O 13 grava só a `base` (não a lista do 10).
ler_br_ne <- function(f) {
  readRDS(f) %>%
    filter(Indicador %in% INDICADORES_PAINEL, Recorte_Demografico == "Total") %>%
    select(Indicador, Estimativa, SE, Ano, Trimestre, Regiao_Geografica)
}

serie <- bind_rows(map_dfr(arquivos, ler_um), map_dfr(arquivos_br_ne, ler_br_ne)) %>%
  mutate(
    Ano_Trimestre = Ano + (Trimestre - 1) / 4,
    IC_inf = ic_inferior(Estimativa, SE),
    IC_sup = ic_superior(Estimativa, SE)
  ) %>%
  arrange(Indicador, Regiao_Geografica, Ano, Trimestre)

if (nrow(serie) == 0) stop("Série vazia depois do filtro — confira indicadores/geografias contra dados_saida/serie/.")

# ---- 2. Rótulos e escala de exibição (mesmos nomes do CATALOGO no 09) --------

nomes_indicadores <- c(
  Taxa_Desocupacao          = "Taxa de desocupação",
  Nivel_Ocupacao            = "Nível da ocupação",
  Taxa_Participacao         = "Taxa de participação na força de trabalho",
  Taxa_Informalidade        = "Taxa de informalidade",
  Taxa_Subocupacao          = "Subocupação por insuficiência de horas",
  Rendimento_Medio_Habitual = "Rendimento médio real habitual"
)
unidade_indicador <- c(
  Taxa_Desocupacao = "pct", Nivel_Ocupacao = "pct", Taxa_Participacao = "pct",
  Taxa_Informalidade = "pct", Taxa_Subocupacao = "pct", Rendimento_Medio_Habitual = "reais"
)
# Mesmos rótulos de território do GEO_AGREG/GEO_ZONA no 09_preencher_relatorio.R.
nomes_geografias <- c(
  Brasil = "Brasil", Nordeste = "Nordeste",
  Piauí = "Piauí", Teresina = "Teresina",
  "Agreg_Entorno metropolitano de Teresina (PI)" = "Entorno metropolitano",
  "Agreg_Centro-Leste do Piauí" = "Centro-Leste",
  "Agreg_Baixo Parnaíba do Piauí" = "Baixo Parnaíba",
  "Agreg_Alto Parnaíba e Chapadas Sul do Piauí" = "Alto Parnaíba e Chapadas",
  Zona_Urbana = "Zona urbana", Zona_Rural = "Zona rural"
)
# Rampa fria (mesma família de cores do projeto — R/03_comparacoes_indicadores.R,
# gerar_paleta_fria()), uma cor por território do Piauí, na ordem de
# GEOGRAFIAS; Brasil e Nordeste em laranja/marrom, fora da rampa, pra ler como
# referência externa.
geos_pi <- setdiff(GEOGRAFIAS, GEOGRAFIAS_REFERENCIA)
paleta_todos <- c(
  Brasil = "#A6611A", Nordeste = "#E08214",
  setNames(colorRampPalette(c("#08306B", "#2171B5", "#6BAED6", "#969696", "#252525"))(length(geos_pi)),
           unname(nomes_geografias[geos_pi]))
)

serie <- serie %>%
  mutate(
    Regiao_Nome = recode(Regiao_Geografica, !!!nomes_geografias),
    Indicador_Nome = recode(Indicador, !!!nomes_indicadores),
    unidade = unidade_indicador[Indicador],
    Estimativa_disp = ifelse(unidade == "pct", Estimativa * 100, Estimativa),
    IC_inf_disp = ifelse(unidade == "pct", IC_inf * 100, IC_inf),
    IC_sup_disp = ifelse(unidade == "pct", IC_sup * 100, IC_sup)
  )
serie$Indicador_Nome <- factor(serie$Indicador_Nome, levels = unname(nomes_indicadores))

# Pandemia (coleta por telefone) e transição amostral Censo 2010->2022 — datas
# fixas, decididas em CONTEXTO_PROJETO.md §8.5 (17/09/2026); não dependem do
# trimestre de referência.
pandemia   <- c(2020 + 1/4, 2022 + 0/4)
transicao  <- c(2025 + 2/4, max(serie$Ano_Trimestre) + 0.30)

sombra <- function(p) {
  p +
    annotate("rect", xmin = pandemia[1], xmax = pandemia[2], ymin = -Inf, ymax = Inf,
             fill = "#FDE0DD", alpha = 0.5) +
    annotate("rect", xmin = transicao[1], xmax = transicao[2], ymin = -Inf, ymax = Inf,
             fill = "#FEE6CE", alpha = 0.5)
}

eixo_x <- scale_x_continuous(breaks = seq(2016, 2026, by = 2),
                              labels = function(x) sprintf("%dT1", as.integer(x)))

fonte_caption <- paste0(
  "Fonte: IBGE — PNAD Contínua trimestral, microdados. Elaboração própria. ",
  "Faixa rosa = pandemia (coleta por telefone, 2020T2–2021T4); faixa laranja = ",
  "transição amostral do Censo 2010 para o Censo 2022 (2025T3 em diante, em curso)."
)

tema_serie <- theme_minimal(base_size = 9) +
  theme(plot.title = element_text(face = "bold", size = 11),
        plot.caption = element_text(hjust = 0, size = 6.3, color = "gray30", lineheight = 1.15),
        panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"))

# quebra a legenda da fonte em duas linhas pra caber na largura da figura
quebrar_caption <- function(txt, largura = 130) paste(strwrap(txt, largura), collapse = "\n")

formatar_eixo_y <- function(u) {
  if (u == "reais") function(x) paste0("R$ ", format(x, big.mark = ".", scientific = FALSE))
  else function(x) paste0(x, "%")
}

# ---- 3. Painel Piauí: 6 indicadores-farol em pequenos múltiplos --------------

geos_painel <- c("Piauí", "Nordeste", "Brasil")
d_painel <- serie %>% filter(Indicador %in% INDICADORES_PAINEL, Regiao_Geografica %in% geos_painel)
d_painel$Regiao_Nome <- factor(d_painel$Regiao_Nome, levels = geos_painel)

p_painel <- ggplot(d_painel, aes(x = Ano_Trimestre, y = Estimativa_disp,
                                 color = Regiao_Nome, fill = Regiao_Nome))
p_painel <- sombra(p_painel)
p_painel <- p_painel +
  geom_ribbon(aes(ymin = IC_inf_disp, ymax = IC_sup_disp), alpha = 0.18, color = NA) +
  geom_line(aes(linewidth = Regiao_Nome)) +
  scale_color_manual(values = paleta_todos[geos_painel], name = NULL) +
  scale_fill_manual(values = paleta_todos[geos_painel], name = NULL) +
  scale_linewidth_manual(values = c("Piauí" = 0.8, "Nordeste" = 0.55, "Brasil" = 0.55), name = NULL) +
  facet_wrap(~Indicador_Nome, scales = "free_y", ncol = 3) +
  eixo_x +
  labs(title = sprintf("Panorama da série — Piauí, Nordeste e Brasil (2016T2–%s)", sufixo),
       subtitle = "Indicadores aprovados na triagem de confiabilidade (CONTEXTO_PROJETO.md §8.5); banda = IC 95%",
       x = NULL, y = NULL, caption = quebrar_caption(fonte_caption)) +
  tema_serie +
  theme(axis.text.x = element_text(size = 6.3), axis.text.y = element_text(size = 7),
        legend.position = "top", legend.justification = "left")

arq_painel <- sprintf("output/figuras/panorama_piaui_%s.png", sufixo)
ggsave(arq_painel, p_painel, width = 9, height = 5.4, bg = "white", dpi = 150)

# ---- 4. Gráficos territoriais: 1 indicador, pequenos múltiplos por território ----

grafico_territorial <- function(indicador, titulo, arquivo, width = 7.5, height = 10.5) {
  d <- serie %>% filter(Indicador == indicador)
  d$Regiao_Nome <- factor(d$Regiao_Nome, levels = unname(nomes_geografias[GEOGRAFIAS]))
  u <- unidade_indicador[[indicador]]

  p <- ggplot(d, aes(x = Ano_Trimestre, y = Estimativa_disp, color = Regiao_Nome, fill = Regiao_Nome))
  p <- sombra(p)
  p <- p +
    geom_ribbon(aes(ymin = IC_inf_disp, ymax = IC_sup_disp), alpha = 0.18, color = NA) +
    geom_line(linewidth = 0.8) +
    scale_color_manual(values = paleta_todos, guide = "none") +
    scale_fill_manual(values = paleta_todos, guide = "none") +
    facet_wrap(~Regiao_Nome, ncol = 2) +  # grade 5x2 (Brasil, Nordeste + 8 territórios)
    eixo_x +
    scale_y_continuous(labels = formatar_eixo_y(u)) +
    labs(title = titulo,
         subtitle = "Brasil e Nordeste (referência) e os territórios do Piauí; cada painel com sua própria banda de IC 95%",
         x = NULL, y = NULL, caption = quebrar_caption(fonte_caption)) +
    tema_serie

  ggsave(arquivo, p, width = width, height = height, bg = "white", dpi = 150)
  arquivo
}

arq_ocupacao <- grafico_territorial(
  "Nivel_Ocupacao",
  titulo = sprintf("Nível da ocupação por território (2016T2–%s)", sufixo),
  arquivo = sprintf("output/figuras/territorial_ocupacao_%s.png", sufixo))

arq_informalidade <- grafico_territorial(
  "Taxa_Informalidade",
  titulo = sprintf("Taxa de informalidade por território (2016T2–%s)", sufixo),
  arquivo = sprintf("output/figuras/territorial_informalidade_%s.png", sufixo))

arq_rendimento_estratos <- grafico_territorial(
  "Rendimento_Medio_Habitual",
  titulo = sprintf("Rendimento médio real habitual por território (2016T2–%s)", sufixo),
  arquivo = sprintf("output/figuras/territorial_rendimento_estratos_%s.png", sufixo))

# A versão anterior (Teresina + Zona só) saiu — as 4 figuras acima já cobrem
# os 8 territórios do corpo, então esse recorte parcial ficou redundante.
arquivo_antigo <- sprintf("output/figuras/territorial_rendimento_%s.png", sufixo)
if (file.exists(arquivo_antigo)) { file.remove(arquivo_antigo); message("Removida (redundante): ", arquivo_antigo) }

message("Figuras salvas:\n  ", paste(c(arq_painel, arq_ocupacao, arq_informalidade,
                                       arq_rendimento_estratos), collapse = "\n  "))
