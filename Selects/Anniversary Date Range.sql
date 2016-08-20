/*
This query will select records based on a date range for records that have a date 
anniversary within that date range.

This example selects only those people who have a multiple of 
5 year anniversary (5, 10, 15, 20, ...)

The query will work even if the date range spans over a year end (12/1/2006 - 1/31/2007)
*/ 

declare @BeginDate datetime
set @BeginDate = '2006-6-1'
declare @EndDate datetime
set @EndDate = '2006-6-30'
declare @Period int
set @Period = 5

select emp_doh, dateadd(year, datediff(year, emp_doh, @BeginDate), emp_doh) as Anniversary, 
datediff(year,emp_doh,dateadd(year, datediff(year, emp_doh, @BeginDate), emp_doh)) as Years, 
datediff(year,emp_doh,dateadd(year, datediff(year, emp_doh, @BeginDate), emp_doh)) % @Period as Period, 
* from employee_main
where dateadd(year, datediff(year, emp_doh, @BeginDate), emp_doh) >= @BeginDate 
and dateadd(year, datediff(year, emp_doh, @BeginDate),emp_doh) <= @EndDate 
and month(emp_doh) >= month(@BeginDate) 
--select those who have a multiple of @Period defined year anniversary
and (datediff(year,emp_doh,dateadd(year, datediff(year, emp_doh, @BeginDate), emp_doh)) % @Period) = 0
--also select those with a larger than 1 year anniversary to remeove those with a "zero" year anniversary
and datediff(year,emp_doh,dateadd(year, datediff(year, emp_doh, @BeginDate), emp_doh)) > 1

--use UNION, and not UNION ALL to prevent duplicates
union 

--additional query incase the date range spans across the end of year
select emp_doh, dateadd(year, datediff(year, emp_doh, @BeginDate) + 1, emp_doh) as Anniversary, 
datediff(year,emp_doh,dateadd(year, datediff(year, emp_doh, @BeginDate), emp_doh)) + 1 as Years, 
(datediff(year,emp_doh,dateadd(year, datediff(year, emp_doh, @BeginDate), emp_doh)) + 1 ) % @Period as Period, 
* from employee_main 
where dateadd(year, datediff(year, emp_doh, @BeginDate) + 1, emp_doh) >= @BeginDate 
and dateadd(year, datediff(year, emp_doh, @BeginDate) + 1, emp_doh) <= @EndDate  
and month(emp_doh) < month(@BeginDate) 
--select those who have a multiple of @Period defined year anniversary
and ((datediff(year,emp_doh,dateadd(year, datediff(year, emp_doh, @BeginDate), emp_doh)) + 1 ) % @Period) = 0
--also select those with a larger than 1 year anniversary to remeove those with a "zero" year anniversary
and (datediff(year,emp_doh,dateadd(year, datediff(year, emp_doh, @BeginDate), emp_doh)) + 1) > 1

order by EMP_DOH
