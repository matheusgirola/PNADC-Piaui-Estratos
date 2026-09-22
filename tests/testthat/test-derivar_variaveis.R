# Testes de R/derivar_variaveis.R sobre microdado sintético (helper-derivar.R).
# Rodar da raiz do projeto: testthat::test_dir("tests/testthat")

# ---- Guarda de rótulos ------------------------------------------------------

test_that("checar_rotulos() para quando um rótulo some do dicionário", {
  sem_ftp <- pessoa()   # nenhuma linha com o rótulo de VD4003
  expect_error(
    derivar_variaveis(montar_desenho(sem_ftp, cobertura = FALSE), sm_hora = 7),
    "VD4003"
  )
})

test_that("checar_rotulos() para quando uma variável some", {
  dados <- linhas_cobertura()
  dados$VD4030 <- NULL
  expect_error(checar_rotulos(dados), "VD4030 \\(variável ausente\\)")
})

test_that("checar_rotulos() passa quando todos os rótulos existem", {
  expect_true(checar_rotulos(linhas_cobertura()))
})

test_that("flag() transforma NA em 0", {
  expect_identical(flag(c(TRUE, FALSE, NA)), c(1, 0, 0))
})

# ---- Geografia --------------------------------------------------------------

test_that("Estrato_agregado cobre os limites de cada faixa", {
  estratos <- c("2210011", "2210030", "2220010", "2220020", "2251011",
                "2252022", "2253010", "2254020", "2210031", "2310011")
  v <- do.call(derivar_teste, lapply(estratos, function(e) pessoa(Estrato = e)))
  expect_identical(as.character(v$Estrato_agregado), c(
    "Teresina", "Teresina",
    "Entorno metropolitano de Teresina (PI)", "Entorno metropolitano de Teresina (PI)",
    "Centro-Leste do Piauí", "Baixo Parnaíba do Piauí",
    "Alto Parnaíba e Chapadas Sul do Piauí", "Alto Parnaíba e Chapadas Sul do Piauí",
    NA, NA
  ))
})

test_that("Situacao lê o 6º dígito do Estrato e só vale no Piauí", {
  v <- derivar_teste(
    pessoa(Estrato = "2251011"),
    pessoa(Estrato = "2251021"),
    pessoa(Estrato = "2251031"),
    pessoa(Estrato = "2251041"),
    pessoa(Estrato = "2951021", UF = "Bahia")
  )
  expect_identical(as.character(v$Situacao),
                   c("Urbano tradicional", "Rural", "FCU", NA, NA))
  expect_identical(levels(v$Situacao), c("Urbano tradicional", "Rural", "FCU"))
})

test_that("Regiao separa Nordeste do resto", {
  v <- derivar_teste(pessoa(UF = "Piauí"), pessoa(UF = "Bahia"), pessoa(UF = "São Paulo"))
  expect_identical(v$Regiao, c("Nordeste", "Nordeste", "Resto do Brasil"))
})

# ---- Recortes demográficos --------------------------------------------------

test_that("Faixa_Etaria_trabalho respeita os limites 14, 29/30, 64/65", {
  idades <- c(13, 14, 29, 30, 64, 65, 100)
  v <- do.call(derivar_teste, lapply(idades, function(i) pessoa(V2009 = i)))
  expect_identical(v$Faixa_Etaria_trabalho,
                   c(NA, "Jovens", "Jovens", "Adulto", "Adulto", "Idoso", "Idoso"))
})

test_that("Faixa_Etaria_sidra segue os grupos da tabela 4094", {
  idades <- c(13, 14, 17, 18, 24, 25, 39, 40, 59, 60)
  v <- do.call(derivar_teste, lapply(idades, function(i) pessoa(V2009 = i)))
  expect_identical(as.character(v$Faixa_Etaria_sidra), c(
    NA, "14 a 17 anos", "14 a 17 anos", "18 a 24 anos", "18 a 24 anos",
    "25 a 39 anos", "25 a 39 anos", "40 a 59 anos", "40 a 59 anos", "60 anos ou mais"
  ))
})

test_that("Instrucao corta em fundamental completo e mantém NA", {
  v <- derivar_teste(
    pessoa(VD3004 = "Fundamental completo ou equivalente"),
    pessoa(VD3004 = "Médio incompleto ou equivalente"),
    pessoa(VD3004 = NA)
  )
  expect_identical(as.character(v$Instrucao),
                   c("Até fundamental completo", "Acima de fundamental completo", NA))
})

test_that("Sexo reetiqueta V2007", {
  v <- derivar_teste(pessoa(V2007 = "Homem"), pessoa(V2007 = "Mulher"))
  expect_identical(as.character(v$Sexo), c("Masculino", "Feminino"))
})

test_that("recortes da PIT são NA fora dela e Raca_pit descarta Ignorado", {
  v <- derivar_teste(
    pessoa(V2009 = 13, VD4001 = NA, VD4002 = NA),
    pessoa(V2010 = "Ignorado"),
    pessoa(V2010 = "Preta", V2007 = "Mulher")
  )
  expect_identical(v$pit, c(0, 1, 1))
  expect_identical(as.character(v$Sexo_pit), c(NA, "Masculino", "Feminino"))
  expect_identical(as.character(v$Raca_pit), c(NA, NA, "Preta"))
  expect_identical(as.character(v$Instrucao_sidra),
                   c(NA, "Médio completo ou equivalente", "Médio completo ou equivalente"))
  expect_identical(levels(v$Instrucao_sidra), NIVEIS_VD3004)
})

# ---- Mercado de trabalho (0/1 sem NA) ---------------------------------------

test_that("indicadores 0/1 de força de trabalho nunca saem NA", {
  v <- derivar_teste(
    pessoa(),
    pessoa(VD4002 = ROTULOS$VD4002[["desocup"]], VD4009 = NA),
    pessoa(VD4001 = ROTULOS$VD4001[["fora"]], VD4002 = NA, VD4009 = NA),
    pessoa(V2009 = 10, VD4001 = NA, VD4002 = NA, VD4009 = NA)
  )
  expect_identical(v$ft,      c(1, 1, 0, 0))
  expect_identical(v$fora_ft, c(0, 0, 1, 0))
  expect_identical(v$ocup,    c(1, 0, 0, 0))
  expect_identical(v$desocup, c(0, 1, 0, 0))
  expect_false(anyNA(v[c("pit", "ft", "fora_ft", "ocup", "desocup",
                         "emp_privado", "emp_publico", "ocup_agro",
                         "subocup_horas", "ftp", "subutil", "ft_ampliada")]))
})

test_that("subutilização soma subocupado, desocupado e FTP", {
  v <- derivar_teste(
    pessoa(VD4004A = ROTULOS$VD4004A[["subocup"]]),
    pessoa(VD4002 = ROTULOS$VD4002[["desocup"]], VD4009 = NA),
    pessoa(VD4001 = ROTULOS$VD4001[["fora"]], VD4002 = NA, VD4009 = NA,
           VD4003 = ROTULOS$VD4003[["ftp"]]),
    pessoa(VD4001 = ROTULOS$VD4001[["fora"]], VD4002 = NA, VD4009 = NA)
  )
  expect_identical(v$subutil,     c(1, 1, 1, 0))
  expect_identical(v$ft_ampliada, c(1, 1, 1, 0))
})

test_that("emp_privado e emp_publico seguem as categorias do SIDRA 4097", {
  cats <- c(ROTULOS$VD4009, "Trabalhador doméstico com carteira de trabalho assinada")
  v <- do.call(derivar_teste, lapply(cats, function(x) pessoa(VD4009 = x)))
  expect_identical(v$emp_privado, c(1, 1, 0, 0, 0, 0))
  expect_identical(v$emp_publico, c(0, 0, 1, 1, 1, 0))
})

test_that("ocup_agro exige estar ocupado", {
  agro <- ROTULOS$VD4010[["agro"]]
  v <- derivar_teste(
    pessoa(VD4010 = agro),
    pessoa(VD4010 = agro, VD4002 = ROTULOS$VD4002[["desocup"]]),
    pessoa()
  )
  expect_identical(v$ocup_agro, c(1, 0, 0))
})

test_that("informal cobre as cinco posições e exige CNPJ ausente (V4019)", {
  v <- derivar_teste(
    pessoa(VD4009 = ROTULOS$VD4009[["priv_sem"]]),
    pessoa(VD4009 = "Trabalhador doméstico sem carteira de trabalho assinada"),
    pessoa(VD4009 = "Trabalhador familiar auxiliar"),
    pessoa(VD4009 = "Conta-própria", V4019 = "Não"),
    pessoa(VD4009 = "Conta-própria", V4019 = "Sim"),
    pessoa(VD4009 = "Conta-própria", V4019 = NA),
    pessoa(VD4009 = "Empregador", V4019 = "Não"),
    pessoa(VD4009 = ROTULOS$VD4009[["priv_com"]]),
    pessoa(VD4009 = NA)
  )
  expect_identical(v$informal, c(1, 1, 1, 1, 0, 0, 1, 0, 0))
})

test_that("nem_nem: 14 a 29, não estuda e não ocupado", {
  v <- derivar_teste(
    pessoa(V2009 = 20, V3002 = "Não", VD4002 = ROTULOS$VD4002[["desocup"]]),
    pessoa(V2009 = 20, V3002 = "Não", VD4002 = NA),
    pessoa(V2009 = 20, V3002 = "Sim", VD4002 = NA),
    pessoa(V2009 = 20, V3002 = "Não"),
    pessoa(V2009 = 30, V3002 = "Não", VD4002 = NA),
    pessoa(V2009 = 13, V3002 = "Não", VD4002 = NA)
  )
  expect_identical(v$nem_nem, c(1, 1, 0, 0, 0, 0))
})

test_that("ft_ou_desalentada inclui desalentados fora da força", {
  v <- derivar_teste(
    pessoa(),
    pessoa(VD4001 = ROTULOS$VD4001[["fora"]], VD4002 = NA, VD4005 = "Pessoas desalentadas"),
    pessoa(VD4001 = ROTULOS$VD4001[["fora"]], VD4002 = NA)
  )
  expect_identical(v$ft_ou_desalentada, c(1, 1, 0))
})

# ---- Rendimento -------------------------------------------------------------

test_that("valor_hora usa 5 semanas por mês e subremuneração compara com sm_hora", {
  v <- derivar_teste(
    pessoa(VD4019 = 1000, VD4031 = 40),   # 5,00/h < 7
    pessoa(VD4019 = 1400, VD4031 = 40),   # 7,00/h, não é < 7
    pessoa(VD4019 = 2000, VD4031 = 40, Habitual = 1.1)
  )
  expect_equal(v$valor_hora, c(5, 7, 10))
  expect_identical(v$subremuneracao, c(1, 0, 0))
  expect_equal(v$VD4019_real, c(1000, 1400, 2200))
})

# ---- Agrupamentos de motivos (NA fica NA) -----------------------------------

test_that("motivo_desistencia_grupo agrupa e preserva NA", {
  v <- derivar_teste(
    pessoa(V4074A = ROTULOS$V4074A[["localidade"]]),
    pessoa(V4074A = "Outro motivo qualquer"),
    pessoa(V4074A = NA)
  )
  expect_identical(as.character(v$motivo_desistencia_grupo),
                   c("Não havia trabalho na localidade", "Outros motivos", NA))
})

test_that("motivo_nao_procura_grupo agrupa e preserva NA", {
  v <- derivar_teste(
    pessoa(VD4030 = ROTULOS$VD4030[["afazeres"]]),
    pessoa(VD4030 = ROTULOS$VD4030[["saude"]]),
    pessoa(VD4030 = "Outro motivo qualquer"),
    pessoa(VD4030 = NA)
  )
  expect_identical(as.character(v$motivo_nao_procura_grupo), c(
    "Afazeres domésticos ou cuidado de parentes", "Problema de saúde ou gravidez",
    "Outros motivos", NA
  ))
})

# ---- Contrato da função -----------------------------------------------------

test_that("derivadas pré-existentes são sobrescritas, não reaproveitadas", {
  dados <- pessoa(V2009 = 13, VD4001 = NA, VD4002 = NA)
  dados$pit <- 1        # valor velho e errado, como num .rds antigo
  dados$informal <- 1
  desenho <- montar_desenho(dados)
  v <- derivar_variaveis(desenho, sm_hora = 7)$variables
  expect_identical(v$pit[1], 0)
  expect_identical(v$informal[1], 0)
})

test_that("devolve o desenho preparado pelo convey, sem perder linhas", {
  desenho <- montar_desenho(pessoa())
  d <- derivar_variaveis(desenho, sm_hora = 7)
  expect_s3_class(d, "svyrep.design")
  expect_s3_class(d, "convey.design")
  expect_identical(nrow(d$variables), nrow(desenho$variables))
})
