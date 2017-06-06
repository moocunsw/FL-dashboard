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
  headerPanel("Word count analysis of comments"),
  h4( "This chart shows the number of comments by all participants containing different number of words."),
  fluidRow(showOutput("WordCountSummary", "nvd3")),
  fluidRow(highchartOutput("WordCountScatter"))
)

server <- function(input, output, session) {
  
  source("../config.R")
  
  getComments <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from comments")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      # Source : http://stackoverflow.com/questions/8920145/count-the-number-of-words-in-a-string-in-r
      data$wordCount <- sapply(gregexpr("[[:alpha:]]+", data$text), function(x) sum(x > 0))
      
      WordCountSummary <- ddply(data, .(wordCount), summarise, Words =n())
      
      return(WordCountSummary)
    }
  })
  
  
  
  output$WordCountSummary <- renderChart({
    WordCountSummary <- getComments()
    
    Histogram1 <- nPlot(x='wordCount',y='Words',data=WordCountSummary,type='multiBarChart')
    Histogram1$chart(showControls = F,margin = list(left = 100),tooltipContent = "#! function(key, x, y, e){ 
  return  '' + e.point.Words + ' comments have ' + e.point.wordCount + ' words.'
                 } !#")
    Histogram1$yAxis(showMaxMin = FALSE, axisLabel = "The number of comments",tickFormat = "#! function(d){return d3.format(',f')(d)} !#")
    Histogram1$xAxis(axisLabel = 'The number of words')
    Histogram1$set(title = "Word count analysis of comments")
    Histogram1$addParams(dom = 'WordCountSummary')
    
    return(Histogram1)
  })
  
  output$WordCountScatter <- renderHighchart(
    {
      WordCountSummary <- getComments()
      ds <- list_parse2(WordCountSummary)
      
      
      highchart() %>% 
        hc_add_theme(hc_theme_538()) %>% 
        hc_yAxis(showMaxMin = FALSE, title = list(text="The number of comments"),tickFormat = "#! function(d){return d3.format(',f')(d)} !#") %>% 
        hc_xAxis(title = list(text='The number of words')) %>% 
        hc_add_series(data = ds, name = "WordCount", type = "scatter", color = "lightblue")%>%
        hc_tooltip( formatter = JS("function(){
                                   return (this.y + ' comments had ' + this.x + ' words')
    }")) 
    }
  )
  
}

shinyApp(ui = ui, server = server)

