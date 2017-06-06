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

library(shiny)
library(shinydashboard)
library(DT)
library(RMySQL)
library(shinyjs)


ui <- dashboardPage(dashboardHeader( disable = T)
              , dashboardSidebar()
              , dashboardBody(
                useShinyjs(),
               fluidRow(
                            box(
                              title = "Submitted assignments by clicking on any assignment, reviews will be shown in the bottom", 
                              status = "primary", solidHeader = TRUE, width = 12, collapsible = TRUE
                              , DT::dataTableOutput("assignmentViewer")
                            )
                          ),
                          fluidRow(
                            box(
                              title = "Assignment's reviews", 
                              status = "primary", solidHeader = TRUE, width = 12, collapsible = TRUE
                              , DT::dataTableOutput("reviewerViewer")
                            )
                          )
                  
                ))

server <- function(input, output, session) {
  source('../config.R')
  source('../utilities.R')
  
  addClass(selector = "body", class = "sidebar-collapse")
 
  getAssignmentData <- eventReactive(session$clientData$url_search,
                                  {
                                    query <- parseQueryString(session$clientData$url_search)
                                    if (!is.null(query[['course']]))
                                    {
                                      courseSlug = query[['course']]
                                      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
                                      rs = dbSendQuery(mydb, "select * from peer_review_assignments")
                                      data = fetch(rs, n=-1)
                                      dbClearResult(rs)
                                      dbDisconnect(mydb)
                                      
                                      data <- subset(data,select=c("id","step","text","submitted_at","review_count"))
                                      
                                      data$id <- as.factor(data$id)
                                      data$step <- as.factor(data$step)
                                      
                                      return (data)
                                    }
                                  }
  )
  
getReviewData <- function(assignment.id)
{
 query <- parseQueryString(session$clientData$url_search)
 if (!is.null(query[['course']]))
 {
   courseSlug = query[['course']]
   mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
   rs = dbSendQuery(mydb, paste("select * from peer_review_reviews where assignment_id = ",assignment.id,sep=''))
   data = fetch(rs, n=-1)
   dbClearResult(rs)
   dbDisconnect(mydb)
   
   data <- subset(data,select=c("id","assignment_id","guideline_one_feedback","guideline_two_feedback","guideline_three_feedback","created_at"))
   
   data$id <- as.factor(data$id)
   data$assignment_id <- as.factor(data$assignment_id)
   
   return (data)
 }
}
  
  
  output$assignmentViewer <- renderDataTable({
    
    data <- getAssignmentData()
   
    DT::datatable(
      data[,c("id","step","text","submitted_at","review_count")], class = 'cell-border stripe', filter = 'top', extensions = 'Buttons',
      colnames = c(
        "ID" = 1,
        "Step" = 2,
        "Assignment" = 3,
        "Date" = 4,
        "Number of Reviews" = 5
      ),
      options = list(
        scrollY = "700px",
        lengthMenu = list(c(10,20,30),c('10','20','30')),
        pageLength = 20,
        dom = 'lfrtBip',
        buttons = list(
          "print", 
          list(
            extend = 'pdf',
            filename = 'Comments',
            text = 'Download pdf'
          ),
          list(
            extend = 'excel',
            filename = 'Comments',
            text = 'Download Excel'
          )
        )
      ),
      rownames = FALSE,
      selection = 'single'
    )
  })
  
  threadSelected <- eventReactive( input$assignmentViewer_rows_selected, {
    runif(input$assignmentViewer_rows_selected)
  })
  
  output$reviewerViewer <- renderDataTable({
    threadSelected()
    data <- getAssignmentData()
    assignment <- data[input$assignmentViewer_rows_selected,]
    
    if(assignment$review_count < 1){
      return()
    }
    
    rows <- getReviewData(assignment$id)
    rows <- rows[order(rows$created_at),]
    
    DT::datatable(
      rows[,c("id","assignment_id","guideline_one_feedback","guideline_two_feedback","guideline_three_feedback","created_at")], class = 'cell-border stripe', extensions = 'Buttons',
      colnames = c(
        "Review ID" = 1,
        "Assignement ID" = 2,
        "First guideline" = 3,
        "Second guideline" = 4,
        "Third guideline" = 5,
        "Created at" = 6
      ),
      options = list(
        #scrollY = "700px",
        lengthMenu = list(c(3,6,30),c('3','6','30')),
        pageLength = 3,
        dom = 'lfrtBip',
        buttons = list(
          "print", 
          list(
            extend = 'pdf',
            filename = 'Comment Thread',
            text = 'Download pdf'
          ),
          list(
            extend = 'excel',
            filename = 'Comment Thread',
            text = 'Download Excel'
          )
        )
      ),
      rownames = FALSE
    )
  })
  
}

shinyApp(ui = ui, server = server)
