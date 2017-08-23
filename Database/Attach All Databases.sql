/*
 * Creates T-SQL code that attaches all non-system databases to the 
 * server. This script doens't actually attach the database, but instead 
 * creates T-SQL code that attaches the databases.
 * 
 * Best to output the query resutls to text or to a file instead of a table 
 * so it formats the commands properly.
 * 
 * Run this script before detaching any databases otherwise it will not be
 * able to create this script. It needs to know the database file names while
 * the databases are still attached.
 *
 * Dan Smith: 2017-08-23
 */

 -- Don't need the row count at the end of the script.
 set nocount on
 go

select --db.[name] as [Name], df.physical_name as [DataFile], lf.physical_name as [LogFile], replace(lf.physical_name, '\Data\', '\Log\') as [NewLogFile],
replace(
replace(
replace(N'
CREATE DATABASE [$0] ON 
( FILENAME = N''$1'' ),
( FILENAME = N''$2'' )
 FOR ATTACH
GO
', '$0', db.[Name]),
'$1', df.physical_name),
'$2', lf.physical_name)
from sys.databases as db
inner join sys.master_files df
	on df.database_id = db.database_id and df.[type] = 0
inner join sys.master_files lf
	on lf.database_id = db.database_id and lf.[type] = 1
where db.[name] not in ('master','model','msdb','tempdb')
order by db.[name]
