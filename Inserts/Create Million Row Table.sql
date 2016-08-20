/*
This is an insert query that creates a million row table use
for testing various queries for performance with large record sets
by Jeff Moden
-- Create and populate a 1,000,000 row test table.
-- Column "RowNum" has a range of 1 to 1,000,000 unique numbers
-- Column "SomeInt" has a range of 1 to 50,000 non-unique numbers
-- Column "SomeChar" has a range of "AA" to "ZZ" non-unique 2 character strings
-- Column "SomeMoney has a range of 0.0000 to 99.9999 non-unique numbers
-- Column "SomeCSV" contains 'Part01,Part02,Part03,Part04,Part05,Part06,Part07,Part08,Part09,Part10' for all rows.
-- Column "SomeHex12" contains 12 random hex characters (ie, 0-9,A-F)
*/
SELECT TOP 1000000
	RowNum    = IDENTITY(INT,1,1),
	SomeInt   = ABS(CHECKSUM(NEWID()))%50000+1,
	SomeChar  = CHAR(ABS(CHECKSUM(NEWID()))%26+65) + CHAR(ABS(CHECKSUM(NEWID()))%26+65),
	SomeCSV   = CAST('Part01,Part02,Part03,Part04,Part05,Part06,Part07,Part08,Part09,Part10' AS VARCHAR(80)),
	SomeMoney = CAST(ABS(CHECKSUM(NEWID()))%10000 /100.0 AS MONEY),
	SomeHex12 = RIGHT(NEWID(),12)
INTO dbo.BigTestTable
FROM Master.dbo.SysColumns t1
	CROSS JOIN Master.dbo.SysColumns t2
 
--===== A table is not properly formed unless a Primary Key has been assigned
ALTER TABLE dbo.BigTestTable
	ADD PRIMARY KEY CLUSTERED (RowNum)
 
--===== Create and index for the lookups we expect
CREATE INDEX IX_BigTestTable_SomeInt_SomeChar
	ON dbo.BigTestTable (SomeInt,SomeChar)
GO

IF OBJECT_ID('dbo.BigTestTable',N'U') IS NOT NULL BEGIN
	DROP TABLE dbo.BigTestTable
END
GO

/*
Here is another way to fill in data for a test table where you want
to derive values for some fields based on an identity like value.
The inner-inner query gets a set of rows by using a cross join with 
the syscolumn table on itself, which is limited to 1000000 rows (change 
as needed to give a different number of rows).  Then the inner query
sets a row number using the inner-inner query's fields.
The Select Into query can then use the RowNumber field in calculations
when creating new rows in the BigTestTable
*/

SELECT 
	RowNum    = IDENTITY(INT,1,1),
	SomeInt = r.RowNumber,
	SomeInt10 = r.RowNumber % 10,
	SomeInt100 = r.RowNumber % 100
INTO dbo.BigTestTable
FROM (
	SELECT ROW_NUMBER() OVER(ORDER BY x.aid, x.bid) AS RowNumber 
	FROM (
		SELECT TOP 1000000 a.id AS aid, b.id AS bid
		FROM master.dbo.syscolumns a
		CROSS JOIN master.dbo.syscolumns b
	) x
) r
GO
