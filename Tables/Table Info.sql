/*
	vwTableInfo - Table Information View

This view display space and storage information for every table in a
SQL Server 2005 database.
Columns are:
	Schema
	Name
	Owner		may be different from Schema
	Columns		count of the max number of columns ever used
	HasClusIdx	1 if table has a clustered index, 0 otherwise
	RowCount
	IndexKB		space used by the table's indexes
	DataKB		space used by the table's data

 16-March-2008, RBarryYoung@gmail.com
 31-January-2009, Edited for better formatting
*/
--CREATE VIEW vwTableInfo
-- AS
SELECT SCHEMA_NAME(tbl.SCHEMA_ID) AS [Schema]
, tbl.Name
, COALESCE((SELECT pr.name 
        FROM sys.database_principals pr 
        WHERE pr.principal_id = tbl.principal_id)
    , SCHEMA_NAME(tbl.SCHEMA_ID)) AS [Owner]
, tbl.max_column_id_used AS [Columns]
, CAST(CASE idx.index_id WHEN 1 THEN 1 ELSE 0 END AS BIT) AS [HasClusIdx]
, COALESCE( (SELECT SUM (spart.ROWS) FROM sys.partitions spart 
    WHERE spart.OBJECT_ID = tbl.OBJECT_ID AND spart.index_id < 2), 0) AS [RowCount]

, COALESCE( (SELECT CAST(v.low/1024.0 AS FLOAT) 
    * SUM(a.used_pages - CASE WHEN a.TYPE <> 1 THEN a.used_pages WHEN p.index_id < 2 THEN a.data_pages ELSE 0 END) 
        FROM sys.indexes AS i
         JOIN sys.partitions AS p ON p.OBJECT_ID = i.OBJECT_ID AND p.index_id = i.index_id
         JOIN sys.allocation_units AS a ON a.container_id = p.partition_id
        WHERE i.OBJECT_ID = tbl.OBJECT_ID  )
    , 0.0) AS [IndexKB]

, COALESCE( (SELECT CAST(v.low/1024.0 AS FLOAT)
    * SUM(CASE WHEN a.TYPE <> 1 THEN a.used_pages WHEN p.index_id < 2 THEN a.data_pages ELSE 0 END) 
        FROM sys.indexes AS i
         JOIN sys.partitions AS p ON p.OBJECT_ID = i.OBJECT_ID AND p.index_id = i.index_id
         JOIN sys.allocation_units AS a ON a.container_id = p.partition_id
        WHERE i.OBJECT_ID = tbl.OBJECT_ID)
    , 0.0) AS [DataKB]
, tbl.create_date, tbl.modify_date

FROM sys.tables AS tbl
INNER JOIN sys.indexes AS idx 
	ON (idx.OBJECT_ID = tbl.OBJECT_ID AND idx.index_id < 2)
INNER JOIN master.dbo.spt_values v 
	ON (v.number=1 AND v.TYPE='E')

 