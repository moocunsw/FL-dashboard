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
library(shiny)

ui <- fluidPage(
  fluidRow(showOutput("EnrolmentsByWeek", "highcharts"))
)

server <- function(input, output, session) {
  
source("../config.R")
  
  EnrolmentsByWeek <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug <- query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_EnrolmentsByWeek")
      enrolments = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      return(enrolments)
    }
  })
  
 
  
  output$EnrolmentsByWeek <- renderChart({
      data <- EnrolmentsByWeek()
      data$week_number <- as.character(data$week_number)
      
      h1 <- hPlot(cum ~ week_number, data = data, type = 'line', radius = 6)
      
      h1$yAxis(tickInterval = 50,
               title = list(text = 'The number of learners'))
      h1$xAxis(title = list(text = 'Week'), categories = unique(data$week_number))
      
      h1$tooltip(borderWidth=0, followPointer=TRUE, followTouchMove=TRUE, shared = TRUE,
                 formatter = "#! function()
                 { return 'Week ' + this.x + '<br>Enrolments: ' + this.y ;
                 }
                 
                 !#")
      h1$title(text= "Enrolment cumulative growth by week")
      h1$subtitle(text= "This chart shows the accumulative number of enrollments per week.")
      h1$exporting(enabled = TRUE)
      h1$addParams(dom = 'EnrolmentsByWeek')
      return(h1)
  })
  
}

shinyApp(ui = ui, server = server)
