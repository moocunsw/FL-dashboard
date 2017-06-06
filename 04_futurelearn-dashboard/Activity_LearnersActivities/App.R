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

library(RMySQL)
library(rCharts)
library(highcharter)
library(plyr)
library(dplyr)
library(shiny)

ui <- fluidPage(
 headerPanel("Learners Activity by Week"),
 h4(strong("Registrants"), " are users who wenrolled in the course as a learner.",br(),
    strong("Learners"), " are users who have at least viewed at least one step at anytime in any course week. This includes those who go on to leave the course.",br(),
    strong("Active learners"), " are those who have completed at least one step at anytime in any course week, including those who go on to leave the course.",br(),
    strong("Returning Learners"), " are those who completed at least a step in at least two distinct course weeks. These do not have to be sequential or consecutive, nor completed in different calendar weeks.",br(),
    strong("Social Learners"), " are those who have posted at least one comment on any step. "
 ),
  fluidRow(showOutput("LearnersActivities", "nvd3")),
  fluidRow(HTML('<hr>'),highchartOutput("FunnelLearnersActivities", height = "600px")) 
)

server <- function(input, output, session) {
  
source("../config.R")
source("../utilities.R")
  
  LearnersActivities <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_LearnersActivities")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      return(data)
    }
  })
  
 getFunnelData <- reactive({
   query <- parseQueryString(session$clientData$url_search)
   if (!is.null(query[['course']]))
   {
     courseSlug = query[['course']]
   mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
   rs = dbSendQuery(mydb, "select learner_id,role from enrolments")
   enrolments = fetch(rs, n=-1)
   dbClearResult(rs)
   dbDisconnect(mydb)
   
   mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
   rs = dbSendQuery(mydb, "select learner_id,week_number,last_completed_at,first_visited_at from step_activity")
   step_activity = fetch(rs, n=-1)
   dbClearResult(rs)
   dbDisconnect(mydb)
   
   mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
   rs = dbSendQuery(mydb, "select author_id from comments")
   comments = fetch(rs, n=-1)
   dbClearResult(rs)
   dbDisconnect(mydb)
   
   registrants <- nrow(subset(enrolments,role == "learner"))
   
   step_activity <- inner_join(step_activity,enrolments,by ="learner_id")
   step_activity <- subset(step_activity, role == "learner")
   
   comments <- inner_join(comments,enrolments,by =c("author_id"="learner_id"))
   comments <- subset(comments, role == "learner")
   
   active_learners <- subset(step_activity,last_completed_at != "<NA>")
   active_learners <- length(unique(active_learners$learner_id))
   
   learners <- subset(step_activity,first_visited_at != "<NA>")
   learners <- length(unique(learners$learner_id))
   
   social_learners <- length(unique(comments$author_id))
   
   uniqueLearnerIdsWeek <- step_activity[ ! duplicated( step_activity[ c("learner_id","week_number") ] ) , ]
   uniqueLearnerIdsWeek <- ddply(uniqueLearnerIdsWeek,.(learner_id),transform,rank = rank(week_number,ties.method = "min")) 
   uniqueLearnerIdsWeek <- filter(uniqueLearnerIdsWeek,rank>1)
   uniqueLearnerIdsWeek<- ddply(uniqueLearnerIdsWeek, .(learner_id), summarise, week_number=min(week_number))
   returning_learner <- length(unique(uniqueLearnerIdsWeek$learner_id))
   
   completed_learners <- subset(step_activity,last_completed_at != "<NA>")
   completed_learners <- ddply(completed_learners,.(learner_id),summarise,freq=n())
   types <- getStepTypeByCourse(courseSlug)
   completed_learners$half <- round(nrow(types)/2)
   completed_learners <- subset(completed_learners,freq >= half)
   completed_learners <- length(unique(completed_learners$learner_id))
   
   result <- data.frame(
     name = c("Registrants","Learners", "Active Learners","Social Learners", "Returning Learners", "Completed >=50% of steps"),
     y = c(registrants,learners,active_learners,social_learners,returning_learner,completed_learners)
   )
   result$name <- paste(result$name, ' (', result$y, ')', sep = '')
   result <- result[order(-result[,2]),]
   return(result)
   }
 })
  
  output$LearnersActivities <- renderChart({
      finalResult <- LearnersActivities()
      finalResult$week_number <- as.character(finalResult$week_number)
      n1<-nPlot(value ~ week_number, group = 'variable', 
                data = finalResult, 
                type = 'lineChart')
      n1$xAxis(tickValues = unique(finalResult$week_number),
               tickFormat = "#!function(d) {return 'Week ' + d3.format(',f')(d)}!#")
      n1$yAxis(showMaxMin = FALSE,
               tickFormat = "#!function(d) {return d3.format(',f')(d)}!#")
      n1$chart(useInteractiveGuideline = TRUE)
      n1$addParams(dom = 'LearnersActivities')
      n1$set(title = "Learners Activity by Week")
      return(n1)
  })
  
  output$FunnelLearnersActivities <- renderHighchart(
    {
      result <- getFunnelData()
     
      h1<-   highchart() %>% 
        hc_chart(type = "funnel") %>% 
        hc_title(text="Learners Activity")%>%
        hc_subtitle(text="This chart shows the total number of participants groupbed by different types over the course period.") %>%
        hc_exporting(enabled= T)%>%  
        hc_add_series(
          name = "Learners",
          data = list_parse2(
            result
          )
        )%>%
        hc_tooltip(headerFormat="")%>%
        hc_exporting(enabled= T)
      
      return(h1)
    }
  )
  
}

shinyApp(ui = ui, server = server)
