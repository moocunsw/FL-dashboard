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
  fluidRow(column=4,highchartOutput("gender",width = "400px",height = "600px")) #polycharts
)

server <- function(input, output, session) {
  
source("../config.R", local = T)
source("../utilities.R", local = T)
  
  genderSummary <- eventReactive(session$clientData$url_search,{
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from enrolments")
      enrolments = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      learners = subset(enrolments, role == "learner")
      genderSummary <- ddply(learners, .(gender), dplyr::summarise, total =n())
      
      return(genderSummary)
    }
  })
  
  
  output$gender <- renderHighchart({
      df <- genderSummary()
      
      total = sum(df$total)
      df = subset(df, gender != "Unknown")
      filled = sum(df$total)
      pct <- round(filled/total,2)* 100
      
      if("other" %in% df$gender)
      {
        other <- subset(df,gender == "other", select=c("total"))
        df$total <- ifelse(df$gender == "nonbinary", other$total + df$total, df$total)
      }
      df$pct <- round(df$total/filled,2)*100
      df <- subset(df,gender %in% c("female","male","nonbinary"))
      
      h1 <- 
        highchart(width = 400, height = 400) %>% 
        hc_chart(
          type = "solidgauge",
          backgroundColor = "#F0F0F0",
          marginTop = 50
        ) %>% 
        hc_title(
          text = "Gender",
          style = list(
            fontSize = "24px"
          )
        ) %>% 
        hc_subtitle(text=paste("This chart shows the percentage of gender distribution among learners based on the pre-survey information. 
                    Only ", pct, "% of learners have given their gender. In another word, ",filled," learners out of ",total, " learners revealed their gender.",sep = "")) %>%
        
        hc_tooltip(
          borderWidth = 0,
          backgroundColor = 'none',
          shadow = FALSE,
          style = list(
            fontSize = '16px'
          ),
          pointFormat = '{series.name}<br><span style="font-size:2em; color: {point.color}; font-weight: bold">{point.y}%</span>',
          positioner = JS("function (labelWidth, labelHeight) {
                          return {
                          x: 200 - labelWidth / 2,
                          y: 280
                          };
  }")
    ) %>% 
        hc_pane(
          startAngle = 0,
          endAngle = 360,
          background = list(
            list(
              outerRadius = '112%',
              innerRadius = '88%',
              backgroundColor = JS("Highcharts.Color('#ffe6f0').setOpacity(1).get()"),
              borderWidth =  0
            ),
            list(
              outerRadius = '87%',
              innerRadius = '63%',
              backgroundColor = JS("Highcharts.Color('#e6f5ff').setOpacity(1).get()"),
              borderWidth = 0
            ),
            list(
              outerRadius = '62%',
              innerRadius =  '38%',
              backgroundColor = JS("Highcharts.Color('#f2ccff').setOpacity(0.1).get()"),
              borderWidth = 0
            )
          )
        ) %>% 
        hc_yAxis(
          min = 0,
          max = 100,
          lineWidth = 0,
          tickPositions = list()
        ) %>% 
        hc_plotOptions(
          solidgauge = list(
            borderWidth = '34px',
            dataLabels = list(
              enabled = F
            ),
            linecap = 'round',
            stickyTracking = FALSE
          )
        ) %>% 
        hc_add_series(
          name = "Female",
          borderColor = JS("Highcharts.Color('#ff0066').setOpacity(1).get()"),
          data = list(list(
            color = JS("Highcharts.Color('#ff0066').setOpacity(1).get()"),
            radius = "100%",
            innerRadius = "100%",
            y = subset(df,gender == "female", select=c("pct"))$pct
          ))
        ) %>% 
        hc_add_series(
          name = "Male",
          borderColor = JS("Highcharts.Color('#0099ff').setOpacity(1).get()"),
          data = list(list(
            color = JS("Highcharts.Color('#0099ff').setOpacity(1).get()"),
            radius = "75%",
            innerRadius = "75%",
            y = subset(df,gender == "male", select=c("pct"))$pct
          ))
        )  %>% 
        hc_add_series(
          name = "Other",
          borderColor = JS("Highcharts.Color('#9900cc').setOpacity(1).get()"),
          data = list(list(
            color = JS("Highcharts.Color('#9900cc').setOpacity(1).get()"),
            radius = "50%",
            innerRadius = "50%",
            y = subset(df,gender == "nonbinary", select=c("pct"))$pct
          ))
        )%>%
        hc_exporting(enabled = TRUE)
      
      
      return(h1)
  })
  
}

shinyApp(ui = ui, server = server)
