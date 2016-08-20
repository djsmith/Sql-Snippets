/*
Get Stored Procedure Parameters
It can be useful to have a class that automatically manages and caches the stored procedure parameters used by the application. This stored procedure will return the parameters for all of the stored procedures in a database.
This could be modified to get the parameters for only a single stored procedure with an addition al where clause.
*/
SELECT objs.name SpName, cols.name Pname, cols.prec, cols.scale,
	cols.isnullable, cols.isoutparam, cols.length, cols.xtype 
FROM sysobjects objs 
JOIN syscolumns cols ON objs.id = cols.id
WHERE objs.type = 'P'  
--AND objs.name = 'EmployeeInfoSelect'
ORDER BY SpName 
