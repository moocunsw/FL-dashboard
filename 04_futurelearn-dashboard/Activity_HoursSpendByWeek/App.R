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
library(plyr)
library(dplyr)
library(shiny)
library(reshape2)

ui <- fluidPage(
  fluidRow(h4('This chart shows the number of learners who spend different hours in each week.'),
           h4('The hour spent is calculated based on the first time a learner visited any step and the last time the learner completed the step. The learners have to complete an step to be included in this chart.'),
           showOutput("HoursSpendByWeek", "nvd3")),
  fluidRow(hr(h4('This chart shows the percentage of learners who spend different hours in each week.')),
           h4('The hour spent is calculated based on the first time a learner visited any step and the last time the learner completed the step. The learners have to complete an step to be included in this chart.'),
            showOutput("HoursSpendByWeekPcs", "nvd3"))
  , fluidRow(hr(h4('This chart shows the percentage of learners who spend different hours in each week. The hours spend is capped to the selected option. If you select 1 Day, it means the maximum hours spend on each week is 24 hours, the rest of the data will be filtered out.'))
    ,selectInput(inputId = 'filter', 'Select maximum hours spend on each week:'
                          ,c('1 Day (24 hrs)'='24', '2 Days (48 hrs)'='48','5 Days (120 hrs)'='120'
                             ,'1 Week (168 hrs)'='168','2 Weeks (336 hrs)'='336','3 Weeks (504 hrs)'='504'
                             ,'4 Weeks (672 hrs)'='672','5 Weeks (840 hrs)'='840','6 Weeks (1008 hrs)'='1008'
                             ,'7 Weeks (1176 hrs)'='1176'))
    ,showOutput("FilteredHoursSpendByWeekPcs", "nvd3")
  )
  ) 


server <- function(input, output, session) {
  source("../config.R",local = TRUE)
  
  HoursSpendByWeek <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_HoursSpendByWeek")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      return(data)
    }
  })
  
  getStepActivity <- reactive(
    {
      query <- parseQueryString(session$clientData$url_search)
      if (!is.null(query[['course']]))
      {
        courseSlug = query[['course']]
        mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
        rs = dbSendQuery(mydb,"select * from step_activity; ")
        step_activity = fetch(rs, n=-1)
        dbClearResult(rs)
        dbDisconnect(mydb)
        return(step_activity)
      }
    }
  )
  
  getHoursSpendbyWeekFiltered <- eventReactive(input$filter,
                                               {
                                                 # Hours is not rounded, they used the int part of the decimal number.
                                                 stepActivity <- getStepActivity()
                                                 #print(input$filter)
                                                 flt <- filter(stepActivity,!is.na(last_completed_at))
                                                 mut <- mutate(flt,
                                                               delta = as.numeric(
                                                                 difftime(strptime(last_completed_at,"%Y-%m-%d %H:%M:%S"), strptime(first_visited_at,"%Y-%m-%d %H:%M:%S"), units="mins")
                                                               )
                                                 )
                                                 mut <- subset(mut,!is.na(delta))
                                                 
                                                 weekCompletion <- ddply(mut,.(learner_id, week_number),summarise,hours = round(sum(delta) / 60,2))
                                                 weekCompletion <- filter(weekCompletion,hours >= 0 & hours <= as.numeric(input$filter))
                                                 
                                                 # Find the breaks in the hours
                                                 breaks=c(-1,1,2,5,10,20,as.numeric(input$filter))
                                                 labels=c("less than 1", "1-2", "2-5", "5-10", '10-20', paste('20-',input$filter,sep=''))
                                                
                                                 melted <- melt(weekCompletion, na.rm = TRUE, value.name = "hours", id.vars=c("week_number"), measure.vars=c("hours"))
                                                 melted$hours <- cut(melted$hours, breaks=breaks, labels=labels);
                                                 bucketed <- ddply(melted,.(week_number, hours),summarise,freq = n());
                                                 # We have to fill the gaps in the dataframe. Since this data is going to group by hours, if there is no 
                                                 # corresponding row for each week_number and any hours, the graph shift the data to left to fill the gap by itself.
                                                 # Then at the end of axis, there are empty bars.
                                                 # So the following will find all missing hours for each week_number, and put 0 for each attribute column.
                                                 uniqueWeeks <- unique(bucketed$week_number);
                                                 uniquehours <- unique(bucketed$hours);
                                                 tmp <- merge(uniquehours,uniqueWeeks);
                                                 tmp <- tmp[ ,c(2,1)];
                                                 colnames(tmp) <- c("week_number","hours");
                                                 tmp <- left_join(tmp,bucketed,by=c("week_number"="week_number","hours"="hours"),all.y=TRUE)
                                                 tmp <- replace(tmp, is.na(tmp), 0)
                                                 
                                                 return(tmp)
                                                }
                                               )
  
  
  output$FilteredHoursSpendByWeekPcs <- renderChart({
    validate(need(input$filter,'Please select a range for hours spent in a week'))
    
    data <- getHoursSpendbyWeekFiltered()
    totalByWeek <- ddply(data,.(week_number),summarise,total=sum(freq))
    data <- merge(data,totalByWeek)
    data$pct <- data$freq/data$total
    
    n2 <- nPlot(pct ~ week_number, group = 'hours', data = data, type = 'multiBarChart')
    n2$yAxis(axisLabel = 'Learners',tickFormat = "#! function(d) {return d3.format('.0%')(d)} !#")
    n2$xAxis(tickFormat = "#! function(d) {return 'Week ' + d} !#")
    n2$chart(showControls = F,stacked = TRUE, tooltipContent = "#! function(key, x, y, e){ 
             return  y + ' of learners spent ' + key + ' hour at ' + x
  } !#")
    n2$addParams(dom = "FilteredHoursSpendByWeekPcs")
    
    return(n2)
  })
  
  output$HoursSpendByWeekPcs <- renderChart({
    data <- HoursSpendByWeek()
    totalByWeek <- ddply(data,.(week_number),summarise,total=sum(freq))
    data <- merge(data,totalByWeek)
    data$pct <- data$freq/data$total
    
    n2 <- nPlot(pct ~ week_number, group = 'hours', data = data, type = 'multiBarChart')
    n2$yAxis(axisLabel = 'Learners',tickFormat = "#! function(d) {return d3.format('.0%')(d)} !#")
    n2$xAxis(tickFormat = "#! function(d) {return 'Week ' + d} !#")
    n2$chart(showControls = F,stacked = TRUE, tooltipContent = "#! function(key, x, y, e){ 
             return  y + ' of learners spent ' + key + ' hour at ' + x
  } !#")
    n2$addParams(dom = "HoursSpendByWeekPcs")
    
    return(n2)
  })
  
  output$HoursSpendByWeek <- renderChart({
    HoursSpendByWeek <- HoursSpendByWeek()
    
    
    n2 <- nPlot(freq ~ week_number, group = 'hours', data = HoursSpendByWeek, type = 'multiBarChart')
    n2$yAxis(axisLabel = 'Learners',tickFormat = "#! function(d) {return d3.format('.0')(d)} !#")
    n2$xAxis(tickFormat = "#! function(d) {return 'Week ' + d} !#")
    n2$chart(showControls = F,stacked = TRUE, tooltipContent = "#! function(key, x, y, e){ 
             return  y + ' learners spent ' + key + ' hour at ' + x
  } !#")
    n2$set(title = "Hours spend per week")
    n2$addParams(dom = "HoursSpendByWeek")
    
    return(n2)
  })
  
  }

shinyApp(ui = ui, server = server)

