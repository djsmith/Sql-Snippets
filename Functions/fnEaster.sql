if exists (select * from Information_Schema.Routines where specific_name = 'fnEaster' and specific_schema = 'dbo' and routine_type = 'function') begin
	drop function [dbo].[fnEaster]
end
go

/*
Function uses formula based on the vernal equinox to get Easter Sunday for a given year.

Example:
declare @Year smallint set @Year = 2009
select dbo.fnEaster(@Year) as Easter, DateAdd(d,-2,dbo.fnEaster(@Year)) as GoodFriday, DateAdd(d,-47,dbo.fnEaster(@Year)) as MardiGras
--Easter                GoodFriday           MardiGras
--2009-04-12 00:00:00	2009-04-10 00:00:00	2009-02-24 00:00:00

Reference:
http://www.mssqltips.com/tip.asp?tip=1537
http://aa.usno.navy.mil/faq/docs/easter.php

*/
create function [dbo].[fnEaster]
	(@Year smallint)
returns smalldatetime
as
begin
	--Formula based on http://aa.usno.navy.mil/faq/docs/easter.php
	declare
		@c int, 
		@n int, 
		@k int, 
		@i int, 
		@j int, 
		@l int, 
		@m int, 
		@d int, 
		@Easter datetime

	set @c = (@Year / 100)
	set @n = @Year - 19 * (@Year / 19)
	set @k = (@c - 17) / 25
	set @i = @c - @c / 4 - ( @c - @k) / 3 + 19 * @n + 15
	set @i = @i - 30 * ( @i / 30 )
	set @i = @i - (@i / 28) * (1 - (@i / 28) * (29 / (@i + 1)) * ((21 - @n) / 11))
	set @j = @Year + @Year / 4 + @i + 2 - @c + @c / 4
	set @j = @j - 7 * (@j / 7)
	set @l = @i - @j
	set @m = 3 + (@l + 40) / 44
	set @d = @l + 28 - 31 * ( @m / 4 )

	-- Create a date of Jan 1st of the given year, then adjust according to the calculated month and day
	set @Easter = DateAdd(d, @d-1, DateAdd(m, @m-1, Convert(smalldatetime, Convert(char(4), @Year)+'0101')))
	
	return @Easter
end 
go


