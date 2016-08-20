 /*
This script returns some handy data about one chosen table, which 
might be of value especially if you would like to cancel out empty or 
almost empty columns (you've seen your tables with few hundred columns, 
most of those not really used). It provides data about the number of 
indexes, dependencies (again, review query results, ignore possible errors 
from sp_msdependencies), rows, columns and distinct entries in a column.

Author: Gregor Borosa
http://www.sqlservercentral.com/articles/Data+Quality/65326/

*/


/* SET THE TABLE NAME */
DECLARE @FullTableName sysname
SET @FullTableName = ''
PRINT @fullTableName

DECLARE @TableId INT
DECLARE @TableName sysname
DECLARE @SchemaName sysname
SET @TableId = OBJECT_ID(@FullTableName)
SET @TableName = OBJECT_NAME(@TableId)
SET @SchemaName = OBJECT_SCHEMA_NAME(@TableId)
--Reset the @FullTableName to wrap the schema and name in quotes
SET @FullTableName = QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)

SELECT name INTO #Cols FROM syscolumns 
WHERE 1=1
	AND id = @TableId 
	AND xtype NOT IN (34, 35, 36, 99, 189)	--skipping image, text, uniqueidentifier, ntext, timestamp

CREATE TABLE #Depends (oType SMALLINT, oobjname sysname, oowner VARCHAR(50), osequence SMALLINT)

INSERT INTO #Depends EXEC sp_MSdependencies @FullTableName, NULL, 1315327	
SELECT	@FullTableName AS TableName, 
	(SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName AND TABLE_SCHEMA = @SchemaName) AS ColumnsCount,
	(SELECT COUNT(*) FROM sysindexes si WHERE si.id = @TableId AND (si.status & 64) = 0) AS IndexesCount,
	(SELECT COUNT(*) FROM #Depends) AS DependenciesCount,
--Use this if you don't like errors from sp_msdependencies, but might show smaller number of dependant objects.
-- 	(SELECT COUNT(DISTINCT o.name) 
-- 		FROM sysobjects o, master.dbo.spt_values v, sysdepends d 	
-- 		WHERE o.id = d.id and o.xtype = SUBSTRING(v.name,1,2) COLLATE database_default and v.type = 'O9T' and d.depid = @TableId and deptype < 2) As DependenciesCount,
	(SELECT ISNULL(rowcnt,0) FROM sysindexes WHERE id = @TableId AND indid IN(0,1)) AS RowsCount

CREATE TABLE #Quality (
	Column_Name sysname,
	Column_Type VARCHAR(50),
	Count_Distincts INT
)

DECLARE @ColName VARCHAR(255)
DECLARE cCols CURSOR STATIC FORWARD_ONLY READ_ONLY 
	FOR SELECT name FROM #Cols
OPEN cCols
	FETCH NEXT FROM cCols INTO @ColName
WHILE @@FETCH_STATUS = 0
BEGIN
	EXECUTE( 'INSERT INTO #Quality (Column_Name, Column_Type, Count_Distincts)
			SELECT t.name, 
			(SELECT data_type FROM INFORMATION_SCHEMA.COLUMNS WHERE table_name='''+@TableName+''' AND column_name='''+@ColName+'''),
			COUNT(distinct isnull([' + @ColName + '],0))
			FROM ' + @FullTableName + ', #Cols t WHERE t.name=''' + @ColName + ''' GROUP BY t.name')
 	FETCH NEXT FROM cCols INTO @ColName
END

CLOSE cCols
DEALLOCATE cCols

SELECT * FROM #Quality ORDER BY Count_Distincts ASC, Column_Name

DROP TABLE #Quality
DROP TABLE #Cols
DROP TABLE #Depends
GO
 