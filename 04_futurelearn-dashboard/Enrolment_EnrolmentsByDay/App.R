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
library(highcharter)
library(xts)
library(shiny)

ui <- fluidPage(
  fluidRow(highchartOutput("enrolmentsByDay"))
)

server <- function(input, output, session) {
  
source("../config.R", local = T)
source("../utilities.R", local = T)
  
  enrolmentsByDay <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_EnrolmentsByDay")
      enrolments = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      enrolments$enrolled_at <- as.Date(enrolments$enrolled_at,"%Y-%m-%d")
      
      return(enrolments)
    }
  })
  
  findCourseStartEndDatesByWeek <- reactive(
    {
      query <- parseQueryString(session$clientData$url_search)
      if (!is.null(query[['course']]))
      {
        courseSlug = query[['course']]
        dates2 = findStartEndDatesByWeek(courseSlug)
        return(dates2)
      }
    }
  )
  
  output$enrolmentsByDay <- renderHighchart({
      df <- enrolmentsByDay()
      dates <- findCourseStartEndDatesByWeek()
      dates$start_date <- as.Date(dates$start_date)
      dates$end_date <- as.Date(dates$end_date)
      
      title = c()
      for(i in 1:nrow(dates))
      {
        title <- append(title, paste("Week ",dates$week_number[i],sep = ""))
      }
      title <- append(title,"Course finished")
      
      df$enrolled_at <- as.Date(df$enrolled_at)
      df$freq <- NULL
      df_xts <-  xts(df[,-1], order.by=df[,1])

      h1<- highchart(type = "stock") 
      h1 <- hc_title(h1,text = "Enrolment cumulative growth") 
      h1 <- hc_subtitle(h1,text = "This chart shows the cumulative growth of enrollments from the first time a learner enrolled.") 
      h1 <- hc_add_series_xts(h1,df_xts, id = "df", name= "Enrolments") 
      h1 <- hc_add_series_flags(h1,append(dates$start_date,dates$end_date[nrow(dates)]),
                                title = title, 
                                text = title,
                                id = "df", name = "Flags")
     h1 <- hc_add_theme(h1,hc_theme_flat()) 
     h1 <- hc_exporting(h1,enabled = T)
      
      
      return(h1)
  })
  
}

shinyApp(ui = ui, server = server)
