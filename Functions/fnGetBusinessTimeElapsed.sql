if exists (select * from Information_Schema.Routines where specific_name = 'fnGetBusinessTimeElapsed' and specific_schema = 'dbo' and routine_type = 'function') begin
	drop function [dbo].[fnGetBusinessTimeElapsed]
end
go

/*
Function returns the number of Days, Hours, Minutes or Seconds between
two dates based on a 5 day a week, 8 hours a day work schedule

Parameters:
	@startDate any valid date
	@endDate any valid date
	@timeInterval varchar(10); (D)ays, (H)ours, (M)inutes, (S)econds
	
Reference:
	http://www.sqlservercentral.com/scripts/DateDiff/63347/
	
Examples:
	select dbo.fnGetBusinessTimeElapsed('1/1/2000', '1/4/2000', 's'), dbo.fnGetBusinessTimeElapsed('1/1/2000 9:00am', '1/4/2000 3:00pm', 's'), dbo.fnGetBusinessTimeElapsed('1/1/2000 9:02am', '1/4/2000 4:01pm', 's')
*/
create function [dbo].[fnGetBusinessTimeElapsed] (
	@startDate datetime,
	@endDate datetime,
	@timeInterval varchar(10)
)
returns integer as
begin
	declare 
		@AdjStart datetime,
		@Days int,
		@TimeElapsed varchar(50),
		@Hours int,
		@Minutes int,
		@Seconds int,
		@AdjStartTime datetime
		
	select @AdjStartTime = DateAdd(hh, Floor(DateDiff(hh, @startDate, @endDate)/24)*24, @startDate) 

	select @AdjStart = DateAdd(dd, (Floor(DateDiff(dd, @startDate, @endDate)/7)*7), @startDate)
	select @Days = (
		Floor(DateDiff(dd, @startDate, @endDate)/7)*5) + (DateDiff(dd, @AdjStart, @endDate) - 2 +
		case when DatePart(dw, @AdjStart) < Abs(-8 + DateDiff(dd, @AdjStart, @endDate)) + 1 
			then 1 
			else 0 end
		+
		case when DatePart(dw, @AdjStart) > 1 and DatePart(dw, @AdjStart) < Abs(-8 + DateDiff(dd, @AdjStart, @endDate))
			then 1 
			else 0 end
	)

	/*
	--Use this to deincrement for holidays if necessary
	select @Days = @Days 
	case when '01/01/2001' between @startDate and @endDate and DatePart(dw, '01/01/2001') between 2 and 6 then 1 else 0 end 
	case when '07/04/2001' between @startDate and @endDate and DatePart(dw, '07/04/2001') between 2 and 6 then 1 else 0 end 
	--minus additional days in the calendar year by listing each 
	*/

	select @Hours = (@Days * 8) 
	+ case 
	when DatePart(hh, @endDate-@AdjStartTime) between 0 and 8 then DatePart(hh, @endDate-@AdjStartTime)
	when DatePart(hh, @endDate-@AdjStartTime) between 9 and 16 then DatePart(hh, @endDate-@AdjStartTime) - 8
	when DatePart(hh, @endDate-@AdjStartTime) between 16 and 24 then DatePart(hh, @endDate-@AdjStartTime) - 16
	end

	select @Minutes = @Hours * 60 + DatePart(n, @endDate-@AdjStartTime)
	select @Seconds = @Minutes * 60 + DatePart(s, @endDate-@AdjStartTime)

	return case
		when Left(Upper(@timeInterval),1) = 'D' then @Days
		when Left(Upper(@timeInterval),1) = 'H' then @Hours
		when Left(Upper(@timeInterval),1) = 'M' then @Minutes
		when Left(Upper(@timeInterval),1) = 'S' then @Seconds
	end

end
go

 