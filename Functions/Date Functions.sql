/*
Date Functions
Various date functions for getting the start or end of a month or quarter. 
Avoids problems with leap years and Feb 29th.
*/
DECLARE @TheDate DATETIME
SET @TheDate = '1/1/2005'
DECLARE @D INT
DECLARE @M INT
DECLARE @Q INT
DECLARE @Y INT
-- set the quarter, month and year
SET @D = DAY(@TheDate)
SET @M = MONTH(@TheDate)
SET @Q = FLOOR(@M/4) + 1
SET @Y = YEAR(@TheDate)

select @TheDate, @D, @M, @Q, @Y

--first day of the month; just append month, day and year
SELECT CAST(CAST(@M AS VARCHAR(2))+'/1/'+CAST(@Y AS VARCHAR(4)) AS DATETIME) AS FirstDayOfMonth

--last date of the month; first add a month then subtract one day, works with leap year
SELECT DATEADD(dd, -1, DATEADD(m, 1, CAST(@M AS VARCHAR(2))+'/1/'+CAST(@Y AS VARCHAR(4)))) AS LastDayOfMonth

--first date of the quarter
SELECT DATEADD(qq, @Q-1, '1/1/'+CAST(@Y AS VARCHAR(4))) AS FirstDayOfQuarter

--last date of the quarter
SELECT DATEADD(dd, -1, DATEADD(qq, @Q, '1/1/'+CAST(@Y AS VARCHAR(4)))) AS LastDayOfQuarter

--first date of the quarter for a given month
SELECT DATEADD(qq, DATEPART(qq, CAST(@M AS VARCHAR(2))+'/1/'+CAST(@Y AS VARCHAR(4)))-1, '1/1/'+CAST(@Y AS VARCHAR(4))) AS FirstDayOfQuarterOfGivenMonth

--last date of the quarter for a given month
SELECT DATEADD(dd, -1, DATEADD(qq, DATEPART(qq, CAST(@M AS VARCHAR(2))+'/1/'+CAST(@Y AS VARCHAR(4))), '1/1/'+CAST(@Y AS VARCHAR(4)))) AS LastDayOfQuarterOfGivenMonth

GO

--Function returns the X day of the month for a given day of the week
-- i.e., returns the third Monday after the start date
-- NOTE this function is probably overly complicated, but it works
-- http://www.sqlservercentral.com/scripts/Date/65850/
CREATE FUNCTION dbo.GetXDayOfMonth (@startDate DATETIME, @dayOfMonth INT, @dayOfWeek NVARCHAR(20)) 
	RETURNS DATETIME
AS
/* 
@startDate = start date (mm/dd/yyyy), 
@endDate = end date (mm/dd/yyyy), 
@dayOfMonth values (1, 2, 3, 4, 5) where   
	1 = First day of month
	2 = Second day of month
	3 = Third day of month
	4 = Fourth day of month
	5 = Last day of month
@dayOfWeek values (Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday)
*/ 
BEGIN 
	DECLARE @DateCounter DATETIME
	SET @DateCounter = @startDate
	DECLARE @EndDate DATETIME
	SET @EndDate = DATEADD(week, 5, @startDate)
	DECLARE @MonthName NVARCHAR(20)
	SET @MonthName = DATENAME(MONTH, @startDate)
	DECLARE @WeekDay AS INT
	DECLARE @Date AS DATETIME

	IF @dayOfWeek='Monday' BEGIN
		SET @WeekDay = 0
	END
	IF @dayOfWeek='Tuesday' BEGIN
		SET @WeekDay = 1
	END
	IF @dayOfWeek='Wednesday' BEGIN
		SET @WeekDay = 2
	END
	IF @dayOfWeek='Thursday' BEGIN
		SET @WeekDay = 3
	END
	IF @dayOfWeek='Friday' BEGIN
		SET @WeekDay = 4
	END
	IF @dayOfWeek='Saturday' BEGIN
		SET @WeekDay = 5
	END
	IF @dayOfWeek='Sunday' BEGIN
		SET @WeekDay = 6
	END

	WHILE @DateCounter <= @endDate BEGIN
		IF (SELECT DATENAME(MONTH, @DateCounter))=@MonthName BEGIN
			IF @dayOfMonth = 1 BEGIN
				SET @Date = (SELECT 
					CASE WHEN DATEPART(DAY, DATEADD(wk, DATEDIFF(wk, @WeekDay, DATEADD(dd, 6-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay)) > 7 THEN DATEADD(wk, DATEDIFF(wk, @WeekDay, DATEADD(dd, 6-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay)-7
					ELSE DATEADD(wk, DATEDIFF(wk, @WeekDay, DATEADD(dd, 6-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay) END)
			END
	        
        	IF @dayOfMonth = 2 BEGIN
				SET @Date = (SELECT 
					CASE WHEN DATEPART(DAY, DATEADD(wk, DATEDIFF(wk, @WeekDay,  DATEADD(dd, 12-DATEPART(DAY, @DateCounter), @DateCounter)),  @WeekDay)) > 14 THEN DATEADD(wk,  DATEDIFF(wk, @WeekDay,  DATEADD(dd, 12-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay)-7
					ELSE DATEADD(wk, DATEDIFF(wk, @WeekDay, DATEADD(dd, 12-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay) END)
			END
			IF @dayOfMonth = 3 BEGIN
				SET @Date = (SELECT 
					CASE WHEN DATEPART(DAY, DATEADD(wk, DATEDIFF(wk, @WeekDay, DATEADD(dd, 18-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay)) > 21 THEN DATEADD(wk, DATEDIFF(wk, @WeekDay, DATEADD(dd, 18-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay)-7
					ELSE DATEADD(wk, DATEDIFF(wk, @WeekDay, DATEADD(dd, 18-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay) END)
			END
			
        	IF @dayOfMonth = 4 BEGIN
				SET @Date = (SELECT 
					CASE WHEN DATEPART(DAY, DATEADD(wk, DATEDIFF(wk, @WeekDay, DATEADD(dd, 24-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay)) > 28 THEN DATEADD(wk, DATEDIFF(wk, @WeekDay, DATEADD(dd, 24-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay)-7
					ELSE DATEADD(wk, DATEDIFF(wk, @WeekDay, DATEADD(dd, 24-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay) END)
			END
	        
        	IF @dayOfMonth = 5 BEGIN
				SET @Date = (SELECT 
					CASE WHEN DATEPART(DAY, DATEADD(wk, DATEDIFF(wk, @WeekDay, DATEADD(dd, 30-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay)) > 28 THEN DATEADD(wk, DATEDIFF(wk, @WeekDay, DATEADD(dd, 30-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay)
					ELSE DATEADD(wk, DATEDIFF(wk, @WeekDay, DATEADD(dd, 24-DATEPART(DAY, @DateCounter), @DateCounter)), @WeekDay) END)
			END
		END
		
    	SET @DateCounter = DATEADD(MONTH, 1, @DateCounter)
	END
	
	--RETURN CAST(CONVERT(NVARCHAR, @Date, 101) AS NVARCHAR(10)) 
	RETURN @Date
END
GO

--SELECT dbo.GetXDayOfMonth('1/1/2009', '1/10/2009', 2, 'Monday') AS XDayOfMonth
SELECT dbo.GetXDayOfMonth('1/1/2009', 2, 'Monday') AS XDayOfMonth
GO

IF OBJECT_ID(N'dbo.GetXDayOfMonth', N'FN') IS NOT NULL BEGIN
	DROP FUNCTION dbo.GetXDayOfMonth
END
GO


