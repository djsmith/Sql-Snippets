/************************************************************************
This script is based on the "SQL Server 2005 Paging – The Holy Grail" 
article by Robert Cary, which describes various ways to select a subset
of a table (i.e., a page) using new features of SQL Server 2005.  

In the discussion forum for the article there were several
comments and additional test scripts that presented alternative queryies.

http://www.sqlservercentral.com/articles/T-SQL/66030/
http://www.sqlservercentral.com/Forums/Topic672980-329-1.aspx
************************************************************************/

SET STATISTICS TIME OFF
SET STATISTICS IO OFF
    
IF OBJECT_ID('dbo.BigTestTable', 'U') IS NOT NULL BEGIN
	-- DROP TABLE dbo.BigTestTable
	GOTO SkipCreateTable
END

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


SkipCreateTable:
GO

--===== Define the starting row and page size
DECLARE @StartRow INT ; SET @StartRow = 900000
DECLARE @PageSize INT ; SET @PageSize = 50
 

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

PRINT ''
PRINT ''
PRINT '--============================================================================='
PRINT '--      The "Holy Grail" method'
PRINT '--============================================================================='
 

SET STATISTICS IO ON
SET STATISTICS TIME ON
 
;WITH
cteCols AS (
	SELECT SomeInt, SomeChar,
		ROW_NUMBER() OVER(ORDER BY SomeInt, SomeChar) AS Seq,
		ROW_NUMBER() OVER(ORDER BY SomeInt DESC, SomeChar DESC) AS TotRows
	FROM dbo.BigTestTable
)
SELECT Seq, SomeInt, SomeChar, TotRows + Seq - 1 AS TotRows
FROM cteCols
WHERE Seq BETWEEN @StartRow AND @StartRow + @PageSize - 1
ORDER BY Seq
 

SET STATISTICS TIME OFF
SET STATISTICS IO OFF

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS


PRINT ''
PRINT ''
PRINT '--============================================================================='
PRINT '--      The "No RBAR/No Join" method'
PRINT '--============================================================================='
 

SET STATISTICS IO ON
SET STATISTICS TIME ON
 
--===== The "No RBAR/No Join" method
;WITH
cteCols AS (
	SELECT NULL AS SomeInt, NULL AS SomeChar, 0 AS Seq, Rows AS TotRows
	FROM sys.Partitions
	WHERE Object_ID = OBJECT_ID('dbo.BigTestTable')
		AND Index_ID = 1
	UNION ALL --------------------------------------------------------------------
	SELECT SomeInt, SomeChar,
		ROW_NUMBER() OVER(ORDER BY SomeInt, SomeChar) AS Seq,
		NULL AS TotRows
	FROM dbo.BigTestTable
)
SELECT Seq, SomeInt, SomeChar, TotRows
FROM cteCols
WHERE Seq BETWEEN @StartRow AND @StartRow + @PageSize - 1
	OR Seq = 0
ORDER BY Seq
 

SET STATISTICS TIME OFF
SET STATISTICS IO OFF

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS


PRINT ''
PRINT ''
PRINT '--============================================================================='
PRINT '--      A different No Join method'
PRINT '--============================================================================='
 

SET STATISTICS IO ON
SET STATISTICS TIME ON
 
;WITH
cteCols AS (
	SELECT SomeInt, SomeChar,
		ROW_NUMBER() OVER(ORDER BY SomeInt, SomeChar) AS Seq,
		NULL AS TotRows
	FROM dbo.BigTestTable
)
SELECT Seq, SomeInt, SomeChar, (
	SELECT Rows
	FROM sys.Partitions
	WHERE Object_ID = OBJECT_ID('dbo.BigTestTable')
		AND Index_ID = 1) AS TotRows
FROM cteCols
WHERE Seq BETWEEN @StartRow AND @StartRow + @PageSize - 1
	OR Seq = 0
ORDER BY Seq
 

SET STATISTICS TIME OFF
SET STATISTICS IO OFF
 
DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS


PRINT ''
PRINT ''
PRINT '--============================================================================='
PRINT '--      Peso''s Embedded "2 Bite" method'
PRINT '--============================================================================='


SET STATISTICS IO ON
SET STATISTICS TIME ON
 
;WITH
cteCols AS (
	SELECT SomeInt, SomeChar,
        ROW_NUMBER() OVER(ORDER BY SomeInt, SomeChar) AS Seq,
        NULL AS TotRows
	FROM dbo.BigTestTable
)
SELECT Seq, SomeInt, SomeChar, (SELECT COUNT(*) FROM dbo.BigTestTable) AS TotRows
FROM cteCols
WHERE Seq BETWEEN @StartRow AND @StartRow + @PageSize - 1
	OR Seq = 0
ORDER BY Seq
 

SET STATISTICS TIME OFF
SET STATISTICS IO OFF

DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS

