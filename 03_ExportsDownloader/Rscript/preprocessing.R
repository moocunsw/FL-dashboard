library(RMySQL)
library(plyr)
library(dplyr)
library(tidyr)
library(stringr)
library(reshape2)
library(lubridate)
library(syuzhet)
library(data.table)
library(eRm)

# The first argument is the path to the config file which includes the database connection information, java home address, and positive and negative word files.
# The second argument is the course name which usually is in <course_name>-<version> format.
# Next arguments are the raw datasets: team_members, comments, enrolments, step_activity and question_response, in this specific order.
# The rest of the arguments are the functions that are need to be run.
#
# Example to generate all the data required for all the visualisation:
#   Rscript preprocessing.R preprocessing_config.R through-engineers-eyes-3 team_members comments enrolments step_activity question_response vis_ActivityByStep vis_HoursSpendByWeek vis_LastProgressesByDate vis_LastProgressesByStep vis_LearnersActivities vis_LearnersActivitiesByDay vis_MinutesSpendByStep vis_StepProgressCountsHeatmap vis_NetworkAnalysisByStep vis_VisitedFirstStepFinishedAllSteps vis_AfinnSentimentAnalysisResult vis_BingSentimentAnalysisResult vis_CommentsHistogramByLearners vis_CommentsOverviewTable vis_CommentsStatsByStepRole vis_CommentsStatsDay vis_CommentsStatsDayType vis_CommentsStatsStep vis_CommentsStatsByEducators vis_OriginalSentimentAnalysisResult vis_WordCountAnalysisByRole vis_WordCountStatsByEducators vis_EnrolmentsByDay vis_EnrolmentsByWeek vis_AttemptToCorrect vis_FirstItemMap vis_LastItemMap vis_FirstPersonItemMap vis_LastPersonItemMap vis_QuestionResponseOverview vis_QuizAttempts vis_FirstRaschAnalysisSummary vis_LastRaschAnalysisSummary vis_VisitedOtherStepsDuringQuiz

myArgs <- commandArgs(trailingOnly = TRUE)


source(myArgs[1])
Sys.setenv(JAVA_HOME = java_home)
courseSlug = myArgs[2]

#-------------------------------------------------------
getDbConnect <- function(courseSlug)
{
  mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
  return(mydb)
}

#-------------------------------------------------------
findDBNameVersion <- function(courseSlug)
{
  db_version <- substr(courseSlug,rev(gregexpr("\\-", courseSlug)[[1]])[1]+1,nchar(courseSlug))
  db_name <- substr(courseSlug,1,rev(gregexpr("\\-", courseSlug)[[1]])[1]-1)
  result <- data.frame(database=character(0),version=character(0))
  result <- rbind(result, c(db_name,db_version))
  colnames(result) <- c("database","version")
  return(result)
}

#-------------------------------------------------------
getStartEndDatesByWeek <- function()
{
  db_detail = findDBNameVersion(courseSlug)
  query = paste("call ", db_name, ".find_start_dates_by_week('",db_detail$database,"','", db_detail$version ,"');",sep = "")
  mydb = getDbConnect(db_name)
  rs = dbSendQuery(mydb, query)
  startEndDatesByWeek = fetch(rs, n=-1)
  dbClearResult(rs)
  dbDisconnect(mydb)
  return(startEndDatesByWeek)
}

#-------------------------------------------------------
getStepTypeByCourse <- function()
{
  db_detail = findDBNameVersion(courseSlug)
  query = paste("call ", db_name, ".find_step_type_by_course('",db_detail$database,"','", db_detail$version ,"');",sep = "")
  mydb = getDbConnect(db_name)
  rs = dbSendQuery(mydb, query)
  stepTypeByCourse = fetch(rs, n=-1)
  dbClearResult(rs)
  dbDisconnect(mydb)
  return(stepTypeByCourse)
}

#-------------------------------------------------------
insertIntoLoggingTable <- function(message, table_name, courseSlug)
{
  course_details <- findDBNameVersion(courseSlug)
  query <- paste("CALL `insert_course_logging_table`('",course_details$database,"', "
                 ,course_details$version,", '', '",as.character(Sys.time()),"', '",message,"','",table_name,"');",sep = "")
  mydb = getDbConnect(db_name)
  rs = dbSendQuery(mydb, query)
  dbClearResult(rs)
  dbDisconnect(mydb)
}

insertIntoErrorLoggingTable <- function(message)
{
  query <- paste("CALL `insert_error_logging_table`('",as.character(Sys.time())
                 , "', '",message,"');",sep = "")
  mydb = getDbConnect(db_name)
  rs = dbSendQuery(mydb, query)
  dbClearResult(rs)
  dbDisconnect(mydb)
}

loadEnrolment <- function(){
  mydb = getDbConnect(courseSlug)
  rs = dbSendQuery(mydb, "select * from enrolments")
  enrolments <- fetch(rs, n=-1)
  dbClearResult(rs)
  dbDisconnect(mydb)
  
  enrolments$enrolled_at <- as.Date(enrolments$enrolled_at)
  enrolments$unenrolled_at <- as.Date(enrolments$unenrolled_at)
  return(enrolments)
}

loadComments <- function()
{
  mydb = getDbConnect(courseSlug)
  rs = dbSendQuery(mydb, "select * from comments")
  comments = fetch(rs, n=-1)
  dbClearResult(rs)
  dbDisconnect(mydb)
  
  comments$step <- factor(comments$step)
  
  steps <- as.data.frame(unique(comments$step))
  steps[,2:3] <- matrix(as.numeric(unlist(strsplit(as.character(steps[,1]), "[.]"))), ncol=2, byrow=TRUE)
  steps <- steps[with(steps,order(steps[,2],steps[,3])), ]
  steps[,1] <- ordered(steps[,1], levels=levels(steps[,1])[unclass(steps[,1])])
  stepOrder <- levels(steps[,1])
  
  comments$timestamp <- as.Date(comments$timestamp)
  comments$step <- factor(comments$step, levels = stepOrder)
  comments <- comments[order(comments$step),]
  # Source : http://stackoverflow.com/questions/8920145/count-the-number-of-words-in-a-string-in-r
  comments$wordCount <- sapply(gregexpr("[[:alpha:]]+", comments$text), function(x) sum(x > 0))
  
  stepTypes <- getStepTypeByCourse()
  stepTypes$step <- factor(stepTypes$step)
  
  combined <- sort(union(levels(comments$step), levels(stepTypes$step)))
  
  commentsWithType <- inner_join(mutate(comments, step=factor(step, levels=combined)), mutate(stepTypes, step=factor(step, levels=combined)), by = c("step" = "step"))
  
  return(commentsWithType)
}

loadStepActivity <- function()
{
  mydb = getDbConnect(courseSlug)
  rs = dbSendQuery(mydb, "select * from step_activity")
  stepActivity = fetch(rs, n=-1)
  dbClearResult(rs)
  dbDisconnect(mydb)
  
  stepTypes <- getStepTypeByCourse()
  
  stepActivity <- inner_join(stepActivity,stepTypes,by = c("step" = "step"))
  
  
  stepActivity$step <- factor(stepActivity$step)
  # We need to construct an ordered list of the steps to use as the levels for
  # other data frames.
  # The most logical way is to take the list of unique steps referenced in step activity.
  steps <- as.data.frame(unique(stepActivity$step))
  steps[,2:3] <- matrix(as.numeric(unlist(strsplit(as.character(steps[,1]), "[.]"))), ncol=2, byrow=TRUE)
  steps <- steps[with(steps,order(steps[,2],steps[,3])), ]
  steps[,1] <- ordered(steps[,1], levels=levels(steps[,1])[unclass(steps[,1])])
  stepOrder <- levels(steps[,1])
  
  stepActivity$step <- factor(stepActivity$step, levels = stepOrder)
  stepActivity <- stepActivity[order(stepActivity$step),] 
  
  
  return(stepActivity)
}

loadLearnersStepActivity <- function()
{
  activityWithRole <-subset(stepActivity,! learner_id %in% team.members$id)
  return(subset(activityWithRole, select = c("learner_id","step","week_number","first_visited_at","last_completed_at")))
}

loadQuestionResponce <- function()
{
  mydb = getDbConnect(courseSlug)
  rs = dbSendQuery(mydb, "select * from question_response")
  questionResponse = fetch(rs, n=-1)
  dbClearResult(rs)
  dbDisconnect(mydb)
  
  if (exists("questionResponse")) {
    questionResponse$correct <- as.logical(questionResponse$correct)
    questionResponse$quiz_question <- factor(questionResponse$quiz_question)
  }
  
  return(questionResponse)
}

insertEnrolmentsByDayToDb <- function()
{
  table_name = "vis_EnrolmentsByDay"
  
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    enrolments <- subset(enrolments, !learner_id %in% team.members$id)
    t <- ddply(enrolments,.(enrolled_at),summarise,freq = n())
    enrolmentsByDay <- mutate(t,cum = cumsum(freq)) 
    
    # Set old class to avoid this error which is from dplyr package:
    #   Error in (function (classes, fdef, mtable)  : 
    #   unable to find an inherited method for function 'dbWriteTable' for signature '"MySQLConnection", "character", "tbl_df"'
    setOldClass(c("tbl_df", "data.frame")) 
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = enrolmentsByDay, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(enrolled_at = "date",freq = "int",cum = "int")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertEnrolmentsByWeekToDb <- function()
{
  table_name = "vis_EnrolmentsByWeek"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    # Find all learners that enrolled
    enrolments <- subset(enrolments, !learner_id %in% team.members$id)
    
    # Find the start and end date of each week that the course was running
    #startEndDatesByWeek <- getStartEndDatesByWeek(courseSlug)
    
    # Do an inner join between two dataframes to find the week number of enrolment day.
    mergedf <- merge(enrolments, startEndDatesByWeek)
    mergedf <- mergedf[(mergedf$enrolled_at >= mergedf$start_date & 
                          mergedf$enrolled_at <= mergedf$end_date),]
    mergedf <- mergedf[c('week_number', 'learner_id')]
    
    t <- ddply(mergedf,.(week_number),summarise,freq = n())
    # If no data existed, the following error will be raised:
    # Got an error at vis_EnrolmentsByWeek in remaking-nature-2. Error: object freq not found
    # So I added the condition:
    if(nrow(t) == 0)
      t <- cbind(t,data.frame(freq=integer(0)))
    
    EnrolmentsByWeek <- mutate(t,cum = cumsum(freq)) 
    
    # Set old class to avoid this error which is from dplyr package:
    #   Error in (function (classes, fdef, mtable)  : 
    #   unable to find an inherited method for function 'dbWriteTable' for signature '"MySQLConnection", "character", "tbl_df"'
    setOldClass(c("tbl_df", "data.frame")) 
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = EnrolmentsByWeek, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(week_number = "smallint",freq = "int",cum = "int")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}


insertActivityByStepToDb <- function()
{
  table_name = "vis_ActivityByStep"
  
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    stepSummary <- ddply(stepActivity,.(step),summarise, completions = sum(!is.na(last_completed_at)), views = n() - completions)
    
    flt <- dplyr::filter(stepActivity,!is.na(last_completed_at))
    mt <- dplyr::mutate(flt,
                        delta = as.numeric(
                          difftime(last_completed_at,first_visited_at, units="mins"
                          )
                        )
    )
    #completedSteps <- filter(mt, delta > 0 & delta < 180)
    
    commentsSummary <- ddply(comments,.(step), summarise, comments = n(), likes = sum(as.numeric(likes)))
    
    sum <- ddply(mt,.(step), summarise, deltaMean = round(mean(delta),2), deltaSD = round(sd(delta),2))
    lj <- left_join(sum,stepSummary, by=c("step" = "step"))
    stepSummary <-  left_join(lj,commentsSummary, by=c("step" = "step"))
    
    stepSummary$views <- stepSummary$views + stepSummary$completions
    
    colnames(stepSummary) <- c("Step","Mean Completion (mins)","SD Completion (mins)", "Completions", "Visits", "Comments", "Likes")
    
    ActivityByStep <- stepSummary[ ,c(1,4:7,2:3)]
    
    ActivityByStep$Comments[is.na(ActivityByStep$Comments)] <- 0
    ActivityByStep$Likes[is.na(ActivityByStep$Likes)] <- 0
    
    # Set old class to avoid this error which is from dplyr package:
    #   Error in (function (classes, fdef, mtable)  :
    #   unable to find an inherited method for function 'dbWriteTable' for signature '"MySQLConnection", "character", "tbl_df"'
    setOldClass(c("tbl_df", "data.frame"))
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = ActivityByStep, overwrite = TRUE, row.names = FALSE ,
                 field.types = list(Step = "varchar(5)",Completions = "bigint",Visits = "bigint"
                                    ,Comments = "bigint",Likes = "bigint",`Mean Completion (mins)` = "double",`SD Completion (mins)` = "double"))
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
    
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
  
}


#active learners are those (of any role) who have completed at least one step at anytime
#in any course week, including those who go on to leave the course.
activeLearnersByWeek <- function(){
  flt <- filter(stepActivity, !is.na(last_completed_at))
  result <- ddply(flt, .(week_number),summarise,
                  activeLearners = (length(unique(learner_id)))
  )
  return(result)
}

#Learners are users (of any role) who have at least viewed at least one step at anytime in any course week. 
#This includes those who go on to leave the course. This is also presented as a percentage of joiners.
learnersByWeek <- function(){
  result <- ddply(stepActivity,.(week_number) ,summarise,learners = (length(unique(learner_id))))
  return(result)
}

#Returning Learners are those who completed at least a step in at least two distinct course weeks. 
#These do not have to be sequential or consecutive, nor completed in different calendar weeks. 
#This is also presented as a percentage of learners.
returningLearnersByWeek <- function()
{
  uniqueLearnerIdsWeek <- stepActivity[ ! duplicated( stepActivity[ c("learner_id","week_number") ] ) , ]
  uniqueLearnerIdsWeek <- ddply(uniqueLearnerIdsWeek,.(learner_id),transform,rank = rank(week_number,ties.method = "min")) 
  uniqueLearnerIdsWeek <- filter(uniqueLearnerIdsWeek,rank>1)
  uniqueLearnerIdsWeek<- ddply(uniqueLearnerIdsWeek, .(learner_id), summarise, week_number=min(week_number))
  result <- ddply(uniqueLearnerIdsWeek, .(week_number), summarise, returningLearners=length(unique(learner_id)))
  return(result)
}

#Social Learners are those (of any role) who have posted at least one comment on any step.   
#This is also presented as a percentage of learners.
socialLearnersByWeek <- function()
{
  result <- ddply(comments,.(week_number),summarise,
                  socialLearners = (length(unique(author_id)))
  )
  return(result)
}

insertLearnersActivitiesToDb <- function()
{
  
  table_name = "vis_LearnersActivities"
  
  tryCatch({  
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    list_df <- list(activeLearnersByWeek(),learnersByWeek(),
                    socialLearnersByWeek(),returningLearnersByWeek())
    finalResult <- Reduce(dplyr::left_join,list_df)
    finalResult$week_number <- as.character(finalResult$week_number)
    tmp_m = melt(finalResult, id = "week_number")
    tmp_m$variable <- ifelse(tmp_m$variable == "activeLearners", "Active Learners", 
                             ifelse(tmp_m$variable == "learners", "Learners",
                                    ifelse(tmp_m$variable == "socialLearners", "Social Learners",
                                           ifelse(tmp_m$variable == "returningLearners", "Returning Learners",""))))
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = tmp_m, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(week_number = "int",variable = "varchar(25)",value = "bigint")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

#active learners are those (of any role) who have completed at least one step at anytime
#in any course week, including those who go on to leave the course.
activeLearnersByDay <- function(){
  stepActivity <- learnersStepActivity
  stepActivity$first_visited_at <- as.Date(stepActivity$first_visited_at)
  flt <- filter(stepActivity, !is.na(last_completed_at))
  result <- ddply(flt, .(first_visited_at), summarise,
                  activeLearners = (length(unique(learner_id)))
  )
  return(result)
}

#Learners are users (of any role) who have at least viewed at least one step at anytime in any course week. 
#This includes those who go on to leave the course. This is also presented as a percentage of joiners.
learnersByDay <- function(){
  stepActivity <- learnersStepActivity
  stepActivity$first_visited_at <- as.Date(stepActivity$first_visited_at)
  result <- ddply(stepActivity,.(first_visited_at), summarise,learners = (length(unique(learner_id))))
  return(result)
}

#Returning Learners are those who completed at least a step in at least two distinct course weeks. 
#These do not have to be sequential or consecutive, nor completed in different calendar weeks. 
#This is also presented as a percentage of learners.
returningLearnersByDay <- function()
{
  stepActivity <- learnersStepActivity
  stepActivity$first_visited_at <- as.Date(stepActivity$first_visited_at)
  uniqueLearnerIdsDay <- stepActivity[ ! duplicated( stepActivity[ c("learner_id","first_visited_at") ] ) , ]
  uniqueLearnerIdsDay <- ddply(uniqueLearnerIdsDay,.(learner_id),transform,rank = rank(first_visited_at,ties.method = "min")) 
  uniqueLearnerIdsDay <- filter(uniqueLearnerIdsDay,rank>1)
  uniqueLearnerIdsDay<- ddply(uniqueLearnerIdsDay, .(learner_id), summarise, first_visited_at=min(first_visited_at))
  result <- ddply(uniqueLearnerIdsDay, .(first_visited_at), summarise, returningLearners=length(unique(learner_id)))
  return(result)
}

#Social Learners are those (of any role) who have posted at least one comment on any step.   
#This is also presented as a percentage of learners.
socialLearnersByDay <- function()
{
  result <- ddply(comments,.(timestamp),summarise,
                  socialLearners = (length(unique(author_id)))
  )
  colnames(result) <- c("first_visited_at","socialLearners")
  return(result)
}

insertLearnersActivitiesByDayToDb <- function()
{
  table_name = "vis_LearnersActivitiesByDay"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    list_df <- list(activeLearnersByDay(),learnersByDay(),
                    socialLearnersByDay(),returningLearnersByDay())
    finalResult <- Reduce(dplyr::left_join,list_df)
    finalResult$first_visited_at <- as.character(finalResult$first_visited_at)
    tmp_m = melt(finalResult, id = "first_visited_at")
    tmp_m$variable <- ifelse(tmp_m$variable == "activeLearners", "Active Learners", 
                             ifelse(tmp_m$variable == "learners", "Learners",
                                    ifelse(tmp_m$variable == "socialLearners", "Social Learners",
                                           ifelse(tmp_m$variable == "returningLearners", "Returning Learners",""))))
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = tmp_m, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(first_visited_at = "date",variable = "varchar(25)",value = "bigint")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}


insertLastProgressesByStepToDb <- function(){
  table_name = "vis_LastProgressesByStep"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    gb <- group_by(learnersStepActivity,learner_id, step)
    mut <- mutate(gb,last_interaction_at = sort(c(last_completed_at, first_visited_at), decreasing = TRUE, na.last = NA)[1])
    gb <- group_by(mut,learner_id)
    arr <- arrange(gb,desc(last_interaction_at))
    sli <- slice(arr,1)
    ungb <- ungroup(sli)
    LastProgressesByStep <- ddply(ungb,.(step), summarise,freq = n())
    
    # Computing the number of remainder student at each step
    # If a student visited step also visited any other step after that,
    # the student is counted as remained for the step.
    steps <- unique(LastProgressesByStep$step)
    remained <- data.frame(step=character(0),remained=integer(0))
    for(step in steps)
    {
      visisted.step <- learnersStepActivity[learnersStepActivity$step == step, ]
      visited.again <- data.frame(learner_id=character(0),visited_again=character(0))
      for(i in visisted.step$learner_id)
      {
        if(is.na(i))
          next
        
        first_visited_at <- visisted.step[which(visisted.step$learner_id == i), ]$first_visited_at
        # There was an error for remaking-nature-1 where the first_visited_at vale for a learner was NA
        # So here I filter out this case from the dataset, otherwise the error below will be raised:
        #   Got an error at vis_LastProgressesByStep in remaking-nature-1. Error: missing value where TRUE/FALSE needed
        if(is.na(first_visited_at))
          next
        
        all.dates <- learnersStepActivity[learnersStepActivity$learner_id == i, ]$first_visited_at
        
        visited = sum(all.dates > first_visited_at  )
        if(visited > 0 )
        {
          visited.again <- rbind(visited.again,data.frame(learner_id=i,visited_again='Yes'))
        }
        else
        {
          visited.again <- rbind(visited.again,data.frame(learner_id=i,visited_again='No'))
        }
      }
      visisted.step <- inner_join(visisted.step,visited.again,by='learner_id')
      remained <- rbind(remained, data.frame(step=step,remained=nrow(subset(visisted.step,visited_again=='Yes'))))
    }
    
    LastProgressesByStep <- inner_join(LastProgressesByStep,remained,by='step')
    
    # Set old class to avoid this error which is from dplyr package:
    #   Error in (function (classes, fdef, mtable)  :
    #   unable to find an inherited method for function 'dbWriteTable' for signature '"MySQLConnection", "character", "tbl_df"'
    setOldClass(c("tbl_df", "data.frame"))
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = LastProgressesByStep, overwrite = TRUE, row.names = FALSE ,
                 field.types = list(step = "varchar(5)",freq = "bigint",remained='bigint'))
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertLastProgressesByDateToDb <- function(){
  table_name = "vis_LastProgressesByDate"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    gb <- group_by(learnersStepActivity,learner_id, step)
    mut <- mutate(gb,last_interaction_at = 
                    sort(c(last_completed_at, first_visited_at), decreasing = TRUE, na.last = NA)[1])
    gb <- group_by(mut,learner_id) 
    arr <- arrange(gb,desc(last_interaction_at))
    sli <- slice(arr,1) 
    ungb <- ungroup(sli) 
    mut <- mutate(ungb,
                  last_interaction_at = as.Date(last_interaction_at))
    
    gb <- group_by(mut,last_interaction_at) 
    
    # It is possible that the last day any learner disengaged from the course,
    # (s)he has been finished the course before that date.
    # So the FullyParticipated will be added to show how many learners fully participated in the course.
    tmp <- merge(mut,enrolments,by=c("learner_id"="learner_id"))
    tmp$fully_participated_at <- as.Date(tmp$fully_participated_at)
    tmp <- subset(tmp,fully_participated_at<=last_interaction_at)
    FullyParticipatedByDate <- ddply(tmp,.(last_interaction_at), summarise,FullyParticipated = n())
    
    LastProgressesByDate <- summarise(gb,freq = n())
    # If no one yet marked as the fully participated then it raise the following error
    # Got an error at vis_LastProgressesByDate in remaking-nature-2. Error: origin must be supplied
    # I fixed it with a condition added:
    if(nrow(FullyParticipatedByDate) > 0)
    {
      ByDate <- left_join(LastProgressesByDate,FullyParticipatedByDate,by=c("last_interaction_at"="last_interaction_at"))
      ByDate <- replace(ByDate, is.na(ByDate), 0)
    }    else
    { LastProgressesByDate$FullyParticipated <- 0
    ByDate <- LastProgressesByDate}
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = ByDate, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(last_interaction_at = "date",freq = "bigint",FullyParticipated="bigint")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertHoursSpendByWeekToDb <- function()
{
  table_name = "vis_HoursSpendByWeek"
  
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    # Hours is not rounded, they used the int part of the decimal number.
    flt <- filter(stepActivity,!is.na(last_completed_at))
    mut <- mutate(flt,
                  delta = as.numeric(
                    difftime(strptime(last_completed_at,"%Y-%m-%d %H:%M:%S"), strptime(first_visited_at,"%Y-%m-%d %H:%M:%S"), units="mins")
                  )
    )
    mut <- subset(mut,!is.na(delta))
    
    #mut <- filter(mut,delta > 0 & delta < 180)
    weekCompletion <- ddply(mut,.(learner_id, week_number),summarise,hours = round(sum(delta) / 60,2))
    
    breaks=c(-1,1,2,5,10,20,100000)
    labels=c("less than 1", "1-2", "2-5", "5-10", '10-20', "20+")
    
    melted <- melt(weekCompletion, na.rm = TRUE, value.name = "hours", id.vars=c("week_number"), measure.vars=c("hours"))
    melted$hours <- cut(melted$hours, breaks=breaks, labels=labels);
    bucketed <- ddply(melted,.(week_number, hours),summarise,freq = n());
    # We have to fill the gaps in the dataframe. Since this data is going to group by hours, if there is no 
    # corresponding row for each week_number and any hours, the graph shift the data to left to fill the gap by itself.
    # Then at the end of axis, there are empty bars.
    # So the following will find all missing hours for each week_number, and put 0 for each attribute column.
    uniqueWeeks <- unique(bucketed$week_number);
    uniquehours <- unique(bucketed$hours);
    tmp <- merge(uniquehours,uniqueWeeks);
    tmp <- tmp[ ,c(2,1)];
    colnames(tmp) <- c("week_number","hours");
    tmp <- left_join(tmp,bucketed,by=c("week_number"="week_number","hours"="hours"),all.y=TRUE)
    tmp <- replace(tmp, is.na(tmp), 0)
    # Set old class to avoid this error which is from dplyr package:
    #   Error in (function (classes, fdef, mtable)  : 
    #   unable to find an inherited method for function 'dbWriteTable' for signature '"MySQLConnection", "character", "grouped_df"'
    setOldClass(c("grouped_df", "data.frame")) ;
    
    mydb = getDbConnect(courseSlug);
    dbWriteTable(mydb,  name = table_name, value = tmp, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(week_number = "int", hours = "varchar(20)",freq = "bigint")) 
    dbDisconnect(mydb);
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
    
  },error=function(e){
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertStepProgressCountsHeatmapToDb <- function()
{
  table_name = "vis_StepProgressCountsHeatmap"
  
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    flt <- filter(stepActivity,!is.na(last_completed_at))
    mut <- mutate(flt, last_completed_at = as.Date(last_completed_at))
    stepProgressCounts <- ddply(mut,.(step, last_completed_at), summarise, freq = n())
    
    stepProgressCounts <- subset(stepProgressCounts, last_completed_at > startEndDatesByWeek$start_date[1])
    
    # Set old class to avoid this error which is from dplyr package:
    #   Error in (function (classes, fdef, mtable)  : 
    #   unable to find an inherited method for function 'dbWriteTable' for signature '"MySQLConnection", "character", "grouped_df"'
    setOldClass(c("grouped_df", "data.frame")) 
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = stepProgressCounts, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(step = "varchar(5)", last_completed_at = "date",freq = "bigint")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

# insertStepProgressCountsHeatmapByWeekToDb <- function()
# {
#   table_name = "vis_StepProgressCountsHeatmapByWeek"
#   
#   tryCatch({
#     insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
#     
#     flt <- filter(stepActivity,!is.na(last_completed_at))
#     mut <- mutate(flt, last_completed_at = as.Date(last_completed_at))
#     stepProgressCounts <-  ddply(mut, .(step,last_completed_at),dplyr::summarise, freq = n())
#     
#     stepProgressCounts <- subset(stepProgressCounts, last_completed_at > startEndDatesByWeek$start_date[1])
#     
#     mergedf <- merge(stepProgressCounts, startEndDatesByWeek)
#     mergedf <- mergedf[(mergedf$last_completed_at >= mergedf$start_date & 
#                           mergedf$last_completed_at <= mergedf$end_date),]
#     mergedf <- mergedf[c('step','week_number','freq')]
#     
#     stepProgressCounts <- ddply(mergedf, .(step,week_number),summarise,freq = sum(freq)) 
#     
#     # Fill the gaps in the data frame
#     uniqueSteps <- unique(stepProgressCounts$step)
#     uniqueWeeks <- unique(stepProgressCounts$week_number)
#     tmp <- merge(uniqueWeeks,uniqueSteps)
#     tmp <- tmp[ ,c(2,1)]
#     colnames(tmp) <- c("step","week_number")
#     tmp <- left_join(tmp,stepProgressCounts,by=c("step"="step","week_number"="week_number"),all.y=TRUE)
#     tmp <- replace(tmp, is.na(tmp), 0)
#     #levels(tmp$step) <- unique(tmp$step)
#     
#     # Sort the data frame based on week and step
#     tmp[,4:5] <- matrix(as.numeric(unlist(strsplit(as.character(tmp[,1]), "[.]"))), ncol=2, byrow=TRUE)
#     tmp <- tmp[with(tmp,order(tmp[,2],tmp[,4],tmp[,5])), ]
#     tmp$V4 <- NULL 
#     tmp$V5 <- NULL 
#     
#     # Set old class to avoid this error which is from dplyr package:
#     #   Error in (function (classes, fdef, mtable)  : 
#     #   unable to find an inherited method for function 'dbWriteTable' for signature '"MySQLConnection", "character", "grouped_df"'
#     setOldClass(c("grouped_df", "data.frame")) 
#     
#     mydb = getDbConnect(courseSlug)
#     dbWriteTable(mydb, name = table_name, value = tmp, overwrite = TRUE, row.names = FALSE , 
#                  field.types = list(step = "varchar(5)", week_number = "int",freq = "bigint")) 
#     dbDisconnect(mydb)
#     
#     insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
#   }, error=function(e)
#   { 
#     #error handling code, maybe just skip this iteration using
#     msg <- gsub("'",'',conditionMessage(e))
#     message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
#     insertIntoErrorLoggingTable(message)
#   })
# }

# insertCommentsCountHeatmapToDb <- function()
# {
#   table_name = "vis_CommentsCountHeatmap"
#   tryCatch({
#     insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
#     
#     commentsCounts <- ddply(comments, .(step, timestamp), summarise, freq = n())
#     # Consider comments given during the course is active
#     commentsCounts <- subset(commentsCounts, timestamp > startEndDatesByWeek$start_date[1])
#     commentsCounts <- subset(commentsCounts, timestamp < startEndDatesByWeek$start_date[length(startEndDatesByWeek$start_date)])
#     
#     # Set old class to avoid this error which is from dplyr package:
#     #   Error in (function (classes, fdef, mtable)  : 
#     #   unable to find an inherited method for function 'dbWriteTable' for signature '"MySQLConnection", "character", "grouped_df"'
#     setOldClass(c("grouped_df", "data.frame")) 
#     
#     mydb = getDbConnect(courseSlug)
#     dbWriteTable(mydb, name = table_name, value = commentsCounts, overwrite = TRUE, row.names = FALSE , 
#                  field.types = list(step = "varchar(5)", timestamp = "date",freq = "bigint")) 
#     dbDisconnect(mydb)
#     
#     insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
#   }, error=function(e)
#   { 
#     #error handling code, maybe just skip this iteration using
#     msg <- gsub("'",'',conditionMessage(e))
#     message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
#     insertIntoErrorLoggingTable(message)
#   })
# }

insertCommentsOverviewTableToDb <- function()
{
  table_name = "vis_CommentsOverviewTable"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    overview <- data.frame(stat_type = "Total comments", value = length(comments$id))
    overview <- rbind(overview, data.frame(stat_type = "Total Likes", value = sum(as.numeric(comments$likes)) ))
    
    overview <- rbind(overview, data.frame(stat_type = "Unique authors", value = length(unique(comments$author_id))))
    overview <- rbind(overview, data.frame(stat_type = "Median word count per comment", value = round(median(comments$wordCount))))
    overview <- rbind(overview, data.frame(stat_type = "Average word count per comment", value = round(mean(comments$wordCount))))
    
    WordCountByPerson <- ddply(comments, .(author_id), summarise,mean = sum(wordCount)/n())
    
    overview <- rbind(overview, data.frame(stat_type = "Median word count per person", value = round(median(WordCountByPerson$mean) )))
    overview <- rbind(overview, data.frame(stat_type = "Average word count per person", value = round(mean(WordCountByPerson$mean))))
    
    parents <- ddply(comments,.(parent_id),summarise, freq = n())
    parents <- na.omit(parents, cols = "parent_id")
    totalComments <- nrow(comments)
    
    overview <- rbind(overview, data.frame(stat_type = "Average number of reply per comment", value = sum(parents$freq)/ totalComments))
    overview <- rbind(overview, data.frame(stat_type = "Maximum number of reply for a comment", value = max(parents$freq)))
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = overview, overwrite = TRUE, row.names = FALSE ,
                 field.types = list(stat_type = "varchar(50)", value = "bigint"))
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertCommentsStatsStepToDb <- function()
{
  table_name = "vis_CommentsStatsStep"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    temp <- comments 
    # Consider comments given during the course is active
    temp <- subset(temp, timestamp >= startEndDatesByWeek$start_date[1])
    temp <- subset(temp, timestamp <= startEndDatesByWeek$start_date[length(startEndDatesByWeek$start_date)])
    
    commentsByStep <- ddply(temp, .(step), summarise, freq_comment = n(), likes = sum(as.numeric(likes)))
    
    commentsByStep[,4:5] <- matrix(as.numeric(unlist(strsplit(as.character(commentsByStep$step), split = "[.]"))), ncol=2, byrow=TRUE)
    commentsByStep <- commentsByStep[with(commentsByStep,order(commentsByStep$V4,commentsByStep$V5)), ]
    commentsByStep[,4:5] <- list(NULL)
    
    # Set old class to avoid this error which is from dplyr package:
    #   Error in (function (classes, fdef, mtable)  :
    #   unable to find an inherited method for function 'dbWriteTable' for signature '"MySQLConnection", "character", "tbl_df"'
    setOldClass(c("tbl_df", "data.frame"))
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = commentsByStep, overwrite = TRUE, row.names = FALSE ,
                 field.types = list(step = "varchar(5)", freq_comment = "bigint", likes = "bigint"))
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertCommentsStatsDayToDb <- function()
{
  table_name = "vis_CommentsStatsDay"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    finalResult <- ddply(comments,.(timestamp),summarise,freq_comment = n(), likes = sum(as.numeric(likes)))
    # Consider comments given during the course is active
    # finalResult <- subset(finalResult, timestamp > startEndDatesByWeek$start_date[1])
    # finalResult <- subset(finalResult, timestamp < startEndDatesByWeek$start_date[length(startEndDatesByWeek$start_date)])
    
    # Set old class to avoid this error which is from dplyr package:
    #   Error in (function (classes, fdef, mtable)  :
    #   unable to find an inherited method for function 'dbWriteTable' for signature '"MySQLConnection", "character", "tbl_df"'
    setOldClass(c("tbl_df", "data.frame"))
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = finalResult, overwrite = TRUE, row.names = FALSE ,
                 field.types = list(timestamp = "date", freq_comment = "bigint", likes = "bigint"))
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertCommentsStatsDayTypeToDb <- function()
{
  table_name = "vis_CommentsStatsDayType"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    finalResult <- ddply(comments,.(timestamp,type), summarise, freq_comment = n(), likes = sum(as.numeric(likes)))
    # Consider comments given during the course is active
    # finalResult <- subset(finalResult, timestamp > startEndDatesByWeek$start_date[1])
    # finalResult <- subset(finalResult, timestamp < startEndDatesByWeek$start_date[length(startEndDatesByWeek$start_date)])
    
    # Set old class to avoid this error which is from dplyr package:
    #   Error in (function (classes, fdef, mtable)  : 
    #   unable to find an inherited method for function 'dbWriteTable' for signature '"MySQLConnection", "character", "grouped_df"'
    setOldClass(c("grouped_df", "data.frame")) 
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = finalResult, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(timestamp = "date",type = "varchar(10)", freq_comment = "bigint", likes = "bigint")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

score.sentiment = function(sentences,method)
{
  # Anonymous function
  # Parameters
  # sentences: vector of text to score
  # method: the sentiment analysis method name, i.e. "afinn", "bing", "nrc", "stanford"
  func <- function(sentence,method)
  {
    # remove html tags
    sentence = gsub("<.*?>", "", sentence)
    # remove punctuation
    sentence = gsub("[[:punct:]]", " ", sentence)
    # remove control characters
    sentence = gsub("[[:cntrl:]]", "", sentence)
    # remove digits?
    #sentence = gsub('\\d+', '', sentence)
    # remove numbers
    sentence = gsub("[[:digit:]]", "", sentence)
    # remove html links
    sentence = gsub("http\\w+", "", sentence)
    # remove unnecessary spaces
    sentence = gsub("[ \t]{2,}", "", sentence)
    #sentence = gsub("^\\s+|\\s+$", "", sentence)
    
    # define error handling function when trying tolower
    tryTolower = function(x)
    {
      # create missing value
      y = NA
      # tryCatch error
      try_error = tryCatch(tolower(x), error=function(e) e)
      # if not an error
      if (!inherits(try_error, "error"))
        y = tolower(x)
      # result
      return(y)
    }
    # use tryTolower with sapply
    sentence = sapply(sentence, tryTolower)
    
    # remove NAs in some_txt
    sentence = sentence[!is.na(sentence)]
    names(sentence) = NULL
    
    s_v <- get_sentences(sentence)
    sentiment_vector <- get_sentiment(s_v, method=method)
    
    return(sentiment_vector)
  }
  
  # Create a new dataframe consisting of two columns, id and score, both of type numeric.
  # This is the output of the function.
  scores = data.frame(id = numeric, score = numeric);
  
  # Run sentiment analysis on each comment and update the output dataframe.
  for (s in 1:nrow(sentences))   {
    # Run sentiment analyis for this comment
    score = func(sentences$text[s],method)
    
    # Update the output dataframe with the score
    # scores = rbind(scores,c(sentences$id[s],score))
    temp.df <- data.frame(sentences$id[s],score)
    names(temp.df) <- c("id", "score")
    scores <- rbind(scores, temp.df)
  }
  
  return(scores)
}

matches.word.df = data.frame(id=character(0),word=character(0),flag=integer(0))
getScore.orig <- function(id,sentence, pos.words, neg.words)
{
  # remove html tags
  sentence = gsub("<.*?>", "", sentence)
  # remove punctuation
  sentence = gsub("[[:punct:]]", " ", sentence)
  # remove control characters
  sentence = gsub("[[:cntrl:]]", "", sentence)
  # remove digits?
  #sentence = gsub('\\d+', '', sentence)
  # remove numbers
  sentence = gsub("[[:digit:]]", "", sentence)
  # remove html links
  sentence = gsub("http\\w+", "", sentence)
  # remove unnecessary spaces
  sentence = gsub("[ \t]{2,}", "", sentence)
  #sentence = gsub("^\\s+|\\s+$", "", sentence)
  
  # define error handling function when trying tolower
  tryTolower = function(x)
  {
    # create missing value
    y = NA
    # tryCatch error
    try_error = tryCatch(tolower(x), error=function(e) e)
    # if not an error
    if (!inherits(try_error, "error"))
      y = tolower(x)
    # result
    return(y)
  }
  # use tryTolower with sapply
  sentence = sapply(sentence, tryTolower)
  
  # split sentence into words with str_split (stringr package)
  word.list = str_split(sentence, "\\s+")
  words = unlist(word.list)
  
  # compare words to the dictionaries of positive & negative terms
  pos.matches = match(words, pos.words)
  neg.matches = match(words, neg.words)
  
  pos.matches.word <- pos.words[pos.matches]
  pos.matches.word =  pos.matches.word[!is.na( pos.matches.word)]
  
  neg.matches.word <- neg.words[neg.matches]
  neg.matches.word =  neg.matches.word[!is.na( neg.matches.word)]
  
  
  # get the position of the matched term or NA
  # we just want a TRUE/FALSE
  pos.matches = !is.na(pos.matches)
  neg.matches = !is.na(neg.matches)
  
  # final score
  score = sum(pos.matches) - sum(neg.matches)
  
  if(length(pos.matches.word) > 0)
  {  
    pos.matches.word =  unique(pos.matches.word)
    for(i in 1:length(pos.matches.word))
    {  matches.word.df <<- rbind(matches.word.df,data.frame(id=id,
                                                            word=pos.matches.word[i],flag=1))
    }
  }
  if(length(neg.matches.word) > 0)
  {
    neg.matches.word =  unique(neg.matches.word)
    for(i in 1:length(neg.matches.word))
    {  matches.word.df <<- rbind(matches.word.df,data.frame(id=id,
                                                            word=neg.matches.word[i],flag=0))
    }
  }
  return(score)
}

score.sentiment.orig = function(sentences, pos.words, neg.words, .progress='none')
{
  # Parameters
  # sentences: vector of text to score
  # pos.words: vector of words of postive sentiment
  # neg.words: vector of words of negative sentiment
  # .progress: passed to laply() to control of progress bar
  
  matches.word.df <<- data.frame(id=character(0),word=character(0),flag=integer(0))
  
  # create simple array of scores with laply
  scores = c()
  for(i in 1:nrow(sentences))
  {
    score = getScore.orig(sentences$id[i],sentences$text[i],
                          pos.words, neg.words)
    scores <- c(scores, score)
  }
  
  table_name = "vis_WordCloudOfOriginalSentimentAnalysis"
  insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
  
  mydb = getDbConnect(courseSlug)
  dbWriteTable(mydb, name = table_name, value = matches.word.df, overwrite = TRUE, row.names = FALSE , 
               field.types = list(id = "bigint", 
                                  word = "varchar(100)", flag="int" )) 
  dbDisconnect(mydb)
  
  insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  
  # data frame with scores for each sentence
  scores.df = data.frame(id=sentences$id,step = sentences$step, score=scores, 
                         likes = sentences$likes, wordCount= sentences$wordCount, 
                         author_id=sentences$author_id, text= sentences$text)
  return(scores.df)
}

insertBingSentimentAnalysisResultToDb <- function()
{
  table_name = "vis_BingSentimentAnalysisResult"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    method = "bing"
    scores_bing = score.sentiment(comments,method)
    colnames(scores_bing) <- c("id","score")
    scores_bing$step <- comments$step
    if(nrow(scores_bing[scores_bing$id==scores_bing$score,]) > 0 )
    {
      scores_bing[scores_bing$id==scores_bing$score,]$score = 0
    }
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = scores_bing, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(id = "bigint", score = "int", step = "varchar(5)")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertAfinnSentimentAnalysisResultToDb <- function()
{
  table_name = "vis_AfinnSentimentAnalysisResult"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    method = "afinn"
    scores_afinn = score.sentiment(comments,method)
    # colnames(scores_afinn) <- c("id","score")
    scores_afinn$step <- comments$step
    
    if(nrow(scores_afinn[scores_afinn$id==scores_afinn$score,]) > 0)
    {
      scores_afinn[ scores_afinn$id == scores_afinn$score,]$score = 0
    }
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = scores_afinn, overwrite = TRUE, row.names = FALSE ,
                 field.types = list(id = "bigint", score = "int", step = "varchar(5)"))
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertOriginalSentimentAnalysisResultToDb <- function()
{
  table_name = "vis_OriginalSentimentAnalysisResult"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    method = "orig"
    
    pos = readLines(pos_file)
    neg = readLines(neg_file)
    scores_orig = score.sentiment.orig(comments, pos, neg)
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = scores_orig, overwrite = TRUE, row.names = FALSE ,
                 field.types = list(id = "bigint", step = "varchar(5)", score = "int", likes = "int", wordCount = "int", author_id = "varchar(36)", text = "text"))
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  {
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertQuestionResponseOverviewToDb <- function(){
  table_name = "vis_QuestionResponseOverview"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    
    attempts <- data.table(questionResponse)
    attempts <- attempts[order(-rank(learner_id), quiz_question, submitted_at)]
    attempts <- attempts[, attempt := 1:.N, by=c("learner_id", "quiz_question")]
    
    correctAttempts <- attempts[attempts$correct == TRUE, ]
    correctAttempts$step <- gsub(".\\d$","", correctAttempts$quiz_question)
    correctAttempts <- ddply(correctAttempts,.(learner_id,quiz_question,step),summarise, attempt = max(attempt))
    correctAttempts <- filter(correctAttempts,!is.na(learner_id))
    
    numberOfSteps <- length(unique(correctAttempts$step))
    
    newdf1 <- ddply(correctAttempts,.(learner_id,step),summarise, score=length(quiz_question)/sum(attempt))
    totalScoresByLearner <- ddply(newdf1,.(learner_id),summarise, totalScore=round(sum(score),2))
    totalScoresByLearner$totalPercentage <-  round(totalScoresByLearner$totalScore/numberOfSteps,2)
    
    # Set old class to avoid this error which is from dplyr package:
    #   Error in (function (classes, fdef, mtable)  : 
    #   unable to find an inherited method for function 'dbWriteTable' for signature '"MySQLConnection", "character", "tbl_dt"'
    setOldClass(c("tbl_dt", "data.frame")) 
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = totalScoresByLearner, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(learner_id = "varchar(36)", totalScore = "double", totalPercentage = "double")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

getRaschMatrix <- function()
{
  tmp <- questionResponse
  # We can have an option to create the Rasch model based on the first student attempt or the last one
  # In the current report from FutureLearn, the last attempt is considered. However, considering the required assumption of having a RM, the last attemp does not
  # seem right. Since one of the RM assumption is that the quiz has been answered once. Or there is no hint for answering a question.
  # Some courses are designed to have quizes which shows a hint box that your answer is not correct and the correct answer will be given.
  if(attemp == "last"){ tmp <- questionResponse[order(questionResponse$submitted_at, decreasing = TRUE),] }
  if(attemp == "first"){ tmp <- questionResponse[order(questionResponse$submitted_at, decreasing = FALSE),] }
  
  raschMatrix <- tmp[!duplicated(tmp[c("learner_id", "quiz_question")]),]
  raschMatrix <- reshape2::dcast(raschMatrix, learner_id ~ quiz_question, value.var="correct")
  raschMatrix[raschMatrix=="true"] <- as.numeric(1)
  raschMatrix[raschMatrix=="false"] <- as.numeric(0)
  raschMatrix[raschMatrix=="TRUE"] <- as.numeric(1)
  raschMatrix[raschMatrix=="FALSE"] <- as.numeric(0)
  
  # Voided questions are bad - they result in large numbers of learners responding NA (e.g. not
  # responding because they can't). Because we don't know for sure if they are voided, we look
  # for columns with 90%+ NAs, and drop them.
  raschMatrix <- raschMatrix[apply(raschMatrix, 2, function(x) mean(is.na(x)) <= 0.90) ]
  raschMatrix <- na.omit(raschMatrix)
  raschMatrix <- raschMatrix[rowSums(raschMatrix[-1], na.rm=TRUE) > 1, ]
  
  return(raschMatrix)
}

insertFirstRaschAnalysisSummaryToDb <- function()
{
  if(exists("firstRaschMatrix"))
  {
    table_name = "vis_FirstRaschAnalysisSummary"
    tryCatch({
      insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
      
      raschModel <- RM(firstRaschMatrix[-1])
      
      modelSummary <- as.matrix(summary(raschModel$etapar))
      rasch_summary <- as.data.frame(modelSummary) 
      colnames(rasch_summary) <- c("Difficulty")
      rasch_summary$metrics <- row.names(rasch_summary)
      
      mydb = getDbConnect(courseSlug)
      dbWriteTable(mydb, name = table_name, value = rasch_summary[,c(2,1)], overwrite = TRUE, row.names = FALSE , 
                   field.types = list(Metrics = "varchar(20)" ,Difficulty = "double")) 
      dbDisconnect(mydb)
      
      insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
    }, error=function(e)
    { 
      #error handling code, maybe just skip this iteration using
      msg <- gsub("'",'',conditionMessage(e))
      message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
      insertIntoErrorLoggingTable(message)
    })
  }
}

insertLastRaschAnalysisSummaryToDb <- function()
{
  if(exists("lastRaschMatrix"))
  {
    table_name = "vis_LastRaschAnalysisSummary"
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    raschModel <- tryCatch(RM(lastRaschMatrix[-1]), error=function(e) e)
    if (!inherits(raschModel, "error"))
    {
      tryCatch({
        modelSummary <- as.matrix(summary(raschModel$etapar))
        rasch_summary <- as.data.frame(modelSummary) 
        colnames(rasch_summary) <- c("Difficulty")
        rasch_summary$metrics <- row.names(rasch_summary)
        
        mydb = getDbConnect(courseSlug)
        dbWriteTable(mydb, name = table_name, value = rasch_summary[,c(2,1)], overwrite = TRUE, row.names = FALSE , 
                     field.types = list(Metrics = "varchar(20)" ,Difficulty = "double")) 
        dbDisconnect(mydb)
        
        insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
      }, error=function(e)
      { 
        #error handling code, maybe just skip this iteration using
        msg <- gsub("'",'',conditionMessage(e))
        message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
        insertIntoErrorLoggingTable(message)
      })
    }
    else
    {
      #error handling code, maybe just skip this iteration using
      message <- paste("Could not calculate rasch model for ", courseSlug,' for last attempt at insertLastRaschAnalysisSummaryToDb.', sep = "")
      insertIntoErrorLoggingTable(message)
    }
  }
}

insertFirstItemMapToDb <- function()
{
  if(exists("firstRaschMatrix"))
  {
    table_name = "vis_FirstItemMap"
    tryCatch({
      insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
      
      raschModel <- RM(firstRaschMatrix[-1])
      
      df <- as.data.frame(-raschModel$betapar)
      df$step <- gsub("beta ","",rownames(df))
      colnames(df) <- c("difficulty","question")
      
      mydb = getDbConnect(courseSlug)
      dbWriteTable(mydb, name = table_name, value = df[,c(2,1)], overwrite = TRUE, row.names = FALSE , 
                   field.types = list(question = "varchar(8)" ,difficulty = "double")) 
      dbDisconnect(mydb)
      
      insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
    }, error=function(e)
    { 
      #error handling code, maybe just skip this iteration using
      msg <- gsub("'",'',conditionMessage(e))
      message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
      insertIntoErrorLoggingTable(message)
    })
  }
}

insertLastItemMapToDb <- function()
{
  if(exists("lastRaschMatrix"))
  {
    table_name = "vis_LastItemMap"
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    # raschModel <- try(RM(lastRaschMatrix[-1]))
    # 
    # if(inherits(raschModel, "try-error"))
    # {
    #   #error handling code, maybe just skip this iteration using
    #   message <- paste("Could not calculate rasch model for ", courseSlug, ' for the last attempt at insertLastItemMapToDb.', sep = "")
    #   insertIntoErrorLoggingTable(message)
    #   return()
    # }
    tryCatch({
      raschModel <- RM(lastRaschMatrix[-1])
      
      df <- as.data.frame(-raschModel$betapar)
      df$step <- gsub("beta ","",rownames(df))
      colnames(df) <- c("difficulty","question")
      
      mydb = getDbConnect(courseSlug)
      dbWriteTable(mydb, name = table_name, value = df[,c(2,1)], overwrite = TRUE, row.names = FALSE ,
                   field.types = list(question = "varchar(8)" ,difficulty = "double"))
      dbDisconnect(mydb)
      
      insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
    }, error=function(e)
    { 
      #error handling code, maybe just skip this iteration using
      msg <- gsub("'",'',conditionMessage(e))
      message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
      insertIntoErrorLoggingTable(message)
    })
  }
}

insertFirstPersonItemMapToDb <- function()
{
  if(exists("firstRaschMatrix"))
  {
    table_name = "vis_FirstPersonItemMap"
    tryCatch({
      insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
      
      raschModel <- RM(firstRaschMatrix[-1])
      
      df <- as.data.frame(-raschModel$betapar)
      
      df_t <- data.frame(t(df))
      colnames(df_t) <- gsub("beta.","",colnames(df_t))
      
      data <- firstRaschMatrix
      
      # Since the RM removes some responses due to complete 0/full,
      # when the matrix is going to be multiply by this vector form RM,
      # the number of column does not match.
      # The fillowing fill the gaps as 0.
      for(i in 1:ncol(data[,2:ncol(data)]))
      {
        if(i <= length(colnames(df_t)))
        {
          if(colnames(df_t)[i] != colnames(data[,2:ncol(data)])[i])
          {
            df_t = cbind(df_t[1:(i-1)],list(0),df_t[i:ncol(df_t)])
            colnames(df_t)[i] = colnames(data[,2:ncol(data)])[i]
          }
        }
        else
        {
          df_t$new = 0
          colnames(df_t)[i] = colnames(data[,2:ncol(data)])[i]
        }
      }
      
      data$score <- 0
      for(i in 1:nrow(data))
      {
        s <- rowSums(data[i,2:(ncol(data)-1)]*df_t)
        data[i,ncol(data)] <- s
      }
      
      data[2:(ncol(data)-1)] <- list(NULL)
      
      mydb = getDbConnect(courseSlug)
      dbWriteTable(mydb, name = table_name, value = data, overwrite = TRUE, row.names = FALSE , 
                   field.types = list(learner_id = "varchar(36)" ,score = "double")) 
      dbDisconnect(mydb)
      
      insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
    }, error=function(e)
    { 
      #error handling code, maybe just skip this iteration using
      msg <- gsub("'",'',conditionMessage(e))
      message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
      insertIntoErrorLoggingTable(message)
    })
  }
}

insertLastPersonItemMapToDb <- function()
{
  if(exists("lastRaschMatrix"))
  {
    table_name = "vis_LastPersonItemMap"
    
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    raschModel <- tryCatch(RM(lastRaschMatrix[-1]), error=function(e) e)
    if (!inherits(raschModel, "error"))
    {
      tryCatch({
        df <- as.data.frame(-raschModel$betapar)
        
        df_t <- data.frame(t(df))
        colnames(df_t) <- gsub("beta.","",colnames(df_t))
        
        data <- lastRaschMatrix
        
        # Since the RM removes some responses due to complete 0/full,
        # when the matrix is going to be multiply by this vector form RM,
        # the number of column does not match.
        # The fillowing fill the gaps as 0.
        
        for(i in 1:ncol(data[,2:ncol(data)]))
        {
          if(i <= length(colnames(df_t)))
          {
            if(colnames(df_t)[i] != colnames(data[,2:ncol(data)])[i])
            {
              df_t = cbind(df_t[1:(i-1)],list(0),df_t[i:ncol(df_t)])
              colnames(df_t)[i] = colnames(data[,2:ncol(data)])[i]
            }
          }
          else
          {
            df_t$new = 0
            colnames(df_t)[i] = colnames(data[,2:ncol(data)])[i]
          }
        }
        
        data$score <- 0
        
        for(i in 1:nrow(data))
        {
          try_error <- tryCatch(rowSums(data[i,2:(ncol(data)-1)]*df_t), error=function(e) e)
          # if not an error
          if (!inherits(try_error, "error"))
          {
            data[i,ncol(data)] <- try_error
          }
        }
        
        data[2:(ncol(data)-1)] <- list(NULL)
        
        mydb = getDbConnect(courseSlug)
        dbWriteTable(mydb, name = table_name, value = data, overwrite = TRUE, row.names = FALSE , 
                     field.types = list(learner_id = "varchar(36)" ,score = "double")) 
        dbDisconnect(mydb)
        
        insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
      }, error=function(e)
      { 
        #error handling code, maybe just skip this iteration using
        msg <- gsub("'",'',conditionMessage(e))
        message <- paste("Got an error at ", table_name, ' in ', courseSlug,' at insertLastPersonItemMapToDb. Error: ',msg, sep = "")
        insertIntoErrorLoggingTable(message)
      })
    }
    else
    {
      #error handling code, maybe just skip this iteration using
      message <- paste("Could not calculate rasch model for ", courseSlug,' for last attempt at insertLastPersonItemMapToDb.', sep = "")
      insertIntoErrorLoggingTable(message)
    }
    
  }
}

# insertQuartileAnalysisResultToDb <- function()
# {
#   if(nrow(questionResponse) > 0)
#   {
#     table_name = "vis_QuartileAnalysisResult"
#     tryCatch({
#       insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
#       
#       attempts <- data.table(questionResponse)
#       attempts <- attempts[order(-rank(learner_id), quiz_question, submitted_at)]
#       attempts <- attempts[, attempt := 1:.N, by=c("learner_id", "quiz_question")]
#       correctAttempts <- attempts[attempts$correct == TRUE, ]
#       
#       correctAttempts$step <- gsub(".\\d$","", correctAttempts$quiz_question)
#       correctAttempts$score <- abs(correctAttempts$attempt-4)
#       numberOfQuestions <- length(unique(correctAttempts$quiz_question))
#       perfectScore <- numberOfQuestions * 3
#       
#       totalScoresByLearner <-ddply(correctAttempts,.(learner_id),summarise, totalScore = sum(score), totalPercentage = sum(score)/perfectScore)
#       
#       totalScoresByLearner <- within(totalScoresByLearner, quartile <- as.integer(cut(totalPercentage, unique(quantile(totalPercentage, probs=0:4/4), include.lowest=TRUE))))
#       
#       correctAttempts <- merge(x=correctAttempts, y=totalScoresByLearner, by="learner_id")
#       
#       correctAttemptsQuartileSummary <-  ddply(correctAttempts,.(quiz_question, quartile),summarise,
#                                                first = sum(attempt==1)/length(unique(learner_id)),
#                                                second = sum(attempt==2)/length(unique(learner_id)),
#                                                third = sum(attempt==3)/length(unique(learner_id))
#       )
#       
#       meltedCorrectAttemptsQuartileSummary <- melt(correctAttemptsQuartileSummary, id.vars=c("quiz_question", "quartile"), variable.name="attempt", value.name="p")
#       
#       mydb = getDbConnect(courseSlug)
#       dbWriteTable(mydb, name = table_name, value = meltedCorrectAttemptsQuartileSummary, overwrite = TRUE, row.names = FALSE , 
#                    field.types = list(quiz_question = "varchar(8)", quartile = "int", attempt = "varchar(10)" ,p = "double")) 
#       dbDisconnect(mydb)
#       
#       insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
#     }, error=function(e)
#     { 
#       #error handling code, maybe just skip this iteration using
#       msg <- gsub("'",'',conditionMessage(e))
#       message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
#       insertIntoErrorLoggingTable(message)
#     })
#   }
# }

insertCommentsStatsByStepRoleToDb <- function()
{
  table_name = "vis_CommentsStatsByStepRole"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    tmp <- comments
    commentsWithRole <- left_join(tmp,subset(team.members,select=c("id","team_role")), by=c("author_id" = "id"))
    commentsWithRole$team_role <- replace(commentsWithRole$team_role, is.na(commentsWithRole$team_role), 'learner')
    colnames(commentsWithRole)[ncol(commentsWithRole)] <- "role"
    
    fr <- ddply(commentsWithRole, .(step,role), dplyr::summarize, 
                comments = n(),total_likes = sum(as.numeric(likes)),mean_likes= round(mean(as.numeric(likes)),2))
    fr$step <- as.character(fr$step)
    
    # Fill the gaps in the data frame to be prepared for visualisation
    uniqueSteps <- unique(fr$step)
    uniqueRoles <- unique(fr$role)
    tmp <- merge(uniqueRoles,uniqueSteps)
    tmp <- tmp[ ,c(2,1)]
    colnames(tmp) <- c("step","role")
    tmp <- left_join(tmp,fr,by=c("step"="step","role"="role"),all.y=TRUE)
    tmp <- replace(tmp, is.na(tmp), 0)
    
    tmp[,6:7] <- matrix(as.numeric(unlist(strsplit(as.character(tmp$step), split = "[.]"))), ncol=2, byrow=TRUE)
    tmp <- tmp[with(tmp,order(tmp$V6,tmp$V7)), ]
    tmp[,6:7] <- list(NULL)
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = tmp, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(step = "varchar(5)", role = "varchar(20)", 
                                    comments = "int", total_likes = "int", mean_likes = "double")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertWordCountStatsByEducatorsToDb <- function()
{
  table_name = "vis_WordCountStatsByEducators"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    tmp <- comments
    commentsWithRole <- inner_join(tmp,team.members, by=c("author_id" = "id"))
    
    # non_learners = subset(enrolments, role != "learner")
    # non_learner_ids = non_learners[ ! duplicated( non_learners[ c("learner_id","role") ] ) , ]
    
    # commentsWithRole <- inner_join(commentsWithRole,non_learner_ids, by=c("author_id" = "learner_id"))
    
    WordCountSummary <- ddply(commentsWithRole, .(author_id,first_name,last_name,wordCount), summarise, Words =n())
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = WordCountSummary, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(author_id = "varchar(36)"
                                    , first_name = "varchar(100)"
                                    , last_name = "varchar(255)", wordCount = "double", Words = "double")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertAttemptToCorrectToDb <- function()
{
  if(nrow(questionResponse) > 0)
  {
    table_name = "vis_AttemptToCorrect"
    tryCatch({
      insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
      
      attempts <- data.table(questionResponse)
      attempts <- attempts[order(-rank(learner_id), quiz_question, submitted_at)]
      attempts <- attempts[, attempt := 1:.N, by=c("learner_id", "quiz_question")]
      attempts$attempt <- ifelse(attempts$attempt > 4 ,"5+",attempts$attempt)
      correctAttempts <- attempts[attempts$correct == TRUE, ]
      dSummary <- ddply(correctAttempts,.(quiz_question,attempt), summarise, value = n())
      
      dSummary[,4:6] <- matrix(as.numeric(unlist(strsplit(as.character(dSummary[,1]), "[.]"))), ncol=3, byrow=TRUE)
      dSummary <- dSummary[with(dSummary,order(dSummary[,4],dSummary[,5],dSummary[,6])), ]
      dSummary[4:6] <- list(NULL)
      
      mydb = getDbConnect(courseSlug)
      dbWriteTable(mydb, name = table_name, value = dSummary, overwrite = TRUE, row.names = FALSE , 
                   field.types = list(quiz_question = "varchar(10)", attempt = "varchar(3)", value = "bigint")) 
      dbDisconnect(mydb)
      
      insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
    }, error=function(e)
    { 
      #error handling code, maybe just skip this iteration using
      msg <- gsub("'",'',conditionMessage(e))
      message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
      insertIntoErrorLoggingTable(message)
    })
  }
}

insertQuizAttemptsToDb <- function()
{
  if(nrow(questionResponse) > 0)
  {
    table_name = "vis_QuizAttempts"
    tryCatch({
      insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
      
      summary <-  ddply(questionResponse, .(quiz_question,correct), summarise, attempts = n() , UniqueAttempts = length(unique(learner_id)))
      summary$quiz_question <- as.character(summary$quiz_question)
      
      summary[,5:7] <- matrix(as.numeric(unlist(strsplit(as.character(summary[,1]), "[.]"))), ncol=3, byrow=TRUE)
      summary <- summary[with(summary,order(summary[,5],summary[,6],summary[,7])), ]
      summary[5:7] <- list(NULL)
      
      summary$correct <- ifelse(summary$correct == 0 ,"Incorrect","Correct")
      
      mydb = getDbConnect(courseSlug)
      dbWriteTable(mydb, name = table_name, value = summary, overwrite = TRUE, row.names = FALSE , 
                   field.types = list(quiz_question = "varchar(10)", correct = "varchar(10)", attempts = "bigint", UniqueAttempts = "bigint")) 
      dbDisconnect(mydb)
      
      insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
    }, error=function(e)
    { 
      #error handling code, maybe just skip this iteration using
      msg <- gsub("'",'',conditionMessage(e))
      message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
      insertIntoErrorLoggingTable(message)
    })
  }
}

insertCommentsHistogramByLearnersToDb <- function()
{
  table_name = "vis_CommentsHistogramByLearners"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    
    learners_comments = subset(comments, !author_id %in% team.members$id)
    
    learnersCommentsSummary <- ddply(learners_comments, .(author_id), summarise, comments =n())
    histSummary <- ddply(learnersCommentsSummary, .(comments), summarise, participents = n())
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = histSummary, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(comments = "double", participents = "double")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertWordCountAnalysisByRoleToDb <- function()
{
  table_name = "vis_WordCountAnalysisByRole"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    commentsWithRole <- left_join(comments,team.members, by=c("author_id" = "id"))
    commentsWithRole$team_role  <- ifelse(is.na(commentsWithRole$team_role),'learner','organisation_admin')
    commentsSummary <- ddply(commentsWithRole, .(team_role), summarise, wordCount =sum(wordCount), comments=n())
    colnames(commentsSummary)[1] <- 'role'
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = commentsSummary, overwrite = TRUE, row.names = FALSE ,
                 field.types = list(role = "varchar(50)",wordCount = "double", comments = "double"))
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertVisitedFirstStepFinishedAllStepsToDb <- function()
{
  table_name = "vis_VisitedFirstStepFinishedAllSteps"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    uniqueWeeks <- unique(learnersStepActivity$week_number)
    uniqueWeeksSteps <- subset(learnersStepActivity[ ! duplicated( learnersStepActivity[ c("week_number" , "step") ] ) , ],
                               select= c("week_number" , "step"))
    row.names(uniqueWeeksSteps) <- NULL
    
    students_started <- data.frame(learner_id=character(0),
                                   step = character(0),
                                   week_number=integer(0))
    for(i in 1:length(uniqueWeeks))
    {
      s <- paste(uniqueWeeks[i],".1",sep = "")
      temp <- learnersStepActivity[learnersStepActivity$step == s, ] 
      
      students_started <- rbind(students_started,data.frame(learner_id=temp$learner_id,
                                                            step = temp$step,
                                                            week_number=temp$week_number))
    }
    
    steps_per_week <- ddply(uniqueWeeksSteps,.(week_number),summarise,total_steps = n())
    
    steudents_visit_per_week <- ddply(learnersStepActivity,.(learner_id,week_number),summarise,total_visit=n())
    
    students_started <- inner_join(steudents_visit_per_week,students_started, by = c("learner_id"="learner_id",
                                                                                     "week_number"="week_number"))
    students_started <- inner_join(students_started,steps_per_week,by=c("week_number"="week_number"))
    
    finished_all_steps <- subset(students_started, total_visit == total_steps)
    
    students_started.sum <-  ddply(students_started,.(week_number), summarise, total=n())
    finished_all_steps.sum <- ddply(finished_all_steps,.(week_number), summarise, finished=n())
    result <- inner_join(students_started.sum,finished_all_steps.sum,by=c("week_number"="week_number"))
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = result, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(week_number = "double",total = "double", finished = "double")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertNetworkAnalysisByStepToDb <- function()
{
  table_name = "vis_NetworkAnalysisByStep"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    stepActivity <- subset(learnersStepActivity,select =c('learner_id','step','first_visited_at'))
    
    stepActivity <- na.omit(stepActivity)
    stepActivity <-  stepActivity[with(stepActivity,order(stepActivity[,1],stepActivity[,3])), ]
    
    uniqueLearners <- unique(stepActivity$learner_id)
    df <- data.frame(learner_id=character(0), source=character(0),target=character(0),value = integer(0))
    
    for(i in 1:length(uniqueLearners))
    { 
      l_id <- uniqueLearners[i]
      tmp <- subset(stepActivity,learner_id == l_id)
      #print(uniqueLearners[i])
      if(nrow(tmp) == 1)
      {
        df <- rbind(df,data.frame(learner_id = l_id,
                                  source="NA",target=tmp$step[1],value = 1))
      }
      else
      {
        for(j in 1:(nrow(tmp)-1))
        {
          df <- rbind(df,data.frame(learner_id = l_id,
                                    source=tmp$step[j],target=tmp$step[(j+1)],value = 1))
        }
      }
    }
    
    df <- subset(df,source != 'NA')
    
    table_name = "vis_NetworkAnalysisByLearners"
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = df, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(learner_id= "varchar(36)",source = "varchar(5)",target = "varchar(5)", value = "double")) 
    dbDisconnect(mydb)
    
    df.sum <- ddply(df,.(source,target),summarise,value=sum(value))
    
    table_name = "vis_NetworkAnalysisByStep"
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = df.sum, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(source = "varchar(5)",target = "varchar(5)", value = "double")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}


insertCommentsStatsByEducatorsToDb <- function()
{
  table_name = "vis_CommentsStatsByEducators"
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    tmp <- comments
    commentsWithRole <- inner_join(tmp,team.members, by=c("author_id" = "id"))
    
    # non_learners = subset(enrolments, role != "learner")
    # non_learner_ids = non_learners[ ! duplicated( non_learners[ c("learner_id","role") ] ) , ]
    # 
    # commentsWithRole <- inner_join(commentsWithRole,non_learner_ids, by=c("author_id" = "learner_id"))
    
    WordCountSummary <- subset(commentsWithRole, select = c("first_name", "last_name"
                                                            , "team_role", "step", "wordCount"))
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb, name = table_name, value = WordCountSummary, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(first_name = "varchar(100)"
                                    , last_name = "varchar(255)"
                                    , team_role = "varchar(50)", step = "varchar(5)", wordCount = "double")) 
    dbDisconnect(mydb)
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
  }, error=function(e)
  { 
    #error handling code, maybe just skip this iteration using
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

# insertScoresHistogramToDB <- function()
# {
#   table_name = "vis_ScoresHistogram"
#   tryCatch({
#     if(exists("questionResponse") == FALSE)
#       return()
#     
#     insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
#     
#     questionResponse <- left_join(questionResponse,team.members, by=c("learner_id" = "id"))
#     # If no one from the UNSW staff commented the following error will be raised:
#     # Got an error at vis_ScoresHistogram in remaking-nature-2. Error: last_submitted_at column not found in lhs, cannot join
#     # So I have fixed it by having the following condition.
#     if(nrow(questionResponse) > 0)
#     {
#       questionResponse <- subset(questionResponse, is.na(first_name) & !is.na(learner_id))
#       
#       questions <- ddply(questionResponse,.(quiz_question,week_number,step_number,question_number), summarise
#                          , correct_attempts=sum(correct==1), incorrect_attempts=sum(correct==0))
#       
#       questionResponse$type <- ifelse(questionResponse$correct==1,"Correct", "Incorrect")
#       
#       questionResponse.last.attempt <- ddply(questionResponse,.(learner_id,quiz_question), summarise, last_submitted_at = max(submitted_at))
#       
#       questionResponse.last.attempt <- inner_join(questionResponse.last.attempt
#                                                   , questionResponse
#                                                   , by = c("learner_id"="learner_id"
#                                                            ,"quiz_question"="quiz_question","last_submitted_at"="submitted_at"))
#       questionResponse.last.attempt <- questionResponse.last.attempt[order(questionResponse.last.attempt[,5]
#                                                                            , questionResponse.last.attempt[,6]
#                                                                            , questionResponse.last.attempt[,7]),]
#       dataset <- left_join(questions,questionResponse.last.attempt
#                            , by=c("week_number"="week_number", "step_number"="step_number","quiz_question"="quiz_question"),all.y=TRUE)
#       dataset <- replace(dataset, is.na(dataset), 0)
#       dataset$type <- ifelse(dataset$type == 0, "Not Answered",dataset$type)
#       dataset <- subset(dataset,select=c("learner_id","quiz_question","week_number","step_number","type"))
#       
#       
#       summary <- ddply(dataset,.(learner_id),summarise,correct=sum(type=="Correct"),incorrect=sum(type=="Incorrect"),total=n())
#       summary$score <- round(summary$correct/nrow(questions)*10)
#       
#     } else
#     {
#       summary <- data.frame(learner_id = character(0)
#                             , correct = integer(0), incorrect = integer(0)
#                             , total = integer(0), score= integer(0))
#     }
#     
#     mydb = getDbConnect(courseSlug)
#     dbWriteTable(mydb, name = table_name, value = summary, overwrite = TRUE, row.names = FALSE , 
#                  field.types = list(learner_id = "varchar(36)"
#                                     , correct = "double", incorrect = "double"
#                                     , total = "double", score = "int")) 
#     dbDisconnect(mydb)
#     
#     insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
#   }, error=function(e)
#   { 
#     #error handling code, maybe just skip this iteration using
#     msg <- gsub("'",'',conditionMessage(e))
#     message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
#     insertIntoErrorLoggingTable(message)
#   })
# }

insertMinutessSpendByStepToDb <- function()
{
  table_name = "vis_MinutesSpendByStep"
  
  tryCatch({
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    # Hours is not rounded, they used the int part of the decimal number.
    flt <- filter(learnersStepActivity,!is.na(last_completed_at))
    flt$delta <- as.numeric(
      difftime(strptime(flt$last_completed_at,"%Y-%m-%d %H:%M:%S"), strptime(flt$first_visited_at,"%Y-%m-%d %H:%M:%S"), units="mins")
    )
    stepCompletion <- subset(flt,!is.na(delta))
    
    # Find the breaks in the hours
    # hours <- data.frame(unique(weekCompletion$hours))
    # colnames(hours) <- 'hour'
    # hours$hour <- hours[order(hours[,1]), ]
    
    breaks=c(-1,1,2,5,10,20,30,60,100000)
    labels=c("less than 1", "1-2", "3-5", "6-10", '11-20','21-30','31-60', "more than an hour")
    
    melted <- melt(stepCompletion, na.rm = TRUE, value.name = "delta", id.vars=c("step"), measure.vars=c("delta"))
    melted$delta <- cut(melted$delta, breaks=breaks, labels=labels)
    bucketed <- ddply(melted,.(step, delta),summarise,freq = n())
    # We have to fill the gaps in the dataframe. Since this data is going to group by hours, if there is no 
    # corresponding row for each week_number and any hours, the graph shift the data to left to fill the gap by itself.
    # Then at the end of axis, there are empty bars.
    # So the following will find all missing hours for each week_number, and put 0 for each attribute column.
    uniqueWeeks <- unique(bucketed$step);
    uniquehours <- unique(bucketed$delta);
    tmp <- merge(uniquehours,uniqueWeeks);
    tmp <- tmp[ ,c(2,1)];
    colnames(tmp) <- c("step","delta");
    tmp <- left_join(tmp,bucketed,by=c("step"="step","delta"="delta"),all.y=TRUE)
    tmp <- replace(tmp, is.na(tmp), 0)
    # Set old class to avoid this error which is from dplyr package:
    #   Error in (function (classes, fdef, mtable)  : 
    #   unable to find an inherited method for function 'dbWriteTable' for signature '"MySQLConnection", "character", "grouped_df"'
    setOldClass(c("grouped_df", "data.frame")) ;
    
    mydb = getDbConnect(courseSlug);
    dbWriteTable(mydb,  name = table_name, value = tmp, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(step = "varchar(5)", delta = "varchar(20)",freq = "bigint")) 
    dbDisconnect(mydb);
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
    
  },error=function(e){
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
}

insertVisitedOtherStepsDuringQuizToDb <- function()
{
  table_name = "vis_VisitedOtherStepsDuringQuiz"
  
  tryCatch({
    
    if(nrow(questionResponse) == 0)
      return()
    insertIntoLoggingTable(paste("Start processing data for ",table_name, " from ", courseSlug,sep = ""), table_name, courseSlug)
    
    question.response <- subset(questionResponse, !learner_id %in% team.members$id)
    
    # Here we compute tfor each learner the first time attempted to answer a quiz and the last time answered a question of a quiz
    learners.quiz.response <- ddply(question.response,.(learner_id,week_number,step_number),summarise,started=min(submitted_at),finished=max(submitted_at),score=sum(correct))
    
    learners.visited.during.quiz = 
      stepActivity %>%
      inner_join(learners.quiz.response, by = c("learner_id" = "learner_id")) %>%
      filter( started != finished & first_visited_at >= started & (first_visited_at <= finished | last_completed_at <= finished )) 
    
    learners.visited.during.quiz <- subset(learners.visited.during.quiz,select=c("learner_id","step","week_number.x","step_number.x"
                                                                                 ,"week_number.y", "step_number.y","score"))
    colnames(learners.visited.during.quiz) <- c("learner_id","visited_step","visited_week_number","visited_step_number"
                                                ,"quiz_week_number", "quiz_step_number","quiz_score")
    
    mydb = getDbConnect(courseSlug)
    dbWriteTable(mydb,  name = table_name, value = learners.visited.during.quiz, overwrite = TRUE, row.names = FALSE , 
                 field.types = list(learner_id = "varchar(36)", visited_step = "varchar(5)",visited_week_number = "int"
                                    ,visited_step_number="int",quiz_week_number="int", quiz_step_number="int",quiz_score="int")) 
    dbDisconnect(mydb);
    
    insertIntoLoggingTable("Inserted processed data!", table_name, courseSlug)
    
  },error=function(e){
    msg <- gsub("'",'',conditionMessage(e))
    message <- paste("Got an error at ", table_name, ' in ', courseSlug,'. Error: ',msg, sep = "")
    insertIntoErrorLoggingTable(message)
  })
  
}

loadTeamMembers <- function(){
  mydb = getDbConnect(courseSlug)
  rs = dbSendQuery(mydb, "select * from team_members")
  team.members <- fetch(rs, n=-1)
  dbClearResult(rs)
  dbDisconnect(mydb)
  
  return(team.members)
}

if(is.element('team_members'	, myArgs))
{
  team.members = loadTeamMembers()
}

if(is.element('comments'			, myArgs))
{
  comments = loadComments()
  startEndDatesByWeek = getStartEndDatesByWeek()
}

if(is.element('enrolments'	 	    , myArgs))
{
  enrolments = loadEnrolment()
  if(exists("startEndDatesByWeek") == FALSE)
    startEndDatesByWeek = getStartEndDatesByWeek()
}

if(is.element('step_activity'		, myArgs))
{
  stepActivity = loadStepActivity()
  if(exists("startEndDatesByWeek") == FALSE)
    startEndDatesByWeek = getStartEndDatesByWeek()
  learnersStepActivity = loadLearnersStepActivity()
}
if(is.element('question_response'	, myArgs))
{
  questionResponse = loadQuestionResponce()
  if(nrow(questionResponse) > 0)
  { 
    attemp <<- 'first'
    firstRaschMatrix = getRaschMatrix()
    attemp <<- 'last'
    lastRaschMatrix = getRaschMatrix()
  }
}





if(is.element('vis_ActivityByStep'					, myArgs)){insertActivityByStepToDb()}
if(is.element('vis_HoursSpendByWeek'				, myArgs)){insertHoursSpendByWeekToDb()}
if(is.element('vis_LastProgressesByDate'			, myArgs)){insertLastProgressesByDateToDb()}
if(is.element('vis_LastProgressesByStep'			, myArgs)){insertLastProgressesByStepToDb()}
if(is.element('vis_LearnersActivities'				, myArgs)){insertLearnersActivitiesToDb()}
if(is.element('vis_LearnersActivitiesByDay'				, myArgs)){insertLearnersActivitiesByDayToDb()}
if(is.element('vis_MinutesSpendByStep',myArgs)){insertMinutessSpendByStepToDb()}
if(is.element('vis_StepProgressCountsHeatmap'		, myArgs)){insertStepProgressCountsHeatmapToDb()}
if(is.element('vis_NetworkAnalysisByStep',myArgs)){insertNetworkAnalysisByStepToDb()}
if(is.element('vis_VisitedFirstStepFinishedAllSteps',myArgs)){insertVisitedFirstStepFinishedAllStepsToDb()}
if(is.element('vis_AfinnSentimentAnalysisResult'	, myArgs)){insertAfinnSentimentAnalysisResultToDb()}
if(is.element('vis_BingSentimentAnalysisResult'		, myArgs)){insertBingSentimentAnalysisResultToDb()}
if(is.element('vis_CommentsHistogramByLearners',myArgs)){insertCommentsHistogramByLearnersToDb()}
if(is.element('vis_CommentsOverviewTable'			, myArgs)){insertCommentsOverviewTableToDb()}
if(is.element('vis_CommentsStatsByStepRole',myArgs)){insertCommentsStatsByStepRoleToDb()}
if(is.element('vis_CommentsStatsDay'				, myArgs)){insertCommentsStatsDayToDb()}
if(is.element('vis_CommentsStatsDayType'				, myArgs)){insertCommentsStatsDayTypeToDb()}
if(is.element('vis_CommentsStatsStep'				, myArgs)){insertCommentsStatsStepToDb()}
if(is.element('vis_CommentsStatsByEducators',myArgs)){insertCommentsStatsByEducatorsToDb()}
if(is.element('vis_OriginalSentimentAnalysisResult'	, myArgs)){insertOriginalSentimentAnalysisResultToDb()}
if(is.element('vis_WordCountAnalysisByRole',myArgs)){insertWordCountAnalysisByRoleToDb()}
if(is.element('vis_WordCountStatsByEducators',myArgs)){insertWordCountStatsByEducatorsToDb()}
if(is.element('vis_EnrolmentsByDay'					, myArgs)){insertEnrolmentsByDayToDb()}
if(is.element('vis_EnrolmentsByWeek'				, myArgs)){insertEnrolmentsByWeekToDb()}
if(is.element('vis_AttemptToCorrect',myArgs)){insertAttemptToCorrectToDb()}
if(is.element('vis_FirstItemMap'							, myArgs)){insertFirstItemMapToDb()}
if(is.element('vis_LastItemMap'							, myArgs)){insertLastItemMapToDb()}
if(is.element('vis_FirstPersonItemMap'					, myArgs)){insertFirstPersonItemMapToDb()}
if(is.element('vis_LastPersonItemMap'					, myArgs)){insertLastPersonItemMapToDb()}
if(is.element('vis_QuestionResponseOverview'		, myArgs)){insertQuestionResponseOverviewToDb()}
if(is.element('vis_QuizAttempts',myArgs)){insertQuizAttemptsToDb()}
if(is.element('vis_FirstRaschAnalysisSummary'			, myArgs)){insertFirstRaschAnalysisSummaryToDb()}
if(is.element('vis_LastRaschAnalysisSummary'			, myArgs)){insertLastRaschAnalysisSummaryToDb()}
if(is.element('vis_VisitedOtherStepsDuringQuiz',myArgs)){insertVisitedOtherStepsDuringQuizToDb()} 

# # The following are not used
#if(is.element('vis_CommentsCountHeatmap'			, myArgs)){insertCommentsCountHeatmapToDb()}
#if(is.element('vis_QuartileAnalysisResult'			, myArgs)){insertQuartileAnalysisResultToDb()}
#if(is.element('vis_StepProgressCountsHeatmapByWeek'		, myArgs)){insertStepProgressCountsHeatmapByWeekToDb()}
#if(is.element('vis_ScoresHistogram',myArgs)){insertScoresHistogramToDB()} 
