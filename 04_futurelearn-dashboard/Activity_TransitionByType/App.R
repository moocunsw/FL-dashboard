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
  h4("This network shows the transition of learners among materials of all weeks based on the step type. 
     The step type comes from the label which is shown in the course page that has been designed by the educators.
     The network is created from the first time the learner visited any step at each week. 
     The thickness of each arrow is based on the total number of visits among the step types. 
     The size of each node is based on the total number of visits that initiated from that step type.
     If hover on the edge it shows the number of learners transited from the source to the target (that is perceivable from the arrow). ")),
  fluidRow(uiOutput("outputSlider")),
  fluidRow(column(width=12,style='border-style: solid;border-color: #000000'
                  , visNetworkOutput("network")))
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
      
      df.sum$source <- as.character(df.sum$source)
      df.sum$target <- as.character(df.sum$target)
      
      step_types <- getStepTypeByCourse(courseSlug)
      df.sum <- inner_join(df.sum,step_types,by=c("source"="step"))
      colnames(df.sum) <- c("source","target","value","source_type")
      df.sum <- inner_join(df.sum,step_types,by=c("target"="step"))
      colnames(df.sum) <- c("source","target","value","source_type","target_type")
      
      df.sum.type <- ddply(df.sum,.(source_type,target_type),summarise,value=sum(value))
      
      c <- step_types$type
      n <- length(unique(c))
      ids <- data.frame(type=unique(c), id = 1:n)
      df.sum.type <- inner_join(df.sum.type,ids,by=c("source_type"="type"))
      colnames(df.sum.type) <- c("source_type","target_type","value","source")
      df.sum.type <- inner_join(df.sum.type,ids,by=c("target_type"="type"))
      colnames(df.sum.type) <- c("source_type","target_type","value","source","target")
      
      return(df.sum.type)
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
                                           
                                           step_types <- getStepTypeByCourse(courseSlug)
                                           step_activity <- inner_join(step_activity,step_types)
                                           
                                           fun <- function(x) sum(is.na(x)==F)
                                           result <- ddply(step_activity,.(type), colwise(fun ,.(last_completed_at)))
                                           colnames(result) <- c("type","completed")
                                           return(result)
                                         }
                                       })
  
  output$network <- renderVisNetwork({
    
    df.sum.type <- filterResult()
    result <- findCompletedbyWeek()
    
    
    ids <- subset(df.sum.type[ ! duplicated( df.sum.type[ c("source_type" , "source") ] ) , ], select = c("source_type" , "source"))
    colnames(ids) <- c("type","id")
    ids <- ids[order(ids[,2]), ]
    
    node.value <- ddply(df.sum.type,.(source_type),summarise,value = sum(value))
    total = sum(node.value$value)
    node.value$pct <- round(node.value$value/total*100)
    node.value$source_type <- as.character(node.value$source_type)
    ids <- inner_join(ids,node.value,by= c("type"="source_type"))
    ids <- inner_join(ids,result, by = "type")
    
    
    # Set the color of nodes based on week
    colors <- c("chocolate","lightpink","plum", "grey", "orange", 
                "lightblue", "red","aquamarine","coral","lightgreen")
    
    m <- length(unique(node.value$source_type))
    colors <- data.frame(type=ids$type,color=colors[1:m])
    colors$type <- as.character(colors$type)
    ids <- inner_join(colors,ids,by=c('type'='type')) 
    
    nodes <- data.frame(id = ids$id,
                        label = paste(ids$type,"(",ids$pct,"%)",sep=""),
                        value = ids$value,
                        shape = "dot", 
                        title = paste("Completion of step type <b>",ids$type,"</b>:",ids$completed),
                        color= ids$color
    )      
    edges <- data.frame(from = df.sum.type$source, 
                        to = df.sum.type$target,
                        value = df.sum.type$value,
                        arrows = c("to"),
                        smooth = list(enabled = TRUE, type = "diagonalCross"),
                        color = list(hover = "green"),
                        
                        title = paste('<b>',df.sum.type$source_type,'</b> &#8594; <b>',df.sum.type$target_type,'</b> :',df.sum.type$value,"visits"))                                # tooltip (html or character))
    visNetwork(nodes, edges)%>% 
      visIgraphLayout(randomSeed = 123,layout = "layout_in_circle") %>% 
      visNodes(scaling = list(label = list(enabled = T)))
    
  })
}



shinyApp(ui = ui, server = server)