--This script will create a procedure that will drop an existing 
-- database user and then drop the server login
--Example: 
-- exec sp_dropuserlogin 'UserXYZ'
--Note; this script only works if the database user name is the same as the server login name
-- A better system would go thru all databases looking to for the database user by the login's SID
-- and then drop the login

use master
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[sp_dropuserlogin]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[sp_dropuserlogin]
GO

create proc sp_dropuserlogin 
	@username varchar(50)
as
begin
	declare @command varchar(2000)
	set @command = 'use [?] exec sp_revokedbaccess '''+@username+''' '
 	print @command
	exec sp_msforeachdb @command
	exec sp_droplogin @username
end
go
 