/*
This script sets up maintenance plans without having to use SSIS or even Management Studio
by executing various T-SQL statements.

Custom Maintenance Plans - the T-SQL way
By Mark Marinovic
http://www.sqlservercentral.com/scripts/Maintenance/66864/

*/

USE [master]
GO

IF IS_SRVROLEMEMBER('sysadmin') = 1
   BEGIN
      --Check prerequisites
      IF NOT EXISTS (SELECT  'X'
                     FROM    msdb..sysoperators O
                     WHERE   O.[name] = 'SQLServer_Admin')
         BEGIN
            --Add Operator
            EXEC msdb.dbo.sp_add_operator @name = N'SQLServer_Admin', @enabled = 1, @pager_days = 0, @email_address = N'name@domain.com'
         END
      --Create Admin database if it does not exist
      IF NOT EXISTS (SELECT  'X'
                     FROM    sys.databases SDB
                     WHERE   SDB.[name] = 'Admin')
         BEGIN
            PRINT 'Creating new "Admin" database on server ' + @@SERVERNAME + '...'

            DECLARE @RegPathParams sysname,
               @Arg sysname,
               @Param sysname,
               @n integer,
               @strSQL nvarchar(1000),
               @DefaultDBDataPath nvarchar(512),
               @DefaultDBLogPath nvarchar(512)

        --Find default database Data path
            PRINT 'Determining default Database Data directory on server ' + @@SERVERNAME + '...'

            SET @n = 0
            SET @RegPathParams = N'Software\Microsoft\MSSQLServer\MSSQLServer\Parameters'
            SET @Param = ''
            WHILE (NOT @Param IS NULL)
               BEGIN
                  SET @Param = NULL
                  SET @Arg = 'SqlArg' + CONVERT(nvarchar(100), @n)
                  EXEC [master].dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', @RegPathParams, @Arg, @Param OUTPUT

                  IF (@Param LIKE '-d%')
                     BEGIN
                        SET @Param = SUBSTRING(@Param, 3, 255)
                        SET @DefaultDBDataPath = SUBSTRING(@Param, 1, LEN(@Param) - CHARINDEX('\', REVERSE(@Param)))
                        BREAK
                     END
                  SET @n = @n + 1
               END

        --Find default database Log directory
            PRINT 'Determining default Database Log directory on server ' + @@SERVERNAME + '...'
            EXEC [master].dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', @DefaultDBLogPath OUTPUT

        --Create Admin database
            SET @strSQL = 'CREATE
                        DATABASE [Admin] ON (NAME = N''Admin_Data'', FILENAME = N''' + @DefaultDBDataPath + '\Admin_Data.mdf'', SIZE = 15MB, FILEGROWTH = 10%)
                        LOG ON (NAME = N''Admin_Log'', FILENAME = N''' + COALESCE(@DefaultDBLogPath, @DefaultDBDataPath) + '\Admin_Log.ldf'', SIZE = 15MB, FILEGROWTH = 10%)'
            EXEC sp_executesql @strSQL

            ALTER DATABASE [Admin] SET RESTRICTED_USER
            ALTER DATABASE [Admin] SET RECOVERY SIMPLE
            EXEC [Admin]..sp_changedbowner 'sa'
         END
   END
ELSE
   BEGIN
      RAISERROR ('Please log in as a user with sysadmin (sa) privileges.',
      20,
      1) WITH LOG
      RETURN
   END
GO




USE [Admin]
GO

IF EXISTS (SELECT  'X'
           FROM    sys.objects O
           WHERE   O.[name] = 'MaintenancePlanStaticDatabases'
                   AND O.[type_desc] = 'USER_TABLE')
   BEGIN
      DROP TABLE [dbo].[MaintenancePlanStaticDatabases]
   END
GO
IF EXISTS (SELECT  'X'
           FROM    sys.objects O
           WHERE   O.[name] = 'MaintenancePlanSettings'
                   AND O.[type_desc] = 'USER_TABLE')
   BEGIN
      DROP TABLE [dbo].[MaintenancePlanSettings]
   END
GO

DECLARE @RegPathParams sysname,
   @Arg sysname,
   @Param sysname,
   @n integer,
   @BackupDirectory nvarchar(512),
   @ErrorLogPath nvarchar(512)

--Find default Error Log path
PRINT 'Determining default Error Log directory on server ' + @@SERVERNAME + '...'

SET @n = 0
SET @RegPathParams = N'Software\Microsoft\MSSQLServer\MSSQLServer\Parameters'
SET @Param = ''
WHILE(NOT @Param IS NULL)
   BEGIN
      SET @Param = NULL
      SET @Arg = 'SqlArg' + CONVERT(nvarchar(100), @n)

      EXEC [master].dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', @RegPathParams, @Arg, @Param OUTPUT

      IF (@Param LIKE '-e%')
         BEGIN
            SET @Param = SUBSTRING(@Param, 3, 255)
            SET @ErrorLogPath = SUBSTRING(@Param, 1, LEN(@Param) - CHARINDEX('\', REVERSE(@Param)))
            BREAK
         END
      SET @n = @n + 1
   END

--Find default Backup directory 
PRINT 'Determining default Database Backup directory on server ' + @@SERVERNAME + '...'

EXEC [master].dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @BackupDirectory OUTPUT

CREATE TABLE [dbo].[MaintenancePlanSettings]
(
 [MaintenancePlanID] tinyint IDENTITY(0,1)
                             NOT NULL,
 [MaintenancePlanName] varchar(50) NOT NULL,
 [PurgeDayCountTextReports] tinyint NOT NULL,
 [PurgeDayCountHistory] tinyint NOT NULL,
 [PurgeDayCountBAKFiles] tinyint NOT NULL,
 [PurgeDayCountTRNFiles] tinyint NOT NULL,
 [BackupFilePath] varchar(255) NOT NULL,
 [OutputLogFilePath] varchar(255) NOT NULL,
 [LatestNDB] smallint NOT NULL,
 [IndexFillFactor] tinyint NOT NULL)
ON [PRIMARY]

ALTER TABLE [dbo].[MaintenancePlanSettings]
ADD CONSTRAINT [PK_MaintenancePlanSettings] PRIMARY KEY CLUSTERED ([MaintenancePlanID] ASC) ON [PRIMARY]
ALTER TABLE [dbo].[MaintenancePlanSettings]
ADD CONSTRAINT [UX_MaintenancePlanName] UNIQUE NONCLUSTERED ([MaintenancePlanName]) ON [PRIMARY]

--Output defaults to user
PRINT 'Default Text report retention set at 28 days.'
PRINT 'Default Job History retention set at 28 days.'
PRINT 'Default *.BAK file retention set at 2 days.'
PRINT 'Default *.TRN file retention set at 2 days.'
PRINT 'Default databases subject to Maintenance Plan: 0 (all databases).'
PRINT 'Default Index Fill Factor: 85%'

ALTER TABLE [dbo].[MaintenancePlanSettings]
ADD CONSTRAINT [DF_PurgeDayCountTextReports] DEFAULT ((28)) FOR [PurgeDayCountTextReports]
ALTER TABLE [dbo].[MaintenancePlanSettings]
ADD CONSTRAINT [DF_PurgeDayCountHistory] DEFAULT ((28)) FOR [PurgeDayCountHistory]
ALTER TABLE [dbo].[MaintenancePlanSettings]
ADD CONSTRAINT [DF_PurgeDayCountBAKFiles] DEFAULT ((2)) FOR [PurgeDayCountBAKFiles]
ALTER TABLE [dbo].[MaintenancePlanSettings]
ADD CONSTRAINT [DF_PurgeDayCountTRNFiles] DEFAULT ((2)) FOR [PurgeDayCountTRNFiles]
ALTER TABLE [dbo].[MaintenancePlanSettings]
ADD CONSTRAINT [DF_LatestNDB] DEFAULT ((0)) FOR [LatestNDB]
ALTER TABLE [dbo].[MaintenancePlanSettings]
ADD CONSTRAINT [DF_IndexFillFactor] DEFAULT ((85)) FOR [IndexFillFactor]

ALTER TABLE [dbo].[MaintenancePlanSettings]
      WITH CHECK
ADD CONSTRAINT [CK_IndexFillFactor] CHECK (([IndexFillFactor] >= (0)
                                            AND [IndexFillFactor] <= (100)))
ALTER TABLE [dbo].[MaintenancePlanSettings]
      WITH CHECK
ADD CONSTRAINT [CK_LatestNDB] CHECK (([LatestNDB] >= (0)))
ALTER TABLE [dbo].[MaintenancePlanSettings]
      WITH CHECK
ADD CONSTRAINT [CK_PurgeDayCountBAKFiles] CHECK (([PurgeDayCountBAKFiles] > (0)))
ALTER TABLE [dbo].[MaintenancePlanSettings]
      WITH CHECK
ADD CONSTRAINT [CK_PurgeDayCountHistory] CHECK (([PurgeDayCountHistory] > (0)))
ALTER TABLE [dbo].[MaintenancePlanSettings]
      WITH CHECK
ADD CONSTRAINT [CK_PurgeDayCountTextReports] CHECK (([PurgeDayCountTextReports] > (0)))
ALTER TABLE [dbo].[MaintenancePlanSettings]
      WITH CHECK
ADD CONSTRAINT [CK_PurgeDayCountTRNFiles] CHECK (([PurgeDayCountTRNFiles] > (0)))

--Create default Maintenance Plan
INSERT  INTO dbo.MaintenancePlanSettings
        (
         [MaintenancePlanName],
         [BackupFilePath],
         [OutputLogFilePath])
VALUES  (
         'default',
         @BackupDirectory,
         @ErrorLogPath)
GO




CREATE TABLE [dbo].[MaintenancePlanStaticDatabases]
(
 [FK_MaintenancePlanID] tinyint NOT NULL,
 [DatabaseName] varchar(50) NOT NULL,
 [Disposition] char(1) NOT NULL)
ON [PRIMARY]
GO
ALTER TABLE [dbo].[MaintenancePlanStaticDatabases]
ADD CONSTRAINT [FK_MaintenancePlanStaticDatabases_MaintenancePlanSettings] FOREIGN KEY ([FK_MaintenancePlanID]) REFERENCES [dbo].[MaintenancePlanSettings] (MaintenancePlanID)
ALTER TABLE [dbo].[MaintenancePlanStaticDatabases]
ADD CONSTRAINT [UX_MaintenancePlanStaticDatabases] UNIQUE NONCLUSTERED ([FK_MaintenancePlanID],[DatabaseName]) ON [PRIMARY]

ALTER TABLE [dbo].[MaintenancePlanStaticDatabases]
ADD CONSTRAINT [DF_Disposition] DEFAULT ('I') FOR [Disposition]

ALTER TABLE [dbo].[MaintenancePlanStaticDatabases]
      WITH CHECK
ADD CONSTRAINT [CK_Disposition] CHECK (([Disposition] = 'E'
                                        OR [Disposition] = 'I'))
GO
--Set databases always subject to the Maintenance Plan
INSERT  INTO [dbo].[MaintenancePlanStaticDatabases]
        (
         [FK_MaintenancePlanID],
         [DatabaseName],
         [Disposition])
VALUES  (
         0,
         'Admin',
         'I')
INSERT  INTO [dbo].[MaintenancePlanStaticDatabases]
        (
         [FK_MaintenancePlanID],
         [DatabaseName],
         [Disposition])
VALUES  (
         0,
         'master',
         'I')
INSERT  INTO [dbo].[MaintenancePlanStaticDatabases]
        (
         [FK_MaintenancePlanID],
         [DatabaseName],
         [Disposition])
VALUES  (
         0,
         'model',
         'I')
INSERT  INTO [dbo].[MaintenancePlanStaticDatabases]
        (
         [FK_MaintenancePlanID],
         [DatabaseName],
         [Disposition])
VALUES  (
         0,
         'msdb',
         'I')
INSERT  INTO [dbo].[MaintenancePlanStaticDatabases]
        (
         [FK_MaintenancePlanID],
         [DatabaseName],
         [Disposition])
VALUES  (
         0,
         'distribution',
         'I')
GO




IF EXISTS (SELECT  'X'
           FROM    sys.objects O
           WHERE   O.[name] = 'vwMaintenancePlanDatabases'
                   AND O.[type_desc] = 'VIEW')
   BEGIN
      DROP VIEW [dbo].[vwMaintenancePlanDatabases]
   END
GO
CREATE VIEW [dbo].[vwMaintenancePlanDatabases]
AS SELECT  DBRank.MaintenancePlanID,
           DBRank.DatabaseName
   FROM    (SELECT  MP.MaintenancePlanID,
                    SDB.[name] AS DatabaseName,
                    RANK() OVER (
                    ORDER BY SDB.create_date DESC) AS DatabaseRank,
                    MP.LatestNDB
            FROM    sys.databases SDB
                    CROSS JOIN dbo.MaintenancePlanSettings MP
            WHERE
                    --Exclude system databases
                    SDB.[name] NOT IN ('Admin', 'master', 'model', 'msdb', 'tempdb', 'distribution')
                    --Exclude database snapshots
                    AND SDB.source_database_id IS NULL
                    --Other status checks
                    AND SDB.state_desc = 'ONLINE') DBRank
   WHERE
           --32,767 is uppermost limit for SMALLINT data type used for this column (NDB = 0 represents ALL user databases on the instance)
           DBRank.DatabaseRank <= CASE WHEN DBRank.LatestNDB = 0 THEN 32767
                                       ELSE DBRank.LatestNDB
                                  END
   UNION

   --Automatically include databases with an "I" (Include) disposition by default
   SELECT  MPSD.FK_MaintenancePlanID,
           MPSD.DatabaseName
   FROM    dbo.MaintenancePlanStaticDatabases MPSD --Validate database names with JOIN
           INNER JOIN sys.databases SDB
           ON SDB.[name] = MPSD.DatabaseName
   WHERE   MPSD.Disposition = 'I'
GO




IF EXISTS (SELECT  'X'
           FROM    sys.objects O
           WHERE   O.[name] = 'procMaintenancePlan_SetOutputLog'
                   AND O.[type_desc] = 'SQL_STORED_PROCEDURE')
   BEGIN
      DROP PROCEDURE [dbo].[procMaintenancePlan_SetOutputLog]
   END
GO
CREATE PROCEDURE [dbo].[procMaintenancePlan_SetOutputLog]
(
 @MaintenancePlanID integer)
AS
BEGIN

   SET NOCOUNT ON

   DECLARE @JobID varchar(255),
      @OutputFileName varchar(255),
      @strSQL nvarchar(255)

   DECLARE sJobs CURSOR FAST_FORWARD
 --Find jobs associated with the "Custom Database Maintenance" category

      FOR SELECT  SJ.[job_id] AS JobID,
                  CASE WHEN CHARINDEX('\', REVERSE(MP.OutputLogFilePath)) = 1 THEN MP.OutputLogFilePath
                       ELSE MP.OutputLogFilePath + '\'
                  END + SJ.[name] + '_' + REPLACE(REPLACE(REPLACE(CONVERT(varchar(20), GETDATE(), 121), ' ', ''), ':', ''), '-', '') + 'txt' AS OutputLogFileName
          FROM    msdb..sysjobs SJ
                  INNER JOIN msdb..syscategories SC
                  ON SC.category_id = SJ.category_id
                  CROSS JOIN dbo.MaintenancePlanSettings MP
          WHERE   SC.[name] = 'Custom Database Maintenance'
                  --If MP ID is passed in as a NULL, default MP ID = 0
                  AND MP.MaintenancePlanID = COALESCE(@MaintenancePlanID, 0)
   OPEN sJobs
   FETCH sJobs INTO @JobID,@OutputFileName
   WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @JobID = RTRIM(@JobID)
         SET @OutputFileName = RTRIM(@OutputFileName)
     
     --Change output files to custom, per-run file
         SET @strSQL = N'EXEC msdb.dbo.sp_update_jobstep @job_id = ''' + @JobID + ''', @step_id = 1, @output_file_name = ''' + @OutputFileName + ''''
         EXEC sp_executesql @strSQL
         FETCH sJobs INTO @JobID,@OutputFileName
      END
   CLOSE sJobs
   DEALLOCATE sJobs
END
GO




IF EXISTS (SELECT  'X'
           FROM    sys.objects O
           WHERE   O.[name] = 'procMaintenancePlan_Subplan_7_CleanupBackups'
                   AND O.[type_desc] = 'SQL_STORED_PROCEDURE')
   BEGIN
      DROP PROCEDURE [dbo].[procMaintenancePlan_Subplan_7_CleanupBackups]
   END
GO
CREATE PROCEDURE [dbo].[procMaintenancePlan_Subplan_7_CleanupBackups]
(
 @MaintenancePlanID integer)
AS
BEGIN

   SET NOCOUNT ON

   DECLARE @PurgeDayCountBAK tinyint,
      @PurgeDateBAK datetime,
      @PurgeDayCountTRN tinyint,
      @PurgeDateTRN datetime,
      @BackupFilePath nvarchar(255),
      @strSQL nvarchar(255)

--If MP ID is passed in as a NULL, default MP ID = 0
   SET @MaintenancePlanID = COALESCE(@MaintenancePlanID, 0)

   IF NOT EXISTS (SELECT  'X'
                  FROM    dbo.MaintenancePlanSettings
                  WHERE   MaintenancePlanID = @MaintenancePlanID)
      BEGIN
         RAISERROR ('Maintenance Plan ID %d does not exist.',
         16,
         1,
         @MaintenancePlanID)
         RETURN
      END

   SELECT  @PurgeDayCountBAK = MP.PurgeDayCountBAKFiles
   FROM    dbo.MaintenancePlanSettings MP
   WHERE   MP.MaintenancePlanID = @MaintenancePlanID
   SELECT  @PurgeDayCountTRN = MP.PurgeDayCountTRNFiles
   FROM    dbo.MaintenancePlanSettings MP
   WHERE   MP.MaintenancePlanID = @MaintenancePlanID
   SELECT  @BackupFilePath = MP.BackupFilePath
   FROM    dbo.MaintenancePlanSettings MP
   WHERE   MP.MaintenancePlanID = @MaintenancePlanID

   SET @PurgeDateBAK = GETDATE() - @PurgeDayCountBAK
   SET @PurgeDateTRN = GETDATE() - @PurgeDayCountTRN

--Purge aged backup and t-log files
   PRINT CHAR(10) + '***************' + CONVERT(varchar(25), GETDATE(), 121) + ': Deleting aged Full Backup files' + '***************'
   SET @strSQL = 'EXEC master..xp_delete_file 0, ''' + @BackupFilePath + ''', N''bak'', ''' + CONVERT(varchar(25), @PurgeDateBAK, 121) + ''''
   PRINT 'SQL sent: ' + @strSQL
   EXEC sp_executesql @strSQL

   PRINT CHAR(10) + '***************' + CONVERT(varchar(25), GETDATE(), 121) + ': Deleting aged Transaction Log files' + '***************'
   SET @strSQL = 'EXEC master..xp_delete_file 0, ''' + @BackupFilePath + ''', N''trn'', ''' + CONVERT(varchar(25), @PurgeDateTRN, 121) + ''''
   PRINT 'SQL sent: ' + @strSQL
   EXEC sp_executesql @strSQL

   PRINT CHAR(10) + 'Maintenance cleanup finished: ' + CONVERT(varchar(25), GETDATE(), 121)
END
GO




IF EXISTS (SELECT  'X'
           FROM    sys.objects O
           WHERE   O.[name] = 'procMaintenancePlan_Subplan_6_BackupTranLogs'
                   AND O.[type_desc] = 'SQL_STORED_PROCEDURE')
   BEGIN
      DROP PROCEDURE [dbo].[procMaintenancePlan_Subplan_6_BackupTranLogs]
   END
GO
CREATE PROCEDURE [dbo].[procMaintenancePlan_Subplan_6_BackupTranLogs]
(
 @MaintenancePlanID integer)
AS
BEGIN

   SET NOCOUNT ON

   DECLARE @dbName varchar(255),
      @strSQL nvarchar(255),
      @bakLocation varchar(255)

--If MP ID is passed in as a NULL, default MP ID = 0
   SET @MaintenancePlanID = COALESCE(@MaintenancePlanID, 0)
   SELECT  @bakLocation = MP.BackupFilePath
   FROM    dbo.MaintenancePlanSettings MP
   WHERE   MP.MaintenancePlanID = @MaintenancePlanID

   IF NOT EXISTS (SELECT  'X'
                  FROM    dbo.MaintenancePlanSettings
                  WHERE   MaintenancePlanID = @MaintenancePlanID)
      BEGIN
         RAISERROR ('Maintenance Plan ID %d does not exist.',
         16,
         1,
         @MaintenancePlanID)
         RETURN
      END

--Add trailing backwhack if it is missing from the end of the string
   IF CHARINDEX('\', REVERSE(@bakLocation)) > 1
      BEGIN
         SET @bakLocation = @bakLocation + '\'
      END

   DECLARE sDatabases CURSOR FAST_FORWARD
      FOR SELECT  MP.DatabaseName
          FROM    dbo.vwMaintenancePlanDatabases MP
                  INNER JOIN sys.databases SDB
                  ON SDB.[name] = MP.DatabaseName
          --Backup tran logs only for those databases chosen that *also* have recovery model of FULL
          WHERE   SDB.recovery_model_desc = 'FULL'
                  AND MP.MaintenancePlanID = @MaintenancePlanID
   OPEN sDatabases
   FETCH sDatabases INTO @dbName
   WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @dbName = RTRIM(@dbName)
         SET @strSQL = N'BACKUP LOG [' + @dbName + '] TO DISK = ''' + @bakLocation + @dbName + '_backup_' + REPLACE(REPLACE(REPLACE(CONVERT(varchar(20), GETDATE(), 121), ' ', ''), ':', ''), '-', '') + 'trn''
                         WITH NOFORMAT, INIT, NAME = ''' + @dbName + ' - Transaction Log backup'', SKIP, NOREWIND, NOUNLOAD, STATS = 10'
         EXEC sp_executesql @strSQL
         FETCH sDatabases INTO @dbName
      END
   CLOSE sDatabases
   DEALLOCATE sDatabases
END
GO




IF EXISTS (SELECT  'X'
           FROM    sys.objects O
           WHERE   O.[name] = 'procMaintenancePlan_Subplan_5_BackupFull'
                   AND O.[type_desc] = 'SQL_STORED_PROCEDURE')
   BEGIN
      DROP PROCEDURE [dbo].[procMaintenancePlan_Subplan_5_BackupFull]
   END
GO
CREATE PROCEDURE [dbo].[procMaintenancePlan_Subplan_5_BackupFull]
(
 @MaintenancePlanID integer)
AS
BEGIN

   SET NOCOUNT ON

   DECLARE @dbName varchar(255),
      @strSQL nvarchar(255),
      @bakLocation varchar(255)

--If MP ID is passed in as a NULL, default MP ID = 0
   SET @MaintenancePlanID = COALESCE(@MaintenancePlanID, 0)
   SELECT  @bakLocation = MP.BackupFilePath
   FROM    dbo.MaintenancePlanSettings MP
   WHERE   MP.MaintenancePlanID = @MaintenancePlanID

   IF NOT EXISTS (SELECT  'X'
                  FROM    dbo.MaintenancePlanSettings
                  WHERE   MaintenancePlanID = @MaintenancePlanID)
      BEGIN
         RAISERROR ('Maintenance Plan ID %d does not exist.',
         16,
         1,
         @MaintenancePlanID)
         RETURN
      END

--Add trailing backwhack if it is missing from the end of the string
   IF CHARINDEX('\', REVERSE(@bakLocation)) > 1
      BEGIN
         SET @bakLocation = @bakLocation + '\'
      END

   DECLARE sDatabases CURSOR FAST_FORWARD
      FOR SELECT  MP.DatabaseName
          FROM    dbo.vwMaintenancePlanDatabases MP
          WHERE   MP.MaintenancePlanID = @MaintenancePlanID
   OPEN sDatabases
   FETCH sDatabases INTO @dbName
   WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @dbName = RTRIM(@dbName)
         SET @strSQL = N'BACKUP DATABASE [' + @dbName + '] TO DISK = ''' + @bakLocation + @dbName + '_backup_' + REPLACE(REPLACE(REPLACE(CONVERT(varchar(20), GETDATE(), 121), ' ', ''), ':', ''), '-', '') + 'bak''
                         WITH NOFORMAT, INIT, NAME = ''' + @dbName + ' - Full database backup'', SKIP, NOREWIND, NOUNLOAD, STATS = 10'
         EXEC sp_executesql @strSQL
         FETCH sDatabases INTO @dbName
      END
   CLOSE sDatabases
   DEALLOCATE sDatabases
END
GO




IF EXISTS (SELECT  'X'
           FROM    sys.objects O
           WHERE   O.[name] = 'procMaintenancePlan_Subplan_4_CleanupHistory'
                   AND O.[type_desc] = 'SQL_STORED_PROCEDURE')
   BEGIN
      DROP PROCEDURE [dbo].[procMaintenancePlan_Subplan_4_CleanupHistory]
   END
GO
CREATE PROCEDURE [dbo].[procMaintenancePlan_Subplan_4_CleanupHistory]
(
 @MaintenancePlanID integer)
AS
BEGIN

   SET NOCOUNT ON

   DECLARE @PurgeDayCountHistory tinyint,
      @PurgeDateHistory datetime,
      @PurgeDayCountTextReports tinyint,
      @PurgeDateTextReports datetime,
      @TextReportFilePath nvarchar(255),
      @strSQL nvarchar(255)

--If MP ID is passed in as a NULL, default MP ID = 0
   SET @MaintenancePlanID = COALESCE(@MaintenancePlanID, 0)

   IF NOT EXISTS (SELECT  'X'
                  FROM    dbo.MaintenancePlanSettings
                  WHERE   MaintenancePlanID = @MaintenancePlanID)
      BEGIN
         RAISERROR ('Maintenance Plan ID %d does not exist.',
         16,
         1,
         @MaintenancePlanID)
         RETURN
      END

   SELECT  @PurgeDayCountHistory = MP.PurgeDayCountHistory
   FROM    dbo.MaintenancePlanSettings MP
   WHERE   MP.MaintenancePlanID = @MaintenancePlanID
   SELECT  @PurgeDayCountTextReports = MP.PurgeDayCountTextReports
   FROM    dbo.MaintenancePlanSettings MP
   WHERE   MP.MaintenancePlanID = @MaintenancePlanID
   SELECT  @TextReportFilePath = MP.OutputLogFilePath
   FROM    dbo.MaintenancePlanSettings MP
   WHERE   MP.MaintenancePlanID = @MaintenancePlanID

   SET @PurgeDateHistory = GETDATE() - @PurgeDayCountHistory
   SET @PurgeDateTextReports = GETDATE() - @PurgeDayCountTextReports

--Purge aged db backup and job history
   PRINT CHAR(10) + '***************' + CONVERT(varchar(25), GETDATE(), 121) + ': Purging msdb backup history' + '***************'
   SET @strSQL = 'EXEC msdb..sp_delete_backuphistory ''' + CONVERT(varchar(25), @PurgeDateHistory, 121) + ''''
   PRINT 'SQL sent: ' + @strSQL
   EXEC sp_executesql @strSQL

   PRINT CHAR(10) + '***************' + CONVERT(varchar(25), GETDATE(), 121) + ': Purging msdb job history' + '***************'
   SET @strSQL = 'EXEC msdb.dbo.sp_purge_jobhistory @oldest_date = ''' + CONVERT(varchar(25), @PurgeDateHistory, 121) + ''''
   PRINT 'SQL sent: ' + @strSQL
   EXEC sp_executesql @strSQL

--Purge aged job output text reports
   PRINT CHAR(10) + '***************' + CONVERT(varchar(25), GETDATE(), 121) + ': Deleting aged text reports' + '***************'
   SET @strSQL = 'EXEC master..xp_delete_file 0, ''' + @TextReportFilePath + ''', N''txt'', ''' + CONVERT(varchar(25), @PurgeDateTextReports, 121) + ''''
   PRINT 'SQL sent: ' + @strSQL
   EXEC sp_executesql @strSQL

   PRINT CHAR(10) + 'Maintenance cleanup finished: ' + CONVERT(varchar(25), GETDATE(), 121)
END
GO




IF EXISTS (SELECT  'X'
           FROM    sys.objects O
           WHERE   O.[name] = 'procMaintenancePlan_Subplan_3_UpdateStats'
                   AND O.[type_desc] = 'SQL_STORED_PROCEDURE')
   BEGIN
      DROP PROCEDURE [dbo].[procMaintenancePlan_Subplan_3_UpdateStats]
   END
GO
CREATE PROCEDURE [dbo].[procMaintenancePlan_Subplan_3_UpdateStats]
(
 @MaintenancePlanID integer)
AS
BEGIN

   SET NOCOUNT ON

   DECLARE @dbName varchar(255),
      @strSQL nvarchar(255)

--If MP ID is passed in as a NULL, default MP ID = 0
   SET @MaintenancePlanID = COALESCE(@MaintenancePlanID, 0)

   IF NOT EXISTS (SELECT  'X'
                  FROM    dbo.MaintenancePlanSettings
                  WHERE   MaintenancePlanID = @MaintenancePlanID)
      BEGIN
         RAISERROR ('Maintenance Plan ID %d does not exist.',
         16,
         1,
         @MaintenancePlanID)
         RETURN
      END

   DECLARE sDatabases CURSOR FAST_FORWARD
      FOR SELECT  MP.DatabaseName
          FROM    dbo.vwMaintenancePlanDatabases MP
          WHERE   MP.MaintenancePlanID = @MaintenancePlanID
   OPEN sDatabases
   FETCH sDatabases INTO @dbName
   WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @dbName = RTRIM(@dbName)
         PRINT CHAR(10) + '***************' + CONVERT(varchar(25), GETDATE(), 121) + ': UPDATING STATISTICS FOR DATABASE [' + @dbName + ']' + '***************' + CHAR(10)
         SET @strSQL = N'EXEC [' + @dbName + ']..sp_updatestats'
         EXEC sp_executesql @strSQL
         FETCH sDatabases INTO @dbName
      END
   CLOSE sDatabases
   DEALLOCATE sDatabases
END
GO




IF EXISTS (SELECT  'X'
           FROM    sys.objects O
           WHERE   O.[name] = 'procMaintenancePlan_Subplan_2_Reindex'
                   AND O.[type_desc] = 'SQL_STORED_PROCEDURE')
   BEGIN
      DROP PROCEDURE [dbo].[procMaintenancePlan_Subplan_2_Reindex]
   END
GO
CREATE PROCEDURE [dbo].[procMaintenancePlan_Subplan_2_Reindex]
(
 @MaintenancePlanID integer)
AS
BEGIN

   SET NOCOUNT ON

   DECLARE @dbName varchar(255),
      @strSQL nvarchar(255),
      @IndexFillFactor tinyint

--If MP ID is passed in as a NULL, default MP ID = 0
   SET @MaintenancePlanID = COALESCE(@MaintenancePlanID, 0)
   SELECT  @IndexFillFactor = MP.IndexFillFactor
   FROM    dbo.MaintenancePlanSettings MP
   WHERE   MP.MaintenancePlanID = @MaintenancePlanID

   IF NOT EXISTS (SELECT  'X'
                  FROM    dbo.MaintenancePlanSettings
                  WHERE   MaintenancePlanID = @MaintenancePlanID)
      BEGIN
         RAISERROR ('Maintenance Plan ID %d does not exist.',
         16,
         1,
         @MaintenancePlanID)
         RETURN
      END

   IF @IndexFillFactor IS NULL
      BEGIN
         RAISERROR ('Invalid Index fill factor.',
         16,
         1)
         RETURN
      END

   DECLARE sDatabases CURSOR FAST_FORWARD
      FOR SELECT  MP.DatabaseName
          FROM    dbo.vwMaintenancePlanDatabases MP
          WHERE   MP.MaintenancePlanID = @MaintenancePlanID
   OPEN sDatabases
   FETCH sDatabases INTO @dbName
   WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @dbName = RTRIM(@dbName)
         PRINT CHAR(10) + '***************' + CONVERT(varchar(25), GETDATE(), 121) + ': STARTED INDEX REBUILDS FOR DATABASE [' + @dbName + ']' + '***************' + CHAR(10)
         SET @strSQL = N'EXEC [' + @dbName + ']..sp_msForEachTable ''ALTER INDEX ALL ON ? REBUILD WITH (FILLFACTOR = ' + CAST(@IndexFillFactor AS varchar(3)) + ', SORT_IN_TEMPDB = OFF, STATISTICS_NORECOMPUTE = OFF)'''
         EXEC sp_executesql @strSQL
         FETCH sDatabases INTO @dbName
      END
   CLOSE sDatabases
   DEALLOCATE sDatabases
END
GO




IF EXISTS (SELECT  'X'
           FROM    sys.objects O
           WHERE   O.[name] = 'procMaintenancePlan_Subplan_1_CheckDB'
                   AND O.[type_desc] = 'SQL_STORED_PROCEDURE')
   BEGIN
      DROP PROCEDURE [dbo].[procMaintenancePlan_Subplan_1_CheckDB]
   END
GO
CREATE PROCEDURE [dbo].[procMaintenancePlan_Subplan_1_CheckDB]
(
 @MaintenancePlanID integer)
AS
BEGIN

   SET NOCOUNT ON

   DECLARE @dbName varchar(255),
      @strSQL nvarchar(255)

--If MP ID is passed in as a NULL, default MP ID = 0
   SET @MaintenancePlanID = COALESCE(@MaintenancePlanID, 0)

   IF NOT EXISTS (SELECT  'X'
                  FROM    dbo.MaintenancePlanSettings
                  WHERE   MaintenancePlanID = @MaintenancePlanID)
      BEGIN
         RAISERROR ('Maintenance Plan ID %d does not exist.',
         16,
         1,
         @MaintenancePlanID)
         RETURN
      END

   DECLARE sDatabases CURSOR FAST_FORWARD
      FOR SELECT  MP.DatabaseName
          FROM    dbo.vwMaintenancePlanDatabases MP
          WHERE   MP.MaintenancePlanID = @MaintenancePlanID
   OPEN sDatabases
   FETCH sDatabases INTO @dbName
   WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @dbName = RTRIM(@dbName)
         PRINT CHAR(10) + CHAR(10) + '***************' + CONVERT(varchar(25), GETDATE(), 121) + ': PERFORMING DBCC CHECKS FOR DATABASE [' + @dbName + ']' + '***************' + CHAR(10) + CHAR(10)
         SET @strSQL = N'DBCC CHECKDB(''' + @dbName + ''') WITH ALL_ERRORMSGS'
         EXEC sp_executesql @strSQL
         FETCH sDatabases INTO @dbName
      END
   CLOSE sDatabases
   DEALLOCATE sDatabases
END
GO




--Add Custom Maintenance jobs
USE [msdb]
GO

DECLARE @CategoryName varchar(255),
   @JobName varchar(255),
   @OperatorName varchar(255)

SET @CategoryName = 'Custom Database Maintenance'
SET @JobName = 'CustomMaintenance.Seed Maintenance Plan Output Log Files'
SET @OperatorName = 'SQLServer_Admin'




--Add categories if they do not exist
IF NOT EXISTS (SELECT  'X'
               FROM    msdb.dbo.syscategories
               WHERE   name = N'[Uncategorized (Local)]'
                       AND category_class = 1)
   BEGIN
      EXEC msdb.dbo.sp_add_category @class = 'JOB', @type = 'LOCAL', @name = '[Uncategorized (Local)]'
   END
IF NOT EXISTS (SELECT  'X'
               FROM    msdb.dbo.syscategories
               WHERE   name = @CategoryName
                       AND category_class = 1)
   BEGIN
      EXEC msdb.dbo.sp_add_category @class = 'JOB', @type = 'LOCAL', @name = @CategoryName
   END




IF EXISTS (SELECT  'X'
           FROM    msdb.dbo.sysjobs_view
           WHERE   name = @JobName)
   BEGIN
      EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1
   END

EXEC msdb.dbo.sp_add_job @job_name = @JobName, @enabled = 1, @notify_level_eventlog = 2, @notify_level_email = 2, @notify_level_netsend = 0, @notify_level_page = 0, @delete_level = 0, @description = 'This job will update all output log file names for each job in the "Custom Database Maintenance" category.', @category_name = '[Uncategorized (Local)]', @owner_login_name = 'sa', @notify_email_operator_name = @OperatorName
EXEC msdb.dbo.sp_add_jobstep @job_name = @JobName, @step_name = 'Step 1', @step_id = 1, @cmdexec_success_code = 0, @on_success_action = 1, @on_success_step_id = 0, @on_fail_action = 2, @on_fail_step_id = 0, @retry_attempts = 0, @retry_interval = 0, @os_run_priority = 0, @subsystem = 'TSQL', @command = 'EXEC dbo.procMaintenancePlan_SetOutputLog @MaintenancePlanID = 0
GO', @database_name = 'Admin', @flags = 0

EXEC msdb.dbo.sp_update_job @job_name = @JobName, @start_step_id = 1

EXEC msdb.dbo.sp_add_jobschedule @job_name = @JobName, @name = 'Schedule 1', @enabled = 1, @freq_type = 4, @freq_interval = 1, @freq_subday_type = 4, @freq_subday_interval = 1, @freq_relative_interval = 0, @freq_recurrence_factor = 0, @active_start_date = 20090101, @active_end_date = 99991231, @active_start_time = 0, @active_end_time = 235959

EXEC msdb.dbo.sp_add_jobserver @job_name = @JobName, @server_name = N'(local)'




SET @JobName = 'CustomMaintenance.Subplan_1_CheckDB'

IF EXISTS (SELECT  'X'
           FROM    msdb.dbo.sysjobs_view
           WHERE   name = @JobName)
   BEGIN
      EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1
   END

EXEC msdb.dbo.sp_add_job @job_name = @JobName, @enabled = 1, @notify_level_eventlog = 2, @notify_level_email = 2, @notify_level_netsend = 0, @notify_level_page = 0, @delete_level = 0, @description = NULL, @category_name = @CategoryName, @owner_login_name = 'sa', @notify_email_operator_name = @OperatorName
EXEC msdb.dbo.sp_add_jobstep @job_name = @JobName, @step_name = 'Step 1', @step_id = 1, @cmdexec_success_code = 0, @on_success_action = 1, @on_success_step_id = 0, @on_fail_action = 2, @on_fail_step_id = 0, @retry_attempts = 0, @retry_interval = 0, @os_run_priority = 0, @subsystem = 'TSQL', @command = 'EXEC dbo.procMaintenancePlan_Subplan_1_CheckDB @MaintenancePlanID = 0
GO', @database_name = 'Admin', @flags = 0

EXEC msdb.dbo.sp_update_job @job_name = @JobName, @start_step_id = 1

EXEC msdb.dbo.sp_add_jobschedule @job_name = @JobName, @name = 'Schedule 1', @enabled = 1, @freq_type = 8, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 1, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = 20090101, @active_end_date = 99991231, @active_start_time = 0, @active_end_time = 235959

EXEC msdb.dbo.sp_add_jobserver @job_name = @JobName, @server_name = N'(local)'




SET @JobName = 'CustomMaintenance.Subplan_2_Reindex'

IF EXISTS (SELECT  'X'
           FROM    msdb.dbo.sysjobs_view
           WHERE   name = @JobName)
   BEGIN
      EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1
   END

EXEC msdb.dbo.sp_add_job @job_name = @JobName, @enabled = 1, @notify_level_eventlog = 2, @notify_level_email = 2, @notify_level_netsend = 0, @notify_level_page = 0, @delete_level = 0, @description = NULL, @category_name = @CategoryName, @owner_login_name = 'sa', @notify_email_operator_name = @OperatorName
EXEC msdb.dbo.sp_add_jobstep @job_name = @JobName, @step_name = 'Step 1', @step_id = 1, @cmdexec_success_code = 0, @on_success_action = 1, @on_success_step_id = 0, @on_fail_action = 2, @on_fail_step_id = 0, @retry_attempts = 0, @retry_interval = 0, @os_run_priority = 0, @subsystem = 'TSQL', @command = 'EXEC dbo.procMaintenancePlan_Subplan_2_Reindex @MaintenancePlanID = 0
GO', @database_name = 'Admin', @flags = 0

EXEC msdb.dbo.sp_update_job @job_name = @JobName, @start_step_id = 1

EXEC msdb.dbo.sp_add_jobschedule @job_name = @JobName, @name = 'Schedule 1', @enabled = 1, @freq_type = 8, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 1, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = 20090101, @active_end_date = 99991231, @active_start_time = 10000, @active_end_time = 235959

EXEC msdb.dbo.sp_add_jobserver @job_name = @JobName, @server_name = N'(local)'




SET @JobName = 'CustomMaintenance.Subplan_3_UpdateStats'

IF EXISTS (SELECT  'X'
           FROM    msdb.dbo.sysjobs_view
           WHERE   name = @JobName)
   BEGIN
      EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1
   END

EXEC msdb.dbo.sp_add_job @job_name = @JobName, @enabled = 1, @notify_level_eventlog = 2, @notify_level_email = 2, @notify_level_netsend = 0, @notify_level_page = 0, @delete_level = 0, @description = NULL, @category_name = @CategoryName, @owner_login_name = 'sa', @notify_email_operator_name = @OperatorName
EXEC msdb.dbo.sp_add_jobstep @job_name = @JobName, @step_name = 'Step 1', @step_id = 1, @cmdexec_success_code = 0, @on_success_action = 1, @on_success_step_id = 0, @on_fail_action = 2, @on_fail_step_id = 0, @retry_attempts = 0, @retry_interval = 0, @os_run_priority = 0, @subsystem = 'TSQL', @command = 'EXEC dbo.procMaintenancePlan_Subplan_3_UpdateStats @MaintenancePlanID = 0
GO', @database_name = 'Admin', @flags = 0

EXEC msdb.dbo.sp_update_job @job_name = @JobName, @start_step_id = 1

EXEC msdb.dbo.sp_add_jobschedule @job_name = @JobName, @name = 'Schedule 1', @enabled = 1, @freq_type = 4, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 1, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = 20090101, @active_end_date = 99991231, @active_start_time = 20000, @active_end_time = 235959

EXEC msdb.dbo.sp_add_jobserver @job_name = @JobName, @server_name = N'(local)'




SET @JobName = 'CustomMaintenance.Subplan_4_CleanupHistory'

IF EXISTS (SELECT  'X'
           FROM    msdb.dbo.sysjobs_view
           WHERE   name = @JobName)
   BEGIN
      EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1
   END

EXEC msdb.dbo.sp_add_job @job_name = @JobName, @enabled = 1, @notify_level_eventlog = 2, @notify_level_email = 2, @notify_level_netsend = 0, @notify_level_page = 0, @delete_level = 0, @description = NULL, @category_name = @CategoryName, @owner_login_name = 'sa', @notify_email_operator_name = @OperatorName
EXEC msdb.dbo.sp_add_jobstep @job_name = @JobName, @step_name = 'Step 1', @step_id = 1, @cmdexec_success_code = 0, @on_success_action = 1, @on_success_step_id = 0, @on_fail_action = 2, @on_fail_step_id = 0, @retry_attempts = 0, @retry_interval = 0, @os_run_priority = 0, @subsystem = 'TSQL', @command = 'EXEC dbo.procMaintenancePlan_Subplan_4_CleanupHistory @MaintenancePlanID = 0
GO', @database_name = 'Admin', @flags = 0

EXEC msdb.dbo.sp_update_job @job_name = @JobName, @start_step_id = 1

EXEC msdb.dbo.sp_add_jobschedule @job_name = @JobName, @name = 'Schedule 1', @enabled = 1, @freq_type = 8, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 1, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = 20090101, @active_end_date = 99991231, @active_start_time = 30000, @active_end_time = 235959

EXEC msdb.dbo.sp_add_jobserver @job_name = @JobName, @server_name = N'(local)'




SET @JobName = 'CustomMaintenance.Subplan_5_BackupFull'

IF EXISTS (SELECT  'X'
           FROM    msdb.dbo.sysjobs_view
           WHERE   name = @JobName)
   BEGIN
      EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1
   END

EXEC msdb.dbo.sp_add_job @job_name = @JobName, @enabled = 1, @notify_level_eventlog = 2, @notify_level_email = 2, @notify_level_netsend = 0, @notify_level_page = 0, @delete_level = 0, @description = NULL, @category_name = @CategoryName, @owner_login_name = 'sa', @notify_email_operator_name = @OperatorName
EXEC msdb.dbo.sp_add_jobstep @job_name = @JobName, @step_name = 'Step 1', @step_id = 1, @cmdexec_success_code = 0, @on_success_action = 1, @on_success_step_id = 0, @on_fail_action = 2, @on_fail_step_id = 0, @retry_attempts = 0, @retry_interval = 0, @os_run_priority = 0, @subsystem = 'TSQL', @command = 'EXEC dbo.procMaintenancePlan_Subplan_5_BackupFull @MaintenancePlanID = 0
GO', @database_name = 'Admin', @flags = 0

EXEC msdb.dbo.sp_update_job @job_name = @JobName, @start_step_id = 1

EXEC msdb.dbo.sp_add_jobschedule @job_name = @JobName, @name = 'Schedule 1', @enabled = 1, @freq_type = 4, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 1, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = 20090101, @active_end_date = 99991231, @active_start_time = 200000, @active_end_time = 235959

EXEC msdb.dbo.sp_add_jobserver @job_name = @JobName, @server_name = N'(local)'




SET @JobName = 'CustomMaintenance.Subplan_6_BackupTranLogs'

IF EXISTS (SELECT  'X'
           FROM    msdb.dbo.sysjobs_view
           WHERE   name = @JobName)
   BEGIN
      EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1
   END

EXEC msdb.dbo.sp_add_job @job_name = @JobName, @enabled = 1, @notify_level_eventlog = 2, @notify_level_email = 2, @notify_level_netsend = 0, @notify_level_page = 0, @delete_level = 0, @description = NULL, @category_name = @CategoryName, @owner_login_name = 'sa', @notify_email_operator_name = @OperatorName
EXEC msdb.dbo.sp_add_jobstep @job_name = @JobName, @step_name = 'Step 1', @step_id = 1, @cmdexec_success_code = 0, @on_success_action = 1, @on_success_step_id = 0, @on_fail_action = 2, @on_fail_step_id = 0, @retry_attempts = 0, @retry_interval = 0, @os_run_priority = 0, @subsystem = 'TSQL', @command = 'EXEC dbo.procMaintenancePlan_Subplan_6_BackupTranLogs @MaintenancePlanID = 0
GO', @database_name = 'Admin', @flags = 0

EXEC msdb.dbo.sp_update_job @job_name = @JobName, @start_step_id = 1

EXEC msdb.dbo.sp_add_jobschedule @job_name = @JobName, @name = 'Schedule 1', @enabled = 1, @freq_type = 4, @freq_interval = 1, @freq_subday_type = 8, @freq_subday_interval = 2, @freq_relative_interval = 0, @freq_recurrence_factor = 0, @active_start_date = 20090101, @active_end_date = 99991231, @active_start_time = 0, @active_end_time = 235959

EXEC msdb.dbo.sp_add_jobserver @job_name = @JobName, @server_name = N'(local)'




SET @JobName = 'CustomMaintenance.Subplan_7_CleanupBackups'

IF EXISTS (SELECT  'X'
           FROM    msdb.dbo.sysjobs_view
           WHERE   name = @JobName)
   BEGIN
      EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1
   END

EXEC msdb.dbo.sp_add_job @job_name = @JobName, @enabled = 1, @notify_level_eventlog = 2, @notify_level_email = 2, @notify_level_netsend = 0, @notify_level_page = 0, @delete_level = 0, @description = NULL, @category_name = @CategoryName, @owner_login_name = 'sa', @notify_email_operator_name = @OperatorName
EXEC msdb.dbo.sp_add_jobstep @job_name = @JobName, @step_name = 'Step 1', @step_id = 1, @cmdexec_success_code = 0, @on_success_action = 1, @on_success_step_id = 0, @on_fail_action = 2, @on_fail_step_id = 0, @retry_attempts = 0, @retry_interval = 0, @os_run_priority = 0, @subsystem = 'TSQL', @command = 'EXEC dbo.procMaintenancePlan_Subplan_7_CleanupBackups @MaintenancePlanID = 0
GO', @database_name = 'Admin', @flags = 0

EXEC msdb.dbo.sp_update_job @job_name = @JobName, @start_step_id = 1

EXEC msdb.dbo.sp_add_jobschedule @job_name = @JobName, @name = 'Schedule 1', @enabled = 1, @freq_type = 4, @freq_interval = 1, @freq_subday_type = 1, @freq_subday_interval = 1, @freq_relative_interval = 0, @freq_recurrence_factor = 1, @active_start_date = 20090101, @active_end_date = 99991231, @active_start_time = 195500, @active_end_time = 235959

EXEC msdb.dbo.sp_add_jobserver @job_name = @JobName, @server_name = N'(local)'
GO