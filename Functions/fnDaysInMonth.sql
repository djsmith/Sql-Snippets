/*
Returns the number of days in the given month by getting
the first day of the next month then subtracting one
day using the DateAdd function, then returing the day using
the DatePart function

Examples:
Select dbo.fnDaysInMonth(getdate())
select dbo.fnDaysInMonth('2-23-2004') --Leap year: 29
select dbo.fnDaysInMonth('2-23-2005') --Non leap year: 28
select dbo.fnDaysInMonth('2-23-2100') --Non leap year: 28
select dbo.fnDaysInMonth('2-23-2104') --Leap year: 29
*/
If Exists (Select * From dbo.sysobjects Where id = OBJECT_ID(N'[dbo].[fnDaysInMonth]') AND xtype in (N'FN', N'IF', N'TF'))
	Drop Function [dbo].[fnDaysInMonth]
Go

Create Function [dbo].[fnDaysInMonth](
	@date datetime
) 
Returns int
as
Begin
	Declare @ReturnDays int
	Set @ReturnDays = datepart(dd,dateadd(mm,1,dateadd(dd,datepart(dd,@date)*-1,@date)))
	Return @ReturnDays
End
Go
