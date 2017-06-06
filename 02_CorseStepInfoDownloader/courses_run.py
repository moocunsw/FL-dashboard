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
# The code was reused by Dr. Mahsa Chitsaz, Educational Data Scientist
# in the Portfolio of the Pro-Vice Chancellor Education PVC(E) at UNSW Sydney, Australia.
# The original code is available at https://github.com/moocobservatory/mooc-dashboard/.
#
# For further information, requests to access the repo as developer, comments and feedback,
# please contact education.data@unsw.edu.au
#
# ************************************************************************************************


import datetime
from bs4 import BeautifulSoup

class FLCourses:

	def __init__(self,login,organisation,logger):
		"""Check we have Facilitator level privileges

			:param:
			    login: The BeautifulSoup Session
		"""
		self.__session  =  login
		self.__mainsite = 'https://www.futurelearn.com'
		self.__isAdmin = False
		self.__uni = ''
		self.__logger = logger
		self.__organisation = organisation
		admin_url = self.__mainsite + '/admin/organisations/{0}/courses'.format(organisation)
		self.__rep = self.__session.get(admin_url, allow_redirects=True)

		if(self.__rep.status_code == 200):
			self.__isAdmin = True
			soup = BeautifulSoup(self.__rep.content,'html.parser')
			uni = soup.findAll('div',class_ = 'm-action-bar__title')
			self.__uni = uni[0].text.strip().replace('\n','')

	def getCourses(self):
		"""	Scrape the course metadata

			:return
			    courses (Dictionary) : A dictionary keyed on course name, values are themselves dictionaries of course metadata
			"""

		if(self.__isAdmin):
			webpage = self.__rep.content
			soup = BeautifulSoup(webpage,'html.parser')
			# get all courses info
			tables = soup.findAll("table",{'class': 'm-table m-table--highlightable m-table--manage-courses m-table--bookended'})
			courses = {}

			for table in tables:
				for course in table.find_all('tbody'):
					try:
						course_name = course.a['title']
						course_name_fl = course.a['href'].replace('/admin/courses/','').split("/")[0]
						self.__logger.info("Found course: %s ..." %course_name_fl)
						#get courses run in different time
						course_runs = course.find_all('tr')
						run_count = len(course_runs)
						self.__logger.info("...with %d runs" %run_count)
						course_info = {}

						for course_run in course_runs:
							l = course_run.find_all('span')
							_start_date = l[2].text
							_status = l[1].text.lower()
							_stats_path = course_run.find(title = 'View stats')['href']
							_run_details_path = course_run.find(title = 'View run on FutureLearn')['href']

							# Fetch data of finished courses only
							if( _status == 'finished' or _status == 'in progress' or _status == 'upcoming'):

								run_duration_weeks = self.getRunDuration(self.__mainsite + _run_details_path)

								# Convert to Date type and compute end date
								# Pad if needed. e.g. 9 May 2016 to 09 May 2016
								if(len(_start_date) == 10):
									_start_date = "0"+_start_date

								start_date = datetime.datetime.strptime(_start_date, "%d %b %Y")
								end_date = start_date + datetime.timedelta(weeks=int(run_duration_weeks))

								#print "...end date: %s" %end_date

								run_data = { 'course_name_fl' : course_name_fl, 'duration_week' : run_duration_weeks
									, 'start_date': start_date.strftime('%Y-%m-%d')
									, 'end_date': end_date.strftime('%Y-%m-%d')
									, 'status' : _status.upper(), 'version' : run_count, 'active' : 1
									, 'datasets' : self.getDatasets(self.__mainsite + _stats_path)
									, 'organisation': self.__organisation
									}
								course_info[str(run_count)] = run_data

							run_count-=1

						courses[course_name] = course_info
					except Exception, e:
						self.__logger.erro("Some problem!")
		
			return courses
		
		else:
			return None

	def getDatasets(self, stats_dashboard_url):
		""" Assemble URL to datasets (CSV files)

		:param stats_dashboard_url:
		:return:
		"""

		#data = {}
		filenames = []
		
		if(self.__isAdmin):
			soup = BeautifulSoup(self.__session.get(stats_dashboard_url).content, 'html.parser')
			# FutureLearn removed the class name of the ul tag
			datasets = soup.find('ul',attrs={'class': None})

			if(datasets):	
				links = datasets.find_all('li')

				for li in links:
					link = li.find('a')['href']
					split = str.split(str(link),'/')
					filename = split[7]
					filenames.append(filename)
			return filenames

	def getRunDuration(self, _run_details_url):
		""" Find the duration of the course, in weeks

		:param _run_details_url:
		:return:
		"""
		#print "Looking up duration: %s" % _run_details_url

		duration = 0
		if(self.__isAdmin):
			soup = BeautifulSoup(self.__session.get(_run_details_url).content, 'html.parser')
			#run_data = soup.findAll('span',class_ = 'm-key-info__data')
			run_data = soup.findAll('span',class_ = 'm-metadata__title')
			if(run_data):
				for run_datum in run_data:
					if("Duration" in run_datum.string):
						duration = run_datum.string.replace('Duration','').replace('weeks','').strip()

		if(duration == 0):
			self.__logger.error("Unable to parse duration")
		return duration

