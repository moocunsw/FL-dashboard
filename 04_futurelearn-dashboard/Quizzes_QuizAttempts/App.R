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

ui <- fluidPage(
  fluidRow(highchartOutput("QuizAttempts")),
  fluidRow(highchartOutput("QuizAttemptsStack"))
  )


server <- function(input, output, session) {
  source("../config.R")
  
  getQuizAttempts <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug <- query[['course']]
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_QuizAttempts")
      data = fetch(rs, n=-1)
      
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      return(data)
    }
  })
  
  
 
  output$QuizAttempts <- renderHighchart({
    
    summary <- getQuizAttempts()
    
    correctSummary <- subset(summary, correct == "Correct")
    incorrectSummary <- subset(summary, correct == "Incorrect")
    
    
    h1 <- highchart(type = "chart")
    h1 <- hc_title(h1, text = "Quiz Attempts")
    h1 <-   hc_subtitle(h1, text = "This chart shows the number of correct and incorrect attempts for each quiz question.")
    # create axis :)
    h1 <-   hc_yAxis_multiples(h1, 
        list(title = list(text = "The number of correct attempts"))
        ,list(title = list(text = "The number of incorrect attempts"), opposite = TRUE)
      )
    h1 <-   hc_xAxis(h1, 
        list(title = list(text = "Quiz question"), categories = unique(summary$quiz_question))
      )
 
      # series :D
      h1 <-   hc_add_series_labels_values(h1, incorrectSummary$quiz_question, incorrectSummary$attempts, 
                                  type = "column", yAxis = 0, name = "Incorrect attempts")
      h1 <-   hc_add_series_labels_values(h1, correctSummary$quiz_question, correctSummary$attempts, 
                                  type = "column", yAxis = 1, name = "Correct attempts")  
      h1 <-   hc_exporting(h1, enabled = T) 
      h1 <- hc_colors(h1,c("lightpink","lightgreen"))
      # I <3 themes
      h1 <-   hc_add_theme(h1, hc_theme_smpl())
    return(h1)
  })
  
  
  output$QuizAttemptsStack <- renderHighchart({
    
    summary <- getQuizAttempts()
    
    correctSummary <- subset(summary, correct == "Correct")
    incorrectSummary <- subset(summary, correct == "Incorrect")
    
    
    h1 <- highchart(type = "chart")
    h1 <- hc_title(h1, text = "Quiz Attempts")
    h1 <-   hc_subtitle(h1, text = "This chart shows the number of correct and incorrect attempts for each quiz question.")
    # create axis :)
    h1 <-   hc_yAxis(h1, 
                     title = list(text = "The number of attempts")
                     #,list(title = list(text = "The number of incorrect attempts"), opposite = TRUE)
    )
    h1 <-   hc_xAxis(h1, 
                     list(title = list(text = "Quiz question"), categories = unique(summary$quiz_question))
    )
    h1 <- hc_plotOptions(h1,
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
    # series :D
    h1 <-   hc_add_series_labels_values(h1, incorrectSummary$quiz_question, incorrectSummary$attempts, 
                                        type = "column", yAxis = 0, name = "Incorrect attempts")
    h1 <-   hc_add_series_labels_values(h1, correctSummary$quiz_question, correctSummary$attempts, 
                                        type = "column", yAxis = 0, name = "Correct attempts")  
    
    h1 <-   hc_exporting(h1, enabled = T) 
    h1 <- hc_colors(h1,c("lightpink","lightgreen"))
    # I <3 themes
    h1 <-   hc_add_theme(h1, hc_theme_smpl())
    return(h1)
  })
  
}

shinyApp(ui = ui, server = server)
