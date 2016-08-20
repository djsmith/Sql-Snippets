/**********************************************************************************************************
Date Calendar
By Sean Smith, 2009/10/29 
http://www.sqlservercentral.com/scripts/Date/68389/

Business rules or requirements surrounding a date are often difficult to implement. This script 
pre-calculates many elements of a date's characteristics into a lookup table. 

To run it, simply choose the database in which you want the table to reside, populate the 
@vDate_Start and @vDate_End variables with the date range you want populated in the calendar, and execute.

Below is a listing of the output fields and their description using a date of 10/06/2009 (MM/DD/YYYY) 
as the reference example (the code should compensate for how any SQL Server instance is set up to 
handle the internal settings for start / end of week, weekdays, etc.). All values after the 
calendar_date field are specific to the date value found in each individual record.

    * calendar_date: calendar date value (2009-10-06 00:00:00.000)
    * calendar_year: year portion of the date (2009)
    * calendar_month: month portion of the date (10)
    * calendar_day: day portion of the date (6)
    * calendar_quarter: quarter in which the date value falls under (4)
    * first_day_in_week: first day of the week in which the date value is found (2009-10-04 00:00:00.000)
    * last_day_in_week: last day of the week in which the date value is found (2009-10-10 00:00:00.000)
    * is_week_in_same_month: is the first_day_in_week and last_day_in_week value contained within the same month - Boolean (1)
    * first_day_in_month: first day of the month (2009-10-01 00:00:00.000)
    * last_day_in_month: last day of the month (2009-10-31 00:00:00.000)
    * day_of_week: day of the week (3)
    * week_of_month: week of the month (2)
    * week_of_year: week of the year (41)
    * days_in_month: total days in the month (31)
    * month_days_remaining: number of days remaining in the month (25)
    * weekdays_in_month: number of weekdays in the the month (22)
    * month_weekdays_remaining: number of weekdays remaining in the month (18)
    * month_weekdays_completed: number of weekdays completed in the month (4)
    * day_of_year: number of days completed in the year (279)
    * year_days_remaining: number of days remaining in the year (86)
    * is_weekday: is the date a weekday - Boolean (1)
    * is_leap_year: is the date contained within a leap year - Boolean (0)
    * day_name: full name of the day (Tuesday)
    * month_day_name_instance: number of occurrences of the day_name within the month up until and including the specified date (1)
    * quarter_day_name_instance: number of occurrences of the day_name within the quarter up until and including the specified date (1)
    * year_day_name_instance: number of occurrences of the day_name within the year up until and including the specified date (40)
    * month_name: full name of the month (October)
    * year_week: calendar_year and week_of_year (left padded with zeros) values concatenated (200941)
    * year_month: calendar_year and calendar_month (left padded with zeros) values concatenated (200910)
    * year_quarter: calendar_year and calendar_quarter (prefixed with a "Q") values concatenated (2009Q4)

**********************************************************************************************************/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ARITHABORT OFF
SET ARITHIGNORE ON

DECLARE @vDate_Start AS datetime
DECLARE @vDate_End AS datetime

SET @vDate_Start = '01/01/2000'
SET @vDate_End = '12/31/2030'

----------------------------------------------------------------------------------------------------------------------
--	Error Trapping: Check If Permanent Table(s) Already Exist(s) And Drop If Applicable
----------------------------------------------------------------------------------------------------------------------

IF OBJECT_ID('dbo.date_calendar') IS NOT NULL
   BEGIN
      DROP TABLE dbo.date_calendar
   END


----------------------------------------------------------------------------------------------------------------------
--	Permanent Table: Create Date Xref Table
----------------------------------------------------------------------------------------------------------------------

CREATE TABLE dbo.date_calendar (calendar_date datetime PRIMARY KEY CLUSTERED,
                                calendar_year int,
                                calendar_month int,
                                calendar_day int,
                                calendar_quarter int,
                                first_day_in_week datetime,
                                last_day_in_week datetime,
                                is_week_in_same_month int,
                                first_day_in_month datetime,
                                last_day_in_month datetime,
                                day_of_week int,
                                week_of_month int,
                                week_of_year int,
                                days_in_month int,
                                month_days_remaining int,
                                weekdays_in_month int,
                                month_weekdays_remaining int,
                                month_weekdays_completed int,
                                day_of_year int,
                                year_days_remaining int,
                                is_weekday int,
                                is_leap_year int,
                                day_name varchar(10),
                                month_day_name_instance int,
                                quarter_day_name_instance int,
                                year_day_name_instance int,
                                month_name varchar(10),
                                year_week varchar(6),
                                year_month varchar(6),
                                year_quarter varchar(6)) ;


----------------------------------------------------------------------------------------------------------------------
--	Table Insert: Populate Base Date Values Into Permanent Table Using Common Table Expression (CTE)
----------------------------------------------------------------------------------------------------------------------

WITH cte_date_base_table
   AS
   (
   SELECT  @vDate_Start
	AS calendar_date

   UNION ALL

   SELECT  DATEADD (DAY, 1, CTE.calendar_date)
   FROM    cte_date_base_table CTE
   WHERE   DATEADD (DAY, 1, CTE.calendar_date) <= @vDate_End
   )

    INSERT  INTO dbo.date_calendar (calendar_date )
            SELECT  CTE.calendar_date
            FROM    cte_date_base_table CTE
            OPTION (MAXRECURSION 0)


----------------------------------------------------------------------------------------------------------------------
--	Table Update I: Populate Additional Date Xref Table Fields (Pass I)
----------------------------------------------------------------------------------------------------------------------

UPDATE  dbo.date_calendar
SET     calendar_year = DATEPART(YEAR, calendar_date),
        calendar_month = DATEPART(MONTH, calendar_date),
        calendar_day = DATEPART(DAY, calendar_date),
        calendar_quarter = DATEPART(QUARTER, calendar_date),
        first_day_in_week = DATEADD(DAY, -DATEPART(WEEKDAY, calendar_date) + 1, calendar_date),
        first_day_in_month = CONVERT(varchar(6), calendar_date, 112) + '01',
        day_of_week = DATEPART(WEEKDAY, calendar_date),
        week_of_year = DATEPART(WEEK, calendar_date),
        day_of_year = DATEPART(DAYOFYEAR, calendar_date),
        is_weekday = ISNULL((CASE WHEN ((@@DATEFIRST - 1) + (DATEPART(WEEKDAY, calendar_date) - 1)) % 7 NOT IN (5, 6) THEN 1
                             END), 0),
        day_name = DATENAME(WEEKDAY, calendar_date),
        month_name = DATENAME(MONTH, calendar_date)


ALTER TABLE dbo.date_calendar ALTER COLUMN calendar_year int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN calendar_month int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN calendar_day int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN calendar_quarter int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN first_day_in_week datetime NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN first_day_in_month datetime NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN day_of_week int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN week_of_year int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN day_of_year int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN is_weekday int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN day_name varchar(10) NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN month_name varchar(10) NOT NULL


CREATE NONCLUSTERED INDEX [IX_calendar_year] ON dbo.date_calendar (calendar_year)


CREATE NONCLUSTERED INDEX [IX_calendar_month] ON dbo.date_calendar (calendar_month)


CREATE NONCLUSTERED INDEX [IX_calendar_quarter] ON dbo.date_calendar (calendar_quarter)


CREATE NONCLUSTERED INDEX [IX_first_day_in_week] ON dbo.date_calendar (first_day_in_week)


CREATE NONCLUSTERED INDEX [IX_day_of_week] ON dbo.date_calendar (day_of_week)


CREATE NONCLUSTERED INDEX [IX_is_weekday] ON dbo.date_calendar (is_weekday)


----------------------------------------------------------------------------------------------------------------------
--	Table Update II: Populate Additional Date Xref Table Fields (Pass II)
----------------------------------------------------------------------------------------------------------------------

UPDATE  dbo.date_calendar
SET     last_day_in_week = first_day_in_week + 6,
        last_day_in_month = DATEADD(MONTH, 1, first_day_in_month) - 1,
        week_of_month = DATEDIFF(WEEK, first_day_in_month, calendar_date) + 1,
        is_leap_year = ISNULL((CASE WHEN calendar_year % 400 = 0 THEN 1
                                    WHEN calendar_year % 100 = 0 THEN 0
                                    WHEN calendar_year % 4 = 0 THEN 1
                               END), 0),
        year_week = CONVERT(varchar(4), calendar_year) + RIGHT('0' + CONVERT(varchar(2), week_of_year), 2),
        year_month = CONVERT(varchar(4), calendar_year) + RIGHT('0' + CONVERT(varchar(2), calendar_month), 2),
        year_quarter = CONVERT(varchar(4), calendar_year) + 'Q' + CONVERT(varchar(1), calendar_quarter)


ALTER TABLE dbo.date_calendar ALTER COLUMN last_day_in_week datetime NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN last_day_in_month datetime NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN week_of_month int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN is_leap_year int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN year_week varchar(6) NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN year_month varchar(6) NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN year_quarter varchar(6) NOT NULL


CREATE NONCLUSTERED INDEX [IX_last_day_in_week] ON dbo.date_calendar (last_day_in_week)


CREATE NONCLUSTERED INDEX [IX_year_month] ON dbo.date_calendar (year_month)


CREATE NONCLUSTERED INDEX [IX_year_quarter] ON dbo.date_calendar (year_quarter)


----------------------------------------------------------------------------------------------------------------------
--	Table Update III: Populate Additional Date Xref Table Fields (Pass III)
----------------------------------------------------------------------------------------------------------------------

UPDATE  dbo.date_calendar
SET     days_in_month = DATEPART(DAY, last_day_in_month),
        weekdays_in_month = A.weekdays_in_month,
        year_days_remaining = (365 + is_leap_year) - day_of_year
FROM    (SELECT  X.year_month, SUM(X.is_weekday) AS weekdays_in_month
         FROM    dbo.date_calendar X
         GROUP BY X.year_month) A
WHERE   A.year_month = dbo.date_calendar.year_month


ALTER TABLE dbo.date_calendar ALTER COLUMN days_in_month int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN weekdays_in_month int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN year_days_remaining int NOT NULL


----------------------------------------------------------------------------------------------------------------------
--	Table Update IV: Populate Additional Date Xref Table Fields (Pass IV)
----------------------------------------------------------------------------------------------------------------------

UPDATE  dbo.date_calendar
SET     month_weekdays_remaining = weekdays_in_month - A.month_weekdays_remaining_subtraction
FROM    (SELECT  X.calendar_date, ROW_NUMBER() OVER (PARTITION BY X.year_month
                 ORDER BY X.calendar_date) AS month_weekdays_remaining_subtraction
         FROM    dbo.date_calendar X
         WHERE   X.is_weekday = 1) A
WHERE   A.calendar_date = dbo.date_calendar.calendar_date


----------------------------------------------------------------------------------------------------------------------
--	Table Update V: Populate Additional Date Xref Table Fields (Pass V)
----------------------------------------------------------------------------------------------------------------------

UPDATE  dbo.date_calendar
SET     month_weekdays_remaining = A.month_weekdays_remaining
FROM    (SELECT  X.calendar_date, COALESCE(Y.month_weekdays_remaining, Z.month_weekdays_remaining, X.weekdays_in_month) AS month_weekdays_remaining
         FROM    dbo.date_calendar X
                 LEFT JOIN dbo.date_calendar Y
                    ON DATEADD(DAY, 1, Y.calendar_date) = X.calendar_date
                       AND Y.year_month = X.year_month
                 LEFT JOIN dbo.date_calendar Z
                    ON DATEADD(DAY, 2, Z.calendar_date) = X.calendar_date
                       AND Z.year_month = X.year_month
         WHERE   X.month_weekdays_remaining IS NULL) A
WHERE   A.calendar_date = dbo.date_calendar.calendar_date


ALTER TABLE dbo.date_calendar ALTER COLUMN month_weekdays_remaining int NOT NULL


----------------------------------------------------------------------------------------------------------------------
--	Table Update VI: Populate Additional Date Xref Table Fields (Pass VI)
----------------------------------------------------------------------------------------------------------------------

UPDATE  dbo.date_calendar
SET     is_week_in_same_month = A.is_week_in_same_month,
        month_days_remaining = days_in_month - calendar_day,
        month_weekdays_completed = weekdays_in_month - month_weekdays_remaining,
        month_day_name_instance = A.month_day_name_instance,
        quarter_day_name_instance = A.quarter_day_name_instance,
        year_day_name_instance = A.year_day_name_instance
FROM    (SELECT  X.calendar_date, ISNULL((CASE WHEN DATEDIFF(MONTH, X.first_day_in_week, X.last_day_in_week) = 0 THEN 1
                                          END), 0) AS is_week_in_same_month, ROW_NUMBER() OVER (PARTITION BY X.year_month, X.day_name
                 ORDER BY X.calendar_date) AS month_day_name_instance, ROW_NUMBER() OVER (PARTITION BY X.year_quarter, X.day_name
                 ORDER BY X.calendar_date) AS quarter_day_name_instance, ROW_NUMBER() OVER (PARTITION BY X.calendar_year, X.day_name
                 ORDER BY X.calendar_date) AS year_day_name_instance
         FROM    dbo.date_calendar X) A
WHERE   A.calendar_date = dbo.date_calendar.calendar_date


ALTER TABLE dbo.date_calendar ALTER COLUMN is_week_in_same_month int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN month_days_remaining int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN month_weekdays_completed int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN month_day_name_instance int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN quarter_day_name_instance int NOT NULL


ALTER TABLE dbo.date_calendar ALTER COLUMN year_day_name_instance int NOT NULL


----------------------------------------------------------------------------------------------------------------------
--	Main Query: Final Display/Output
----------------------------------------------------------------------------------------------------------------------

SELECT  URD.*
FROM    dbo.date_calendar URD
ORDER BY URD.calendar_date
 