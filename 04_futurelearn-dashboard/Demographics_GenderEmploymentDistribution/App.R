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
  fluidRow(highchartOutput("gender", height = "600px")) 
)

server <- function(input, output, session) {
  
source("../config.R", local = T)
source("../utilities.R", local = T)
  
  employmentGenderSummary <- reactive({
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
      employmentGenderSummary <- ddply(learners, .(employment_status,gender), summarise, total =n())
      
      if("other" %in% employmentGenderSummary$gender)
      {
        other <- subset(employmentGenderSummary,gender == "other", select=c("total"))
        employmentGenderSummary$total <- ifelse(employmentGenderSummary$gender == "nonbinary", other$total + employmentGenderSummary$total, employmentGenderSummary$total)
      }
      employmentGenderSummary <- subset(employmentGenderSummary,gender!="other")
      
      uniqueGender <- unique(employmentGenderSummary$gender)
      uniqueStatuses <- unique(employmentGenderSummary$employment_status)
      tmp <- merge(uniqueStatuses,uniqueGender)
      tmp <- tmp[ ,c(2,1)]
      colnames(tmp) <- c("gender","employment_status")
      tmp <- left_join(tmp,employmentGenderSummary,all.y=TRUE)
      tmp <- replace(tmp, is.na(tmp), 0)
      
      return(tmp)
    }
  })
  
  
  output$gender <- renderHighchart({
      tmp <- employmentGenderSummary()
      tmp <- tmp[order(-tmp[,3]),]
      
      total = sum(tmp$total)
      
      tmp <- subset(tmp,employment_status!= "Unknown" & gender!="Unknown")
      filled = sum(tmp$total)
      pct <- round(filled/total,2)* 100
      
      uniqueStatuses <- unique(tmp$employment_status)
      
      
      h1 <- 
        highchart() %>% 
        hc_title(text = "Gender vs Employment Status") %>% 
        hc_subtitle(text=paste("This chart shows the number of learners for each gender vs their employment statuses on the pre-survey information. 
                               Only ", pct, "% of learners have given their gender and employment statuses. In another word, ",filled," learners out of ",total, " learners revealed their gender and employment status.",sep = "")) %>%
        hc_xAxis(categories = uniqueStatuses) %>% 
        hc_yAxis(title = list(text = "The number of learners")) %>% 
        hc_add_series(name = "Female", type = "column", data = subset(tmp,gender=="female")$total) %>% 
        hc_add_series(name = "Male", type = "column", data = subset(tmp,gender=="male")$total) %>% 
        hc_add_series(name = "Other", type = "column",
                      data = subset(tmp,gender=="nonbinary")$total) %>%
        hc_exporting(enabled = TRUE) %>%
        hc_tooltip(shared = T)
      
      
      
      return(h1)
  })
  
}

shinyApp(ui = ui, server = server)
