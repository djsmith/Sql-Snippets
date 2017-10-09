set ansi_nulls on
go
set quoted_identifier on
go

-- Create this proc in the master so it can be used anywhere
use master
go

if exists (select * from sys.objects where type = 'P' and name = 'sp_CreateDbOwner')
	drop procedure sp_CreateDbOwner
go

create procedure sp_CreateDbOwner 
	@dbNames varchar(max) = null
as
begin
/* ==================================================================
 * Author:		Dan Smith
 * Create date: 2017-08-24
 * Description:	Create db owner login for a given database.
 * 
 * Parameters:
 * @dbNames The @dbNames parameter can be a single database, a 
 *          comma separated list of databases, or 'all' to run
 *          on all user databases. If null, then use the current 
 *          database.
 * 
 * Examples:
 * exec sp_CreateDbOwner 'MyDb, YourDb, TheirDb' -- runs on these three databases
 * exec sp_CreateDbOwner 'MyDb' -- runs on a single database
 * exec sp_CreateDbOwner 'all' -- runs on all user databases
 * exec sp_CreateDbOwner -- runs on the current database
 *
 * Errors:
 * if @dbNames includes a non-existant database.
 * if @dbNames includes a system database (master, model, msdb, tempdb).
 * if a login matching dbName_dbOwner already exists.
 * 
 * ================================================================*/

	/* set nocount on added to prevent extra result sets from
	   interfering with SELECT statements. */
	set nocount on;

	/* If @dbNames is null, get name of current database */
	if (@dbNames is NULL) begin
		set @dbNames = DB_NAME()
	end

    --print @dbNames

	/* Split list of dbNames into array, clean brackets and extra spaces from the list */
	declare @Delimiter char(1) set @Delimiter = ','
	declare @List xml

	select @List = CONVERT(xml,' <root> <s>' +
	REPLACE(REPLACE(REPLACE(@dbNames, '[', ''), ']', ''),@Delimiter, '</s> <s>') + '</s>   </root> ')

	set rowcount 0

	/* Create temp table of dbNames from input:
	 *  - If @dbNames = 'all' then get list of all user databases from sys.databases,
	 *    otherwise, split dbNames into list by commas.
	 */
	select [dbName] = [name]
	into #dbNamesTemp
	from (
		select [name] from sys.databases
		where [name] not in ('master', 'model', 'msdb', 'tempdb')
			and LOWER(@dbNames) = 'all'
		union all
		select [name] = LTRIM(RTRIM(T.c.value('.','nvarchar(255)')))
		from @List.nodes('/root/s') T(c)
		where LOWER(@dbNames) != 'all'
	) as db
	
	--select *, LEN([dbName]) as length from #dbNamesTemp

	/* Loop through array to create new account for each */
	set rowcount 1

	/* Get first dbName from temp table */
	declare @dbName as sysname
	select @dbName = [dbName] from #dbNamesTemp

	/* Continue loop until table is empty */
	while @@rowcount <> 0
	begin
		set rowcount 0
		--select @dbName, DB_ID(@dbName)

		/* validate dbName, confirm db already exists, and don't run on system database */
		if (@dbName is null or Len(@dbName) < 1) begin
			raiserror (N'The dbName parameter cannot be null or blank.', 10, 1)
			goto skipIt
		end

		if (DB_ID(@dbName) is null) begin
			raiserror (N'Database [%s] does not exist.', 10, 1, @dbName)
			goto skipIt
		end

		if (DB_ID(@dbName) < 5) begin
			raiserror (N'Do not run this on a system database [%s].', 10, 1, @dbName)
			goto skipIt
		end

		/* Generate user name for DB Owner */
		declare @dbOwner sysname set @dbOwner = @dbName + '_dbOwner'

		/* Check if login already exists */
		if exists (SELECT name FROM master.sys.server_principals WHERE name = @dbOwner) begin
			raiserror (N'Login [%s] already exists.', 10, 1, @dbOwner)
			goto skipIt
		end

		--print @dbOwner

		/* Generate random password */
		declare @chars varchar(100) set @chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
		declare @password sysname set @password = (select top 16 substring(@chars, 1 + Number, 1) as [text()]
			from master..spt_values
			where number < datalength(@chars)
			  and type = 'P'
			order by newid()
			for xml path(''))

		/* Create user with password */
		declare @sqlCommand nvarchar(2000)
		set @sqlCommand = REPLACE(REPLACE(REPLACE(N'
		USE [master]
		CREATE LOGIN [__dbName__dbOwner] WITH PASSWORD=N'''', DEFAULT_DATABASE=[__dbName], CHECK_EXPIRATION=OFF, CHECK_POLICY=ON',
		'WITH PASSWORD=N''''', 'WITH PASSWORD=N''' + @password + ''''), N'__dbName__dbOwner', @dbOwner), N'__dbName', @dbName)

		/* Deny new login to veiw other databases */
		set @sqlCommand = @sqlCommand + REPLACE(N'
		DENY VIEW ANY DATABASE TO [__dbName__dbOwner]', '__dbName__dbOwner', @dbOwner)

		/* Give user owner rights on database.
		 **** User can't be an owner (dbo) and a db_owner role at the same time
		 **** so don't use this code.
		 */
		--set @sqlCommand = @sqlCommand + REPLACE(REPLACE(N'
		--USE [__dbName]
		--CREATE USER [__dbName__dbOwner] FOR LOGIN [__dbName__dbOwner]
		--ALTER USER [__dbName__dbOwner] WITH DEFAULT_SCHEMA=[dbo]
		--ALTER ROLE [db_owner] ADD MEMBER [__dbName__dbOwner]',
		--N'__dbName__dbOwner', @dbOwner), N'__dbName', @dbName)

		/* Make this user the owner (dbo) of the database.
		 * Allows the user to view this database in the SSMS list even with 
		 * the above DENY VIEW ANY DATABASE...
		 */
		set @sqlCommand = @sqlCommand + N'
		exec [' + @dbName + '].[dbo].[sp_changedbowner] [' + @dbOwner + ']'

		declare @errorMessage nvarchar(4000)

		--print @sqlCommand
		begin try
			exec sp_executesql @sqlCommand
		end try
		begin catch
			select @errorMessage = ERROR_MESSAGE()
			raiserror (N'Error executing SQL command: "%s" %s', 10, 1, @errorMessage, @sqlCommand)
			goto skipIt
		end catch

		print FormatMessage(CHAR(10) + 'Created user [%s] with owner rights on database [%s]. Password: %s', @dbOwner, @dbName, @password)

		skipIt:

		-- remove dbName from temp table
		delete #dbNamesTemp where [dbName] = @dbName

		-- get next dbName from temp table
		set rowcount 1
		select @dbName = [dbName] from #dbNamesTemp
	end

	theEnd:

	drop table #dbNamesTemp
end
go


