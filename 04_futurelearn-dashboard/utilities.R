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

getStepTypeByCourse <- function(courseSlug)
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


getStepUrlByCourse <- function(courseSlug)
{
  db_detail = findDBNameVersion(courseSlug)
  query = paste("call futurelearn_courses_information.find_step_url_by_course('",db_detail$database,"','", db_detail$version ,"');",sep = "")
  mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=db_name, host=db_host)
  rs = dbSendQuery(mydb, query)
  stepUrlByCourse = fetch(rs, n=-1)
  dbClearResult(rs)
  dbDisconnect(mydb)
  return(stepUrlByCourse)
}

result <-  function(x) 
{ if(is.na(as.numeric(x)) == F)
{if (x>0) return('positive') 
  if (x<0) return('negative') 
  return('neutral')}
}

isPreResponsesAvailable <- function(courseSlug)
{
  mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
  rs = dbSendQuery(mydb, "select renamed_col from renamed_col_pre_responses 
                   where original_col='Which country do you live in?' or original_col='What is your gender?'")
  renamed.col = fetch(rs, n=-1)
  dbClearResult(rs)
  dbDisconnect(mydb)
  
  mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
  rs = dbSendQuery(mydb, paste("select ",renamed.col$renamed_col,",partner_export_id from pre_responses"))
  pre.responses = fetch(rs, n=-1)
  dbClearResult(rs)
  dbDisconnect(mydb)
  
  if(nrow(pre.responses)>0)
  {
    return(courseSlug)
  }
  return(FALSE)
}

# Function to compute Jensen-Shannon divergence between two distributions
# (This is slightly more standard than the 'symmetric Kullback-Leibler divergence' computed below_
jensen.shannon.divergence <- function(p, q) {
  m <- 0.5*(p + q)
  0.5*sum(p*log(p/m)) + 0.5*sum(q*log(q/m))
}

# Symmetric version of Kullback-Leibler divergence:
KL <- function(x, y) {
  0.5*sum(x*log(x/y)) + 0.5*sum(y*log(y/x))
}

big <- function(Dt, pos=1) {
  ordered_rows <- apply(Dt, 1, order, decreasing = TRUE)
  positions <- rep(colnames(Dt), nrow(Dt))[as.vector(ordered_rows[pos,])]
  return(positions)
}