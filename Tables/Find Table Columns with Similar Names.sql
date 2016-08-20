 /*
The purpose of this procedure is finding tables with similar column names. 
It lists all columns of a given table, avoiding some data types 
(images, timestamps etc.), and not minding the columns not used in indexes 
in linked tables. That is for narrowing our results. If you don't get 
enough rows with potentially linked tables, you can try commenting 
out the line with the join on sysindexes table and/or trying partial matches 
to column names with %s.

Author: Gregor Borosa
http://www.sqlservercentral.com/articles/Data+Quality/65326/

*/


/* Set the table name */
DECLARE @TableName sysname, @SchemaName sysname
SET @TableName = 'HumanResources.Employee'

SELECT name INTO #Cols FROM syscolumns 
WHERE 1=1
	AND id = OBJECT_ID(@TableName, N'U')
	AND xtype NOT IN (34, 35, 99, 189)	--skipping image, text, ntext, timestamp
	
SELECT c.name AS Column_name, 
	(SELECT data_type 
	FROM INFORMATION_SCHEMA.COLUMNS 
	WHERE table_name=o.name 
		AND column_name=c.name) AS Column_type,
	o.name AS Table_name, 
	(SELECT ISNULL(rowcnt,0) 
	FROM sysindexes 
	WHERE id = (SELECT id 
				FROM sysobjects 
				WHERE name=o.name AND xtype='U') 
		AND indid IN(0,1)) AS RowsCount
FROM sysobjects o, syscolumns c, #Cols tc
WHERE o.id=c.id 
	AND o.xtype='U' 
	AND c.name=tc.name
	--only columns, which are part of some index:
	AND c.id IN (SELECT k.id 
				FROM sysindexkeys k, sysindexes x 
				WHERE k.id=c.id 
					AND k.colid=c.colid 
					AND k.indid=x.indid 
					AND (x.status & 64) = 0 
					AND c.id=x.id)
ORDER BY c.name, o.name

DROP TABLE #Cols
GO
