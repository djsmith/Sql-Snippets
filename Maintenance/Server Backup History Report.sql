 /*
	Server Backup History Report
	(Full DB Backups only)
	1.	lists all databases with no backup history
	2.	lists last backup for other databases 
		includes Date, User, Size, Duration, Age, Finish Date & Location
	3. Option to copy backup file to another folder

	Includes system databases
	Excludes TempDB
	
	Excludes backup history data where backupmediafamily.device_type = 7
	these are typically created by Veritas BackupExec
	
	Tested on SQL Server 2000 (SP3)
	
	Brett Ivery	24/03/2006	created
				11/04/2006	added file existence check
	Dan Smith 11/11/2007 added #prCopyFiles proc to copy file to another folder

*/
SET nocount ON
-- drop temp proc if exists
IF object_id('tempdb..#prFileExists') IS NOT NULL
    DROP PROCEDURE #prFileExists
GO

-- START create temp proc to check backup file existence
CREATE PROCEDURE dbo.#prFileExists 
	@path varchar(300) , 
	@p2 int  OUTPUT
AS BEGIN
/*
	DECLARE @EXISTS bit
	EXECUTE dbo.#prFileExists 'c:\boot.ini', @EXISTS OUTPUT
	SELECT @EXISTS AS [EXISTS]
*/
	DECLARE @RES varchar(500)
	DECLARE @EXEC varchar(1000)
	IF object_id('tempdb..#cmdshell') IS NOT NULL
		DROP TABLE #cmdshell
	CREATE TABLE #cmdshell (
		res varchar (100)
	) 
	SET @EXEC = 'IF exist "' + @path + '" (echo Found) ELSE (echo NOT Found)' 
	INSERT INTO #cmdshell (res) 
		EXEC master..xp_cmdshell @EXEC
	DELETE #cmdshell WHERE res IS NULL
	SET @RES = (SELECT res FROM #cmdshell)
	IF @RES = 'Found'
		SET @p2 = 1
	ELSE
		SET @p2 = 0
END
GO
-- END create temp proc to check backup file existence

if object_id('tempdb..#prCopyFiles') is not null
    drop procedure #prCopyFiles
GO

create proc dbo.#prCopyFiles 
	@SourceFile varchar(200), 
	@DestinationFolder varchar(200) 
as
begin
	declare @DOSCommand varchar(500)

	set nocount on

	--Check whether the user supply \ in the directory name
	if not (right(@DestinationFolder, 1) = '\') begin
		set @DestinationFolder = @DestinationFolder + '\'
	end

	--The following DOS command will copy files. The /D switch only copies new files.
	--If a file exists in the destination folder, it will not try to copy it again.
	set @DOSCommand = 'xcopy /D ' + '"' + @SourceFile + '" "' + @DestinationFolder + '"'
	--Compress doesn't work properly in Win2k3 Server regarding the Destination parameter
	--set @DOSCommand = 'compress -R -S ' + '"' + @SourceFile + '" "' + @DestinationFolder + '"'

	--print @DOSCommand
	exec master..xp_cmdshell @DOSCommand, no_output
end
GO

--Declare variables and temp table for existing backup data
DECLARE @i int
DECLARE @EXISTS bit
DECLARE @location varchar(260)
DECLARE @copyDestination varchar(200)
SET @i = 0
SET @copyDestination = '' --set to blank to disable the copy
DECLARE @tmp TABLE (
	[ID]				[int] identity(1,1) NOT NULL,
	[FileExists]		bit DEFAULT 0,
	[DBName] 			[varchar] (30) NULL ,
	[UserName] 			[varchar] (30) NULL ,
	[BackupSize] 		[decimal] (20,2) NULL ,
	[Duration] 			[varchar] (10) NULL ,
	[BackupAge]			[int] NULL ,
	[FinishDate] 		[varchar] (20) NULL ,
	[Location]			[varchar] (260) NULL ,
	[device_type] 		[tinyint] NULL 
) 

-- return data about databases with no backup history
PRINT ' ================================================================================================================================'
PRINT ' ' + @@servername + ' - Database Backup History (SQL Backups only)' 
PRINT ' '
if exists(
	SELECT 
		DB.Name 
	FROM
		master..sysdatabases DB
		left join
		(
			select database_name
			from msdb..BACKUPSET BS
				join msdb..backupmediaset MS
					on
					BS.media_set_id = MS.media_set_id
					join msdb..backupmediafamily MF
					on
					BS.media_set_id = MF.media_set_id
				WHERE
				type = 'D'
				and mf.device_type <> 7
			group by database_name
		) BS
		on BS.database_name = DB.name
	where 
		BS.Database_name is null
		and 
		not DB.Name = 'TempDB'
)
	
		SELECT 
			DB.Name as [Databases With No Backup History]
		FROM
			master..sysdatabases DB
			left join
			(
				select database_name
				from msdb..BACKUPSET BS
				join msdb..backupmediaset MS
					on
					BS.media_set_id = MS.media_set_id
					join msdb..backupmediafamily MF
					on
					BS.media_set_id = MF.media_set_id
				WHERE
				type = 'D'
				and mf.device_type <> 7
				group by database_name
			) BS
			on BS.database_name = DB.name
		where 
			BS.Database_name is null
			and 
			not DB.Name = 'TempDB'
else
		SELECT 
			'- None -' as [Databases With No Backup History]

-- get existing backup history data
-- (into table variable for later modification)
PRINT ' Databases With Backup History'
PRINT ' -------------------------------- '
INSERT @tmp(
	[DBName] 			
	, [UserName] 			
	, [BackupSize] 		
	, [Duration] 			
	, [BackupAge]	
	, [FinishDate] 		
	, [Location]
	, [device_type] 		
)
SELECT 
	cast(database_name AS varchar(30)) AS [DBName],
	cast(user_name AS varchar(30)) AS [UserName],
	cast(backup_size AS decimal(20,2)) / 1048576 AS [BackupSize],
	cast(datediff(n,backup_start_date,backup_finish_date) AS varchar(5)) + ' min.' AS [Duration],
	cast(datediff(dd,backup_finish_date,Getdate()) AS varchar(10))  AS [BackupAge],
	convert(varchar(20),backup_finish_date) AS [FinishDate],
	physical_device_name AS [Location],
	mf.device_type
FROM
	master..sysdatabases DB
	JOIN
	msdb..BACKUPSET BS
	ON DB.name = BS.database_name
	JOIN msdb..backupmediaset MS
	ON
	BS.media_set_id = MS.media_set_id
	JOIN msdb..backupmediafamily MF
	ON
	BS.media_set_id = MF.media_set_id
	JOIN
	(
		SELECT 
			max(backup_set_id) AS backup_set_id
		FROM
			msdb..BACKUPSET BS
			JOIN msdb..backupmediaset MS
				ON
				BS.media_set_id = MS.media_set_id
				JOIN msdb..backupmediafamily MF
				ON
				BS.media_set_id = MF.media_set_id
		WHERE
			type = 'D'
			AND mf.device_type <> 7
		GROUP BY database_name
	) MaxBackup
	ON 
	BS.backup_set_id = MaxBackup.backup_set_id
WHERE
	type = 'D' 
	
-- loop through the results and update the FileExists field 
-- (calling temp proc for each row)
	SELECT @i = min(ID) FROM @tmp WHERE ID > @i
	WHILE @i IS NOT NULL BEGIN
		IF @i IS NOT NULL BEGIN
			--	PRINT cast(@i AS varchar(20))
			SET @location = (SELECT location FROM @tmp WHERE ID = @i)
			EXECUTE #prFileExists @location, @EXISTS OUTPUT		
			UPDATE @tmp SET FileExists = @EXISTS WHERE ID = @i
			IF (IsNull(@copyDestination,'') != '') BEGIN
				EXECUTE #prCopyFiles @location, @copyDestination
			END
		END
		SELECT @i = min(ID) FROM @tmp WHERE ID > @i
	END

-- return the results
	SELECT 
		[DBName] 			
		, [UserName] 			
		, [BackupSize] 		
		, [Duration] 			
		, [BackupAge]	AS [BackupAge (Days)]
		, [FinishDate] 
		, [FileExists]
		, [Location]	
	FROM 
		@tmp
	ORDER BY 
		[BackupAge] DESC, DBName ASC

-- drop the temp proc
IF object_id('tempdb..#prFileExists') IS NOT NULL
    DROP PROCEDURE #prFileExists
GO

if object_id('tempdb..#prCopyFiles') is not null
    drop procedure #prCopyFiles
GO

PRINT ' ================================================================================================================================'
