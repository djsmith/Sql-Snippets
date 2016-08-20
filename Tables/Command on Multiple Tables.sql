/*
SQL Command on Multiple Tables
This SQL code will run the same SQL command on multiple tables by looping 
through a Cursor created from the sysobjects table.
*/

Declare @Sql varchar(2000)
Declare @TableName varchar(100)

Set @WhereClause = 'Where emp_ssn = ' + Char(39) + '111-11-1111' + Char(39)

--Create cursor to select all of the "employee" tables
Declare Tables Cursor For 
Select Table_Name From Information_Schema.Tables
Where Table_Type = 'Base Table' and Table_Name Like 'employee_%'

Open Tables
Fetch Next From Tables Into @TableName

--Loop through the cursor and execute sql statement on each table
While @@Fetch_Status = 0
Begin
	Set @Sql = 'Select * From ' + @TableName + ' ' + @WhereClause
	Print '-------- ' + @TableName + ' Table ---------'
	Exec(@Sql)
	Fetch Next From Tables Into @TableName
End

--Clean up
Close Tables
Deallocate Tables
 