 /*
Returns 1 (True) if the given date is in a leap year,
otherwise returns 0 (false)

Examples:
select dbo.fnIsLeapYear('1-2-2004')
select dbo.fnIsLeapYear('1-2-2005')
select dbo.fnIsLeapYear('1-2-2100')
select dbo.fnIsLeapYear('1-2-2104')
select dbo.fnIsLeapYear('1-2-2400')

*/
If Exists (Select * From dbo.sysobjects Where id = OBJECT_ID(N'[dbo].[fnIsLeapYear]') AND xtype in (N'FN', N'IF', N'TF'))
	Drop Function [dbo].[fnIsLeapYear]
Go

-- User defined function
Create Function dbo.fnIsLeapYear(
	@date datetime
)
Returns bit
as
Begin
	Declare @Year int
	Set @Year = DatePart(yy,@date)
	If (@Year % 400 = 0)
		Return 1
	Else If (@Year % 100 = 0) 
		Return 0
	Else If (@Year % 4 = 0)
		Return 1

	Return 0
End
GO

