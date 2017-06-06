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
  h4("This network shows the transition of learners among materials for the selected week. 
     The network is created from the first time the learner visited any step at each week. 
     The thickness of each arrow is based on the total number(percentage) of visits between the steps. 
     If hover on the edge it shows the number of learners (percentage) transited from the source to the target (that is perceivable from the arrow).",
     br("It is possible to switch among percentage, the total number and the simplified options.")
    
     )),
  fluidRow(column(width = 3,radioButtons("pct_num", "Percentage or total number:"
                        , c("Percentage (The percentage option shows the percentage of visits from each step of the selected week to any other step in the course.)"
                            , "Number (The number option shows the total number of transitions among all steps of the selected week.)"
                            , "Simplified(The simplified option shows the percentage of visits from each step to another within a week.)"
                            )
                        ))
           , column(width = 3, uiOutput("choose_week"))
           , column(width = 3, uiOutput("choose_step"))
           ),
  fluidRow(
           column(width = 12, style='border-style: solid;border-color: #000000'
                  , visNetworkOutput("network"))
           )
)

server <- function(input, output, session) {
  source("../config.R", local = TRUE)
  source("../utilities.R", local = TRUE)
  
  getCourseSlug <- eventReactive(session$clientData$url_search,{
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      return(courseSlug)
    }
  })
  
  findResults <- reactive({
      courseSlug = getCourseSlug()
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_NetworkAnalysisByStep")
      df.sum = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      df.sum <- subset(df.sum,source != 'NA')
      df.sum[,4:5] <- do.call(rbind,strsplit(as.character(df.sum$source),'[.]') )
      df.sum[,5:6] <- do.call(rbind,strsplit(as.character(df.sum$target),'[.]') )
      df.sum[,6] <- NULL
      
      return(df.sum)
    
  })
  
  getTotalVisistsByStep <- eventReactive(session$clientData$url_search,
                                         {
                                           courseSlug = getCourseSlug()
                                           mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
                                           rs = dbSendQuery(mydb, "select * from step_activity")
                                           data = fetch(rs, n=-1)
                                           dbClearResult(rs)
                                           dbDisconnect(mydb)
                                           
                                           summary <- ddply(data,.(step),summarise,value=n())
                                           return(summary)
                                         }
  )
  
  get_num_weeks <- reactive({
      courseSlug = getCourseSlug()
      db_detail = findDBNameVersion(courseSlug)
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=db_name, host=db_host)
      rs = dbSendQuery(mydb, paste("call futurelearn_courses_information.get_duration_week_by_course('",db_detail$database,"','", db_detail$version ,"');",sep = ""))
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      return(data$duration_week)
    
  })
  
  data_sets <- c("All")
  data.sets.week <- c()
  
  # Drop-down selection box for which data set
  output$choose_week <- renderUI({
    n <- get_num_weeks()
    for(i in 1:n)
    {
      data.sets.week <- c(data.sets.week, as.character(i))
    }

    selectInput("week", "Choose a week number", as.list(data.sets.week), selected = 1)
    
   
  })
  
  output$choose_step <- renderUI({
    result <- findResultsNumber()
    c <- unique(result$source)
    
    data_sets <- c(data_sets,c)
    selectInput("step", "Choose a step number or all steps", as.list(data_sets))
    
  })
  
  findResultsPct <- eventReactive(input$week,
                                  {
                                    # Select only all nodes that has step from the given week
                                    df.sum <- findResults()
                                    week <- input$week
                                    df.sum <- df.sum[df.sum$V4 == week, ]
                                    df.sum[,4:5] <- list(NULL)
                                    
                                    return(df.sum)
                                  }
  )
  
  prepareDatasetPct <- reactive(
                                  {
                                    
                                    df.sum <- findResultsPct()
                                    
                                    step = input$step
                                    
                                    totals <- ddply(df.sum,.(source),summarise, total = sum(value))
                                    df.sum <- inner_join(df.sum,totals,by=c("source"="source"))
                                    df.sum$pct <-  round(df.sum$value/df.sum$total,2)*100
                                    df.sum$total <- NULL
                                    
                                    df.sum <- subset(df.sum,pct > 0)
                                    
                                    if(step != "All")
                                    {
                                      df.sum <- subset(df.sum,source == step)
                                    }
                                    
                                    # Put the id of each step in the source and target filed to be used by
                                    # the visNetwork function
                                    df.sum$source <- as.character(df.sum$source)
                                    df.sum$target <- as.character(df.sum$target)
                                    c <- df.sum$source
                                    d <- df.sum$target
                                    
                                    c <- unique(c(as.vector(c), as.vector(d)))
                                    n <- length(c)
                                    ids <- data.frame(step=c, id = 1:n)
                                    
                                    
                                    df.sum <- inner_join(df.sum,ids,by=c("source"="step"))
                                    colnames(df.sum) <- c("source_step","target","value","pct","source")
                                    df.sum <- inner_join(df.sum,ids,by=c("target"="step"))
                                    colnames(df.sum) <- c("source_step","target_step","value","pct","source","target")
                                    
                                    return(df.sum)
                                  })
  
  findResultsNumber <- eventReactive(input$week,
                                  {
                                    # Select only all nodes that has step from the given week
                                    df.sum <- findResults()
                                    week <- input$week
                                    df.sum <- df.sum[df.sum$V4 == week & df.sum$V5 == week, ]
                                    df.sum[,4:5] <- list(NULL)
                                    
                                    return(df.sum)
                                  }
  )
  
  prepareDataset <- reactive(
                                  {
                                    # Select only all nodes that has step from the given week
                                  
                                    df.sum <- findResultsNumber()
                                    step = input$step
                                    
                                    if(step != "All")
                                    {
                                      df.sum <- subset(df.sum,source == step)
                                    }
                                    
                                    # Put the id of each step in the source and target filed to be used by
                                    # the visNetwork function
                                    df.sum$source <- as.character(df.sum$source)
                                    df.sum$target <- as.character(df.sum$target)
                                    c <- df.sum$source
                                    d <- df.sum$target
                                    
                                    c <- unique(c(as.vector(c), as.vector(d)))
                                    n <- length(c)
                                    ids <- data.frame(step=c, id = 1:n)
                                    
                                    df.sum <- inner_join(df.sum,ids,by=c("source"="step"))
                                    colnames(df.sum) <- c("source_step","target","value","source")
                                    df.sum <- inner_join(df.sum,ids,by=c("target"="step"))
                                    colnames(df.sum) <- c("source_step","target_step","value","source","target")
                                    
                                    total <- sum(df.sum$value)
                                    df.sum$pct <- round(df.sum$value/total,2)*100
                                    return(df.sum)
                                  })
  
  prepareIdsNumber <- reactive({
    df.sum <- prepareDataset()
    
    # Set the size of the node based on the sum of outgoing weight
    c <- df.sum$source_step
    d <- df.sum$target_step
    
    c <- unique(c(as.vector(c), as.vector(d)))
    n <- length(c)
    ids <- data.frame(step=c, id = 1:n)
    
    ids$step <- as.character(ids$step)
    node.value <- getTotalVisistsByStep()
    ids <- left_join(ids,node.value,by= "step")
    
    courseSlug = getCourseSlug()
    
    types <- getStepTypeByCourse(courseSlug)
    ids <- left_join(ids,types, by ="step")
    
    # Set the color of nodes based on week
    colors <- c("chocolate","lightpink","plum", "grey", "orange", 
                "lightblue", "red","aquamarine","coral","lightgreen",
                "blueviolet","bisque","cyan","gold","blueviolet",
                "firebrick","darkseagreen","burlywood","olivedrab","darkgray",
                "deepskyblue","darkorange","lightskyblue","lightsalmon","navajowhite",
                "azure","lightcyan","indianred","salmon","green",
                "lavenderblush")
    
    
    colors <- data.frame(step=ids$step,color=colors[1:n])
    colors$step <- as.character(colors$step)
    ids <- inner_join(colors,ids,by=c('step'='step'))      
    return(ids)
  })
  
  prepareIdsPct <- reactive({
    df.sum <- prepareDatasetPct()
    
    # Set the size of the node based on the sum of outgoing weight
    c <- df.sum$source_step
    d <- df.sum$target_step
    
    c <- unique(c(as.vector(c), as.vector(d)))
    n <- length(c)
    ids <- data.frame(step=c, id = 1:n)
    
    ids$step <- as.character(ids$step)
    node.value <- getTotalVisistsByStep()
    ids <- left_join(ids,node.value,by= "step")
    
    courseSlug = getCourseSlug()
      
    types <- getStepTypeByCourse(courseSlug)
    ids <- left_join(ids,types, by ="step")
    
    # Set the color of nodes based on week
    colors <- c("chocolate","lightpink","plum", "grey", "orange", 
                "lightblue", "red","aquamarine","coral","lightgreen",
                "blueviolet","bisque","cyan","gold","blueviolet",
                "firebrick","darkseagreen","burlywood","olivedrab","darkgray",
                "deepskyblue","darkorange","lightskyblue","lightsalmon","navajowhite",
                "azure","lightcyan","indianred","salmon","green",
                "lavenderblush")
    
    
    colors <- data.frame(step=ids$step,color=colors[1:n])
    colors$step <- as.character(colors$step)
    ids <- inner_join(colors,ids,by=c('step'='step'))      
    return(ids)
  })
  
  
  output$network <- renderVisNetwork({
    
    validate(
      need(input$week, 'Please select a week number')
    )

    
    if(input$pct_num == "Number (The number option shows the total number of transitions among all steps of the selected week.)" 
       | input$pct_num == "Simplified(The simplified option shows the percentage of visits from each step to another within a week.)")
    {
      
      df.sum <- prepareDataset()
      ids <- prepareIdsNumber()
      
      if(input$pct_num == "Simplified(The simplified option shows the percentage of visits from each step to another within a week.)")
      {
        df.sum <- subset(df.sum,pct > 0)
      }
      
      nodes <- data.frame(id = ids$id,
                          label = ids$step,
                          value = ids$value,
                          shape = "circle", 
                          title = paste(ids$step,'(',ids$type,') visits: ',ids$value,sep = ''),
                          color= ids$color
      )      
      
        edges <- data.frame(from = df.sum$source, 
                        to = df.sum$target,
                        value = df.sum$value,
                        arrows = c("to"),
                        smooth = list(enabled = TRUE, type = "diagonalCross"),
                        color = list(hover = "green"),
                        
                        title = paste('<b>Step',df.sum$source_step,'</b> &#8594; <b>Step',df.sum$target_step,"</b>:",df.sum$value,"visits<br>Or",
                                      df.sum$pct,'% of visits in the Week', input$week))                            
    
    
       return(visNetwork(nodes, edges)%>% visIgraphLayout(randomSeed = 123,layout = "layout_in_circle") %>% 
                visNodes(scaling = list(label = list(enabled = T))))
    }
    
    else
    {
      
      df.sum.pct <- prepareDatasetPct()
      idsPct <- prepareIdsPct()
      
      nodes.pct <- data.frame(id = idsPct$id,
                          label = idsPct$step,
                          value = idsPct$value,
                          shape = "circle", 
                          title = paste(idsPct$step,'(',idsPct$type,') visits: ',idsPct$value,sep = ''),
                          color= idsPct$color
      )      
      
      edges.pct <- data.frame(from = df.sum.pct$source, 
                              to = df.sum.pct$target,
                              value = df.sum.pct$pct,
                              arrows = c("to"),
                              smooth = list(enabled = TRUE, type = "diagonalCross"),
                              color = list(hover = "green"),
                              
                              #dashes = c(TRUE, FALSE),
                              title = paste('<b>Step ',df.sum.pct$source_step,'</b> &#8594; <b>Step ',df.sum.pct$target_step, '</b>:',df.sum.pct$value,
                                            ' visits<br>Or ',df.sum.pct$pct,'% of visits from <b>Step ',df.sum.pct$source_step,'</b>',sep =''))                                 # tooltip (html or character))
      return(visNetwork(nodes.pct, edges.pct)  %>% 
             visIgraphLayout(randomSeed = 123,layout = "layout_in_circle")%>% 
               visNodes(scaling = list(label = list(enabled = T))))
      
    }
  })
}



shinyApp(ui = ui, server = server)