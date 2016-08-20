SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[fnDaysBetween]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[fnDaysBetween]
GO

/* 
Returns one row for each day that falls in the date range.
If @IncludeWeekends is 1 then Saturdays and Sundays are included.
Note: DayCount column doesn't increment for Saturdays and Sundays
	when @IncludeWeekends is 0
Example:
	Select * From dbo.fnDaysBetween('2005-01-01', '2005-02-3', default)
****************************************************************/
Create Function dbo.fnDaysBetween(@BeginDate datetime, @EndDate datetime, @IncludeWeekends bit = 1)
Returns @Days
	Table (DayCount int Primary Key, [Date] smalldatetime)
As Begin

	Declare @DayCount int -- counter for each day between start and end
	Declare @WorkDT smalldatetime -- Date we're working with

	Set @WorkDT = @BeginDate
	Set @DayCount = 1

	-- Insert one record for each day
	While @WorkDT <= @EndDate 
	Begin
		
		-- Only include a day if we're including weekends 
		-- or if the day of the week is not Saturday or Sunday.
		If @IncludeWeekends = 1
			or (Datepart(dw,@WorkDT) > 1 and Datepart(dw,@WorkDT) < 7) 
		Begin
			Insert Into @Days Values (@DayCount, @WorkDT)
			Set @DayCount = @DayCount+1
		END
	
		Set @WorkDT = DateAdd(dd, 1, @WorkDT)
	END
	
	Return 
END

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

 