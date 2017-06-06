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
library(shiny)

ui <- fluidPage(
 fluidRow(highchartOutput("WordCountAnalysisByRole")) #polycharts
)

server <- function(input, output, session) {
  
source("../config.R", local = T)
source("../utilities.R", local = T)
  
  WordCount <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_WordCountAnalysisByRole")
      data = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)

      return(data)
    }
  })
  
  
  output$WordCountAnalysisByRole <- renderHighchart({
    commentsSummary <- WordCount()
    total = sum(commentsSummary$wordCount)
    
    wordByLearners = subset(commentsSummary,role=="learner")$wordCount
    learner = round(wordByLearners / total,2)*100
    
    col1 <- "lightblue"
    col2 <- "lightgreen"
    
    h1 <- highchart() %>% 
      hc_title(text = "The word count analysis") %>% 
      hc_subtitle(text = "The following chart shows three metrics by word count analysis. The blue bar shows the accumulation of words in all comments by the participant role. The black line shows the number of comments made by each group. The pie chart shows the percentage of accumulated words by two groups of learners and educators. ") %>% 
      hc_legend(enabled = FALSE) %>% 
      hc_xAxis(categories = commentsSummary$role) %>% 
      hc_yAxis_multiples(
        list(
          title = list(text = "The number of words",style = list(color = "lightblue")),
          align = "left",
          showFirstLabel = FALSE,
          showLastLabel = FALSE,
          labels = list(style = list(color = "lightblue"))
        ),
        list(
          title = list(text = "The number of comments"),
          align = "right",
          showFirstLabel = FALSE,
          showLastLabel = FALSE,
          opposite = TRUE
        )
      ) %>% 
      hc_tooltip( formatter = JS("function(){
                                if('The Percentage of word comments' == this.series.name){
                                return  '<b>' + this.point.name + ': </b>' + this.y + '%'
                                } else {
                            unts = this.series.name == 'The number of comments' ? 'comments' : 'words';
                            return (this.x + ': ' + this.y + ' ' + unts)
                                }}"),
             useHTML = TRUE) %>% 
      hc_add_series(name = "The number of words", type = "column",yAxis = 0, 
                    color = "lightblue",
                    data = commentsSummary$wordCount) %>% 
      hc_add_series(name = "The number of comments", type = "spline",
                    color = "black",
                    data = commentsSummary$comments, yAxis = 1) %>% 
      hc_add_series(name = "The Percentage of word comments", type = "pie",
                    data = list(list(y = learner, name = "Learners",
                                     sliced = TRUE, color = col1),
                                list(y = (100-learner), name = "Educators",
                                     color = col2,
                                     dataLabels = list(enabled = FALSE))),
                    center = c('50%', 45),
                    size = 80)%>%
      hc_exporting(enabled = TRUE)
    
    return(h1)
  })
  
}

shinyApp(ui = ui, server = server)
