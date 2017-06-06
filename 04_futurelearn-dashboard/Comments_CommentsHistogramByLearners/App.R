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
  headerPanel("Comments by Learners"),
  h4( "This chart shows the number of comments made by different number of learners."),
  fluidRow(showOutput("CommentsHistogramByLearners", "nvd3")) #polycharts
)

server <- function(input, output, session) {
  
  source("../config.R")
  
  getComments <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_CommentsHistogramByLearners")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      return(data)
    }
  })
  
  
  output$CommentsHistogramByLearners <- renderChart({
    histSummary <- getComments()
   
    Histogram1 <- nPlot(x='comments',y='participents',data=histSummary,type='multiBarChart')
    Histogram1$chart(showControls = F,margin = list(left = 100),tooltipContent = "#! function(key, x, y, e){ 
                     return  '' + y + ' learners made ' + x + ' comments.'
  } !#")
    Histogram1$yAxis(showMaxMin = FALSE, axisLabel = "The number of learners",tickFormat = "#! function(d){return d3.format(',f')(d)} !#")
    Histogram1$xAxis(axisLabel = 'The number of comments')
    Histogram1$addParams(dom = 'CommentsHistogramByLearners')
    
    
    return(Histogram1)
  })
  
}

shinyApp(ui = ui, server = server)

