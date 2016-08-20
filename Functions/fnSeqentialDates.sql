/*
This function returns a table containing a table of dates between
the @StartDate and @EndDate

This function is fast enough for date ranges up to eight or
ten years. For larger date ranges, a technique with multiple CROSS JOINs is a
better alternative.

The function first seeds the return table with a single date, then enters
a loop to add more rows by selecting the existing rows. This results in a 
exponential progression of adding more rows to the return table. When
the @EndDate value is reached the @@RowCount is 0 and the loop exits.

Exaples:
--The number of workdays there in August 2006:
SELECT COUNT(*) Workdays FROM dbo.fnSeqentialDates('8/1/2006', '8/31/2006') 
WHERE DATEPART(dw, SeqDate) BETWEEN 2 AND 6
--Note; This doesn't take into account holidays. For that create a separate 
-- table of holidays and use a WHERE NOT IN clause

--The last Thursday in April 2007:
SELECT MAX(dt.SeqDate) LastThursday FROM dbo.fnSeqentialDates('4/1/2007', '4/30/2007') dt 
WHERE DATEPART(dw, dt.SeqDate) = 5

--Fridays in the first quarter 2008:
-- Even when 2008 is a leap year, the function is working.
SELECT SeqDate Fridays FROM dbo.fnSeqentialDates('3/31/2008', '1/1/2008') 
WHERE DATEPART(dw, SeqDate) = 6

--The last Thursday in April 2007:
SELECT MAX(dt.SeqDate) LastThursday FROM dbo.fnSeqentialDates('4/1/2007', '4/30/2007') dt 
WHERE DATEPART(dw, dt.SeqDate) = 5

--The second Tuesday in September 2012:
-- Use dt.SeqDate > '9/7/2012' because the first Tuesday will occur within the first seven days in month.
SELECT MIN(dt.SeqDate) SecondTuesday FROM dbo.fnSeqentialDates('9/1/2012', '9/30/2012') dt 
WHERE DATEPART(dw, dt.SeqDate) = 3 AND dt.SeqDate > '9/7/2012'

--The last Wednesday of every month in 2006?”.
SELECT MAX(SeqDate) LastWednesday FROM dbo.fnSeqentialDates('1/1/2006', '12/31/2006') 
WHERE DATEPART(dw, SeqDate) = 4 
GROUP BY MONTH(SeqDate) 
ORDER BY MONTH(SeqDate)

--First and last day of every month in 2008?”.
SELECT MIN(SeqDate) FirstDay, MAX(SeqDate) LastDay FROM dbo.fnSeqentialDates('1/1/2008', '12/31/2008') 
GROUP BY MONTH(SeqDate) 
ORDER BY MONTH(SeqDate)

--The paydays of every month in 2008 and 2009?”. Assuming monthly pay-day is 27th 
-- of every month and if 27th is weekend or holiday, the first weekday before that.
SELECT MAX(SeqDate) Paydays FROM dbo.fnSeqentialDates('1/1/2008', '12/31/2009')
WHERE SeqDate NOT IN (
	SELECT hDate FROM tblHolidays
	) 
	AND DAY(SeqDate) <= 27 
	AND DATEPART(dw, SeqDate) BETWEEN 2 AND 6
GROUP BY YEAR(SeqDate), MONTH(SeqDate) 
ORDER BY YEAR(SeqDate), MONTH(SeqDate)

--The number of Mondays until retirement”.
declare @today datetime
set @today = getdate()
--For some reason using the getdate() function as an input parameter causes an error
SELECT COUNT(SeqDate) Mondays FROM dbo.fnSeqentialDates(@today, '3/13/2032') 
WHERE DATEPART(dw, SeqDate) = 2

Source:
http://www.sqlservercentral.com/columnists/plarsson/howmanymoremondaysuntiliretire.asp
*/

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[fnSeqentialDates]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[fnSeqentialDates]
GO

create function dbo.fnSeqentialDates
(
	@StartDate datetime,
	@EndDate datetime
)
returns @Dates table
	(SeqDate datetime)
as

begin
	declare @Temp datetime

	if @StartDate > @EndDate
		select @Temp = @StartDate,
		@StartDate = dateadd(day, datediff(day, 0, @EndDate), 0),
		@EndDate = dateadd(day, datediff(day, 0, @Temp), 0)
	else
		select @StartDate = dateadd(day, datediff(day, 0, @StartDate), 0),
		@EndDate = dateadd(day, datediff(day, 0, @EndDate), 0)

	insert @Dates (SeqDate)
	values (@StartDate)

	while @@ROWCOUNT > 0
	begin
		insert @Dates (SeqDate)
		select dateadd(dd, n.Items, d.SeqDate)
		from @Dates d
		cross join (
			select count(SeqDate) Items
			from @Dates
		) n
		where dateadd(dd, n.Items, d.SeqDate) <= @EndDate
	end

	return
end
