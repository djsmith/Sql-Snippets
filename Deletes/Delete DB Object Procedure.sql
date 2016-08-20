USE master
GO

IF OBJECT_ID(N'dbo.sp_DropDatabaseObject') IS NOT NULL BEGIN
	DROP PROCEDURE dbo.sp_DropDatabaseObject 
END
GO

CREATE PROCEDURE dbo.sp_DropDatabaseObject 
	@pSchemaName VARCHAR(100) -- the schema the object belongs to, when applicable
	,@pObjectName sysname -- name of the object to drop, including schema (i.e. dbo.TableName)
	,@pObjectType CHAR(2) -- type of object to be dropped. 
	-- Can be 'U', 'V', 'P', 'FN', 'I' (for table, view, procedure, function, and index)
AS

----------------------------------------------------------------------------
-- Declarations
----------------------------------------------------------------------------
DECLARE -- Standard declares
	@FALSE TINYINT -- Boolean false.
	,@TRUE TINYINT -- Boolean true.
	,@ExitCode INT -- Return value of this procedure.
	,@rc INT -- Return code from a called SP.
	,@Error INT -- Store error codes returned by statements and procedures (@@error).
	,@RaiseMessage VARCHAR(1000) -- Creates helpful message to be raised when running.

DECLARE -- sp specific declares
	@SingleQuote NCHAR(1)
	,@SQL NVARCHAR(4000)
	,@IndexTableName VARCHAR(50)
	,@IndexIndexName VARCHAR(50)

----------------------------------------------------------------------------
-- Initializations
----------------------------------------------------------------------------
SELECT -- Standard constants
	@FALSE = 0
	,@TRUE = 1
	,@ExitCode = 0
	,@rc = 0
	,@Error = 0
	,@SingleQuote = CHAR(39)

----------------------------------------------------------------------------
-- Validate that all objects have an appropriate ObjectType
----------------------------------------------------------------------------
IF @pObjectType NOT IN ('U', 'V', 'P', 'FN', 'I') BEGIN
	SELECT @RaiseMessage = 'Invalid ObjectType value: ' + @pObjectType
	GOTO ErrorHandler
END

----------------------------------------------------------------------------
-- Put together the SQL to drop the database object
----------------------------------------------------------------------------
IF @pObjectType = 'U' BEGIN
	IF EXISTS (SELECT * FROM sys.objects WHERE name = @pObjectName AND TYPE = @pObjectType AND SCHEMA_ID = SCHEMA_ID(@pSchemaName) ) BEGIN
		-- The table exists, prepare to delete it
		SELECT @SQL = 'Drop table ' + @pSchemaName + '.' + @pObjectName 
	END 
	ELSE BEGIN
		SELECT @RaiseMessage = 'Table ' + @pObjectName + ' does not exist or has already been deleted'
		PRINT @RaiseMessage
		GOTO ExitProc
	END
END

IF @pObjectType = 'V' BEGIN
	IF EXISTS (SELECT * FROM sys.objects WHERE name = @pObjectName AND TYPE = @pObjectType AND SCHEMA_ID = SCHEMA_ID(@pSchemaName) ) BEGIN
		-- The view exists, prepare to delete it
		SELECT @SQL = 'Drop view ' + @pSchemaName + '.' + @pObjectName 
	END 
	ELSE BEGIN
		SELECT @RaiseMessage = 'View ' + @pObjectName + ' does not exist or has already been deleted'
		PRINT @RaiseMessage
		GOTO ExitProc
	END
END

IF @pObjectType = 'P' BEGIN
	IF EXISTS (SELECT * FROM sys.objects WHERE name = @pObjectName AND TYPE = @pObjectType AND SCHEMA_ID = SCHEMA_ID(@pSchemaName) ) BEGIN
		-- The procedure exists, prepare to delete it
		SELECT @SQL = 'Drop procedure ' + @pSchemaName + '.' + @pObjectName 
	END 
	ELSE BEGIN
		SELECT @RaiseMessage = 'Procedure ' + @pObjectName + ' does not exist or has already been deleted'
		PRINT @RaiseMessage
		GOTO ExitProc
	END
END

IF @pObjectType = 'FN' BEGIN
	IF EXISTS (SELECT * FROM sys.objects WHERE name = @pObjectName AND TYPE = @pObjectType AND SCHEMA_ID = SCHEMA_ID(@pSchemaName) ) BEGIN
		-- The function exists, prepare to delete it
		SELECT @SQL = 'Drop function ' + @pSchemaName + '.' + @pObjectName 
	END 
	ELSE BEGIN
		SELECT @RaiseMessage = 'Function ' + @pObjectName + ' does not exist or has already been deleted'
		PRINT @RaiseMessage
		GOTO ExitProc
	END
END

IF @pObjectType = 'I' BEGIN
	-- Parse out the table/index names to be able to test for index existance easily
	SELECT @IndexTableName = SUBSTRING(@pObjectName, 1, CHARINDEX('.', @pObjectName) - 1) 
	SELECT @IndexIndexName = SUBSTRING(@pObjectName, CHARINDEX('.', @pObjectName) + 1, 50 )
	IF INDEXPROPERTY(OBJECT_ID(@IndexTableName),@IndexIndexName,'IndexID') IS NOT NULL BEGIN
		-- Check first whether it's a primary key
		IF EXISTS (SELECT * FROM sys.indexes 
					WHERE is_primary_key = @TRUE AND OBJECT_NAME(OBJECT_ID) = @IndexTableName AND name = @IndexIndexName) BEGIN
			SELECT @SQL = 'Alter table ' + @pSchemaName + '.' + @IndexTableName + ' drop constraint ' + @IndexIndexName
		END
		ELSE BEGIN
			SELECT @SQL = 'Drop Index ' + @pSchemaName + '.' + @pObjectName 
		END
	END
	ELSE BEGIN
		SELECT @RaiseMessage = 'Index ' + @pObjectName + ' does not exist or has already been deleted'
		PRINT @RaiseMessage
		GOTO ExitProc
	END 
END

----------------------------------------------------------------------------
-- Drop the database object
----------------------------------------------------------------------------
IF @SQL IS NOT NULL BEGIN
	EXEC @RC = sp_executesql @sql
	SELECT @Error = @@ERROR
	IF @Error <> 0 OR @RC <> 0 BEGIN
		SELECT @RaiseMessage = 'Error dropping object : ' + @pObjectName + ' using sql statement: ' + @SQL
		GOTO ErrorHandler 
	END
	SELECT @RaiseMessage = 'Completed dropping object: ' + @pObjectName + ' using sql statement: ' + @SQL
	PRINT @RaiseMessage
END

GOTO ExitProc

----------------------------------------------------------------------------
-- Error Handler
----------------------------------------------------------------------------
ErrorHandler:
	SELECT @ExitCode = -100

	-- Print the Error Message now that will kill isql.
	RAISERROR (
	@RaiseMessage
	,16 -- Severity.
	,1 -- State.
	)

	GOTO ExitProc

----------------------------------------------------------------------------
-- Exit Procedure
----------------------------------------------------------------------------
ExitProc:
	RETURN (@ExitCode)

GO

-- Marks it as a system object. Otherwise, it may return object information from the master database instead of the calling database
EXEC sys.sp_MS_marksystemobject sp_DropDatabaseObject
GO

 