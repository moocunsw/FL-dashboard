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
library(plyr)
library(dplyr)
library(rCharts)
library(shiny)

ui <- fluidPage(
  tags$head(tags$script(src = "https://code.highcharts.com/highcharts.js"),
            tags$script(src = "https://code.highcharts.com/highcharts-more.js"),
            tags$script(src = "https://code.highcharts.com/modules/exporting.js"),
            tags$script(src = "https://code.highcharts.com/modules/heatmap.js")
  ),
  fluidRow(showOutput("StepProgressCountsHeatmapByWeek", "highcharts")),
  fluidRow(showOutput("StepProgressPctsHeatmapByWeek", "highcharts"))
)

server <- function(input, output, session) {
  
  source("../config.R")
  
  StepProgressCounts <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_StepProgressCountsHeatmapByWeek")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      return(data)
    }
  })
  
  output$StepProgressCountsHeatmapByWeek <- renderChart({
    tmp <- StepProgressCounts()
    
    uniqueY <- unique(tmp$step)
    uniqueX <- unique(tmp$week_number)
    
    # The highcharts to draw the heatmap needs three columns i.e. x, y and value.
    # We set each of these columns appropriatly.
    # Also x and y columns have to be index of x and y axises. 
    # So we use the index from the level of each of this column.
    
    tmp$x <- 0
    tmp$y <- 0
    
    levels(tmp$x) <- 0:(length(uniqueX)-1)
    levels(tmp$y) <- 0:(length(uniqueY)-1)
    
    for(i in 1:length(tmp$y))
    {
      tmp$y[i] <- which(uniqueY == tmp$step[i])-1
    }
    for(i in 1:length(tmp$x))
    {
      tmp$x[i] <- which(uniqueX == tmp$week_number[i])-1
    }
    colnames(tmp)[3] <- "value"
    
    hm2 <- rCharts:::Highcharts$new()
    hm2$title(text = "Step Activity Progress by Week")
    hm2$subtitle(text = "This chart shows the heatmap of step activity vs week. The Coloring is based on the number of learners who visited the step at the given week.")
    hm2$xAxis(categories = uniqueX,
              formatter = "#!function(d){return 'Week ' + d}!#",
              title = list(text = 'Week'))
    hm2$yAxis(categories = uniqueY,showLastLabel = FALSE,
              title = list(text = "Step"))
    
    hm2$addParams(colorAxis = 
                    list(min = 0,
                         minColor='#FFFFFF',
                         maxColor='#7cb5ec'
                    )
    )
    hm2$chart(zoomType = "x", type = 'heatmap',height = 600)
    hm2$series(name = 'Positive', 
               data= toJSONArray2(tmp, json = F), 
               color='#cccccc')
    
    
    hm2$tooltip(borderWidth=0, followPointer=TRUE, followTouchMove=TRUE, shared = FALSE,
                formatter = "#! function()
                { var tooltip = ''
                return this.point.value + 
                ' learners visited Step ' +this.series.yAxis.categories[this.point.y]
                + ' at Week ' + this.series.xAxis.categories[this.point.x];
                }
                
                !#")
    
    hm2$addParams(dom = 'StepProgressCountsHeatmapByWeek')
    
    return(hm2)
  })
  
  output$StepProgressPctsHeatmapByWeek <- renderChart(
    {
      mergedf <- StepProgressCounts()
      
      total_week <- ddply(mergedf,.(week_number), dplyr::summarise, total_week=sum(freq))
      total_step <- ddply(mergedf,.(step,week_number), dplyr::summarise, total_step=sum(freq))
      
      
      stepProgressCounts <- inner_join(total_week,total_step, by = c("week_number"="week_number")) 
      stepProgressCounts$value <- round(stepProgressCounts$total_step/stepProgressCounts$total_week* 100)
      
      # Fill the gaps in the data frame
      uniqueSteps <- unique(stepProgressCounts$step)
      uniqueWeeks <- unique(stepProgressCounts$week_number)
      tmp <- merge(uniqueWeeks,uniqueSteps)
      tmp <- tmp[ ,c(2,1)]
      colnames(tmp) <- c("step","week_number")
      tmp <- left_join(tmp,stepProgressCounts,by=c("step"="step","week_number"="week_number"),all.y=TRUE)
      tmp <- replace(tmp, is.na(tmp), 0)
      levels(tmp$step) <- unique(tmp$step)
      
      # Sort the data frame based on week and step
      tmp[,6:7] <- matrix(as.numeric(unlist(strsplit(as.character(tmp[,1]), "[.]"))), ncol=2, byrow=TRUE)
      tmp <- tmp[with(tmp,order(tmp[,2],tmp[,6],tmp[,7])), ]
      tmp$V6 <- NULL 
      tmp$V7 <- NULL 
      
      uniqueY <- unique(tmp$step)
      uniqueX <- unique(tmp$week_number)
      
      # The highcharts to draw the heatmap needs three columns i.e. x, y and value.
      # We set each of these columns appropriatly.
      # Also x and y columns have to be index of x and y axises. 
      # So we use the index from the level of each of this column.
      
      tmp$x <- 0
      tmp$y <- 0
      
      levels(tmp$x) <- 0:(length(uniqueX)-1)
      levels(tmp$y) <- 0:(length(uniqueY)-1)
      
      for(i in 1:length(tmp$y))
      {
        tmp$y[i] <- which(uniqueY == tmp$step[i])-1
      }
      for(i in 1:length(tmp$x))
      {
        tmp$x[i] <- which(uniqueX == tmp$week_number[i])-1
      }
      
      
      hm2 <- rCharts:::Highcharts$new()
      hm2$title(text = "Normalised Step Activity Progress by Week")
      hm2$subtitle(text = "This chart shows the heatmap of step activity vs week. The Coloring is based on the percentage of learners who visited the step at the given week. It has been normalised by dividing the number of visitors for each step to the total number of visitors for the relative week.")
      
      hm2$xAxis(categories = uniqueX,
                #formatter = "#!function(d){return 'Week ' + d}!#",
                title = list(text = 'Date'))
      hm2$yAxis(categories = uniqueY,showLastLabel = FALSE,
                title = list(text = "Step"))
      
      hm2$addParams(colorAxis = 
                      list(min = 0,
                           minColor='#FFFFFF',
                           maxColor='#7cb5ec'
                      )
      )
      hm2$chart(zoomType = "x", type = 'heatmap',height = 600)
      hm2$series(name = 'Positive', 
                 data= toJSONArray2(tmp, json = F), 
                 color='#cccccc')
      
      
      hm2$tooltip(borderWidth=0, followPointer=TRUE, followTouchMove=TRUE, shared = FALSE,
                  formatter = "#! function()
                  { var tooltip = ''
                  return this.point.value + 
                  '% learners visited the step ' +this.series.yAxis.categories[this.point.y]
                  + ' at Week ' + this.series.xAxis.categories[this.point.x];
                  }
                  
                  !#")
      
      hm2$addParams(dom = 'heatmap')
      hm2$addAssets(js = 
                      c("https://ajax.googleapis.com/ajax/libs/jquery/1.11.1/jquery.min.js",
                        "https://code.highcharts.com/modules/heatmap.js"
                      )
      )
      
      hm2$addParams(dom = 'StepProgressPctsHeatmapByWeek')
      
      return(hm2)
    }
  )
  
}

shinyApp(ui = ui, server = server)
