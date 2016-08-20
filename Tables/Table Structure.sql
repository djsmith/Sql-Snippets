/*
Simple Display of Table Structure
The sp_help stored procedure can provide information about a particular database object including the structure of a table, but often this procedure returns more information than is needed. A simple display of a table’s structure is provided here.
*/
create procedure prDisplayStructure (
	@tableName varchar(50)
) as
	if exists (select * from dbo.sysobjects
		where id =object_id(N'[dbo].['+@tableName+']')
			and objectproperty(id, N'IsUserTable') = 1)
	Begin
		select cols.name as 'Name', typs.name as 'Type', cols.Length as 'Length',
		cols.prec as 'Precision', cols.Scale as 'Scale', Allownulls as 'Allow Nulls'
		from syscolumns cols
		inner join systypes typs 
			on cols.xusertype=typs.xusertype
		where id =object_id(@tableName)
		--Uncomment the next line to provide an alphibetical listing
		--ORDER BYname
	End
	else
	Begin
		print 'No table named '+@tableName + ' in the ' + db_name() + 'Database'
	End
	
return 
 