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
library(xts)
library(shiny)


ui <- fluidPage(
  fluidRow(radioButtons("normalised_num", "Normalised or total number:", c("Normalised","Number"))),
  fluidRow(highchartOutput("CommentsTypeStatsDay",height = "600"))
)

server <- function(input, output, session) {
  
  source("../config.R", local = T)
  source("../utilities.R", local = T)
  
  commentsStatsType <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_CommentsStatsDayType")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      return(data)
    }
  })
  
  
  findCourseStartEndDatesByWeek <- reactive(
    {
      query <- parseQueryString(session$clientData$url_search)
      if (!is.null(query[['course']]))
      {
        courseSlug = query[['course']]
        dates2 = findStartEndDatesByWeek(courseSlug)
        return(dates2)
      }
    }
  )
  

  
  output$CommentsTypeStatsDay <- renderHighchart(
    {
      
      fr <- commentsStatsType()
      dates <- findCourseStartEndDatesByWeek()
      
      dates$start_date <- as.Date(dates$start_date)
      dates$end_date <- as.Date(dates$end_date)
      
      title = c()
      for(i in 1:nrow(dates))
      {
        title <- append(title, paste("Week ",dates$week_number[i]," started",sep = ""))
      }
      title <- append(title,"Course finished")
      
      fr$timestamp <- as.Date(fr$timestamp)
      
      article <- subset(fr, type == "Article")
      discussion <- subset(fr, type == "Discussion")
      video <- subset(fr, type == "Video")
      
      h1<- highchart(type = "stock") 
      h1 <- hc_title(h1,text = "Comments Type Statistics by Date") 
      h1 <- hc_add_theme(h1,hc_theme_flat()) 
      h1 <- hc_exporting(h1,enabled = T) 
      h1 <- hc_legend(h1,enabled = T) 
      
      if(input$normalised_num == "Normalised")
      {
        article_min <- subset(article, timestamp == as.character(median(article$timestamp)))$freq_comment 
        article$freq_normalized = round(article$freq_comment*100/article_min)
        article_xts_freq <-  xts(article$freq_comment, order.by=article$timestamp)
        article_xts <-  xts(article$freq_normalized, order.by=article$timestamp)
        
        discussion_min <- subset(discussion, timestamp == as.character(median(discussion$timestamp)))$freq_comment 
        discussion$freq_normalized = round(discussion$freq_comment*100/discussion_min)
        discussion_xts <-  xts(discussion$freq_normalized, order.by=discussion$timestamp)
        discussion_xts_freq <-  xts(discussion$freq_comment, order.by=discussion$timestamp)
        
        video_min <- subset(video, timestamp == as.character(median(video$timestamp)))$freq_comment 
        video$freq_normalized = round(video$freq_comment*100/video_min)
        video_xts <-  xts(video$freq_normalized, order.by=video$timestamp)
        video_xts_freq <-  xts(video$freq_comment, order.by=video$timestamp)
        
        baseLevel <- xts(rep(100, NROW(video_xts)), index(video_xts))
        
        h1 <- hc_subtitle(h1,text = paste("This chart shows the normalized number of comments for each step type (Article, Discussion and Video) at any date.
                          The base line is at the middle date(", median(video$timestamp), ") with the value of 100. 
                                          If you click on invisible data sets under the chart, you can see the actual numbers for each step type.",sep = "" ))
        h1 <- hc_add_series_xts(h1,article_xts, id = "Article", name= "Comments(normalised) on Article Step") 
        h1 <- hc_add_series_xts(h1,article_xts_freq,dashstyle = "ShortDash", id = "Article_freq", name= "Comments on Article Step", visible = F) 
        h1 <- hc_add_series_xts(h1,discussion_xts,id = "Discussion", name= "Comments(normalised) on Discussion Step") 
        h1 <- hc_add_series_xts(h1,discussion_xts_freq,dashstyle = "ShortDash",id = "Discussion_freq", name= "Comments on Discussion Step", visible = F) 
        h1 <- hc_add_series_xts(h1,video_xts,id = "Video", name= "Comments(normalised) on Video Step") 
        h1 <- hc_add_series_xts(h1,video_xts_freq,dashstyle = "ShortDash",id = "Video_freq", name= "Comments on Video Step", visible = F) 
        h1 <- hc_add_series_xts(h1,baseLevel, color = "red", name = "Base level", enableMouseTracking = FALSE)
        h1 <- hc_colors(h1,c("purple","mediumpurple","orange","lightsalmon","green","mediumseagreen"))
        
       
      }
      else
      {
        article_xts <-  xts(article$freq_comment, order.by=article$timestamp)
        discussion_xts <-  xts(discussion$freq_comment, order.by=discussion$timestamp)
        video_xts <-  xts(video$freq_comment, order.by=video$timestamp)
        
        h1 <- hc_subtitle(h1,text = "This chart shows the number of comments for each step type (Article, Discussion and Video) at any date.") 
        h1 <- hc_add_series_xts(h1,article_xts, id = "Article", name= "Comments on Article Step") 
        h1 <- hc_add_series_xts(h1,discussion_xts,id = "Discussion", name= "Comments on Discussion Step") 
        h1 <- hc_add_series_xts(h1,video_xts,id = "Video", name= "Comments on Video Step") 
        h1 <- hc_colors(h1,c("purple","orange","green"))
        
        
      }
      
     
      
      h1 <- hc_add_series_flags(h1,append(dates$start_date,dates$end_date[nrow(dates)]),
                                title = title, 
                                text = title,
                                id = "Video", name = "Flags")
      
      h1
    }
  )
  
  
}

shinyApp(ui = ui, server = server)
