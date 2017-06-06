# ************************************************************************************************
# *****************       FutureLearn Analytics dashboard. (Educators' view)    *********************************
#
# The project is developed to provide re-usable analytics building blocks supporting the sense-making process of
# learners' and educators' activity in FutureLearn MOOCs.
# The original data sources are provided by FutureLearn to partners as files in CSV format. The code shared in this
# repository is based on a specific database conversion, and the overall architecture are documented in the README file.
#
# The scripts are provided 'as is' WITHOUT ANY WARRANTY. The key is to encourage others in the community
# to share knowledge, expertise and experiences, contributing to the project and benefit each other in the process.
#
# For this reason, the code is released under GNU Affero General Public License, version 3.
# For a quick summary see: https://tldrlegal.com/license/gnu-affero-general-public-license-v3-(agpl-3.0)
# Full details of the license see: https://www.gnu.org/licenses/agpl.html
#
# The original code was written by Dr. Mahsa Chitsaz, Educational Data Scientist
# in the Portfolio of the Pro-Vice Chancellor Education PVC(E) at UNSW Sydney, Australia.
#
# For further information, requests to access the repo as developer, comments and feedback,
# please contact education.data@unsw.edu.au
#
# ************************************************************************************************

findDBNameVersion <- function(courseSlug)
{
  db_version <- substr(courseSlug,rev(gregexpr("\\-", courseSlug)[[1]])[1]+1,nchar(courseSlug))
  db_name <- substr(courseSlug,1,rev(gregexpr("\\-", courseSlug)[[1]])[1]-1)
  result <- data.frame(database=character(0),version=character(0))
  result <- rbind(result, c(db_name,db_version))
  colnames(result) <- c("database","version")
  return(result)
}

findStartEndDatesByWeek <- function(courseSlug)
{
  # dbInfo <- findDBNameVersion(courseSlug)
  mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=db_name, host=db_host)
  
  #dates2 <- as.Date(c(startEndDates$start_date, startEndDates$end_date), format = "%Y-%m-%d")
  db_detail = findDBNameVersion(courseSlug)
  query = paste("call futurelearn_courses_information.find_start_dates_by_week('",db_detail$database,"','", db_detail$version ,"');",sep = "")
  rs = dbSendQuery(mydb, query)
  startEndDatesByWeek = fetch(rs, n=-1)
  dbClearResult(rs)
  dbDisconnect(mydb)
  return(startEndDatesByWeek)
}


findStartEndDates <- function(courseSlug)
  {
    dbInfo <- findDBNameVersion(courseSlug)
    mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=db_name, host=db_host)
    rs = dbSendQuery(mydb, paste("SELECT start_date, end_date FROM course_information WHERE course_name_fl ='",dbInfo$database,"' and version = ", dbInfo$version,sep=""))
    startEndDates = fetch(rs, n=-1)
    dbClearResult(rs)
    dbDisconnect(mydb)
    dates2 <- as.Date(c(startEndDates$start_date, startEndDates$end_date), format = "%Y-%m-%d")
    return(dates2)
}

getStepTypeByCourse <- function()
{
  db_detail = findDBNameVersion(courseSlug)
  query = paste("call futurelearn_courses_information.find_step_type_by_course('",db_detail$database,"','", db_detail$version ,"');",sep = "")
  mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=db_name, host=db_host)
  rs = dbSendQuery(mydb, query)
  stepTypeByCourse = fetch(rs, n=-1)
  dbClearResult(rs)
  dbDisconnect(mydb)
  return(stepTypeByCourse)
}

result <-  function(x) 
{ if(is.na(as.numeric(x)) == F)
{if (x>0) return('positive') 
  if (x<0) return('negative') 
  return('neutral')}
}