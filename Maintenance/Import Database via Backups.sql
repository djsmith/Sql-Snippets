SET QUOTED_IDENTIFIER OFF
GO
use Filer
go
IF EXISTS (SELECT name FROM sysobjects WHERE name = 'spF_build_import' AND type = 'P' )
    DROP PROC spF_build_import
GO
CREATE procedure spF_build_import
@sourcedbserver	sysname = ''
,@dbname	sysname	= ''
,@newdbname	sysname = ''
,@targetdir 	varchar(255) = ''
,@runrestore 	char(1) = 'N'
,@overwritedb	char(1) = 'N'
,@checkbackup	char(1) = 'Y'
,@ok 		int OUTPUT
AS
-- INPUT PARAMETERS
-----------------------------------------------------------------------------------------------------------
-- @sourcedbserver	:  	This is the source server where the database(s) are imported from.
-- 			   	Source server must be a linked server on the local importing server.
--				Database must have been backed up to different server (UNC-path).
-----------------------------------------------------------------------------------------------------------
-- @dbname  		:  	If blank, all dbs are imported, except master, model, msdb and tempdb.
-----------------------------------------------------------------------------------------------------------
-- @newdbname  		:  	If @dbname is not blank, imported database can be renamed on target.
--			   	Database file names will also be renamed with 'IMP_' prefix.
-----------------------------------------------------------------------------------------------------------
-- @targetdir  		:  	Database directory on target server.
--			   	If parameter value is blank, it will default to SQL Server Default
--			   	Data Directory. If Default Data Directory is NULL, SP will abort.
-----------------------------------------------------------------------------------------------------------
-- @runrestore		:  	Enter Y to run import on target (current) server or N (default)
--			   	to generate import script. Run import is not allowed to self.
--			   	Check is built in.
-----------------------------------------------------------------------------------------------------------
-- @overwritedb		:  	Enter Y to overwrite all databases with the same name or N if you don't
--				want overwrite. Check is built in. RESTORE with REPLACE will only be
--				generated or executed if you specify @overwritedb = 'Y'.
-----------------------------------------------------------------------------------------------------------
-- @checkbackup		:	Check existence of backup files with UNC-path on backup server.
--				Default is Y for yes check. Enter N to skip check if you want to be able
--				to generate script when target server is running on an account without
--				access to backup the files. Script info from msdb system tables is
--				selected using the privileges of the linked server account. Note that
--				in order to actually run the generated script, you must have access
--				to the backup files with the account that is running SQL Server.
-----------------------------------------------------------------------------------------------------------
-- OUTPUT PARAMETER
-----------------------------------------------------------------------------------------------------------
-- @ok			:  	Returns 0 on success or 1 on failure.
-----------------------------------------------------------------------------------------------------------
--
-- DOCUMENTATION
-----------------------------------------------------------------------------------------------------------
-- Import database from source server using full and transaction log backups as recorded in msdb. Use it to
-- import one or more databases to your development environment, to test your backups regularly or to move
-- databases to a new server.
-----------------------------------------------------------------------------------------------------------
-- To move to a new server, take a transaction log backup and put all in read only mode on the source
-- server, then run this SP on the target server with the source server name as an input parameter.
-----------------------------------------------------------------------------------------------------------
-- Import one or all databases. Generate import scripts or run import at once. Existence or access to
-- backup files will be verified.
-----------------------------------------------------------------------------------------------------------
-- Run your destination SQL Server with an NT-account with privileges on the server with the backup files.
-----------------------------------------------------------------------------------------------------------
-- Link source server using an account that is allowed to read msdb system tables on source server.
-----------------------------------------------------------------------------------------------------------
-- Run this SP on target server where dbs are to be imported.
-----------------------------------------------------------------------------------------------------------
-- This SP can be put in any DB, Filer is the DBA database at our site.
-----------------------------------------------------------------------------------------------------------
-- Works on SQL 7 and SQL 2000 with native and/or LiteSpeed full backups and native transaction log backup.
-----------------------------------------------------------------------------------------------------------
--
-- REQUIREMENTS
-- ********************************************************************************************************
-- * BUILD AND IMPORT REQUIRES THAT ALL FULL BACKUPS ARE ZIPPED WITH SQL LITESPEED (FILE EXTENSION .ZBAK) *
-- * OR WITH NATIVE BACKUP. TRANS LOG BACKUPS ARE ALWAYS NATIVE BACKUPS. REQUIRES THAT ALL BACKUPS ARE    *
-- * KEPT ON DISK. REMEMBER TO KEEP ALL TRANSACTION LOG BACKUPS SINCE LAST TOTAL BACKUP AVAILABLE ON DISK.*
-- * DATABASES BACKUPS ON SOURCE SERVER MUST HAVE BEEN MADE TO A SHARED UNC-PATH, E.G. ON A BACKUP SERVER.*
-- ********************************************************************************************************
--
-- LIMITATIONS
-- ********************************************************************************************************
-- * Works only for restore from disk, preferably from a backup server.                                   *
-- * Only one target disk can be referenced. Works with native and/or LiteSpeed full backups and native   *
-- * transaction log backups, NOT with differential backups. Works best if you have a backup server.      *
-- * Databases master, model, msdb, tempdb, Northwind and pubs are always excluded from import when 	  *
-- * @dbname is not specified. If one of them is specified, commented (/*---*/) scripts are generated.    *
-- * Replicated databases are excluded from import. Restoring backups of replicated databases to a        *
-- * different server or database requires special considerations. For this reason, replicated databases  *
-- * are automatically excluded for import. Logging of excluded replicated databases is made to output.   *
-- ********************************************************************************************************
--
-- EXAMPLES
-----------------------------------------------------------------------------------------------------------
-- Import a database named 'ARKIV4706' from a source server named 'XXVIS009DB', run an immediate restore
-- with REPLACE of an eventually existing database with the same name on the target server, place the
-- database files in the SQL Server Default Data Directory on the target server and check for the
-- existence of the backup files for 'ARKIV4706':
/*
DECLARE @rc int
exec Filer.dbo.spF_build_import 'XXVIS009DB','ARKIV4706','','','Y','Y','Y',@ok = @rc OUTPUT
*/
-----------------------------------------------------------------------------------------------------------
-- Use a database named 'Filer' from a source server named 'XXVIS009DB', rename it to 'Test' on the
-- target server, generate a restore script that will REPLACE any existing database with the name 'Test',
-- place the database files in a directory named 'D:\Databases' on the target server and check for the
-- existence of the backup files for 'Filer':
/*
DECLARE @rc int
exec Filer.dbo.spF_build_import 'XXVIS009DB','Filer','Test','D:\Databases','N','Y','Y',@ok = @rc OUTPUT
*/
-----------------------------------------------------------------------------------------------------------
-- Use all databases except master, model, msdb, Northwind and pubs from a source server named
-- 'XXVIS009DB', generate a restore script that does not overwrite any existing databases, locate the
-- database files in the SQL Server Default Data Directory on the target server and check for the
-- existence of backup files.
/*
DECLARE @rc int
exec Filer.dbo.spF_build_import 'XXVIS009DB','','','','N','N','Y',@ok = @rc OUTPUT
*/
-----------------------------------------------------------------------------------------------------------
-- Use a database named 'Apps' from on the current server, generate a restore script with REPLACE of the
-- existing database with the same name on the current server, place the database files in the SQL Server
-- Default Data Directory on the server and check for the  existence of the backup files for 'Apps':
/*
DECLARE @rc int
exec Filer.dbo.spF_build_import '','Apps','','','N','Y','Y',@ok = @rc OUTPUT
*/
-- Note that only script generation is supported, when source is same as target, as in the example above.
-----------------------------------------------------------------------------------------------------------
--
-- BACKGROUND
-----------------------------------------------------------------------------------------------------------
-- This stored procedure is based on one that was originally written by Greg Larsen for
-- Washington State Department of Health, USA. Date of original: 12/16/2001
-- I found it at http://www.sqlservercentral.com - thank you Greg!
-- Modified: By Lennart Gerdvall, Faktab Finans AB, Visby, Sweden.
-- Dates: 2002-11-07, 2005-06-10, 2006-06-16
-- Greg Larsens SP was designed to help rebuilding a crashed database server.
-- The original SP has been re-written to a great extent in order to allow creation of script on a
-- database source server and execution of a restore script including transaction log backups on a
-- target server to allow for easy import of databases from a running source server to a target server.
-- Use SP when moving to a new server in production or importing databases to a development server.
-- This SP generates or runs TSQL script that will restore one or all the databases specified, to the
-- current SQL Server (target server). This SP takes into account when the last full backup was taken
-- on the source server and all succeeding transaction log backups taken on the source server since
-- the last database backup, based on the information in the source servers msdb database.
-----------------------------------------------------------------------------------------------------------
--
-- CHANGES
-- ********************************************************************************************************
-- Modified to include several backup files for one database.
-- Modified to include MOVE to logical and physical file.
-- Skipped restore of diff backups - we don't do that kind.
-- Added input/output for one database, target directory and source server.
-- Added option to print script or to run restore script. DEFAULT IS PRINT SCRIPT.
-- Blank target directory will use SQL Server Default Data Directory. If this also is blank, SP will stop
-- before doing anything.
-- Added check for existence of backup files on backup server.
-- Added check for existence of target directory.
-- Added option to change database name on target server. If this option is selected, database file names
-- will be preceeded by the prefix 'IMP_<new database name>_' to minimize the risk of of overwriting files.
-- Added option to control overwrite of databases. Default is NO OVERWRITE (N).
-- Added option to disable check of existence of backup files.
-- Added check of target disk size. No import is made if database takes more than 90 % of available space.
-- Added check for existence of named database on source server.
-- Added check for existence of a full backup for the current database.
-- Added check of attempt to import replicated databas. This is not allowed.
-- Added space of replaced database files on target drive, when calculating available disk space on target.
--
-----------------------------------------------------------------------------------------------------------
-- INITS, DECLARATIONS AND CHECKS
-----------------------------------------------------------------------------------------------------------
-- Cleanup temp tables
IF OBJECT_ID('tempdb..#sourcebackups') IS NOT NULL DROP TABLE #sourcebackups
IF OBJECT_ID('tempdb..#FileExists') IS NOT NULL DROP TABLE #FileExists
IF OBJECT_ID('tempdb..#DriveSpace') IS NOT NULL DROP TABLE #DriveSpace

SET QUOTED_IDENTIFIER OFF
SET NOCOUNT ON
SET ANSI_NULLS OFF
SET @ok = 0

-- Variables used in original SP
DECLARE
	 @cmd 			nvarchar (4000)
 	,@cmd2 			nvarchar (4000)
 	,@db 			varchar(128)
 	,@filename 		varchar(4000)
 	,@cnt 			int
 	,@num_processed 	int
 	,@name 			varchar(4000)
	,@phys  		varchar(4000)
 	,@physical_device_name 	varchar(512)
 	,@backup_start_date 	datetime
 	,@type 			char(1)

-- Variables added by LGE
DECLARE
	 @omvand 		varchar(500)
	,@slashpos 		integer
	,@mypartlen 		integer
	,@mydir 		varchar(200)
	,@fyspath 		varchar(500)
	,@backupid 		int
	,@devcount 		int
	,@valcount 		int
 	,@mybackupfile		varchar(8000)
	,@SSQL 			varchar(8000)
	,@SQLMOVE 		varchar(8000)
	,@SQLFULL 		varchar(8000)
	,@myHeader		varchar(400)
 	,@logical_name 		nvarchar(4000)
	,@physical_name 	nvarchar(4000)
	,@logdevcount 		int
	,@logvalcount		int
	,@zipped		varchar(2)	-- N or Y
	,@remotedbcursorsql	varchar(500)
	,@currentbackupstart	datetime
	,@thepos 		int
	,@default_data_dir 	varchar(255)
	,@sqlphysical		nvarchar(2000)
	,@parmdefdevice 	nvarchar(200)
	,@sqlbackupid		nvarchar(2000)
	,@parmdefbackupid 	nvarchar(200)
	,@returnrow		int		-- General rowcounter
	,@ret             	int		-- Return code for SP
	,@user            	sysname         -- Current user
	,@comment		varchar(3)	-- Comment prints
	,@logbakfilename	varchar(512)	-- Test of transaction log file backup name
	,@customerrmess		varchar(500)    -- Keeps my customized error messages.
	,@quotesql		varchar(100)	-- To SET QUOTED_IDENTIFIER OFF
	,@mydbsize 		NUMERIC(18,2)
	,@getdbsize 		NVARCHAR(1000)
	,@currdbsize		INT
	,@parmdefdbsize 	nvarchar(200)
	,@StatusReport 		varchar(1000)
	,@DirName 		varchar(255)
	,@spacelimit 		NUMERIC(5,2)
	,@dbspace  		NUMERIC(5,2)
	,@numdb			INT
	,@sqlnumdb		NVARCHAR(200)
	,@parmsnumdb		NVARCHAR(50)
	,@ispublished		INT
	,@sqlpublisheddb	NVARCHAR(200)
	,@parmspublisheddb	NVARCHAR(50)
	,@publtype		VARCHAR(50)
	,@mydbsizetarget 	NUMERIC(18,2)
	,@getdbsizetarget 	NVARCHAR(1000)
	,@currdbsizetarget	INT
	,@parmdefdbsizetarget 	nvarchar(200)


SET @user = SUSER_SNAME()
SET @ret = 0
SET @quotesql = 'SET QUOTED_IDENTIFIER OFF'

-- Check if current user is sysadmin
IF IS_SRVROLEMEMBER('sysadmin') = 0
BEGIN
	SET @customerrmess = 'The current user %s is not a member of the sysadmin role on ' + @@servername
	RAISERROR(@customerrmess,16,1)
	SET @ret = 1
	GOTO CLEANUP
END

-- Disallow multiple rename of databases
IF (@dbname = '' AND @newdbname > '' )
BEGIN
	SET @customerrmess = 'You are not allowed to rename multiple databases for import to target server'
	RAISERROR(@customerrmess,16,1)
	SET @ret = 1
	GOTO CLEANUP
END

-- Check input parameter for running import or generating import script
SET @runrestore = UPPER(@runrestore)
IF (@runrestore <> 'Y' AND @runrestore <> 'N' )
BEGIN
	SET @customerrmess = 'Enter Y to restore database to target server or N to generate script for restore'
	RAISERROR(@customerrmess,16,1)
	SET @ret = 1
	GOTO CLEANUP
END
ELSE
BEGIN
	-- Comment information output if script is generated
	IF @runrestore = 'Y' SET @comment = '' ELSE SET @comment = '-- '
END

-- Check input parameter for overwriting database or not
SET @overwritedb = UPPER(@overwritedb)
IF (@overwritedb <> 'Y' AND @overwritedb <> 'N' )
BEGIN
	SET @customerrmess = 'Enter Y to overwrite database on target server or N to avoid overwriting'
	RAISERROR(@customerrmess,16,1)
	SET @ret = 1
	GOTO CLEANUP
END

-- Check input parameter for checking existence of database backup files or not
SET @checkbackup = UPPER(@checkbackup)
IF (@checkbackup <> 'Y' AND @checkbackup <> 'N' )
BEGIN
	SET @customerrmess = 'Enter Y for checking existence of database backup files or N to skip check'
	RAISERROR(@customerrmess,16,1)
	SET @ret = 1
	GOTO CLEANUP
END

-- If this is an import from last backup on current server to itself, do not allow run, only script generation
IF ((@sourcedbserver = '' OR @sourcedbserver = @@servername) AND @runrestore = 'Y')
BEGIN
	SET @customerrmess = 'Only script generation is supported for self import to ' + @@servername + ' - change parameter @runrestore to N'
	RAISERROR(@customerrmess,16,1)
	SET @ret = 1
	GOTO CLEANUP
END

-- Check existence of the linked server where you want to import the database(s) from
IF @sourcedbserver > ''
BEGIN
	SELECT @returnrow = count(srvname) from master..sysservers where srvname = @sourcedbserver
	IF @returnrow = 0
	BEGIN
		SET @customerrmess = 'This is not a linked server on ' + @@servername + ' - this is a requirement'
		RAISERROR(@customerrmess,16,1)
		SET @ret = 1
		GOTO CLEANUP
	END
END

-- Headlines
BEGIN
IF @sourcedbserver > ''
     SELECT @myHeader = @comment + 'Import of databases to SQL Server ' + @@SERVERNAME + ' created from msdb on ' + UPPER(@sourcedbserver) + ' at ' + convert(varchar(30),Getdate(),120)
ELSE
     SELECT @myHeader = @comment + 'Import of databases to SQL Server ' + @@SERVERNAME + ' created from msdb on LOCAL server at ' + convert(varchar(30),Getdate(),120)
END

-- Fix the input parameter @sourcedbserver and add '[servername].' to allow reference to linked tables
IF @sourcedbserver > '' SET @sourcedbserver = '[' + @sourcedbserver + '].'

-- Do we have a database on the source server?
IF @dbname > ''
BEGIN
	SET @parmsnumdb = N'@pnumdb INT output'
	SET @sqlnumdb = N'SELECT @pnumdb = COUNT(name) FROM ' + @sourcedbserver + '[master].[dbo].[sysdatabases] WHERE name = '+ CHAR(39) + @dbname + CHAR(39)

	-- Do a database count on source server
	EXECUTE sp_executesql @sqlnumdb, @parmsnumdb, @pnumdb = @numdb output
	IF @numdb = 0
	BEGIN
		IF @sourcedbserver = '' SET @customerrmess = 'Source database ' + @dbname + ' was not found on SQL Server ' + @@servername
		ELSE SET @customerrmess = 'Source database ' + @dbname + ' was not found on SQL Server ' + @sourcedbserver
		RAISERROR(@customerrmess,16,1)
		SET @ret = 1
		GOTO CLEANUP
	END
END

-- Fix the input parameter @targetdir if no target directory is specified. Get it from the registry if defined.
IF @targetdir = ''
BEGIN
	EXECUTE master..xp_regread 'HKEY_LOCAL_MACHINE','SOFTWARE\Microsoft\MSSQLServer\MSSQLServer','DefaultData',@default_data_dir OUTPUT
	IF @default_data_dir IS NULL
	BEGIN
		SET @customerrmess = 'Missing value for SQL Server Default Data Directory on LOCAL Server ' + @@servername + ' - specify a target directory'
		RAISERROR(@customerrmess,16,1)
		SET @ret = 1
		GOTO CLEANUP
	END
	ELSE
	BEGIN
		SELECT @targetdir = @default_data_dir
	END
END

--- Put an ending backslash for @targetdir if missing
IF @targetdir > ''
BEGIN
	SELECT @thepos = CHARINDEX ( '\' , REVERSE(@targetdir), 1)
	IF @thepos > 1  or @thepos = 0
	BEGIN
		SELECT @targetdir = @targetdir + '\'
	END
END

-- Create table for file and directory existence test, in order to suppress row message from exec master..xp_fileexist
Create Table #FileExists (File_Exists INT,File_is_a_Directory INT,Parent_Directory_Exists INT )

-- Check existence of target directory
IF @targetdir > ''
BEGIN
	-- Check existence of target directory on server
	-- PRINT @comment + 'Checking existence of target directory ' + @targetdir + ' on server ' + @@servername
	INSERT INTO #FileExists exec master..xp_fileexist @targetdir
	IF NOT EXISTS (Select * From #FileExists Where File_is_a_Directory = 1)
	BEGIN
		SET @customerrmess = 'Target directory ' + @targetdir + ' does not exist on server ' + @@servername
		RAISERROR(@customerrmess,16,1)
		SET @ret = 1
		GOTO CLEANUP
	END
	-- Empty file existence table
	TRUNCATE TABLE #FileExists
END
ELSE
BEGIN
	SET @customerrmess = 'Target directory has not been specified on server ' + @@servername
	RAISERROR(@customerrmess,16,1)
	SET @ret = 1
	GOTO CLEANUP
END
-----------------------------------------------------------------------------------------------------------
-- SECTION 1, GET DATA ON BACKUPS FROM MSDB
-----------------------------------------------------------------------------------------------------------
-- DECLARE database cursor
DECLARE @dbcursor CURSOR
DECLARE @mysetcursor nvarchar(1000)

-- Set SELECT for database cursor
IF @dbname = ''
	SET @remotedbcursorsql = 'SELECT name from ' + @sourcedbserver + 'master.dbo.sysdatabases
	where name not in (''' + 'master' + ''',''' + 'model' + ''',''' + 'msdb' + ''',''' + 'tempdb' + ''',''' + 'Northwind' + ''',''' + 'pubs' + ''') order by name asc'
ELSE
	SET @remotedbcursorsql = 'SELECT name from ' + @sourcedbserver + 'master.dbo.sysdatabases where name = ''' + @dbname + ''''

-- Open cursor containing list of database names.
SET @mysetcursor = 'SET @dbcursor = CURSOR FOR ' + @remotedbcursorsql + ' FOR READ ONLY; OPEN @dbcursor'
EXEC sp_executesql @mysetcursor,N'@dbcursor cursor OUTPUT', @dbcursor OUTPUT

-- Headings and settings
IF UPPER(@runrestore) = 'Y' EXEC(@quotesql)
ELSE
BEGIN
	PRINT (@myHeader)
	PRINT REPLICATE('-',LEN(@myHeader))
	PRINT @quotesql + CHAR(13) + 'GO'
END

-- Create a global temporary table that will hold the name of the backup, the database name, and the type of database backup.
CREATE table #sourcebackups (id int IDENTITY(1,1) PRIMARY KEY CLUSTERED, name nvarchar(255), database_name nvarchar(50), type char(1), phys nvarchar(3500), start datetime NULL)
SET IDENTITY_INSERT #sourcebackups OFF

FETCH next from @dbcursor into @db
-- Process until no more databases are left
WHILE @@FETCH_STATUS = 0
BEGIN
-----------------------------------------------------------------------------------------------------------
-- Subsection 1A: FULL BACKUPS
-----------------------------------------------------------------------------------------------------------
	-- Check if the database is replicated - do not allow import of replicated databases.
	SET @parmspublisheddb = N'@pispublished INT output'
	SET @sqlpublisheddb = N'SELECT @pispublished = category FROM ' + @sourcedbserver + '[master].[dbo].[sysdatabases] WHERE name = ' + CHAR(39) + @db + CHAR(39)

	-- If replicated, @ispublished will be 1 = Published, 2 = Subscribed, 4 = Merge Published or 8 = Merge Subscribed.
	-- Note: Other category values in SQL 7 - e.g. 5 is transactional replication.
	EXECUTE sp_executesql @sqlpublisheddb, @parmspublisheddb, @pispublished = @ispublished output
	IF @ispublished > 0
	BEGIN
		IF @ispublished = 1 SET @publtype = 'Published'
		ELSE IF @ispublished = 2 SET @publtype = 'Subscribed'
		ELSE IF @ispublished = 4 SET @publtype = 'Merge Published'
		ELSE IF @ispublished = 8 SET @publtype = 'Merge Subscribed'
		ELSE SET @publtype = 'Unknown Publication Type'
		IF @sourcedbserver = '' SET @customerrmess = 'Source database ' + @db + ' is a replication database (' + @publtype + ') on SQL Server ' + @@servername + CHAR(13) + 'It will be excluded from import'
		ELSE SET @customerrmess = 'Source database ' + @db + ' is a replication database (' + @publtype + ') on SQL Server ' + @sourcedbserver + CHAR(13) + 'It will be excluded from import'
		RAISERROR(@customerrmess,1,1)
		SET @ret = 0
		GOTO GETNEXTDB
	END

	-- Check if overwrite is allowed or not, unless you want script only
	IF (UPPER(@overwritedb) = 'N' and UPPER(@runrestore) = 'Y')
	BEGIN
		IF @newdbname > ''
		BEGIN
			IF EXISTS (Select name From master..sysdatabases WHERE name = @newdbname)
			BEGIN
				SET @customerrmess = 'New database ' + @newdbname + ' already exists on target server ' + @@servername + ', change the @overwritedb parameter to Y to overwrite'
				RAISERROR(@customerrmess,16,1)
				SET @ret = 1
				GOTO CLEANUP
			END
		END
		ELSE
		BEGIN
			IF EXISTS (Select name From master..sysdatabases WHERE name = @db)
			BEGIN
				SET @customerrmess = 'Database ' + @db + ' already exists on target server ' + @@servername + ', change the @overwritedb parameter to Y to overwrite'
				RAISERROR(@customerrmess,16,1)
				SET @ret = 1
				GOTO CLEANUP
			END
		END
	END

	SET @parmdefbackupid = N'@pbackupid int output,@pbackup_start_date datetime output'

	-- Get ID and time of last full backup.
	SET @sqlbackupid =
	N'SELECT @pbackupid =
	MAX(bs.backup_set_id),
	@pbackup_start_date =
	MAX(bs.backup_start_date)
	FROM ' + @sourcedbserver + 'msdb.dbo.backupset as bs ' +
	'INNER JOIN ' +
	@sourcedbserver + 'msdb.dbo.backupfile as bf ON
	bs.backup_set_id = bf.backup_set_id
	WHERE
	bs.type = ''' + 'D' + ''' and bs.database_name = ''' + @db + ''''

	EXECUTE sp_executesql @sqlbackupid, @parmdefbackupid, @pbackupid = @backupid output, @pbackup_start_date = @backup_start_date output

	-- Did a full database backup name get found?
	IF @backupid IS NULL
	BEGIN
		SET @customerrmess = @comment + 'A full backup is missing for source database ' + @db + '. Backup database before running import'
		RAISERROR(@customerrmess,16,1)
		SET @ret = 1
		GOTO CLEANUP
	END

	-- Get size of database on source server, check for disk space on target server
	SET @parmdefdbsize = N'@pmydbsize NUMERIC(18,2) output'
	SET @getdbsize = N'SELECT @pmydbsize = (SUM(size)/128.0) FROM ' + @sourcedbserver + '[' + @db + '].[dbo].[sysfiles]'
	EXECUTE sp_executesql @getdbsize, @parmdefdbsize, @pmydbsize = @mydbsize output
	SET @currdbsize = CAST(@mydbsize AS INT)

	-- Get the drive letter from the target directory
	set @DirName = SUBSTRING(@targetdir,1,1)
	set @StatusReport = ''

	-- Allow use of max 90% of available space on target disk
	set @spacelimit = 0.9

	-- Get size of an existing database on the target server that is to be replaced
	-- If there is one, add size in @currdbsizetarget to @dbspace since we drop the old one
	SET @currdbsizetarget = 0
	IF (@dbname > '' AND @newdbname > '')
	BEGIN
		IF EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE name = @newdbname)
		BEGIN
			-- Get total filesize of database in target directory on target server
			SET @parmdefdbsizetarget = N'@pmydbsizetarget NUMERIC(18,2) output'
			SET @getdbsizetarget = N'SELECT @pmydbsizetarget = (SUM(size)/128.0) FROM ' +
			'[' + @newdbname + '].[dbo].[sysfiles] ' +
			'WHERE SUBSTRING(filename,1,1) = ' + CHAR(39) + @DirName + CHAR(39)

			-- Get size of database on source server
			EXECUTE sp_executesql @getdbsizetarget, @parmdefdbsizetarget, @pmydbsizetarget = @mydbsizetarget output
			SET @currdbsizetarget = CAST(@mydbsizetarget AS INT)
			PRINT @comment + 'Size of replaced local database files for ' + @newdbname
			+ ' on drive ' + @DirName + ' is ' + CAST(@currdbsizetarget AS VARCHAR(30)) + ' MB'
		END
	END
	ELSE IF (@dbname > '' AND @newdbname = '')
	BEGIN
		IF EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE name = @dbname)
		BEGIN
			-- Get total filesize of database in target directory on target server
			SET @parmdefdbsizetarget = N'@pmydbsizetarget NUMERIC(18,2) output'
			SET @getdbsizetarget = N'SELECT @pmydbsizetarget = (SUM(size)/128.0) FROM ' +
			'[' + @dbname + '].[dbo].[sysfiles] ' +
			'WHERE SUBSTRING(filename,1,1) = ' + CHAR(39) + @DirName + CHAR(39)

			-- Get size of database on target server
			EXECUTE sp_executesql @getdbsizetarget, @parmdefdbsizetarget, @pmydbsizetarget = @mydbsizetarget output
			SET @currdbsizetarget = CAST(@mydbsizetarget AS INT)
			PRINT @comment + 'Size of replaced local database files for ' + @dbname
			+ ' on drive ' + @DirName + ' is ' + CAST(@currdbsizetarget AS VARCHAR(30)) + ' MB'
		END
	END
	ELSE
	BEGIN
		IF EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE name = @db)
		BEGIN
			-- Get total filesize of database in target directory on target server
			SET @parmdefdbsizetarget = N'@pmydbsizetarget NUMERIC(18,2) output'
			SET @getdbsizetarget = N'SELECT @pmydbsizetarget = (SUM(size)/128.0) FROM ' +
			'[' + @db + '].[dbo].[sysfiles] ' +
			'WHERE SUBSTRING(filename,1,1) = ' + CHAR(39) + @DirName + CHAR(39)

			-- Get size of database on source server
			EXECUTE sp_executesql @getdbsizetarget, @parmdefdbsizetarget, @pmydbsizetarget = @mydbsizetarget output
			SET @currdbsizetarget = CAST(@mydbsizetarget AS INT)
			PRINT @comment + 'Size of replaced local database files for ' + @dbname
			+ ' on drive ' + @DirName + ' is ' + CAST(@currdbsizetarget AS VARCHAR(30)) + ' MB'
		END
	END

	-- Calculate if there is enough disk space for import of database, as compared to @spacelimit
	IF OBJECT_ID('tempdb..#DriveSpace') IS NULL CREATE TABLE #DriveSpace (DriveName char(1),DriveSpace int)
	TRUNCATE TABLE #DriveSpace
	INSERT INTO #DriveSpace exec master..xp_fixeddrives
	-- Calculate space usage, but add space for database removed
	SELECT @dbspace = (cast(@currdbsize as numeric)/cast((DriveSpace + @currdbsizetarget) as numeric)) from #DriveSpace where DriveName = @DirName
	IF @dbspace > @spacelimit
	BEGIN
		SET @customerrmess = @comment +
			'Not enough disk space to import database ' +
			@db + ', ' +
			CAST((@dbspace * 100) AS VARCHAR(30)) +
			' percent of free disk on ' + @DirName + ' would be used' + CHAR(13) + @comment +
			CAST(@currdbsize AS VARCHAR(20)) + ' MB disk space is required for this database on ' + @targetdir
		IF @runrestore = 'Y'
		BEGIN
			RAISERROR(@customerrmess,16,1)
			SET @ret = 1
			GOTO CLEANUP
		END
		ELSE PRINT @customerrmess
	END
	ELSE
	BEGIN
		SET @StatusReport = @comment +
			'Enough space available to import database ' +
			@db + ', ' +
			CAST((@dbspace * 100) AS VARCHAR(30)) +
			' percent of free disk on ' + @DirName + ' would be used' + CHAR(13) + @comment +
			CAST(@currdbsize AS VARCHAR(20)) + ' MB disk space is required for this database on ' + @targetdir
		PRINT @StatusReport
	END

	-- Print start of import message for current database
	IF @newdbname = ''
	BEGIN
		IF @runrestore = 'Y'
		BEGIN
			PRINT 'Import of database ' + @db + ' has started'
			PRINT 'All files for database ' + @db + ' will be placed in directory ' + @targetdir
		END
		ELSE
		BEGIN
			PRINT @comment + 'Generating script for import of database ' + @db
			PRINT @comment + 'All files for database ' + @db + ' will be placed in directory ' + @targetdir
		END
	END
	ELSE
	BEGIN
		IF @runrestore = 'Y'
		BEGIN
			PRINT 'Import of database ' + @db + ' has started - database is renamed to ' + @newdbname
			PRINT 'All files for renamed database ' + @newdbname + ' will be placed in directory ' + @targetdir
		END
		ELSE
		BEGIN
			PRINT @comment + 'Generating script for import of database ' + @db + ' - database is renamed to ' + @newdbname
			PRINT @comment + 'All files for renamed database ' + @newdbname + ' will be placed in directory ' + @targetdir
		END
	END

	-- Initialize the physical device name and get the device names to builde restore statements.
	SET @physical_device_name = ''
	SET @devcount = 0
	SET @valcount = 1

	SET @parmdefdevice = N'@xphysical_device_name varchar(512) output'

	WHILE	@physical_device_name IS NOT NULL
	BEGIN
		SET @sqlphysical =
		N'SELECT DISTINCT
		@xphysical_device_name = MIN(bfam.physical_device_name)
		FROM
		 ' + @sourcedbserver + 'msdb.dbo.backupset bs INNER JOIN
		 ' + @sourcedbserver + 'msdb.dbo.backupfile bf ON bs.backup_set_id = bf.backup_set_id INNER JOIN
		 ' + @sourcedbserver + 'msdb.dbo.backupmediafamily bfam ON bs.media_set_id = bfam.media_set_id INNER JOIN
		 ' + @sourcedbserver + 'msdb.dbo.backupmediaset bmed ON bs.media_set_id = bmed.media_set_id
		WHERE
		 bs.backup_set_id = ' + cast(@backupid as varchar(50)) + ' AND bfam.physical_device_name > ''' + @physical_device_name + ''''

		EXECUTE sp_executesql @sqlphysical, @parmdefdevice, @xphysical_device_name = @physical_device_name output

		IF @physical_device_name IS NOT NULL
		BEGIN
			-- Check existence of physical full backup file
			-- PRINT @comment + 'Checking existence of physical full backup file ' + @physical_device_name + ' for database ' + @db
			IF UPPER(@checkbackup) = 'Y'
				BEGIN
				INSERT INTO #FileExists exec master..xp_fileexist @physical_device_name
				If NOT EXISTS (Select * From #FileExists Where File_Exists = 1)
				BEGIN
					SET @customerrmess = 'Backup file ' + @physical_device_name + ' does not exist for database ' + @db
					RAISERROR(@customerrmess,16,1)
					SET @ret = 1
					GOTO CLEANUP
				END
				-- Empty file existence table
				TRUNCATE TABLE #FileExists
			END

			-- Keep track of the sequence number of the file in order to generate the correct RESTORE statement
			SET  @devcount = @devcount + @valcount
			IF @devcount = 1
			BEGIN
				-- If extension is 'ZBAK' assume backup is compressed
			     	IF UPPER(RIGHT(@physical_device_name,4)) ='ZBAK'
				BEGIN
					-- Check SQLLitespeed extended procedures are present
					IF NOT EXISTS(SELECT * FROM master.dbo.sysobjects (nolock)
					         WHERE [name] = 'xp_backup_database' AND xtype='X')
					BEGIN
						SET @customerrmess = 'SQLLitespeed is not installed on SQL server instance ' + @@servername + ' - required for zipped backups'
						RAISERROR(@customerrmess,16,1)
						SET @ret = 1
						GOTO CLEANUP
					END
					IF @newdbname > '' SET @SSQL = 'exec master.dbo.xp_restore_database @database = ' + '[' + @newdbname + ']' + CHAR(13) + CHAR(10)
					ELSE SET @SSQL = 'exec master.dbo.xp_restore_database @database = ' + '[' + @db + ']' + CHAR(13) + CHAR(10)

					SELECT @mybackupfile = ',@filename = ' + CHAR(39) + CHAR(39) + @physical_device_name + + CHAR(39) + CHAR(39) + CHAR(13) + CHAR(10)
					SET @SSQL =  @SSQL + @mybackupfile
					SELECT @zipped = 'Y'
				END
				ELSE
				BEGIN
					IF @newdbname > '' SET @SSQL = 'RESTORE DATABASE ' + '[' + @newdbname + ']' + ' FROM ' + CHAR(13) + CHAR(10)
					ELSE SET @SSQL = 'RESTORE DATABASE ' + '[' + @db + ']' + ' FROM ' + CHAR(13) + CHAR(10)

					SELECT @mybackupfile = ' DISK = ' + CHAR(34) + @physical_device_name + CHAR(34) + CHAR(13) + CHAR(10)
					SET @SSQL =  @SSQL + @mybackupfile
					SELECT @zipped = 'N'
				END
			END
			ELSE BEGIN
				-- If extension is 'ZBAK' assume backup is compressed
			     	IF @zipped = 'Y'
				BEGIN
					SELECT @mybackupfile = ',@filename = ' + CHAR(39) + CHAR(39) + @physical_device_name + + CHAR(39) + CHAR(39) + CHAR(13) + CHAR(10)
					SET @SSQL =  @SSQL + @mybackupfile
				END
				ELSE
				BEGIN
					SELECT @mybackupfile = ',DISK = ' + CHAR(34) + @physical_device_name + CHAR(34) + CHAR(13) + CHAR(10)
					SET @SSQL =  @SSQL + @mybackupfile
				END
			END
		END
	END

	-- Initialize the logical and physical file names.
	SET @logical_name = ''
	SET @physical_name = ''
	SET @logdevcount = 0
	SET @logvalcount = 1
	SET @SQLFULL = ''
	SET @SQLMOVE = ''

   	/*Cursor for select of logical and physical files*/
	DECLARE @lognamecursor CURSOR
	DECLARE @logcursorsql varchar(500)
	DECLARE @mysetlogcursor nvarchar(1000)
	SET @logcursorsql = 'SELECT logical_name, physical_name from ' + @sourcedbserver +
	'msdb.dbo.backupfile where backup_set_id = ' + cast(@backupid as varchar(50))

	-- Open cursor containing list of database logical names.
	SET @mysetlogcursor = 'SET @lognamecursor = CURSOR FOR ' + @logcursorsql + ' FOR READ ONLY; OPEN @lognamecursor'
	EXEC sp_executesql @mysetlogcursor,N'@lognamecursor cursor OUTPUT', @lognamecursor OUTPUT

	-- Fetch data from cursor containing list of database backups files for specific database being processed
	FETCH NEXT FROM @lognamecursor INTO @logical_name, @physical_name
	WHILE @@FETCH_STATUS = 0
	BEGIN
	     	BEGIN
			IF @targetdir > '' -- target directory is always not blank
			BEGIN
				-- Put an ending backslash if missing
				SELECT @omvand = REVERSE(@physical_name)
				SELECT @slashpos = PATINDEX('%\%', @omvand)
				SELECT @mypartlen = @slashpos - 1
				IF @newdbname > '' SELECT @physical_name = @targetdir + 'IMP_' + @newdbname + '_' + REVERSE(SUBSTRING(@omvand, 1, @mypartlen))
				ELSE SELECT @physical_name = @targetdir + REVERSE(SUBSTRING(@omvand, 1, @mypartlen))
				IF @newdbname > '' print @comment + 'New file name for renamed database ' + @newdbname + ' is ' + @physical_name
			END

			SET @logdevcount = @logdevcount + @logvalcount
			IF @logdevcount = 1 BEGIN
				-- If extension is 'ZBAK' assume backup is compressed
			     	IF @zipped ='Y' SET @SQLMOVE = 	',@with = ' + CHAR(39) + CHAR(39) + 'MOVE ' + CHAR(34) + @logical_name + CHAR(34) + ' TO ' + CHAR(34) + @physical_name + CHAR(34) + CHAR(39) + CHAR(39) + CHAR(13) + CHAR(10)
				ELSE SET @SQLMOVE = ' MOVE ' + CHAR(34) + @logical_name + CHAR(34) + ' TO ' + CHAR(34) + @physical_name + CHAR(34) + CHAR(13) + CHAR(10)
			END
			ELSE BEGIN
				-- If extension is 'ZBAK' assume backup is compressed
			     	IF @zipped ='Y' SET @SQLMOVE = @SQLMOVE + ',@with = ' + CHAR(39) + CHAR(39) + 'MOVE ' + CHAR(34) + @logical_name + CHAR(34) + ' TO ' + CHAR(34) + @physical_name + CHAR(34) + CHAR(39) + CHAR(39) + CHAR(13) + CHAR(10)
				ELSE SET @SQLMOVE = @SQLMOVE + ',MOVE ' + CHAR(34) + @logical_name + CHAR(34) + ' TO ' + CHAR(34) + @physical_name + CHAR(34) + CHAR(13) + CHAR(10)
			END
		END

	-- Get next logical file to process
	FETCH NEXT FROM @lognamecursor INTO @logical_name, @physical_name
     	END

	SET @cmd = 'insert into #sourcebackups (name,database_name,type,phys,start) SELECT ' +  CHAR(39) + @SSQL + CHAR(39) + ',' + CHAR(39) + @db + CHAR(39) +
	 ',' + CHAR(39) + 'D' + CHAR(39) + ',' + CHAR(39) + @SQLMOVE + CHAR(39) + ',' + CHAR(39) + CAST(@backup_start_date AS VARCHAR(30)) + CHAR(39)

	-- Execute command to place records in table to hold backup names
	-- for all transaction log backups from the last database backup
	EXEC sp_executesql @cmd

     	-- Close and deallocate logical file cursor for current database being processed
     	CLOSE @lognamecursor
     	DEALLOCATE @lognamecursor

-----------------------------------------------------------------------------------------------------------
-- Subsection 1B: LOG BACKUPS
-----------------------------------------------------------------------------------------------------------
	-- Build command to place records in table to hold backup names for all
	-- transaction log backups from the last database backup
	SET @cmd = 'insert into #sourcebackups (name,database_name,type,phys,start) SELECT physical_device_name,' + CHAR(39) + @db + CHAR(39) +
	 ',' + CHAR(39) + 'L' + CHAR(39) +  ',' + CHAR(39) + '' + CHAR(39) +
	 ',backup_start_date from ' + @sourcedbserver + 'msdb.dbo.backupset a join ' + @sourcedbserver + 'msdb.dbo.backupmediaset b on a.media_set_id = b.media_set_id join ' +
	 @sourcedbserver + 'msdb.dbo.backupmediafamily c on a.media_set_id = c.media_set_id ' +
	       ' where type= ' + CHAR(39) + 'L' + CHAR(39) + ' and backup_start_date >  @backup_start_dat and ' +
	 CHAR(39) + @db + CHAR(39) + ' = database_name order by backup_start_date asc'

	-- Execute command to place records in table to hold backup names
	-- for all transaction log backups from the last database backup
	EXEC sp_executesql @cmd,@params=N'@backup_start_dat datetime', @backup_start_dat = @backup_start_date

	-- Check existence of log backup files
	DECLARE trans_file_name cursor local for SELECT name from #sourcebackups where database_name = @db and type = 'L' order by id asc
	-- Open cursor containing list of database transaction log backup files for the specific database being processed
	OPEN trans_file_name
	-- Get first database backup for specific database being processed
	FETCH next from trans_file_name into @logbakfilename
	-- Process until no more log backup files exist for specific database being processed
	WHILE @@FETCH_STATUS = 0
	BEGIN
		-- Check existence of physical transaction log backup file
		-- PRINT @comment + 'Checking existence of physical transaction log backup file ' + @logbakfilename + ' for database ' + @db
		IF UPPER(@checkbackup) = 'Y'
		BEGIN
			INSERT INTO #FileExists exec master..xp_fileexist @logbakfilename
			IF NOT EXISTS (Select * From #FileExists Where File_Exists = 1)
			BEGIN
				SET @customerrmess = 'Transaction log backup file ' + @logbakfilename + ' does not exist for database ' + @db
				RAISERROR(@customerrmess,16,1)
				SET @ret = 1
				GOTO CLEANUP
			END
			-- Empty file existence table
			TRUNCATE TABLE #FileExists
		END

	-- get next log backup file name to process
	FETCH next from trans_file_name into @logbakfilename
	END
	-- close cursor
	CLOSE trans_file_name
	DEALLOCATE trans_file_name

	-- Get next database to process
GETNEXTDB:
FETCH next from @dbcursor into @db
END
-- Close database cursor
CLOSE @dbcursor
-----------------------------------------------------------------------------------------------------------
-- Section 2: BUILD RESTORE SCRIPTS FOR FULL BACKUPS AND TRANSACTION LOG BACKUPS
-----------------------------------------------------------------------------------------------------------
-- Process full backups and transaction logs and build scripts for all databases
open @dbcursor
-- Get first recod from database list cursor
FETCH next from @dbcursor into @db
WHILE @@FETCH_STATUS = 0
BEGIN
     -- Define cursor for all database and log backups for specific database being processed
     -- RESTORE BACKUPS FOR DATABASE ' + @db
     DECLARE backup_name cursor local for SELECT name, type, phys, start from #sourcebackups where database_name = @db order by id asc
	-- Open cursor containing list of database backups for specific database being processed
     OPEN backup_name
     -- Determine the number of different backups available for specific database being processed
     SELECT @cnt = count(*) from #sourcebackups where database_name = @db
     -- Get first database backup for specific database being processed
     FETCH next from backup_name into @physical_device_name, @type, @phys, @currentbackupstart
     -- Set counter to track the number of backups processed
     SET @num_processed = 0
     -- Process until no more database backups exist for specific database being processed
     WHILE @@FETCH_STATUS = 0
     BEGIN
	-- Increment the counter to track the number of backups processed
	  SET @num_processed = @num_processed + 1
	-- Is the number of database backup processed the same as the number of different backups available for DB?
	  IF @cnt = @num_processed
	-- If so, is the type of backup currently being processed a transaction log backup or a full backup?
	    IF @type = 'L'
	    BEGIN
		-- Build restore command to restore the last transaction log
		IF @newdbname > ''
	      		SELECT @cmd = 'RESTORE LOG ' + '[' + RTRIM(@newdbname) + ']' + CHAR(13) +
	              ' FROM DISK = ' + CHAR(39) +
	                rtrim(substring(@physical_device_name,1,len(@physical_device_name))) +
	                CHAR(39) + CHAR(13) + CHAR(10) + ' WITH REPLACE'
		ELSE
	      		SELECT @cmd = 'RESTORE LOG ' + '[' + RTRIM(@db) + ']' + CHAR(13) +
	              ' FROM DISK = ' + CHAR(39) +
	                rtrim(substring(@physical_device_name,1,len(@physical_device_name))) +
	                CHAR(39) + CHAR(13) + CHAR(10) + ' WITH REPLACE'

		SELECT @cmd2 = ''
	    END
	    ELSE
	    BEGIN
		-- Last backup was a full backup, not a transaction log backup (no logbackups exist)
		-- Build restore command to restore the last database backup
			IF @zipped ='Y'
			BEGIN
				IF @overwritedb = 'Y' SELECT @cmd = @physical_device_name + ',@with = ' + CHAR(39) + 'REPLACE, RECOVERY' + CHAR(39) + CHAR(13)
				ELSE SELECT @cmd = @physical_device_name + ',@with = ' + CHAR(39) + 'RECOVERY' + CHAR(39) + CHAR(13)
			END
			ELSE
			BEGIN
				IF @overwritedb = 'Y' SELECT @cmd = @physical_device_name + ' WITH REPLACE, RECOVERY, STATS=1, ' + CHAR(13)
				ELSE SELECT @cmd = @physical_device_name + ' WITH RECOVERY, STATS=1, ' + CHAR(13)
			END
			SELECT @cmd2 = @phys
	    END
	  ELSE
	-- Current backup is not the last backup, so we do a NORECOVERY.
	-- Check if the current backup being processed a transaction log backup or not!
	    IF @type = 'L'
		BEGIN
		-- Build restore command to restore the current transaction backup, with no recovery
			IF @newdbname > ''
			      SELECT @cmd = 'RESTORE LOG ' + '[' + RTRIM(@newdbname) + ']' + CHAR(13) +
			              ' FROM DISK = ' + CHAR(39) +
			               rtrim(substring(@physical_device_name,1,len(@physical_device_name))) +
			                 CHAR(39) + CHAR(13) + ' WITH REPLACE, NORECOVERY'
			ELSE
			      SELECT @cmd = 'RESTORE LOG ' + '[' + RTRIM(@db) + ']' + CHAR(13) +
			              ' FROM DISK = ' + CHAR(39) +
			               rtrim(substring(@physical_device_name,1,len(@physical_device_name))) +
			                 CHAR(39) + CHAR(13) + ' WITH REPLACE, NORECOVERY'

			SELECT @cmd2 = ''
		END
	    ELSE
		BEGIN
		-- Current backup being processed is a full backup, not a transaction log backup (log backups exist)
		-- Build restore command to restore the currrent database backup, with no recovery
			IF @zipped ='Y'
			BEGIN
				IF @overwritedb = 'Y' SELECT @cmd = @physical_device_name + ',@with = ' + CHAR(39) + 'REPLACE, NORECOVERY' + CHAR(39) + CHAR(13)
				ELSE SELECT @cmd = @physical_device_name + ',@with = ' + CHAR(39) + 'NORECOVERY' + CHAR(39) + CHAR(13)
			END
			ELSE
			BEGIN
				IF @overwritedb = 'Y' SELECT @cmd = @physical_device_name + ' WITH REPLACE, NORECOVERY, STATS=1, ' + CHAR(13)
				ELSE SELECT @cmd = @physical_device_name + ' WITH NORECOVERY, STATS=1, ' + CHAR(13)
			END
			SELECT @cmd2 = @phys
		END
	   -- Comment restore of system and demo databases
	   IF @db IN ('master','model','msdb','tempdb','Northwind','pubs')
		BEGIN
	      		SET @cmd = '/* ' + CHAR(13) + @cmd + CHAR(13)
			SET @cmd2 = @cmd2 + CHAR(13) +  + '*/'
		END
	   -- Generate the restore command and other commands for restore script
	   IF @cmd2 > ''
		BEGIN
			SET @cmd = @cmd + @cmd2
		END

	   -- Run restore or print restore scripts?
	   IF @runrestore = 'Y'
	   BEGIN
		   -- Execute restore from full backup and transaction log backups
		IF @newdbname > ''
			IF @currentbackupstart IS NOT NULL print 'Restoring database ' + @db + ' to database ' + @newdbname + ' from backup with start date ' + convert(char(24),@currentbackupstart,121)
		ELSE
			IF @currentbackupstart IS NOT NULL print 'Restoring database ' + @db + ' from backup with start date ' + convert(char(24),@currentbackupstart,121)

		EXEC (@cmd)
	  END
	  ELSE
	  BEGIN
		   -- Print restore script for full backup and transaction log backups
		IF @newdbname > ''
			IF @currentbackupstart IS NOT NULL print @comment + 'Script for restoring database ' + @db + ' to database ' + @newdbname + ' from backup with start date ' + convert(char(24),@currentbackupstart,121)
		ELSE
			IF @currentbackupstart IS NOT NULL print @comment + 'Script for restoring database ' + @db + ' from backup with start date ' + convert(char(24),@currentbackupstart,121)

		PRINT @cmd
		PRINT 'GO'
	  END

	  -- Get next database backup to process
	  FETCH next from backup_name into @physical_device_name, @type, @phys, @currentbackupstart
     END
     -- Close and deallocate database backup name cursor for current database being processed
     CLOSE backup_name
     DEALLOCATE backup_name
  --Get next database to process
  IF @newdbname > ''
  	PRINT @comment + 'Import of database ' + @db + ' to new dabase name ' + @newdbname + ' has completed'
  ELSE
  	PRINT @comment + 'Import of database ' + @db + ' has completed'
  PRINT REPLICATE('-',LEN(@myHeader))
  FETCH next from @dbcursor into @db
END
-----------------------------------------------------------------------------------------------------------
-- CLEANUP
-----------------------------------------------------------------------------------------------------------
CLEANUP:
-- Close and deallocate cursor containing list of databases to process
IF Cursor_Status('variable', '@dbcursor') >= 0
BEGIN
	CLOSE @dbcursor
	DEALLOCATE @dbcursor
END
-- Close and deallocate cursor containing list of database logical names
IF Cursor_Status('variable', '@lognamecursor') >= 0
BEGIN
	CLOSE @lognamecursor
	DEALLOCATE @lognamecursor
END
-- Close and deallocate cursor containing list of backup files to process
IF Cursor_Status('local', 'backup_name') >= 0
BEGIN
	CLOSE backup_name
	DEALLOCATE backup_name
END
-- Close and deallocate cursor containing list of transaction log files to process
IF Cursor_Status('local', 'trans_file_name') >= 0
BEGIN
	CLOSE trans_file_name
	DEALLOCATE trans_file_name
END
-- Drop temporary tables
IF OBJECT_ID('tempdb..#sourcebackups') IS NOT NULL DROP TABLE #sourcebackups
IF OBJECT_ID('tempdb..#FileExists') IS NOT NULL DROP TABLE #FileExists
IF OBJECT_ID('tempdb..#DriveSpace') IS NOT NULL DROP TABLE #DriveSpace
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS ON
SET @ok = @ret
RETURN @ret
GO


 