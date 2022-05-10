# Code for making ATC level 5 graph

#-------------------------
library(tidyverse)

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = "localhost/coriva",
  user = "kvesilind",
  password = readLines("~/.password_kvesilind"),
  port = "5432")

con = DatabaseConnector::connect(connectionDetails)

# CompareRatios
cov = readRDS("/home/kvesilind/data/results162CovidAgeOver18_level5_period2.RData")
resp = readRDS("/home/kvesilind/data/results165RespiratoryAgeOver18_level5_period2.RData")

cov = map(cov, function(x){names(x)[1] = "ATC"; x}) %>% map(as_tibble) %>% bind_rows %>% filter(str_detect(name, "day 31-180")) %>% mutate(Cohort = "Covid-19 Age 18+")
resp = map(resp, function(x){names(x)[1] = "ATC"; x}) %>% map(as_tibble) %>% bind_rows %>% filter(str_detect(name, "day 31-180")) %>% mutate(Cohort = "Respiratory finding Age 18+")
data = merge(cov, resp, by='ATC')

# Source for the calculation http://genometoolbox.blogspot.com/2014/06/test-for-difference-in-two-odds-ratios.html
#(1) Take the absolute value of the difference between the two log odds ratios. We will call this value δ.

data = mutate(data, difference = abs(estimate.x - estimate.y))
data = mutate(data, sign_difference = sign(estimate.x - estimate.y))
#head(data)

#(2) Calculate the standard error for δ, SE(δ), using the formula:
data = mutate(data, SEdifference = sqrt(seLogRr.x**2 + seLogRr.y**2))
#head(data)

#(3) Calculate the Z score for the test: z=δ/SE(δ)
data = mutate(data, Zscore = difference/SEdifference)
#head(data)

#(4) Calculate Pvalue
data = mutate(data, Pvalue = 2*(1-pnorm(Zscore)))
#head(data)

# Join back with original data
ATC = querySql(con, "select * from coriva.ohdsi_vocab.concept where vocabulary_id = 'ATC';")
data = data %>%
  mutate(ATC1 = str_sub(ATC, 1, 1)) %>%
  left_join(ATC %>% select(DrugName = "CONCEPT_NAME", ATC = "CONCEPT_CODE")) 


d = bind_rows(cov, resp) %>%
  left_join(data %>% select(ATC, Pvalue, sign_difference)) %>%
  left_join(ATC %>% select(DrugName = "CONCEPT_NAME", ATC = "CONCEPT_CODE"))  %>%
  mutate(AtcDrug = paste(ATC, ' (',DrugName, ')', sep='' )) %>%
  mutate(AtcDrug = factor(AtcDrug) %>% fct_reorder(-Pvalue)) %>%
  filter(!is.na(Pvalue)) %>%
  filter(Pvalue < 0.05 / nrow(data))

ggplot(d) + 
  geom_point(aes(x = estimate, y = AtcDrug, color = Cohort)) + 
  geom_errorbar(aes(x = estimate, xmin = lb95Ci, xmax = ub95Ci, y = AtcDrug, color = Cohort)) + 
  scale_x_continuous(trans = "log2", limits = c(0.5, 4)) + 
  geom_vline(xintercept = 1) + 
  facet_grid(sign_difference ~., scales = "free_y", space = "free_y") +
  theme_bw() +
  theme(
    strip.text.y = element_text(angle = 0),
    legend.position = c(0.7, 0.99),
    legend.justification = c(0, 1)
  )

ggsave("~/level5_compared_signif.pdf",h = 40, w = 15, limitsize = FALSE)