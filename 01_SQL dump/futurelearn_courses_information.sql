-- MySQL dump 10.13  Distrib 5.7.9, for Win64 (x86_64)
--
-- Database: futurelearn_courses_information
-- ------------------------------------------------------
-- Server version	5.6.34-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Create schema `futurelearn_courses_information`
--
DROP DATABASE IF EXISTS futurelearn_courses_information;
CREATE DATABASE futurelearn_courses_information;

USE futurelearn_courses_information;

--
-- Table structure for table `column_information`
--

DROP TABLE IF EXISTS `column_information`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `column_information` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `column_name` varchar(255) DEFAULT NULL,
  `column_type` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `course_file_information`
--

DROP TABLE IF EXISTS `course_file_information`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `course_file_information` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `course_id` int(11) DEFAULT NULL,
  `file_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `course_information_course_file_id_idx` (`course_id`) USING BTREE,
  KEY `file_information_course_file_id_idx` (`file_id`) USING BTREE,
  CONSTRAINT `course_file_information_ibfk_1` FOREIGN KEY (`course_id`) REFERENCES `course_information` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `course_file_information_ibfk_2` FOREIGN KEY (`file_id`) REFERENCES `file_information` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `course_information`
--

DROP TABLE IF EXISTS `course_information`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `course_information` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `course_name` varchar(100) DEFAULT NULL,
  `course_name_fl` varchar(100) DEFAULT NULL,
  `duration_week` int(11) DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `version` smallint(6) DEFAULT '1',
  `active` tinyint(4) DEFAULT NULL,
  `status` varchar(20) DEFAULT NULL,
  `organisation` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8 COMMENT='This table stores information for any course offered by FutureLearn, e.g. course start date, the duration, etc.';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `course_information_details`
--

DROP TABLE IF EXISTS `course_information_details`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `course_information_details` (
  `index` bigint(20) DEFAULT NULL,
  `course_id` bigint(20) DEFAULT NULL,
  `duration` text,
  `duration_secs` double DEFAULT NULL,
  `step_content` text,
  `step_number` text,
  `step_url` text,
  `title` text,
  `type` text,
  `week_date` text,
  `week_datetime` text,
  `week_heading` text,
  `week_label` text,
  KEY `ix_course_information_details_index` (`index`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `course_logging_table`
--

DROP TABLE IF EXISTS `course_logging_table`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `course_logging_table` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `course_file_id` int(11) DEFAULT NULL,
  `vis_table_id` int(11) DEFAULT '2',
  `log_datetime` datetime DEFAULT NULL,
  `comment` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `course_information_course_logging_id_idx` (`course_file_id`) USING BTREE,
  KEY `vis_table_information_course_logging_id_idx` (`vis_table_id`) USING BTREE,
  CONSTRAINT `course_logging_table_ibfk_1` FOREIGN KEY (`course_file_id`) REFERENCES `course_file_information` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `course_logging_table_ibfk_2` FOREIGN KEY (`vis_table_id`) REFERENCES `vis_table_information` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `error_logging_table`
--

DROP TABLE IF EXISTS `error_logging_table`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `error_logging_table` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `error_message` text,
  `error_datetime` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `file_column_information`
--

DROP TABLE IF EXISTS `file_column_information`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `file_column_information` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `file_id` int(11) DEFAULT NULL,
  `column_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `file_information_file_column_id_idx` (`file_id`) USING BTREE,
  KEY `column_information_file_column_id_idx` (`column_id`) USING BTREE,
  CONSTRAINT `file_column_information_ibfk_1` FOREIGN KEY (`column_id`) REFERENCES `column_information` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `file_column_information_ibfk_2` FOREIGN KEY (`file_id`) REFERENCES `file_information` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `file_information`
--

DROP TABLE IF EXISTS `file_information`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `file_information` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `file_name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `vis_table_file_information`
--

DROP TABLE IF EXISTS `vis_table_file_information`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `vis_table_file_information` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `vis_table_id` int(11) DEFAULT NULL,
  `file_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `file_information_vis_table_file_id_idx` (`file_id`) USING BTREE,
  KEY `vis_table_information_vis_table_id_idx` (`vis_table_id`) USING BTREE,
  CONSTRAINT `vis_table_file_information_ibfk_1` FOREIGN KEY (`file_id`) REFERENCES `file_information` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `vis_table_file_information_ibfk_2` FOREIGN KEY (`vis_table_id`) REFERENCES `vis_table_information` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `vis_table_information`
--

DROP TABLE IF EXISTS `vis_table_information`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `vis_table_information` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `vis_table_name` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping routines for database 'futurelearn_courses_information'
--
/*!50003 DROP PROCEDURE IF EXISTS `find_courseSlug_from_error_log` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `find_courseSlug_from_error_log`()
BEGIN

SELECT distinct substring(substring_index(error_message,'. Error: ',1),position(' in ' IN error_message) + 4) as courseSlug FROM futurelearn_courses_information.error_logging_table where error_datetime >= CURDATE() and error_message like 'Got an error%'
union
SELECT distinct replace(substring(substring_index(error_message,'/stats-dashboard',1),position('admin/courses/' IN error_message) + length('admin/courses/')),'/','-') as courseSlug FROM futurelearn_courses_information.error_logging_table where error_datetime >= CURDATE() and error_message like 'Failed to get%'
union
SELECT distinct substring(substring_index(error_message,' database',1),position(' into ' IN error_message) + 6) as courseSlug FROM futurelearn_courses_information.error_logging_table where error_datetime >= CURDATE() and error_message like 'Failed to write%'
;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `find_course_id` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `find_course_id`(
course_name_fl varchar(100),
version int
)
BEGIN

select  id
from 	futurelearn_courses_information.course_information ci
where	ci.course_name_fl = course_name_fl
and		ci.version = version;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `find_start_dates_by_week` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `find_start_dates_by_week`(
course_name_fl varchar(100),
version int
)
BEGIN


declare start_d date; 
declare d_week int(11);
declare v_counter int unsigned default 2;
declare e_date date;

select 	start_date, duration_week INTO start_d, d_week 
from 	futurelearn_courses_information.course_information ci
where	ci.course_name_fl = course_name_fl
and		ci.version = version;

DROP TEMPORARY TABLE IF EXISTS futurelearn_courses_information.date_details;

CREATE TEMPORARY TABLE futurelearn_courses_information.date_details (
    start_date date NOT NULL
    , end_date date NOT NULL
    , week_number smallint NOT NULL
);

start transaction;
insert into date_details (start_date,end_date,week_number) values (start_d,date_add(start_d,INTERVAL 6 DAY), 1);
set e_date = date_add(start_d,INTERVAL 7 DAY);

while v_counter <= d_week do
insert into date_details (start_date,end_date,week_number) values (e_date, date_add(e_date,INTERVAL 6 DAY), v_counter);
set e_date = date_add(e_date,INTERVAL 7 DAY);
set v_counter=v_counter+1;
end while;
commit;

SELECT * FROM date_details;

drop temporary table futurelearn_courses_information.date_details;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `find_step_content_by_course` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `find_step_content_by_course`(
course_name_fl varchar(100),
version int
)
BEGIN

select 	cif.step_number as `step`, cif.step_content
from 	futurelearn_courses_information.course_information ci
		inner join futurelearn_courses_information.course_information_details cif on cif.course_id = ci.id
where	ci.course_name_fl = course_name_fl
and		ci.version = version;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `find_step_content_title_by_course` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `find_step_content_title_by_course`(
course_name_fl varchar(100),
version int
)
BEGIN

select 	cif.step_number as `step`, cif.step_content, cif.title, cif.type
from 	futurelearn_courses_information.course_information ci
		inner join futurelearn_courses_information.course_information_details cif on cif.course_id = ci.id
where	ci.course_name_fl = course_name_fl
and		ci.version = version;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `find_step_title_by_course` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `find_step_title_by_course`(
course_name_fl varchar(100),
version int
)
BEGIN

select 	cif.step_number as `step`, cif.title
from 	futurelearn_courses_information.course_information ci
		inner join futurelearn_courses_information.course_information_details cif on cif.course_id = ci.id
where	ci.course_name_fl = course_name_fl
and		ci.version = version;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `find_step_type_by_course` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `find_step_type_by_course`(
course_name_fl varchar(100),
version int
)
BEGIN

select 	cif.step_number as `step`, cif.`type`
from 	futurelearn_courses_information.course_information ci
		inner join futurelearn_courses_information.course_information_details cif on cif.course_id = ci.id
where	ci.course_name_fl = course_name_fl
and		ci.version = version;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `find_step_url_by_course` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `find_step_url_by_course`(
course_name_fl varchar(100),
version int
)
BEGIN

select 	cif.step_number as `step`, cif.step_url
from 	futurelearn_courses_information.course_information ci
		inner join futurelearn_courses_information.course_information_details cif on cif.course_id = ci.id
where	ci.course_name_fl = course_name_fl
and		ci.version = version;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `find_step_url_for_quizzes` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `find_step_url_for_quizzes`(
course_name_fl varchar(100),
version int
)
BEGIN

SELECT 		step_number,step_url
FROM 		futurelearn_courses_information.course_information_details cid 
			inner join 	futurelearn_courses_information.course_information ci 
			on 			ci.id = cid.course_id
where 		`type` in ('Exercise','Quiz','Test')
and   		ci.course_name_fl = course_name_fl
and			ci.version = version;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `get_active_courses` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `get_active_courses`()
BEGIN
select 	ci.course_name_fl as course_name, ci.version as version, ci.organisation
from	futurelearn_courses_information.course_information ci 
where ci.active = true
order by ci.course_name_fl;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `get_active_course_file_names` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `get_active_course_file_names`()
BEGIN
select 	ci.course_name_fl as course_name, ci.version, fi.file_name, ci.organisation
from	futurelearn_courses_information.course_file_information cfi 	
inner join futurelearn_courses_information.course_information ci on ci.id = cfi.course_id
inner join futurelearn_courses_information.file_information fi on fi.id = cfi.file_id
where ci.course_name_fl is not null
order by ci.course_name_fl;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `get_duration_week_by_course` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `get_duration_week_by_course`(
course_name_fl varchar(100),
version int
)
BEGIN

select  duration_week
from 	futurelearn_courses_information.course_information ci
where	ci.course_name_fl = course_name_fl
and		ci.version = version;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `get_file_column_names` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `get_file_column_names`()
BEGIN
SELECT file_name, `column_name`, `column_type`
FROM futurelearn_courses_information.file_column_information fci
inner join futurelearn_courses_information.file_information fi on fci.file_id = fi.id
inner join futurelearn_courses_information.column_information ci on ci.id = fci.column_id
order by file_name;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `get_file_information` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `get_file_information`()
BEGIN
SELECT * FROM futurelearn_courses_information.file_information where id > 0;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `get_finished_courses` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `get_finished_courses`()
BEGIN
select 	ci.course_name_fl as course_name, ci.version as version, ci.organisation
from	futurelearn_courses_information.course_information ci 
where ci.status = 'FINISHED'
order by ci.course_name_fl;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `get_inprogress_courses` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `get_inprogress_courses`()
BEGIN

select 	ci.course_name_fl as course_name, max(ci.version) as version, start_date, ci.course_name as course_name_full, ci.organisation
from	futurelearn_courses_information.course_information ci 
where 	date_add(end_date, interval 7 day) >= date(now()) and start_date <  date(now())
group by ci.course_name_fl 
order by ci.course_name_fl;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `get_vis_tables_by_course` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `get_vis_tables_by_course`(
course_name varchar(255),
version int
)
BEGIN

 set @course_id  = (select  id
 from	`futurelearn_courses_information`.`course_information` ci
 where	ci.course_name_fl = course_name and ci.version = version);

# Find all vid_table_id that have any file associated to the available files for the course
drop temporary table if exists files_table;
CREATE TEMPORARY TABLE IF NOT EXISTS files_table AS 
(
select cfi.file_id,vis_table_id 
FROM 	futurelearn_courses_information.course_file_information cfi 	
		inner join futurelearn_courses_information.vis_table_file_information vtfi 	on vtfi.file_id = cfi.file_id 
where 	cfi.course_id = @course_id);

# Try to match the number of files for each of the vis_table to the above table.
# If these two number does not match it means that some files are not available for the course but it is needed for the vis_table.
drop temporary table if exists vis_table;
CREATE TEMPORARY TABLE IF NOT EXISTS vis_table AS 
(
select 	vtfi.vis_table_id,vtfi2.no_files as no_files_orig,count(*) as no_files
FROM 	files_table vtfi
																	inner join (select vis_table_id,count(*) as no_files from futurelearn_courses_information.vis_table_file_information group by vis_table_id) vtfi2 on vtfi.vis_table_id=vtfi2.vis_table_id
group by vtfi.vis_table_id
having no_files = vtfi2.no_files);

select vti.vis_table_name, fi.file_name
from 	files_table ft 
		inner join vis_table vt on vt.vis_table_id = ft.vis_table_id
        inner join futurelearn_courses_information.vis_table_information vti		on vti.id = ft.vis_table_id
		inner join futurelearn_courses_information.file_information fi				on fi.id = ft.file_id;
        

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `insert_academics_information_except_fl_id` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `insert_academics_information_except_fl_id`(
first_name		varchar(45),
last_name		varchar(100),
email_address 	varchar(255),
role			varchar(45),
profile_id		bigint
)
BEGIN

 set @total  = (select  count(*) as total
 from	`futurelearn_courses_information`.`academics_information` 
 WHERE profile_id=profile_id);

if (@total < 1) then

INSERT INTO `futurelearn_courses_information`.`academics_information` (`email_address`,`first_name`,`last_name`,`role`,`profile_id`)
values( email_address,first_name,last_name,role,profile_id);

end if;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `insert_course_file_information` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `insert_course_file_information`(
course_id int(11) 
,file_id int(11)
)
BEGIN

set @total  = (select  count(*) as total
 from	`futurelearn_courses_information`.`course_file_information`  cfi
 WHERE cfi.course_id=course_id and cfi.file_id=file_id);

if (@total < 1) then

INSERT INTO `futurelearn_courses_information`.`course_file_information` (`course_id`,`file_id`) VALUES (course_id,file_id);

end if;

END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `insert_course_information` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `insert_course_information`(
course_name varchar(100) 
, course_name_fl varchar(100) 
, duration_week int(11) 
, end_date date 
, start_date date 
, version smallint(6) 
, active tinyint(4) 
, _status varchar(20)
, organisation varchar(45)
)
BEGIN

if(course_name_fl is not null and version is not null) then

	set @total  = (select  count(*) as total
	 from	`futurelearn_courses_information`.`course_information` ci
	 WHERE ci.course_name_fl=course_name_fl and ci.version = version);

	if (@total < 1) then

		INSERT INTO `futurelearn_courses_information`.`course_information`
		(
		`course_name`,
		`course_name_fl`,
		`duration_week`,
		`end_date`,
		`start_date`,
		`version`,
		`active`,
		`status`,
		`organisation`)
		VALUES
		(course_name,course_name_fl,duration_week,end_date,start_date,version,active,_status,organisation);
	      
	end if;

end if;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `insert_course_logging_table` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `insert_course_logging_table`(
  course_name varchar(100),
  version int,
  file_name varchar(255),
  log_datetime datetime,
  comments varchar(500),
  vis_table_name varchar(100)
 )
BEGIN
 
 set @course_id  = (select  id
 from	`futurelearn_courses_information`.`course_information` ci
 where	ci.course_name_fl = course_name and ci.version = version);
 
 if file_name = '' or length(file_name) < 4 then
	 set @course_file_id = 0;
else
	 set @file_id  = (select  id
	 from	`futurelearn_courses_information`.`file_information` fi
	 where	fi.file_name = file_name);
	 
	 set @course_file_id  = (select  id
	 from	`futurelearn_courses_information`.`course_file_information` cfi
	 where	cfi.course_id = @course_id and cfi.file_id = @file_id);
 end if;
 
 if vis_table_name = '' or length(vis_table_name) < 4 then
	 set @vis_table_id = 0; -- this has been changed from 0 (ajc: 2016-05-16, is a temporary workaround until Mahsa returns).
 else
	 set @vis_table_id  = (select  id
	 from	`futurelearn_courses_information`.`vis_table_information` vi
	 where	vi.vis_table_name = vis_table_name);
 end if;
 
 if (@course_id > 0) then
 INSERT INTO `futurelearn_courses_information`.`course_logging_table`
 (
 `course_file_id`,
 `vis_table_id`,
 `log_datetime`,
 `comment`)
 VALUES
 (
  	@course_file_id,
    @vis_table_id,
 	log_datetime,
	comments);
 end if;
 
 END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `insert_error_logging_table` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `insert_error_logging_table`(
  error_datetime datetime,
  error_message text
  )
BEGIN
 
 INSERT INTO `futurelearn_courses_information`.`error_logging_table`
 (
 `error_message`,
 `error_datetime`)
 VALUES
 (error_message,error_datetime
 );
 
 
 END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `update_course_information` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE PROCEDURE `update_course_information`(
course_name varchar(100) 
, course_name_fl varchar(100) 
, duration_week int(11) 
, end_date date 
, start_date date 
, version smallint(6) 
, active tinyint(4) 
, _status varchar(20)
, organisation varchar(45)
)
BEGIN

if(course_name_fl is not null and version is not null) then

	set @total  = (select  count(*) as total
	 from	`futurelearn_courses_information`.`course_information` ci
	 WHERE ci.course_name_fl=course_name_fl and ci.version = version);

	if (@total = 1) then
		UPDATE `futurelearn_courses_information`.`course_information` ci
		SET
        `course_name` = course_name,
		`duration_week` = duration_week,
		`end_date` = end_date,
		`start_date` = start_date,
		`active` = active,
		`status` = _status,
		`organisation` = organisation
		WHERE ci.course_name_fl=course_name_fl and ci.version = version;

      
	end if;
    if (@total = 0) then
		CALL `futurelearn_courses_information`.`insert_course_information`(course_name, course_name_fl, duration_week, end_date, start_date, version, active, _status, organisation);
	end if;

end if;
END ;;
DELIMITER ;


-- To force MySQL insert an id with 0 value
SET @@session.sql_mode = 
    CASE WHEN @@session.sql_mode NOT LIKE '%NO_AUTO_VALUE_ON_ZERO%' 
        THEN CASE WHEN LENGTH(@@session.sql_mode)>0
            THEN CONCAT_WS(',',@@session.sql_mode,'NO_AUTO_VALUE_ON_ZERO')  -- added, wasn't empty
            ELSE 'NO_AUTO_VALUE_ON_ZERO'                                    -- replaced, was empty
        END
        ELSE @@session.sql_mode                                             -- unchanged, already had NO_AUTO_VALUE_ON_ZERO set
    END;
    
--
-- Dumping data for table `file_information`
--

LOCK TABLES `file_information` WRITE;
/*!40000 ALTER TABLE `file_information` DISABLE KEYS */;
INSERT INTO `file_information` VALUES (0,'not existed'),(1,'comments'),(2,'enrolments'),(3,'question_response'),(4,'step_activity'),(5,'peer_review_assignments'),(6,'peer_review_reviews'),(8,'pre_survey'),(9,'post_survey'),(10,'team_members'),(11,'campaigns'),(12,'textrank'),(13,'tfidf');
/*!40000 ALTER TABLE `file_information` ENABLE KEYS */;
UNLOCK TABLES;


--
-- Dumping data for table `column_information`
--

LOCK TABLES `column_information` WRITE;
/*!40000 ALTER TABLE `column_information` DISABLE KEYS */;
INSERT INTO `column_information` VALUES (0,NULL,NULL),(1,'age_range','varchar(20)'),(2,'assignment_id','bigint(20)'),(3,'author_id','varchar(36)'),(4,'correct','tinyint(1)'),(5,'country','varchar(20)'),(6,'created_at','datetime'),(7,'employment_area','varchar(50)'),(8,'employment_status','varchar(50)'),(9,'enrolled_at','datetime'),(10,'first_viewed_at','datetime'),(11,'first_visited_at','datetime'),(12,'fully_participated_at','datetime'),(13,'gender','varchar(20)'),(14,'guideline_one_feedback','text'),(15,'guideline_three_feedback','text'),(16,'guideline_two_feedback','text'),(17,'highest_education_level','varchar(50)'),(18,'id','bigint(20)'),(19,'index','bignint(20)'),(20,'last_completed_at','datetime'),(21,'learner_id','varchar(36)'),(22,'likes','int(11)'),(23,'moderated','datetime'),(24,'parent_id','bigint(20)'),(25,'purchased_statement_at','datetime'),(26,'question_number','smallint(6)'),(27,'quiz_question','varchar(10)'),(28,'response','varchar(50)'),(29,'review_count','int(11)'),(30,'reviewer_id','varchar(36)'),(31,'role','varchar(20)'),(32,'step','varchar(5)'),(33,'step_number','smallint(6)'),(34,'submitted_at','datetime'),(35,'text','text'),(36,'timestamp','datetime'),(37,'unenrolled_at','datetime'),(38,'week_number','smallint(6)'),(39,'utm_source','varchar(255)'),(40,'utm_campaign','varchar(255)'),(41,'utm_medium','varchar(255)'),(42,'domain','varchar(255)'),(43,'enrolments','int(11)'),(44,'active_learners','int(11)'),(45,'first_name','varchar(100)'),(46,'last_name','varchar(100)'),(47,'team_role','varchar(50)'),(48,'user_role','varchar(50)'),(49,'first_reported_at','datetime'),(50,'first_reported_reason','varchar(255)'),(51,'moderation_state','varchar(100)'),(52,'detected_country','varchar(2)');
/*!40000 ALTER TABLE `column_information` ENABLE KEYS */;
UNLOCK TABLES;


--
-- Dumping data for table `course_information`
--

LOCK TABLES `course_information` WRITE;
/*!40000 ALTER TABLE `course_information` DISABLE KEYS */;
INSERT INTO `course_information` VALUES (0,NULL,NULL,NULL,NULL,NULL,1,NULL,NULL,NULL);
/*!40000 ALTER TABLE `course_information` ENABLE KEYS */;
UNLOCK TABLES;


--
-- Dumping data for table `vis_table_information`
--

LOCK TABLES `vis_table_information` WRITE;
/*!40000 ALTER TABLE `vis_table_information` DISABLE KEYS */;
INSERT INTO `vis_table_information` VALUES (0,'not existed'),(1,'vis_ActivityByStep'),(2,'vis_AfinnSentimentAnalysisResult'),(3,'vis_BingSentimentAnalysisResult'),(4,'vis_CommentsCountHeatmap'),(5,'vis_CommentsOverviewTable'),(6,'vis_CommentsStatsDay'),(7,'vis_CommentsStatsStep'),(8,'vis_EnrolmentsByDay'),(9,'vis_EnrolmentsByWeek'),(10,'vis_HoursSpendByWeek'),(11,'vis_FirstItemMap'),(12,'vis_LastProgressesByDate'),(13,'vis_LastProgressesByStep'),(14,'vis_LearnersActivities'),(15,'vis_OriginalSentimentAnalysisResult'),(16,'vis_FirstPersonItemMap'),(17,'vis_QuartileAnalysisResult'),(18,'vis_QuestionResponseOverview'),(19,'vis_FirstRaschAnalysisSummary'),(20,'vis_StepProgressCountsHeatmap'),(21,'vis_CommentsStatsByStepRole'),(22,'vis_StepProgressCountsHeatmapByWeek'),(23,'vis_AttemptToCorrect'),(24,'vis_WordCloudOfOriginalSentimentAnalysis'),(25,'vis_LearnersActivitiesByDay'),(26,'vis_LastItemMap'),(27,'vis_LastPersonItemMap'),(28,'vis_LastRaschAnalysisSummary'),(29,'vis_QuizAttempts'),(30,'vis_CommentsStatsDayType'),(31,'vis_ActivityByDayType'),(33,'vis_WordCountStatsByEducators'),(34,'vis_CommentsHistogramByLearners'),(35,'vis_VisitedFirstStepFinishedAllSteps'),(36,'vis_WordCountAnalysisByRole'),(37,'vis_NetworkAnalysisByStep'),(38,'vis_NetworkAnalysisByLearners'),(39,'vis_CommentsStatsByEducators'),(40,'vis_QuizNetworkAnalysisByLearners'),(41,'vis_ScoresHistogram'),(42,'vis_MinutesSpendByStep'),(43,'vis_VisitedOtherStepsDuringQuiz');
/*!40000 ALTER TABLE `vis_table_information` ENABLE KEYS */;
UNLOCK TABLES;



--
-- Dumping data for table `course_file_information`
--

LOCK TABLES `course_file_information` WRITE;
/*!40000 ALTER TABLE `course_file_information` DISABLE KEYS */;
INSERT INTO `course_file_information` VALUES (0,0,0);
/*!40000 ALTER TABLE `course_file_information` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `course_information_details`
--

LOCK TABLES `course_information_details` WRITE;
/*!40000 ALTER TABLE `course_information_details` DISABLE KEYS */;
INSERT INTO `futurelearn_courses_information`.`course_information_details` VALUES (0,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);
/*!40000 ALTER TABLE `course_information_details` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `file_column_information`
--

LOCK TABLES `file_column_information` WRITE;
/*!40000 ALTER TABLE `file_column_information` DISABLE KEYS */;
INSERT INTO `file_column_information` VALUES (0,0,0),(1,1,19),(2,1,18),(3,1,3),(4,1,24),(5,1,32),(6,1,38),(7,1,33),(8,1,35),(9,1,36),(10,1,23),(11,1,22),(12,2,19),(13,2,21),(14,2,9),(15,2,37),(16,2,31),(17,2,12),(18,2,25),(19,2,13),(20,2,5),(21,2,1),(22,2,17),(23,2,8),(24,2,7),(25,3,19),(26,3,21),(27,3,27),(28,3,38),(29,3,33),(30,3,26),(31,3,28),(32,3,34),(33,3,4),(34,4,19),(35,4,21),(36,4,32),(37,4,38),(38,4,33),(39,4,11),(40,4,20),(41,5,19),(42,5,18),(43,5,32),(44,5,38),(45,5,33),(46,5,3),(47,5,35),(48,5,10),(49,5,34),(50,5,23),(51,6,19),(52,6,18),(53,6,32),(54,6,38),(55,6,33),(56,6,30),(57,6,2),(58,6,14),(59,6,15),(60,6,16),(62,6,6),(63,5,29),(64,10,19),(65,10,18),(66,10,45),(67,10,46),(68,10,47),(69,10,48),(70,11,19),(71,11,39),(72,11,40),(73,11,41),(74,11,42),(75,11,43),(76,11,44),(77,1,49),(78,1,50),(79,1,51),(80,2,52);
/*!40000 ALTER TABLE `file_column_information` ENABLE KEYS */;
UNLOCK TABLES;


--
-- Dumping data for table `vis_table_file_information`
--

LOCK TABLES `vis_table_file_information` WRITE;
/*!40000 ALTER TABLE `vis_table_file_information` DISABLE KEYS */;
INSERT INTO `vis_table_file_information` VALUES (0,0,0),(1,8,2),(2,9,2),(3,1,4),(4,1,1),(5,14,4),(6,14,1),(7,13,4),(8,12,4),(9,10,4),(10,20,4),(11,4,1),(12,5,1),(13,7,1),(14,6,1),(15,3,1),(16,2,1),(17,15,1),(18,18,3),(19,19,3),(20,11,3),(21,16,3),(22,17,3),(23,21,1),(24,21,2),(25,22,4),(26,22,2),(27,23,3),(28,24,1),(29,25,1),(30,25,2),(31,25,4),(32,26,3),(33,27,3),(34,28,3),(35,15,2),(36,29,3),(37,30,1),(39,33,1),(40,33,2),(41,34,1),(42,34,2),(43,35,1),(44,35,2),(45,35,4),(46,36,1),(47,36,2),(48,37,2),(49,37,4),(50,38,2),(51,38,4),(52,39,1),(53,39,2),(54,40,3),(55,40,2),(56,41,3),(57,41,10),(58,42,4),(59,42,10),(60,43,3),(61,43,4),(62,43,10);
/*!40000 ALTER TABLE `vis_table_file_information` ENABLE KEYS */;
UNLOCK TABLES;



/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2017-05-29  9:19:46
