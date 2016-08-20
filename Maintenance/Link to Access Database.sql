/*
Link to Access Database
These commands will link an Access database to a SQL Server, after which the 
SQL Server can manipulate the database tables.
*/

sp_addlinkedserver 
    'Perfect', 
    'Access 97', 
    'Microsoft.Jet.OLEDB.4.0', 
    'D:\Program Files\PRM96\Database\Perfect.mdb'
go
sp_addlinkedsrvlogin 'Perfect', false, 'sa', 'Admin', NULL
go
select * from Perfect...employee_main where emp_fname like 'jam%'
go
select * from Perfect...ct_reason
go
sp_droplinkedsrvlogin 'Perfect', 'sa'
go
sp_dropserver 'Perfect'
go
 