FutureLearn CSV Datafiles Downloader Script
=============================================
Developer : Mahsa Chitsaz (m.chitsaz@unsw.edu.au) and Andrew Clayphan (a.clayphan@unsw.edu.au)

Last Updated : 5 June 2017 by Mahsa Chitsaz

This script will automate the downloads of the FutureLearn '.csv' data files. It it based on the current FutureLearn website layout configuration (as of June 2017).
 If FutureLearn changes their login page, website path navigation or layout, this script may fail. Once a FutureLearn API becomes available parts of this script should be deprecated.

Note: This script is needed to run in a daily basis to update the database from the available data in the FutureLearn website.
 
Library Prerequisites
------------
Tested as working for Python 2.7.9+ on both Windows/Linux. Should work on any platform, as long as the libraries are installed. 

The following Libraries are required:
* logging
* ConfigParser
* numpy
* pandas
* traceback
* os
* datetime
* time
* MySQLdb
* sqlalchemy
* subprocess

How to run
---------------------------
```bash
$ cd 03_ExportsDownloader
$ python main.py
note: configuration options are done in 'config.txt', there are no command line arguments.
```

Configuration Setup
---------------------------
See file ```config.txt```

Options (general section):
* username: your futurelearn username
* password: your futurelearn password
* wait_time_seconds: to help with slow connections, set to a default of 5 seconds
* place_files_in_data_directory: where to download the CSV files to (if left blank, will download to the current directory, if does not exist, it will try to create the folder)
* use_course_name_as_folder: create a folder by the course name and store all CSV files in such a folder.
* download_enable: if set to True, the download script can be ran.
* use_course_slugs: If set to True, the course slugs from course_slugs variables will be considered. 
* course_slugs: a list of course names in the format <course_slug>, <version> each entry separated by a newline
* use_active_courses: the active courses will be considered for download. 
* use_inprogress_courses: the in-progress courses will be considered for download.


Options (database section):
* db_host: your database host
* db_name: your database name
* db_user: your database username
* db_pass: your database password


Options (Rscript Preprocessing):
* preprocessing_enable: if set to True, the R script will be ran to prepare the data for visualisation.
* path_to_script: where the R script is stored.
* config_file: where the R config file is stored.

Options (SQL script):

For each CSV file, the SQL CREATE TABLE script is stored in this section that should not be touched. If FutureLearn added a new column to CSV files, the script has to be changed accordingly.

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
