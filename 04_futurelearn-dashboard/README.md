Web Application - Shiny R
================================
Developer : Mahsa Chitsaz (m.chitsaz@unsw.edu.au)

Last Updated : 5 June 2017 by Mahsa Chitsaz

Overview
=========
There are multiple folders that contains the Shiny app code for visualising different plots or table. 
For all of the App.R files and any MOOC in FutureLearn, 
the CSV files have to be stored in a database named by the FutureLearn abbrivation for that MOOC (the one that is in the url of the FL website). 

How to run
------------
Run the App.R in any folder and use the 'course' argument in the url to specify what course, e.g. http://localhost:3838?course=through-engineers-eyes-3.


Prerequisities
--------------
The following R libraries has to be installed on the R server by the given commands:

```
install.packages("RMySQL")
install.packages("shiny")
install.packages("rCharts")
install.packages("highcharter")
install.packages("visNetwork")
install.packages("ggplot2")
install.packages("treemap")
install.packages("viridisLite")
install.packages("xts")
install.packages("plyr")
install.packages("dplyr")
install.packages("data.table")
install.packages("tm")
install.packages("wordcloud")
install.packages("countrycode")
install.packages("DT")
```

Setup the R Config file
---------------------
In the config file, all credentials related to login in to the database has to be given. For some libraries, the JAVA_HOME address of the mashine has to be listed.
* db_host: your database host
* db_name: your database name
* db_user: your database username
* db_pass: your database password

List of visualisations
----------------------
Demographics information:
* __Demographics_EducationDistribution__: This chart shows the number of learners with different education levels based on the data in enrolments file. 
* __Demographics_EmploymentAreaDistribution__: This chart shows the number of learners with different education levels based on the data in enrolments file.
* __Demographics_GenderAgeDistribution__: This chart shows the number of learners for each gender vs their age range on the data in enrolments file. 
* __Demographics_GenderDistribution__: This chart shows the percentage of gender distribution among learners based on the data in enrolments file. 
* __Demographics_GenderEmploymentDistribution__: This chart shows the number of learners for each gender vs their employment statuses on the data in enrolments file. 
* __Demographics_GenderGeographicalDistribution__: This chart shows the number of female or male learners enrolled in the course from each country based on the data in enrolments file. The size and color of the chart are based on the number of female and male learners respectively.
* __Demographics_GeographicalDistribution__: This chart shows the number of learners enrolled in the course from each country based on the data in enrolments file.

Enrolments information:
* __Enrolment_EnrolmentsByDay__: This chart shows the cumulative growth of enrollments from the first time a learner enrolled.
* __Enrolment_EnrolmentsByWeek__: This chart shows the accumulative number of enrollments per week.

Learner's step activity:
* __Activity_ActivityByStep__: The first chart shows the percentage of each group of activities for every step. 'Visits' shows the percentage of those who visited but not completed. The next chart shows the number of each activity for every step. The Completion, Visits, Comments and Likes are the number of completed steps, the number of visited (includes completed) and the number of comments and likes by learners respectively.
* __Activity_HoursSpendByWeek__: The first chart shows the percentage of learners who spend different hours in each week. The hour spent is calculated based on the first time a learner visited any step and the last time the learner completed the step. The learners have to complete a step to be included in this chart. The next chart shows the number of learners who spend different hours in each week. The last chart shows the percentage of learners who spend different hours in each week. The hours spend is capped to the selected option.
* __Activity_LastProgressesByDate__: The chart shows the number of learners who disengaged from the course at any date, as well as the number of learners who finished the course on the date.
* __Activity_LastProgressesByStep__: This chart shows the number of learners who disengaged from the course at any step.
* __Activity_LearnersActivities__: The first chart shows the number of learners for each type by Week. Learners are users who have at least viewed at least one step at anytime in any course week. This includes those who go on to leave the course. Active learners are those who have completed at least one step at anytime in any course week, including those who go on to leave the course. Returning Learners are those who completed at least a step in at least two distinct course weeks. These do not have to be sequential or consecutive, nor completed in different calendar weeks. Social Learners are those who have posted at least one comment on any step. The second chart shows the average number of participants groupbed by different types over the course period.
* __Activity_LearnersActivitiesByDay__: This chart shows the number of learners who spend different minutes in each step.
* __Activity_MinutesSpendByStep__: This chart shows the number of learners who spend different minutes in each step.
* __Activity_StepProgressCountsHeatmap__: The first chart shows the activity heatmap of step vs week. The Coloring is based on the number of learners who visited the step at the given week. The next chart also shows the heatmap of step activity vs week. 
* __Activity_Transition3StepsByType__: The chart shows the transitions of learners among steps. The chart also shows the total number of visits from each step type to another considering all n-step transitions in the course. 
* __Activity_TransitionByType__: This network shows the transition of learners among materials of all weeks based on the step type. The step type comes from the label which is shown in the course page that has been designed by the educators. 
* __Activity_TransitionByWeek__: This network shows the transition of learners among materials of all weeks. 
* __Activity_TransitionByWeekSelection__: This network shows the transition of learners among materials for the selected week.
* __Activity_VisitedFirstStepFinishedAllSteps__: This chart shows the number of learners who visited the first step for each week and finished all the steps afterwards. The green line shows the percentage of such students.

Comment activities:
* __Comments_AfinnSentimentAnalysisResult__: [Afinn Method](http://neuro.imm.dtu.dk/wiki/AFINN) has been used to find the sentiment score of comments. 
* __Comments_BingSentimentAnalysisResult__: [Bing Method](https://www.cs.uic.edu/~liub/FBS/sentiment-analysis.html) has been used to find the sentiment score of comments.
* __Comments_CommentsHistogramByLearners__: This chart shows the number of comments made by different number of learners.
* __Comments_CommentsOverviewTable__: The table shows the basic statistics about the comments given by learners such as total number of comments and likes, unique number of authors, median/average word count per comment or per person, and average/maximum number of reply per comment.
* __Comments_CommentsStatsByStepRole__: This chart shows the number of comments at any step given by learners or educators.
* __Comments_CommentsStatsDay__: This chart shows the number of comments at any date.
* __Comments_CommentsStatsDayType__: This chart shows the number of comments for each step type (Article, Discussion and Video) at any date.
* __Comments_CommentsStatsStep__: The first chart shows the number of comments and likes at any step. The following charts individually show the number of comments and likes at any step.
* __Comments_CommentsSummaryByEducators__: This chart shows the number of comment made by different educators.
* __Comments_OriginalSentimentAnalysisResult__: The sentiment score of comments has been calculated from the word dictionary provided by FutureLearn. The first chart shows the number of positive and negative comment per step. The second chart shows the number of positive and negative comments at any step. The third chart shows the percentage of positive and negative comment per step. The forth chart shows the number of positive, negative and neutral comment per step. The last chart shows the number of positive, negative and neutral comment per step grouped by the role of authors.
* __Comments_Top10CommentsByLikes__: The table shows the top 10 comments by the highest likes.
* __Comments_WordCloudOfOriginalSentimentAnalysis__
* __Comments_WordCountAnalysisByRole__: The chart shows three metrics by word count analysis, namely the accumulation of words in all comments by the participant role, the number of comments made by each group, the percentage of accumulated words by two groups of learners and educators. 
* __Comments_WordCountSummary__: This chart shows the number of comments by all participants containing different number of words.
* __Comments_WordCountSummaryByEducators__: This chart shows the number of comments containing different number of words for each educators.

Quizzes or Test activities:
* __Quizzes_AttemptToCorrect__: This chart shows the number of learners who correctly answered a quiz by the number of attempts. The number of attempts are limited to 5 levels.
* __Quizzes_ItemMap__: The chart shows the difficulty of each question provided by the Rasch model. The result of both first and last attempts are shown.
* __Quizzes_PersonMap__: The chart shows the number of learners by different scores. The result of both first and last attempts are shown.
* __Quizzes_QuestionResponseOverview__: This chart shows the number of learners by the overall percentage of answering the question correctly. The data is normalised for all learners based on dividing the total questions for each quiz to the total number of attempts for the quiz.
* __Quizzes_QuizAttempts__: This chart shows the number of correct and incorrect attempts for each quiz question.
* __Quizzes_RaschAnalysisSummary__: Rasch modelling can be used to produce a logistical representation of both learner ability and question difficulty. This data is based upon quiz/test performance for all students, taking only their first/last attempt at each question.
* __Quizzes_StepVisitedDuringQuizAttempt__: This chart shows the percentage/number of the visited step per week when a learner visited such step during answering a quiz question. 

Peer review:
* __PeerReview_PeerReviewViewer__: Showing the assignments and its peer reviews.

License
=======
The project is developed to provide re-usable analytics building blocks supporting the sense-making process of
 learners' and educators' activity in FutureLearn MOOCs.
 The original data sources are provided by FutureLearn to partners as files in CSV format. The code shared in this
 repository is based on a specific database conversion, and the overall architecture are documented in the README file.

 The scripts are provided 'as is' WITHOUT ANY WARRANTY. The key is to encourage others in the community
to share knowledge, expertise and experiences, contributing to the project and benefit each other in the process.

 For this reason, the code is released under GNU Affero General Public License, version 3.
 For a quick summary see: https://tldrlegal.com/license/gnu-affero-general-public-license-v3-(agpl-3.0)
 Full details of the license see: https://www.gnu.org/licenses/agpl.html

 The original code was written by Dr. Mahsa Chitsaz, Educational Data Scientist
 in the Portfolio of the Pro-Vice Chancellor Education PVC(E) at UNSW Sydney, Australia.

 For further information, requests to access the repo as developer, comments and feedback,
 please contact education.data@unsw.edu.au
