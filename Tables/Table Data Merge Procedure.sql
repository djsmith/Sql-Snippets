IF OBJECT_ID(N'[dbo].[usp_merge]', N'P') IS NOT NULL BEGIN
	DROP PROCEDURE [dbo].[usp_merge]
END
GO

CREATE PROCEDURE [dbo].[usp_merge] (
	@SrcServer VARCHAR(100),
	@SrcDatabase VARCHAR(100),
	@SrcSchema VARCHAR(100),
	@SrcTable VARCHAR(100),
	@SrcType VARCHAR(100),
	@TgtDatabase VARCHAR(100),
	@TgtSchema VARCHAR(100),
	@TgtTable VARCHAR(100),
	@WhereClause VARCHAR(500),
	@Debug CHAR(1),
	@OutputPK CHAR(1),
	@ParseOnly CHAR(1)
) AS
BEGIN
-------------------------------------------------------------------------------------------------------------------------------
-- Procedure Name: usp_merge
-- Author: Glen Schwickerath
-- Date Created: 02/05/2009
-- http://www.sqlservercentral.com/articles/T-SQL/66066/
--
-- Purpose: Stored procedure to utilize SQL Server 2008 MERGE statement. This stored procedure will
-- dynamically generate the required MERGE SQL statement and execute it.
--
-- This procedure is open source and free. The author is not responsible for any use, misuse,
-- or system errors which occur as a result of utilizing this code.
--
-- This code is provide freely to the reader. If you find usp_merge a useful, time-saving tool, 
-- please contribute $10 to your local food bank.
--
-- Parameters: @SrcServer Link server for iSeries or SQL Server. NULL for local.
-- @SrcDatabase Source database.
-- @SrcSchema Source schema. Default to "dbo".
-- @SrcTable Source table
-- @SrcType Source server type. "LINK" (SQL Server Link), or "SQL" (default)
-- @TgtDatabase Target database
-- @TgtSchema Target schema Default to "dbo".
-- @TgtTable Target table. If NULL, default to @SrcTable.
-- @WhereClause Where clause to subset data merged. If left empty->entire table is merged.
-- @Debug Displays debugging information. "Y" or "N" (default)
-- @OutputPK Output key values and operations performed. "Y" or "N" (Default)
-- @ParseOnly Generate MERGE statement but do not execute. "Y" or "N" (Default)
--
-- Example Syntax:
--
-- SQL Server->SQL Server 
-- 
-- usp_merge @SrcServer=NULL,
-- @SrcDatabase='AdventureWorks',
-- @SrcSchema='Production',
-- @SrcTable='TransactionHistory',
-- @SrcType='SQL',
-- @TgtDatabase='AdventureWorksCopy',
-- @TgtSchema=Production,
-- @TgtTable=NULL,
-- @WhereClause='TransactionID between 100000 and 102000',
-- @Debug='Y',
-- @OutputPK='Y' 
-- @ParseOnly='N'
-- 
-- LINK(SQL Server)->SQL Server
--
-- usp_merge @SrcServer='ServerLink',
-- @SrcDatabase='AdventureWorks',
-- @SrcSchema='Production',
-- @SrcTable='TransactionHistory',
-- @SrcType='SQL',
-- @TgtDatabase='AdventureWorksCopy',
-- @TgtSchema=Production,
-- @TgtTable=NULL,
-- @WhereClause='TransactionID between 100000 and 102000',
-- @Debug='Y',
-- @OutputPK='Y' 
-- @ParseOnly='N'
--
-- Updates:
--
--------------------------------------------------------------------------------------------------------------------------------
SET NOCOUNT ON
DECLARE @MergeSQL VARCHAR(MAX), --Complete sql string
	@TempSQL VARCHAR(MAX), --Temporary sql string
	@Str VARCHAR(500), --Temporary results string
	@CTR INT, --Temporary results counter
	@NoPK INT=0 --Indicates no primary key found
 
 
CREATE TABLE #SrcCols (SelColumn VARCHAR(100), SrcColumn VARCHAR(100))
CREATE TABLE #SrcPK (SrcColumn VARCHAR(100))

--
-- Edit input values
--
IF @SrcDatabase IS NULL OR @SrcTable IS NULL OR
	 (@SrcServer IS NULL AND @SrcType = 'LINK') OR
	 (@SrcSchema IS NULL AND @SrcType = 'LINK') BEGIN
	RAISERROR('usp_merge: Invalid input parameters',16,1)
	RETURN -1
END
 
IF @Debug IS NULL SELECT @Debug = 'N'
IF @OutputPK IS NULL SELECT @OutputPK = 'N'
IF @TgtTable IS NULL SELECT @TgtTable = @SrcTable
IF @TgtSchema IS NULL SELECT @TgtSchema = 'dbo'
IF @TgtDatabase IS NULL SELECT @TgtDatabase = DB_NAME()
IF @SrcType IS NULL SELECT @SrcType = 'SQL'
IF @SrcSchema IS NULL SELECT @SrcSchema = 'dbo'
IF @ParseOnly IS NULL SELECT @ParseOnly = 'N'
IF @Debug = 'Y' 
BEGIN
	SELECT @Str = 'Starting MERGE from '+@SrcDatabase+'.'+@SrcSchema+'.'+@SrcTable+' to '
	 +@TgtDatabase+'.'+@TgtSchema+'.'+@TgtTable+'.'
	PRINT @Str
	PRINT ''
	SELECT @Str = 'Where clause: '+@WhereClause
	IF LEN(@WhereClause) > 0 PRINT @Str
	PRINT ''
	IF @ParseOnly = 'Y' BEGIN 
		PRINT '@ParseOnly=''Y'' selected. Statement will not be executed.' 
		PRINT '' 
	END
END
 
------------------------------------------------------------------------------------------------------------------------
-- Generate MERGE statement
------------------------------------------------------------------------------------------------------------------------
 
--*********************************************************
-- Retrieve source column and primay key definitions *
--*********************************************************
IF @SrcType = 'LINK' BEGIN
	SELECT @TempSQL = ' select COLUMN_NAME as SelColumn, COLUMN_NAME as SrcColumn '+
	 ' from ['+@SrcServer+'].['+@SrcDatabase+'].INFORMATION_SCHEMA.COLUMNS '+
	 ' where TABLE_NAME = '''+@SrcTable+''''+
	 ' and TABLE_SCHEMA = '''+@SrcSchema+''''
	IF @Debug = 'Y' PRINT 'Retrieving column information from SQL Linked Server...'
END
ELSE
BEGIN
	SELECT @TempSQL = ' select COLUMN_NAME as SelColumn, COLUMN_NAME as SrcColumn '+
	 ' from '+@SrcDatabase+'.INFORMATION_SCHEMA.COLUMNS '+
	 ' where TABLE_NAME = '''+@SrcTable+''''+
	 ' and TABLE_SCHEMA = '''+@SrcSchema+''''
	IF @Debug = 'Y' PRINT 'Retrieving column information from SQL Server...'
END

INSERT INTO #SrcCols EXEC(@TempSQL)

IF @Debug = 'Y' PRINT ''
-- Check for columns
IF NOT EXISTS (SELECT 1 FROM #SrcCols) BEGIN
	SELECT @Str = 'No column information found for table '+@SrcTable+'. Exiting...'
	IF @Debug = 'Y' PRINT @Str
	SELECT @Str = 'usp_merge: '+@Str
	RAISERROR(@Str,16,1)
	RETURN -1
END

IF @Debug = 'Y' BEGIN
	SELECT @Str = 'Source table columns: '
	SELECT @Str = @Str + SrcColumn + ',' FROM #SrcCols
	SELECT @Str = SUBSTRING(@Str,1,LEN(@Str)-1)
	PRINT @Str
	PRINT ''
END
 
-- Retrieve primary keys
IF @SrcType = 'LINK' BEGIN
	SELECT @TempSQL = ' select b.COLUMN_NAME as SrcColumn from ['+@SrcDatabase+'].information_schema.TABLE_CONSTRAINTS a '+
	 ' JOIN ['+@SrcServer+'].['+@SrcDatabase+'].information_schema.CONSTRAINT_COLUMN_USAGE b on a.CONSTRAINT_NAME=b.CONSTRAINT_NAME '+
	 ' where a.CONSTRAINT_SCHEMA='''+@SrcSchema+''' and a.TABLE_NAME = '''+@SrcTable+''''+
	 ' and a.CONSTRAINT_TYPE = ''PRIMARY KEY'''
	IF @Debug = 'Y' PRINT 'Retrieving primary key information from SQL Linked Server...'
END
ELSE --@SrcType = 'SQL'
BEGIN
	SELECT @TempSQL = ' select b.COLUMN_NAME as SrcColumn from ['+@SrcDatabase+'].information_schema.TABLE_CONSTRAINTS a '+
	 ' JOIN ['+@SrcDatabase+'].information_schema.CONSTRAINT_COLUMN_USAGE b on a.CONSTRAINT_NAME=b.CONSTRAINT_NAME '+
	 ' where a.CONSTRAINT_SCHEMA='''+@SrcSchema+''' and a.TABLE_NAME = '''+@SrcTable+''''+
	 ' and a.CONSTRAINT_TYPE = ''PRIMARY KEY'''
	IF @Debug = 'Y' PRINT 'Retrieving primary key information from SQL Server...'
END

INSERT INTO #SrcPK EXEC(@TempSQL)
 
--***************************************************************************************************************** 
-- Primary keys could not be found on source server. First try to locate primary keys on target server. If
-- they cannot be found on target server, resort to matching on every column.
--*****************************************************************************************************************
-- If we can't get the primary keys from the AS400, take them from SQL Server
IF NOT EXISTS(SELECT 1 FROM #SrcPK) BEGIN
	SELECT @TempSQL = ' SELECT b.COLUMN_NAME AS SrcColumn FROM ['+@TgtDatabase+'].INFORMATION_SCHEMA.TABLE_CONSTRAINTS a '+
	' JOIN ['+@TgtDatabase+'].INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE b ON a.CONSTRAINT_NAME=b.CONSTRAINT_NAME '+
	' WHERE a.CONSTRAINT_SCHEMA='''+@TgtSchema+''' AND a.TABLE_NAME = '''+@TgtTable+''''+
	' AND a.CONSTRAINT_TYPE = ''PRIMARY KEY'''
	IF @Debug = 'Y' PRINT 'Could not locate primary keys from the source. Trying target server...' 
	INSERT INTO #SrcPK EXEC(@TempSQL)

	-- Final hack - use every column
	IF NOT EXISTS(SELECT 1 FROM #SrcPK) 
	BEGIN
	IF @Debug = 'Y' PRINT 'Could not locate primary keys from target server. Using all columns to match. This may be painful...'
	INSERT INTO #SrcPK SELECT SrcColumn FROM #SrcCols
	SELECT @NoPK = 1 
	END
END

IF @Debug = 'Y' AND @NoPK = 0 BEGIN
	SELECT @Str = 'Primary key(s) utilized: '
	SELECT @Str = @Str + SrcColumn + ',' FROM #SrcPK
	SELECT @Str = SUBSTRING(@Str,1,LEN(@Str)-1)
	PRINT @Str
	PRINT ''
END
 
--***************************************************************************************************************** 
-- Step 1) Generate Merge statement beginning
--
-- Syntax: MERGE [Production].[TransactionHistory] T 
--*****************************************************************************************************************
SELECT @MergeSQL = 'MERGE ['+@TgtDatabase+'].['+@TgtSchema+'].['+@TgtTable+'] T USING ('
 
--***************************************************************************************************************** 
-- Step 2) Generate Merge statement source selection
--
-- Syntax: USING (select "all fields" 
-- from Production.TransactionHistory 
-- where TransactionID between 100000 and 102000 ') ) S 
--
--*****************************************************************************************************************
SELECT @TempSQL =''
IF @SrcType = 'LINK' BEGIN
	SELECT @TempSQL = @TempSQL + SelColumn + ',' FROM #SrcCols
	SELECT @TempSQL = SUBSTRING(@TempSQL,1,LEN(@TempSQL)-1)
	SELECT @TempSQL = REPLACE(@TempSQL,'"','''''')
	SELECT @TempSQL = ' SELECT '+@TempSQL+' FROM ['+@SrcServer+'].['+@SrcDatabase+'].['+@SrcSchema+'].['+@SrcTable+'] '+
	 (CASE WHEN @WhereClause > '' THEN ' WHERE '+@WhereClause ELSE '' END)+') S '
END
ELSE -- @SrcType = 'SQL'
BEGIN
	SELECT @TempSQL = @TempSQL + SelColumn + ',' FROM #SrcCols
	SELECT @TempSQL = SUBSTRING(@TempSQL,1,LEN(@TempSQL)-1)
	SELECT @TempSQL = REPLACE(@TempSQL,'"','''''')
	SELECT @TempSQL = ' SELECT '+@TempSQL+' FROM ['+@SrcDatabase+'].['+@SrcSchema+'].['+@SrcTable+'] '+
	 (CASE WHEN @WhereClause > '' THEN ' WHERE '+@WhereClause ELSE '' END)+') S ' 
END

SELECT @MergeSQL=@MergeSQL+@TempSQL
 
--***************************************************************************************************************** 
-- Step 3) Join syntax between source and target using primary keys
--
-- Syntax: ON S.TransactionID = T.TransactionID
--
--*****************************************************************************************************************
IF EXISTS(SELECT 1 FROM #SrcPK) BEGIN
	SELECT @TempSQL = ' ON '
	SELECT @TempSQL = @TempSQL + 'S.'+SrcColumn+' = T.'+SrcColumn+' AND ' FROM #SrcPK
	SELECT @TempSQL = SUBSTRING(@TempSQL,1,LEN(@TempSQL)-4)
	SELECT @MergeSQL = @MergeSQL+@TempSQL
END
 
--***************************************************************************************************************** 
-- Step 4) Update matching rows. If there is no PK, this statement is bypassed
--
-- Syntax: WHEN MATCHED AND 
-- "target field values" <> "source field values" THEN
-- UPDATE SET "non-key target field values" = "non-key source field values"
--
--*****************************************************************************************************************
IF @NoPK = 0 BEGIN
	SELECT @TempSQL = ' WHEN MATCHED AND '

	SELECT @TempSQL = @TempSQL + 'S.'+cols.SrcColumn+' <> T.'+cols.SrcColumn+' OR ' 
	FROM #SrcCols cols
	LEFT OUTER JOIN #SrcPK PK ON cols.SrcColumn=PK.SrcColumn
	WHERE PK.SrcColumn IS NULL

	SELECT @TempSQL = SUBSTRING(@TempSQL,1,LEN(@TempSQL)-3)
	SELECT @TempSQL = @TEMPSQL+' THEN UPDATE SET '

	SELECT @TempSQL = @TempSQL + 'T.'+cols.SrcColumn+' = S.'+cols.SrcColumn+',' 
	FROM #SrcCols cols
	LEFT OUTER JOIN #SrcPK PK ON cols.SrcColumn=PK.SrcColumn
	WHERE PK.SrcColumn IS NULL

	SELECT @TempSQL = SUBSTRING(@TempSQL,1,LEN(@TempSQL)-1)
	SELECT @MergeSQL = @MergeSQL+@TempSQL
END

--***************************************************************************************************************** 
-- Step 5) Inserting new rows
--
-- Syntax: WHEN NOT MATCHED BY TARGET THEN
-- INSERT ("target columns") 
-- VALUES ("source columns")
--
--*****************************************************************************************************************
SELECT @TempSQL = ' WHEN NOT MATCHED BY TARGET THEN INSERT ('
SELECT @TempSQL = @TempSQL+SrcColumn+',' FROM #SrcCols
SELECT @TempSQL = SUBSTRING(@TempSQL,1,LEN(@TempSQL)-1)
SELECT @TempSQL = @TempSQL+') VALUES ('
SELECT @TempSQL = @TempSQL+SrcColumn+',' FROM #SrcCols
SELECT @TempSQL = SUBSTRING(@TempSQL,1,LEN(@TempSQL)-1)
SELECT @TempSQL = @TempSQL+') '
SELECT @MergeSQL = @MergeSQL+@TempSQL
 
--***************************************************************************************************************** 
-- Step 6) Delete rows from target that do not exist in source. Utilize @WhereClause if it has been provided
--
-- Syntax: WHEN NOT MATCHED BY SOURCE AND TransactionID between 100000 and 102000 THEN DELETE
--
--*****************************************************************************************************************
SELECT @MergeSQL = @MergeSQL+' WHEN NOT MATCHED BY SOURCE '+
 (CASE WHEN @WhereClause > '' THEN ' AND '+@WhereClause ELSE '' END)+' THEN DELETE '

--***************************************************************************************************************** 
-- Step 7) Include debugging information if @OutputPK = 'Y'
--
-- Syntax: OUTPUT $action, inserted.TransactionID as Inserted, deleted.TransactionID as Deleted; 
--
--*****************************************************************************************************************
IF @OutputPK = 'Y' BEGIN
	SELECT @TempSQL=' OUTPUT $action,'
	SELECT @TempSQL=@TempSQL+'INSERTED.'+SrcColumn+' AS ['+SrcColumn+' Ins Upd],' FROM #SrcPK
	SELECT @TempSQL=@TempSQL+'DELETED.' +SrcColumn+' AS ['+SrcColumn+' Deleted],' FROM #SrcPK
	SELECT @TempSQL = SUBSTRING(@TempSQL,1,LEN(@TempSQL)-1)
	SELECT @MergeSQL = @MergeSQL + @TempSQL
END
 
--***************************************************************************************************************** 
-- Step 8) MERGE statement must end with a semi-colon
--
-- Syntax: ; 
--
--*****************************************************************************************************************
SELECT @MergeSQL=@MergeSQL+';'
 
--***************************************************************************************************************** 
-- Include other debugging information
--*****************************************************************************************************************
IF @Debug = 'Y' BEGIN
	PRINT ''
	SELECT @STR='Length of completed merge sql statement: '+CONVERT(VARCHAR(10),LEN(@Mergesql))
	PRINT @STR
	PRINT ''
	PRINT 'Text of completed merge sql statement'
	PRINT '-------------------------------------'
	SELECT @CTR = 1
	WHILE @CTR < LEN(@Mergesql) BEGIN
		SELECT @Str = SUBSTRING(@MergeSQL,@CTR,200)
		PRINT @Str
		SELECT @CTR=@CTR+200
	END
	PRINT ''
	-- Add a rowcount
	SELECT @MergeSQL = @MergeSQL + ' PRINT CONVERT(VARCHAR(10),@@ROWCOUNT) '
END

--***************************************************************************************************************** 
-- Execute MERGE statement
--***************************************************************************************************************** 
IF @ParseOnly = 'N' EXEC (@MergeSQL)
IF (@@ERROR <> 0) BEGIN
	RAISERROR('usp_merge: SQL execution failed',16,1)
	RETURN -1
END

IF @Debug = 'Y' AND @ParseOnly = 'N' BEGIN
	SELECT @Str = '^Number of rows affected (insert/update/delete)'
	PRINT @Str
END
 

--***************************************************************************************************************** 
-- Cleanup
--***************************************************************************************************************** 
DROP TABLE #SrcCols
DROP TABLE #SrcPK
RETURN 0
 
END
GO


/*
This first example is a SQL Server->SQL Server direct database table 
merge. The @SrcServer variable is left NULL because the stored procedure 
is executed locally on the server. Secondly, the @TgtTable variable is 
left NULL and the stored procedure will default its value to @SrcTable.
NOTE: The @ParseOnly parameter = 'Y' so this will only print out the
resulting MERGE statement
*/
EXECUTE [dbo].[usp_merge]
	@SrcServer=NULL,
	@SrcDatabase='AdventureWorks',
	@SrcSchema='Production',
	@SrcTable='TransactionHistory',
	@SrcType='SQL',
	@TgtDatabase='AdventureWorksCopy',
	@TgtSchema=Production,
	@TgtTable=NULL,
	@WhereClause='TransactionID between 100000 and 102000',
	@Debug='Y',
	@OutputPK='Y',
	@ParseOnly='Y'
GO

/*
Illustrates utilizeing a SQL Server Linked Server table source merging 
to a local database table destination. The additional parameter required 
is the Linked Servername (@SrcServer). I have modified this stored 
procedure to also synchronize heterogeneous data sources to target SQL 
Server tables via a Linked Server. However, since there are many 
possibilities for source Linked Tables, I did not include sample code 
to do this.
NOTE: The @ParseOnly parameter = 'Y' so this will only print out the
resulting MERGE statement
*/	
EXECUTE [dbo].[usp_merge] 
	@SrcServer='MyServerLink',
	@SrcDatabase='AdventureWorks',
	@SrcSchema='Production',
	@SrcTable='TransactionHistory',
	@SrcType='SQL',
	@TgtDatabase='AdventureWorksCopy',
	@TgtSchema=Production,
	@TgtTable=NULL,
	@WhereClause='TransactionID between 100000 and 102000',
	@Debug='Y',
	@OutputPK='Y',
	@ParseOnly='Y'
GO

 

 