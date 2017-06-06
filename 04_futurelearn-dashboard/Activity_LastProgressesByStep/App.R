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
library(highcharter)
library(plyr)
library(dplyr)
library(shiny)

ui <- fluidPage(
 
  fluidRow(highchartOutput("LastProgressesByStep"))
  ,fluidRow(highchartOutput("LastProgressesByWeek"))
  ) 


server <- function(input, output, session) {
  
  source("../config.R")
  
  LastProgressesByStep <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_LastProgressesByStep")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      data[,4:5] <- matrix(as.numeric(unlist(strsplit(as.character(data[,1]), "[.]"))), ncol=2, byrow=TRUE)
      colnames(data)[4:5] <- c('week_number','step_number')
      
      return(data)
    }
  })
  
  
  output$LastProgressesByStep <- renderHighchart({
    data <- LastProgressesByStep()
    h1<-  highchart(type = "chart") 
    h1 <- hc_title(h1,text = "Left and remained learners by step") 
    h1 <- hc_xAxis(h1,title=list(text='Step'),categories=data$step)
    h1 <- hc_yAxis_multiples(h1,
                             list(title = list(text = "The number of left learners",style = list(color = "lightpink")),
                                  align = "left",
                                  showFirstLabel = FALSE,
                                  showLastLabel = FALSE,
                                  labels = list(style = list(color = "lightpink"))
                             )
                             , list(title = list(text = "The number of remained learners",style = list(color = "lightgreen")),
                                    align = "right",
                                    opposite = T,
                                    showFirstLabel = FALSE,
                                    showLastLabel = FALSE,
                                    labels = list(style = list(color = "lightgreen")))
                             
    )
    h1 <- hc_subtitle(h1,text = "The pink column shows the number of learners who disengaged from the course at any step. 
                      The blue line shows the number of learners who visited the step and any other step afterwards. Such number is called as remained.") 
    h1 <- hc_add_series(h1,name='Leavers', type="column",color ="lightpink",data=data$freq,yAxis=0) 
    h1 <- hc_add_series(h1,name='Remained', type="column",color ="lightgreen",data=data$remained,yAxis=1)
    h1 <- hc_add_theme(h1,hc_theme_flat()) 
    h1 <- hc_exporting(h1,enabled = TRUE)
    h1 <- hc_legend(h1,enabled = TRUE)
    
    return(h1)
  })
  
  output$LastProgressesByWeek <- renderHighchart({
    data <- LastProgressesByStep()
    data <- ddply(data,.(week_number),summarise,freq=sum(freq))
    
    h1<-  highchart(type = "chart") 
    h1 <- hc_title(h1,text = "Left and remained learners by week") 
    h1 <- hc_xAxis(h1,title=list(text='Week'),categories=data$week_number)
    h1 <- hc_yAxis(h1,title = list(text = "The number of left learners",style = list(color = "lightpink")),
                                  align = "left",
                                  showFirstLabel = FALSE,
                                  showLastLabel = FALSE,
                                  labels = list(style = list(color = "lightpink"))
    )
    h1 <- hc_plotOptions(h1,column=list(dataLabels=list(enabled=T)))
    h1 <- hc_subtitle(h1,text = "The pink column shows the number of learners who disengaged from the course at any week.") 
    h1 <- hc_add_series(h1,name='Leavers', type="column",color ="lightpink",data=data$freq)
    h1 <- hc_add_theme(h1,hc_theme_flat()) 
    h1 <- hc_exporting(h1,enabled = TRUE)
    h1 <- hc_legend(h1,enabled = TRUE)
    
    return(h1)
  })
  
}

shinyApp(ui = ui, server = server)

