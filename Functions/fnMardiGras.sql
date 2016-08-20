if exists (select * from Information_Schema.Routines where specific_name = 'fnMardiGras' and specific_schema = 'dbo' and routine_type = 'function') begin
	drop function [dbo].[fnMardiGras]
end
go

/*
Function returns the date of Mardi Gras based on the given year's date of Easter

Example:
declare @Year smallint set @Year = 2009
select dbo.fnEaster(@Year) as Easter, dbo.fnMardiGras(@Year) as MardiGras, DateDiff(d, dbo.fnMardiGras(@Year), dbo.fnEaster(@Year)) as DaysBetween 
--Easter                MardiGras            DaysBetween
--2009-04-12 00:00:00	2009-02-24 00:00:00	47

References:
http://www.mssqltips.com/tip.asp?tip=1537

Dependendies:
This function depends on 
	dbo.fnEaster 
	dbo.fnDaysBetween 
	
Changes:
Dan Smith (8/22/2008) The function was modified from the above article by using 
	a set based query instead of a while loop to calcualte the number of days 
	between Mardi Gras and Easter
*/
create function [dbo].[fnMardiGras]
	(@Year smallint)
returns smalldatetime
as
begin
	declare @Easter smalldatetime, @PreEaster smalldatetime, @Count tinyint, @MardiGras datetime
	set @Easter = (select dbo.fnEaster(@Year))
	set @PreEaster = DateAdd(d, -40, @Easter)
	set @MardiGras = @Easter

	set @Count = (select Count(*) from (
						select * from dbo.fnDaysBetween(@PreEaster, @Easter, default)
						where DatePart(dw,[Date]) = 1 
						union all
						select * from dbo.fnDaysBetween(@PreEaster, @Easter, default)
						) as d)

	set @MardiGras = DateAdd(d, @Count*-1, @Easter)

	return @MardiGras
end 
go
