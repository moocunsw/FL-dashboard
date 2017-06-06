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
 fluidRow(highchartOutput("LearnersActivitiesByDay"),height = "1500px") 
)

server <- function(input, output, session) {
  
source("../config.R")
source("../utilities.R")
  
  LearnersActivitiesByDay <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_LearnersActivitiesByDay")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      return(data)
    }
  })
  
  findCourseStartEndDates <- reactive(
    {
      query <- parseQueryString(session$clientData$url_search)
      if (!is.null(query[['course']]))
      {
        courseSlug = query[['course']]
        dates <- findStartEndDates(courseSlug)
        return(dates)
      }
    }
  )
  
  output$LearnersActivitiesByDay <- renderHighchart({
      df <- LearnersActivitiesByDay()
      dates <- findCourseStartEndDates()
      
      df$first_visited_at <- as.Date(df$first_visited_at)
      
      df_active <- subset(df,select = c("first_visited_at","value"), variable == "Active Learners")
      active_xts <-  xts(df_active[,2], order.by=df_active[,1])
      
      df_Learners <- subset(df,select = c("first_visited_at","value"), variable == "Learners")
      Learners_xts <-  xts(df_Learners[,2], order.by=df_Learners[,1])
      
      df_Social <- subset(df,select = c("first_visited_at","value"), variable == "Social Learners")
      Social_xts <-  xts(df_Social[,2], order.by=df_Social[,1])
      
      df_Returning <- subset(df,select = c("first_visited_at","value"), variable == "Returning Learners")
      Returning_xts <-  xts(df_Returning[,2], order.by=df_Returning[,1])
      
      h1<-  highchart(type = "chart") 
      h1 <- hc_title(h1,text = "Learners Activity by day") 
      h1 <- hc_subtitle(h1,text = 
                          "<b>Learners</b> are users who have at least viewed at least one step at anytime in any course week. This includes those who go on to leave the course.<br>
                  <b>Active learners</b> are those who have completed at least one step at anytime in any course week, including those who go on to leave the course.<br>
                  <b>Returning Learners</b> are those who completed at least a step in at least two distinct course weeks. These do not have to be sequential or consecutive, nor completed in different calendar weeks.<br>
                  <b>Social Learners</b> are those who have posted at least one comment on any step. ") 
      h1 <- hc_add_series_xts(h1,Learners_xts, id = "df_Learners", name= "Learners", type="line",color ="#99DB34") 
      h1 <- hc_add_series_xts(h1,active_xts, id = "df_active", name= "Active Learners", type="line",color ="lightblue") 
      h1 <- hc_add_series_xts(h1,Social_xts, id = "df_Social", name= "Social Learners", type="line",color ="#DB7834") 
      h1 <- hc_add_series_xts(h1,Returning_xts, id = "df_Returning", name= "Returning Learners", type="line",color ="lightpink") 
      
      h1 <- hc_add_series_flags(h1,dates,name = "Flags",
                                title = c("Course started", "Course finished"), 
                                text = c("Start date of the course", "End date of the course"),
                                id = "df_Learners")
      h1 <- hc_add_theme(h1,hc_theme_flat()) 
      h1 <- hc_exporting(h1,enabled = TRUE)
      h1 <- hc_legend(h1,enabled = TRUE)
      h1 <- hc_rangeSelector(h1, allButtonsEnabled = F,
                        buttons = list( list(
                          type= 'all',
                          text= 'All')),
                        buttonTheme= list(width =  60))
      
      return(h1)
  })
  
}

shinyApp(ui = ui, server = server)
