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

import requests
from bs4 import BeautifulSoup

def login(email,password,url):
	"""Login to FutureLearn with the supplied credentials, Get a list of courses and their metadata, then attempt to download the associated CSV files

		:param:
		    	email (str): The facilitators email address
		    	password (str): The facilitators FutureLearn password
		    	url (str): The target URL
		:returns
		    	s: The session
		    	rep: The response
		"""

	s = requests.session()
	web = s.get(url)
	html = web.content
	soup = BeautifulSoup(html,'html.parser')
	tags = soup.find_all(['input'])
	login_data = {};
	for tag in tags:
		if(tag.has_attr('value') and tag.has_attr('name')):
			login_data[tag['name']] = tag['value']
	login_data['email'] = email
	login_data['password'] = password
	rep = s.post(url,data = login_data)
	return (s,rep)

