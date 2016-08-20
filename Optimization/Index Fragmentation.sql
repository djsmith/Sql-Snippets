 /*
Shows table indexes with a fragmentation of greater than 15% and page count is creater than 2
http://sqlserverpedia.com/blog/sql-server-bloggers/my-top-5-sql-server-indexing-best-practices/
*/

SELECT 
   SI.[name] AS index_name, 
   OBJECT_SCHEMA_NAME(SDDIPS.[object_id]) + '.' + OBJECT_NAME(SDDIPS.[object_id]) AS [object_name], 
   SDDIPS.[index_type_desc], SDDIPS.[avg_fragmentation_in_percent], SDDIPS.[page_count] 
FROM sys.[dm_db_index_physical_stats](DB_ID(), NULL, NULL, NULL, 'Detailed') SDDIPS
INNER JOIN sys.[indexes] SI 
	ON SDDIPS.[object_id] = SI.[object_id]
	AND SDDIPS.[index_id] = SI.[index_id]
WHERE SDDIPS.[avg_fragmentation_in_percent] > 15
   AND SDDIPS.[page_count] > 2
   AND SDDIPS.[index_id] > 0
ORDER BY OBJECT_SCHEMA_NAME(SDDIPS.[object_id]), OBJECT_NAME(SDDIPS.[object_id])
