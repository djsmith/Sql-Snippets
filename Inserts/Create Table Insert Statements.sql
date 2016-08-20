/*
Create Table Insert Statements</Title>
This stored procedure creates a series of insert statements for each row in a database table
*/

SET NOCOUNT ON
GO

PRINT 'Using Master database'
USE master
GO

PRINT 'Checking for the existence of this procedure'
IF (SELECT OBJECT_ID('sp_create_insert_statements','P')) IS NOT NULL --means, the procedure already exists
BEGIN
	PRINT 'Procedure already exists. So, dropping it'
	DROP PROC sp_create_insert_statements
END
GO

CREATE PROC sp_Create_Insert_Statements
(
	@table_name varchar(776),  		-- The table for which the INSERT statements will be generated using the existing data
	@target_table varchar(776) = NULL, 	-- Use this parameter to specify a different table name into which the data will be inserted
	@include_column_list bit = 1,		-- Use this parameter to include/ommit column list in the generated INSERT statement
	@from varchar(800) = NULL, 		-- Use this parameter to filter the rows based on a filter condition (using WHERE)
	@include_timestamp bit = 0, 		-- Specify 1 for this parameter, if you want to include the TIMESTAMP/ROWVERSION column's data in the INSERT statement
	@debug_mode bit = 0,			-- If @debug_mode is set to 1, the SQL statements constructed by this procedure will be printed for later examination
	@owner varchar(64) = NULL,		-- Use this parameter if you are not the owner of the table
	@ommit_images bit = 0,			-- Use this parameter to generate INSERT statements by omitting the 'image' columns
	@ommit_identity bit = 0,		-- Use this parameter to ommit the identity columns
	@top int = NULL,			-- Use this parameter to generate INSERT statements only for the TOP n rows
	@cols_to_include varchar(8000) = NULL,	-- List of columns to be included in the INSERT statement
	@cols_to_exclude varchar(8000) = NULL	-- List of columns to be excluded from the INSERT statement
)
AS
BEGIN

/***********************************************************************************************************
Procedure:	sp_create_insert_statements   


	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	This code was originally created by Narayana Vyas Kondreddi http://vyaskn.tripod.com/

	Extensions to the original code are as follows:

	Everything is now bound within a transaction to ensure we have consistancy.
	A delete statement has been added to ensure the tables content is what is in the script.
	The table's triggers will be disabled to stop unwanted actions when this resultant script is run. The triggers are re-enabled at the end.
	Error handling has been added so they can be trapped and the transaction can be rolled back.
	The transaction count is checked at the end to ensure we have no open transactions - this can be a problem when using QA to run the procedure and you have selected the wrong database.
	An order by clause was added to make sure the insert statements are ordered by the primary key if it exists.

	It is the intention that this script remains free. 
	If you have any queries you could contact either myself through my web-site www.innovartis.co.uk or Vyas at http://vyaskn.tripod.com/

	Mark Baekdal

	---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

                                          
Purpose:	To generate INSERT statements from existing data. 
		These INSERTS can be executed to regenerate the data at some other location.
		This procedure is also useful to create a database setup, where in you can 
		script your data along with your table definitions.

NOTE:		This procedure may not work with tables with too many columns.
		Results can be unpredictable with huge text columns or SQL Server 2000's sql_variant data types
		IMPORTANT: Whenever possible, Use @include_column_list parameter to ommit column list in the INSERT statement, for better results

Example 1:	To generate INSERT statements for table 'titles':
		
		EXEC sp_Create_Insert_Statements 'titles'

Example 2: 	To ommit the column list in the INSERT statement: (Column list is included by default)
		IMPORTANT: If you have too many columns, you are advised to ommit column list, as shown below,
		to avoid erroneous results
		
		EXEC sp_Create_Insert_Statements 'titles', @include_column_list = 0

Example 3:	To generate INSERT statements for 'titlesCopy' table from 'titles' table:

		EXEC sp_Create_Insert_Statements 'titles', 'titlesCopy'

Example 4:	To generate INSERT statements for 'titles' table for only those titles 
		which contain the word 'Computer' in them:
		NOTE: Do not complicate the FROM or WHERE clause here. It's assumed that you are good with T-SQL if you are using this parameter

		EXEC sp_Create_Insert_Statements 'titles', @from = "from titles where title like '%Computer%'"

Example 5: 	To specify that you want to include TIMESTAMP column's data as well in the INSERT statement:
		(By default TIMESTAMP column's data is not scripted)

		EXEC sp_Create_Insert_Statements 'titles', @include_timestamp = 1

Example 6:	To print the debug information:
  
		EXEC sp_Create_Insert_Statements 'titles', @debug_mode = 1

Example 7: 	If you are not the owner of the table, use @owner parameter to specify the owner name
		To use this option, you must have SELECT permissions on that table

		EXEC sp_Create_Insert_Statements Nickstable, @owner = 'Nick'

Example 8: 	To generate INSERT statements for the rest of the columns excluding images
		When using this otion, DO NOT set @include_column_list parameter to 0.

		EXEC sp_Create_Insert_Statements imgtable, @ommit_images = 1

Example 9: 	To generate INSERT statements excluding (ommiting) IDENTITY columns:
		(By default IDENTITY columns are included in the INSERT statement)

		EXEC sp_Create_Insert_Statements mytable, @ommit_identity = 1

Example 10: 	To generate INSERT statements for the TOP 10 rows in the table:
		
		EXEC sp_Create_Insert_Statements mytable, @top = 10

Example 11: 	To generate INSERT statements with only those columns you want:
		
		EXEC sp_Create_Insert_Statements titles, @cols_to_include = "'title','title_id','au_id'"

Example 12: 	To generate INSERT statements by omitting certain columns:
		
		EXEC sp_Create_Insert_Statements titles, @cols_to_exclude = "'title','title_id','au_id'"
***********************************************************************************************************/

SET NOCOUNT ON

--Making sure user only uses either @cols_to_include or @cols_to_exclude
IF ((@cols_to_include IS NOT NULL) AND (@cols_to_exclude IS NOT NULL))
	BEGIN
		RAISERROR('Use either @cols_to_include or @cols_to_exclude. Do not specify both',16,1)
		RETURN -1 --Failure. Reason: Both @cols_to_include and @cols_to_exclude parameters are specified
	END

--Making sure the @cols_to_include and @cols_to_exclude parameters are receiving values in proper format
IF ((@cols_to_include IS NOT NULL) AND (PATINDEX('''%''',@cols_to_include) = 0))
	BEGIN
		RAISERROR('Invalid use of @cols_to_include property',16,1)
		PRINT 'Specify column names surrounded by single quotes and separated by commas'
		PRINT 'Eg: EXEC sp_Create_Insert_Statements titles, @cols_to_include = "''title_id'',''title''"'
		RETURN -1 --Failure. Reason: Invalid use of @cols_to_include property
	END

IF ((@cols_to_exclude IS NOT NULL) AND (PATINDEX('''%''',@cols_to_exclude) = 0))
	BEGIN
		RAISERROR('Invalid use of @cols_to_exclude property',16,1)
		PRINT 'Specify column names surrounded by single quotes and separated by commas'
		PRINT 'Eg: EXEC sp_Create_Insert_Statements titles, @cols_to_exclude = "''title_id'',''title''"'
		RETURN -1 --Failure. Reason: Invalid use of @cols_to_exclude property
	END


--Checking to see if the server name is specified along wih the table name
--Your server context should be local to the table for which you want to generate INSERT statements
--specifying the server name is not allowed
IF (parsename(@table_name,4)) IS NOT NULL
	BEGIN
		RAISERROR('Do not specify the server name in the @table_name parameter. Be connected to the required server and just specify the table name.',16,1)
		RETURN -1 --Failure. Reason: Database name is specified along with the table name, which is not allowed
	END

--Checking to see if the database name is specified along wih the table name
--Your database context should be local to the table for which you want to generate INSERT statements
--specifying the database name is not allowed
IF (parsename(@table_name,3)) IS NOT NULL
	BEGIN
		RAISERROR('Do not specify the database name in the @table_name parameter. Be in the required database and just specify the table name.',16,1)
		RETURN -1 --Failure. Reason: Database name is specified along with the table name, which is not allowed
	END

--Checking to see if the table owner is specified along wih the table name
--Use the @owner parameter to specify the owner of the table
IF (parsename(@table_name,2)) IS NOT NULL
	BEGIN
		RAISERROR('Do not specify the owner name in the @table_name parameter, use the @owner parameter instead. ',16,1)
		RETURN -1 --Failure. Reason: Owner name is specified along with the table name, which is not allowed
	END

--Checking for the existence of 'user table'
--This procedure is not written to work on system tables
IF @owner IS NULL
	BEGIN
		IF (OBJECT_ID(@table_name,'U') IS NULL) 
			BEGIN
				RAISERROR('User table not found.',16,1)
				PRINT 'You may see this error, if you are not the owner of this table. In that case use @owner parameter to specify the owner name.'
				PRINT 'Make sure you have SELECT permission on that table.'
				RETURN -1 --Failure. Reason: There is no user table with this name
			END
	END
ELSE
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = @table_name AND TABLE_TYPE = 'BASE TABLE' AND TABLE_SCHEMA = @owner)
			BEGIN
				RAISERROR('User table not found.',16,1)
				PRINT 'You may see this error, if you are not the owner of this table. In that case use @owner parameter to specify the owner name.'
				PRINT 'Make sure you have SELECT permission on that table.'
				RETURN -1 --Failure. Reason: There is no user table with this name		
			END
	END

--Variable declarations
DECLARE	@Column_ID int, 		
		@Column_List varchar(8000), 
		@Column_Name varchar(128), 
		@Start_Insert varchar(786), 
		@Data_Type varchar(128), 
		@Actual_Values varchar(8000),	--This is the string that will be finally executed to generate INSERT statements
		@IDN varchar(128)				--Will contain the IDENTITY column's name in the table

--Variable Initialization
SET @IDN = ''
SET @Column_ID = 0
SET @Column_Name = 0
SET @Column_List = ''
SET @Actual_Values = ''
IF @owner IS NULL 
	BEGIN
		SET @Start_Insert = 'INSERT INTO ' + '[' + RTRIM(COALESCE(@target_table,@table_name)) + ']' 
	END
ELSE
	BEGIN
		SET @Start_Insert = 'INSERT ' + '[' + LTRIM(RTRIM(@owner)) + '].' + '[' + RTRIM(COALESCE(@target_table,@table_name)) + ']' 		
	END


--To get the first column's ID
IF @owner IS NULL
	BEGIN
		SELECT	@Column_ID = MIN(ORDINAL_POSITION) 	
		FROM	INFORMATION_SCHEMA.COLUMNS (NOLOCK) 
		WHERE 	TABLE_NAME = @table_name
	END
ELSE
	BEGIN
		SELECT	@Column_ID = MIN(ORDINAL_POSITION) 	
		FROM	INFORMATION_SCHEMA.COLUMNS (NOLOCK) 
		WHERE 	TABLE_NAME = @table_name AND
			TABLE_SCHEMA = @owner		
	END


--Loop through all the columns of the table, to get the column names and their data types
WHILE @Column_ID IS NOT NULL
	BEGIN
		IF @owner IS NULL
			BEGIN
				SELECT 	@Column_Name = '[' + COLUMN_NAME + ']', 
				@Data_Type = DATA_TYPE 
				FROM 	INFORMATION_SCHEMA.COLUMNS (NOLOCK) 
				WHERE 	ORDINAL_POSITION = @Column_ID AND 
				TABLE_NAME = @table_name
			END
		ELSE
			BEGIN
				SELECT 	@Column_Name = '[' + COLUMN_NAME + ']', 
				@Data_Type = DATA_TYPE 
				FROM 	INFORMATION_SCHEMA.COLUMNS (NOLOCK) 
				WHERE 	ORDINAL_POSITION = @Column_ID AND 
				TABLE_NAME = @table_name AND
				TABLE_SCHEMA = @owner
			END

		IF @cols_to_include IS NOT NULL --Selecting only user specified columns
		BEGIN
			IF CHARINDEX( '''' + SUBSTRING(@Column_Name,2,LEN(@Column_Name)-2) + '''',@cols_to_include) = 0 
			BEGIN
				GOTO SKIP_LOOP
			END
		END

		IF @cols_to_exclude IS NOT NULL --Selecting only user specified columns
		BEGIN
			IF CHARINDEX( '''' + SUBSTRING(@Column_Name,2,LEN(@Column_Name)-2) + '''',@cols_to_exclude) <> 0 
			BEGIN
				GOTO SKIP_LOOP
			END
		END
		--Making sure to output SET IDENTITY_INSERT ON/OFF in case the table has an IDENTITY column
		IF (SELECT COLUMNPROPERTY( OBJECT_ID(@table_name),SUBSTRING(@Column_Name,2,LEN(@Column_Name) - 2),'IsIdentity')) = 1 
		BEGIN
			IF @ommit_identity = 0 --Determing whether to include or exclude the IDENTITY column
				SET @IDN = @Column_Name
			ELSE
				GOTO SKIP_LOOP			
		END


		
		--Tables with columns of IMAGE data type are not supported for obvious reasons
		IF(@Data_Type in ('image'))
			BEGIN
				IF (@ommit_images = 0)
					BEGIN
						RAISERROR('Tables with image columns are not supported.',16,1)
						PRINT 'Use @ommit_images = 1 parameter to generate INSERTs for the rest of the columns.'
						PRINT 'DO NOT ommit Column List in the INSERT statements. If you ommit column list using @include_column_list=0, the generated INSERTs will fail.'
						RETURN -1 --Failure. Reason: There is a column with image data type
					END
				ELSE
					BEGIN
					GOTO SKIP_LOOP
					END
			END

		--Determining the data type of the column and depending on the data type, the VALUES part of
		--the INSERT statement is generated. Care is taken to handle columns with NULL values. Also
		--making sure, not to lose any data from flot, real, money, smallmomey, datetime columns
		SET @Actual_Values = @Actual_Values  +
		CASE 
			WHEN @Data_Type IN ('char','varchar','nchar','nvarchar') 
				THEN 
					''''''''' + '+'COALESCE(REPLACE(RTRIM(' + @Column_Name + '),'''''''',''''''''''''),''nvkon©'')' + ' + ''''''''' 
			WHEN @Data_Type IN ('datetime','smalldatetime') 
				THEN 
					''''''''' + '+'COALESCE(RTRIM(CONVERT(char,' + @Column_Name + ',109)),''nvkon©'')' + ' + ''''''''' 
			WHEN @Data_Type IN ('uniqueidentifier') 
				THEN  
					''''''''' + '+'COALESCE(REPLACE(CONVERT(char(255),RTRIM(' + @Column_Name + ')),'''''''',''''''''''''),''NULL'')' + ' + ''''''''' 
			WHEN @Data_Type IN ('text','ntext') 
				THEN  
					''''''''' + '+'COALESCE(REPLACE(CONVERT(char,' + @Column_Name + '),'''''''',''''''''''''),''NULL'')' + ' + ''''''''' 
			WHEN @Data_Type IN ('binary','varbinary') 
				THEN  
					'COALESCE(RTRIM(CONVERT(char,' + 'CONVERT(int,' + @Column_Name + '))),''NULL'')'  
			WHEN @Data_Type IN ('timestamp','rowversion') 
				THEN  
					CASE 
						WHEN @include_timestamp = 0 
							THEN 
								'''DEFAULT''' 
							ELSE 
								'COALESCE(RTRIM(CONVERT(char,' + 'CONVERT(int,' + @Column_Name + '))),''NULL'')'  
					END
			WHEN @Data_Type IN ('float','real','money','smallmoney')
				THEN
					'COALESCE(LTRIM(RTRIM(' + 'CONVERT(char, ' +  @Column_Name  + ',2)' + ')),''NULL'')' 
			ELSE 
				'COALESCE(LTRIM(RTRIM(' + 'CONVERT(char, ' +  @Column_Name  + ')' + ')),''NULL'')' 
		END   + '+' +  ''',''' + ' + '
		
		--Generating the column list for the INSERT statement
		SET @Column_List = @Column_List +  @Column_Name + ','	

		SKIP_LOOP: --The label used in GOTO

		IF @owner IS NULL
			BEGIN
				SELECT 	@Column_ID = MIN(ORDINAL_POSITION) 
				FROM 	INFORMATION_SCHEMA.COLUMNS (NOLOCK) 
				WHERE 	TABLE_NAME = @table_name AND 
				ORDINAL_POSITION > @Column_ID
			END
		ELSE
			BEGIN
				SELECT 	@Column_ID = MIN(ORDINAL_POSITION) 
				FROM 	INFORMATION_SCHEMA.COLUMNS (NOLOCK) 
				WHERE 	TABLE_NAME = @table_name AND 
				ORDINAL_POSITION > @Column_ID AND
				TABLE_SCHEMA = @owner
			END
	--Loop ends here!
	END

--To get rid of the extra characters that got concatened during the last run through the loop
SET @Column_List = LEFT(@Column_List,len(@Column_List) - 1)
SET @Actual_Values = LEFT(@Actual_Values,len(@Actual_Values) - 6)

--sort out the order by clause
DECLARE PK_Cols CURSOR
READ_ONLY
FOR 
select 
	column_name
from
	INFORMATION_SCHEMA.KEY_COLUMN_USAGE 
where
	objectproperty(object_id(constraint_name),'IsPrimaryKey')=1
	and table_name = @table_name
	and table_schema = isnull(@owner,table_schema)
order by
	constraint_name
	,ordinal_position


DECLARE @pk_col_name sysname,@pk_col_names varchar(8000)
OPEN PK_Cols
set @pk_col_names=',  '
FETCH NEXT FROM PK_Cols INTO @pk_col_name
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		set @pk_col_names=@pk_col_names + @pk_col_name + ',' 		
	END
	FETCH NEXT FROM PK_Cols INTO @pk_col_name
END
set @pk_col_names = right(@pk_col_names,len(@pk_col_names)-1)
set @pk_col_names = rtrim(ltrim(@pk_col_names))
--remove the last comma if exists
if @pk_col_names<>'' begin
	if right(@pk_col_names,1)=',' set @pk_col_names=left(@pk_col_names,len(@pk_col_names)-1)
end 
CLOSE PK_Cols
DEALLOCATE PK_Cols



--Forming the final string that will be executed, to output the INSERT statements
IF (@include_column_list <> 0)
	BEGIN
		SET @Actual_Values = 
			'SELECT col1=' +  
			CASE WHEN @top IS NULL OR @top < 0 THEN '' ELSE ' TOP ' + LTRIM(STR(@top)) + ' ' END + 
			'''' + RTRIM(@Start_Insert) + 
			' ''+' + '''(' + RTRIM(@Column_List) +  '''+' + ''')''' + 
			' +''VALUES(''+ ' +  'REPLACE(' + @Actual_Values + ',''''''nvkon©'''''',''NULL'')'  + '+'')''' + ' ' + 
			' into ##values ' + 
			COALESCE(@from,' FROM ' + CASE WHEN @owner IS NULL THEN '' ELSE '[' + LTRIM(RTRIM(@owner)) + '].' END + '[' + rtrim(@table_name) + ']' + '(NOLOCK)') 
			--order by clause
			+ case when @pk_col_names = '' then '' else ' order by ' + @pk_col_names end
	END
ELSE IF (@include_column_list = 0)
	BEGIN
		SET @Actual_Values = 
			'SELECT col1=' + 
			CASE WHEN @top IS NULL OR @top < 0 THEN '' ELSE ' TOP ' + LTRIM(STR(@top)) + ' ' END + 
			'''' + RTRIM(@Start_Insert) + 
			' '' +''VALUES(''+ ' +  'REPLACE(' + @Actual_Values + ',''''''nvkon©'''''',''NULL'')'  + '+'')''' + ' ' + 
			' into ##values ' + 
			COALESCE(@from,' FROM ' + CASE WHEN @owner IS NULL THEN '' ELSE '[' + LTRIM(RTRIM(@owner)) + '].' END + '[' + rtrim(@table_name) + ']' + '(NOLOCK)')
			--order by clause
			+ case when @pk_col_names = '' then '' else ' order by ' + @pk_col_names end
	END	


--Determining whether to ouput any debug information
IF @debug_mode =1
	BEGIN
		PRINT '/*****START OF DEBUG INFORMATION*****'
		PRINT 'Beginning of the INSERT statement:'
		PRINT @Start_Insert
		PRINT ''
		PRINT 'The column list:'
		PRINT @Column_List
		PRINT ''
		PRINT 'The SELECT statement executed to generate the INSERTs'
		PRINT @Actual_Values
		PRINT ''
		PRINT '*****END OF DEBUG INFORMATION*****/'
		PRINT ''
	END



--All the hard work pays off here!!! You'll get your INSERT statements, when the next line executes!

--wrap everything within a transaction
if object_id('tempdb..##values') IS NOT NULL
drop table ##values
if object_id('tempdb..#return') IS NOT NULL
drop table #return

EXEC (@Actual_Values)

--select * from ##values

if object_id('tempdb..##values') IS NOT NULL begin
	update ##values set col1 = col1 + char(13) + ' SET @ERROR = @@ERROR IF @ERROR<>0 GOTO ErrorHandler'
	--put all the output into another temporary table which we will select from
	declare @col_length int
	select @col_length = max(len(col1)) from ##values
	select order_number = identity(int,1,1) ,result=replicate('-',@col_length) into #return
	insert into #return(result)values('--Statement produced by procedure sp_Create_Insert_Statements ''' + @table_name + '''')		
	insert into #return(result)values('')
	insert into #return(result)values('SET NOCOUNT ON')
	insert into #return(result)values('GO')
	insert into #return(result)values('')
	
	
	--Disable all the triggers on the table and delete everything that exists
	insert into #return(result)values('ALTER TABLE [' + @table_name + '] DISABLE TRIGGER ALL')
	insert into #return(result)values('GO')
	insert into #return(result)values('')
	
	--wrap everything in a transaction
	insert into #return(result)values('DECLARE @ERROR INT')
	insert into #return(result)values('SET @ERROR = 0')
	insert into #return(result)values('BEGIN TRAN')
	
	
	insert into #return(result)values('DELETE FROM [' + @table_name + ']')
	insert into #return(result)values('SET @ERROR = @@ERROR IF @ERROR<>0 GOTO ErrorHandler')
	
	--Do a DBCC CheckIdent on the table
	insert into #return(result)values('DBCC CHECKIDENT ([' + @table_name + '])')
	insert into #return(result)values('SET @ERROR = @@ERROR IF @ERROR<>0 GOTO ErrorHandler')

	--Determining whether to print IDENTITY_INSERT or not
	IF (@IDN <> '')
		BEGIN
			insert into #return(result)values('SET IDENTITY_INSERT ' + '[' + RTRIM(COALESCE(@target_table,@table_name)) + ']' + ' ON')
			insert into #return(result)values('')
		END
	insert into #return(result) select col1 from ##values
	insert into #return(result)values('')
	
	IF (@IDN <> '')
		BEGIN
			insert into #return(result)values('SET IDENTITY_INSERT ' + '[' + RTRIM(COALESCE(@target_table,@table_name)) + ']' + ' OFF')
			insert into #return(result)values('')
		END
	
	--end the transaction
	insert into #return(result)values('ErrorHandler:')
	insert into #return(result)values('IF @ERROR = 0 COMMIT ELSE ROLLBACK')
	insert into #return(result)values('GO')

	insert into #return(result)values('--if you are in the wrong database, you will end up with an open transaction as the error handler')
	insert into #return(result)values('--will not pick up a schema error, so here we check the transaction count and rollback if above 0')
	insert into #return(result)values('--this will only happen in query analyzer as the connection would stay alive.')
	insert into #return(result)values('if @@trancount<>0 rollback')	
	insert into #return(result)values('GO')

	--turn the triggers back on
	insert into #return(result)values('ALTER TABLE [' + @table_name + '] ENABLE TRIGGER ALL')
	insert into #return(result)values('GO')
	
	
	
	insert into #return(result)values('SET NOCOUNT OFF')
	insert into #return(result)values('GO')
	insert into #return(result)values('')

	--get rid of the dashes
	delete from #return where result like '-----%'
	
	select ' '=result from #return order by order_number
end
else
	select ''


if object_id('tempdb..##values') IS NOT NULL
drop table ##values

if object_id('tempdb..#return') IS NOT NULL
drop table #return




SET NOCOUNT OFF
RETURN 0 --Success. We are done!
END

GO

PRINT 'Created the procedure'
GO

--Run the following commands ONLY if you want this procedure to
--work from Master database, just like any other system procedure. But
--the following commands modify a system table. If you don't want that, 
--then don't run these commands (in this case, you will have to first 
--create this procedure in the database, before using it on that database's
--tables. So you will end up creating this same procedure on all the databases
--for which you want to generate insert scripts

sp_configure 'allow', 1							     
GO									     
RECONFIGURE WITH OVERRIDE						     
GO									     
UPDATE sysobjects SET status=-2147483647 WHERE name = 'sp_create_insert_statements'  
GO									     
sp_configure 'allow', 0							     
GO									     
RECONFIGURE WITH OVERRIDE					             
GO	

SET NOCOUNT OFF
GO

PRINT 'Done' 