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
library(shiny)
library(plyr)
library(dplyr)

ui <- fluidPage(
  fluidRow(showOutput("CommentsStatsByStepRole", "highcharts"))
)

server <- function(input, output, session) {
  
  source("../config.R")
  
  commentsStats <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_CommentsStatsByStepRole")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      data[,6:7] <- matrix(as.numeric(unlist(strsplit(as.character(data$step), split = "[.]"))), ncol=2, byrow=TRUE)
      data <- data[with(data,order(data$V6,data$V7)), ]
      data[,6:7] <- list(NULL)
      
      return(data)
    }
  })
  
  output$CommentsStatsByStepRole <- renderChart({
    fr <- commentsStats()
    
    roles <- unique(fr$role)
    steps <- unique(fr$step)
    
    h1 <- Highcharts$new()
    h1$xAxis(labels=list(rotation = 90),
              categories = steps ,
              title = list(text = 'Step'))
    
    h1$yAxis(title = list(text = 'Total number of comments'))
    fr$y <- fr$comments
    empty.steps <- data.frame(step=steps)
    empty.steps$x <- rownames(empty.steps)
    empty.steps$x <- as.integer(empty.steps$x) - 1 
    
    for(i in 1:length(roles))
    {
      role = roles[i]
      tmp <- fr[fr$role==role,]
      tmp <- left_join(empty.steps,tmp,by="step")
      tmp$y <- replace(tmp$y,is.na(tmp$y),0)
      tmp$y <- as.integer(tmp$y)
      tmp$x <- as.integer(tmp$x)
      h1$series(name = role, type='column', data= toJSONArray2(tmp, json = F,names = T))
    }
    
     
    h1$title(text = "Comments Statistics by Step and Role")
    h1$subtitle(text = "This chart shows the number of comments at any step given by learners or educators.")
    h1$tooltip(borderWidth=0, followPointer=TRUE, followTouchMove=TRUE, shared = F,
                formatter = "#! function(args)
               {return ('<b>Step: </b>' + this.x + 
               '<br><b>Total number of comments by '+this.series.name+': </b>' + this.y +
               '<br><b>Total number of likes by '+this.series.name+': </b>' + this.point.total_likes +
               '<br><b>Average number of likes by '+this.series.name+': </b>' + this.point.mean_likes); }
                !#")
    
    h1$exporting(enabled = TRUE)
    h1$addParams(dom = 'CommentsStatsByStepRole')
    return(h1)
    
  })
  
  
}

shinyApp(ui = ui, server = server)
