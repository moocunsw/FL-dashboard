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

require(shiny)
library(RMySQL)
require(visNetwork)
library(plyr)
library(dplyr)

ui <- fluidPage(
  fluidRow(
  h4("This network shows the transition of learners among materials of all weeks. 
     The network is created from the first time the learner visited any step at each week. 
     The thickness of each arrow is based on the total number of visits between the weeks. 
     If hover on the edge it shows the number of learners transited from the source to the target (that is perceivable from the arrow). ")),
  fluidRow(uiOutput("outputSlider")),
  fluidRow(column(width=12,style='border-style: solid;border-color: #000000'
                  ,visNetworkOutput("network")))
)

server <- function(input, output, session) {
  source("../config.R", local = TRUE)
  source("../utilities.R", local = TRUE)
  
  findResults <- eventReactive(session$clientData$url_search,{
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_NetworkAnalysisByStep")
      df.sum = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      df.sum <- subset(df.sum,source != 'NA')
      df.sum[,4:5] <- do.call(rbind,strsplit(as.character(df.sum$source),'[.]') )
      df.sum[,5:6] <- do.call(rbind,strsplit(as.character(df.sum$target),'[.]') )
      df.sum[,6] <- NULL
      df.sum.week <- subset(df.sum,select=c("V4","V5","value"))
      colnames(df.sum.week) <- c("source","target","value")
      df.sum.week <- ddply(df.sum.week,.(source,target), summarise, value = sum(value))
      
      return(df.sum.week)
    }
  })
  
  output$outputSlider <- renderUI(
    {
      results <- findResults()
      min <- min(results$value)
      max <- max(results$value)
      sliderInput("dataRange","Select the value range for the number of transitions", min = min, max = max,
                  value = c(min,max), width = 600)
    }
  )
  
  filterResult <- eventReactive(input$dataRange,
  {
    df.sum.week <- findResults()
    return(subset(df.sum.week,value >= input$dataRange[1] & value <= input$dataRange[2] ))
  })
  
  findCompletedbyWeek <- eventReactive(session$clientData$url_search,
  {
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from step_activity")
      step_activity = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      fun <- function(x) sum(is.na(x)==F)
      result <- ddply(step_activity,.(week_number), colwise(fun ,.(last_completed_at)))
      colnames(result) <- c("week","completed")
      result$week <- as.character(result$week)
      return(result)
    }
  })
  
  output$network <- renderVisNetwork({
    df.sum.week <- filterResult()
    result <- findCompletedbyWeek()
    # minimal example
    c <- df.sum.week$source
    n <- length(unique(c))
    ids <- data.frame(week=unique(c), id = 1:n)
    ids$week <- as.character(ids$week)
    node.value <- ddply(df.sum.week,.(source),summarise,value = sum(value))
    node.value$source <- as.character(node.value$source)
    ids <- inner_join(ids,node.value,by= c("week"="source"))
    ids <- inner_join(ids,result, by = "week")
    
    colors <- c("lightpink", "grey", "orange", "lightblue", "red","lightgreen","purple")
    
    m <- length(unique(node.value$source))
    colors <- data.frame(week=ids$week,color=colors[1:m])
    colors$week <- as.character(colors$week)
    ids <- inner_join(colors,ids,by=c('week'='week')) 
    ids$label <- paste("Week", ids$week)
    
    nodes <- data.frame(id = ids$week, 
                        label = ids$label ,
                        value = ids$value,
                        shape = "circle", 
                        color = ids$color,# color
                        title = paste("Steps completion at<b>",ids$label,"</b>:",ids$completed)
    )                  # shadow
    edges <- data.frame(from = df.sum.week$source, 
                        to = df.sum.week$target,
                        value = df.sum.week$value,
                        arrows = c("to"),
                        smooth = list(enabled = TRUE, type = "diagonalCross"),
                        color = list(hover = "green"),
                        #dashes = c(TRUE, FALSE),
                        title = paste('<b>Week',df.sum.week$source,'</b> &#8594; <b>Week',df.sum.week$target,"</b>:",df.sum.week$value,"visits"))                                 # tooltip (html or character))
    visNetwork(nodes, edges)%>% 
      visIgraphLayout(randomSeed = 123,layout = "layout_in_circle")%>% 
      visNodes(scaling = list(label = list(enabled = T)))
    
     })
}



shinyApp(ui = ui, server = server)