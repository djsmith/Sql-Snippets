/*
Unmatched Logins
Depending on how a database is backed up and restored a database can have 
invalid logins, which can affect the dbo user in a database and the sa server 
account. This can prevent changing the account password using enterprise manager
http://support.microsoft.com/default.aspx?scid=kb;en-us;305711
http://support.microsoft.com/default.aspx?scid=kb;en-us;296437
http://support.microsoft.com/default.aspx?scid=kb;en-us;274188
http://support.microsoft.com/default.aspx?scid=kb;en-us;240872

*/

-- Gets information about a database and the logins
USE djstest
go
sp_helpdb 'djstest'
go
sp_helpuser
go

-- Finds all database login names with unmatched server logins
Use &lt;database name&gt;
GO
SELECT u.name AS "Name"
FROM sysusers u
     LEFT JOIN master.dbo.syslogins l ON u.sid = l.sid
Where u.islogin = 1 and l.name is null
GO


-- Finds all database login names with unmatched server logins
sp_change_users_login 'report'

-- Changes the user login in a database
use &lt;database name&gt;
sp_change_users_login 'update_one', 'test', 'test'

-- Removes a login name from a database
use &lt;database name&gt;
sp_revokedbaccess '&lt;db user name&gt;'

-- Changes the owner of the database
use &lt;database name&gt;
sp_changedbowner @loginame = '&lt;existing server user account&gt;'

-- Removes null login names from the database
declare @UserNamesCr Cursor
declare @UserNameVch varchar(100)
declare @RevokeResultBt bit
declare @ResultLogVch varchar(8000)

Set @ResultLogVch = 'Removing Un-matched User Accounts' + CHAR(13) + CHAR(10)

set @UserNamesCr = Cursor For 
    Select u.name AS "Name"
    From sysusers u
        Left Join master.dbo.syslogins l On u.sid = l.sid
    Where u.islogin = 1 and l.name Is Null and u.name &lt;&gt; 'dbo'

Open @UserNamesCr

Fetch Next From @UserNamesCr Into @UserNameVch

While (@@FETCH_STATUS = 0) 
Begin
    Exec @RevokeResultBt = sp_revokedbaccess @UserNameVch
    --set @RevokeResultBt = 1
    If (@RevokeResultBt = 1)
        Set @ResultLogVch = @ResultLogVch + 'User Account "' + @UserNameVch + '" removed.' + CHAR(13) + CHAR(10)
    Else
        Set @ResultLogVch = @ResultLogVch + 'User Account "' + @UserNameVch + '" not removed.' + CHAR(13) + CHAR(10)

    Fetch Next From @UserNamesCr Into @UserNameVch
End

Print @ResultLogVch

 