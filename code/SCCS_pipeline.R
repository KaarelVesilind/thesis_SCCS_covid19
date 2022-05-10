# SCCS study pipeline

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
# ATC codes for declared level
library("rjson")
myData <- fromJSON(file="ATC_level2.json")
ATCcodes = list()
for (i in myData) {
  ATCcodes = append(ATCcodes, i$concept_code)
}

#-----------------------------------------

resultList = list()
library(SelfControlledCaseSeries)

# Exposure cohort ID
exposureId = 165 

# Loop for studying every ATC code
for (outcomeId in 1: length(ATCcodes)){
  print(outcomeId)
  sccsData <- getDbSccsData(connectionDetails = connectionDetails,
                            cdmDatabaseSchema = cdmDatabaseSchema,
                            outcomeDatabaseSchema =  "kvesilind", 
                            outcomeTable = "COHORT_level2",
                            outcomeIds = outcomeId, 
                            exposureDatabaseSchema = cohortDatabaseSchema,
                            exposureTable = "COHORT",
                            exposureIds = exposureId,
                            cdmVersion = cdmVersion)
  studyPop <- createStudyPopulation(sccsData = sccsData,
                                    outcomeId = outcomeId,
                                    firstOutcomeOnly = FALSE,
                                    naivePeriod = 180)
  covarExposureSplit <- createEraCovariateSettings(label = "Exposure of interest",
                                                   includeEraIds = exposureId,
                                                   start = -30,
                                                   end = 10000, # Big number so the period is till the end of observation period
                                                   endAnchor = "era start",
                                                   splitPoints = c(30, 180))
  sccsIntervalData <- createSccsIntervalData(studyPopulation = studyPop,
                                             sccsData = sccsData,
                                             eraCovariateSettings = covarExposureSplit)
  if (summary(sccsIntervalData)$caseCount != 0) {
    model <- fitSccsModel(sccsIntervalData)
    # Save the results to list
    resultList = append(resultList, list(c(ATCcodes[outcomeId], getModel(model))))
  }
}

# ------------------------------------------
# Save results to file
saveRDS(resultList, file="results165RespiratoryAgeOver18_level2_period2.RData")