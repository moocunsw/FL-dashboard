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
library(plyr)
library(dplyr)
library(highcharter)

ui <- fluidPage(
  fluidRow(highchartOutput("StepVisitedDuringQuizAttemptPct")),
  fluidRow(highchartOutput("StepVisitedDuringQuizAttempt"))
  )


server <- function(input, output, session) {
  source("../config.R")
  
  getVisitedOtherStepsDuringQuiz <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug <- query[['course']]
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_VisitedOtherStepsDuringQuiz")
      data = fetch(rs, n=-1)
      
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      summary <- ddply(data,.(`visited_week_number`,`visited_step_number`,visited_step),summarise,visits=n())
      summary <- summary[with(summary,order(summary[,1],summary[,2])), ]
      totals <- ddply(summary,.(visited_week_number),summarise,total=sum(visits))
      summary <- inner_join(summary,totals,by='visited_week_number')
      summary$pct <- round(summary$visits/summary$total*100,2)
      
      
      return(summary)
    }
  })
  
  
 
  output$StepVisitedDuringQuizAttemptPct <- renderHighchart({
    
    summary <- getVisitedOtherStepsDuringQuiz()
    m <- round(max(summary$pct)+1)
    if(m > 100)
      m = 100
    h1 <- highchart(type = "chart")
    h1 <- hc_title(h1, text = "Step Visited During Quiz Attemp")
    h1 <-   hc_subtitle(h1, text = "This chart shows the percentage of the visited step per week when a learner visited such step during answering a quiz question. The coloring is based on the week since the percentage is calculated per total visits in each week.")
    # create axis :)
    h1 <-   hc_yAxis(h1,max=m,min=0,labels=list(format='{value}%'))
      
    h1 <-   hc_xAxis(h1, 
        title = list(text = "Step"), categories = summary$visited_step      )
 
      # series :D
      h1 <-   hc_add_series_df(h1, data=summary,y=pct,name = "Visits",type='column',color = visited_week_number)
      h1 <-   hc_exporting(h1, enabled = T) 
      # I <3 themes
      h1 <-   hc_add_theme(h1, hc_theme_smpl())
      h1 <- hc_tooltip(h1,formatter = JS("function() { return '<b>Step:</b> '+ this.point.category +
                     '<br>' + '<b>The percentage of visits to the step per week during a quiz attempt: </b>' + 
                     this.point.y+ '%';} "))
    return(h1)
  })
  
  
  output$StepVisitedDuringQuizAttempt <- renderHighchart({
    
    summary <- getVisitedOtherStepsDuringQuiz()
    
    h1 <- highchart(type = "chart")
    h1 <- hc_title(h1, text = "Step Visited During Quiz Attemp")
    h1 <-   hc_subtitle(h1, text = "This chart shows the number of the visits to each step when a learner visited such step during answering a quiz question.")
    # create axis :)
    h1 <-   hc_yAxis(h1,max=round(max(summary$visits)+1),min=0)
    
    h1 <-   hc_xAxis(h1, 
                     list(title = list(text = "Step"), categories = summary$visited_step)
    )
    
    # series :D
    
    h1 <-   hc_add_series(h1, data=summary$visits,name = "Visits",type='column')
    h1 <-   hc_exporting(h1, enabled = T) 
    h1 <- hc_legend(h1,enabled=F)
    # I <3 themes
    h1 <-   hc_add_theme(h1, hc_theme_smpl())
    h1 <- hc_tooltip(h1,formatter = JS("function() { return '<b>Step:</b> '+ this.point.category +
                     '<br>' + '<b>Visits: </b>' + 
                     this.point.y;} "))
    return(h1)
  })
  
}

shinyApp(ui = ui, server = server)
