/*
Uses a temporary table to loop thru the user tables in a database,
run the sp_spacedused procedure, add the results to the temporary table
and then display the table with various statistics.
*/

Create Table #SpaceUsed (
	[TableName] nvarchar(128), 
	[Rows] char(11), 
	[Reserved] varchar(15), 
	[Data] varchar(15), 
	[Index] varchar(15), 
	[Unused] varchar(15)
)
GO

Declare @TableName nvarchar(128)
Declare @MaxTableName nvarchar(128)
Declare @Cmd nvarchar(1000) 

set nocount on

select @TableName = '', @MaxTableName = max(name) 
from sysobjects 
where xtype='u'

while @TableName < @MaxTableName 
begin
	select @TableName = min(name) 
	from sysobjects 
	where xtype='u' and name > @TableName
	
	set @Cmd='exec sp_spaceused['+@TableName+']'
	insert into #SpaceUsed 
		exec sp_executesql @Cmd
end

exec sp_spaceused

--Query must trim the ' KB' text output by the sp_spacedused procedure
select *, 
cast(left([Reserved],len([Reserved])-3) as decimal)/([Rows]+1) as KBPerRow,
cast(left([Index],len([Index])-3) as decimal)/(cast(left([Data],len([Data])-3) as decimal)+cast(left([Index],len([index])-3) as decimal)+1) as IndexRatio,
cast(left([Reserved],len([Reserved])-3) as decimal)/[S].[SumReserved] as SpaceRatio
from #SpaceUsed 
cross join (
	select sum(cast(left([Reserved],len([Reserved])-3) as decimal)) as SumReserved
	from #SpaceUsed) as S
order by cast(left([Reserved],len([Reserved])-3) as int) desc

SET NOCOUNT OFF
GO

DROP TABLE #SpaceUsed
GO

