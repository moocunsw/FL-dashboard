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
library(plyr)
library(dplyr)
library(shiny)
library(reshape2)

ui <- fluidPage(
  fluidRow(h4('This chart shows the number of learners who spend different minutes in each step.'),
           h4('The minute spent is calculated based on the first time a learner visited any step and the last time the learner completed the step. The learners have to complete an step to be included in this chart.'),
           showOutput("MinutesSpendByStep", "nvd3")),
  fluidRow(hr(h4('This chart shows the percentage of learners who spend different minutes in each week.')),
           h4('The minute spent is calculated based on the first time a learner visited any step and the last time the learner completed the step. The learners have to complete an step to be included in this chart.'),
            showOutput("MinutesSpendByStepPct", "nvd3"))
  ) 


server <- function(input, output, session) {
  source("../config.R",local = TRUE)
  
  MinutesSpendByStep <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_MinutesSpendByStep")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      return(data)
    }
  })
  
  getStepActivity <- reactive(
    {
      query <- parseQueryString(session$clientData$url_search)
      if (!is.null(query[['course']]))
      {
        courseSlug = query[['course']]
        mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
        rs = dbSendQuery(mydb,"select * from step_activity; ")
        step_activity = fetch(rs, n=-1)
        dbClearResult(rs)
        dbDisconnect(mydb)
        return(step_activity)
      }
    }
  )
  
  output$MinutesSpendByStepPct <- renderChart({
    data <- MinutesSpendByStep()
    totalByStep <- ddply(data,.(step),summarise,total=sum(freq))
    data <- inner_join(data,totalByStep,by='step')
    data$pct <- data$freq/data$total
    
    n2 <- nPlot(pct ~ step, group = 'delta', data = data, type = 'multiBarChart')
    n2$yAxis(axisLabel = 'Learners',tickFormat = "#! function(d) {return d3.format('.0%')(d)} !#")
    n2$xAxis(tickFormat = "#! function(d) {return 'Step ' + d} !#")
    n2$chart(showControls = F,stacked = TRUE, tooltipContent = "#! function(key, x, y, e){ 
              if(key == 'more than an hour'){return  y + ' learners spent ' + key + ' at ' + x;}
             return  y + ' of learners spent ' + key + ' minute at ' + x;
  } !#")
    n2$addParams(dom = "MinutesSpendByStepPct")
    
    return(n2)
  })
  
  output$MinutesSpendByStep <- renderChart({
    MinutesSpendByStep <- MinutesSpendByStep()
    
    n2 <- nPlot(freq ~ step, group = 'delta', data = MinutesSpendByStep, type = 'multiBarChart')
    n2$yAxis(axisLabel = 'Learners',tickFormat = "#! function(d) {return d3.format('.0')(d)} !#")
    n2$xAxis(tickFormat = "#! function(d) {return 'Step ' + d} !#")
    n2$chart(showControls = F,stacked = TRUE, tooltipContent = "#! function(key, x, y, e){ 
            if(key == 'more than an hour'){return  y + ' learners spent ' + key + ' at ' + x;}
            return  y + ' learners spent ' + key + ' minute at ' + x;
  } !#")
    n2$set(title = "Minutes Spend By Step")
    n2$addParams(dom = "MinutesSpendByStep")
  
    return(n2)
  })
  
  }

shinyApp(ui = ui, server = server)

