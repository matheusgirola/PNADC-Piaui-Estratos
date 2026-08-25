# 1. Instalar e carregar os pacotes necessários
install.packages(c("tidyverse", "survey", "PNADcIBGE", "geobr", "sf"))
library(tidyverse)
library(survey)
library(PNADcIBGE)
library(geobr)
library(sf)

# 2. Baixar os microdados da PNAD Contínua (Ex: 2026, Trimestre 1)
# O pacote PNADcIBGE já baixa o arquivo e cria o objeto de desenho amostral
pnad_objeto <- get_pnad(year = 2026, quarter = 1, design = TRUE)

# 3. Calcular a renda média por UPA considerando o peso amostral
# V2007 = Sexo, VD4019 = Rendimento mensal habitual do trabalho principal
renda_por_upa <- svyby(
  formula = ~VD4019, 
  by = ~UPA, 
  design = pnad_objeto, 
  FUN = svymean, 
  na.rm = TRUE
)

# 4. Baixar a malha de setores censitários do IBGE (Ex: Estado de São Paulo)
# Nota: Você precisará da tabela de correspondência UPA -> Setor Censitário 
# que o IBGE disponibiliza nos arquivos de documentação da PNAD.
setores_sp <- read_census_tract(code_tract = "SP", year = 2020)

# 5. Cruzar os dados estatísticos com a base geográfica (sf)
# Supondo que você já associou os setores às suas respectivas UPAs
mapa_renda <- setores_sp %>%
  left_join(renda_por_upa, by = c("cod_upa" = "UPA"))

# 6. Gerar o mapa de espacialização
ggplot(data = mapa_renda) +
  geom_sf(aes(fill = VD4019), color = NA) +
  scale_fill_viridis_c(name = "Renda Média (R$)", na.value = "gray90") +
  theme_minimal() +
  labs(title = "Espacialização da Renda Média por UPA / Setor Censitário")