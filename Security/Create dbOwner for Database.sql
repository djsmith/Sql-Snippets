/* This script creates a DB Owner login and user for a given database, 
 * using a random password.
 */ 

declare @dbName sysname set @dbName = DB_NAME()

/* validate dbName, confirm db already exists, and don't run on system database */
if (@dbName is null or Len(@dbName) < 1) begin
	raiserror (N'The dbName parameter cannot be null or blank.', 10, 1)
	goto theEnd
end

if (DB_ID(@dbName) is null) begin
	raiserror (N'DB [%s] does not exist.', 10, 1, @dbName)
	goto theEnd
end

if (DB_ID(@dbName) < 5) begin
	raiserror (N'Do not run this using a system database [%s].', 10, 1, @dbName)
	goto theEnd
end

/* Generate user name for DB Owner */
declare @dbOwner sysname set @dbOwner = @dbName + '_dbOwner'

/* Check if login already exists */
if exists (SELECT name FROM master.sys.server_principals WHERE name = @dbOwner) begin
	raiserror (N'Login [%s] already exists.', 10, 1, @dbOwner)
	goto theEnd
end

/* generate random password */
declare @chars varchar(100) set @chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
declare @password sysname set @password = (select top 16 substring(@chars, 1 + Number, 1) as [text()]
	from master..spt_values
	where number < datalength(@chars)
	  and type = 'P'
	order by newid()
	for xml path(''))

/* create user with password */
declare @sqlCommand nvarchar(2000)
set @sqlCommand = REPLACE(REPLACE(REPLACE(N'USE [master]
CREATE LOGIN [__dbName__dbOwner] WITH PASSWORD=N'''', DEFAULT_DATABASE=[__dbName], CHECK_EXPIRATION=OFF, CHECK_POLICY=ON',
'WITH PASSWORD=N''''', 'WITH PASSWORD=N''' + @password + ''''), N'__dbName__dbOwner', @dbOwner), N'__dbName', @dbName)

/* give user owner rights on database */
set @sqlCommand = @sqlCommand + REPLACE(REPLACE(N'
USE [__dbName]
CREATE USER [__dbName__dbOwner] FOR LOGIN [__dbName__dbOwner]
ALTER USER [__dbName__dbOwner] WITH DEFAULT_SCHEMA=[dbo]
ALTER ROLE [db_owner] ADD MEMBER [__dbName__dbOwner]',
N'__dbName__dbOwner', @dbOwner), N'__dbName', @dbName)

--print @sqlCommand
exec sp_executesql @sqlCommand

print FormatMessage(CHAR(10) + 'Created user [%s_dbOwner] with owner rights on database [%s]. Password: %s', @dbName, @dbName, @password)

theEnd: