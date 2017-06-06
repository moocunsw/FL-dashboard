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
library(tidyr)
library(shiny)
library(highcharter)
library(plyr)
library(dplyr)
library(DT)

ui <- fluidPage(
  fluidRow( highchartOutput("ActivityByStep")),
  fluidRow( htmlOutput("caption"),DT::dataTableOutput('ActivityTable')),
  fluidRow( HTML('<hr>'),highchartOutput("ActivityByStepPcst"))
  )


server <- function(input, output, session) {
  source("../config.R")
  
  stepSummary <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug <- query[['course']]
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_ActivityByStep")
      data = fetch(rs, n=-1)
      
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      return(data)
    }
  })
  
  output$caption <- renderUI(
    {
      HTML("<hr><br>The following table shows the detail of step activities. 
       The Completion, Visits, Comments and Likes are the number of completed steps, 
       the number of visited (includes completed)
       and the number of comments and likes by learners respectively.<hr>")
    }
  )
 
  output$ActivityByStepPcst <- renderHighchart({
    
    stepSummary <- stepSummary()
    gat <- gather(stepSummary,variable, value, Completions:Likes) 
    stepSummaryMelted <- gat[,c(1,4,5)]
    
    cols <- c("lightblue","darkorange")
    
    
    h1 <- highchart() %>% 
      hc_chart(animation = FALSE) %>% 
      hc_title(text = "Visits and Completion by Step") %>% 
      hc_subtitle(text = "The following chart shows the percentage of each group of activities for every step. 
       'Visits' shows the percentage of those who visited but not completed.") %>% 
      hc_xAxis(categories = unique(stepSummaryMelted$Step)) %>% 
      hc_yAxis(title = list(text = "The number of learners"))%>%
      hc_tooltip(yDecimals = 2, shared = T) %>% 
      hc_plotOptions(
        series = list(
          point = list(
            events = list(
              drop = JS("function(){
                        alert(this.series.name + ' ' + this.category + ' ' + Highcharts.numberFormat(this.y, 2))
  }")
        )
              ),
        stickyTracking = FALSE,
        stacking = "percent"
            ),
        column = list(
          stacking = "normal"
        ),
        line = list(
          cursor = "ns-resize"
        )
        ) %>% 
      hc_add_series(
        name = "Visits",
        data = subset(stepSummaryMelted,variable == "Visits")$value,
        type = "column",
        minPointLength = 2
      ) %>% 
      hc_add_series(
        name = "Completions",
        data = subset(stepSummaryMelted,variable == "Completions")$value,
        type = "column",
        minPointLength = 2
      ) %>% 
      hc_colors(cols)%>%
      hc_exporting(enabled = T)
    
    return(h1)
  })
  
  output$ActivityByStep <- renderHighchart({
    
    stepSummary <- stepSummary()
    gat <- gather(stepSummary,variable, value, Completions:Likes) 
    stepSummaryMelted <- gat[,c(1,4,5)]
    
    cols <- c("green","orange","lightblue","darkorange")
    
    
    h1 <- highchart() %>% 
      hc_chart(animation = FALSE) %>% 
      hc_title(text = "Activity by Step") %>% 
      hc_subtitle(text = "The following chart shows the number of each activity for every step.
       'Visits' shows the number of visitors but not completed the step.") %>% 
      hc_xAxis(categories = unique(stepSummaryMelted$Step)) %>% 
      hc_yAxis(title = list(text = "The number of learners"))%>%
      hc_tooltip(yDecimals = 2, shared = T) %>% 
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
        ) %>% 
      hc_add_series(
        name = "Likes",
        data = subset(stepSummaryMelted,variable == "Likes")$value,
        type = "column",
        minPointLength = 2
      ) %>%
      hc_add_series(
        name = "Comments",
        data = subset(stepSummaryMelted,variable == "Comments")$value,
        
        type = "column",
        minPointLength = 2
      ) %>% 
      hc_add_series(
        name = "Visits",
        data = subset(stepSummaryMelted,variable == "Visits")$value,
        type = "column",
        minPointLength = 2
      ) %>% 
      hc_add_series(
        name = "Completions",
        data = subset(stepSummaryMelted,variable == "Completions")$value,
        type = "column",
        minPointLength = 2
      ) %>% 
      hc_colors(cols)%>%
      hc_legend(enabled = T,align = "right", verticalAlign = "middle", layout = "vertical") %>%
      hc_exporting(enabled = T)
    
    return(h1)
  })
  
  output$table <- renderTable({
    stepSummary <- stepSummary()
    stepSummary
  })
  
  output$ActivityTable <- renderDataTable(
    {
     stepSummary <- stepSummary()
      stepSummary
    }
    ,extensions = 'Buttons',
    options = list(
      "dom" = 'T<"clear">lBfrtip',
      buttons = list('copy', 'csv', 'excel', 'pdf', 'print')
    ))
}

shinyApp(ui = ui, server = server)
