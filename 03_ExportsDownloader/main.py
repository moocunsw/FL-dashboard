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
# The original code was written by Dr. Mahsa Chitsaz, Educational Data Scientist and Dr. Andrew Clayphan, Educational Data Scientist
# in the Portfolio of the Pro-Vice Chancellor Education PVC(E) at UNSW Sydney, Australia.
#
# For further information, requests to access the repo as developer, comments and feedback,
# please contact education.data@unsw.edu.au
#
# ************************************************************************************************

# ---------------------------------------------------------------------------------
#
# Download script for grabbing FutureLearn Files
#
# Note: Requires Python >= 2.7.9 (e.g. 2.7.9/2.7.10/2.7.11)
#
#
# ---------------------------------------------------------------------------------
import logging
import numpy as np
import pandas as pd
import traceback
import requests
from bs4 import BeautifulSoup
from datetime import datetime
import MySQLdb
import ConfigParser
import os
import time
from sqlalchemy import create_engine
import subprocess

def add_error_file(course_name, file_name):
            cp.error_files = {}
            if course_name not in cp.error_files.keys():
                cp.error_files[course_name] = [file_name]
            else:
                temp = cp.error_files[course_name]
                if file_name not in temp:
                    temp.append(file_name)
            return cp.error_files

class ConfigParameters:
    def __init__(self,config_file):
        # Set up a quick to the console logger ---------------------------------------------
        self.logger = logging.getLogger('futurelearn_data_downloader')
        logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', datefmt='%Y-%m-%d %I:%M:%S %p')
        self.logger.setLevel(logging.INFO)

        # Configuration options ------------------------------------------------------------
        self.config = ConfigParser.ConfigParser(allow_no_value=True)
        self.config.read(config_file)
        self.wait_time_seconds = self.config.getint("general", "wait_time_seconds")
        self.username = self.config.get("general", "username")
        self.password = self.config.get("general", "password")
        self.db_host = self.config.get("database", "db_host")
        self.db_name = self.config.get("database", "db_name")
        self.db_user = self.config.get("database", "db_user")
        self.db_pass = self.config.get("database", "db_pass")
        self.sql_scripts = {}
        self.sql_scripts['comments'] = self.config.get("sql_script", "comments")
        self.sql_scripts['enrolments'] = self.config.get("sql_script", "enrolments")
        self.sql_scripts['question_response'] = self.config.get("sql_script", "question_response")
        self.sql_scripts['step_activity'] = self.config.get("sql_script", "step_activity")
        self.sql_scripts['peer_review_assignments'] = self.config.get("sql_script", "peer_review_assignments")
        self.sql_scripts['peer_review_reviews'] = self.config.get("sql_script", "peer_review_reviews")
        self.sql_scripts['team_members'] = self.config.get("sql_script", "team_members")
        self.sql_scripts['campaigns'] = self.config.get("sql_script", "campaigns")
        self.sql_scripts['question_response_v2'] = self.config.get("sql_script", "question_response_v2")

        self.use_active_courses = self.config.getboolean("general", "use_active_courses")
        self.use_inprogress_courses = self.config.getboolean("general", "use_inprogress_courses")
        self.download_enable = self.config.getboolean("general", "download_enable")
        self.preprocessing_enable = self.config.getboolean("rscript", "preprocessing_enable")
        self.use_course_name_as_folder = self.config.getboolean("general", "use_course_name_as_folder")

        if len(self.username.strip()) == 0 or len(self.password.strip()) == 0:
            self.logger.error("Username or Password is blank... Fill it in, in the config, Aborting now....")
            exit()

        if len(self.db_host.strip())==0 or len(self.db_name.strip())==0 or len(self.db_user.strip())==0 or len(self.db_pass.strip())==0:
            self.logger.error("Database connection is blank... Fill it in, in the config, Aborting now....")
            exit()

        # Create a dictionary of file names for each course that any error occurred on fetching it.
        # This list will be further used to not preprocessing on those files.
        self.error_files = {}

        # Create connection to database
        self.db = MySQLdb.connect(host=self.db_host, user=self.db_user,
                             passwd=self.db_pass, db=self.db_name,
                             charset='utf8', use_unicode=True)
        cursor = self.db.cursor()
        # Find all databases which wil be used further to create one for a course if not existed
        cursor.execute("show databases")
        self.databases = cursor.fetchall()
        cursor.close()

        # Get all file names for each active course to be used to hit the FutureLearn website.
        cursor = self.db.cursor()
        cursor.callproc("get_active_course_file_names")
        self.course_information = cursor.fetchall()
        cursor.close()

        # Get a list of all active courses
        if self.config.getboolean("general", "use_course_slugs") is True:
            items = [x.strip() for x in self.config.get("general", "course_slugs").split("\n")]
            self.active_courses = [filter(None, map(str.strip, item.split(","))) for item in items] # list of ['course_slug', 'version']
        elif self.use_active_courses is True:
            cursor = self.db.cursor()
            cursor.callproc("get_active_courses")
            self.active_courses = cursor.fetchall()
            cursor.close()
        elif self.use_inprogress_courses is True:
            cursor = self.db.cursor()
            cursor.callproc("get_inprogress_courses")
            self.active_courses = cursor.fetchall()
            cursor.close()
        else:
            self.logger.error("Have not set one of: 'use_inprogress_courses'/'use_active_courses'/'use_course_slugs' to TRUE.")
            exit(1)

        # Remove all courses and files from course_information that is not listed in the active_courses
        to_be_removed = []
        for cf in range(0, len(self.course_information)):
            course = self.course_information[cf][0]
            version = self.course_information[cf][1]

            for i in range(0, len(self.active_courses)):
                ac_course = self.active_courses[i][0]
                ac_version = self.active_courses[i][1]
                if course == ac_course and str(version) == str(ac_version):
                    to_be_removed.append(cf)

        self.course_information = [i for j, i in enumerate(self.course_information) if j in to_be_removed]

        # Get all column names and types for all csv files, which will be used to store the csv file into db.
        # Note from ajc: Returns a tuplelist of (filename, column_name, column_type)
        cursor = self.db.cursor()
        cursor.callproc('get_file_column_names')
        self.file_column_names = cursor.fetchall()
        cursor.close()


        self.cursor = self.db.cursor()

        # Specify where the files will be written to --------------------------------------
        self.place_files_in_data_directory = self.config.get("general", "place_files_in_data_directory")
        if len(self.place_files_in_data_directory.strip()) == 0:
            self.output_path = os.getcwd()
        else:
            self.output_path = self.place_files_in_data_directory
            # create the folder
            if not os.path.exists(self.output_path):
                os.makedirs(self.output_path)

def find_all_file_names_by_course(c, v):
    file_names = []
    for ci in cp.course_information:
        if ci[0] == c and str(ci[1]) == str(v):
            file_names.append(ci[2])
    return file_names

def EmptyTablesInDataBase():
    # Make sure there exists a database names <course_slug>-<version> and it has all appropriate tables for each file.
    for a_course in cp.active_courses:
        course_name = a_course[0]
        version = a_course[1]

        target_db_name = course_name + '-' + str(version)
        existed_db = False
        for database in cp.databases:
            if database[0] == target_db_name:
                existed_db = True
                break

        if not existed_db:
            cp.cursor.execute("CREATE DATABASE `{0}`  DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;".format(target_db_name))
            cp.db.commit()

        # Create the table for each file based on the script provided in the config file
        course_db = MySQLdb.connect(host=cp.db_host, user=cp.db_user, passwd=cp.db_pass, db=target_db_name, charset='utf8', use_unicode=True)
        course_cursor = course_db.cursor()
        course_cursor.execute("show tables")
        tables = course_cursor.fetchall()
        # Flatten the list of lists
        tables = [item for sublist in tables for item in sublist]

        # Find all available files for each course from database
        file_names = find_all_file_names_by_course(course_name, version)

        for file in file_names:
            if file in tables:
                # Truncate all tables in the database
                try:
                    course_cursor.execute("TRUNCATE TABLE {0};".format(file))
                    course_db.commit()
                except Exception, e:
                    error_message = "Could not truncate {0} table at {1} database.".format(file, target_db_name)
                    args = [str(datetime.now()), error_message]
                    cp.logger.error(error_message)
                    cp.cursor.callproc("insert_error_logging_table", args)
                    cp.db.commit()
            else:
                # Create the table from the config file
                try:
                    course_cursor.execute(cp.sql_scripts[file])
                    course_db.commit()
                except Exception, e:
                    error_message = "Could not create {0} table at {1} database.".format(file, target_db_name)
                    cp.logger.error(error_message)
                    args = [str(datetime.now()), error_message]
                    cp.cursor.callproc("insert_error_logging_table", args)
                    cp.db.commit()


# FutureLearn has changed the schema of the comments table in their dashboard on 21 Nov 2016,
# to make all the tables with the same schemas I have added this function to add the missed columns.
# In case of any missing columns, the function will drop the table and create the table with the new schema frm the
# config file.
def AddNewColumnsToCommentsFile(df, target_db_name):
    drop_table = False
    if 'first_reported_at' not in df.columns.values:
        df['first_reported_at'] = np.nan
        drop_table = True
    if 'first_reported_reason' not in df.columns.values:
        df['first_reported_reason'] = np.nan
        drop_table = True
    if 'moderation_state' not in df.columns.values:
        df['moderation_state'] = np.nan
        drop_table = True

    # Create the table for each file based on the script provided in the config file
    course_db = MySQLdb.connect(host=cp.db_host, user=cp.db_user, passwd=cp.db_pass, db=target_db_name, charset='utf8', use_unicode=True)
    suffix = 'comments'
    if drop_table:
        course_cursor = course_db.cursor()
        course_cursor.execute("DROP TABLE {0};".format(suffix))
        course_db.commit()

        course_cursor.execute(cp.sql_scripts[suffix])
        course_db.commit()

        course_cursor.close()
    course_db.close()

    return(df)

def AddNewColumnsToQuestionResponseFile(df, target_db_name):
    drop_table = False
    if 'question_type' in df.columns.values and 'cloze_response' in df.columns.values:
        drop_table = True

    # Create the table for each file based on the script provided in the config file
    if drop_table:
        course_db = MySQLdb.connect(host=cp.db_host, user=cp.db_user, passwd=cp.db_pass, db=target_db_name, charset='utf8', use_unicode=True)
        suffix = 'question_response'

        course_cursor = course_db.cursor()
        course_cursor.execute("DROP TABLE {0};".format(suffix))
        course_db.commit()

        course_cursor.execute(cp.sql_scripts['question_response_v2'])
        course_db.commit()

        course_cursor.close()
        course_db.close()

def AddNewColumnsToEnrolmenFile(df, target_db_name):
    drop_table = False
    suffix = 'enrolments'
    if 'detected_country' not in df.columns.values:
        df['detected_country'] = np.nan
        drop_table = True
    else:
        query = "SELECT column_name FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='{0}' and TABLE_NAME = '{1}';".format(target_db_name,suffix)
        course_db = MySQLdb.connect(host=cp.db_host, user=cp.db_user, passwd=cp.db_pass, db=target_db_name, charset='utf8', use_unicode=True)
        course_cursor = course_db.cursor()
        course_cursor.execute(query)
        column_names = course_cursor.fetchall()
        course_db.commit()
        course_db.close()
        if 'detected_country' not in column_names:
            drop_table = True

    # Create the table for each file based on the script provided in the config file
    course_db = MySQLdb.connect(host=cp.db_host, user=cp.db_user, passwd=cp.db_pass, db=target_db_name, charset='utf8', use_unicode=True)

    if drop_table:
        course_cursor = course_db.cursor()
        course_cursor.execute("DROP TABLE {0};".format(suffix))
        course_db.commit()

        course_cursor.execute(cp.sql_scripts[suffix])
        course_db.commit()

        course_cursor.close()
    course_db.close()

    return(df)

def DownloadCSVFiles():
    # Log into FutureLearn -------------------------------------------------------------
    sign_in_page = "https://www.futurelearn.com/sign-in"
    cp.logger.info("Logging into the futurelearn website (wait 5 seconds)")

    loginInfo = requests.session()
    web = loginInfo.get(sign_in_page)
    html = web.content
    soup = BeautifulSoup(html, 'html.parser')
    tags = soup.find_all(['input'])
    login_data = {}
    for tag in tags:
        if tag.has_attr('value') and tag.has_attr('name'):
            login_data[tag['name']] = tag['value']
    login_data['email'] = cp.username
    login_data['password'] = cp.password
    rep = loginInfo.post(sign_in_page,data = login_data)

    if rep.status_code == 200:
        # Give the driver some time to login, else all the requests below will crap out
        time.sleep(cp.wait_time_seconds)

        # Ignore the truncation warning from MySQL
        from warnings import filterwarnings
        filterwarnings('ignore', 'Data truncated for column.*')

        # Grab the Course Assets -----------------------------------------------------------
        cp.logger.info("Downloading course exports")
        for i in range(0, len(cp.course_information)):
            course = cp.course_information[i]

            course_slug = course[0]
            version = course[1]
            suffix = course[2] # this will be the name of the table in the database
            organisation = course[3]

            target_db_name = course_slug + "-" + str(version)

            cp.logger.info("")
            cp.logger.info("Downloading files from course: {0}".format(target_db_name))

            # Create a connection to <course_slug>-<version> database to insert data files into it.
            # dialect+driver://username:password@host:port/database
            engine = create_engine('mysql+mysqldb://{0}:{1}@{2}/{3}'.format(cp.db_user, cp.db_pass, cp.db_host, target_db_name))

            if cp.use_course_name_as_folder:
                # Put the csv files of each course in separate folder
                course_output_path = cp.output_path + os.sep + course_slug
                if not os.path.exists(course_output_path):
                    os.makedirs(course_output_path)
            else:
                # Otherwise, put all files in the given folder
                course_output_path = cp.output_path

            url = "https://www.futurelearn.com/admin/courses/{0}/{1}/stats-dashboard/data/{2}".format(course_slug, version, suffix)
            cp.logger.info("Downloading: {0}".format(url))

            start_datetime = str(datetime.now())
            hit_error = False
            try:
                #response = driver.request('GET', url)
                response = loginInfo.get(url)
            except Exception, e:
                errorMessage = "Failed to request {0} ".format(url)
                cp.logger.error(errorMessage)
                args = [str(datetime.now()), errorMessage]
                cp.cursor.callproc("insert_error_logging_table", args)
                cp.db.commit()
                add_error_file(course_slug, suffix)
                hit_error = True # to fix the bug, where a failure comes after a successful run

            if response.status_code == 200 and hit_error == False:
                filename = "{0}-{1}_{2}.csv".format(course_slug, version, suffix.replace('_', '-'))
                filepath = course_output_path + os.sep + filename

                end_datetime = str(datetime.now())

                # Logging the insertion into futurelearn_courses_information db
                args = [course_slug, version, suffix, start_datetime, "Started downloading the file at {0}".format(url), ""]
                cp.cursor.callproc("insert_course_logging_table", args)
                cp.db.commit()

                args = [course_slug, version, suffix, end_datetime, "Completed downloading the file.", ""]
                cp.cursor.callproc("insert_course_logging_table", args)
                cp.db.commit()

                # write the file out
                try:
                    args = [course_slug, version, suffix, str(datetime.now()),
                            "Started writing the file at {0}".format(filepath), ""]
                    cp.cursor.callproc("insert_course_logging_table", args)
                    cp.db.commit()

                    f = open(filepath, 'w')
                    f.write(response.content)
                    f.close()

                    args = [course_slug, version, suffix, str(datetime.now()), "Completed writing the file.", ""]
                    cp.cursor.callproc("insert_course_logging_table", args)
                    cp.db.commit()

                    try:
                        args = [course_slug, version, suffix, str(datetime.now()), "Started loading: {0}.".format(filepath), ""]
                        cp.cursor.callproc("insert_course_logging_table", args)
                        cp.db.commit()

                        cp.logger.info("Loading '{0}.csv' to '{1}' database...".format(suffix, target_db_name))

                        # We have to specify the data type of the column,
                        # otherwise 'step' column would be considered as floating point
                        types = {}
                        for cf in cp.file_column_names:
                            file_name = cf[0]
                            column_name = cf[1]
                            column_type = cf[2]
                            if file_name == suffix:
                                if 'varchar' in column_type:
                                    types[column_name] = str
                                elif 'tinyint' in column_type:
                                    types[column_name] = bool
                                else:
                                    types[column_name] = object

                        # Load CSV file to the <course_slug>-<version> database
                        df = pd.read_csv(filepath, dtype=types, sep=',')
                        if suffix == 'comments':
                            df = AddNewColumnsToCommentsFile(df,  target_db_name)
                        if suffix == 'question_response':
                            AddNewColumnsToQuestionResponseFile(df,  target_db_name)
                        if suffix == 'enrolments':
                            df = AddNewColumnsToEnrolmenFile(df,  target_db_name)

                        # Note from ajc: this is a workaround for 'datetime' items,
                        # which have been set to object earlier.
                        df_file_column_names = pd.DataFrame(list(cp.file_column_names))
                        df_file_column_names.columns = ['filename', 'column_name', 'column_type']
                        df_get_datetime_by_filename = df_file_column_names[(df_file_column_names.filename == suffix) & (df_file_column_names.column_type == 'datetime')]
                        datetime_columns = list(df_get_datetime_by_filename['column_name'])

                        for datetime_column in datetime_columns:
                            df[datetime_column] = pd.to_datetime(df[datetime_column])

                        df.to_sql(con=engine, name=suffix, if_exists='append', flavor='mysql', chunksize=1000) # note: this table starts off empty as it is created earlier with sql_scripts

                        # Logging the insertion into futurelearn_courses_information db
                        args = [course_slug, version, suffix, str(datetime.now()),
                                "Completed loading the csv file into {0} database.".format(target_db_name), ""]
                        cp.cursor.callproc("insert_course_logging_table", args)
                        cp.db.commit()
                    except Exception, e:
                        errorMessage = "Failed to write {0} file into {1} database".format(filename, target_db_name)
                        cp.logger.error(errorMessage)
                        cp.logger.error(traceback.format_exc())
                        args = [str(datetime.now()), errorMessage]
                        cp.cursor.callproc("insert_error_logging_table", args)
                        cp.db.commit()
                        add_error_file(course_slug, suffix)

                except Exception, e:
                    cp.logger.error("Failed to write file: {0} (now moving to the next file)".format(filename))
                    cp.logger.error(traceback.format_exc())
                    args = [str(datetime.now()), "Failed to write file: {0}".format(filename)]
                    cp.cursor.callproc("insert_error_logging_table", args)
                    cp.db.commit()
                    add_error_file(course_slug, suffix)
            else:
                cp.logger.error("Failed to get: {0}".format(url))
                cp.logger.error("The url does not exist on the futurelearn website, as the course probably hasn't started yet.".format(url))
                cp.logger.error(traceback.format_exc())
                args = [str(datetime.now()), "Failed to get: {0}".format(url)]
                cp.cursor.callproc("insert_error_logging_table", args)
                cp.db.commit()
                add_error_file(course_slug, suffix)


        cp.logger.info("FutureLearn exports finished")
    loginInfo.close()

# ----------------------------------------------------------------------------------
# After exporting all tables we have to prepare data for visualisations. The Rscript preprocessing.R
# will have all routines to be executed.
# First of all, the list of all needed visualisations will be extracted by calling get_vis_tables_by_course store procedure
# that will be passed to Rscript as arguments to run the appropriate routines.
# If there were any sort of error that the csv file didn't download or it couldn't load to db, the according
# visualisation table wouldn't be touched. But a note will be logged into logging table.

def run_R_script(args):
    command = 'Rscript'
    path2script = cp.config.get("rscript", "path_to_script")
    course_slug = args[1]
    course_name = course_slug[0:course_slug.rfind('-')]
    version = course_slug[course_slug.rfind('-')+1:]
    # Logging the insertion into futurelearn_courses_information db
    log_args = [course_name, version, "", str(datetime.now()),
            "Started running the {0} Rscript on {1} course.".format(path2script, course_slug), ""]
    cp.cursor.callproc("insert_course_logging_table", log_args)
    cp.db.commit()

    # Build subprocess command
    cmd = [command, path2script] + args
    print cmd
    try:
        FNULL = open(os.devnull, 'w')
        output = subprocess.call(cmd, stdout=FNULL, stderr=subprocess.STDOUT)

        log_args = [course_name, version, "", str(datetime.now()),
                    "Completed running the Rscript.", ""]
        cp.cursor.callproc("insert_course_logging_table", log_args)
        cp.db.commit()
    except subprocess.CalledProcessError as output:
        error_message = "Failed to run R file {0} for course {1}".format(path2script, course_slug)
        cp.logger.error(error_message, output.output)
        cp.logger.error(traceback.format_exc())
        cp.cursor.callproc("insert_error_logging_table", [str(datetime.now()), error_message + '; ' + output.output])
        cp.db.commit()

def PreprocessByR():
    cp.logger.info("Start preprocessing data...")

    rscript_config_file = cp.config.get("rscript", "config_file")

    for i in range(0, len(cp.active_courses)):
        course = cp.active_courses[i]
        course_slug = course[0]
        version = course[1]

        cp.logger.info("Started running Rscript for course: {0}".format(course_slug))

        # Get the list of all visualisation tables for each active course
        cursor = cp.db.cursor()
        cursor.callproc('get_vis_tables_by_course', [course_slug, version])
        vis_table_file_names = cursor.fetchall()
        cursor.close()
        cursor = cp.db.cursor()

        rscript_args = [rscript_config_file, course_slug + '-' + str(version)]

        course_file_error = []
        if course_slug in cp.error_files.keys():
            course_file_error = cp.error_files[course_slug]

        not_update_vis_table_due_to_error = []
        for vtfn in vis_table_file_names:
            vis_table_name = vtfn[0]
            file_name = vtfn[1]
            if file_name in course_file_error and vis_table_name not in not_update_vis_table_due_to_error:
                not_update_vis_table_due_to_error.append(vis_table_name)

        for vtfn in vis_table_file_names:
            vis_table_name = vtfn[0]
            file_name = vtfn[1]
            # If we encountered any error to fetch the file,
            # we ignore all routines in rscript that needs this base file.
            if vis_table_name in not_update_vis_table_due_to_error:
                msg = "Failed to process {0} visualisation table due to an error.".format(vis_table_name)
                log_args = [course_slug, version, "", str(datetime.now()), msg, ""]
                cursor.callproc("insert_course_logging_table", log_args)
                cp.db.commit()
                cp.logger.error(msg)
                continue

            rscript_args.append(vis_table_name)
            if file_name not in rscript_args:
                rscript_args.append(file_name)

        run_R_script(rscript_args)

        cp.logger.info("Completed running the Rscript.")

    cp.logger.info("Finished preprocessing data.")

# Entry point
cp = ConfigParameters('config.txt')

if cp.download_enable:
    EmptyTablesInDataBase()
    DownloadCSVFiles()

if cp.preprocessing_enable:
    PreprocessByR()

cp.db.close()


# ----------------------------------------------------------------------------------
