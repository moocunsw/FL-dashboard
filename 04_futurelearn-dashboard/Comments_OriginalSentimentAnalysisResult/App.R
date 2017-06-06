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

library(plyr)
library(dplyr)
library(rCharts)
library(highcharter)
library(shiny)
library(RMySQL)


ui <- fluidPage(
  
  
  fluidRow(highchartOutput("OriginalSentimentAnalysisResult"),height = "700"),
  fluidRow(highchartOutput("OriginalSentimentAnalysisResultMultiBar")),
  fluidRow(showOutput("OriginalSentimentAnalysisStepTypePct", "highcharts")),
  fluidRow(showOutput("OriginalSentimentAnalysisResultPct", "highcharts")),
  fluidRow(showOutput("OriginalSentimentByStep", "highcharts")),
  fluidRow(showOutput("OriginalSentimentCommentsByStep","highcharts"))
  
) 

server <- function(input, output, session) {
  
  source("../config.R", local = TRUE)
  source("../utilities.R", local = TRUE)
  
  
  
  findSentiments <- reactive({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query[['course']]))
    {
      courseSlug = query[['course']]
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select * from vis_OriginalSentimentAnalysisResult")
      fr = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      mydb = dbConnect(MySQL(), user=db_user, password=db_pass, dbname=courseSlug, host=db_host)
      rs = dbSendQuery(mydb, "select learner_id, role from enrolments")
      enrolments = fetch(rs, n=-1)
      dbClearResult(rs)
      dbDisconnect(mydb)
      
      colnames(enrolments)[1] <- "author_id"
      fr <- inner_join(fr,enrolments)
      types <- getStepTypeByCourse(courseSlug)
      fr <- left_join(fr, types, by = "step")
      
      
      return(fr)
    }
  })
  
  doSentimentByStep <- reactive({
    fr <- findSentiments()
    fr$sentiment <- lapply(fr$score,result)
    fr$sentiment <- as.character(fr$sentiment)
    step_score <- ddply(fr,.(step,sentiment),dplyr::summarize,freq=n(),total_likes=sum(likes),mean_likes=round(mean(likes),2))
    
    uniqueSentiments <- unique(step_score$sentiment)
    uniqueSteps <- unique(step_score$step)
    tmp <- merge(uniqueSentiments,uniqueSteps)
    tmp <- tmp[ ,c(2,1)]
    colnames(tmp) <- c("step","sentiment")
    tmp <- left_join(tmp,step_score,by=c("step"="step","sentiment"="sentiment"))
    step_score <- replace(tmp, is.na(tmp), 0)
    
    step_score[,6:7] <- matrix(as.numeric(unlist(strsplit(as.character(step_score[,1]), "[.]"))), ncol=2, byrow=TRUE)
    step_score <- step_score[with(step_score,order(step_score[,6],step_score[,7])), ]
    step_score <- step_score[with(step_score,order(desc(step_score[,2]))), ]
    step_score[,6:7] <- list(NULL,NULL)
    return(step_score)
  })
  
  doSentimentByStepType <- reactive({
    fr <- findSentiments()
    fr$sentiment <- lapply(fr$score,result)
    fr$sentiment <- as.character(fr$sentiment)

    step_score <- ddply(fr,.(type,sentiment),dplyr::summarize,freq=n(),total_likes=sum(likes),mean_likes=round(mean(likes),2))

    uniqueSentiments <- unique(step_score$sentiment)
    uniqueTypes <- unique(step_score$type)
    tmp <- merge(uniqueSentiments,uniqueTypes)
    tmp <- tmp[ ,c(2,1)]
    colnames(tmp) <- c("type","sentiment")
    tmp <- left_join(tmp,step_score,by=c("type"="type","sentiment"="sentiment"))
    step_score <- replace(tmp, is.na(tmp), 0)

    step_score.sum <- ddply(step_score,.(type),summarise,total = sum(freq))

    step_score <- left_join(step_score,step_score.sum, by = c("type" = "type"))
    step_score$pct <- round(step_score$freq / step_score$total,2) * 100

    step_score$pct <- ifelse(step_score$sentiment == "negative", -1 * step_score$pct, step_score$pct)
    css <- subset(step_score, step_score$sentiment == "negative" | step_score$sentiment == "positive")

    css$sentiment <- ifelse(css$sentiment == "positive", "Positive Comments", "Negative Comments")


    return(css)
  })
  
  doSentimentAnalysis <- reactive({
    
    step_score <- doSentimentByStep()
      step_score$freq <- ifelse(step_score$sentiment == "negative", -1 * step_score$freq, step_score$freq)
      step_score.sub <- subset(step_score, (step_score$sentiment == "negative" | step_score$sentiment == "positive"))
    
      emptySteps <- ddply(step_score.sub, .(step), summarise, freq = sum(abs(freq)))
      emptySteps <- subset(emptySteps, freq == 0, select = c("step"))
      
      step_score.sub <- subset(step_score.sub, !(step_score.sub$step %in% emptySteps$step) )
        
      return(step_score.sub)
      
    })
  
  
  
  doSentimentAnalysisPct <- reactive({
    
    step_score <- doSentimentByStep()
    
    step_score.sum <- ddply(step_score,.(step),summarise,total = sum(freq))
    step_score.sum$step <- as.character(step_score.sum$step)
    
    step_score <- left_join(step_score,step_score.sum, by = c("step" = "step"))
    step_score$pct <- round(step_score$freq / step_score$total,2) * 100
    
    step_score$pct <- ifelse(step_score$sentiment == "negative", -1 * step_score$pct, step_score$pct)
    step_score <- subset(step_score, step_score$sentiment == "negative" | step_score$sentiment == "positive")
    
    return(step_score)
  })
  
  doCommentSentimentAnalysis <- reactive(
    {
      comments_sentiment <- findSentiments()
      fr <- ddply(comments_sentiment, .(step,role), dplyr::summarize, 
                  comments = n(),total_likes = sum(likes),
                  total_wordCount = sum(wordCount), 
                  mean_likes= round(mean(likes),2),
                  mean_score=round(mean(score),2),
                  mean_wordCount=round(mean(wordCount),2),
                  pos_comments = round(length(id[score > 0])/n(),2)*100,
                  neg_comments = round(length(id[score < 0])/n(),2)*100, 
                  neu_comments = round(length(id[score == 0])/n(),2)*100)
      
      # We have to fill the gaps in the dataframe. Since this data is gouing to group by role, if there is no 
      # corresponding row for each step and any role, the graph shift the data to left to fill the gap by itself.
      # Then at the end of axis, there are empty bars.
      # So the following will find all missing steps for each role, and put 0 for each attribute column.
      fr$step <- as.character(fr$step)
      uniqueSteps <- unique(fr$step)
      uniqueRoles <- unique(fr$role)
      tmp <- merge(uniqueRoles,uniqueSteps)
      tmp <- tmp[ ,c(2,1)]
      colnames(tmp) <- c("step","role")
      tmp <- left_join(tmp,fr,by=c("step"="step","role"="role"))
      fr <- replace(tmp, is.na(tmp), 0)
      
      fr[,12:13] <- matrix(as.numeric(unlist(strsplit(as.character(fr[,1]), "[.]"))), ncol=2, byrow=TRUE)
      fr <- fr[with(fr,order(fr[,12],fr[,13])), ]
      fr[,12:13] <- list(NULL,NULL)
      return(fr)
    }
  )
  
  
  output$OriginalSentimentAnalysisResult <- renderHighchart(
    {
      query <- parseQueryString(session$clientData$url_search)
      if (!is.null(query[['course']]))
      {
        
        withProgress(message = 'Reading Data...', value = 0, {
          
          data <- doSentimentAnalysis()
          
          data$step <- as.character(data$step)
          
          positive <- data[data$sentiment=="positive",]
          negative <- data[data$sentiment=="negative",]
          
          h1 <- highchart(type = "chart") %>% 
            hc_title(text = "Sentiment Analysis on Comments") %>% 
            hc_subtitle(text = 'The sentiment score of comments has been calculated from the word dictionary provided by FutureLearn. Each sentence is divided to its words, using the dictionary positive and negative words will be identified. The score is the number of positive words subtracted by the number of negative words in a comment. If the score is greater (less) than 0 the comment is flagged as positive (negative) sentiment. If the score is 0, the comment has neutral sentiment.') %>%
            # create axis :)
            hc_yAxis(
              labels = list(formatter = JS("function() { return (Math.abs(this.value));}")),
                   title = list(enabled = TRUE, text = 'The total number of comments')
            ) %>% 
            hc_xAxis(
              list(title = list(text = "Step"), categories = unique(data$step))
            ) %>%
            # series :D
            hc_add_series_labels_values(negative$step, negative$freq,  
                                        type = "bar", name = "Negative Comments") %>% 
            hc_add_series_labels_values(positive$step, positive$freq, 
                                        type = "bar", name = "Positive Comments") %>% 
            hc_colors(c("lightpink","lightgreen"))%>%
            hc_tooltip(formatter = JS("function() { return '<b>Step:</b> '+ this.x 
                            + '<br><b>The number of ' + this.series.name +': </b>' + Math.abs(this.y) ;}")) %>%
            # I <3 themes
            #hc_chart(height = 700)%>%
            hc_exporting(enabled = TRUE) %>%
            hc_add_theme(hc_theme_smpl())
          
          
          
        })
        #h1$addParams(dom = 'OriginalSentimentAnalysisResult')
        #h1$chart(height=700)
        return(h1)
      }
    })
  
  output$OriginalSentimentAnalysisResultMultiBar <-renderHighchart({
    data <- doSentimentAnalysis()
    
    data$step <- as.character(data$step)
    negative <- subset(data, sentiment == "negative")
    negative$freq <- -1 * negative$freq
    
    positive <- subset(data, sentiment == "positive")
    
    
    highchart(type = "chart") %>% 
      hc_title(text = "Sentiment Analysis on Comments") %>% 
      hc_subtitle(text = "This chart shows the number of positive and negative comments at any step.") %>%
      # create axis :)
      hc_yAxis_multiples(
        list(title = list(text = "The number of negative comments")),
        list(title = list(text = "The number of positive comments"), opposite = TRUE)
      ) %>% 
      hc_xAxis(
        list(title = list(text = "Step"), categories = unique(data$step))
      ) %>%
      # series :D
      hc_add_series_labels_values(negative$step, negative$freq,  
                                  type = "column", yAxis = 0, name = "Negative Comments") %>%
      hc_add_series_labels_values(positive$step, positive$freq, 
                                  type = "column", yAxis = 1, name = "Positive Comments") %>% 
      # I <3 themes
      hc_colors(c("lightpink","lightgreen")) %>%
      hc_exporting(enabled = TRUE) %>%
      hc_add_theme(hc_theme_smpl())
  })
  
  output$OriginalSentimentAnalysisResultPct <- renderChart(
    {
      query <- parseQueryString(session$clientData$url_search)
      if (!is.null(query[['course']]))
      {
        
        withProgress(message = 'Reading Data...', value = 0, {
          
          css <- doSentimentAnalysisPct()
          
          css$sentiment <- ifelse(css$sentiment == "positive", "Positive Comments", "Negative Comments")
          
          h1 <- hPlot(
            y = 'pct', 
            x = 'step', 
            type = 'bar', 
            data = css,
            group = 'sentiment',
            title = "Sentiment Analysis on Comments",
            subtitle ='This chart shows the percentage of positive and negative comment per step. ')
          
          h1$plotOptions(series = list(stacking = 'normal'))
          
          h1$tooltip(formatter = "#! function() { return '<b>Step:</b> '+ this.point.category +
                     '<br>' + '<b>The percentage of ' + this.series.name + ': </b>' + 
                     Highcharts.numberFormat(Math.abs(this.point.y), 0)+ '%';} !#")
          
          h1$legend(reversed = "true")
          
          h1$xAxis(categories = unique(css$step),
                   title = list(text = 'Step'))
          h1$yAxis(min = -100, max = 100,labels = list(formatter = "#! function() { return (Math.abs(this.value));} !#"),
                   title = list(enabled = TRUE, text = 'The percentage of comments'))
          
          
          h1$colors(c('lightpink', 'lightgreen'))
          
          
          h1$exporting(enabled = TRUE)
          
      })
        h1$addParams(dom = 'OriginalSentimentAnalysisResultPct')
        h1$chart(height=700)
        return(h1)
    }
    })
  
  output$OriginalSentimentAnalysisStepTypePct <- renderChart(
    {
      query <- parseQueryString(session$clientData$url_search)
      if (!is.null(query[['course']]))
      {
        
        withProgress(message = 'Reading Data...', value = 0, {
          
          css <- doSentimentByStepType()
          
          
          h1 <- hPlot(
            y = 'pct', 
            x = 'type', 
            type = 'bar', 
            data = css,
            group = 'sentiment',
            title = "Sentiment Analysis on Comments by Step Type",
            subtitle ='This chart shows the percentage of positive and negative comment per step type. ')
          
          h1$plotOptions(series = list(stacking = 'normal'))
          
          h1$tooltip(formatter = "#! function() { return '<b>Step:</b> '+ this.point.category +
                     '<br>' + '<b>The percentage of ' + this.series.name + ' comments: </b>' + 
                     Highcharts.numberFormat(Math.abs(this.point.y), 0)+ '%';} !#")
          
          h1$legend(reversed = "true")
          
          h1$xAxis(categories = unique(css$type),
                   title = list(text = 'Step Type'))
          h1$yAxis(min = -100, max = 100,labels = list(formatter = "#! function() { return (Math.abs(this.value));} !#"),
                   title = list(enabled = TRUE, text = 'The percentage of comments'))
          
          
          h1$colors(c('lightpink', 'lightgreen'))
          
          
          h1$exporting(enabled = TRUE)
          
      })
        h1$addParams(dom = 'OriginalSentimentAnalysisStepTypePct')
        h1$chart(height=400)
        return(h1)
    }
    })
  
  
  
  output$OriginalSentimentByStep <- renderChart(
    {
      withProgress(message = 'Reading Data...', value = 0, {
      fr <- doSentimentByStep()

      stepOrder <- unique(fr$step)

      fr$y <- fr$freq

      hm <- rCharts:::Highcharts$new()
      hm$exporting(enabled = TRUE)
      hm$title(text = "Sentiment Analysis on Comments")
      hm$subtitle(text ='This chart shows the number of positive, negative and neutral comment per step. ')
      hm$xAxis(labels=list(rotation = 90),
               categories = stepOrder,
               title = list(text = 'Step'))
      hm$yAxis(title = list(text = "The number of comments"))

      positive <- fr[fr$sentiment=="positive",]
      negative <- fr[fr$sentiment=="negative",]
      neutral <- fr[fr$sentiment=="neutral",]
      hm$series(name = 'Positive', type='line', data= toJSONArray2(positive, json = F,names = T), color='lightgreen', xAxis=0, yAxis=0)
      hm$series(name = 'Negative', type='line', data= toJSONArray2(negative, json = F,names = T), color='lightpink', xAxis=0, yAxis=0)
      hm$series(name = 'Neutral', type='line', data= toJSONArray2(neutral, json = F,names = T), color='#DFE1DF', xAxis=0, yAxis=0)

      hm$tooltip(borderWidth=0, followPointer=TRUE, followTouchMove=TRUE, shared = TRUE,
                 formatter = "#! function()
                 { var tooltip = ''
                 for(i = 0 ; i < this.points.length; i++)
                 {
                 tooltip += 'The number of ' + this.points[i].series.name + ' comments: ' + this.points[i].y + '<br>'
                 }
                 for(i = 0 ; i < this.points.length; i++)
                 {
                 tooltip += 'The number of likes for ' + this.points[i].series.name + ' comments: ' + this.points[i].point.total_likes + '<br>'
                 }
                 return 'Step: ' + this.x + '<br>' + tooltip ;
                 }

                 !#")


      })
      hm$addParams(dom = 'OriginalSentimentByStep')

      return(hm)

    }  )
  
  
  
  output$OriginalSentimentCommentsByStep <- renderChart(
    {
      withProgress(message = 'Reading Data...', value = 0, {
        
        css <- doCommentSentimentAnalysis()
        
        hm3 <- Highcharts$new()
        hm3$exporting(enabled = TRUE)
        hm3$title(text = "Sentiment Analysis on Comments")
        hm3$subtitle(text ='This chart shows the number of positive, negative and neutral comment per step grouped by the role. ')
        
        hm3$xAxis(labels=list(rotation = 90),
                  categories = unique(css$step) ,
                  title = list(text = 'Step'))
        
        hm3$yAxis(list(
          list(title = list(text = 'Total number of comments')),
          list(title = list(text = 'The percentage of sentiment comments'))
        ))
        
        css$y <- css$comments
        
        learner <- css[css$role=="learner",]
        educator <- css[css$role=="educator",]
        pos_comment <- learner
        pos_comment$y <- pos_comment$pos_comments
        neg_comment <- learner
        neg_comment$y <- neg_comment$neg_comments
        
        hm3$series(name = 'Learners', type='column', data= toJSONArray2(learner, json = F,names = T), color='lightblue', xAxis=0, yAxis=0)
        if(nrow(educator) > 0)
        {hm3$series(name = 'Educators', type='column', data= toJSONArray2(educator, json = F,names = T), color='#FFC133', xAxis=0, yAxis=0)}
        hm3$series(name = 'Percentage of Positive Comments by Learners', type='line', data= toJSONArray2(pos_comment, json = F,names = T), color='lightgreen', xAxis=0, yAxis=1)
        hm3$series(name = 'Percentage of Negative Comments by Learners', type='line', data= toJSONArray2(neg_comment, json = F,names = T), color='lightpink', xAxis=0, yAxis=1)
        
        hm3$legend(align = 'center', verticalAlign = 'bottom', layout = 'vertical')
        
        
        if(nrow(educator) > 0)
        {
          hm3$tooltip(borderWidth=0, followPointer=TRUE, followTouchMove=TRUE, shared = TRUE,
                      formatter = "#! function(args)
                      { return 'Step: ' + this.x + '<br>'
                      + 'The number of comments by ' + this.points[0].series.name + ': ' + this.points[0].y + '<br>'
                      + 'The number of comments by ' + this.points[1].series.name + ': ' + this.points[1].y + '<br>'
                      + 'The percentage of positive comments by Learners : ' + this.points[2].y + '%<br>'
                      + 'The percentage of negative comments by Educators : ' + this.points[3].y + '%<br>'
                      + 'The number of likes by ' + this.points[0].series.name + ': ' + this.points[0].point.total_likes + '<br>'
                      + 'The number of likes by ' + this.points[1].series.name + ': ' + this.points[1].point.total_likes + '<br>'
                      + 'The average number of likes by ' + this.points[0].series.name + ': ' + this.points[0].point.mean_likes + '<br>'
                      + 'The average number of likes by ' + this.points[1].series.name + ': ' + this.points[1].point.mean_likes ;
                      }
                      
                      !#")}
        else
        {
          hm3$tooltip(borderWidth=0, followPointer=TRUE, followTouchMove=TRUE, shared = TRUE,
                      formatter = "#! function(args)
                      { return 'Step: ' + this.x + '<br>'
                      + 'The number of comments by ' + this.points[0].series.name + ': ' + this.points[0].y + '<br>'
                      + 'The number of comments by ' + this.points[1].series.name + ': ' + this.points[1].y + '<br>'
                      + 'The percentage of positive comments by Learners : ' + this.points[2].y + '%<br>'
                      + 'The number of likes by ' + this.points[0].series.name + ': ' + this.points[0].point.total_likes + '<br>'
                      + 'The number of likes by ' + this.points[1].series.name + ': ' + this.points[1].point.total_likes + '<br>'
                      + 'The average number of likes by ' + this.points[0].series.name + ': ' + this.points[0].point.mean_likes + '<br>'
                      + 'The average number of likes by ' + this.points[1].series.name + ': ' + this.points[1].point.mean_likes ;
                      }
                      
                      !#")}
      })
      
      hm3$addParams(dom = 'OriginalSentimentCommentsByStep')
      
      return(hm3)
      
}  )
}

shinyApp(ui, server)
