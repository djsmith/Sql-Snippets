
/*
Calculates the age from the birth date compared to the today's date parameter

Usage:
	Select dbo.fnCalcAge('3/13/1967', '1/13/2007')
	Select dbo.fnCalcAge('3/13/1967', GetDate())
*/

IF  EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[fnCalcAge]') AND xtype in (N'FN', N'IF', N'TF'))
	DROP FUNCTION [dbo].[fnCalcAge]
Go

Create Function dbo.fnCalcAge(@birthDate datetime, @todaysDate datetime)
	Returns tinyint
AS

Begin

	Declare @Birthyear int, @CurrentYear int, @Age tinyint
	Set @Birthyear = datepart(yy, @Birthdate)
	Set @CurrentYear = datepart(yy, @TodaysDate)

	--Check for leap year birthdates
	If datepart(m, @Birthdate) = 2 AND datepart(d, @Birthdate) = 29
	Begin
		If ('2/28/' + convert(varchar(4), @CurrentYear)) <= @TodaysDate
		Begin
			Set @Age = (Select @CurrentYear - @Birthyear)
		End
		Else
		Begin
			Set @Age = (Select (@CurrentYear -1) - @Birthyear)
		End
	End
	Else
	Begin
		If (convert(varchar(2), datepart(m, @Birthdate)) + '/' + convert(varchar(2), datepart(d, @Birthdate)) + '/' + convert(varchar(4), @CurrentYear)) <= @TodaysDate
		Begin
			Set @Age = (Select  @CurrentYear - @Birthyear)
		End
		Else
		Begin
			Set @Age = (Select(@CurrentYear -1) - @Birthyear)
		End
	End
	
	Return @Age
End
Go
