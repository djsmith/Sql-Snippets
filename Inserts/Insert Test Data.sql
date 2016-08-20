/*
This query inserts random data into a [TestData] table.  This includes
an AccountID integer field, an Amount money field and a Date DateTime field.
*/

SET NOCOUNT ON
IF OBJECT_ID('dbo.TestData','U') IS NOT NULL
	DROP TABLE dbo.TestData
GO
-- Create the test table
CREATE TABLE dbo.TestData (
	ID        INT      IDENTITY (1,1) NOT NULL,
	AccountID INT      NULL,
	Amount    MONEY    NULL,
	[DATE]    DATETIME NULL,
)

-- Add the primary key
ALTER TABLE dbo.TestData
	ADD PRIMARY KEY NONCLUSTERED (ID)  --nonclustered to resolve "Merry-go-Round"


-- Build the table 100 rows at a time to "mix things up"
DECLARE @Counter INT 
SET @Counter = 0

WHILE @Counter < 1000000
BEGIN
	-- Add 100 rows to the test table
	INSERT INTO dbo.TestData
		(AccountID, Amount, DATE)
	SELECT TOP 100
		AccountID = ABS(CHECKSUM(NEWID()))%50000+1,
		Amount    = CAST(CHECKSUM(NEWID())%10000 /100.0 AS MONEY),
		DATE      = CAST(RAND(CHECKSUM(NEWID()))*3653.0+36524.0 AS DATETIME)
	FROM Master.dbo.SysColumns t1
	CROSS JOIN Master.dbo.SysColumns t2 

	-- Increment the counter
	SET @Counter = @Counter + 100
END
GO

SELECT * FROM dbo.TestData

IF OBJECT_ID('dbo.TestData','U') IS NOT NULL
	DROP TABLE dbo.TestData
