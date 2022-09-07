# install.packages("rjson") # Optional
library("rjson") 
library(Capr)
### Database connections
library(DatabaseConnector)

Sys.setenv(DATABASECONNECTOR_JAR_FOLDER = "/home/kvesilind/Jdbc")
#downloadJdbcDrivers(dbms = "postgresql")

# options(andromedaTempFolder = "D:/andromedaTemp")
options(sqlRenderTempEmulationSchema = NULL)

# Details for connecting to the server:
# See ?DatabaseConnector::createConnectionDetails for help
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = "localhost/coriva",
  user = "kvesilind",
  password = readLines("~/.password_kvesilind"))

connection <- connect(connectionDetails)

vocabularyDatabaseSchema <- "ohdsi_cdm_20220330" 



# Kõigi ATC kolmanda taseme koodide sisselugemine
# tõmbasin andmed välja datagripiga ohdsi_vocab schema concept tabelist concept_class_id = 'ATC 3rd'
# Load the package required to read JSON files.

# Give the input file name to the function.
myData <- fromJSON(file="/home/kvesilind/ATC_level5.json")
# Print the result.
print(length(myData))

# CohortGenerator::createCohortTables(connectionDetails = connectionDetails, cohortDatabaseSchema = "rkolde", cohortTableNames = CohortGenerator::getCohortTableNames("cohort_level5"))

# myData = tail(myData, -4169)
# print(length(myData))
cohortId = 0
for (code in myData) {
  cohortId = cohortId + 1
  print(cohortId)
  #code$concept_code = "R03AC02"
  #code1 = "R01AD12"
  #Cohordi tegemine
  # 1 - leia concept code ravimi jaoks
  conceptCode = getConceptCodeDetails(conceptCode = code$concept_code,
                                      vocabulary = "ATC",
                                      connection = connection,
                                      vocabularyDatabaseSchema = vocabularyDatabaseSchema,
                                      mapToStandard = F)  %>%
    createConceptSetExpression(Name = code$concept_code, includeDescendants = F)
  
  # 2 -cohort entry event
  
  # Drug exposure
  
  exposureQuery = createDrugExposure(conceptSetExpression = NULL, attributeList = list(createFirstAttribute(), createDrugSourceConceptAttribute(conceptCode)))
  
  
  DrugDiag <- createPrimaryCriteria(Name = paste(code$concept_name, "prescriptions"),
                                    ComponentList = list(exposureQuery),
                                    ObservationWindow = createObservationWindow(0L,0L),
                                    Limit = "All")
  
  
  
  # 3 - Inclusion criteria
  
  inclusion = createInclusionRules('', NULL, Limit = "ALL", Description = NULL)
  
  
  # 4 - Cohort exit
  
  EsDrugDiag <- createDateOffsetEndStrategy(offset = 1, eventDateOffset = "StartDate")
  
  # 5 - Cohort definition
  cd <- createCohortDefinition(Name = paste(code$concept_name, "prescriptions"),
                               Description = paste("Code", code$concept_code),
                               PrimaryCriteria = DrugDiag,
                               InclusionRules = inclusion,
                               EndStrategy = EsDrugDiag)
  
  # 6 - Cohort deployment
  genOp <- CirceR::createGenerateOptions(cohortIdFieldName = "cohort_definition_id",
                                         cohortId = cohortId,
                                         cdmSchema = vocabularyDatabaseSchema,
                                         targetTable = "cohort_level5_20220330",
                                         resultSchema = "kvesilind",
                                         vocabularySchema = vocabularyDatabaseSchema,
                                         generateStats = F)
  cohortInfo <- compileCohortDefinition(cd, genOp)
  #cohortInfo
  
  # 7 - SQL magic
  sql <- cohortInfo$ohdiSQL
  sql <- SqlRender::render(sql)
  sql <- SqlRender::translate(sql, "postgresql")
  DatabaseConnector::executeSql(connection = connection, sql = sql)
  
}

