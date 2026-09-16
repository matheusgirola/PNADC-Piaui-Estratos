# ==============================================================================
# derivar_variaveis.R — variáveis derivadas sobre o desenho da PNADC.
#
# Fonte única das derivadas: o 01_pipeline_trimestral.R e a validação contra
# o SIDRA (scripts_teste/validacao_sidra.R) chamam a mesma função, então
# indicador validado e indicador publicado não podem divergir.
#
# Recebe o svyrep.design de get_pnadc() (ou o lido do cache) e devolve o
# mesmo desenho com as colunas novas. Derivadas que já existam no objeto
# (ex.: .rds antigos gravados pelo scripts_teste/01_run.R) são SOBRESCRITAS —
# nunca reaproveitadas, porque a definição pode ter mudado desde a gravação.
#
# Definições do mercado de trabalho: IBGE, PNAD Contínua — Notas
# metodológicas (Conceitos e métodos), e as tabelas trimestrais do SIDRA
# usadas como referência de validação (4093, 4094, 4095, 4097, 4099, 4100,
# 5434, 6402). Variáveis brutas conforme o dicionário da rodada: V2007 (sexo),
# V2009 (idade), V2010 (cor ou raça), VD3004 (nível de instrução), VD4001
# (condição na força de trabalho), VD4002 (condição de ocupação), VD4003
# (força de trabalho potencial), VD4004A (subocupação por insuficiência de
# horas habituais), VD4009 (posição na ocupação e categoria do emprego),
# VD4010 (grupamento de atividade), VD4019 (rendimento habitual de todos os
# trabalhos).
#
# CONVENÇÃO: os indicadores de mercado de trabalho são 0/1 numéricos, com NA
# virando 0 e o universo explícito. Comparação de fator com NA devolve NA, e
# o na.rm = TRUE das funções do survey descarta essas linhas sem avisar — o
# número sai, mas sobre o universo errado.
# ==============================================================================

library(dplyr)

UFS_NORDESTE <- c("Piauí", "Maranhão", "Ceará", "Rio Grande do Norte", "Paraíba",
                  "Pernambuco", "Bahia", "Alagoas", "Sergipe")

# Rótulos exatos de que as fórmulas dependem. O dicionário muda entre rodadas;
# se um rótulo sumir, a comparação vira FALSE pra todo mundo e o indicador sai
# zerado sem erro. Por isso checar_rotulos() para a execução.
ROTULOS <- list(
  VD4001 = c(ft = "Pessoas na força de trabalho",
             fora = "Pessoas fora da força de trabalho"),
  VD4002 = c(ocup = "Pessoas ocupadas",
             desocup = "Pessoas desocupadas"),
  VD4003 = c(ftp = "Pessoas fora da força de trabalho e na força de trabalho potencial"),
  VD4004A = c(subocup = "Pessoas subocupadas"),
  VD4009 = c(priv_com = "Empregado no setor privado com carteira de trabalho assinada",
             priv_sem = "Empregado no setor privado sem carteira de trabalho assinada",
             pub_com  = "Empregado no setor público com carteira de trabalho assinada",
             pub_sem  = "Empregado no setor público sem carteira de trabalho assinada",
             militar  = "Militar e servidor estatutário"),
  VD4010 = c(agro = "Agricultura, pecuária, produção florestal, pesca e aquicultura")
)

checar_rotulos <- function(variaveis) {
  faltando <- character(0)
  for (v in names(ROTULOS)) {
    if (!v %in% names(variaveis)) {
      faltando <- c(faltando, sprintf("%s (variável ausente)", v))
      next
    }
    presentes <- unique(as.character(variaveis[[v]]))
    ausentes  <- setdiff(ROTULOS[[v]], presentes)
    if (length(ausentes) > 0) faltando <- c(faltando, sprintf("%s = '%s'", v, ausentes))
  }
  if (length(faltando) > 0) {
    stop("Rótulos esperados não encontrados nos microdados (dicionário mudou?):\n  ",
         paste(faltando, collapse = "\n  "))
  }
  invisible(TRUE)
}

# 0/1 sem NA
flag <- function(x) as.numeric(!is.na(x) & x)

derivar_variaveis <- function(design, sm_hora) {
  checar_rotulos(design$variables)
  R <- ROTULOS

  design$variables <- design$variables %>%
    mutate(
      # ---- Geografia ----------------------------------------------------------
      Regiao = ifelse(UF %in% UFS_NORDESTE, "Nordeste", "Resto do Brasil"),

      Estrato_agregado = factor(case_match(as.integer(Estrato),
                                           2210011:2210030 ~ "Teresina",
                                           2220010:2220020 ~ "Entorno metropolitano de Teresina (PI)",
                                           2251011:2251022 ~ "Centro-Leste do Piauí",
                                           2252011:2252022 ~ "Baixo Parnaíba do Piauí",
                                           2253010:2254020 ~ "Alto Parnaíba e Chapadas Sul do Piauí",
                                           .default = NA_character_
      )),

      Zona          = factor(V1022, labels = c("Urbana", "Rural")),
      Estrato_Admin = V1023,

      # ---- Recortes demográficos ---------------------------------------------
      Sexo                   = factor(V2007, labels = c("Masculino", "Feminino")),
      Raca                   = V2010,
      Faixa_Etaria_trabalho  = case_match(V2009,
                                          14:29   ~ "Jovens",
                                          30:64   ~ "Adulto",
                                          65:130  ~ "Idoso",
                                          .default = NA_character_
      ),
      Instrucao = factor(case_when(
        VD3004 %in% c("Sem instrução e menos de 1 ano de estudo",
                      "Fundamental incompleto ou equivalente",
                      "Fundamental completo ou equivalente") ~ "Até fundamental completo",
        !is.na(VD3004) ~ "Acima de fundamental completo",
        TRUE ~ NA_character_
      )),

      # ---- Indicadores antigos (sem mudança de definição) ---------------------
      formal_setor_privado = factor(case_match(VD4009,
                                               "Empregado no setor privado com carteira de trabalho assinada" ~ "Com carteira",
                                               "Empregado no setor privado sem carteira de trabalho assinada" ~ "Sem carteira"
      )),

      medio_completo_ou_mais = factor(case_match(VD3004,
                                                 c("Médio completo ou equivalente", "Superior incompleto ou equivalente",
                                                   "Superior completo") ~ 1,
                                                 .default = 0
      )),

      ft_ou_desalentada = as.numeric(
        (!is.na(VD4001) & VD4001 == "Pessoas na força de trabalho") |
          (!is.na(VD4005) & VD4005 == "Pessoas desalentadas")
      ),

      valor_hora      = VD4019 / (5 * VD4031),
      subremuneracao  = as.numeric(valor_hora < sm_hora),
      VD4019_real     = VD4019 * Habitual,

      informal = as.numeric(
        (!is.na(VD4009) & VD4009 == "Empregado no setor privado sem carteira de trabalho assinada") |
          (!is.na(VD4009) & VD4009 == "Trabalhador doméstico sem carteira de trabalho assinada") |
          (!is.na(VD4009) & VD4009 == "Trabalhador familiar auxiliar") |
          ((!is.na(VD4009) & VD4009 == "Empregador") & (!is.na(V4019) & V4019 == "Não")) |
          ((!is.na(VD4009) & VD4009 == "Conta-própria") & (!is.na(V4019) & V4019 == "Não"))
      ),

      nem_nem = as.numeric(
        (V2009 >= 14 & V2009 <= 29) &
          (!is.na(V3002) & V3002 == "Não") &
          (is.na(VD4002) | VD4002 != "Pessoas ocupadas")
      ),

      Setor_AdminPublica = factor(case_when(
        is.na(VD4010) ~ NA_character_,
        VD4010 == "Administração pública, defesa e seguridade social" ~ "Administração pública",
        TRUE ~ "Exceto administração pública"
      )),

      contribuinte_renda_domicilio =  as.numeric(
        (!is.na(VD2002) & VD2002 == "Pessoa responsável") |
          (!is.na(VD2002) & VD2002 == "Cônjuge ou companheiro(a)")
      ),

      # ---- Mercado de trabalho (0/1, universo explícito) ----------------------
      # PIT: 14 anos ou mais na data de referência (V2009). Coincide com
      # !is.na(VD4001), que é definida só para esse universo.
      pit     = flag(V2009 >= 14),
      ft      = flag(VD4001 == R$VD4001[["ft"]]),
      fora_ft = flag(VD4001 == R$VD4001[["fora"]]),
      ocup    = flag(VD4002 == R$VD4002[["ocup"]]),
      desocup = flag(VD4002 == R$VD4002[["desocup"]]),

      # Setor privado exclusive trabalhador doméstico (SIDRA 4097, cat. 31721)
      emp_privado = flag(VD4009 %in% R$VD4009[c("priv_com", "priv_sem")]),
      # Setor público = com carteira + sem carteira + militar/estatutário
      # (SIDRA 4097, cat. 31727)
      emp_publico = flag(VD4009 %in% R$VD4009[c("pub_com", "pub_sem", "militar")]),
      # Ocupados no grupamento agropecuária do trabalho principal (SIDRA 5434,
      # cat. 47947) — inclui conta-própria, empregador e familiar auxiliar
      ocup_agro = flag(ocup == 1 & VD4010 == R$VD4010[["agro"]]),

      # Subutilização (SIDRA 4100): subocupado por insuficiência de horas +
      # desocupado + força de trabalho potencial. As três são disjuntas por
      # construção (subocupado é ocupado; FTP está fora da força).
      subocup_horas = flag(VD4004A == R$VD4004A[["subocup"]]),
      ftp           = flag(VD4003 == R$VD4003[["ftp"]]),
      subutil       = subocup_horas + desocup + ftp,
      ft_ampliada   = ft + ftp,

      # ---- Composição da PIT (universo PIT; NA fora dele) ---------------------
      Sexo_pit = factor(ifelse(pit == 1, as.character(Sexo), NA),
                        levels = c("Masculino", "Feminino")),
      Raca_pit = factor(ifelse(pit == 1 & V2010 != "Ignorado", as.character(V2010), NA),
                        levels = c("Branca", "Preta", "Amarela", "Parda", "Indígena")),
      # Grupos de idade do SIDRA (tabela 4094)
      Faixa_Etaria_sidra = factor(case_when(
        V2009 >= 14 & V2009 <= 17 ~ "14 a 17 anos",
        V2009 >= 18 & V2009 <= 24 ~ "18 a 24 anos",
        V2009 >= 25 & V2009 <= 39 ~ "25 a 39 anos",
        V2009 >= 40 & V2009 <= 59 ~ "40 a 59 anos",
        V2009 >= 60               ~ "60 anos ou mais"
      )),
      Faixa_Etaria_projeto = factor(Faixa_Etaria_trabalho,
                                    levels = c("Jovens", "Adulto", "Idoso")),
      Instrucao_sidra   = factor(ifelse(pit == 1, as.character(VD3004), NA),
                                 levels = levels(VD3004)),
      Instrucao_projeto = factor(ifelse(pit == 1, as.character(Instrucao), NA),
                                 levels = c("Até fundamental completo",
                                            "Acima de fundamental completo"))
    )

  # convey_prep() tem que vir ANTES de qualquer subset (geografia ou universo
  # do indicador): o convey guarda o desenho completo pra estimar medidas de
  # desigualdade/pobreza. Usado pelo svygini do catálogo.
  convey::convey_prep(design)
}
