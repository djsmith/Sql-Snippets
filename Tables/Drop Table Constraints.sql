 /*
This script generates a set of DDL commands that will drop 
various constraints on a particular table.

Taken from 'Generate DDL script to drop table constraints' By VPSD Gupta
http://www.sqlservercentral.com/scripts/Drop+PK+of+a+table/65862/

Examples how to set the various variables in the first DECLARE block: 
-- Drop PK
SELECT @sConstraint_Type = 'PK', @sDB_Name = 'MY_DATABASE', @sTable_Name = 'MY_TABLE'    
-- Drop FKs
SELECT @sConstraint_Type = 'FK', @sDB_Name = 'MY_DATABASE', @sTable_Name = 'MY_TABLE'    
-- Drop Check Constraints
SELECT @sConstraint_Type = 'CK', @sDB_Name = 'MY_DATABASE', @sTable_Name = 'MY_TABLE'    
-- Drop Default Constraints
SELECT @sConstraint_Type = 'DF', @sDB_Name = 'MY_DATABASE', @sTable_Name = 'MY_TABLE'    

*/

DECLARE
	@sConstraint_Type VARCHAR(50),
	@sDB_Name SYSNAME,
	@sSchema_Name SYSNAME,
	@sTable_Name SYSNAME

SELECT 
	@sConstraint_Type = 'DF',   -- PK, FK, CK, DF
	@sDB_Name = 'AdventureWorks', 
	@sSchema_Name = 'HumanResources',
	@sTable_Name = 'Employee'   

SET NOCOUNT ON

DECLARE @sSQL            VARCHAR(8000),
        @sStr            VARCHAR(1000)

-------------------------------------------------------------
if (Select COUNT(*) Where @sConstraint_Type in ('PK', 'FK', 'CK', 'DF'))<1 begin
	raiserror('@sConstraint_Type must be one of these values: ''PK'', ''FK'', ''CK'', ''DF''', 16, 1)
end
else
begin

CREATE TABLE #Temp (
    Type                VARCHAR(50),
    DBName                SYSNAME,
    Schema_Name            SYSNAME,
    Table_Name            SYSNAME,
    Column_Name            SYSNAME DEFAULT '',
    Constraint_Name        SYSNAME,
    DROP_SQL            VARCHAR(8000)
)

IF @sConstraint_Type = 'PK'
BEGIN
    -- Drop PK
    SET @sSQL = 'SELECT    DISTINCT Type        = o.Type,
                            DBName                = ''' + @sDB_Name + ''',
                            Schema_Name            = s.name,
                            Table_Name            = p.name,
                            PK_Constraint_Name    = o.name,
                            DROP_SQL            = ''ALTER TABLE ' + @sDB_Name + '.'' + s.Name + ''.'' + c.Table_Name + '' DROP CONSTRAINT '' + c.CONSTRAINT_NAME
                    FROM    ' + @sDB_Name + '.INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE c
                            INNER JOIN ' + @sDB_Name + '.sys.objects o ON c.CONSTRAINT_NAME = o.name
                            INNER JOIN ' + @sDB_Name + '.sys.objects p on o.parent_object_id = p.object_id
                            INNER JOIN ' + @sDB_Name + '.sys.schemas s ON p.schema_id = s.schema_id
                    WHERE    c.TABLE_NAME = ''' + @sTable_Name + ''' AND c.TABLE_SCHEMA = ''' + @sSchema_Name + '''
                    AND        o.Type = ''PK''
                '
                
    INSERT INTO #Temp (Type, DBName, Schema_Name, Table_Name, Constraint_Name, DROP_SQL)
    EXEC (@sSQL)
END

-------------------------------------------------------------

ELSE IF @sConstraint_Type = 'FK'
BEGIN
    -- Drop FK
    SET @sSQL = '
                    SELECT    DISTINCT Type        = ''FK'',
                            DBName                = ''' + @sDB_Name + ''',
                            Schema_Name            = s.name,
                            Table_Name            = p.name,
                            FK_Constraint_Name    = o.name,
                            DROP_SQL            = ''ALTER TABLE ' + @sDB_Name + '.'' + s.Name + ''.'' + c.Table_Name + '' DROP CONSTRAINT '' + c.CONSTRAINT_NAME
                    FROM    ' + @sDB_Name + '.INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE c
                            INNER JOIN ' + @sDB_Name + '.sys.objects o ON c.CONSTRAINT_NAME = o.name
                            INNER JOIN ' + @sDB_Name + '.sys.objects p on o.parent_object_id = p.object_id
                            INNER JOIN ' + @sDB_Name + '.sys.schemas s ON p.schema_id = s.schema_id
                    WHERE    c.TABLE_NAME = ''' + @sTable_Name + ''' AND c.TABLE_SCHEMA = ''' + @sSchema_Name + '''
                    AND        o.Type = ''F''
                '

    INSERT INTO #Temp (Type, DBName, Schema_Name, Table_Name, Constraint_Name, DROP_SQL)
    EXEC (@sSQL)
END

-------------------------------------------------------------

ELSE IF @sConstraint_Type = 'CK'
BEGIN
    -- Drop Check Constraint
    SET @sSQL = '    
                    SELECT    DISTINCT Type        = ''CK'',
                            DBName                = ''' + @sDB_Name + ''',
                            Schema_Name            = s.name,
                            Table_Name            = p.name,
                            Column_Name            = c.column_name,
                            CK_Constraint_Name    = o.name,
                            DROP_SQL            = ''ALTER TABLE ' + @sDB_Name + '.'' + s.Name + ''.'' + c.Table_Name + '' DROP CONSTRAINT '' + c.CONSTRAINT_NAME
                    FROM    ' + @sDB_Name + '.INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE c
                            INNER JOIN ' + @sDB_Name + '.sys.objects o ON c.CONSTRAINT_NAME = o.name
                            INNER JOIN ' + @sDB_Name + '.sys.objects p on o.parent_object_id = p.object_id
                            INNER JOIN ' + @sDB_Name + '.sys.schemas s ON p.schema_id = s.schema_id
                    WHERE    c.TABLE_NAME = ''' + @sTable_Name + ''' AND c.TABLE_SCHEMA = ''' + @sSchema_Name + '''
                    AND        o.Type = ''C''
                '
    INSERT INTO #Temp (Type, DBName, Schema_Name, Table_Name, Column_Name, Constraint_Name, DROP_SQL)
    EXEC (@sSQL)
END

-------------------------------------------------------------

ELSE IF @sConstraint_Type = 'DF'
BEGIN
    -- Drop Default Constraint
    SET @sSQL = '
                    SELECT    DISTINCT Type        = ''DF'',
                            DBName                = ''' + @sDB_Name + ''',
                            Schema_Name            = s.name,
                            Table_Name            = p.name,
                            Column_Name            = c.name,
                            DF_Constraint_Name    = o.name,
                            DROP_SQL            = ''ALTER TABLE ' + @sDB_Name + '.' + @sSchema_Name + '.'' + p.name + '' DROP CONSTRAINT '' + o.name 
                    FROM    ' + @sDB_Name + '.sys.columns c 
                            INNER JOIN ' + @sDB_Name + '.sys.objects o on c.default_object_id = o.object_id
                            INNER JOIN ' + @sDB_Name + '.sys.objects p on o.parent_object_id = p.object_id
                            INNER JOIN ' + @sDB_Name + '.sys.schemas s ON p.schema_id = s.schema_id
                    WHERE    o.Type = ''D'' 
                    AND        c.object_id = object_id(''' + @sDB_Name + '.' + @sSchema_Name + '.' + @sTable_Name + ''')'

    INSERT INTO #Temp (Type, DBName, Schema_Name, Table_Name, Column_Name, Constraint_Name, DROP_SQL)
    EXEC (@sSQL)
END

-------------------------------------------------------------

SELECT    *
FROM    #Temp

-------------------------------------------------------------
drop table #Temp

end

GO


