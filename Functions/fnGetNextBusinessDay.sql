SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

Create Function fnGetNextBusinessDay (@startDate datetime, @numDays int)
	Returns datetime As

Begin
	Declare @nextBusDay datetime
	Declare @weekDay tinyInt

	Set @nextBusDay = @startDate

	Declare @dayLoop int
	Set @dayLoop = 0

	While @dayLoop < @numDays
	Begin
		-- first get the raw next day
		set @nextBusDay = dateAdd(d,1,@nextBusDay)  

		-- todo; should this be sensitive to the @@DATEFIRST setting?
		SET @weekDay =((@@dateFirst+datePart(dw,@nextBusDay)-2) % 7) + 1  

		-- if it is a Saturday, just jump to Monday
		if @weekDay = 6 set @nextBusDay = dateAdd(d,2,@nextBusDay)  

		-- function recurses when @nextBusDay matches a date in the Holiday table
		select @nextBusDay = dbo.fnGetNextBusinessDay(@nextBusDay,1) 
		Where Exists (Select holidayDate From Holiday Where holidayDate=@nextBusDay)

		-- next day
		Set @dayLoop = @dayLoop + 1 
	End 

	Return @nextBusDay

End

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO
