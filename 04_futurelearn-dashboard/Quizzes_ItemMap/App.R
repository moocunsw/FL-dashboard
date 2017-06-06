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
  fluidRow(showOutput("ItemMap", "highcharts"))
)


server <- function(input, output, session) {
  
  source("../config.R")
  
  getFirstItemMap <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_FirstItemMap;")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      return(data)
    }
  })
  
  getLastItemMap <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_LastItemMap;")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      return(data)
    }
  })
  
  output$ItemMap <- renderChart({
    
    data <-getFirstItemMap() 
    last <- getLastItemMap()
    
    data$question <- as.character(data$question)
    last$question <- as.character(last$question)
    data$difficulty <- round(data$difficulty,2)
    last$difficulty <- round(last$difficulty,2)
    
    questions <- full_join(data,last, by = c("question" = "question"))
    questions[,2:4] <- matrix(as.numeric(unlist(strsplit(as.character(questions[,1]), "[.]"))), ncol=3, byrow=TRUE)
    questions <- questions[with(questions,order(questions[,2],questions[,3],questions[,4])), ]
    questions[2:4] <- list(NULL)
    questions <- questions$question
    
    # The highcharts needs two columns i.e. x and y.
    # We set each of these columns appropriatly.
    # Also y columns have to be index of y axises. 
    # So we use the index from the level of this column.
    
    last$y <- last$question
    for(i in 1:length(last$y))
    {
      last$y[i] <- which(questions == last$question[i])-1
    }
    levels(last$y) <- last$y
    
    data$y <- data$question
    for(i in 1:length(data$y))
    {
      data$y[i] <- which(questions == data$question[i])-1
    }
    levels(data$y) <- data$y
    
    data$x <- data$difficulty
    last$x <- last$difficulty
    data$y <- as.integer(data$y)
    last$y <- as.integer(last$y)
    
    hm2 <- rCharts:::Highcharts$new()
    hm2$title(text = "Item Map")
    hm2$subtitle(text = "A 'Person-Item Map' shows how these two parameters relate. We would generally expect learner ability to fall within a normal distribution. Questions (shown on a scale of difficulty) discriminates across the full spectrum of ability. The 'First Attempt' ('Last Attempt') data set shows the result of Rasch model by considering the first (last) attempt of learners.")
    hm2$xAxis(list(
      list(title = list(text = 'Difficulty by first attempt')), 
      list(title = list(text = 'Difficulty by last attempt'), opposite=TRUE)
    ))
    hm2$yAxis(categories = questions,
              title = list(text = "Questions"))
    hm2$chart(type = 'scatter',height = 1000)
    hm2$series(name = 'First Attempt', xAxis = 0,
               data= toJSONArray2(data, json = F), 
               color='lightblue')
    hm2$series(name = 'Last Attempt', xAxis = 1,
               data= toJSONArray2(last, json = F), 
               color='lightpink')
    hm2$tooltip(borderWidth=0, followPointer=TRUE, followTouchMove=TRUE, shared = FALSE,
                formatter = "#! function()
                { 
                return this.series.name + '<br><b>Question: </b>' +this.series.yAxis.categories[this.point.y] + '<br><b>Difficulty: </b>' + this.point.x;
                }
                
                !#")
    
    hm2$exporting(enabled = T)
    hm2$addParams(dom = 'ItemMap')
   
    return(hm2)
    })
  
}


shinyApp(ui = ui, server = server)