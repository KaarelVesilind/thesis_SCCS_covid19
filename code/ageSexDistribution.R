# Code for making visual Age,sex distribution plots. Table1 gives more info tho

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


con = connect(connectionDetails)

cohortId = 165

# Query out data
person = querySql(con, "select * from coriva.ohdsi_cdm_20211124.person;")
cohort = querySql(con, paste(c("select * from coriva.ohdsi_results_20211124.cohort where cohort_definition_id = ", cohortId, ";"), collapse=""))
data = left_join(cohort, person, by = c("SUBJECT_ID" = "PERSON_ID")) %>% mutate(Age = 2022 - YEAR_OF_BIRTH) %>% mutate(GENDER = GENDER_SOURCE_VALUE)

# Show data on graph
library(plyr)
library(dplyr)
counts = count(data, "GENDER")
mu <- ddply(data, "GENDER", summarise,  avg_age=mean(Age)) %>% 
  mutate(count = counts["freq"]) %>% 
  mutate(percentage = round(100 * (count/sum(count)), digits=2))
# Adding % sign manually because couldn't find other way. 
for (i in 1: 3) {
  mu$percentage[[1]][i] <- paste(mu$percentage[[1]][i],"%")
}
# Overlaid histograms
age = ggplot(data, aes(x=Age, color=GENDER)) +
  geom_histogram(fill="white", binwidth = 5) +
  geom_vline(data=mu, aes(xintercept=avg_age, color=GENDER),
             linetype="dashed")+
  theme(legend.position="top") +scale_color_manual(values=c("#00BFC4", "#F8766D", "#53B400"))+
  scale_fill_manual(values=c("#00BFC4", "#F8766D", "#53B400"))
age
mu
# Basic piechart
sex = ggplot(mu, aes(x="", y=unlist(count), fill=GENDER)) +
  geom_bar(stat="identity", width=1, color="white") +
  coord_polar("y", start=0) +
  geom_text(aes(label = unlist(percentage)),
            position = position_stack(vjust = 0.5), size=5)+
  theme_void() +
  theme(legend.position="top") +scale_color_manual(values=c("#00BFC4", "#F8766D", "#53B400"))+
  scale_fill_manual(values=c("#00BFC4", "#F8766D", "#53B400"))
sex
library(gridExtra)
graph = grid.arrange(age, sex, tableGrob(mu), top="Respiratory finding Age 18+ (162)", heights=2:1)


ggsave("~/AgeSexDistribution/165RespiratoryAgeOver18.pdf", graph, h=7, w=12)
