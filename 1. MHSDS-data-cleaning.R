#######################################
################ TO-DO ################
#######################################

#######################################
################ SETUP ################
#######################################

#Load packages
library("tidyverse")
library("lubridate")
library("here")
library("data.table")

#Clean up the global environment
rm(list = ls())

#Do we want to refresh data?
#If running this for the first time change to 'YES'
#If new data has been added to the NHS England website, change to 'YES' to add this
#Otherwise leave as 'NO'

refresh_data <- "YES"

if(refresh_data=="YES"){
  #Refresh data
  source(here::here("NHSE-web-scraper.R"))
  source(here::here("0. File locations.R"))
} else if (refresh_data=="NO"){
  source(here::here("0. File locations.R"))
}

############################################################################
################ CREATE FOLDER IN REPO FOR DASHBOARD FILES #################
############################################################################

if ("Clean data for dashboard" %in% list.dirs(path = here::here(), full.names = FALSE, recursive = FALSE)){
} else {
  dir.create(here::here("Clean data for dashboard"))
}

##################################################
################ CLEAN MAIN FILE #################
##################################################

MHSDS_main_pooled <- fread(paste0(rawdatadir,main_name,"/Pooled/MHSDS_main_pooled.csv"),
                      header=TRUE, sep=",", check.names=T)

#Subset of metrics (to make size more manageable)

MHSDS_main_pooled <- MHSDS_main_pooled %>%
  filter(.,MEASURE_ID %in% c("CYP01","CYP32","CYP21"))

#Correct dates
MHSDS_main_pooled <- MHSDS_main_pooled %>%
  mutate(.,format_date=ifelse(str_detect(REPORTING_PERIOD_START,"/"),"dmy","ymd")) %>% 
  mutate(.,
         start_ymd=ifelse(format_date=="ymd",REPORTING_PERIOD_START,NA),
         start_dmy=ifelse(format_date=="dmy",REPORTING_PERIOD_START,NA),
         end_ymd=ifelse(format_date=="ymd",REPORTING_PERIOD_END,NA),
         end_dmy=ifelse(format_date=="dmy",REPORTING_PERIOD_END,NA)) %>%
  mutate(.,
         start_ymd=lubridate::ymd(start_ymd),
         start_dmy=lubridate::dmy(start_dmy),
         end_ymd=lubridate::ymd(end_ymd),
         end_dmy=lubridate::dmy(end_dmy)) %>%
  mutate(.,start_date=ymd(ifelse(is.na(start_ymd),as.character(start_dmy),
                             as.character(start_ymd))),
         end_date=ymd(ifelse(is.na(end_ymd),as.character(end_dmy),
                               as.character(end_ymd)))) %>% 
  select(.,-c("start_ymd","start_dmy","end_ymd","end_dmy")) %>%
  mutate(.,month_year=paste(lubridate::month(start_date,label = TRUE),lubridate::year(start_date),sep=" "))

#Save data for dashboard
fwrite(MHSDS_main_pooled, here::here("Clean data for dashboard","MHSDS_main_pooled.csv"), row.names = F, sep = ",")

##################################################
################ EXPLORE ED FILE #################
##################################################

MHSDS_ED_pooled <- fread(paste0(rawdatadir,ed_name,"/Pooled/MHSDS_ED_pooled.csv"),
                           header=TRUE, sep=",", check.names=T)

#Names of measures
ed_cyp_measures <- MHSDS_ED_pooled %>%
  pull(MEASURE_NAME) %>%
  unique(.)

#Clean up dates
MHSDS_ED_pooled <- MHSDS_ED_pooled %>%
  filter(.,MEASURE_ID %in% c("ED88")) %>% 
  mutate(.,start_date=lubridate::dmy(REPORTING_PERIOD_START),
         end_date=lubridate::dmy(REPORTING_PERIOD_END))

#Save data for dashboard
fwrite(MHSDS_ED_pooled, here::here("Clean data for dashboard","MHSDS_ED_pooled.csv"), row.names = F, sep = ",")