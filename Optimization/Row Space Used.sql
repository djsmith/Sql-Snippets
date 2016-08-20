-- This script searches all tables in a database and reports the defined rowlength 
-- and the longest actual row. If a table contains text or image columns it's possible
-- that the actual used length is greater than the defined one.
-- Written for SQL 2000 but works also on 2005
-- Author: Markus Bohse 
-- Date: 02-08-2007


-- Setup the environment
SET TRANSACTION isolation LEVEL READ uncommitted 

SET NOCOUNT ON 

SET ANSI_WARNINGS OFF 

--===== If the result table already exists, drop it
IF OBJECT_ID('TempDB..#tmp') IS NOT NULL
	DROP TABLE #tmp

IF OBJECT_ID('TempDB..#RowLength') IS NOT NULL
	DROP TABLE #rowlength
 
SELECT so.id AS ObjectId, so.name AS TableName, sc.name AS ColumnName
INTO #tmp
FROM sysobjects so
INNER JOIN syscolumns sc
	ON so.id = sc.id
WHERE (OBJECTPROPERTY(sc.id,'IsTable') = 1
	AND OBJECTPROPERTY(sc.id,'IsMSShipped') = 0)

 
UPDATE #tmp
SET TableName = '['+ u.name+'].['+ o.name+']'
FROM sysobjects o 
JOIN sysusers u
	ON u.uid = o.uid
WHERE id = ObjectId

SELECT c.id AS ObjectId, OBJECT_NAME(c.id) AS TableName, 
 SUM(c.length) AS DefinedRowLength, 0 AS MaxActualLength
INTO #rowlength
FROM syscolumns c
WHERE (OBJECTPROPERTY(c.id,'IsTable') = 1
	AND OBJECTPROPERTY(c.id,'IsMSShipped') = 0)
GROUP BY c.id

UPDATE #rowlength
SET TableName=t.TableName
FROM #tmp t
WHERE #rowlength.ObjectId = t.ObjectId

DECLARE @isql NVARCHAR(4000),
	@tbname VARCHAR(128),
	@clname VARCHAR(128),
	@len SMALLINT
 
DECLARE c1 CURSOR FOR
	SELECT DISTINCT tablename
	FROM #tmp
 
OPEN c1

FETCH NEXT FROM c1
INTO @tbname
 
WHILE @@FETCH_STATUS <> -1 BEGIN
	SET @isql = ''
	 
	DECLARE c2 CURSOR FOR
		SELECT columnname
		FROM #tmp
		WHERE tablename = @tbname
	 
	OPEN c2
	 
	FETCH NEXT FROM c2
	INTO @clname
	 
	WHILE @@FETCH_STATUS <> -1 BEGIN
		SELECT @isql = @isql + ' ISNULL(DATALENGTH([' + @clname + ']),0)+'
		 
		FETCH NEXT FROM c2
		INTO @clname
	END
	 
	CLOSE c2
	 
	DEALLOCATE c2
	 
	SELECT @len = LEN(@isql)
	 
	SELECT @isql = 'UPDATE #rowlength SET maxactuallength = (SELECT ISNULL(MAX( ' + LEFT(@isql,@len - 1) + '),0) FROM ' + @tbname + ')WHERE TableName = ' + QUOTENAME(@tbname,'''')
	 
	--PRINT @isql
	 
	EXEC sp_executesql @isql
	 
	FETCH NEXT FROM c1
	INTO @tbname
END

CLOSE c1
DEALLOCATE c1
SELECT TableName, DefinedRowLength, MaxActualLength FROM #rowlength
ORDER BY TableName

IF OBJECT_ID('TempDB..#tmp') IS NOT NULL
	DROP TABLE #tmp

IF OBJECT_ID('TempDB..#RowLength') IS NOT NULL
	DROP TABLE #rowlength


 