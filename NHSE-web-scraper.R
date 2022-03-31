#######################################
################ To-do ################
#######################################

#######################################
################ SETUP ################
#######################################

#Load packages
library("tidyverse")
library("lubridate")
library("DescTools")
library("pbapply")
library("here")
library("rvest")
library("downloader")
library("curl")
library("data.table")

#Clean up the global environment
rm(list = ls())

#Set directory where inputs are saved (*ACTION*)
source(here::here("0. File locations.R"))

#Create sub-directories if not already there

#Main performance files
if (main_name %in% list.dirs(path = rawdatadir, full.names = FALSE, recursive = FALSE)){
} else {
  dir.create(paste0(rawdatadir,main_name))
}
#Eating disorders
if (ed_name %in% list.dirs(path = rawdatadir, full.names = FALSE, recursive = FALSE)){
} else {
  dir.create(paste0(rawdatadir,ed_name))
}

#############################################################
################ Count number of files (PRE) ################
#############################################################

nr_files_before <- sapply(c(paste0(rawdatadir,main_name),
                          paste0(rawdatadir,ed_name)),
                        function(dir){length(list.files(dir,pattern='csv'))})

is_there_pooled_data <- sapply(c(paste0(rawdatadir,main_name,"/Pooled"),
                                 paste0(rawdatadir,ed_name,"/Pooled")),
                               function(dir){length(list.files(dir,pattern='csv'))})

######################################################
################ SCRAPE LANDING PAGES ################
######################################################

#NHS England Vaccination data website
nhse_link_series <- "https://digital.nhs.uk/data-and-information/publications/statistical/mental-health-services-monthly-statistics/"

#Scrape names of pages and clean
monthly_names <- read_html(nhse_link_series) %>%
  html_nodes(xpath="//a[contains(@class, 'cta__button')]") %>%
  html_text() %>%
  as.data.frame() %>%
  rename(.,name=".") %>%
  mutate(.,name=tolower(name)) %>%
  mutate(.,name=str_replace_all(name,"mental health services monthly statistics",""),
         name=str_replace_all(name,"number of children and young people accessing nhs funded community mental health services in england","cyp")) %>%
  mutate(.,name=str_replace_all(name,"-",""),
         name=str_replace_all(name,":",""),
         name=str_replace_all(name,",","")) %>%
  mutate(.,name=trimws(name, "both")) %>%
  mutate(.,index=1:n()) %>% #Find out which links we want to download from here on
  mutate(., first_year=parse_number(name),
         month_name_perf=str_extract(name,"performance(\\s+[^\\s]+){1}"),
         month_name_final=str_extract(name,"final(\\s+[^\\s]+){1}")) %>% 
  mutate(.,month_name=paste(month_name_perf,month_name_final,sep=" ")) %>%
  mutate(.,month_name=str_replace_all(month_name,"NA",""),
         month_name=str_replace_all(month_name,"performance",""),
         month_name=str_replace_all(month_name,"final",""),
         month_name=trimws(month_name, "both")) %>%
  mutate(.,month_year=paste(month_name,first_year,sep=" "),
         wanted=ifelse(month_name!="",1,0)) %>% #Indicator if we want to download this
  mutate(.,month_year=ifelse(name=="cyp april 2018 to march 2019 experimental statistics","april 2018 to march 2019",month_year)) %>% 
  select(.,-c("month_name_perf","month_name_final","first_year"))

#Scrape all download links
monthly_links <- read_html(nhse_link_series) %>%
  html_nodes(xpath="//a[contains(@class, 'cta__button')]/@href") %>%
  html_text() %>%
  paste0("https://digital.nhs.uk",.) %>%
  as.data.frame() %>% 
  rename(.,link=".") %>%
  mutate(.,index=1:n())

#Get only the links from subset we want and ann abbreviated month
months_abbv <- data.frame(month_name=c("january","february","march","april","may","june","july","august","september","october","november","december"),
                         month_abbv=c("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"))
monthly_names <- left_join(monthly_names,
                                  monthly_links,by="index") %>%
  left_join(.,months_abbv,by="month_name")
rm(monthly_links,months_abbv)

#Filter out unwanted links
monthly_names <- monthly_names %>%
  filter(.,wanted==1)

######################################################
################ SCRAPE MONTHLY PAGE #################
######################################################

#Create function to download monthly series
MHSDS_monthly_series_download <- function(monthyr){
  
  #monthyr <- "september 2021"
  
  #Display series name
  print(monthyr)
  
  #Get right monthly page
  nhse_monthly_link <- monthly_names %>%
    filter(.,month_year==monthyr) %>%
    pull(link)
  
  #Abbreviated month
  month_abbv <- monthly_names %>%
    filter(.,month_year==monthyr) %>%
    pull(month_abbv)
  
  if (length(nhse_monthly_link)>0) {
  
    #Get all csv names
    csv_names <- read_html(nhse_monthly_link) %>%
      html_nodes(xpath="//a[contains(@class, 'nhsd-a-box-link')]/@href") %>%
      html_text() %>%
      as.data.frame() %>% 
      rename(.,link=".") %>% 
      mutate(.,is_csv=str_detect(link, "csv")) %>%
      filter(.,is_csv==TRUE) %>%
      filter(.,str_detect(link,month_abbv)) #Only for 'final' month and not provisional
    
    ### FIRST FILE: Main performance file
    
    #Find link
    patterns_perf <- c(paste0("MHSDS_Data_",month_abbv,"F"),
                       paste0("Data_",month_abbv,"Prf"),
                       paste0("MHSDS%20Data_",month_abbv),
                       paste0("MHSDS%20Monthly_File_",month_abbv))
    prf_link <- csv_names %>%
      filter(.,str_detect(link, paste(patterns_perf, collapse = "|"))) %>%
      slice_head(.,n=1) %>%
      pull(link) %>%
      ifelse(length(.)!=0,.,"no link found")
    
    #Download into right folder
    setwd(paste0(rawdatadir,main_name))
    already_there_main <- list.files()
    to_download_main <- prf_link[which(basename(URLdecode(prf_link)) %in% already_there_main==FALSE)]
    
    if(length(to_download_main)==0){
      print("nothing to download")
    } else if (to_download_main!="no link found"){
      for (k in 1:length(to_download_main)){
        curl::curl_download(to_download_main[k], destfile=basename(URLdecode(to_download_main[k])))
      }
    } else {
      print("nothing to download")
    }
    rm(already_there_main,to_download_main,patterns_perf,prf_link)
    
    ### SECOND FILE: Eating disorders
    
    #Find link
    ed_link <- csv_names %>%
      filter(.,str_detect(link,paste0("CYPED_",month_abbv))) %>%
      slice_head(.,n=1) %>%
      pull(link) %>%
      ifelse(length(.)!=0,.,"no link found")
    
    #Download into right folder
    setwd(paste0(rawdatadir,ed_name))
    already_there_ed <- list.files()
    to_download_ed <- ed_link[which(basename(URLdecode(ed_link)) %in% already_there_ed==FALSE)]
    
    if(length(to_download_ed)==0){
      print("nothing to download")
    } else if (to_download_ed!="no link found"){
      for (k in 1:length(to_download_ed)){
        curl::curl_download(to_download_ed[k], destfile=basename(URLdecode(to_download_ed[k])))
      }
    } else {
      print("nothing to download")
    }
    rm(already_there_ed,to_download_ed,ed_link)
    
    #Clean up environment
    rm(month_abbv,nhse_monthly_link,csv_names)
    
  } else {
    print("Monthly series not found")
  }
}

#Test function
# MHSDS_monthly_series_download("september 2021")

#Choose months to run function on
all_months <- monthly_names %>%
  pull(month_year)

#Run function
pblapply(all_months,MHSDS_monthly_series_download)
rm(all_months,nhse_link_series,monthly_names,MHSDS_monthly_series_download)

##############################################################
################ Count number of files (POST) ################
##############################################################

nr_files_after <- sapply(c(paste0(rawdatadir,main_name),
                            paste0(rawdatadir,ed_name)),
                          function(dir){length(list.files(dir,pattern='csv'))})

####################################################################
################ Create a new pooled file if needed ################
####################################################################

### Main performance files

#Reshaping older files

basedir_main <- paste0(rawdatadir,main_name)

file_names_main_wide <- list.files(path = basedir_main, pattern= '*.csv', full.names = F, recursive = F) %>%
  as.data.frame() %>%
  rename(., filename=".") %>% 
  filter(.,str_detect(filename,"MHSDS Monthly_File_"))

for (k in 1:nrow(file_names_main_wide)){
  #k <- 1
  print(k)
  
  #Read in wide file
  data_wide <- fread(file = file.path(basedir_main, file_names_main_wide$filename[k]), header = T, colClasses = "character")
  
  #Check if already in long format, otherwise reformat
  if(ncol(data_wide)==11){
    print("already in long format")
  } else {
    print("reformatting")
    var_names <- names(data_wide)[which(!(names(data_wide) %in% c("REPORTING_PERIOD","STATUS","BREAKDOWN",
                                                                  "PRIMARY_LEVEL","PRIMARY_LEVEL_DESCRIPTION",
                                                                  "SECONDARY_LEVEL","SECONDARY_LEVEL_DESCRIPTION")))]
    data_long <- data_wide %>%
      pivot_longer(cols=var_names,
                   names_to="MEASURE_ID_NAME",values_to="MEASURE_VALUE") %>%
      mutate(.,REPORTING_PERIOD_START=paste("01-",REPORTING_PERIOD),
             REPORTING_PERIOD_END=paste("01-",REPORTING_PERIOD),
             MEASURE_ID=word(MEASURE_ID_NAME, 1, sep=" - "),
             MEASURE_NAME=word(MEASURE_ID_NAME, 2, sep=" - ")) %>%
      mutate(REPORTING_PERIOD_START=lubridate::dmy(REPORTING_PERIOD_START),
             REPORTING_PERIOD_END=lubridate::dmy(REPORTING_PERIOD_END)) %>%
      mutate(REPORTING_PERIOD_START=floor_date(REPORTING_PERIOD_START, "month"),
             REPORTING_PERIOD_END=ceiling_date(REPORTING_PERIOD_END, "month")) %>% 
      select(.,-c("REPORTING_PERIOD","MEASURE_ID_NAME")) %>%
      filter(.,MEASURE_ID!="Annual") #to remove duplicates
    
    #Save in long format
    fwrite(data_long, paste0(basedir_main,"/",file_names_main_wide$filename[k]), row.names = F, sep = ",")
  }
  }

#Appending

if ((nr_files_before[which(names(nr_files_before)==paste0(rawdatadir,main_name))] <
  nr_files_after[which(names(nr_files_after)==paste0(rawdatadir,main_name))])|
  is_there_pooled_data[which(names(is_there_pooled_data)==paste0(rawdatadir,main_name,"/Pooled"))]==0){
  #New files were added, so create new pooled files
    #Read in all files and append
  basedir_main <- paste0(rawdatadir,main_name)
  file_names_main <- list.files(path = basedir_main, pattern= '*.csv', full.names = F, recursive = F)
  big_list_main <- lapply(file_names_main, function(file_name){
    dat <- fread(file = file.path(basedir_main, file_name), header = T, colClasses = "character")
    dat$filename <- gsub('.csv', '', file_name)
    return(dat)
  })
  big_data_main <- rbindlist(l = big_list_main, use.names = T, fill = T)
    #Create new sub-folder if needed
  if ("Pooled" %in% list.dirs(path = paste0(rawdatadir,main_name), full.names = FALSE, recursive = FALSE)){
  } else {
    dir.create(paste0(rawdatadir,main_name,"/Pooled"))
  }
    #Save new pooled file
  fwrite(big_data_main, paste0(rawdatadir,main_name,"/Pooled/MHSDS_main_pooled.csv"), row.names = F, sep = ",")
  rm(basedir_main,file_names_main,big_list_main,big_data_main)
} else {
  #No new files were added
  print("No new files were added")
}

### Eating disorder files

if ((nr_files_before[which(names(nr_files_before)==paste0(rawdatadir,ed_name))] <
    nr_files_after[which(names(nr_files_after)==paste0(rawdatadir,ed_name))])|
    is_there_pooled_data[which(names(is_there_pooled_data)==paste0(rawdatadir,ed_name,"/Pooled"))]==0){
  #New files were added, so create new pooled files
  #Read in all files and append
  basedir_ed <- paste0(rawdatadir,ed_name)
  file_names_ed <- list.files(path = basedir_ed, pattern= '*.csv', full.names = F, recursive = F)
  big_list_ed <- lapply(file_names_ed, function(file_name){
    dat <- fread(file = file.path(basedir_ed, file_name), header = T, colClasses = "character")
    dat$filename <- gsub('.csv', '', file_name)
    return(dat)
  })
  big_data_ed <- rbindlist(l = big_list_ed, use.names = T, fill = T)
  #Save pooled file in new folder
  if ("Pooled" %in% list.dirs(path = paste0(rawdatadir,ed_name), full.names = FALSE, recursive = FALSE)){
  } else {
    dir.create(paste0(rawdatadir,ed_name,"/Pooled"))
  }
  fwrite(big_data_ed, paste0(rawdatadir,ed_name,"/Pooled/MHSDS_ED_pooled.csv"), row.names = F, sep = ",")
  rm(basedir_ed,file_names_ed,big_list_ed,big_data_ed)
  
} else {
  #No new files were added
  print("No new files were added")
}

rm(rawdatadir,main_name,ed_name,nr_files_before,nr_files_after,is_there_pooled_data)