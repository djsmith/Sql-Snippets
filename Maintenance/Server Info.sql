/* 	
Script to get Server Info
By Pradyothana Shastry, 2010/02/12 
http://www.sqlservercentral.com/scripts/T-SQL/69348/
*/

--Step 1: Setting NULLs and quoted identifiers to ON and checking the version of SQL Server 
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF EXISTS (SELECT  *
           FROM    dbo.sysobjects
           WHERE   id = OBJECT_ID(N'prodver')
                   AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
   BEGIN
      DROP TABLE prodver
   END
CREATE TABLE prodver ([index] int,
                      Name nvarchar(50),
                      Internal_value int,
                      Charcater_Value nvarchar(50))
INSERT  INTO prodver
        EXEC xp_msver 'ProductVersion'
IF
(SELECT  substring(Charcater_Value, 1, 1)
 FROM    prodver) != 8
   BEGIN
	
                   
-- Step 2: This code will be used if the instance is Not SQL Server 2000 

      DECLARE @image_path nvarchar(100)
      DECLARE @startup_type int
      DECLARE @startuptype nvarchar(100)
      DECLARE @start_username nvarchar(100)
      DECLARE @instance_name nvarchar(100)
      DECLARE @system_instance_name nvarchar(100)
      DECLARE @log_directory nvarchar(100)
      DECLARE @key nvarchar(1000)
      DECLARE @registry_key nvarchar(100)
      DECLARE @registry_key1 nvarchar(300)
      DECLARE @registry_key2 nvarchar(300)
      DECLARE @IpAddress nvarchar(20)
      DECLARE @domain nvarchar(50)
      DECLARE @cluster int
      DECLARE @instance_name1 nvarchar(100)          
      
                    
-- Step 3: Reading registry keys for IP,Binaries,Startup type ,startup username, errorlogs location and domain.
      
      SET @instance_name = coalesce(CONVERT(nvarchar(100), serverproperty('InstanceName')), 'MSSQLSERVER') ;
      IF @instance_name != 'MSSQLSERVER'
         BEGIN
            SET @instance_name = @instance_name
         END

      SET @instance_name1 = coalesce(CONVERT(nvarchar(100), serverproperty('InstanceName')), 'MSSQLSERVER') ;
      IF @instance_name1 != 'MSSQLSERVER'
         BEGIN
            SET @instance_name1 = 'MSSQL$' + @instance_name1
         END
      EXEC master.dbo.xp_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\Microsoft SQL Server\Instance Names\SQL', @instance_name, @system_instance_name OUTPUT ;

      SET @key = N'SYSTEM\CurrentControlSet\Services\' + @instance_name1 ;
      SET @registry_key = N'Software\Microsoft\Microsoft SQL Server\' + @system_instance_name + '\MSSQLServer\Parameters' ;
      IF @registry_key IS NULL
         BEGIN
            SET @instance_name = coalesce(CONVERT(nvarchar(100), serverproperty('InstanceName')), 'MSSQLSERVER') ;
         END
      EXEC master.dbo.xp_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\Microsoft SQL Server\Instance Names\SQL', @instance_name, @system_instance_name OUTPUT ;

      SET @registry_key = N'Software\Microsoft\Microsoft SQL Server\' + @system_instance_name + '\MSSQLServer\Parameters' ;
      SET @registry_key1 = N'Software\Microsoft\Microsoft SQL Server\' + @system_instance_name + '\MSSQLServer\supersocketnetlib\TCP\IP1' ;
      SET @registry_key2 = N'SYSTEM\ControlSet001\Services\Tcpip\Parameters\' ;
      EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @key, @value_name = 'ImagePath', @value = @image_path OUTPUT
      EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @key, @value_name = 'Start', @value = @startup_type OUTPUT
      EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @key, @value_name = 'ObjectName', @value = @start_username OUTPUT
      EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @registry_key, @value_name = 'SQLArg1', @value = @log_directory OUTPUT
      EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @registry_key1, @value_name = 'IpAddress', @value = @IpAddress OUTPUT
      EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @registry_key2, @value_name = 'Domain', @value = @domain OUTPUT

      SET @startuptype = (SELECT  'Start Up Mode' = CASE WHEN @startup_type = 2 THEN 'AUTOMATIC'
                                                         WHEN @startup_type = 3 THEN 'MANUAL'
                                                         WHEN @startup_type = 4 THEN 'Disabled'
                                                    END)                        
                        
--Step 4: Getting the cluster node names if the server is on cluster .else this value will be NULL.

      DECLARE @Out nvarchar(400)
      SELECT  @Out = COALESCE(@Out + '', '') + Nodename
      FROM    sys.dm_os_cluster_nodes                        
                        
-- Step 5: printing Server details 

      SELECT  @domain AS 'Domain', serverproperty('ComputerNamePhysicalNetBIOS') AS 'MachineName', CPU_COUNT AS 'CPUCount', (physical_memory_in_bytes / 1048576) AS 'PhysicalMemoryMB', @Ipaddress AS 'IP_Address', @instance_name1 AS 'InstanceName', @image_path AS 'BinariesPath', @log_directory AS 'ErrorLogsLocation', @start_username AS 'StartupUser', @Startuptype AS 'StartupType', serverproperty('Productlevel') AS 'ServicePack', serverproperty('edition') AS 'Edition', serverproperty('productversion') AS 'Version', serverproperty('collation') AS 'Collation', serverproperty('Isclustered') AS 'ISClustered', @out AS 'ClusterNodes', serverproperty('IsFullTextInstalled') AS 'ISFullText'
      FROM    sys.dm_os_sys_info                         
                      

-- Step 6: Printing database details 

      SELECT  serverproperty('ComputerNamePhysicalNetBIOS') AS 'Machine', @instance_name1 AS InstanceName, (SELECT  'file_type' = CASE WHEN s.groupid <> 0 THEN 'data'
                                                                                                                                       WHEN s.groupid = 0 THEN 'log'
                                                                                                                                  END) AS 'fileType', d.dbid AS 'DBID', d.name AS 'DBName', s.name AS 'LogicalFileName', s.filename AS 'PhysicalFileName', (s.size * 8 / 1024) AS 'FileSizeMB' -- file size in MB                      
              , d.cmptlevel AS 'CompatibilityLevel', DATABASEPROPERTYEX(d.name, 'Recovery') AS 'RecoveryModel', DATABASEPROPERTYEX(d.name, 'Status') AS 'DatabaseStatus',                     
              --, d.is_published as 'Publisher'                      
              --, d.is_subscribed as 'Subscriber'                      
              --, d.is_distributor as 'Distributor' 
              (SELECT  'is_replication' = CASE WHEN d.category = 1 THEN 'Published'
                                               WHEN d.category = 2 THEN 'subscribed'
                                               WHEN d.category = 4 THEN 'Merge published'
                                               WHEN d.category = 8 THEN 'merge subscribed'
                                               ELSE 'NO replication'
                                          END) AS 'Is_replication', m.mirroring_state AS 'MirroringState'                      
			--INTO master.[dbo].[databasedetails]                      
      FROM    sys.sysdatabases d
              INNER JOIN sys.sysaltfiles s
                 ON d.dbid = s.dbid
              INNER JOIN sys.database_mirroring m
                 ON d.dbid = m.database_id
      ORDER BY d.name                      
          
          
          


--Step 7 :printing Backup details                       

      SELECT DISTINCT b.machine_name AS 'ServerName', b.server_name AS 'InstanceName', b.database_name AS 'DatabaseName', d.database_id 'DBID', CASE b.[type]
                                                                                                                                                  WHEN 'D' THEN 'Full'
                                                                                                                                                  WHEN 'I' THEN 'Differential'
                                                                                                                                                  WHEN 'L' THEN 'Transaction Log'
                                                                                                                                                END AS 'BackupType'                                 
			--INTO [dbo].[backupdetails]                        
      FROM            sys.databases d
                      INNER JOIN msdb.dbo.backupset b
                         ON b.database_name = d.name


   END
ELSE

   BEGIN



--Step 8: If the instance is 2000 this code will be used.

      DECLARE @registry_key4 nvarchar(100)
      DECLARE @Host_Name varchar(100)
      DECLARE @CPU varchar(3)
      DECLARE @nodes nvarchar(400)
      SET @nodes = NULL /* We are not able to trap the node names for SQL Server 2000 so far*/
      DECLARE @mirroring varchar(15)
      SET @mirroring = 'NOT APPLICABLE' /*Mirroring does not exist in SQL Server 2000*/
      DECLARE @reg_node1 varchar(100)
      DECLARE @reg_node2 varchar(100)
      DECLARE @reg_node3 varchar(100)
      DECLARE @reg_node4 varchar(100)

      SET @reg_node1 = N'Cluster\Nodes\1'
      SET @reg_node2 = N'Cluster\Nodes\2'
      SET @reg_node3 = N'Cluster\Nodes\3'
      SET @reg_node4 = N'Cluster\Nodes\4'

      DECLARE @image_path1 varchar(100)
      DECLARE @image_path2 varchar(100)
      DECLARE @image_path3 varchar(100)
      DECLARE @image_path4 varchar(100)

      SET @image_path1 = NULL
      SET @image_path2 = NULL
      SET @image_path3 = NULL
      SET @image_path4 = NULL
      EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @reg_node1, @value_name = 'NodeName', @value = @image_path1 OUTPUT
      EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @reg_node2, @value_name = 'NodeName', @value = @image_path2 OUTPUT
      EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @reg_node3, @value_name = 'NodeName', @value = @image_path3 OUTPUT
      EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @reg_node4, @value_name = 'NodeName', @value = @image_path4 OUTPUT

      IF EXISTS (SELECT  *
                 FROM    dbo.sysobjects
                 WHERE   id = OBJECT_ID(N'nodes')
                         AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
         BEGIN
            DROP TABLE nodes
         END
      CREATE TABLE nodes (name varchar(20))
      INSERT  INTO nodes
      VALUES  (@image_path1)
      INSERT  INTO nodes
      VALUES  (@image_path2)
      INSERT  INTO nodes
      VALUES  (@image_path3)
      INSERT  INTO nodes
      VALUES  (@image_path4)
		  --declare @Out nvarchar(400)                        
		  --declare @value nvarchar (20)
      SELECT  @Out = COALESCE(@Out + '/', '') + name
      FROM    nodes
      WHERE   name IS NOT NULL
	  	  
-- Step 9: Reading registry keys for Number of CPUs,Binaries,Startup type ,startup username, errorlogs location and domain.

      SET @instance_name = coalesce(CONVERT(nvarchar(100), serverproperty('InstanceName')), 'MSSQLSERVER') ;
      IF @instance_name != 'MSSQLSERVER'

         BEGIN
            SET @system_instance_name = @instance_name
            SET @instance_name = 'MSSQL$' + @instance_name

            SET @key = N'SYSTEM\CurrentControlSet\Services\' + @instance_name ;
            SET @registry_key = N'Software\Microsoft\Microsoft SQL Server\' + @system_instance_name + '\MSSQLServer\Parameters' ;
            SET @registry_key1 = N'Software\Microsoft\Microsoft SQL Server\' + @system_instance_name + '\Setup' ;
            SET @registry_key2 = N'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\' ;
            SET @registry_key4 = N'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
            EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @registry_key1, @value_name = 'SQLPath', @value = @image_path OUTPUT
            EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @key, @value_name = 'Start', @value = @startup_type OUTPUT
            EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @key, @value_name = 'ObjectName', @value = @start_username OUTPUT
            EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @registry_key, @value_name = 'SQLArg1', @value = @log_directory OUTPUT
            EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @registry_key2, @value_name = 'Domain', @value = @domain OUTPUT
            EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @registry_key4, @value_name = 'NUMBER_OF_PROCESSORS', @value = @CPU OUTPUT


         END

      IF @instance_name = 'MSSQLSERVER'
         BEGIN
            SET @key = N'SYSTEM\CurrentControlSet\Services\' + @instance_name ;
            SET @registry_key = N'Software\Microsoft\MSSQLSERVER\MSSQLServer\Parameters' ;
            SET @registry_key1 = N'Software\Microsoft\MSSQLSERVER\Setup' ;
            SET @registry_key2 = N'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\' ;
            SET @registry_key4 = N'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
            EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @registry_key1, @value_name = 'SQLPath', @value = @image_path OUTPUT
            EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @key, @value_name = 'Start', @value = @startup_type OUTPUT
            EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @key, @value_name = 'ObjectName', @value = @start_username OUTPUT
            EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @registry_key, @value_name = 'SQLArg1', @value = @log_directory OUTPUT
			--EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE',@registry_key1,@value_name='IpAddress',@value=@IpAddress OUTPUT
            EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @registry_key2, @value_name = 'Domain', @value = @domain OUTPUT
            EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE', @registry_key4, @value_name = 'NUMBER_OF_PROCESSORS', @value = @CPU OUTPUT

         END
      SET @startuptype = (SELECT  'Start Up Mode' = CASE WHEN @startup_type = 2 THEN 'AUTOMATIC'
                                                         WHEN @startup_type = 3 THEN 'MANUAL'
                                                         WHEN @startup_type = 4 THEN 'Disabled'
                                                    END)

--Step 10 : Using ipconfig and xp_msver to get physical memory and IP

      IF EXISTS (SELECT  *
                 FROM    dbo.sysobjects
                 WHERE   id = OBJECT_ID(N'tmp')
                         AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
         BEGIN
            DROP TABLE tmp
         END
      CREATE TABLE tmp (server varchar(100) DEFAULT CAST(serverproperty('Machinename') AS varchar),
                        [index] int,
                        name sysname,
                        internal_value int,
                        character_value varchar(30))
      INSERT  INTO tmp ([index], name, internal_value, character_value)
              EXEC xp_msver PhysicalMemory

      IF EXISTS (SELECT  *
                 FROM    dbo.sysobjects
                 WHERE   id = OBJECT_ID(N'ipadd')
                         AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
         BEGIN
            DROP TABLE ipadd
         END
      CREATE TABLE ipadd (server varchar(100) DEFAULT CAST(serverproperty('Machinename') AS varchar),
                          IP varchar(100))
      INSERT  INTO ipadd (IP)
              EXEC xp_cmdshell 'ipconfig'
      DELETE  FROM ipadd
      WHERE   ip NOT LIKE '%IP Address.%'
              OR IP IS NULL


-- Step 11 : Getting the Server details 

      SELECT TOP 1 @domain AS 'Domain', serverproperty('Machinename') AS 'MachineName', @CPU AS 'CPUCount', CAST(t.internal_value AS bigint) AS PhysicalMemoryMB, CAST(substring(I.IP, 44, 41) AS nvarchar(20)) AS IP_Address, serverproperty('Instancename') AS 'InstanceName', @image_path AS 'BinariesPath', @log_directory AS 'ErrorLogsLocation', @start_username AS 'StartupUser', @Startuptype AS 'StartupType', serverproperty('Productlevel') AS 'ServicePack', serverproperty('edition') AS 'Edition', serverproperty('productversion') AS 'Version', serverproperty('collation') AS 'Collation', serverproperty('Isclustered') AS 'ISClustered', @Out AS 'ClustreNodes', serverproperty('IsFullTextInstalled') AS 'ISFullText'
      FROM         tmp t
                   INNER JOIN IPAdd I
                      ON t.server = I.server

-- Step 12 : Getting the instance details 

      SELECT  serverproperty('Machinename') AS 'Machine', serverproperty('Instancename') AS 'InstanceName', (SELECT  'file_type' = CASE WHEN s.groupid <> 0 THEN 'data'
                                                                                                                                        WHEN s.groupid = 0 THEN 'log'
                                                                                                                                   END) AS 'fileType', d.dbid AS 'DBID', d.name AS 'DBName', s.name AS 'LogicalFileName', s.filename AS 'PhysicalFileName', (s.size * 8 / 1024) AS 'FileSizeMB' -- file size in MB                      
              , d.cmptlevel AS 'CompatibilityLevel', DATABASEPROPERTYEX(d.name, 'Recovery') AS 'RecoveryModel', DATABASEPROPERTYEX(d.name, 'Status') AS 'DatabaseStatus', (SELECT  'is_replication' = CASE WHEN d.category = 1 THEN 'Published'
                                                                                                                                                                                                           WHEN d.category = 2 THEN 'subscribed'
                                                                                                                                                                                                           WHEN d.category = 4 THEN 'Merge published'
                                                                                                                                                                                                           WHEN d.category = 8 THEN 'merge subscribed'
                                                                                                                                                                                                           ELSE 'NO replication'
                                                                                                                                                                                                      END) AS 'Is_replication', @Mirroring AS 'MirroringState'
      FROM    sysdatabases d
              INNER JOIN sysaltfiles s
                 ON d.dbid = s.dbid
      ORDER BY d.name                      

-- Step 13 : Getting backup details 

      SELECT DISTINCT b.machine_name AS 'ServerName', b.server_name AS 'InstanceName', b.database_name AS 'DatabaseName', d.dbid 'DBID', CASE b.[type]
                                                                                                                                           WHEN 'D' THEN 'Full'
                                                                                                                                           WHEN 'I' THEN 'Differential'
                                                                                                                                           WHEN 'L' THEN 'Transaction Log'
                                                                                                                                         END AS 'BackupType'
      FROM            sysdatabases d
                      INNER JOIN msdb.dbo.backupset b
                         ON b.database_name = d.name   


-- Step 14: Dropping the table we created for IP and Physical memory

      DROP TABLE TMP
      DROP TABLE IPADD
      DROP TABLE Nodes

   END
GO

-- Step 15 : Setting Nulls and Quoted identifier back to Off 

SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO 