SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[fnWeeksBetween]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[fnWeeksBetween]
GO

/**************************************************************
Returns one row for each week that falls in the date range.
If @IncludePartialWeeks is 0 then only full weeks are returned.
Note: only tested for default value of DATEFIRST.
Example:
	Select * FROM dbo.fnWeeksBetween('2005-01-01', '2005-02-03', default, default)
****************************************************************/
Create Function dbo.fnWeeksBetween(@BeginDate datetime, @EndDate datetime, @IncludePartialWeeks bit = 1, @DayToStartWeek smallint = 1 )
Returns @Weeks 
	Table (WeekCount int Primary Key, WeekStart smalldatetime, WeekEnd smalldatetime)

As Begin

	Declare @WeekCount int -- counter for each week between start and end
	Declare @WeekEnd smalldatetime -- 1st Day of week to start
	Declare @WorkDate smalldatetime -- Date we're working with

	-- Eliminating the time portion of the start date.
	-- At the same time, we subtract enough days to go back to 
	-- the start of the week that @BeginDate falls in.
	Set @WorkDate =  Dateadd(dd, Datepart(dy, @BeginDate) - Datepart(dw, @BeginDate) + @DayToStartWeek - 1, Convert(datetime, Convert(Char(4), Datepart(yyyy,@BeginDate)) + '-01-01'))
	Set @WeekCount = 1

	-- Insert one record for each week
	While @WorkDate <= @EndDate 
	Begin
		Set @WeekEnd = Dateadd(dd, 6, @WorkDate)
		
		-- Only include a week if we're including partial weeks
		-- or if the entire week falls in the date range.
		If @IncludePartialWeeks = 1  
			or (@WorkDate >= @BeginDate and @WeekEnd <= @EndDate) 
		Begin
			Insert Into @Weeks Values (@WeekCount, @WorkDate, @WeekEnd)
		END
	
		Set @WorkDate = DateAdd(wk, 1, @WorkDate)
		Set @WeekCount = @WeekCount+1
	END
	
	Return 
END

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

 