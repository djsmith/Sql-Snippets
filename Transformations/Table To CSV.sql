/*
Join Table Rows to CSV List; 
	Joins the values in a table into a comma seperated list of values
*/
Declare @States varchar(8000)
Select @States = IsNull(@States + '", "', '"') + Code From CT_State Order By Code
Select @States As StateString 
