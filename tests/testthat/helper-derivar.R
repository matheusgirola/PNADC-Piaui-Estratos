# ==============================================================================
# helper-derivar.R — microdado sintético para testar R/derivar_variaveis.R.
#
# Não usa o cache .rds: cada teste descreve as pessoas que importam pra ele
# (pessoa(...)) e o helper monta um svrepdesign pequeno. Os nomes e rótulos
# imitam o que get_pnadc() entrega; os rótulos de que as fórmulas dependem vêm
# do próprio ROTULOS do módulo.
# ==============================================================================

source(test_path("..", "..", "R", "derivar_variaveis.R"), encoding = "UTF-8")

NIVEIS_VD3004 <- c("Sem instrução e menos de 1 ano de estudo",
                   "Fundamental incompleto ou equivalente",
                   "Fundamental completo ou equivalente",
                   "Médio incompleto ou equivalente",
                   "Médio completo ou equivalente",
                   "Superior incompleto ou equivalente",
                   "Superior completo")

SM_HORA_TESTE <- 7

# Pessoa "neutra": 35 anos, Teresina urbana, ocupada com carteira no setor
# privado, médio completo. Cada teste sobrescreve só o que interessa.
pessoa <- function(...) {
  base <- list(
    UF = "Piauí", Estrato = "2210011", V1022 = "Urbana", V1023 = "Capital",
    V2007 = "Homem", V2009 = 35, V2010 = "Parda",
    VD3004 = "Médio completo ou equivalente", V3002 = "Não", VD2002 = "Pessoa responsável",
    VD4001 = ROTULOS$VD4001[["ft"]], VD4002 = ROTULOS$VD4002[["ocup"]],
    VD4003 = NA, VD4004A = NA, VD4005 = NA,
    VD4009 = ROTULOS$VD4009[["priv_com"]], V4019 = NA,
    VD4010 = "Comércio, reparação de veículos automotores e motocicletas",
    VD4019 = 2000, VD4031 = 40, Habitual = 1,
    V4074A = NA, VD4030 = NA
  )
  campos <- list(...)
  desconhecidos <- setdiff(names(campos), names(base))
  if (length(desconhecidos) > 0) stop("Campo desconhecido em pessoa(): ", desconhecidos)
  base[names(campos)] <- campos
  as.data.frame(base, stringsAsFactors = FALSE)
}

# Linhas que só existem pra que todos os rótulos de ROTULOS apareçam nos dados
# (checar_rotulos() para a execução se algum faltar). Descartadas no retorno.
linhas_cobertura <- function() {
  r <- ROTULOS
  do.call(rbind, c(
    lapply(r$VD4001, function(x) pessoa(VD4001 = x)),
    lapply(r$VD4002, function(x) pessoa(VD4002 = x)),
    list(pessoa(VD4003 = r$VD4003[["ftp"]]),
         pessoa(VD4004A = r$VD4004A[["subocup"]]),
         pessoa(VD4010 = r$VD4010[["agro"]]),
         pessoa(V4074A = r$V4074A[["localidade"]]),
         # factor(V1022/V2007, labels = ...) exige os dois níveis presentes
         pessoa(V1022 = "Rural", V2007 = "Mulher")),
    lapply(r$VD4009, function(x) pessoa(VD4009 = x)),
    lapply(r$VD4030, function(x) pessoa(VD4030 = x))
  ))
}

# Monta o desenho com as pessoas do teste + cobertura. Pesos e réplicas são
# arbitrários: aqui só a lógica linha a linha está em teste.
montar_desenho <- function(pessoas, cobertura = TRUE) {
  dados <- pessoas
  dados$.teste <- TRUE
  if (cobertura) {
    cob <- linhas_cobertura()
    cob$.teste <- FALSE
    cob[setdiff(names(dados), names(cob))] <- NA   # colunas extras do teste
    dados <- rbind(dados, cob)
  }
  dados$V2007  <- factor(dados$V2007, levels = c("Homem", "Mulher"))
  dados$V1022  <- factor(dados$V1022, levels = c("Urbana", "Rural"))
  dados$VD3004 <- factor(dados$VD3004, levels = NIVEIS_VD3004)
  dados$V1028  <- 100
  dados$V1028001 <- 90
  dados$V1028002 <- 110
  survey::svrepdesign(data = dados, weights = ~V1028,
                      repweights = "V1028[0-9]+", type = "bootstrap",
                      mse = TRUE, combined.weights = TRUE)
}

# Deriva e devolve só as linhas das pessoas do teste, na ordem em que vieram.
derivar_teste <- function(...) {
  pessoas <- do.call(rbind, list(...))
  d <- derivar_variaveis(montar_desenho(pessoas), sm_hora = SM_HORA_TESTE)
  v <- d$variables
  v[v$.teste, , drop = FALSE]
}
