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
#   - territorial_participacao / territorial_informalidade / territorial_rendimento_estratos
#     / territorial_nem_nem / territorial_populacao_14_59:
#     1 indicador cada (Taxa de Participação — no lugar do Nível da Ocupação
#     desde 22/09/2026 —, Taxa de Informalidade, Rendimento Médio Habitual,
#     Taxa Nem-Nem e % da população de 14 a 59 anos, as duas últimas também
#     de 22/09/2026, pedido do usuário), TODOS os 8
#     territórios do corpo do relatório (Piauí, Teresina, Entorno
#     metropolitano, Centro-Leste, Baixo Parnaíba, Alto Parnaíba e Chapadas,
#     Zona Urbana, Zona Rural), mais Brasil e Nordeste na frente (21/09/2026,
#     mesma ordem das colunas das matrizes do 09) — grade 5x2, em pequenos múltiplos por
#     território — abrem as seções 4, 5 e 6, respectivamente (pedido do
#     usuário, 21/09/2026, revisado no mesmo dia pra unificar num só conjunto
#     de territórios em vez de dois recortes separados). Abrem as seções 4,
#     5, 6, 7 e 8, respectivamente.
# Todos sombreiam a pandemia (2020T2-2021T4, coleta por telefone) e a
# transição amostral Censo 2010->2022 (2025T3 em diante, ainda em curso).
#
# Lê dados_saida/serie/base_<ano>T<tri>.rds (R/10_serie_confiabilidade.R, Piauí)
# e dados_saida/serie_br_ne/base_<ano>T<tri>.rds (R/13_serie_brasil_nordeste.R)
# — não recalcula nada. Roda depois do 10 e do 13; não depende do 11 nem do 09.
# Dados e rótulos no módulo R/graficos_serie.R; aqui só os ggplot.
#   Rscript R/12_graficos_panorama.R
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(ggplot2)
})

source("R/00_config.R", encoding = "UTF-8")  # sufixo, ANO_REF, TRIMESTRE_REF
source("R/precisao.R", encoding = "UTF-8")   # ic_inferior(), ic_superior()
source("R/graficos_serie.R", encoding = "UTF-8")  # territórios, rótulos, ler/preparar_serie()

# ---- 1. Consolida a série -----------------------------------------------------

# INDICADORES_* vêm do R/00_config.R; territórios, rótulos e a leitura, do
# R/graficos_serie.R.
checar_rotulos_graficos(INDICADORES_GRAFICOS)

arquivos <- listar_bases("dados_saida/serie")
if (length(arquivos) == 0) stop("Nenhum dados_saida/serie/base_*.rds encontrado — rode R/10_serie_confiabilidade.R antes.")
arquivos_br_ne <- listar_bases("dados_saida/serie_br_ne")
checar_br_ne(arquivos, arquivos_br_ne)

serie <- ler_serie(arquivos, arquivos_br_ne, INDICADORES_GRAFICOS)
if (nrow(serie) == 0) stop("Série vazia depois do filtro — confira indicadores/geografias contra dados_saida/serie/.")
serie <- preparar_serie(serie)
paleta_todos <- montar_paleta()

# ---- 2. Elementos comuns dos gráficos ----------------------------------------

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
  checar_territorios(serie, indicador)
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

arq_participacao <- grafico_territorial(
  "Taxa_Participacao",
  titulo = sprintf("Taxa de participação por território (2016T2–%s)", sufixo),
  arquivo = sprintf("output/figuras/territorial_participacao_%s.png", sufixo))

arq_informalidade <- grafico_territorial(
  "Taxa_Informalidade",
  titulo = sprintf("Taxa de informalidade por território (2016T2–%s)", sufixo),
  arquivo = sprintf("output/figuras/territorial_informalidade_%s.png", sufixo))

arq_rendimento_estratos <- grafico_territorial(
  "Rendimento_Medio_Habitual",
  titulo = sprintf("Rendimento médio real habitual por território (2016T2–%s)", sufixo),
  arquivo = sprintf("output/figuras/territorial_rendimento_estratos_%s.png", sufixo))

arq_nem_nem <- grafico_territorial(
  "Taxa_Nem_Nem",
  titulo = sprintf("Jovens nem-nem (14 a 29 anos) por território (2016T2–%s)", sufixo),
  arquivo = sprintf("output/figuras/territorial_nem_nem_%s.png", sufixo))

arq_populacao <- grafico_territorial(
  "Proporcao_Populacao_14_59",
  titulo = sprintf("Pessoas de 14 a 59 anos na população, por território (2016T2–%s)", sufixo),
  arquivo = sprintf("output/figuras/territorial_populacao_14_59_%s.png", sufixo))

# Versões que saíram do relatório: Teresina + Zona só (redundante com as
# figuras de 8 territórios) e o Nível da Ocupação por território (trocado pela
# Taxa de Participação em 22/09/2026).
for (arquivo_antigo in sprintf(c("output/figuras/territorial_rendimento_%s.png",
                                 "output/figuras/territorial_ocupacao_%s.png"), sufixo)) {
  if (file.exists(arquivo_antigo)) {
    file.remove(arquivo_antigo)
    message("Removida (saiu do relatório): ", arquivo_antigo)
  }
}

message("Figuras salvas:\n  ", paste(c(arq_painel, arq_participacao, arq_informalidade,
                                       arq_rendimento_estratos, arq_nem_nem, arq_populacao),
                                     collapse = "\n  "))
