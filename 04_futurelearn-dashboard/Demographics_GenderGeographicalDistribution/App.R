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
library("treemap")
library("viridisLite")
library(countrycode)
library(plyr)
library(dplyr)
library(shiny)

ui <- fluidPage(
  #headerPanel("Enrolment cumulative growth"),
  fluidRow(highchartOutput("geographic",height = "800px")) #polycharts
)

server <- function(input, output, session) {
  
source("../config.R", local = T)
source("../utilities.R", local = T)
  
  countrySummary <- reactive({
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
        
        
        mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
        rs = dbSendQuery(mydb, "select renamed_col from renamed_col_pre_responses where original_col='What is your gender?'")
        renamed.col = fetch(rs, n=-1)
        dbClearResult(rs)
        dbDisconnect(mydb)
        
        mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
        rs = dbSendQuery(mydb, paste("select ",renamed.col$renamed_col,",partner_export_id from pre_responses"))
        pre.responses = fetch(rs, n=-1)
        dbClearResult(rs)
        dbDisconnect(mydb)
        
        enrolments <- left_join( enrolments, pre.responses, by=c("learner_id"="partner_export_id"))
        enrolments[,ncol(enrolments)] <- ifelse(is.na(enrolments[,ncol(enrolments)]),"Unknown",tolower(enrolments[,ncol(enrolments)]))
        enrolments$gender <- ifelse(is.na(enrolments$gender),"Unknown",enrolments$gender)
        enrolments$gender <- ifelse(enrolments$gender=="Unknown",enrolments[,ncol(enrolments)],enrolments$gender)
        
      }
      
      learners = subset(enrolments, !learner_id %in% team.members$id)
     
      countryGenderSummary <- ddply(learners, .(country,gender), dplyr::summarise, total =n())
      
      female <- subset(countryGenderSummary, countryGenderSummary$gender=="female" , select=c("country","total"))
      male <- subset(countryGenderSummary, countryGenderSummary$gender=="male" , select=c("country","total"))
      nonbinary <- subset(countryGenderSummary, countryGenderSummary$gender=="nonbinary" , select=c("country","total"))
      unknown <- subset(countryGenderSummary, countryGenderSummary$gender=="Unknown" , select=c("country","total"))
      
      uniqueCountries <- as.data.frame(unique(countryGenderSummary$country))
      colnames(uniqueCountries) <- c("country")
      tmp <- left_join(uniqueCountries,female,all.y=TRUE)
      tmp <- replace(tmp, is.na(tmp), 0)
      colnames(tmp) <- c("country","female")
      tmp <- left_join(tmp,male)
      tmp <- replace(tmp, is.na(tmp), 0)
      colnames(tmp) <- c("country","female","male")
      tmp <- left_join(tmp,nonbinary)
      tmp <- replace(tmp, is.na(tmp), 0)
      colnames(tmp) <- c("country","female","male","nonbinary")
      tmp <- left_join(tmp,unknown)
      tmp <- replace(tmp, is.na(tmp), 0)
      colnames(tmp) <- c("country","female","male","nonbinary","Unknown")
      
      tmp$total <- tmp$female + tmp$male + tmp$nonbinary+ tmp$Unknown
      
      tmp$iso3 <- countrycode(tmp$country,"iso2c","iso3c")
      tmp$continent <- countrycode(tmp$iso3,"iso3c","continent")
      tmp$c_name <- countrycode(tmp$country,"iso2c","country.name")
      
      return(tmp)
    }
  })
  
  
  output$geographic <- renderHighchart({
      
    withProgress(message = 'Calculation in progress',{df <- countrySummary()
      
      total = sum(df$total)
      df = subset(df, country != "Unknown")
      filled = sum(df$total)
      pct <- round(filled/total,2)* 100
      
      
      # There was an error (cannot open file 'Rplots.pdf') in server that fixed by the following code
      # source is https://github.com/timelyportfolio/d3treeR/issues/19
      #tf <- "/tmp/Rplots.pdf"
      tf <- "c:/temp/Rplots.pdf"
      png(tf, height = 1000, width=1000) #you'll need to be specific with height and width
      
      #print(df[1,])
      tm <- treemap(df, index = c("continent","c_name"),
                    vSize = "total", vColor = "female",
                    type = "value", palette = rev(viridis(6)),draw = FALSE,
                    title.legend="The total number of learners")
      dev.off()
      
      h1 <- highchart() %>% 
        hc_add_series_treemap(tm, allowDrillToNode = TRUE,
                             layoutAlgorithm = "squarified",
                             name = "tmdata") %>% 
        hc_exporting(enabled= T)%>%
        hc_title(text = "Gender Geographical Distribution") %>% 
        hc_subtitle(text = paste("This chart shows the number of female or male learners enrolled in the course from each country based on the pre-survey information. 
The size is based on the the total number of learners for each country and the color is based on the number of female learners in each country. 
                    Only ", pct, "% of learners have given their country of origin and their gender. In another word, ",filled," learners out of ",total, " learners revealed their country of origin.",sep = ""))%>% 
        
        # hc_tooltip(pointFormat = "<b>{point.name}</b>:<br>
        #      Total: {point.value:,.0f}<br>
        #      Male: {point.valuecolor:,.0f}")
      hc_tooltip(formatter = JS("function(){var s = this.point.value - this.point.valuecolor;
var f_p = Math.round(this.point.valuecolor/this.point.value * 100);
var m_p = Math.round(s/this.point.value * 100);
                      return ('<b>'+this.point.name + 
'</b>:<br>Total: ' + this.point.value+
'<br>Female: ' + this.point.valuecolor + ' ('+f_p+'%)'+
'<br>Male: ' + s + ' ('+m_p+'%)')
                      }")
      )
    })
      
      
      return(h1)
  })
  
}

shinyApp(ui = ui, server = server)
