USE [msdb]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].pEmailSQLServerHealth (@ServerIP varchar(100), -- SQL Server 2005 Database Server IP Address
                                              @Project varchar(100), -- Name of project or cleint 
                                              @Recepients varchar(2000), -- Recepient(s) of this email (; separated in case of multiple recepients).
                                              @MailProfile varchar(100), -- Mail profile name which exists on the target database server
                                              @Owner varchar(200) -- Owner, basically name/email of the DBA responsible for the server
)
AS
BEGIN
/*

Automating SQL Server Health Check (SQL Server 2005)
By Ritesh Medhe, 2010/01/28 
http://www.sqlservercentral.com/articles/Automating+SQL+Server+Health+Checks/68910/

Features
    * Ensuring jobs have run successfully; also check if any job is running in endless loop, check if any new job has been created.
    * Check whether the backups have happened.
    * Ensure that the backups are deleted as per the retention policy from the disk and there are no unnecessary files lying on the disk which could cause backup failure.
    * Keep an eye on disk space.
    * Check if any new database has been created.
    * Check if there is drastic increase in size of any of the databases.

Prerequisites
    * SQL Server 2005.
    * Valid Database Mail Profile.
    * Sysadmin privilege as this procedure refers to lots of system objects in msdb and master database.
    * xp_cmdshell should be enabled as the code executes DIR command.

Example
	exec pEmailSQLServerHealth '10.10.10.10',  'MYProject', 'myself@mycompany.com', 'TestMailProfile', 'My Self'

*/

   SET NOCOUNT ON

	/* Drop all the temp tables(not necessary at all as local temp tables get dropped as soon as session is released, 
	however, good to follow this practice). */
   IF EXISTS (SELECT  1
              FROM    sysobjects
              WHERE   Name = '#jobs_status')
      BEGIN
         DROP TABLE #jobs_status
      END

   IF EXISTS (SELECT  1
              FROM    sysobjects
              WHERE   Name = '#diskspace')
      BEGIN
         DROP TABLE #diskspace
      END

   IF EXISTS (SELECT  Name
              FROM    sysobjects
              WHERE   Name = '#url')
      BEGIN
         DROP TABLE #url
      END

   IF EXISTS (SELECT  Name
              FROM    sysobjects
              WHERE   Name = '#dirpaths')
      BEGIN
         DROP TABLE #dirpaths
      END    

-- Create the temp tables which will be used to hold the data. 
   CREATE TABLE #url (idd int IDENTITY(1,1),
                      url varchar(1000))

   CREATE TABLE #dirpaths (files varchar(2000))

   CREATE TABLE #diskspace (drive varchar(200),
                            diskspace int)

-- This table will hold data from sp_help_job (System sp in MSDB database)
   CREATE TABLE #jobs_status (job_id uniqueidentifier,
                              originating_server nvarchar(30),
                              Name sysname,
                              enabled tinyint,
                              description nvarchar(512),
                              start_step_id int,
                              category sysname,
                              owner sysname,
                              notify_level_eventlog int,
                              notify_level_email int,
                              notify_level_netsend int,
                              notify_level_page int,
                              notify_email_operator sysname,
                              notify_netsend_operator sysname,
                              notify_page_operator sysname,
                              delete_level int,
                              date_created datetime,
                              date_modified datetime,
                              version_number int,
                              last_run_date int,
                              last_run_time int,
                              last_run_outcome int,
                              next_run_date int,
                              next_run_time int,
                              next_run_schedule_id int,
                              current_execution_status int,
                              current_execution_step sysname,
                              current_retry_attempt int,
                              has_step int,
                              has_schedule int,
                              has_target int,
                              Type int)    

-- To insert data in couple of temp tables created above.
   INSERT  #diskspace (drive, diskspace)
           EXEC xp_fixeddrives
   INSERT  #jobs_status
           EXEC msdb.dbo.sp_help_job  

-- Variable declaration   
   DECLARE @TableHTML varchar(max),
      @StrSubject varchar(100),
      @Oriserver varchar(100),
      @Version varchar(250),
      @Edition varchar(100),
      @ISClustered varchar(100),
      @SP varchar(100),
      @ServerCollation varchar(100),
      @SingleUser varchar(5),
      @LicenseType varchar(100),
      @StartDate datetime,
      @EndDate datetime,
      @Cnt int,
      @URL varchar(1000),
      @Str varchar(1000)
		
-- Variable Assignment
   SELECT  @Version = @@VERSION
   SELECT  @Edition = CONVERT(varchar(100), SERVERPROPERTY('Edition'))
   SELECT  @StartDate = CAST(CONVERT(varchar(4), DATEPART(yyyy, GETDATE())) + '-' + CONVERT(varchar(2), DATEPART(mm, GETDATE())) + '-01' AS datetime)
   SELECT  @StartDate = @StartDate - 1
   SELECT  @EndDate = CAST(CONVERT(varchar(5), DATEPART(yyyy, GETDATE() + 1)) + '-' + CONVERT(varchar(2), DATEPART(mm, GETDATE() + 1)) + '-' + CONVERT(varchar(2), DATEPART(dd, GETDATE() + 1)) AS datetime)
   SET @Cnt = 0

   IF SERVERPROPERTY('IsClustered') = 0
      BEGIN
         SELECT  @ISClustered = 'No'
      END
   ELSE
      BEGIN
         SELECT  @ISClustered = 'YES'
      END

   SELECT  @SP = CONVERT(varchar(100), SERVERPROPERTY('productlevel'))
   SELECT  @ServerCollation = CONVERT(varchar(100), SERVERPROPERTY('Collation'))
   SELECT  @LicenseType = CONVERT(varchar(100), SERVERPROPERTY('LicenseType'))
   SELECT  @SingleUser = CASE SERVERPROPERTY('IsSingleUser')
                           WHEN 1 THEN 'Yes'
                           WHEN 0 THEN 'No'
                           ELSE 'null'
                         END
   SELECT  @OriServer = CONVERT(varchar(50), SERVERPROPERTY('servername'))
   SELECT  @strSubject = 'DB Server Daily Health Checks (' + CONVERT(varchar(50), SERVERPROPERTY('servername')) + ')'    
  
/*
Along with refrences to SQL Server System objects, You will also see lots of HTML code however do not worry, 
Even though I am a primarily a SQL Server DBA, I am little fond of HTML, 
so thought to show some of my HTML skills here :), trust me you would love to see the end product....
*/
   SET @TableHTML = '<font face="Verdana" size="4">Server Info</font>  
	<table border="1" cellpadding="0" cellspacing="0" style="border-collapse: collapse" bordercolor="#111111" width="47%" id="AutoNumber1" height="50">  
	<tr>  
	<td width="27%" height="22" bgcolor="#000080"><b>  
	<font face="Verdana" size="2" color="#FFFFFF">Server IP</font></b></td>  
	<td width="39%" height="22" bgcolor="#000080"><b>  
	<font face="Verdana" size="2" color="#FFFFFF">Server Name</font></b></td>  
	<td width="90%" height="22" bgcolor="#000080"><b>  
	<font face="Verdana" size="2" color="#FFFFFF">Project/Client</font></b></td>  
	</tr>  
	<tr>  
	<td width="27%" height="27"><font face="Verdana" size="2">' + @ServerIP + '</font></td>  
	<td width="39%" height="27"><font face="Verdana" size="2">' + @OriServer + '</font></td>  
	<td width="90%" height="27"><font face="Verdana" size="2">' + @Project + '</font></td>  
	</tr>  
	</table> 

	<table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="1">
	<tr>
	<td width="50%" bgColor="#000080" height="15"><b>
	<font face="Verdana" color="#ffffff" size="1">Version</font></b></td>
	<td width="17%" bgColor="#000080" height="15"><b>
	<font face="Verdana" color="#ffffff" size="1">Edition</font></b></td>
	<td width="18%" bgColor="#000080" height="15"><b>
	<font face="Verdana" color="#ffffff" size="1">Service Pack</font></b></td>
	<td width="93%" bgColor="#000080" height="15"><b>
	<font face="Verdana" color="#ffffff" size="1">Collation</font></b></td>
	<td width="93%" bgColor="#000080" height="15"><b>
	<font face="Verdana" color="#ffffff" size="1">LicenseType</font></b></td>
	<td width="30%" bgColor="#000080" height="15"><b>
	<font face="Verdana" color="#ffffff" size="1">SingleUser</font></b></td>
	<td width="93%" bgColor="#000080" height="15"><b>
	<font face="Verdana" color="#ffffff" size="1">Clustered</font></b></td>
	</tr>
	<tr>
	<td width="50%" height="27"><font face="Verdana" size="1">' + @version + '</font></td>
	<td width="17%" height="27"><font face="Verdana" size="1">' + @edition + '</font></td>
	<td width="18%" height="27"><font face="Verdana" size="1">' + @SP + '</font></td>
	<td width="17%" height="27"><font face="Verdana" size="1">' + @ServerCollation + '</font></td>
	<td width="25%" height="27"><font face="Verdana" size="1">' + @LicenseType + '</font></td>
	<td width="25%" height="27"><font face="Verdana" size="1">' + @SingleUser + '</font></td>
	<td width="93%" height="27"><font face="Verdana" size="1">' + @isclustered + '</font></td>
	</tr>
	</table>

	<p style="margin-top: 0; margin-bottom: 0">&nbsp;</p>' + '<table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="933" bgColor="#ffffff" borderColorLight="#000000" border="1">  
	<tr>  
	<th align="left" width="432" bgColor="#000080">  
	<font face="Verdana" size="1" color="#FFFFFF">Job Name</font></th>  
	<th align="left" width="91" bgColor="#000080">  
	<font face="Verdana" size="1" color="#FFFFFF">Enabled</font></th>  
	<th align="left" width="85" bgColor="#000080">  
	<font face="Verdana" size="1" color="#FFFFFF">Last Run</font></th>  
	<th align="left" width="183" bgColor="#000080">  
	<font face="Verdana" size="1" color="#FFFFFF">Category</font></th>  
	<th align="left" width="136" bgColor="#000080">  
	<font face="Verdana" size="1" color="#FFFFFF">Last Run Date</font></th>  
	<th align="left" width="136" bgColor="#000080">  
	<font face="Verdana" size="1" color="#FFFFFF">Execution Time (Mi)</font></th>  
	</tr>
	<font face="Verdana" size="4">Job Status</font>'

   SELECT  @TableHTML = @TableHTML + '<tr><td><font face="Verdana" size="1">' + ISNULL(CONVERT(varchar(100), A.name), '') + '</font></td>' + CASE enabled
                                                                                                                                               WHEN 0 THEN '<td bgcolor="#FFCC99"><b><font face="Verdana" size="1">False</font></b></td>'
                                                                                                                                               WHEN 1 THEN '<td><font face="Verdana" size="1">True</font></td>'
                                                                                                                                               ELSE '<td><font face="Verdana" size="1">Unknown</font></td>'
                                                                                                                                             END + CASE last_run_outcome
                                                                                                                                                     WHEN 0 THEN '<td bgColor="#ff0000"><b><blink><font face="Verdana" size="2"><a href="mailto:servicedesk@mycompany.com?subject=Job failure - ' + @Oriserver + '(' + @ServerIP + ') ' + CONVERT(varchar(15), GETDATE(), 101) + '&cc=db.support@mycompany.com&body = SD please log this call to DB support,' + '%0A %0A' + '<<' + ISNULL(CONVERT(varchar(100), Name), '''') + '>> Job Failed on ' + @OriServer + '(' + @ServerIP + ')' + '.' + '%0A%0A Regards,' + '">Failed</a></font></blink></b></td>'
                                                                                                                                                     WHEN 1 THEN '<td><font face="Verdana" size="1">Success</font></td>'
                                                                                                                                                     WHEN 3 THEN '<td><font face="Verdana" size="1">Cancelled</font></td>'
                                                                                                                                                     WHEN 5 THEN '<td><font face="Verdana" size="1">Unknown</font></td>'
                                                                                                                                                     ELSE '<td><font face="Verdana" size="1">Other</font></td>'
                                                                                                                                                   END + '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(varchar(100), A.category), '') + '</font></td>' + '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(varchar(50), A.last_run_date), '') + '</font></td>' + '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(varchar(50), X.execution_time_minutes), '') + '</font></td> </tr>'
   FROM    #jobs_status A
           INNER JOIN (SELECT  A.job_id, DATEDIFF(mi, A.last_executed_step_date, A.stop_execution_date) execution_time_minutes
                       FROM    msdb..sysjobactivity A
                               INNER JOIN (SELECT  MAX(session_id) sessionid, job_id
                                           FROM    msdb..sysjobactivity
                                           GROUP BY job_id) B
                                  ON a.job_id = B.job_id
                                     AND a.session_id = b.sessionid
                               INNER JOIN (SELECT DISTINCT Name, job_id
                                           FROM            msdb..sysjobs) C
                                  ON A.job_id = c.job_id) X
              ON A.job_id = X.job_id
   ORDER BY last_run_date DESC

   SELECT  @TableHTML = @TableHTML + '<table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="933" border="1">
	<tr>
		<td width="35%" bgColor="#000080" height="15"><b>
		<font face="Verdana" size="1" color="#FFFFFF">Name</font></b></td>
		<td width="23%" bgColor="#000080" height="15"><b>
		<font face="Verdana" size="1" color="#FFFFFF">CreatedDate</font></b></td>
		<td width="23%" bgColor="#000080" height="15"><b>
		<font face="Verdana" size="1" color="#FFFFFF">DB Size(GB)</font></b></td>
		<td width="30%" bgColor="#000080" height="15"><b>
		<font face="Verdana" size="1" color="#FFFFFF">State</font></b></td>
		<td width="50%" bgColor="#000080" height="15"><b>
		<font face="Verdana" size="1" color="#FFFFFF">RecoveryModel</font></b></td>
	</tr>
	<p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>
	<font face="Verdana" size="4">Databases</font>'

   SELECT  @TableHTML = @TableHTML + '<tr><td><font face="Verdana" size="1">' + ISNULL(Name, '') + '</font></td>' + '<td><font face="Verdana" size="1">' + CONVERT(varchar(2), DATEPART(dd, create_date)) + '-' + CONVERT(varchar(3), DATENAME(mm, create_date)) + '-' + CONVERT(varchar(4), DATEPART(yy, create_date)) + '</font></td>' + '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(varchar(10), AA.[Total SIZE GB]), '') + '</font></td>' + '<td><font face="Verdana" size="1">' + ISNULL(state_desc, '') + '</font></td>' + '<td><font face="Verdana" size="1">' + ISNULL(recovery_model_desc, '') + '</font></td></tr>'
   FROM    sys.databases MST
           INNER JOIN (SELECT  b.name [LOG_DBNAME], CONVERT(decimal(10,2), SUM(CONVERT(decimal(10,2), (a.size * 8)) / 1024) / 1024) [Total SIZE GB]
                       FROM    sys.sysaltfiles A
                               INNER JOIN sys.databases B
                                  ON A.dbid = B.database_id
                       GROUP BY b.name) AA
              ON AA.[LOG_DBNAME] = MST.name
   ORDER BY MST.name

   SELECT  @TableHTML = @TableHTML + '<table id="AutoNumber1" style="BORDER-COLLAPSE: collapse" borderColor="#111111" height="40" cellSpacing="0" cellPadding="0" width="24%" border="1">
	  <tr>
		<td width="27%" bgColor="#000080" height="15"><b>
		<font face="Verdana" size="1" color="#FFFFFF">Disk</font></b></td>
		<td width="59%" bgColor="#000080" height="15"><b>
		<font face="Verdana" size="1" color="#FFFFFF">Free Space (GB)</font></b></td>
	  </tr>
	<p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>
	<p><font face="Verdana" size="4">Disk Stats</font></p>'

   SELECT  @TableHTML = @TableHTML + '<tr><td><font face="Verdana" size="1">' + ISNULL(CONVERT(varchar(100), drive), '') + '</font></td>' + '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(varchar(100), ISNULL(CAST(CAST(diskspace AS decimal(10,2)) / 1024 AS decimal(10,2)), 0)), '') + '</font></td></tr>'
   FROM    #diskspace

   SELECT  @TableHTML = @TableHTML + '</table>'

-- Code for SQL Server Database Backup Stats
   SELECT  @TableHTML = @TableHTML + '<table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="933" bgColor="#ffffff" borderColorLight="#000000" border="1">    
	<tr>    
	<th align="left" width="91" bgColor="#000080">    
	<font face="Verdana" size="1" color="#FFFFFF">Date</font></th>    
	<th align="left" width="105" bgColor="#000080">    
	<font face="Verdana" size="1" color="#FFFFFF">Database</font></th>    
	<th align="left" width="165" bgColor="#000080">    
	 <font face="Verdana" size="1" color="#FFFFFF">File Name</font></th>    
	<th align="left" width="75" bgColor="#000080">    
	 <font face="Verdana" size="1" color="#FFFFFF">Type</font></th>    
	<th align="left" width="165" bgColor="#000080"> 
	<font face="Verdana" size="1" color="#FFFFFF">Start Time</font></th>    
	<th align="left" width="165" bgColor="#000080">    
	<font face="Verdana" size="1" color="#FFFFFF">End Time</font></th>    
	<th align="left" width="136" bgColor="#000080">    
	<font face="Verdana" size="1" color="#FFFFFF">Size(GB)</font></th>  
	</tr> 
	<p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>
	<p><font face="Verdana" size="4">SQL SERVER Database Backup Stats</font></p>'


   SELECT  @TableHTML = @TableHTML + '<tr><td><font face="Verdana" size="1">' + ISNULL(CONVERT(varchar(2), DATEPART(dd, MST.backup_start_date)) + '-' + CONVERT(varchar(3), DATENAME(mm, MST.backup_start_date)) + '-' + CONVERT(varchar(4), DATEPART(yyyy, MST.backup_start_date)), '') + '</font></td>' + '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(varchar(100), MST.database_name), '') + '</font></td>' + '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(varchar(100), MST.name), '') + '</font></td>' + CASE Type
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   WHEN 'D' THEN '<td><font face="Verdana" size="1">' + 'Full' + '</font></td>'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   WHEN 'I' THEN '<td><font face="Verdana" size="1">' + 'Differential' + '</font></td>'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   WHEN 'L' THEN '<td><font face="Verdana" size="1">' + 'Log' + '</font></td>'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   WHEN 'F' THEN '<td><font face="Verdana" size="1">' + 'File or Filegroup' + '</font></td>'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   WHEN 'G' THEN '<td><font face="Verdana" size="1">' + 'File Differential' + '</font></td>'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   WHEN 'P' THEN '<td><font face="Verdana" size="1">' + 'Partial' + '</font></td>'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   WHEN 'Q' THEN '<td><font face="Verdana" size="1">' + 'Partial Differential' + '</font></td>'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ELSE '<td><font face="Verdana" size="1">' + 'Unknown' + '</font></td>'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 END + '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(varchar(50), MST.backup_start_date), '') + '</font></td>' + '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(varchar(50), MST.backup_finish_date), '') + '</font></td>' + '<td><font face="Verdana" size="1">' + ISNULL(CONVERT(varchar(10), CAST((MST.backup_size / 1024) / 1024 / 1024 AS decimal(10,2))), '') + '</font></td>' + '</tr>'
   FROM    backupset MST
   WHERE   MST.backup_start_date BETWEEN @StartDate
           AND @EndDate
   ORDER BY MST.backup_start_date DESC

   SELECT  @TableHTML = @TableHTML + '</table>'

-- Code for physical database backup file present on disk
   INSERT  #url
           SELECT DISTINCT SUBSTRING(BMF.physical_device_name, 1, LEN(BMF.physical_device_name) - CHARINDEX('\', REVERSE(BMF.physical_device_name), 0))
           FROM            backupset MST
                           INNER JOIN backupmediafamily BMF
                              ON BMF.media_set_id = MST.media_set_id
           WHERE           MST.backup_start_date BETWEEN @startdate
                           AND @enddate

   SELECT  @Cnt = COUNT(*)
   FROM    #url
   WHILE @Cnt > 0
      BEGIN

         SELECT  @URL = url
         FROM    #url
         WHERE   idd = @Cnt
         SELECT  @Str = 'EXEC master.dbo.xp_cmdshell ''dir "' + @URL + '" /B/O:D'''

         INSERT  #dirpaths
                 SELECT  'PATH: ' + @URL
         INSERT  #dirpaths
                 EXEC (@Str)

         INSERT  #dirpaths
         VALUES  ('')

         SET @Cnt = @Cnt - 1

      END

   DELETE  FROM #dirpaths
   WHERE   files IS NULL

   SELECT  @TableHTML = @TableHTML + '<table style="BORDER-COLLAPSE: collapse" borderColor="#111111" cellPadding="0" width="933" bgColor="#ffffff" borderColorLight="#000000" border="1">
	<tr>
	<th align="left" width="91" bgColor="#000080">
	<font face="Verdana" size="1" color="#FFFFFF">Physical Files</font></th>
	</tr>
	<p style="margin-top: 1; margin-bottom: 0">&nbsp;</p>
	<p><font face="Verdana" size="4">Physical Backup Files</font></p>'

   SELECT  @TableHTML = @TableHTML + '<tr>' + CASE SUBSTRING(files, 1, 5)
                                                WHEN 'PATH:' THEN '<td bgcolor = "#D7D7D7"><b><font face="Verdana" size="1">' + files + '</font><b></td>'
                                                ELSE '<td><font face="Verdana" size="1">' + files + '</font></td>'
                                              END + '</tr>'
   FROM    #dirpaths

   SELECT  @TableHTML = @TableHTML + '</table>' + '<p style="margin-top: 0; margin-bottom: 0">&nbsp;</p>
	<hr color="#000000" size="1">
	<p><font face="Verdana" size="2"><b>Server Owner:</b> ' + @owner + '</font></p>  
	<p style="margin-top: 0; margin-bottom: 0"><font face="Verdana" size="2">Thanks   
	and Regards,</font></p>  
	<p style="margin-top: 0; margin-bottom: 0"><font face="Verdana" size="2">DB   
	Support Team</font></p>  
	<p>&nbsp;</p>'

   IF @MailProfile IS NOT NULL
      BEGIN
         EXEC msdb.dbo.sp_send_dbmail @profile_name = @MailProfile, @recipients = @Recepients, @subject = @strSubject, @body = @TableHTML, @body_format = 'HTML' ;
      END

   SET NOCOUNT OFF
END