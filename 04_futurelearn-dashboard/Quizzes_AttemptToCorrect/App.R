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
library(shiny)
library(highcharter)
library(plyr)
library(dplyr)

ui <- fluidPage(
  fluidRow(highchartOutput("AttemptToCorrect")),
  fluidRow(HTML('<hr>'),highchartOutput("AttemptToCorrectPct"))
  )


server <- function(input, output, session) {
  source("../config.R")
  
  getAttemptToCorrect <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug <- query[['course']]
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_AttemptToCorrect")
      data = fetch(rs, n=-1)
      
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      return(data)
    }
  })
  
  
 
  output$AttemptToCorrect <- renderHighchart({
    
    data <- getAttemptToCorrect()
    unique.quiz <- unique(data$quiz_question)
    unique.attempts <- unique(data$attempt)
    all <- merge(unique.attempts,unique.quiz)
    colnames(all) <- c('attempt','quiz_question')
    data <- left_join(all,data, by=c('attempt','quiz_question'))
    
    data$quiz_question <- as.character(data$quiz_question)
    cols <- c("green","lightgreen","lightblue","darkorange",'red')
    
    h1 <- highchart() %>% 
      hc_chart(animation = FALSE) %>% 
      hc_title(text="Attempt To Correct")%>%
      hc_subtitle(text="The following chart shows the number of learners who correctly answered a quiz by the number of attempts for each question.")%>%
      hc_xAxis(title = list(text = "Quiz Questions"), categories = unique(data$quiz_question)) %>% 
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
        )%>%
      hc_colors(cols)%>%
      hc_legend(enabled = T,align = "right", verticalAlign = "middle", layout = "vertical") %>%
      hc_exporting(enabled = T)
    
    attempts <- unique(data$attempt)
    for(i in 1:length(attempts))
    {
      a <- attempts[i]
      h1 <- hc_add_series(h1,
                          name = a,
                          data = subset(data,attempt == a)$value,
                          type = "column",
                          minPointLength = 2
      ) 
    }
    
    return(h1)
  })
  
  
  output$AttemptToCorrectPct <- renderHighchart({
    
    data <- getAttemptToCorrect()
    
    unique.quiz <- unique(data$quiz_question)
    unique.attempts <- unique(data$attempt)
    all <- merge(unique.attempts,unique.quiz)
    colnames(all) <- c('attempt','quiz_question')
    data <- left_join(all,data, by=c('attempt','quiz_question'))
    data[is.na(data$value),]$value <- 0
    data$quiz_question <- as.character(data$quiz_question)
    total.attempts <- ddply(data,.(quiz_question),summarise,total=sum(value))
    data <- inner_join(data,total.attempts)
    data$pct <- round(data$value/data$total*100,2)
    cols <- c("green","lightgreen","lightblue","darkorange",'red')
    
    h1 <- highchart() %>% 
      hc_chart(animation = FALSE) %>% 
      hc_subtitle(text="The following chart shows the percentage of learners who correctly answered a quiz by the number of attempts for each question.")%>%
      hc_xAxis(title = list(text = "Quiz Questions"),categories = unique(data$quiz_question)) %>% 
      hc_yAxis(title = list(text = "The percentage of learners")
               ,max =100
               , labels = list(format='{value}%'))%>%
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
        )%>%
      hc_colors(cols)%>%
      hc_legend(enabled = T,align = "right", verticalAlign = "middle", layout = "vertical") %>%
      hc_plotOptions(column=list(dataLabels=list(enabled=T,format='{y}%')))%>%
      hc_exporting(enabled = T)%>%
      hc_tooltip(valueSuffix='%')
    
    attempts <- unique(data$attempt)
    for(i in 1:length(attempts))
    {
      a <- attempts[i]
      h1 <- hc_add_series(h1,
                          name = a,
                          data = subset(data,attempt == a)$pct,
                          type = "column",
                          minPointLength = 2
      ) 
    }
    
    h1  
    
  })
  
}

shinyApp(ui = ui, server = server)
