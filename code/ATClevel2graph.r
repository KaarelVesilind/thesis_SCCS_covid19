### Database connections
library(DatabaseConnector)

Sys.setenv(DATABASECONNECTOR_JAR_FOLDER = "/home/kvesilind/Jdbc")
downloadJdbcDrivers(dbms = "postgresql")

# options(andromedaTempFolder = "D:/andromedaTemp")
options(sqlRenderTempEmulationSchema = NULL)

# Details for connecting to the server:
# See ?DatabaseConnector::createConnectionDetails for help
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = "localhost/coriva",
  user = "kvesilind",
  password = readLines("~/.password_kvesilind"))

library(dplyr)  
#install.packages('tidyverse')
library(tidyverse)

con = connect(connectionDetails)

# ATC table
ATC = querySql(con, "select * from coriva.ohdsi_vocab.concept where vocabulary_id = 'ATC';")

covid = readRDS("/home/kvesilind/data/results162CovidAgeOver18_level2_period2.RData")
respiratory = readRDS("/home/kvesilind/data/results165RespiratoryAgeOver18_level2_period2.RData")


covid = map(covid, function(x){names(x)[1] = "ATC"; x}) %>% map(as_tibble) %>% bind_rows %>% filter(str_detect(name, "day 31-180")) %>% mutate(Cohort = "Covid-19 Age 18+")
respiratory = map(respiratory, function(x){names(x)[1] = "ATC"; x}) %>% map(as_tibble) %>% bind_rows %>% filter(str_detect(name, "day 31-180")) %>% mutate(Cohort = "Respiratory finding Age 18+")

data = bind_rows(covid, respiratory)

data = data %>%
  mutate(ATC1 = str_sub(ATC, 1, 1)) %>%
  left_join(ATC %>% select(DrugClass = "CONCEPT_NAME", ATC1 = "CONCEPT_CODE")) %>%
  left_join(ATC %>% select(DrugName = "CONCEPT_NAME", ATC = "CONCEPT_CODE")) 

# Add ATC code and name together
data$ATC = paste(data$ATC, ' (',data$DrugName, ')', sep='' )


ggplot(data) + 
  geom_point(aes(x = estimate, y = ATC, color = Cohort)) + 
  geom_errorbar(aes(x = estimate, xmin = lb95Ci, xmax = ub95Ci, y = ATC, color = Cohort)) + 
  scale_x_continuous(trans = "log2", limits = c(0.5, 4)) + 
  geom_vline(xintercept = 1) + 
  facet_grid(DrugClass ~., scales = "free_y", space = "free_y") +
  theme_bw() +
  theme(
    strip.text.y = element_text(angle = 0),
    legend.position = c(0.01, 0.99),
    legend.justification = c(0, 1)
  )

ggsave("~/ATClevel2_graph.pdf",h = 20, w = 20)
