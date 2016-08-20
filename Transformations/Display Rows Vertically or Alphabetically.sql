/*
Script creates two procedures to display table fields in in alphabetical order

proc AzDisplay will piviot a table record into a verticle table to two columns and sort the 
table field names alphabetically. Example:
	exec AzDisplay 'HumanResources.Department', 'Id = 1'
 - the first parameter is @TableName
 - second parameter is a where clause to select one or more records from the table
 - thrid parameter is a second where clause to select additional records from the table
 
proc AzSelect will display a table in normal orientation, but order the fields alphabetically
	exec AzDisplay 'HumanResources.Department', 'Id = 1'
 - the first parameter is @TableName
 - second parameter is a where clause to select one or more records from the table
	
Written by By William Talada, 2010/01/21 
http://www.sqlservercentral.com/scripts/select/69177/

Modified by Dan Smith, 2010/01/22; 
 - Modified use of @TableName parameter, passing it to OBJECT_ID() function so the 
   queries work properly with table in schemas other than dbo.
 - Changed @TableName parameters to use the sysname type.
 - Removed image fields from the AzDisplay queries because they cannot be converted to 
   varchar(max) columns and included in the results.
   
*/

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[AzDisplay]') AND Type IN (N'P', N'PC'))
DROP PROCEDURE [dbo].[AzDisplay]
GO

CREATE PROCEDURE [dbo].[AzDisplay]
	@TableName sysname = NULL,
	@WhereClause1 VARCHAR(1000) = NULL,
	@WhereClause2 VARCHAR(1000) = NULL
AS
-- written by Bill Talada

SET NOCOUNT ON

IF @TableName IS NULL
BEGIN
	PRINT 'Samples on selecting all columns alphabetically (one row):'
	PRINT '  exec AzDisplay Customer,''CustomerKey = 123'''
	RETURN 0
END

DECLARE
	@col sysname,
	@list VARCHAR(4000),
	@sql VARCHAR(8000),
	@crlf VARCHAR(2),
	@tab VARCHAR(1)

SET @crlf=CHAR(13)+CHAR(10)
SET @tab=CHAR(9)

SET @col=''
SET @list=''

CREATE TABLE #colvals( col VARCHAR(128), val VARCHAR(MAX))
CREATE TABLE #colvals2( col VARCHAR(128), val VARCHAR(MAX))

SELECT
	@col = MIN(c.name)
FROM
	sys.columns c
JOIN
	sys.tables t
	ON c.object_id=t.object_id
JOIN
	sys.types y
	ON c.system_type_id = y.system_type_id
WHERE
	t.object_id = OBJECT_ID(@TableName, N'U')
	AND (y.name != 'image')

WHILE @col IS NOT NULL
BEGIN
	SET @sql = 'insert into #colvals select '''+@col+''',cast(' + @col + ' as varchar(max)) from '+@tablename+ ' where '+@whereclause1
	EXEC( @sql)

	SELECT
		@col = MIN(c.name)
	FROM
		sys.columns c
	JOIN
		sys.tables t
		ON c.object_id=t.object_id
JOIN
	sys.types y
	ON c.system_type_id = y.system_type_id
WHERE
	t.object_id = OBJECT_ID(@TableName, N'U')
	AND (y.name != 'image')
	AND c.name > @col
END

----------------
IF @whereclause2 IS NOT NULL
BEGIN
	SELECT
		@col = MIN(c.name)
	FROM
		sys.columns c
	JOIN
		sys.tables t
		ON c.object_id=t.object_id
	JOIN
		sys.types y
		ON c.system_type_id = y.system_type_id
	WHERE
		t.object_id = OBJECT_ID(@TableName, N'U')
		AND (y.name != 'image')

	WHILE @col IS NOT NULL
	BEGIN
		SET @sql = 'insert into #colvals2 select '''+@col+''',cast(' + @col + ' as varchar(max)) from '+@tablename+ ' where '+@whereclause2
		EXEC( @sql)

		SELECT
			@col = MIN(c.name)
		FROM
			sys.columns c
		JOIN
			sys.tables t
			ON c.object_id=t.object_id
		JOIN
			sys.types y
			ON c.system_type_id = y.system_type_id
		WHERE
			t.object_id = OBJECT_ID(@TableName, N'U')
			AND (y.name != 'image')
			AND c.name > @col
	END
END
----------------

IF @whereclause2 IS NULL
BEGIN
	SELECT
		col,
		ISNULL(val,'<null>') AS val 
	FROM 
		#colvals
END
ELSE
BEGIN
	SELECT
		c1.col,
		ISNULL(c1.val,'<null>') AS val1,
		ISNULL(c2.val,'<null>') AS val2
	FROM 
		#colvals c1
	JOIN
		#colvals2 c2 ON c1.col = c2.col
	ORDER BY
		c1.col
END

DROP TABLE #colvals
DROP TABLE #colvals2

RETURN 0
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'[dbo].[AzSelect]') AND Type IN (N'P', N'PC'))
DROP PROCEDURE [dbo].[AzSelect]
GO

CREATE PROCEDURE [dbo].[AzSelect]
	@TableName sysname = NULL,
	@WhereClause VARCHAR(1000) = NULL
AS
-- written by Bill Talada

IF @TableName IS NULL
BEGIN
	PRINT 'Samples on selecting all columns alphabetically:'
	PRINT '  exec AzSelect Accessions,''1=1'''
	RETURN 0
END

DECLARE
	@col sysname,
	@list VARCHAR(MAX),
	@sql VARCHAR(MAX),
	@crlf VARCHAR(2),
	@tab VARCHAR(1)

SET @crlf=CHAR(13)+CHAR(10)
SET @tab=CHAR(9)

SET @col=''
SET @list=''

SELECT
	@col = MIN(c.name)
FROM
	sys.columns c
JOIN
	sys.tables t
	ON c.object_id=t.object_id
JOIN
	sys.types y
	ON c.system_type_id = y.system_type_id
WHERE
	t.object_id = OBJECT_ID(@TableName, N'U')
	--AND (y.name != 'image')

WHILE @col IS NOT NULL
BEGIN
	IF DATALENGTH(@list) > 1 SET @list = @list + ',' + @crlf

	SET @list = @list + @tab + @col
	--print @list

	SELECT
		@col = MIN(c.name)
	FROM
		sys.columns c
	JOIN
		sys.tables t
		ON c.object_id=t.object_id
	JOIN
		sys.types y
		ON c.system_type_id = y.system_type_id
	WHERE
		t.object_id = OBJECT_ID(@TableName, N'U')
		--AND (y.name != 'image')
		AND c.name > @col
END

SET @sql = 'select'
	+@crlf+@list
	+@crlf+'from'+@crlf+@tab+@TableName
	+@crlf+'where'+@crlf+@tab+@WhereClause

PRINT @sql
EXEC (@sql)

RETURN 0
GO

 