USE master
GO

if exists (select * FROM dbo.sysobjects where id = object_id(N'[dbo].[sp_ScriptRoles]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_ScriptRoles]
GO

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

/* 
Build statements to replicate authorities for Database Roles.

This routine needs to be named 'sp_' so it can be hosted in master database 
and be able to script roles in any database.

Example: 
	[sp_ScriptRoles] 'AppUsers'
	
Note: For best results output the query to Text instead of a data grid

By Ed Vassie; 2/20/2008
http://www.sqlservercentral.com/scripts/SQL+2000/61878/
http://www.codeplex.com/SQLServerFineBuild
*/
CREATE PROC [dbo].[sp_ScriptRoles]
@Role varchar(255) = '%'
AS BEGIN

SET NOCOUNT ON

-- Display Audit information
PRINT '-- Generated on ' + Convert(char(20), Getdate(), 113) + ' by ' + SYSTEM_USER + ' on ' + @@servername 
PRINT '-- Setup users, roles and privileges. sp_ScriptRoles v1.1'

-- Switch to current database
PRINT 'USE ' + db_name() 
PRINT 'GO' 

-- Add Users to Database
SELECT 
 'EXEC sp_grantdbaccess ''' + RTrim(l.name) + '''' as '-- Add Database Users'
FROM dbo.sysusers u
INNER JOIN master.dbo.syslogins l
 ON u.sid = l.sid
WHERE u.islogin = 1
 AND u.hasdbaccess = 1
 AND u.name NOT IN ('dbo','guest')
 AND u.name NOT LIKE '##%'
ORDER BY u.name 

-- Create Database Roles
SELECT 
 'EXEC sp_addrole ''' + RTrim(r.name) + ''',dbo ' as '-- Create Roles'
FROM dbo.sysusers r
WHERE r.issqlrole = 1 
 AND r.gid > 0
 AND r.name NOT IN ('RepositoryUser', 'TargetServersRole')
 AND r.name LIKE @Role
ORDER BY r.name

-- Add Users to roles
SELECT
 'EXEC sp_addrolemember ''' + RTrim(r.name) + ''',''' + RTrim(Coalesce(l.name,u.name)) + '''' as '-- Add Role Users'
FROM dbo.sysusers u
INNER JOIN sysmembers m
 ON u.uid = m.memberuid
INNER JOIN sysusers r
 ON m.groupuid = r.uid
LEFT OUTER JOIN master.dbo.syslogins l
 ON u.sid = l.sid
WHERE r.issqlrole = 1
 AND u.name <> 'dbo'
 AND r.name LIKE '%'
ORDER BY r.name,u.name

-- Add Privileges to Roles
select -- Object privileges 
 CASE 
 WHEN (p.protecttype = 204) OR (p.protecttype = 205) THEN 
 CASE
 WHEN p.action = 26 THEN
 'GRANT REFERENCES ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' TO ' + RTRIM(u.name)
 WHEN p.action = 193 THEN
 'GRANT SELECT ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' TO ' + RTRIM(u.name)
 WHEN p.action = 195 THEN
 'GRANT INSERT ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' TO ' + RTRIM(u.name)
 WHEN p.action = 196 THEN
 'GRANT DELETE ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' TO ' + RTRIM(u.name)
 WHEN p.action = 197 THEN
 'GRANT UPDATE ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' TO ' + RTRIM(u.name)
 WHEN p.action = 224 THEN
 'GRANT EXECUTE ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' TO ' + RTRIM(u.name)
 END +
 CASE 
 WHEN p.protecttype = 204 THEN 
 ' WITH GRANT OPTION'
 ELSE ''
 END
 WHEN p.protecttype = 206 THEN
 CASE
 WHEN p.action = 26 THEN
 'DENY REFERENCES ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' TO ' + RTRIM(u.name)
 WHEN p.action = 193 THEN
 'DENY SELECT ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' TO ' + RTRIM(u.name)
 WHEN p.action = 195 THEN
 'DENY INSERT ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' TO ' + RTRIM(u.name)
 WHEN p.action = 196 THEN
 'DENY DELETE ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' TO ' + RTRIM(u.name)
 WHEN p.action = 197 THEN
 'DENY UPDATE ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' TO ' + RTRIM(u.name)
 WHEN p.action = 224 THEN
 'GRANT EXECUTE ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' TO ' + RTRIM(u.name)
 END 
 END as '-- Setup Object privileges'
FROM dbo.sysobjects o
INNER JOIN sysusers s
 ON o.uid = s.uid 
INNER JOIN sysprotects p
 ON o.id = p.id
INNER JOIN sysusers u
 ON p.uid = u.uid 
WHERE u.issqlrole = 1 -- Include Roles only
 AND u.gid > 0 -- Exclude System Roles
 AND u.name NOT IN ('RepositoryUser', 'TargetServersRole') -- Exclude Pseudo-system roles
 AND u.name LIKE @Role
 AND NOT (o.xtype = 'V' and o.category = 2) -- Exclude INFORMATION schema views
 AND Coalesce(p.columns, 1) = 1 -- Exclude column-level privileges
ORDER BY u.name,s.name,o.name,p.action

SELECT -- Column privileges 
 CASE 
 WHEN (p.protecttype = 204) OR (p.protecttype = 205) THEN 
 CASE
 WHEN p.action = 26 THEN
 'GRANT REFERENCES ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' (' + RTRIM(c.name) + ') TO ' + RTRIM(u.name)
 WHEN p.action = 193 THEN
 'GRANT SELECT ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' (' + RTRIM(c.name) + ') TO ' + RTRIM(u.name)
 WHEN p.action = 195 THEN
 'GRANT INSERT ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' (' + RTRIM(c.name) + ') TO ' + RTRIM(u.name)
 WHEN p.action = 196 THEN
 'GRANT DELETE ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' (' + RTRIM(c.name) + ') TO ' + RTRIM(u.name)
 WHEN p.action = 197 THEN
 'GRANT UPDATE ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' (' + RTRIM(c.name) + ') TO ' + RTRIM(u.name)
 END +
 CASE 
 WHEN p.protecttype = 204 THEN 
 ' WITH GRANT OPTION'
 ELSE ''
 END
 WHEN p.protecttype = 206 THEN
 CASE
 WHEN p.action = 26 THEN
 'DENY REFERENCES ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' (' + RTRIM(c.name) + ') TO ' + RTRIM(u.name)
 WHEN p.action = 193 THEN
 'DENY SELECT ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' (' + RTRIM(c.name) + ') TO ' + RTRIM(u.name)
 WHEN p.action = 195 THEN
 'DENY INSERT ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' (' + RTRIM(c.name) + ') TO ' + RTRIM(u.name)
 WHEN p.action = 196 THEN
 'DENY DELETE ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' (' + RTRIM(c.name) + ') TO ' + RTRIM(u.name)
 WHEN p.action = 197 THEN
 'DENY UPDATE ON ' + RTRIM(s.name) + '.' + RTRIM(o.name) + ' (' + RTRIM(c.name) + ') TO ' + RTRIM(u.name)
 END 
 END as '-- Setup Column privileges'
FROM dbo.sysobjects o
INNER JOIN sysusers s
 ON o.uid = s.uid 
INNER JOIN sysprotects p
 ON o.id = p.id
INNER JOIN sysusers u
 ON p.uid = u.uid 
INNER JOIN syscolumns c
 ON c.id = o.id
AND c.id = p.id
INNER JOIN master.dbo.spt_values v
 ON v.number = c.colid
WHERE u.issqlrole = 1 -- Include Roles only
 AND u.gid > 0 -- Exclude System Roles
 AND u.name NOT IN ('RepositoryUser', 'TargetServersRole') -- Exclude Pseudo-system roles
 AND u.name LIKE @Role --and c.name = 'InstrumentID' 
 AND NOT (o.xtype = 'V' and o.category = 2) -- Exclude INFORMATION schema views
 AND p.columns <> 1 -- Include only column-level privileges
 AND CASE Substring(p.columns, 1, 1) & 1 -- Identify column for permission
WHEN 0 then Convert(tinyint, Substring(p.columns, v.low, 1))
ELSE (~Convert(tinyint, Coalesce(Substring(p.columns, v.low, 1),0)))
END & v.high <> 0
 AND v.type = N'P'
ORDER BY u.name,s.name,o.name,p.action

PRINT '-- End of script'

END

GO
 