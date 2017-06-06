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
library(shiny)
library(tm)
library(wordcloud)

ui <- fluidPage(
  fluidRow(h4("The following word cloud is constructed from all positive and negative words used in the comments."),
           plotOutput("WordCloudOfOriginalSentimentAnalysis"))
)


server <- function(input, output, session) {
  
  source("../config.R")
  
  getWordCloud <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_WordCloudOfOriginalSentimentAnalysis;")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      return(data)
    }
  })
  
  output$WordCloudOfOriginalSentimentAnalysis <- renderPlot({
    
    WordCloud <-getWordCloud()
    withProgress(message = 'Calculation in progress',{
    text <- WordCloud$word
    myCorpus = Corpus(VectorSource(text))
   
    wordcloud(myCorpus, scale=c(5,0.5),max.words=100,rot.per=0.35, use.r.layout=FALSE,
              colors=brewer.pal(8, "Dark2"))
    })
    })
  
}


shinyApp(ui = ui, server = server)