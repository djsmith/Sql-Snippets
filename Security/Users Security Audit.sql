 --Use the master database
USE master
go

/**************************************************************************** 
   Creation Date: 04/28/02    Created By: Randy Dyess
                              Web Site: www.TransactSQL.Com
                              Email: RandyDyess@TransactSQL.Com
   Purpose: Loops through all databases and obtains members for database roles
            as well as server role members
   Location: master database
   Output Parameters: None
   Return Status: None
   Called By: None
   Calls: None
   Data Modifications: None
   Updates: 
   2/15/2008, Dan Smith; Removed code that made this a stored procedure and 
   left it as a script
****************************************************************************/ 
SET NOCOUNT ON

--Variables
DECLARE @Counter INTEGER
DECLARE @DBName VARCHAR(50)
DECLARE @SQL NVARCHAR(4000)

--Temp table to hold database and user-defiine role user names
CREATE TABLE #RoleMembers (
    ServerName VARCHAR(50) DEFAULT @@SERVERNAME,
    DBName VARCHAR(50),
    RoleName VARCHAR(50),
    UserName VARCHAR(50),
    UserID VARCHAR(100)
   )

--Temp table to hold database names
CREATE TABLE #DbNames (
    ID INTEGER IDENTITY(1, 1),
    DBName VARCHAR(50)
   )

--Obtain members of each server role
INSERT   INTO #RoleMembers (RoleName, UserName, UserID)
         EXEC dbo.sp_helpsrvrolemember

--Obtain database names
INSERT   INTO #DbNames (DBName)
         SELECT   name
         FROM     master.dbo.sysdatabases
SET @Counter = @@ROWCOUNT

--Loop through databases to obtain members  of database roles and user-defined roles
WHILE @Counter > 0
   BEGIN

	--Get database name from temp table
      SET @DBName = (SELECT   DBName
                     FROM     #DbNames
                     WHERE    ID = @Counter)

	--Obtain members of each database and user-defined role
      SET @SQL = 'INSERT INTO #RoleMembers (RoleName, UserName, UserID)
		EXEC [' + @DBName + '].dbo.sp_helprolemember'

      EXEC sp_executesql @SQL

	--Update database name in temp table
      UPDATE   #RoleMembers
      SET      DBName = @DBName
      WHERE    DBName IS NULL

      SET @Counter = @Counter - 1

   END

--'Display by User'
select   UserName as [By User: User], DBName as [Database], RoleName as [Role],
         ServerName as [Server]
from     #RoleMembers
where    UserName <> 'dbo'
order by UserName

--'Display by Role'
select   RoleName as [By Role: Role], DBName as [Database], UserName as [User],
         ServerName as [Server]
from     #RoleMembers
where    UserName <> 'dbo'
order by RoleName

--'Display by Database'
select   DBName as [Database], RoleName as [Role], UserName as [User],
         ServerName as [Server]
from     #RoleMembers
where    UserName <> 'dbo'
order by DBName

--Show any accounts who have a server role
exec sp_helpsrvrolemember

drop table [#RoleMembers]
drop table [#DbNames]
