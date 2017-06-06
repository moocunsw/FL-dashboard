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
library(highcharter)
library(RMySQL)


ui <- fluidPage(
  fluidRow(showOutput("VisitedFirstStepFinishedAllSteps", "highcharts"))
) 

server <- function(input, output, session) {
  
  source("../config.R", local = TRUE)
  source("../utilities.R", local = TRUE)
  
  
  result <-  function(x) 
  { if(is.na(as.numeric(x)) == F)
  {if (x>0) return('positive') 
    if (x<0) return('negative') 
    return('neutral')}
  }
  
  findResults <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_VisitedFirstStepFinishedAllSteps")
      fr = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      return(fr)
    }
  })
  
  observe(
    {
      data <- findResults()
      data$week_number <- as.character(data$week_number)
      data$pct <- round(data$finished/data$total,2)*100
      print(summary(data))
    }
  )
  
  
  output$VisitedFirstStepFinishedAllSteps <- renderChart(
    {
      query <- parseQueryString(session$clientData$url_search)
      if (!is.null(query[['course']]))
      {
        
        withProgress(message = 'Reading Data...', value = 0, {
          
          data <- findResults()
          
          data$week_number <- paste('Week ',data$week_number,sep = "")
          data$pct <- round(data$finished/data$total,2)*100
          
          h1 <- Highcharts$new()
          h1$xAxis(categories = unique(data$week_number) ,
                   title = list(text = 'Week')
          )
          
          h1$yAxis(list(
            list(title = list(text = 'Total number of learners', style = list(color = "lightblue"))
                 , labels = list(style = list(color = "lightblue"))),
            list(title = list(text = 'Percentage of learners finished all steps', style = list(color = "lightgreen"))
                 , opposite = T, min = 0, max = 100, showLastLabel = F
                 , labels = list(style = list(color = "lightgreen")))
          ))
          h1$plotOptions(column = list(stacking = "normal"), line=list(dataLabels=list(enabled=T,format='{y}%')))
          h1$series(name = 'Learners visited first step', type='column', data= toJSONArray2(data.frame(y=data$total), json = F,names = T), color='lightblue', xAxis=0, yAxis=0)
          h1$series(name = 'Learners finished all steps', type='column', data= toJSONArray2(data.frame(y=data$finished), json = F,names = T), color='#FFC133', xAxis=0, yAxis=0)
          h1$series(name = 'Percentage', type='line', data= toJSONArray2(data.frame(y=data$pct), json = F,names = T), color='lightgreen', xAxis=0, yAxis=1)
          
          h1$title(text = "Learners analysis on their continuity")
          h1$subtitle(text = "This chart shows the number of learners who visited the first step for each week and finished all the steps afterwards. The green line shows the percentage of such students.")
          h1$addParams(dom = "VisitedFirstStepFinishedAllSteps")
          h1$exporting(enabled = T)
          
      })
        return(h1)
    }
    })
  
  
}

shinyApp(ui, server)
