/******************************************************************

This script creates the script to restore your database with the information existing in [msdb] database.
It helps you by finding the last FULL backup, the last DIFFERENTIAL backup and all the TRANSACTION LOG backups needed.
It's quite comfortable when you are doing so many differential or log backups.
I hope you enjoy it!!!

Script done by Josep Martínez based on the script done by [jtshyman] named "List SQL backups"
Of course, there's no warranty, etc ...

The variable @DBName should be set to the name of the database you want to query on.
It is not case sensitive unless your collation is.

From http://www.sqlservercentral.com/scripts/Restore/61810/

DJS; Modified to include the With Move and With File options
DJS; Modified to get the last full backup and all subsequend 
	incremental and log backups for the database

Note; this hasn't been fully tested with different combinations of backups
 - Mix of Full, Differential and Log backups
 - Multiple backups stored on a single device (backup file)

*/
-- Important because we're going to 'print' the sql code for the restore
USE Master

SET NOCOUNT ON
DECLARE @DBName sysname
--DECLARE @Days INT, @WithMove INT, @WithStats INT, @Move VARCHAR(8000), @Stats VARCHAR(8000)
DECLARE @WithMove INT, @WithStats INT, @Move VARCHAR(8000), @Stats VARCHAR(8000)
-- These are the only parameters that needs to be configured
SET @DBName='DanPayroll'
SET @WithMove = 1 -- 1 or 0; 1=include a "move xx to yy" statement. "1" requires that dbname is the current database
SET @WithStats = 1 -- 1 or 0; 1=include a "STATS=1" statement

SELECT @Move = Coalesce(@Move,'') + 'MOVE ''' + F.logical_name + ''' TO ''' + F.physical_name + ''', ' + CHAR(13)
FROM msdb..backupset S
JOIN msdb..backupfile F ON S.backup_set_id = F.backup_set_id
WHERE S.database_name = @DBName
AND S.backup_start_date = (
	select Max(backup_start_date) 
	from msdb..backupset 
	where database_name = @DbName and type = 'D')
ORDER by F.file_number
IF LEN(@Move) > 2 SELECT @Move = LEFT(@Move, LEN(@Move)-2)

SET @Stats=''
IF @WithStats=1 BEGIN
	SELECT @Stats = 'STATS=1,'
END

CREATE TABLE #BackupsHistory
(
	id INT IDENTITY(1,1),
	backup_start_date DATETIME,
	backup_type CHAR(1),
	physical_device_name VARCHAR(2000),
	family_sequence_number int
)

--Get the list of backups starting with the most recent full backup; "type='D'"
INSERT INTO #BackupsHistory (backup_start_date, backup_type, physical_device_name, family_sequence_number)
SELECT S.backup_start_date, S.type, M.physical_device_name, M.family_sequence_number
FROM msdb..backupset S
JOIN msdb..backupmediafamily M ON M.media_set_id=S.media_set_id
WHERE S.database_name = @DBName
AND S.backup_start_date >= (
	select Max(backup_start_date) 
	from msdb..backupset 
	where database_name = @DbName and type = 'D')
ORDER by backup_start_date

DECLARE @lastFullBackup INT, @lastFullBackupPath VARCHAR(2000), @lastDifferentialBackup INT, @lastDifferentialBackupPath VARCHAR(2000), @lastFileNumber int

-- We get the last Full backup done. That where we are going to start the restore process
SELECT TOP 1 @lastFullBackup=id, @lastFullBackupPath=physical_device_name, @lastFileNumber=family_sequence_number
FROM #BackupsHistory 
WHERE backup_type='D' 
ORDER BY backup_start_date DESC

-- Restoring the Full backup
PRINT 'RESTORE DATABASE ' + @DBName
PRINT 'FROM DISK=''' + @lastFullBackupPath + ''''
PRINT 'WITH FILE = ' + CAST(@lastFileNumber as varchar(5)) + ', '

IF @WithMove =1 BEGIN
	PRINT @Move
END
IF @WithStats=1 BEGIN
	PRINT @Stats
END

-- IF it's there's no backup (differential or log) after it, we set to recovery
IF (@lastFullBackup = (SELECT MAX(id) FROM #BackupsHistory))
	PRINT 'RECOVERY'
ELSE 
	PRINT 'NORECOVERY'

PRINT 'GO'
PRINT ''


-- We get the last Differential backup (it must be done after the last Full backup)
SELECT TOP 1 @lastFullBackup=id, @lastFullBackupPath=physical_device_name, @lastFileNumber=family_sequence_number
FROM #BackupsHistory 
WHERE backup_type='I' AND id>@lastFullBackup 
ORDER BY backup_start_date DESC

-- IF there's a differential backup done after the full backup we script it
IF (@lastDifferentialBackup IS NOT NULL) BEGIN
	-- Restoring the Full backup
	PRINT 'RESTORE DATABASE ' + @DBName
	PRINT 'FROM DISK=''' + @lastDifferentialBackupPath + ''''
	PRINT 'WITH FILE = ' + CAST(@lastFileNumber as varchar(5)) + ', '
	IF @WithStats=1 BEGIN
		PRINT @Stats
	END
	-- IF it's there's no backup (differential or log) after it, we set to recovery
	IF (@lastDifferentialBackup = (SELECT MAX(id) FROM #BackupsHistory))
		PRINT 'RECOVERY'
	ELSE 
		PRINT 'NORECOVERY'

	PRINT 'GO'
	PRINT ''
END


-- For TRANSACTION LOGs
DECLARE @i INT, @logBackupPath VARCHAR(2000)
IF (@lastDifferentialBackup IS NULL)
	SET @i = @lastFullBackup + 1
ELSE 
	SET @i = @lastDifferentialBackup + 1

-- Here whe are scripting the restores for the necessary logs
WHILE (@i <= (SELECT MAX(id) FROM #BackupsHistory)) BEGIN
	SELECT @logBackupPath=physical_device_name, @lastFileNumber=family_sequence_number FROM #BackupsHistory WHERE id=@i
	PRINT 'RESTORE LOG ' + @DBName
	PRINT 'FROM DISK=''' + @logBackupPath + ''''
	PRINT 'WITH FILE = ' + CAST(@lastFileNumber as varchar(5)) + ', '
	IF @WithStats=1 BEGIN
		PRINT @Stats
	END
	-- IF it's the last transaction log, we'll say it to recover
	IF (@i = (SELECT MAX(id) FROM #BackupsHistory))
		PRINT 'RECOVERY'
	ELSE 
		PRINT 'NORECOVERY'

	PRINT 'GO'
	PRINT ''

	SET @i = @i + 1
END


DROP TABLE #BackupsHistory

