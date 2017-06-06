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
# The original code was written by Dr. Mahsa Chitsaz, Educational Data Scientist  and Dr. Andrew Clayphan, Educational Data Scientist
# in the Portfolio of the Pro-Vice Chancellor Education PVC(E) at UNSW Sydney, Australia.
#
# For further information, requests to access the repo as developer, comments and feedback,
# please contact education.data@unsw.edu.au
#
# ************************************************************************************************

# ---------------------------------------------------------------------------------
#
# Download script for grabbing FutureLearn step information
# Note: Requires Python >= 2.7.9 (e.g. 2.7.9/2.7.10/2.7.11)
#
# Working as of May 30, 2017
# Depends highly on the structure of the FutureLearn website not changing from course to course.
# So far, all courses scraping fine.
#
# ---------------------------------------------------------------------------------

# Libraries
import re
import logging
import ConfigParser
import os
import time
import string
from lxml import html
from lxml import etree
import csv
import pandas as pd
from sqlalchemy import create_engine
from login import login
from courses_run import FLCourses
from db_queries import DBConnection


class ConfigParameters:
    def __init__(self, config_file):
        self.logger = logging.getLogger('futurelearn_course_step_scraper')
        logging.basicConfig(format='%(asctime)s - %(levelname)s - %(message)s', datefmt='%Y-%m-%d %I:%M:%S %p')
        self.logger.setLevel(logging.DEBUG)
        # Configuration options ------------------------------------------------------------
        self.config = ConfigParser.ConfigParser(allow_no_value=True)
        self.config.read(config_file)
        self.step_export_enable = self.config.getboolean("step_info", "export_enable")
        self.step_db_export_enable = self.config.getboolean("step_info", "db_export_enable")
        self.wait_time_seconds = self.config.getint("general", "wait_time_seconds")
        self.username = self.config.get("general", "username")
        self.password = self.config.get("general", "password")
        self.organisations = [x.strip() for x in self.config.get("general", "organisations").split("\n")]
        self.db_host = self.config.get("database", "db_host")
        self.db_name = self.config.get("database", "db_name")
        self.db_user = self.config.get("database", "db_user")
        self.db_pass = self.config.get("database", "db_pass")
        self.course_db_export_enable = self.config.getboolean("course_info", "db_export_enable")
        self.course_export_enable = self.config.getboolean("course_info", "export_enable")
        self.use_inprogress_courses = self.config.getboolean("general", "use_inprogress_courses")
        self.use_active_courses = self.config.getboolean("general", "use_active_courses")
        if len(self.username.strip()) == 0 or len(self.password.strip()) == 0:
            self.logger.error("Username or Password is blank... Fill it in, in the config, Aborting now....")
            exit()

        if len(self.db_host.strip()) == 0 or len(self.db_name.strip()) == 0 or len(self.db_user.strip()) == 0 or len(
                self.db_pass.strip()) == 0:
            self.logger.error("Database connection is blank... Fill it in, in the config, Aborting now....")
            exit()
        # Create connection to database
        self.db = DBConnection(self.db_host, self.db_name, self.db_user, self.db_pass)

        # Get a list of all active courses
        if self.config.getboolean("general", "use_course_slugs") is True:
            items = [x.strip() for x in self.config.get("general", "course_slugs").split("\n")]
            self.active_courses = [filter(None, map(str.strip, item.split(" "))) for item in
                                   items]  # list of ['course_slug', 'version']
        elif self.use_inprogress_courses is True:
            self.active_courses = self.db.getInprogressCourses()
        elif self.use_active_courses:
            self.active_courses = self.db.getActiveCourses()
        else:
            self.logger.error(
                "Have not set one of: 'use_inprogress_courses'/'use_active_courses'/'use_course_slugs' to TRUE.")
            exit(1)

        # Specify where the files will be written to --------------------------------------
        self.place_files_in_data_directory = self.config.get("general", "place_files_in_data_directory")

        if len(self.place_files_in_data_directory.strip()) == 0:
            self.output_path = os.getcwd()
        else:
            self.output_path = self.place_files_in_data_directory
            # create the folder
            if not os.path.exists(self.output_path):
                os.makedirs(self.output_path)

def getStepContents(cp, driver, step_urls, course_slug, version, this_week_number):
    """
        Script the FutureLearn website to find the step content.
    :param  cp: The instance of ConfigParameters class that has all the parameters from config file.
            driver: A session requests object to get the html content of a webpage.
            step_urls: The url to go to the step.
            course_slug: The course slug from futurelearn website. (e.g. remaking-nature)
            version: The version or run of the course.
            this_week_number: The week that the step is in.
    :return:
    """
    steps = []
    cp.logger.info(
        "Grabing step content at week {0} for course: '{1}/{2}'".format(this_week_number, course_slug, version))

    for url in step_urls:
        res = driver.get(url)
        new_url = res.url

        if "quick_enrol" in new_url:
            response = driver.get(new_url)
            if response.status_code == 200:
                # Click the enrol button
                driver.find_element_by_css_selector("input.a-button[type='submit']").click()
                time.sleep(cp.wait_time_seconds)
                res = driver.get(url)
                new_url = res.url
            else:
                cp.logger.info(
                    "Having a problem automatically enrolling into the course: '{0}/{1}'".format(course_slug, version))
                cp.logger.info("You must manually enrol the scraping account into the course.")
                cp.logger.info("Moving to the next course now.")
                continue

        response = driver.get(new_url)

        if response.status_code == 200:
            # Parse html into a DOM tree
            html_content = response.content
            tree = html.fromstring(html_content)

            try:
                elem = tree.xpath("""//*[@id="main-content"]/article/section/div/div[2]/div/div[2]""")
                source_code = map(etree.tostring, elem)
                steps.append(source_code)
                # print source_code
            except Exception, e:
                try:
                    elem = tree.xpath("""//*[@id="main-content"]/article/section/div/div[2]/div/div/div[3]""")
                    source_code = map(etree.tostring, elem)
                    steps.append(source_code[0])
                except Exception, e:
                    cp.logger.error("No Content at step url {0}".format(url))
                    steps.append('Got error')

    cp.logger.info(
        "Finished Grabing step content of week {0} for course: '{1}/{2}'".format(this_week_number, course_slug,
                                                                                 version))
    return (steps)

def getStepInformation(cp):
    """
        Script the FutureLearn website for all the courses in the config file
         in order to find all step information.
    :param cp: The instance of ConfigParameters class that has all the parameters from config file.
    :return:
    """
    # Log into FutureLearn -------------------------------------------------------------
    cp.logger.info("Logging into the futurelearn website (wait 5 seconds)")
    loginInfo, rep = login(cp.username, cp.password, 'https://www.futurelearn.com/sign-in')
    # Grab the Step Assets -----------------------------------------------------------
    cp.logger.info("Downloading steps information for each course")

    # for course_slug, version in course_slugs_info:
    for a_course in cp.active_courses:
        course_slug = a_course[0]
        version = str(a_course[1])
        print course_slug + '- ' + version
        output_filepath = cp.output_path + os.sep + "{0}-{1}-step_info.csv".format(course_slug, version)
        if (os.path.isfile(output_filepath)):
            cp.logger.info("Found the file for: '{0}/{1}' at {2}".format(course_slug, version, output_filepath))
            continue

        cp.logger.debug("--------------------------------------------------------")
        cp.logger.info("Processing course: '{0}/{1}'".format(course_slug, version))

        # Step 1: Go to the course /todo/ page, it will re-direct, just wait.
        cp.logger.debug("Step 1: Go to the course")
        url = "https://www.futurelearn.com/courses/" + course_slug + "/" + version + "/todo/"
        res = loginInfo.get(url)
        new_url = res.url

        # FL have changed thelogin process that it goes to the register page
        if 'register' in new_url:
            response = loginInfo.get(new_url)
            if response.status_code == 200:
                loginInfo.find_element_by_id('email').send_keys(cp.username)
                loginInfo.find_element_by_id('password').send_keys(cp.password)
                loginInfo.find_element_by_css_selector("button[type='submit']").click()
                time.sleep(cp.wait_time_seconds)
                res = loginInfo.get(url)
                new_url = res.url
            else:
                cp.logger.info(
                    "Having a problem automatically logging into the course: '{0}/{1}'".format(course_slug, version))

        # Enrol into the course, if we are not enrolled into it
        # (depends where the above 'GET' redirects to).
        if "quick_enrol" in new_url:
            response = loginInfo.get(new_url)
            if response.status_code == 200:
                cp.logger.info("enrolling into the course: '{0}/{1}'".format(course_slug, version))
                # Click the enrol button
                loginInfo.find_element_by_css_selector("input.a-button[type='submit']").click()
                time.sleep(cp.wait_time_seconds)
                res = loginInfo.get(url)
                new_url = res.url
            else:
                cp.logger.info(
                    "Having a problem automatically enrolling into the course: '{0}/{1}'".format(course_slug, version))

                cp.logger.info("Moving to the next course now.")
                continue

        # After being re-directed...
        response = loginInfo.get(new_url)
        if response.status_code == 200:
            html_content = response.content
        else:
            cp.logger.info("Failed to get: '{0}'".format(new_url))
            cp.logger.info("Moving to the next course now.")
            continue

        # Step 2: Grab the week urls, from the main redirect page.
        cp.logger.debug("Step 2: Grab Week URLs")
        week_urls = []  # These are the urls to each of the weeks within a course.
        suffixes = set(re.findall("/courses/" + course_slug + "/" + version + "/todo/[0-9]+", html_content))

        prefix = "https://www.futurelearn.com"
        for suffix in suffixes:
            week_url = prefix + suffix
            week_urls.append(week_url)

        # Grab the Week and Date information
        tree = html.fromstring(html_content)

        # Stored in a list, in the correct week order (i.e. index 0 = week 1, etc.)
        week_labels = tree.xpath("""//*[@class="m-run-progress-nav__itembox__label"]/text()""")  # e.g. 'Week'
        week_numbers = tree.xpath("""//*[@class="m-run-progress-nav__itembox__number"]/text()""")  # e.g. '1'
        week_dates = tree.xpath("""//*[@class="date"]/@datetime""")  # e.g. '2016-01-11'
        week_dates_str = tree.xpath("""//*[@class="date"]/text()""")  # e.g. '11 Jan'

        # Step 3: Iterate through each week url, and pick up the step information
        cp.logger.debug("Step 3: Iterate through each week")
        df_final = pd.DataFrame()

        # these are not guaranteed to be in week order, since the URL numbering does not have to be ascending
        for week_url in week_urls:
            cp.logger.info("Processing the week url : {0}".format(week_url))
            response = loginInfo.get(week_url)
            df_week = pd.DataFrame()

            if response.status_code == 200:
                html_content = response.content

                # Parse html into a DOM tree
                tree = html.fromstring(html_content)

                # Grab the week heading.
                week_heading = tree.xpath("""//*[@class="u-hidden-small"]/text()""")  # e.g. 'Week 6: Conclusion'

                # Grab the week_index (week number - 1) - so we can relate back to the week and date information pulled earlier.
                this_week_number = int(week_heading[0].split(":")[0][5:].strip())
                week_index = this_week_number - 1

                # Grab the steps
                steps = tree.xpath(
                    """//*[@id="main-content"]/section/div/div/ol/li/ol/li/a/span/div/text()""")  # e.g. [1.1,1.2,etc.]

                # Grab the link to steps
                step_links = tree.xpath(
                    """//*[@id="main-content"]/section/div/div/ol/li/ol/li/a/@href""")  # e.g. ["/courses/through-engineers-eyes/1/steps/78619",etc.]
                step_links = [prefix + step_link for step_link in step_links]

                # Grab the step contents
                step_contents = getStepContents(cp, loginInfo, step_links, course_slug, version, this_week_number)

                # Grab the titles
                titles = tree.xpath("""//*[@class="m-composite-link__primary"]/text()""")
                titles = [title.strip() for title in titles]

                # Grab the asset types (e.g. video (01:28), article, etc.)
                asset_types = tree.xpath("""//*[@class="m-composite-link__secondary type"]/text()""")
                asset_types = [asset_type.strip() for asset_type in asset_types]

                # So far covers: 'video', 'article', 'quiz', 'discussion', 'test' and any other one word tags.
                # If there are special cases, add them in here as required. (e.g. video is a special case for example)
                asset_infos = []  # list of ('asset_type', 'length as str', 'length as int in secs')
                for asset_type in asset_types:
                    if "video" in asset_type:
                        time_str = asset_type[7:-1]
                        # time_str = time_str.lstrip("0")

                        parts = list(reversed(time_str.split(":")))

                        seconds = 0
                        for index, part in enumerate(parts):
                            if index == 0:
                                seconds += int(part)
                            else:
                                try:
                                    seconds += int(part) * (60 ** index)
                                except Exception, e:
                                    print asset_type
                                    exit(1)

                        asset_infos.append(('Video', time_str, seconds))
                    else:
                        asset_infos.append((string.capwords(asset_type), None, None))

                # Put all the collected items into one place.
                if len(asset_infos) > 0:  # Weeks are not guaranteed to have any steps.
                    df_week['step_number'] = steps
                    df_week['title'] = titles
                    df_week['type'] = zip(*asset_infos)[0]
                    df_week['duration'] = zip(*asset_infos)[1]
                    df_week['duration_secs'] = zip(*asset_infos)[2]
                    df_week['week_label'] = ["{0} {1}".format(week_labels[week_index], week_numbers[week_index])] * len(
                        steps)
                    df_week['week_datetime'] = [week_dates[week_index]] * len(steps)
                    df_week['week_date'] = [week_dates_str[week_index]] * len(steps)
                    df_week['week_heading'] = week_heading * len(steps)
                    df_week['step_url'] = step_links
                    df_week['step_content'] = step_contents

                    df_final = df_final.append(df_week)  # concatenate weeks, into a larger df

                else:
                    cp.logger.info("Couldn't find step info for course {0} at week {1}".format(course_slug, week_url))


            else:
                cp.logger.info("Failed to get: '{0}'".format(week_url))
                cp.logger.info("Moving to the next week url.")
                continue

            cp.logger.info("Finished processing the week url : {0}".format(week_url))

        # Step 4: Write-out the 'course dataframe' describing the steps
        cp.logger.debug("Step 4: Write out the file")

        row_count = df_final.shape[0]
        if row_count > 0:
            # To deal with the fact that steps are not properly sorted (even if using the step_number column as key),
            # here is a quick workaround: based on other attributes we can use to get the desired ordering
            # Currently index repeats from 0..n for each week, in ascending order per steps (utilise this fact).
            df_final['index'] = df_final.index
            df_final = df_final.sort_values(['week_datetime', 'index'], ascending=[1, 1])
            df_final = df_final.drop('index', 1)

            df_final = df_final.reset_index(drop=True)  # rename index to 0..n (over all weeks, rather than within).

            f = open(output_filepath, 'w')
            f.write(df_final.to_csv(index=False, encoding='utf-8', quoting=csv.QUOTE_NONNUMERIC))
            f.close()
            cp.logger.info("Created: {0}".format(output_filepath))
        else:
            cp.logger.warn(
                "*** Note: *** (course: '{0}/{1}') has 0 rows, not writing out a file with 0 steps.".format(course_slug,
                                                                                                            version))

    cp.logger.info("FutureLearn step scraper finished")

def loadStepInfoToDatabase(cp):
    """
        Load all step file information into the database.
    :param cp: The instance of ConfigParameters class that has all the parameters from config file.
    :return:
    """
    cp.logger.info("Start loading the csv files to futurelearn_courses_information database...")

    # Create a connection to <course_slug>-<version> database to insert data files into it.
    engine = create_engine('mysql+mysqldb://{0}:{1}@{2}/{3}'.format(cp.db_user, cp.db_pass
                                                                    , cp.db_host, cp.db_name))

    table_name = 'course_information_details'
    dmap = {'course_id': 'int32', 'step_number': 'object', 'title': 'object', 'type': 'object', 'duration': 'object',
            'duration_secs': 'float', 'week_label': 'object', 'week_datetime': 'object', 'week_date': 'object',
            'week_heading': 'object', 'step_url': 'object', 'step_content': 'object'}
    csv_dtype = {'step_number': 'object', 'title': 'object', 'type': 'object', 'duration': 'object',
                 'duration_secs': 'float', 'week_label': 'object', 'week_datetime': 'object', 'week_date': 'object',
                 'week_heading': 'object', 'step_url': 'object', 'step_content': 'object'}

    course_info_df = pd.DataFrame({k: pd.Series(dtype=v) for k, v in dmap.items()})
    for filepath in os.listdir(cp.output_path):
        course_slug = filepath[0:filepath.find('-step_info')]
        course_name = course_slug[0:course_slug.rfind('-')]
        version = course_slug[course_slug.rfind('-') + 1:]

        course_information = cp.db.getCourseId(course_name, version)

        # Load CSV file to the <course_slug>-<version> database
        df = pd.read_csv(cp.output_path + os.sep + filepath, dtype=csv_dtype)
        df['course_id'] = course_information
        course_info_df = course_info_df.append(df)

    course_info_df.to_sql(con=engine, name=table_name, if_exists='replace', flavor='mysql')

    cp.logger.info("Completed loading the csv files to futurelearn_courses_information database.")

def export_to_csv(cp):
    """
    Login to FutureLearn with the supplied credentials,
    then find all the coursed for the organisation.

    """

    filenames = cp.db.getFileInformation()
    loginInfo, rep = login(cp.username, cp.password, 'https://www.futurelearn.com/sign-in')

    if rep.status_code == 200:
        cp.logger.info("Login to FutureLearn website...")
        courseSlugData = {}
        for org in cp.organisations:
            cos = FLCourses(loginInfo, org, cp.logger)
            cp.logger.info("Retrieving courses for {0}...".format(org))

            for course_name, runs in cos.getCourses().items():
                for run, info in runs.items():
                    if (len(info['datasets']) > 0):
                        courseSlugData[course_name + '=' + run] = info

        courseSlug_filename = "CourseSlugData.csv"

        with open(courseSlug_filename, 'w') as f:
            writer = csv.writer(f)
            writer.writerow(
                "course_name,course_name_fl,duration_week,end_date,start_date,version,active,status,organisation".split(
                    ','))
            for course_name in courseSlugData.keys():
                row = courseSlugData[course_name]
                c = course_name[0:course_name.find('=')]
                line = '{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}'.format(c, row['course_name_fl']
                                                                    , row['duration_week'], row['end_date']
                                                                    , row['start_date'], row['version']
                                                                    , row['active'], row['status'], row['organisation'])

                writer.writerow(line.split('|'))
            f.close()

        courseSlug_datasets = "CourseSlugFileInfo.csv"
        with open(courseSlug_datasets, 'w') as f:
            writer = csv.writer(f)
            writer.writerow("course_name_fl,version,file_name,course_id,file_id".split(','))
            for course_name in courseSlugData.keys():
                row = courseSlugData[course_name]
                dataset = row['datasets']
                c = course_name[0:course_name.find('=')]
                args = [c, row['course_name_fl'], row['duration_week'], row['end_date']
                    , row['start_date'], row['version'], row['active'], row['status'], row['organisation']]
                course_id = cp.db.getCourseId(row['course_name_fl'], row['version'], args)

                if course_id == -1:
                    cp.db.insertCourseInformation(args)
                    course_id = cp.db.getCourseId(row['course_name_fl'], row['version'])

                for d in dataset:
                    line = '{0},{1},{2},{3},{4}'.format(row['course_name_fl'], row['version']
                                                        , d, course_id, filenames.get(d))
                    writer.writerow(line.split(','))
            f.close()
    else:
        cp.logger.error("Failed to login to FutureLearn website.")

# Entry point
cp = ConfigParameters('config.txt')

if cp.step_export_enable:
    getStepInformation(cp)

if cp.step_db_export_enable:
    loadStepInfoToDatabase(cp)

if cp.course_export_enable:
    export_to_csv(cp)

if cp.course_db_export_enable:
    cp.logger.info("Inserting the data at CourseSlugData.csv file into database...")
    cp.db.insertCourseInformationFromCSV()
    cp.logger.info("Finished inserting!")
    cp.logger.info("Inserting the data at CourseSlugFileInfo.csv file into database...")
    cp.db.insertCourseFileInformationFromCSV()
    cp.logger.info("Finished inserting!")

# ----------------------------------------------------------------------------------
