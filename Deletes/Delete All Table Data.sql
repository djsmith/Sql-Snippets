/*
This script deletes all data from all tables.
WARNING; THIS CAN TOTALLY FUBAR YOUR DATA!!!

This script is from the article 'The Safe and Easy Way to 
Delete All Data in a SQL Server DB' by Susan Sales Harkins.
http://www.devx.com/dbzone/Article/40967

The scirpt makes use of the sp_MSForEachTable undocumented
stored procedure to disable any constraints and triggers
on the tables before deleting the data.

For more information on sp_MSForEachTable;
http://www.databasejournal.com/features/mssql/article.php/3441031/SQL-Server-Undocumented-Stored-Procedures-spMSforeachtable-and-spMSforeachdb.htm

*/

-- Comment this next line to actually run the sql commands
GOTO ThisIsTheEndMyOnlyFriendTheEnd

PRINT 'Altering tables, disabling constraints and triggers'
EXEC sp_MSForEachTable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL'
EXEC sp_MSForEachTable 'ALTER TABLE ? DISABLE TRIGGER ALL'
PRINT 'Delete data from each table'
EXEC sp_MSForEachTable 'DELETE FROM ?'
PRINT 'Altering tables, re-enabling constraings and triggers'
EXEC sp_MSForEachTable 'ALTER TABLE ? CHECK CONSTRAINT ALL'
EXEC sp_MSForEachTable 'ALTER TABLE ? ENABLE TRIGGER ALL'
PRINT 'Check if any data remains in tables'
EXEC sp_MSForEachTable 'IF EXISTS(SELECT * FROM ?) BEGIN PRINT ''  ** ? table IS NOT EMPTY'' END ELSE BEGIN PRINT ''  - ? table is empty'' END'

ThisIsTheEndMyOnlyFriendTheEnd:
