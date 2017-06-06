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
library(DT)

ui <- fluidPage(
  headerPanel("N-step Transition by Step Type"),
  
  h4("The following chart shows the transitions of learners among steps. The data is prepared by finding all different consequence steps' transition of learners (e.g. if you choose 3 as the depth, one of the transition is 1.1->1.2->1.3), then find the type of each step (e.g. Video (1st)->Article (2nd)->Quiz (3rd)).
     The chart shows the total number of visits from each step type to another considering all n-step transitions in the course.
     You can choose the n from the dropdown. The depth numbers are those n-steps that majority of learners has visited such sequence."),
  fluidRow(uiOutput("choose_depth")),
  fluidRow(showOutput("Transition3StepsByType", "d3_sankey")),
  fluidRow(h4("The following table shows the top 10 frequent paths:"),DT::dataTableOutput('Top10Table',width = 600))
  
)


server <- function(input, output, session) {
  
  source("../config.R")
  source("../utilities.R")
  
  getNetwork <- eventReactive(session$clientData$url_search,
    {
      query <- parseQueryString(session$clientData$url_search)
      if (!is.null(query[['course']]))
      {
      courseSlug = query[['course']]
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_NetworkAnalysisByLearners;")
      df = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      df$value <- NULL
      df$group <- NULL
      
      types <- getStepTypeByCourse(courseSlug)
      df <- inner_join(df,types,by=c("source"="step"))
      colnames(df) <- c("learner_id", "source" , "target", "source_type"  )
      df <- inner_join(df,types,by=c("target"="step"))
      colnames(df) <- c("learner_id", "source" , "target", "source_type", "target_type"  )
     
      df <- ddply(df, .(learner_id), mutate, id = order(source))
      sub.df <- subset(df,select = c("learner_id","id","source","source_type","target","target_type"))
      return(sub.df)
     
      }
    }
  )
  
  getSliderTicks <- eventReactive(session$clientData$url_search,{
    df <- getNetwork()
    learners <- ddply(df,.(learner_id), summarise, depth = n())
    learners <- learners[order(-learners[,2]),] 
    learners.depth <- ddply(learners,.(depth), summarise, freq= n())
    
    learners.depth.gte.mean <- subset(learners.depth,freq >= round(mean(learners.depth$freq)))
    learners.depth.gte.mean <- subset(learners.depth.gte.mean,depth > 1)
    learners.depth.gte.mean$depth <- round(learners.depth.gte.mean$depth)
    return(learners.depth.gte.mean)
  })
  
  data_sets <- c("Choose the number of steps in a path")
  
  # Drop-down selection box for which data set
  output$choose_depth <- renderUI({
    df <- getSliderTicks()
    for(i in 1:nrow(df))
    {
      data_sets <- c(data_sets, as.character(df$depth[i]))
    }
    
    selectInput("depth", "Choose a depth number", as.list(data_sets))
    
  })
  
  getPaths <- eventReactive(input$depth,{
    # If missing input, return to avoid error later in function
    if(is.null(input$depth) | input$depth == "Choose the number of steps in a path")
      return()
    sub.df <- getNetwork()
    three_path_type <- sub.df
    path <- as.integer(input$depth)
    suffix = c("(1st)","(2nd)","(3rd)","(4th)","(5th)","(6th)","(7th)","(8th)","(9th)","(10th)")
    
    suffix = c("(1st)","(2nd)","(3rd)")
    if(path > 3)
    {
      i = 4
      while(i <= path)
      {
        suffix <- c(suffix, paste("(",i,"th)",sep = ""))
        i = i+1
      }
    }
    
    for(i in 1:(path-2))
    {
      
      three_path_type <- inner_join(three_path_type,sub.df,by=c("target"="source","learner_id"="learner_id"))
      three_path_type$source_type.y <- NULL
      three_path_type$id.y <- NULL
      colnames(three_path_type)[2] <- "id"
      three_path_type <- subset(three_path_type, id == 1)
      n <- length(three_path_type)
      colnames(three_path_type)[(n-3):n] <- c(paste("middle",i,sep="") ,paste("middle",i,"_type",sep=""),"target","target_type")
      colnames(three_path_type)[4] <- "source_type"
      
    }
    
    three_path_type$source_type <- paste(three_path_type$source_type,suffix[1],sep = "")
    three_path_type$target_type <- paste(three_path_type$target_type,suffix[path],sep = "")
    
    for(i in 2:(path-1))
    {
      col.name = paste("middle",i-1,"_type",sep="")
      
      three_path_type[,which(colnames(three_path_type) == col.name)] <- paste(three_path_type[,which(colnames(three_path_type) == col.name)], suffix[i],sep="")
      
    }
    
    return(three_path_type)
  })
  
  getFinalNetwork <- eventReactive(input$depth,{
    # If missing input, return to avoid error later in function
    if(is.null(input$depth) | input$depth == "Choose the number of steps in a path")
      return()
   three_path_type <- getPaths()
   
   path <- as.integer(input$depth)
   n = length(colnames(three_path_type))
   cols <- colnames(three_path_type)
   i = 1
   j = 4
   gb = c(cols[j])
   j = 6
   df.sum.type <- data.frame(source_type=character(0),middle1_type=character(0),value=integer(0))
   tmp <- data.frame(source=character(0),target=character(0),value=integer(0))
   
   while(i < path)
   {
     gb <- c(gb, cols[j])
     j = j + 2
     tmp2 <- ddply(three_path_type,gb,summarise,value = n())
     
     if(length(gb) == 2)
     {
       df.sum.type <- tmp2
       colnames(tmp2) <- c("source","target","value")
       tmp <- rbind(tmp2,tmp)
     }
     else
     {
       tmp3<- inner_join(df.sum.type,tmp2, by = gb[1:(length(gb)-1)])
       tmp3$value.x <- NULL
       colnames(tmp3)[length(colnames(tmp3))] <- "value"
       df.sum.type <- tmp3
       tmp3 <- subset(tmp3,select=tail(colnames(tmp3),3))
       colnames(tmp3) <- c("source","target","value")
       tmp <- rbind(tmp3,tmp)
     }
     i = i + 1
   }
   
   tmp <- ddply(tmp,.(source,target), summarise, value = sum(value))
   
      return(tmp)
    
  })
  
  
  output$Transition3StepsByType <- renderChart({
       validate(
      need(input$depth, 'Please select the number of steps in a path')
    )
    withProgress(message = 'Calculation in progress',{
    tmp <-getFinalNetwork() 
    
    print(head(tmp))
    
    # To render the js script for sankey:
    #Source: https://github.com/timelyportfolio/rCharts_d3_sankey/issues/3
    
    sankeyPlot <- rCharts$new()
    sankeyPlot$setLib('http://timelyportfolio.github.io/rCharts_d3_sankey/')
    sankeyPlot$setTemplate(script = 'http://timelyportfolio.github.io/rCharts_d3_sankey/libraries/widgets/d3_sankey/layouts/chart.html')
    sankeyPlot$set(
      data = tmp,
      nodeWidth = 10,
      nodePadding = 5,
      layout = 32,
      width = 1000,
      height = 400
    )
    sankeyPlot$addParams(dom = 'Transition3StepsByType')
    
    return(sankeyPlot)
    })
    })
  
  output$Top10Table <- renderDataTable(
    {
       validate(
        need(input$depth, 'Please select the number of steps in a path')
      )
      
      # Source Code: http://stackoverflow.com/questions/25554068/saving-from-shiny-renderdatatable
      df <- getPaths()
      path = as.integer(input$depth)
      
      suffix = c("1st","2nd","3rd")
      if(path > 3)
      {
        i = 4
        while(i <= path)
        {
          suffix <- c(suffix, paste(i,"th",sep = ""))
          i = i+1
        }
      }
      
      cols <- colnames(df)
      i = 1
      j = 4
      gb = c(cols[j])
      j = 6
      cols.name = c()
      while(i < path)
      {
        gb <- c(gb, cols[j])
        cols.name <- c(cols.name, paste(suffix[i],"Step Type"))
        j = j + 2
        i = i + 1
      }
      cols.name <- c(cols.name, c(paste(suffix[i],"Step Type"),"Total Visits"))
      
      # print(cols.name)
      # print(gb)
      df <- ddply(df,gb,summarise,value = n())
      df <- df[order(-df[,length(colnames(df))]),]
      colnames(df) <- cols.name
      
      top_n(df,10)
      
    },extensions = 'Buttons',
    options = list(
      "dom" = 'T<"clear">lBfrtip',
      buttons = list('copy', 'csv', 'excel', 'pdf', 'print')
    )
  )
  
}


shinyApp(ui = ui, server = server)