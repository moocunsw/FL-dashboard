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
library(highcharter)
library(plyr)
library(dplyr)
library(shiny)


ui <- fluidPage(
  fluidRow(highchartOutput("WordCountSummary")),
  fluidRow(highchartOutput("StepSummary"))
)

server <- function(input, output, session) {
  
  source("../config.R")
  
  getSummary <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_CommentsStatsByEducators")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      data$author_id <- paste(data$first_name,data$last_name) 
      
      
      return(data)
    }
  })
  
  
  
  output$WordCountSummary <- renderHighchart({
    
    data <- getSummary()
    data <- ddply(data, .(author_id), dplyr::summarise, total =n())
    commentsSummary <- data[order(-data[,2]),]
    
    h1<-   
      highchart() %>% 
      hc_title(text = "The number of Comments made by Educators") %>% 
      hc_subtitle(text=paste("This chart shows the number of comment made by different educators.",sep = "")) %>%
      hc_legend(enabled = FALSE) %>% 
      hc_xAxis(labels=list(rotation = -30, style = list(fontSize = '10px')),
               title = list(text = "Educators"),
               categories = commentsSummary$author_id) %>% 
      hc_yAxis(
        title = list(text = "The number of comments"),
          align = "left",
          showFirstLabel = FALSE,
          showLastLabel = FALSE
        
      ) %>% 
      hc_add_series(name = "Comments", type = "column",
                    data = as.list(commentsSummary$total)) %>%
      hc_exporting(enabled = TRUE) 
    
    
    return(h1)
  })
  
  output$StepSummary <- renderHighchart({
    
    data <- getSummary()
    data <- ddply(data, .(author_id,step), dplyr::summarise, total =n())
    
    commentsSummary <- data[order(data[,1], -data[,3]), ]
    
    commentsSummary$step <- as.character(commentsSummary$step)
    
    uniqueAuthors <- unique(commentsSummary$author_id)
    uniqueSteps <- unique(commentsSummary$step)
    
    steps <- data.frame(step = uniqueSteps)
    steps[,2:3] <- matrix(as.numeric(unlist(strsplit(as.character(steps[,1]), "[.]"))), ncol=2, byrow=TRUE)
    steps <- steps[order(steps[,2], steps[,3]), ]
    
    h1<-   
      highchart() %>% 
      hc_title(text = "The number of Comments made by Educators per Step") %>% 
      hc_subtitle(text=paste("This chart shows the number of comment made by different educators per step.",sep = "")) %>%
      hc_legend(enabled = T) %>% 
      hc_tooltip( shared = T) %>%
      hc_xAxis(labels=list(rotation = -30, style = list(fontSize = '10px')),
               title = list(text = "Step"),
               categories = steps$step) %>% 
      hc_yAxis(
        title = list(text = "The number of comments"),
          align = "left",
          showFirstLabel = FALSE,
          showLastLabel = FALSE
        
      ) %>% 
      hc_exporting(enabled = TRUE) %>% 
    hc_plotOptions(
        series = list(
          point = list(
            events = list(
              drop = JS("function(){
                        alert(this.series.name + ' ' + this.category + ' ' + Highcharts.numberFormat(this.y, 2))
  }")
        )
              ),
        stickyTracking = FALSE
            ),
        column = list(
          stacking = "normal"
        ),
        line = list(
          cursor = "ns-resize"
        )
        ) 
      
    
    
    for(i in 1:length(uniqueAuthors))
    {
      author <- uniqueAuthors[i]
      tmp <- commentsSummary[commentsSummary$author_id == author, ]
      tmp <- left_join(steps,tmp,by=c("step"="step"),all.y=TRUE)
      h1 <- hc_add_series(h1,name = author,
                    data = as.list(tmp$total)
                    , type= "column")
    }
    
    return(h1)
  })
  
}

shinyApp(ui = ui, server = server)

