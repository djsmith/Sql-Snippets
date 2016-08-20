/*
This function returns the full name of a person by concatonating the input paramters
in different ways to account for blank or missing first name and middle initial parameters
The function take an ID number to indicate which

Examples:
Select dbo.fnFullName('John', 'X', 'Doe', 0)
Select dbo.fnFullName('John', NULL, 'Doe', 1)
Select *, dbo.fnFullName(FirstName, MI, LastName, 1) as FullName from Person

*/

if  exists (select * from information_schema.routines where specific_schema ='dbo' and specific_name = 'fnFullName' and routine_type = 'function')
	drop function [dbo].[fnFullName]
go

set ansi_nulls on
go
set quoted_identifier on
go
/**********************************************
 Author:		Dan Smith
 Create date: 8/20/2008
 Description:	Returns formatted full name using the inputed name fields. 
 Can return name either as last name first for first name first.
**********************************************/
create function dbo.fnFullName (
	-- Add the parameters for the function here
	@FirstName varchar(20),
	@MI varchar(1),
	@LastName varchar(20),
	@LastNameFirst bit
)
returns varchar(45)
as
begin
	-- Declare the return variable here
	declare @FullName varchar(110)

	-- Add the T-SQL statements to compute the return value here
	if @LastNameFirst = 0 
	begin
		-- If the middle initial is null it will be replaced with a blank string
		set @FullName = @FirstName + Replace(IsNull(' '+LTrim(@MI)+'.',''),' .','') + ' ' + @LastName
	end
	else
	begin
		set @FullName = @LastName + ', ' + @FirstName + Replace(IsNull(' '+LTrim(@MI)+'.',''),' .','') 
	end

	-- Return the result of the function
	return @FullName

end
go
