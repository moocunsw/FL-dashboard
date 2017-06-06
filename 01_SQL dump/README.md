Global Database
================================
Developer : Mahsa Chitsaz (m.chitsaz@unsw.edu.au)
Last Updated : 5 June 2017 by Mahsa Chitsaz


Overview
=========

The futurelearn_courses_information database is designed to store all metadata regarding the MOOCs offered in FutureLearn website. It stores information regarding, the visualisation tables, the CSV files in the MOOCs. 

The script will create the futurelearn_courses_information database in MySQL database. 

The database model is shown as follows:

<p align="center">
  <img src="database_model.jpg" width="350"/>
</p>

Tables
======
The metadata tables that store information about course, CSV files, visualisation table, and columns.
1. course_information: It stores literraly what is available in the course admin page of the FutureLearn website, e.g. course name, duration week, start and end dates, etc.
2. course_information_details: It stores the step information from each MOOC in the FutureLearn website, e.g. step number, title, type, content, etc. 
3. file_information: It stores the file name of the CSV files available in the FutureLearn website.
4. vis_table_information: The name of the visualisation table is stored.
5. column_information: The column name and type of the columns for the tables in the CSV files are stored.

The bridging table to store the intermediate information:
1. course_file_information: The available CSV files to be downloaded for any MOOC are stored.
2. file_column_information: The column information of any CSV files are stored.
3. vis_table_file_information: The required CSV files for compuation of the visualisation routines in the R script are stored.

The logging information are stored in the following tables:
1. course_logging_table: Any transaction happening in the R/Python script will be logged.
2. error_logging_table: Any error message during the compuation will be stored.


Manual insertion
================

In order to run the Python and R script, the futurelearn_courses_information has to store the metadata. Some of those data has to be inserted manually.


vis_table_information
--------------------
This table stores information regarding the table name of each visualisation. Basically, each visualisation has a source table that is listed in this table. We have already inserted all those needed that further will be used in the web application. 
If a new visualisation is added that takes a while to process the data, the source code has to be added to the ExportsDownloader/Rscript/preprocessing.R and its name has to be added to the vis_table_information table.
Then the underling CSV files for such a new visualisation has to be added to vis_table_file_information.
For example, vis_network_analysis table has added and it uses the enrolments and step_activity files:

```
INSERT INTO `futurelearn_courses_information`.`vis_table_information`(`vis_table_name`) 
VALUES('vis_network_analysis');
# After insertion the id of vis_network_analysis is 35, 
# and the file id for enrolments and step_activity are 2 and 4 respectively:
INSERT INTO `futurelearn_courses_information`.`vis_table_file_information`(`vis_table_id`,`file_id`)
VALUES(35,2),(35,4);
```
By such an insertion, for any MOOC that has both enrolments and step_activity files, the code for vis_network_analysis table will be ran.

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
