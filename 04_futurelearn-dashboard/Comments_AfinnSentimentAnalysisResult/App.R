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

library(plyr)
library(dplyr)
library(rCharts)
library(shiny)
library(RMySQL)


ui <- fluidPage(
  fluidRow(showOutput("AfinnSentimentAnalysisResult", "highcharts"))
) 

server <- function(input, output, session) {
  
  source("../config.R", local = TRUE)
  source("../utilities.R",local=T)
  
  doSentimentAnalysis <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_AfinnSentimentAnalysisResult")
      fr = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      fr$sentiment <- lapply(fr$score,result)
      fr$sentiment <- as.character(fr$sentiment)
      step_score <- ddply(fr,.(step,sentiment),dplyr::summarize,freq=n())
      step_score[,4:5] <- matrix(as.numeric(unlist(strsplit(as.character(step_score[,1]), "[.]"))), ncol=2, byrow=TRUE)
      step_score <- step_score[with(step_score,order(step_score[,4],step_score[,5])), ]
      step_score <- step_score[with(step_score,order(desc(step_score[,2]))), ]
      step_score[,4:5] <- list(NULL,NULL)
      
      step_score$freq <- ifelse(step_score$sentiment == "negative", -1 * step_score$freq, step_score$freq)
      step_score.sub <- subset(step_score, step_score$sentiment == "negative" | step_score$sentiment == "positive")
      return(step_score.sub)
      
    }})
  
  
  output$AfinnSentimentAnalysisResult <- renderChart(
    {
      query <- parseQueryString(session$clientData$url_search)
      if (!is.null(query[['course']]))
      {
        
        withProgress(message = 'Reading Data...', value = 0, {
          
          css <- doSentimentAnalysis()
          
          
          h1 <- hPlot(
            y = 'freq', 
            x = 'step', 
            type = 'bar', 
            data = css,
            group = 'sentiment',
            title = "Sentiment Analysis on Comments",
            subtitle ='<a href="http://neuro.imm.dtu.dk/wiki/AFINN">Afinn Method</a> has been used to find the sentiment score of comments. ')
          
          h1$plotOptions(series = list(stacking = 'normal'))
          
          h1$tooltip(formatter = "#! function() { return '<b>Step:</b> '+ this.point.category +
                     '<br>' + '<b>The number of ' + this.series.name + ' comments: </b>' + 
                     Highcharts.numberFormat(Math.abs(this.point.y), 0);} !#")
          
          h1$legend(reversed = "true")
          
          h1$xAxis(categories = unique(css$step),
                   title = list(text = 'Step'))
          h1$yAxis(labels = list(formatter = "#! function() { return (Math.abs(this.value));} !#"),
                   title = list(enabled = TRUE, text = 'The total number of comments'))
          
          
          h1$colors(c('lightpink', 'lightgreen'))
          
          
          h1$exporting(enabled = TRUE)
          
          
          
      })
        h1$addParams(dom = 'AfinnSentimentAnalysisResult')
        h1$chart(height=700)
        return(h1)
    }
    })
}

shinyApp(ui, server)
