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

# ---------------------------------------------------------------------------------
#
# A class for connecting to database. It has functions related to insert/update of a table
# as well as querying the database.
#
# ---------------------------------------------------------------------------------


import pandas as pd
import MySQLdb

class DBConnection:
	def __init__(self,db_host,db_name,db_user,db_pass):
		"""Connect to database and query tables.

			:param:
			    db_host: The database host
			    db_name: The database name
			    db_user: The database user
			    db_pass: The user's password
		"""
		# Create connection to database
		self.__db = MySQLdb.connect(host=db_host,
							 user=db_user,
							 passwd=db_pass,
							 db=db_name,
							 charset='utf8',
							 use_unicode=True)

	def insertCourseFileInformationFromCSV(self):
		"""
				The function insert the data from the CourseSlugFileInfo csv file to database which
				are the files available for download of any course.
				There is the 'insert_course_file_information' store procedure in the database that
				handle such insertion.
		:return:
		"""
		courseSlug_datasets = "CourseSlugFileInfo.csv"
		df = pd.read_csv(courseSlug_datasets)

		cursor = self.__db.cursor()
		for row in df.iterrows():
			args = [row[1]['course_id'],row[1]['file_id']]
			cursor.callproc("insert_course_file_information", args)
		self.__db.commit()
		cursor.close()

	def insertCourseInformationFromCSV(self):
		"""
				This function insert/update the course information from CourseSlugData csv file to database.
				There is the 'update_course_information' store procedure in the database that
				handle such insertion or update.
		:return:
		"""
		courseSlug_datasets = "CourseSlugData.csv"
		df = pd.read_csv(courseSlug_datasets)

		cursor = self.__db.cursor()

		for row in df.iterrows():
			args = [row[1]['course_name'],row[1]['course_name_fl']
					, row[1]['duration_week'],row[1]['end_date']
					,row[1]['start_date'],row[1]['version']
					,row[1]['active'],row[1]['status'],row[1]['organisation']]
			cursor.callproc("update_course_information", args)
		self.__db.commit()
		cursor.close()

	def getCourseId(self,course_name,version):
		"""
			This function returns the id of a course from database.
		:param course_name: the course slug from Futurelearn website (e.g. remaking-nature)
		:param version: the version or run of the course slug. (e.g. 1, 2, etc)
		:return:
		"""
		cursor = self.__db.cursor()
		args = [course_name, version]
		cursor.callproc("find_course_id", args)
		course_information = cursor.fetchall()
		cursor.close()
		if len(course_information) == 0:
			return -1
		return course_information[0][0]

	def getFileInformation(self):
		"""
			This function return the files available for all courses from the data base.
			The get_file_information store procedure has the logic.
		:return:
		"""
		cursor = self.__db.cursor()
		cursor.callproc('get_file_information')
		file_names = cursor.fetchall()
		cursor.close()

		file_names_dic = {}
		for f in file_names:
			file_names_dic[f[1]] = f[0]
		return file_names_dic

	def getInprogressCourses(self):
		"""
			This function returns the in progress courses based on their start date.
			The get_inprogress_courses store procedure has the logic.
		:return:
		"""
		cursor = self.__db.cursor()
		cursor.callproc('get_inprogress_courses')
		courses = cursor.fetchall()
		cursor.close()

		list_courses = []
		for c in courses:
			list_courses.append([c[0],c[1]])

		return list_courses

	def getActiveCourses(self):
		"""
			This function returns the active courses from the database.
			The get_active_courses store procedure has the logic.
		:return:
		"""
		cursor = self.__db.cursor()
		cursor.callproc('get_active_courses')
		courses = cursor.fetchall()
		cursor.close()

		list_courses = []
		for c in courses:
			list_courses.append([c[0],c[1]])

		return list_courses

	def insertCourseInformation(self,args):
		"""
			This function insert a new course into the course_information table.
		:param args: is a list of all the fields in the course_information table.
		:return:
		"""
		cursor = self.__db.cursor()
		cursor.callproc("insert_course_information", args)
		self.__db.commit()
		cursor.close()
