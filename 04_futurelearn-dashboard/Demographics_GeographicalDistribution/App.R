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
library(viridisLite)
library(countrycode)
library(plyr)
library(dplyr)
library(shiny)
library(ggplot2)
library(DT)

ui <- fluidPage(
  fluidRow(div(class = "highchart",highchartOutput("geographic",height = "600px"))),
  
  fluidRow(h4("The following table shows the top 10 countries with the most registrants."),
           DT::dataTableOutput('Top10Table',width = 600))
)

server <- function(input, output, session) {
  
source("../config.R", local = T)
source("../utilities.R", local = T)
  
  countrySummary <- eventReactive(session$clientData$url_search,{
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from enrolments")
      enrolments = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from team_members")
      team.members = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      result = try(isPreResponsesAvailable(courseSlug),TRUE)
      if(result!=FALSE && result == courseSlug)
      {
        mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
        rs = dbSendQuery(mydb, "select renamed_col from renamed_col_pre_responses where original_col='Which country do you live in?'")
        renamed.col = fetch(rs, n=-1)
        dbClearResult(rs)
        dbDisconnect(mydb)
        
        mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
        rs = dbSendQuery(mydb, paste("select ",renamed.col$renamed_col,",partner_export_id from pre_responses"))
        pre.responses = fetch(rs, n=-1)
        dbClearResult(rs)
        dbDisconnect(mydb)
        
        
        enrolments <- left_join( enrolments, pre.responses, by=c("learner_id"="partner_export_id"))
        enrolments[,ncol(enrolments)] <- countrycode(enrolments[,ncol(enrolments)],"country.name","iso2c")
        enrolments[,ncol(enrolments)] <- ifelse(is.na(enrolments[,ncol(enrolments)]),"Unknown",enrolments[,ncol(enrolments)])
        enrolments$country <- ifelse(is.na(enrolments$country),"Unknown",enrolments$country)
        enrolments$country <- ifelse(enrolments$country=="Unknown",enrolments[,ncol(enrolments)],enrolments$country)
      }
      
      learners = subset(enrolments, !learner_id %in% team.members$id)
      if('detected_country' %in% colnames(learners))
      {
        learners$country <- ifelse(learners$country == 'Unknown', learners$detected_country,learners$country)
        learners$country <- ifelse(learners$country == '--', 'Unknown',learners$country)
      }
      
      countrySummary <- ddply(learners, .(country), dplyr::summarise, total =n())
      countrySummary$iso3 <- countrycode(countrySummary$country,"iso2c","iso3c")
      countrySummary$name <- countrycode(countrySummary$country,"iso2c","country.name")
      countrySummary$iso3 <- ifelse(countrySummary$country == "XK", "RSK", countrySummary$iso3)
      countrySummary$name <- ifelse(countrySummary$country == "XK", "Kosovo", countrySummary$name)
      
      return(countrySummary)
    }
  })
  
  
  output$geographic <- renderHighchart({
    withProgress(message = 'Calculation in progress',{df <- countrySummary()
      data(worldgeojson, package = "highcharter")
      
      total = sum(df$total)
      df = subset(df, country != "Unknown")
      filled = sum(df$total)
      pct <- round(filled/total,2)* 100
      
      df$percentage <- round(df$total/filled,2)*100
      df$percentage <- as.character(df$percentage)
      
      dshmstops <- data.frame(q = c(0,exp(1:5)/exp(5)),
                              c = substring(rev(viridis(5 + 1, option = "C")), 0, 7)) %>% 
        list_parse2()
      
      if(nrow(df) > 0)
      {
        h1 <- highchart(height = 600) %>% 
          hc_title(text = "The geographical distribution of enrolments") %>% 
          hc_subtitle(text = paste("This chart shows the number of learners enrolled in the course from each country based on the pre-survey information or the detected country by their IP address. 
                    The county of ", pct, "% of learners have been detected.",sep = ""))%>% 
          hc_add_series_map(worldgeojson, df, name = "Total number of learners",
                            value = "total", joinBy = "iso3"
          ) %>%
          
          hc_colorAxis(stops = dshmstops) %>% 
          hc_legend(enabled = TRUE) %>% 
          hc_add_theme(hc_theme_db()) %>% 
          hc_exporting(enabled= T)%>%
          hc_mapNavigation(enabled = TRUE)%>%
          hc_chart(borderColor = '#EBBA95',
                   borderRadius = 10,
                   borderWidth = 2,
                   backgroundColor = list(
                     linearGradient = c(0, 0, 500, 500),
                     stops = list(
                       list(0, 'rgb(255, 255, 255)'),
                       list(1, 'rgb(200, 200, 255)')
                     )))
      
      }
      else
      {
        h1 <- highchart(height = 600) %>% 
          hc_title(text = "The geographical distribution of enrolments") %>% 
          hc_subtitle(text = "This chart shows the number of learners enrolled in the course from each country based on the pre-survey information or the detected country by their IP address.")
      }
    })
      return(h1)
  })
  
  
  output$Top10Table <- renderDataTable(
    {
      # Source Code: http://stackoverflow.com/questions/25554068/saving-from-shiny-renderdatatable
      df <- countrySummary()
      if(nrow(df) > 0)
      {
        df <- subset(df, country != 'Unknown', select = c("name","total"))
        df <- df[order(-df[,2]),]
        t <- sum(df$total)
        df$pct <- paste(round(df$total/t,2)*100, "%",sep = "")
        row.names(df) <- NULL
        colnames(df) <- c("Country","Total Number", "Percentage")
        df
      }
      else
      {
        data.frame(Country=character(0),`Total Number`=character(0),Percentage=character(0))
      }
      
    },extensions = 'Buttons',
    options = list(
      "dom" = 'T<"clear">lBfrtip',
      buttons = list('copy', 'csv', 'excel', 'pdf', 'print')
    )
  )
  
}

shinyApp(ui = ui, server = server)
