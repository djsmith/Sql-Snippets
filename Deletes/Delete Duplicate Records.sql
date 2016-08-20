/*
Delete duplicate records
This query deletes the duplicate record (second, third, etc.) in a database table, 
retaining the record with the lowest "Key" field value. Changing the Min() funcitons 
to Max() will delete the records with smaller "Key" field values and retain the 
record with the largest record value.
*/
if object_id('tempdb..#PhoneBook') is not null begin
	drop table #PhoneBook
end
go
if object_id('tempdb..#Keepers') is not null begin
	drop table #Keepers
end

create table #PhoneBook (
	[ID] int Identity(1, 1),
	[PhoneNumber] varchar(30),
	[FirstName] varchar(30),
	[LastName] varchar(30),
	[Company] varchar(100)
)

insert #PhoneBook select '902', 'Syed', 'Iqbal', 'SM Soft'
insert #PhoneBook select '905', 'John', 'Chatham', 'Company LLC'
insert #PhoneBook select '909', 'Joe', 'Average', 'United'
-- duplicate insert 1
insert #PhoneBook select '902', 'Syed', 'Iqbal', 'SM Soft'
insert #PhoneBook select '905', 'John', 'Chatham', 'Company LLC'
insert #PhoneBook select '909', 'Joe', 'Average', 'United'
-- duplicate insert 2
insert #PhoneBook select '902', 'Syed', 'Iqbal', 'SM Soft'
insert #PhoneBook select '905', 'John', 'Chatham', 'Company LLC'
-- insert some unique records 
insert #PhoneBook select '901', 'Peter', 'Jones', 'United'
insert #PhoneBook select '903', 'Sally', 'Ranger', 'United'

select *
from #PhoneBook

--Delete duplicate records, preserving the records with the lowest ID value
-- Note; Where Not In clauses are inefficient with large tables and may cause locks
--  see below for a better solution
--delete from #PhoneBook
--where ID not in (
--	select Min(ID)
--	from #PhoneBook
--	group by PhoneNumber
--)

create table #Keepers (
	[ID] int
)

--Fill temp table with IDs of the records to keep
-- by getting the lowest ID value
insert into #Keepers 
select Min(ID)
from #PhoneBook
group by PhoneNumber

--select * from #Keepers

--Delete the records that you don't want to keep
delete #PhoneBook
from #PhoneBook p
left outer join #Keepers k
	on p.ID = k.ID
where k.ID is null

select *
from #PhoneBook

drop table #PhoneBook
drop table #Keepers
go
