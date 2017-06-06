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
  fluidRow(column=4,highchartOutput("employment",height = 600)) #polycharts
)

server <- function(input, output, session) {
  
source("../config.R", local = T)
source("../utilities.R", local = T)
  
  employmentAreaSummary <- eventReactive(session$clientData$url_search,{
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
      learners_fully_participated = subset(learners, fully_participated_at != "<NA>")
      employmentAreaSummary <- ddply(learners, .(employment_area), dplyr::summarise, total = n())
      
      employmentAreaFullyParticipatedSummary <- ddply(learners_fully_participated, .(employment_area), summarise, fully =n())
      
      employmentAreaSummary <- left_join(employmentAreaSummary,employmentAreaFullyParticipatedSummary,by=c('employment_area'='employment_area'))
     
      return(employmentAreaSummary)
    }
  })
  
  
  output$employment <- renderHighchart({
      df <- employmentAreaSummary()
      
      total = sum(df$total)
      df = subset(df, employment_area != "Unknown")
      filled = sum(df$total)
      pct <- round(filled/total,2)* 100
      
      df <- df[order(-df[,2]),]
        
          
       h1<-   
         highchart() %>% 
         hc_title(text = "Employment areas distribution") %>% 
         hc_subtitle(text=paste("The blue bar chart shows the number of learners with different education levels based on the pre-survey information.
                                The pink line shows the number of fully participated learners who marked the majority of steps as complete including all of the assessments. 
                                Only ", pct, "% of learners have given their employment information. In another word, ",filled," learners out of ",total, " learners revealed their employment area.
                                ",sep = "")) %>%
         hc_exporting(enabled = T) %>% 
         hc_xAxis(labels=list(rotation = -45, style = list(fontSize = '10px')),
                  title = list(text = "Employment area"),
                  categories = df$employment_area) %>% 
         hc_yAxis(
          
           itle = list(text = "The number of learners"),
             showFirstLabel = FALSE,
             showLastLabel = FALSE
           
         ) %>% 
         hc_add_series(name = "Learners", type = "column",
                       data = df$total)%>%
         hc_add_series(name = "Fully Participated Learners", type = "column",color='lightpink',
                       data = df$fully)%>%
         hc_legend(enabled=T) %>%
         hc_tooltip(shared = T)
       
      
      return(h1)
  })
  
}

shinyApp(ui = ui, server = server)
