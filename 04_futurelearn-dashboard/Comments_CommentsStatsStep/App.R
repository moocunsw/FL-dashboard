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
 fluidRow(highchartOutput("CommentsLikesStat")),
 fluidRow(showOutput("CommentsStatsStep", "highcharts")),
 fluidRow(showOutput("LikesCommentsStatsStep", "highcharts"))
)

server <- function(input, output, session) {
  
  source("../config.R")
  
  commentsStats <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_CommentsStatsStep")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      return(data)
    }
  })
  
  output$CommentsLikesStat <- renderHighchart(
    {
      data <- commentsStats()
      data$step <- as.character(data$step)
      highchart() %>% 
        hc_title(text = "Comments and Likes per Step") %>% 
        hc_subtitle(text = "This chart shows the number of comments and likes at any step.") %>%
        hc_xAxis(
          list(title = list(text = "Step"), categories = unique(data$step))
        ) %>%
        hc_yAxis(title = list(text = "Number of Comments and Likes"))%>%
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
          name = "Comments",
          data = data$freq_comment,
          draggableY = F,
          dragMinY = 0,
          type = "column",
          minPointLength = 2
        ) %>% 
        hc_add_series(
          name = "Likes",
          data = data$likes,
          draggableY = F,
          dragMinY = 0,
          type = "column",
          minPointLength = 2
        ) %>% 
        
        
        hc_add_theme(hc_theme_smpl())%>%
        hc_exporting(enabled = T)%>%
        hc_colors(c("lightblue","lightgreen"))
    }
  )
  
  output$CommentsStatsStep <- renderChart({
    fr <- commentsStats()
    
    fr$step <- as.character(fr$step)
    uniqueSteps <- unique(fr$step)
    
    h1 <- hPlot(freq_comment ~ step, 
                type = "column",
                data = fr,
                title = "Comments Statistics by Step",
                subtitle = "This chart shows the number of comments at any step."
    )
    h1$tooltip(formatter = "#! function(){return('<b>Step: </b>' +  this.x + '<br><b>Total Comments: </b>' + this.y);} !#")
    h1$xAxis(labels=list(rotation = 90, style = list(fontSize = '10px')), 
             categories = uniqueSteps,
             title = list(text = ""))
    h1$yAxis(title = list(text = "Number of comments"))
    h1$exporting(enabled = TRUE)
    h1$addParams(dom = 'CommentsStatsStep')
    h1$plotOptions(series = list(color = 'lightblue'))
    return(h1)
    
  })
  
  
  output$LikesCommentsStatsStep <- renderChart({
    fr <- commentsStats()
    
    fr$step <- as.character(fr$step)
    uniqueSteps <- unique(fr$step)
    
    h1 <- hPlot(likes ~ step, 
                type = "column",
                data = fr,
                title = "Likes Statistics by Step",
                subtitle = "This chart shows the number of likes on comments at any step."
    )
    h1$tooltip(formatter = "#! function(){return('<b>Step: </b>' +  this.x + '<br><b>Total likes: </b>' + this.y);} !#")
    h1$xAxis(labels=list(rotation = 90, style = list(fontSize = '10px')), 
             categories = uniqueSteps,
             title = list(text = ""))
    h1$yAxis(title = list(text = "Number of likes"))
    h1$exporting(enabled = TRUE)
    h1$addParams(dom = 'LikesCommentsStatsStep')
    h1$plotOptions(series = list(color = 'lightgreen'))
    return(h1)
    
  })
  
  
}

shinyApp(ui = ui, server = server)
