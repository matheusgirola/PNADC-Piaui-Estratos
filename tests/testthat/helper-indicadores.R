# ==============================================================================
# helper-indicadores.R — desenho derivado pequeno para testar R/indicadores.R.
# Usa pessoa()/montar_desenho() do helper-derivar.R (carregado antes, ordem
# alfabética).
# ==============================================================================

source(test_path("..", "..", "R", "indicadores.R"), encoding = "UTF-8")

# Desenho derivado só com as pessoas dadas (as linhas de cobertura de rótulos
# saem depois de derivar, pra não entrarem nas estimativas).
desenho_teste <- function(pessoas) {
  d <- derivar_variaveis(montar_desenho(pessoas), sm_hora = SM_HORA_TESTE)
  d[d$variables$.teste, ]
}

# População de ~60 pessoas: Teresina (urbana) e Centro-Leste (rural), os dois
# sexos, e um bloco fora do Nordeste. Em cada bloco há ocupado formal,
# informal, conta-própria sem CNPJ, subocupado, desocupado, desalentado (na
# FTP), idoso fora da força, jovem nem-nem e criança fora da PIT. Pesos
# diferentes por pessoa, pra que um cálculo sem peso dê outro número.
populacao_teste <- function() {
  R <- ROTULOS
  fora <- list(VD4001 = R$VD4001[["fora"]], VD4002 = NA, VD4009 = NA,
               VD4019 = NA, VD4031 = NA)
  blocos <- list(
    list(UF = "Piauí", Estrato = "2210011", V1022 = "Urbana", V1023 = "Capital"),
    list(UF = "Piauí", Estrato = "2251021", V1022 = "Rural",  V1023 = "Resto da UF"),
    list(UF = "São Paulo", Estrato = "3510011", V1022 = "Urbana", V1023 = "Capital")
  )
  linhas <- list()
  i <- 0
  for (b in blocos) for (sexo in c("Homem", "Mulher")) {
    add <- function(...) {
      i <<- i + 1
      args <- utils::modifyList(c(b, list(V2007 = sexo, V1028 = 80 + 7 * i)), list(...))
      linhas[[length(linhas) + 1]] <<- do.call(pessoa, args)
    }
    add(VD4019 = 3000, V2010 = "Branca")
    add(VD4009 = R$VD4009[["priv_sem"]], VD4019 = 1200, V2009 = 24)
    add(VD4009 = "Conta-própria", V4019 = "Não", VD4019 = 900,
        VD3004 = "Fundamental completo ou equivalente", V2009 = 50)
    add(VD4009 = R$VD4009[["pub_com"]], VD4019 = 4500,
        VD4004A = R$VD4004A[["subocup"]], VD3004 = "Superior completo")
    add(VD4009 = "Conta-própria", V4019 = "Sim", VD4019 = 2500, V2009 = 66,
        VD4010 = R$VD4010[["agro"]], V2010 = "Preta")
    add(VD4002 = R$VD4002[["desocup"]], VD4009 = NA, VD4019 = NA, VD4031 = NA,
        V2009 = 22, VD2002 = "Filho(a) do responsável somente")
    do.call(add, c(fora, list(VD4005 = "Pessoas desalentadas",
                              VD4003 = R$VD4003[["ftp"]],
                              V4074A = R$V4074A[["localidade"]])))
    do.call(add, c(fora, list(V2009 = 70, VD4030 = R$VD4030[["saude"]])))
    do.call(add, c(fora, list(V2009 = 19, VD4030 = R$VD4030[["afazeres"]],
                              VD2002 = "Filho(a) do responsável somente")))
    do.call(add, c(fora, list(V2009 = 10, VD4001 = NA, V3002 = "Sim",
                              VD3004 = "Sem instrução e menos de 1 ano de estudo")))
  }
  do.call(rbind, linhas)
}

# Estimativa bootstrap "na mão" a partir dos pesos: ponto com o peso principal,
# variância pela dispersão das réplicas (escala do próprio desenho).
razao_replicada <- function(design, num, den) {
  w  <- weights(design, "sampling")
  wr <- weights(design, "analysis")
  ponto <- sum(w * num) / sum(w * den)
  reps  <- colSums(wr * num) / colSums(wr * den)
  centro <- if (isTRUE(design$mse)) ponto else mean(reps)
  list(ponto = ponto,
       se = sqrt(design$scale * sum(design$rscales * (reps - centro)^2)))
}
