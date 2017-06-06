FutureLearn Course and Step Meta-data Downloader Script
=============================================
Developer : Mahsa Chitsaz (m.chitsaz@unsw.edu.au) and Andrew Clayphan (a.clayphan@unsw.edu.au)

Last Updated : 5 June 2017 by Mahsa Chitsaz


The script downloads course name, abbreviated course name from FutureLearn (FL), week duration, start and end date as well as its activeness and status at FL website.
It also download meta-data about the steps in a FutureLearn course. For example 1.1 article, 1.2 discussion, 1.3 video and so on.

This is based on the current FutureLearn website layout configuration (as of June 2017). If FutureLearn changes their login page, website path navigation or layout, this script may fail. Once a FutureLearn API becomes available parts of this script should be deprecated.

Provides the following meta-data about a course: 
* course name	(e.g. Environmental Humanities: Remaking Nature)
* abbreviated course name from FutureLearn (e.g. remaking-nature)
* duration week
* end date	
* start date	
* version	
* active	
* status	
* organisation
* step number (e.g. 1.1, 1.2, 1.3 etc)
* title
* type (e.g. Article/Discussion/Video/Exercise/Quiz/etc.)
* date information
    * the date just under the week block heading (e.g. 21 May)
    * the date as a YYYY-MM-DD
* week heading
* week label (e.g. Week 1)

Outputs a CSV file for each course that can be loaded to a database. Such information will be loaded to course_information, course_information_details, and course_file_information tables in the global database.

Note: This script needs to be ran whenever a new MOOC is available in the FutureLearn website, or any changes to the structure of MOOC.

Library Prerequisites
------------
Tested as working for Python 2.7.9+ on both Windows/Linux. Should work on any platform, as long as the libraries are installed. 

The following Libraries are required:
* re
* logging
* ConfigParser
* os
* datetime
* time
* string
* pandas
* lxml
* csv
* MySQLdb
* sqlalchemy

How to run
---------------------------
```bash
$ cd 02_CourseStepInfoDownloader
$ python importAllStepInformation.py
```
note: configuration options are done in 'config.txt', there are no command line arguments.

Configuration Setup
---------------------------
See file ```config.txt```

Options (general section):
* username: your futurelearn username
* password: your futurelearn password
* wait_time_seconds: to help with slow connections, set to a default of 5 seconds
* place_files_in_data_directory: where to download the CSV files to (if left blank, will download to the current directory, if does not exist, it will try to create the folder)
* course_slugs: a list of course names in the format <course_slug> <version> (there is a space between course_slug and version), and each entry must be separated by a newline
* use_inprogress_courses: If set to True, in-progress courses will be considered.
* use_active_courses: If set to True, active courses will be considered.
* organisations: a list of instituation names, and each entry must be separated by a newline. 
* export_enable: if not set to True, the step meta-data information will NOT be fetched from the FutureLearn course website(s)

Options (database section):
* db_host: your database host
* db_name: your database name
* db_user: your database username
* db_pass: your database password

Options (Course info section):
* export_enable: If True, parse the futurelearn.com/admin/courses website for a list of all the courses and put it in CourseSlugData and CourseSlugFileInfo csv files.
* db_export_enable: if True, will look for CourseSlugData and CourseSlugFileInfo files and upload to a database

Options (Step info section):
* export_enable: if True, it download the step information of the given course list
* db_export_enable: if True, will look for files in the output path (set in place_files_in_data_directory option) and upload to a database


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
