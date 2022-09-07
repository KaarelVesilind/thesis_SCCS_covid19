### Database connections
library(DatabaseConnector)

#------ VARIABLES -------
#Vaadeldav kohort 
exposureId = 191
#Tulemustefaili nimi
resultsFile = "results191_level5_firstusage.RData"
#ATC level
ATCfile = "ATC_level5.json"
#------------------------

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

connect(connectionDetails)

outputFolder <- "/home/kvesilind"
cdmDatabaseSchema <- "ohdsi_cdm_20211124"
cohortDatabaseSchema <- "ohdsi_results_20211124"
cohortTablePrefix <- "aesi2"
cohortTable <- "aesi2_cohort"
databaseId <- "U_OF_TARTU_EE"
databaseName <- "University of Tartu"
databaseDescription <- "National health insurance claims for all Estonian COVID-19 cases before February 2021 (~56K cases) and four controls (randomly selected form population) per every case. The database was updated in Nov 2021 and ~25K controls also contracted COVID-19 between February 2021 and November 2021."
cdmVersion <- 5.3

#------------------------------------
# ATC koodide tõmbamine ja neist listi tegemine
library("rjson")
myData <- fromJSON(file=ATCfile)
ATCcodes = list()
for (i in myData) {
  ATCcodes = append(ATCcodes, i$concept_code)
}
#-----------------------------------------
length(ATCcodes)
#Uuringu andmete salvestamine soovitud kujule.

resultList = list()
library(SelfControlledCaseSeries)
for (outcomeId in 1: length(ATCcodes)){
  print(outcomeId)
  sccsData <- getDbSccsData(connectionDetails = connectionDetails,
                            cdmDatabaseSchema = cdmDatabaseSchema,
                            outcomeDatabaseSchema =  "kvesilind", 
                            outcomeTable = "COHORT_level5_firstusage",
                            outcomeIds = outcomeId, 
                            exposureDatabaseSchema = cohortDatabaseSchema,
                            exposureTable = "COHORT",
                            exposureIds = exposureId,
                            cdmVersion = cdmVersion)
  studyPop <- createStudyPopulation(sccsData = sccsData,
                                    outcomeId = outcomeId,
                                    firstOutcomeOnly = FALSE,
                                    naivePeriod = 365)
  covarExposureSplit <- createEraCovariateSettings(label = "Exposure of interest",
                                                   includeEraIds = exposureId,
                                                   start = -30,
                                                   end = 10000, # Suur number, et long-covid oleks andmebaasis oleva perioodi lõpuni
                                                   endAnchor = "era start",
                                                   splitPoints = c(30, 180))
  sccsIntervalData <- createSccsIntervalData(studyPopulation = studyPop,
                                             sccsData = sccsData,
                                             eraCovariateSettings = covarExposureSplit)
  if (summary(sccsIntervalData)$caseCount != 0) {
    model <- fitSccsModel(sccsIntervalData)
    # Salvestame tulemuse hilisemaks analüüsiks listi. Vahepeal mudel ei suuda fittida ja tuleb katkine mudel, selleks try
    try({
      resultList = append(resultList, list(c(ATCcodes[outcomeId], getModel(model))))
    })
  }
}
#getModel(model)


# ------------------------------------------
# Salvestame tulemused hilisemaks, et ei peaks uuesti uuringut läbi jooksutama
saveRDS(resultList, file=resultsFile)
