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
library(plyr)
library(dplyr)
library(rCharts)
library(shiny)

ui <- fluidPage(
  fluidRow(
  showOutput("QuestionResponseOverview", "highcharts")))


server <- function(input, output, session) {
  source("../config.R",local = TRUE)
  
  QuestionResponseOverview <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_QuestionResponseOverview")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      return(data)
    }
  })
  
  output$QuestionResponseOverview <- renderChart(
    {
      totalScoresByLearner <- QuestionResponseOverview()
      totalScoresByLearner$totalPercentage <- totalScoresByLearner$totalPercentage * 100
      histScoresByLearner <- ddply(totalScoresByLearner,.(totalPercentage),summarise,freq = n())
      
      
      h1 <- hPlot(freq~totalPercentage, 
                  type = "area",
                  data = histScoresByLearner,
                  title = "Question Response Overview",
                  subtitle = "This chart shows the number of learners by the overall percentage of answering the question correctly. The data is normalised for all learners based on dividing the total questions for each quiz to the total number of attempts for the quiz."
      )
      h1$tooltip(borderWidth = 0,formatter = "#! function(){return(this.y + ' learners answered correctly the %' + this.x + ' of all questions.');} !#")
      h1$xAxis(title = list(text = "Percentage of all questions"))
      h1$yAxis(title = list(text = "Number of learners"))
      h1$exporting(enabled = TRUE)
      h1$addParams(dom = 'QuestionResponseOverview')
      return(h1)
    }
  )
}

shinyApp(ui = ui, server = server)
