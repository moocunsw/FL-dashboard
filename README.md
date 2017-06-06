FutureLearn MOOC Dashboard
================================

Here is the summary of the needed processes to create FutureLearn dashboard.
1. A global database (futurelearn_courses_information) is designed to store all information regarding the file exports. 
	1. The SQL script (01_SQL dump/futurelearn_courses_information.sql) has to be ran only once.
2. Whenever, a new course is added into the FutureLearn website, its information has to be inserted into different tables in this global database:
	1. Course name, abbreviated course name from FutureLearn, week duration, start and end date as well as its activeness and status at FutureLearn website has to be inserted into course_information table.
	2. All available CSV file names for the new course has to be inserted into the file_course_information table. Therefore [Course Information Downloader](02_CorseStepInfoDownloader/importAllStepInformation.py) has to be ran to add all information into the global database.
	3. All step types are needed for the visualisations, therefore [Step Information Downloader](02_CorseStepInfoDownloader/importAllStepInformation.py) has to be ran first to add these meta data to the course_information_details table.
3. The CSV files are downloaded from FutureLearn website for any available MOOC daily using [Exports Downloader](03_ExportsDownloader/main.py). 
	1. Each course has multiple CSV files that are located in a folder named as course title. The list of these file names will be fetched from the global database;
	2. Every time, new CSV files are downloaded the previous CSV files will be archived. Otherwise, these will be rewritten by new CSV files;
	3. There exists a database named as \<course_name\>-\<version\> for each course in database;
	4. Every time, new CSV files are downloaded, the data will be stored in \<course_name\>-\<version\> database. If multiple times this occurs, previous data will be lost in database.
	5. All the timing and error information will be logged into the global database.
	6. There are different R outines that process the raw data to be ready for visualisation. It is part of the [Exports Downloader script](03_ExportsDownloader\Rscript\preprocessing.R)
		1. These routines will be ran once the raw data is downloaded from FutureLearn website;
		2. Each routine will process data for specific visualisation then insert it into course database by the table name of vis_\<visualisation_name\>. For example, for the visualisation of EnrolmentsByDay the routine insertEnrolmentsByDayToDb is created in the pre-processing R script. 
5. Create a shinyapp page for each visualisation that read the underling data from database, it is available in [FutureLearn dashboard](/04_futurelearn-dashboard);
	1. This includes the R code that creates interactive charts.
	2. For each visualisation, there is a new folder that has the App.R, e.g. EnrolmentByDay chart can be found at EnrolmentsByDay which reads the data from vis_EnrolmentsByDay table in the database. 
6. Create a [web application](05_WebApplication/FLshowcase.html) that can open each visualisation in an iframe by choosing the course name and the type of visualisations from two dropdowns.


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

 The original code was written by Dr. Mahsa Chitsaz, Educational Data Scientist and Dr. Andrew Clayphan, Educational Data Scientist
 in the Portfolio of the Pro-Vice Chancellor Education PVC(E) at UNSW Sydney, Australia.

 For further information, requests to access the repo as developer, comments and feedback,
 please contact education.data@unsw.edu.au
