---------------------------------------
-- create sample tables and data
---------------------------------------
/*
create table Person (PersonID int, FirstName varchar(25), LastName varchar(25))
insert Person (PersonID, FirstName, LastName) values (1, 'Sue', 'Jones')
insert Person (PersonID, FirstName, LastName) values (2, 'Joe', 'Smith')
insert Person (PersonID, FirstName, LastName) values (3, 'Peter', 'Washington')

create table Phone (PersonID int, PhoneNumber varchar(25))
insert Phone (PersonID, PhoneNumber) values (1, '123-555-0203')
insert Phone (PersonID, PhoneNumber) values (1, '098-555-2382')
insert Phone (PersonID, PhoneNumber) values (2, '123-555-0202')
insert Phone (PersonID, PhoneNumber) values (2, '098-555-2382')
insert Phone (PersonID, PhoneNumber) values (2, '230-555-3298')
insert Phone (PersonID, PhoneNumber) values (2, '234-555-0982')

create table Email (PersonID int, EmailAddress varchar(50))
insert Email (PersonID, EmailAddress) values (1, 'sjones@nowhere.com')
insert Email (PersonID, EmailAddress) values (1, 'sj@somewhere.com')
insert Email (PersonID, EmailAddress) values (1, 'SueJones@AspenState.com')
insert Email (PersonID, EmailAddress) values (2, 'jsmith@nowhere.com')
insert Email (PersonID, EmailAddress) values (2, 'js@home.com')
*/
---------------------------------------
-- determine number of records per person
---------------------------------------

declare @Records table (
	PersonID int,
	NumRecords int
)

insert @Records (PersonID, NumRecords)
select PersonID, 1
from Person

update a
	set a.NumRecords = b.NumRecords
from @Records a
inner join (
		select PersonID,
		count(*) as NumRecords
		from Email
		group by PersonID
	) as b
	on a.PersonID = b.PersonID
where a.NumRecords < b.NumRecords

update a
	set a.NumRecords = b.NumRecords
from @Records a
inner join (
		select PersonID,
		count(*) as NumRecords
		from Phone
		group by PersonID
	) as b
	on a.PersonID = b.PersonID
where a.NumRecords < b.NumRecords

--select * from @Records

---------------------------------------
-- initial population of results table, with sequencing
---------------------------------------

declare @Results table (
	PersonID int,
	SeqID int,
	LastName varchar(25),
	FirstName varchar(25),
	EmailAddress varchar(50),
	PhoneNumber varchar(25)
)

declare @LoopCheck int, @LoopCount int

select @LoopCheck = 1, @LoopCount = 1

while @LoopCheck > 0
begin
	insert @Results (PersonID, SeqID, LastName, FirstName)
	select a.PersonID, @LoopCount, a.LastName, a.FirstName
	from Person a
	inner join @Records b
		on a.PersonID = b.PersonID
	where b.NumRecords >= @LoopCount
	
	set @LoopCheck = @@rowcount
	set @LoopCount = @LoopCount + 1
end

--select * from @Results order by PersonID, SeqID

---------------------------------------
-- update results table with email addresses
---------------------------------------

declare @Email table (
	IdenID int identity(1,1),
	PersonID int,
	SeqID int,
	EmailAddress varchar(50)
)

insert @Email (PersonID, SeqID, EmailAddress)
select PersonID, 0, EmailAddress
from Email

update a
	set a.SeqID = a.IdenID - (select count(*) from @Email b where b.PersonID < a.PersonID)
from @Email a

update a set a.EmailAddress = b.EmailAddress
from @Results a
inner join @Email b
	on a.PersonID = b.PersonID
		and a.SeqID = b.SeqID

--select * from @Email
--select * from @Results order by PersonID, SeqID

---------------------------------------
-- update results table with phone addresses
---------------------------------------

declare @Phone table
(
	IdenID int identity(1,1),
	PersonID int,
	SeqID int,
	PhoneNumber varchar(50)
)

insert @Phone (PersonID, SeqID, PhoneNumber)
select PersonID, 0, PhoneNumber
from Phone

update a
	set a.SeqID = a.IdenID - (select count(*) from @Phone b where b.PersonID < a.PersonID)
from @Phone a

update a
	set a.PhoneNumber = b.PhoneNumber
from @Results a
inner join @Phone b
	on a.PersonID = b.PersonID
		and a.SeqID = b.SeqID

--select * from @Phone
--select * from @Results order by PersonID, SeqID

---------------------------------------
-- return final results
---------------------------------------

-- select LastName, FirstName, EmailAddress, PhoneNumber
select * 
from @Results
order by LastName, FirstName, IsNull(EmailAddress,'zzzzzzzzzzzzz'), IsNull(PhoneNumber,'zzzzzzzzzzzzz')
