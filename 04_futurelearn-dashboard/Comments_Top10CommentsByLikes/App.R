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
library(plyr)
library(dplyr)
library(DT)

ui <- fluidPage(
  headerPanel("Top comments by likes"),
  fluidRow(
    h4("The followinf table shows the top 10 comments by the highest likes."),
    DT::dataTableOutput('Top10CommentsByLikesTable')
    
    ))


server <- function(input, output, session) {
  source("../config.R")
  
 
  Top10CommentsByLikes <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug <- query[['course']]
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select `step` as Step, `text` as `Comment`, `likes` as `Likes` from comments order by likes desc;")
      data = fetch(rs, n=-1)
      
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      data <- top_n(data,10,Likes)
      
      return(data)
    }
  })
  
  output$Top10CommentsByLikesTable <- DT::renderDataTable(
    {
      withProgress(message = 'Reading Data...', value = 0, {Top10CommentsByLikes <- Top10CommentsByLikes()})
     
      Top10CommentsByLikes
    },extensions = 'Buttons',
    options = list(
      "dom" = 'T<"clear">lBfrtip',
      buttons = list('copy', 'csv', 'excel', 'pdf', 'print')
  )
)
}

shinyApp(ui = ui, server = server)
