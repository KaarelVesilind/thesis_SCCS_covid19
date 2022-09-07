# Code for making table1

# Table 1

cohortId1 = 162

file = "tableone162.Rdata"

# -------------------------
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

outputFolder <- "/home/kvesilind"
cdmDatabaseSchema <- "ohdsi_cdm_20211124"
cohortDatabaseSchema <- "ohdsi_results_20211124"
cohortTablePrefix <- "aesi2"
cohortTable <- "aesi2_cohort"
databaseId <- "U_OF_TARTU_EE"
databaseName <- "University of Tartu"
databaseDescription <- "National health insurance claims for all Estonian COVID-19 cases before February 2021 (~56K cases) and four controls (randomly selected form population) per every case. The database was updated in Nov 2021 and ~25K controls also contracted COVID-19 between February 2021 and November 2021."
cdmVersion <- 5.3

#---------- Cohort data -----------
library("FeatureExtraction")

CovariateData1 = getDbCovariateData(
  cdmDatabaseSchema = cdmDatabaseSchema,
  connectionDetails = connectionDetails,
  cdmVersion = cdmVersion,
  cohortTable = "cohort",
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortId = cohortId1,
  rowIdField = "subject_id",
  covariateSettings = createDefaultCovariateSettings()
)

CovariateData1 = aggregateCovariates(CovariateData1)

isAggregatedCovariateData(CovariateData1)

#---------- Table1 ----------------
table1 = createTable1(
  covariateData1 = CovariateData1,
  specifications = getDefaultTable1Specifications(),
  output = "one column",
  showCounts = TRUE,
  showPercent = TRUE,
  percentDigits = 1,
  valueDigits = 1,
  stdDiffDigits = 2
)


saveRDS(table1, file=file)


table1 = readRDS("data/tableone/tableone162.Rdata")
table2 = readRDS("data/tableone/tableone187.Rdata")
table3 = readRDS("data/tableone/tableone190.Rdata")
table4 = readRDS("data/tableone/tableone189.Rdata")
print(left_join(table1, table2, by = "Characteristic"), n = Inf)
print(left_join(table3, table4, by = "Characteristic"), n = Inf)

print(table3, n = Inf)
print(table2, n = Inf)


