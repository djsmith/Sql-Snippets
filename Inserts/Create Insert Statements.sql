 /******************************************************************************
**		File: sqlDump.sql
**
**		Desc: This file allows the scripting of data from a database
**		      To aid migration
**		Auth: Peter Livesey 
**		Date: 14/2/2006 
*******************************************************************************
**		Change History
*******************************************************************************
**		Date:		Author:				Description:
**    
*******************************************************************************/

SET ANSI_NULLS ON
SET NOCOUNT ON
DECLARE @Tablename sysname

/*set the table name below to th etable in which the data resides*/
SET @Tablename = 'suppliers'

/*change the following query to query for the dat you require scripted
you may include a where statement if required*/
SELECT * INTO #tabledata  FROM suppliers


DECLARE @tab nvarchar(10)
DECLARE @CRLF char(2)
SET @tab= '  '
SET @CRLF=Char(13)+Char(10)

DECLARE @OutPutStatement varchar (4000)
DECLARE @IDname varchar (100)
DECLARE @SQLstring nvarchar (4000)
DECLARE @FieldNames nvarchar (2000)
declare @CurrentID varchar(1000)

CREATE TABLE #CurrentID (id varchar(1000))
CREATE TABLE #Values (value varchar(1000),type varchar(100))

/*we need the name of the id field for the loop as this is the only field we can guarantee unique*/
SELECT  @IDname = b.name
FROM 
	syscolumns b
INNER JOIN 
	sysindexes si
ON
	b.id = si.id
	and b.colid = si.indid
	
where b.id = OBJECT_ID(@Tablename)
and indid = 1

/*get the fieldnames from the table except autonumbers*/
SELECT  b.name,st.name as stname
into #FieldNames
FROM 
	sysobjects a
INNER JOIN
	syscolumns b
ON
	a.id = b.id
INNER JOIN
	systypes st
ON
	b.xtype = st.xusertype

where a.id = OBJECT_ID(@Tablename)
	and colstat <>1

SET @FieldNames = ''
SELECT  @FieldNames = @FieldNames + b.name + ',' + @CRLF + @tab + @tab 
FROM 
	sysobjects a
INNER JOIN
	syscolumns b
ON
	a.id = b.id
		
WHERE a.name = @Tablename
	and autoval is  null
		
/*remove trailing comma*/
SET @FieldNames = LEFT (@FieldNames,LEN(@FieldNames)-3) 

/*don't go through loop if no key as can't break loop without loop index*/
if (coalesce(@idname,'') !='')
BEGIN 
	/*begin loop*/
	while exists (select '*' from #TableData)
	BEGIN
		/*empty tables for each run through the loop*/
		delete from #CurrentID
		delete from #Values
		/*reset  variable for loop*/
		SET @OutPutStatement = 'INSERT INTO ' + @Tablename  + @CRLF  + @tab +'( ' + @CRLF + @tab + @tab
		/* add fieldnames to insert statement*/
		SET @OutPutStatement= @OutPutStatement + @FieldNames + @CRLF + @tab + ' ) ' + @CRLF +  ' VALUES ' + @CRLF + @tab + ' ( ' 
		
	
		
	
		/* as we have to do this dynamically we will throw 
		   the id into a temprary table and then retrieve into a variable*/
		SET @SQLstring =  'INSERT INTO #CurrentID SELECT  min(CONVERT(varchar(1000),' + @idName + ')) as id FROM #TableData '
		EXEC sp_executesql @SQLstring 
		SELECT @Currentid = id FROM #CurrentID
		
		
		 
		
		
		
		/*place the values into a temp table*/
		SET @SQLstring = ''
		SELECT @SQLstring  =  @SQLstring + @CRLF  + @CRLF +
			
				   ' INSERT INTO  #Values SELECT CONVERT(varchar(1000),' + name + '),''' + stname  + ''' FROM  #Tabledata WHERE '  + @idname  + ' = ''' + CONVERT(varchar(1000),@currentid) +''''
		
				
		FROM #Fieldnames
		
		EXEC sp_executesql @SQLstring 
	
		/* now add the values to the ouput statement*/
		SELECT @OutPutStatement = @OutPutStatement + @CRLF + @tab + @tab +
			CASE type
				WHEN 'char' 		THEN   coalesce('''' + replace(value,'''','''''')+ '''','NULL')  
				WHEN 'varchar' 		THEN   coalesce('''' + replace(value,'''','''''')+ '''','NULL')
				WHEN 'nvarchar'		THEN   coalesce('''' + replace(value,'''','''''')+ '''','NULL')
				WHEN 'nchar'		THEN   coalesce('''' + replace(value,'''','''''')+ '''','NULL')
				WHEN 'text'		THEN   coalesce('''' + replace(value,'''','''''')+ '''','NULL')
				WHEN 'ntext'		THEN   coalesce('''' + replace(value,'''','''''')+ '''','NULL')
				WHEN 'uniqueidentifier'	THEN   coalesce('''' + value + '''','NULL')
				WHEN 'datetime'		THEN   coalesce('''' + value + '''','NULL')
				ELSE  coalesce(value,'NULL')
			END + ','
		FROM #Values
		
		/* remove trailing comma again*/
		SET @OutPutStatement = LEFT (@OutPutStatement,LEN(@OutPutStatement)-1) 
		
		/* finally close the bracket*/
		SET @OutPutStatement = @OutPutStatement + @CRLF + @tab +  ' ) '
		
		/*output the result*/		
		PRINT @OutPutStatement
		
		/*delete statement to help loop*/
		SET @SQLstring = N'DELETE FROM #tabledata WHERE ' + @idName + '= ''' + convert(varchar(1000),@currentid ) + ''''
		exec sp_executesql @SQLstring 
	
	END
END
ELSE
	PRINT ('No Primary Key cannot perform operation')


/*cleanup temp tables*/
drop table #Tabledata
drop table #FieldNames
drop table #CurrentID
drop table #Values

