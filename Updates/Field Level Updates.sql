 /*
Demonstration of limiting the changes in an Update statement to only change
field values where the original and modified version of the value are different.
This can deal with multi-user data change collision problems by not overwriting 
an existing field value made by another concurrent user if this user has not 
changed the value themselves. 

The Update statement uses case functions to decide if the field should
be updated with the modified variable or use the table record's current
value.

Note: If two users both change the field value then the last one in wins.

Dan Smith 8/25/2008
*/

use [AdventureWorks]

--Wrap the demonstration in a transaction so changes can be rolled back
-- and automatically rollback the transaction if there is a failure
begin transaction
set xact_abort on

--Setup temp table to collect results of queries
if exists(select * from tempdb.sys.objects where [object_id] = Object_ID('tempdb..#Results')) begin
	drop table #Results
end

create table #Results(
	[Version] nvarchar(20),
	[ContactID] int,
	[Title] nvarchar(8) null,
	[FirstName] nvarchar(50) not null,
	[MiddleName] nvarchar(50) null,
	[LastName] nvarchar(50) not null,
	[Suffix] nvarchar(10) null,
)

--Original vars to hold original values of fields; use a '_' to prefix the var name
declare @_ContactID int,
	@_Title varchar(8),
	@_FirstName varchar(50),
	@_MiddleName varchar(50),
	@_LastName varchar(50),
	@_Suffix varchar(10)

--Modifiable vars to hold field values. 
declare @Title varchar(8),
	@FirstName varchar(50),
	@MiddleName varchar(50),
	@LastName varchar(50),
	@Suffix varchar(10)
	
set @_ContactID = 1

--Select values into Original vars; these vars must not be changed.
select @_Title=[Title], 
	@_FirstName=[FirstName], 
	@_MiddleName=[MiddleName], 
	@_LastName=[LastName], 
	@_Suffix=[Suffix]
from [Person].[Contact]
where [ContactID] = @_ContactID

--Add the Original vars to the Results table
insert into #Results 
select 'Original' as Version, @_ContactID as ContactID, @_Title as Title, @_FirstName as FirstName, @_MiddleName as MiddleName, @_LastName as LastName, @_Suffix as Suffix

--Set the Modifiable vars to values from Original vars
select @Title=@_Title, 
	@FirstName=@_FirstName, 
	@MiddleName=@_MiddleName, 
	@LastName=@_LastName, 
	@Suffix=@_Suffix

--Simulate a multi-user data change collision problem by changing the database record 
update [Person].[Contact] set
	[FirstName] = 'Peter',
	[MiddleName] = 'Y',
	[Title] = null
--Output clause adds the modified record to the Results table
output 'Second User' as Version, inserted.[ContactID], inserted.[Title], inserted.[FirstName], inserted.[MiddleName], inserted.[LastName], inserted.[Suffix]
into #Results
where ContactID = @_ContactID

--Change values of several Modifiable vars
set @MiddleName = 'X' --This will overwrite the change from the second user
set @LastName = 'Jones' 
set @Suffix = 'Jr.'

--Add the Modifiable vars after changes to the Results table
insert into #Results
select 'Modified' as Version, @_ContactID as ContactID, @Title as Title, @FirstName as FirstName, @MiddleName as MiddleName, @LastName as LastName, @Suffix as Suffix

--This Update statement uses Case functions to control what value to use when updating a field.
--When the Modifiable var equals the Original var (or both are null);
--  then use the current table record field
--  else use the Modifiable var.
update [Person].[Contact] set
	[Title] = case when (@_Title=@Title) or ((@_Title is null) and (@Title is null)) 
		then [Title] 
		else @Title end,
	[FirstName] = case when (@_FirstName=@FirstName) or ((@_FirstName is null) and (@FirstName is null)) 
		then [FirstName] 
		else @FirstName end,
	[MiddleName] = case when (@_MiddleName=@MiddleName) or ((@_MiddleName is null) and (@MiddleName is null)) 
		then [MiddleName] 
		else @MiddleName end,
	[LastName] = case when (@_LastName=@LastName) or ((@_LastName is null) and (@LastName is null)) 
		then [LastName] 
		else @LastName end,
	[Suffix] = case when (@_Suffix=@Suffix) or ((@_Suffix is null) and (@Suffix is null)) 
		then [Suffix] 
		else @Suffix end
--Output clause adds the modified record to the Results table
output 'Final' as Version, inserted.[ContactID], inserted.[Title], inserted.[FirstName], inserted.[MiddleName], inserted.[LastName], inserted.[Suffix]
into #Results
where [ContactID]=@_ContactID

--Show the results from all of the queries
select * from #Results

drop table #Results

--Undo the changes
rollback transaction
