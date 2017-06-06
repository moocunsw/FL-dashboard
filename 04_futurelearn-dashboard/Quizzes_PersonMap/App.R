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

ui <- fluidPage(
  fluidRow(showOutput("PersonMap", "highcharts"))
)


server <- function(input, output, session) {
  
  source("../config.R")
  
  getFirstPersonItemMap <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_FirstPersonItemMap;")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      return(data)
    }
  })
  
  getLastPersonItemMap <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_LastPersonItemMap;")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      return(data)
    }
  })
  
  output$PersonMap <- renderChart({
    
    data <-getFirstPersonItemMap() 
    last <- getLastPersonItemMap()
    
    
    data$score <- round(data$score)
    first <- ddply(data,.(score), summarise, y= n())
    first$x <- round(first$score)
    
    last$score <- round(last$score)
    last <- ddply(last,.(score), summarise, y= n())
    last$x <- round(last$score)
    
    hm2 <- rCharts:::Highcharts$new()
    hm2$title(text = "Person Map")
    hm2$subtitle(text = "A Person-Item Map shows how these two parameters relate. We would generally expect learner ability to fall within a normal distribution. This chart shows the number of persons for each score. The 'First Attempt' ('Last Attempt') data set shows the result of Rasch model by considering the first (last) attempt of learners.")
    
    hm2$xAxis(list(
      list(title = list(text = 'Score by first attempt'), allowDecimals = FALSE), 
      list(title = list(text = 'Score by last attempt'), opposite=TRUE, allowDecimals = FALSE)
    ))
    
    hm2$yAxis(title = list(text = "Persons"), allowDecimals = FALSE)
    hm2$chart(type = 'column', height = 700)
    hm2$series(name = 'First Attempt', xAxis = 0,
               data= toJSONArray2(first, json = F), 
               color='lightblue')
    hm2$series(name = 'Last Attempt', xAxis = 1,
               data= toJSONArray2(last, json = F), 
               color='lightpink')
    hm2$tooltip(borderWidth=0, followPointer=TRUE, followTouchMove=TRUE, shared = FALSE,
                formatter = "#! function()
                { 
                return this.series.name +'<br><b>Total Learners: </b>' +this.point.y + '<br><b>Score: </b>' + this.point.x;
                }
                
                !#")
    
    hm2$exporting(enabled = T)
    hm2$addParams(dom = 'PersonMap')
    
    return(hm2)
    })
  
}


shinyApp(ui = ui, server = server)