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
library(shiny)
library(DT)

ui <- fluidPage(
  headerPanel("Rasch Analysis"),
  mainPanel(
    h4("Rasch modelling can be used to produce a logistical representation of both learner ability and question difficulty. This data is based upon quiz/test performance for all students, taking only their first/last attempt at each question."),
    DT::dataTableOutput('RaschAnalysisSummary')
    
    ))


server <- function(input, output, session) {
  source("../config.R")
  
 
  FirstRaschAnalysisSummary <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug <- query[['course']]
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_FirstRaschAnalysisSummary;")
      data = fetch(rs, n=-1)
      
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      return(data)
    }
  })
  
  LastRaschAnalysisSummary <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug <- query[['course']]
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_LastRaschAnalysisSummary;")
      data = fetch(rs, n=-1)
      
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      return(data)
    }
  })
  
  output$RaschAnalysisSummary <- DT::renderDataTable(
    {
      first <- FirstRaschAnalysisSummary()
      last <- LastRaschAnalysisSummary()
      first$Difficulty <- round(first$Difficulty,2)
      last$Difficulty <- round(last$Difficulty,2)
      RaschAnalysisSummary <- merge(first, last, by = c("Metrics"="Metrics"))
      colnames(RaschAnalysisSummary) <- c("Metrics", "First Attempt","Last Attempt")
      
      dt <- DT::datatable(
        RaschAnalysisSummary,
        rownames = FALSE,
        options = list(dom = 'RaschAnalysisSummary')
      )
      return(dt)
     
    }
  )
}

shinyApp(ui = ui, server = server)
