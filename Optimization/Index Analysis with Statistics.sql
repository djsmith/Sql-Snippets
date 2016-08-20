/*

Non-Indexed Column Selectivity Script

Sean Gorman
2/16/2007

This script finds columns in the selected database which do NOT currently have an index
but SQL Server has automatically created column level statistics (auto create stats must be on)
and may benefit from an index based on selectivity.  Selectivity percentages below 25% 
would most likely be chosen by the query optimizer.  This script should help AID in index
placement, however it should not be used to make blanket indexing decisions.

This script will take a long time to run on a large database.
*/


SET NOCOUNT ON

CREATE TABLE #selectivity
	(
	[table] VARCHAR(128)
	, [column] VARCHAR(128)
	, sel REAL
	, numrows REAL
	)

CREATE TABLE #helpselectivity 
	(
	[rows] VARCHAR(500) --Note: increased field size to avoid truncate errors during insert
	,rowhits REAL
	,selectivity REAL
	)

DECLARE @table VARCHAR(128)
DECLARE @column VARCHAR(128)
DECLARE @numrows REAL
DECLARE @numvalues REAL


DECLARE myCursor  CURSOR FOR

	SELECT systab.[name] AS 'Table Name', syscol.[name] as 'Column Name'
		FROM sysobjects AS systab WITH (NOLOCK)
			JOIN syscolumns AS syscol WITH (NOLOCK)
				ON systab.[id] = syscol.[id]
			JOIN sysindexes AS sysind WITH (NOLOCK)
				ON sysind.[id] = syscol.[id]
				AND (syscol.[name]+'%') LIKE (substring(sysind.[name], 9, 15)+'%')
		WHERE sysind.[name] LIKE '%_WA_Sys%' 
		AND syscol.[name] NOT LIKE '%_indcr'
		GROUP BY systab.[name], syscol.[name]

OPEN myCursor

FETCH NEXT FROM myCursor INTO @table, @column

WHILE @@FETCH_STATUS = 0
	BEGIN

		EXEC 
			(
			'INSERT INTO #helpselectivity 
			SELECT ' + @column + ' , COUNT(*),  0
			FROM ' + @table + ' WITH (NOLOCK) 
			GROUP BY ' + @column
			)
		SELECT	
			@numvalues = COUNT(*)
			, @numrows = SUM(rowhits)
		FROM	#helpselectivity
				
		UPDATE #helpselectivity
		SET selectivity = rowhits / @numrows
		
		INSERT INTO #selectivity
		SELECT @table, @column, (AVG(rowhits) / @numrows) * 100, @numrows  
		FROM #helpselectivity
		
		TRUNCATE TABLE #helpselectivity
				
    FETCH NEXT FROM myCursor INTO @table, @column

END

CLOSE myCursor
DEALLOCATE myCursor 

SELECT 
	[table] AS 'Table Name'
	, [column] AS 'Column Name'
	, sel AS 'Selectivity Percentage'
	, cast(numrows AS NUMERIC) AS 'Total Rows' 
FROM #selectivity
WHERE [sel] IS NOT NULL
GROUP BY [table], [column], [sel], [numrows]
ORDER BY [sel] ASC

DROP TABLE #helpselectivity
DROP TABLE #selectivity



 