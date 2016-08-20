/*
This function dynamically rounds a numeric value where the decimal portion of 
the number is rounded to the number of significant digits indicated by 
the @digits parameter.

This allows you to always show a given number of non zero values for any decimal

An alternative in the function is to use the dynamic rounding on the entire
number instead of just the decimal portion.

Examples:
select dbo.fnFixDecimal(1415.0349654,2) -->returns 1415.035000000000000000
select dbo.fnFixDecimal(1415.000349654,2) -->returns 1415.000350000000000000

Reference:
http://www.sqlservercentral.com/columnists/rfarley/afixfunctionintsql.asp
*/
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[fnFixDecimal]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[fnFixDecimal]
GO

Create Function dbo.fnFixDecimal(@num numeric(36,18), @digits int) 
	Returns numeric(36,18) as
Begin
	Return Case When @num = 0 Then 
		0
	Else 
		Round(@num,@digits-1-Floor(Log10(Abs(@num-Round(@num,0)))))

		--This formula will dynamically round the entire number instead of just the decimal portion
		--Round(@num,@digits-1-Floor(Log10(Abs(@num)))) 
	End
End
GO
 