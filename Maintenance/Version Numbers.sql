/* Various ways to get version numbers out of a server */

SELECT 
	@@VERSION AS [VersionString], 
	@@MICROSOFTVERSION AS [VersionNumber], 
	@@MICROSOFTVERSION / POWER(2, 24) AS [VersionMajor], 
	@@MICROSOFTVERSION & 0xffff AS [VersionBuild],
	SERVERPROPERTY('Edition') AS [Edition],
	SERVERPROPERTY('EngineEdition') AS [EngineNumber],
	CASE SERVERPROPERTY('EngineEdition') 
		WHEN 1 THEN 'Personal or Desktop Engine'
		WHEN 2 THEN 'Standard'
		WHEN 3 THEN 'Enterprise'
		WHEN 4 THEN 'Express'
		END AS [Engine],
	SERVERPROPERTY('ProductVersion ') AS [VERSION],
	SERVERPROPERTY('ProductLevel') AS [LEVEL]
 