 /*
SQL Server 2005 and previous versions do not support passing a table variable
to a stored procedure. In one of my previous articles, I had presented a way
to pass a table to a stored procedure. There had been a large number of
excellent comments in the discussion forum on this subject and a few
alternate methods were discussed.

This code introduces the new feature added to SQL Server 2008, which
supports passing a TABLE to a stored procedure or function.

Passing a Table to a Stored Procedure by Jacob Sebastian
http://www.sqlservercentral.com/articles/News/3182/
*/


/*
Before we create a Function or Stored Procedure that accepts a TABLE variable,
we need to define a User Defined TABLE Type. SQL Server 2008 introduced a new
User defined TABLE type. A TABLE type represents the structure of a table that
can be passed to a stored procedure or function.

So the first step is to create a User Defined TABLE type. The following TSQL
code creates a User defined TABLE type named "ItemInfo".
*/

CREATE TYPE ItemInfo AS TABLE (
	ItemNumber VARCHAR(50),
	Qty INT
)
GO

/* After creating the Table type, insert a few records into an instance of it */

DECLARE @items AS ItemInfo

INSERT INTO @items (ItemNumber, Qty)
VALUES
	('11000', 100),
	('22000', 200),
	('33000', 300)

SELECT * FROM @items
GO

/*
Now create some procs that uses the ItemInfo table type 
Note the @Items parameter must be marked as readonly 
*/
CREATE PROCEDURE pTableParamList (
	@Items ItemInfo readonly
) AS
	SELECT *
	FROM @Items
GO

CREATE PROCEDURE pTableParamSum (
	@Items ItemInfo readonly
) AS
	SELECT SUM(Qty) FROM @Items
GO

/* Create a table type and fill with some data */
DECLARE @i AS ItemInfo
INSERT INTO @i(ItemNumber, Qty)
VALUES
	('11100', 101),
	('22200', 202),
	('33300', 303)

EXEC pTableParamList @i
EXEC pTableParamSum @i
GO


/***** Clean Up ********/
-- Must drop the procs before the table type because of the dependency
IF OBJECT_ID('dbo.pTableParamList') IS NOT NULL BEGIN
	DROP PROC dbo.pTableParamList
END
IF OBJECT_ID('dbo.pTableParamSum') IS NOT NULL BEGIN
	DROP PROC dbo.pTableParamSum
END
IF  EXISTS (SELECT * FROM sys.types st JOIN sys.schemas ss ON st.SCHEMA_ID = ss.SCHEMA_ID WHERE st.name = N'ItemInfo' AND ss.name = N'dbo') BEGIN
	DROP TYPE [dbo].[ItemInfo]
END
GO


