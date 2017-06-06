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
   fluidRow(highchartOutput("WordCountSummary",height = 600)) 
)

server <- function(input, output, session) {
  
  source("../config.R")
  
  getWordCountSummary <- eventReactive(session$clientData$url_search,{
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_WordCountStatsByEducators")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      data$author_id <- paste(data$first_name,data$last_name) 
      
      
      return(data)
    }
  })
  
  
  
  output$WordCountSummary <- renderHighchart({
    
    data <- getWordCountSummary()
    
    uniqueAuthors <- unique(data$author_id)
    uniqueWordcount <- unique(data$wordCount)
    
    Wordcounts <- data.frame(wordCount = uniqueWordcount)
    Wordcounts <- as.data.frame(Wordcounts[order(Wordcounts[,1]), ])
    colnames(Wordcounts) <- c("wordCount")
  
    
    h1<-   
      highchart() %>% 
      hc_title(text = "Word count analysis of comments per educator") %>% 
      hc_subtitle(text=paste("This chart shows the number of comments containing different number of words for each educators.",sep = "")) %>%
      hc_legend(enabled = T) %>% 
      hc_xAxis(labels=list(rotation = -30, style = list(fontSize = '10px')),
               title = list(text = "The number of words"),
               categories = as.character(Wordcounts$wordCount)) %>% 
      hc_yAxis(
        labels = list(format = "{value:,.0f}"),
          title = list(text = "The number of comments"),
          align = "left",
          showFirstLabel = FALSE,
          showLastLabel = FALSE
        
      ) %>% 
      hc_tooltip(shared = T,crosshairs = TRUE,borderWidth = 5
                 , formatter = JS("function()
                { 
                return this.series.name +' Commented <b>' +this.point.y + '</b> times by word count of <b>' + this.series.xAxis.categories[this.point.x] + '</b>';
                }
                
                ")) %>%
      hc_exporting(enabled = TRUE) 
      
    
    
    
    for(i in 1:length(uniqueAuthors))
    {
      author <- uniqueAuthors[i]
      tmp <- data[data$author_id == author, ]
      tmp <- left_join(Wordcounts,tmp,by=c("wordCount"="wordCount"),all.y=TRUE)
      h1 <- hc_add_series(h1,name = author
                          , data = as.list(tmp$Words)
                          , type = "scatter"
                          )
    }
    
   
    
    return(h1)
  })
  
}

shinyApp(ui = ui, server = server)

