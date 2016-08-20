if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[fnRange]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[fnRange]
GO

/*
This function will return a table of integers ranging between two numbers.
The function works by doing a cross join between sub-queries containing the numbers 
between 0-9, 10-90, etc. These sub-queries are then sumed together to build the list
of integers. The sub-queries also filter on the @last parameter so the cross join 
doesn't create more numbers than necessary.

The table from this function can be joined to other tables to generate record sets 
to be inserted into other tables. Using this process is faster than using individual
insert statements or a cursor when inserting more than 100 records.

Example: This query finds all of the values that are not being used by the 
employee_main.keyid identity field; i.e. out of sequence identity values

Declare @MaxId int
Select @MaxId = Max(keyid) From employee_main
Select * From [fnRange](1, @MaxId) as r
Left Outer Join employee_main m
	On r.value=m.keyid
Where m.keyid is null
*/
CREATE FUNCTION dbo.fnRange (
	@first int , --The lowest value in the range. 
	@last int --The highest value in the range.
)  
RETURNS @values TABLE ( value int primary key ) AS  

BEGIN
INSERT INTO @values(value)
select 
	units.value
 +	tens.value 
 +	hundreds.value 
 +	Thousands.value 
 +	TenThousands.value 
 +	CThousands.value 
 +	Millions.value 
AS list
from(
	select 0 as value
	union all	select 1 as value where 1 <= @last
	union all	select 2 as value where 2 <= @last
	union all	select 3 as value where 3 <= @last
	union all	select 4 as value where 4 <= @last
	union all	select 5 as value where 5 <= @last
	union all	select 6 as value where 6 <= @last
	union all	select 7 as value where 7 <= @last
	union all	select 8 as value where 8 <= @last
	union all	select 9 as value where 9 <= @last
) AS Units ,
(
	select 0 as value
	union all	select 10 as value where 10 <= @last
	union all	select 20 as value where 20 <= @last
	union all	select 30 as value where 30<= @last
	union all	select 40 as value where 40 <= @last
	union all	select 50 as value where 50 <= @last
	union all	select 60 as value where 60 <= @last
	union all	select 70 as value where 70 <= @last
	union all	select 80 as value where 80 <= @last
	union all	select 90 as value where 90 <= @last
) AS Tens,
(
	select 0 as value
	union all	select 100 as value where 100 <= @last
	union all	select 200 as value where 200 <= @last
	union all	select 300 as value where 300 <= @last
	union all	select 400 as value where 400 <= @last
	union all	select 500 as value where 500 <= @last
	union all	select 600 as value where 600 <= @last
	union all	select 700 as value where 700 <= @last
	union all	select 800 as value where 800 <= @last
	union all	select 900 as value where 900 <= @last
) AS Hundreds,
(
	select 0 as value
	union all	select 1000 as value where 1000 <= @last
	union all	select 2000 as value where 2000 <= @last
	union all	select 3000 as value where 3000 <= @last
	union all	select 4000 as value where 4000 <= @last
	union all	select 5000 as value where 5000 <= @last
	union all	select 6000 as value where 6000 <= @last
	union all	select 7000 as value where 7000 <= @last
	union all	select 8000 as value where 8000 <= @last
	union all	select 9000 as value where 9000 <= @last
) AS Thousands,
(
	select 0 as value
	union all	select 10000 as value where 10000 <= @last
	union all	select 20000 as value where 20000 <= @last
	union all	select 30000 as value where 30000 <= @last
	union all	select 40000 as value where 40000 <= @last
	union all	select 50000 as value where 50000 <= @last
	union all	select 60000 as value where 60000 <= @last
	union all	select 70000 as value where 70000 <= @last
	union all	select 80000 as value where 80000 <= @last
	union all	select 90000 as value where 90000 <= @last
) AS TenThousands,
(
	select 0 as value
	union all	select 100000 as value where 100000 <= @last
	union all	select 200000 as value where 200000 <= @last
	union all	select 300000 as value where 300000 <= @last
	union all	select 400000 as value where 400000 <= @last
	union all	select 500000 as value where 500000 <= @last
	union all	select 600000 as value where 600000 <= @last
	union all	select 700000 as value where 700000 <= @last
	union all	select 800000 as value where 800000 <= @last
	union all	select 900000 as value where 900000 <= @last
) AS CThousands,
(
	select 0 as value
	union all	select 1000000 as value where 1000000 <= @last
	union all	select 2000000 as value where 2000000 <= @last
	union all	select 3000000 as value where 3000000 <= @last
	union all	select 4000000 as value where 4000000 <= @last
	union all	select 5000000 as value where 5000000 <= @last
	union all	select 6000000 as value where 6000000 <= @last
	union all	select 7000000 as value where 7000000 <= @last
	union all	select 8000000 as value where 8000000 <= @last
	union all	select 9000000 as value where 9000000 <= @last
) AS Millions
where 
	units.value
 +	tens.value 
 +	hundreds.value 
 +	Thousands.value 
 +	TenThousands.value 
 +	CThousands.value 
 +	Millions.value 

between @first and @last

RETURN
END
GO
 