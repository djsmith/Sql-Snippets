USE AdventureWorks ;
GO

IF EXISTS (SELECT  *
           FROM    sys.objects
           WHERE   [object_id] = object_id(N'[dbo].[usp_generate_inserts]')
                   AND type IN (N'P', N'PC'))
   BEGIN
      DROP PROC [dbo].[usp_generate_inserts] ;
   END
GO

CREATE PROC dbo.usp_generate_inserts
(
 @table nvarchar(255))
AS
BEGIN
   SET NOCOUNT ON
   DECLARE @is_identity bit ;
   DECLARE @columns nvarchar(max) ;
   DECLARE @values nvarchar(max) ;
   DECLARE @script nvarchar(max) ;
   IF isnull(charindex('.', @table), 0) = 0
      BEGIN
         PRINT 'Procedure dbo.usp_generate_inserts expects a table_name parameter in the form of schema_name.table_name' ;
      END
   ELSE
      BEGIN
        -- initialize variables as otherwise the padding will fail (return nulls for nvarchar(max) types)
         SET @is_identity = 0 ;
         SET @columns = '' ;
         SET @values = '' ;
         SET @script = '' ;
        /*
            The following select makes an assumption that the identity column should be included in
            the insert statements. Such inserts still work when coupled with identity_insert toggle, 
            which is typically used when there is a need to "plug the holes" in the identity values.
            Please note the special handling of the text data type. The type should never be present
            in SQL Server 2005 tables because it will not be supported in future versions, but there
            are unfortunately plenty of tables with text columns out there, patiently waiting for 
            someone to upgrade them to varchar(max).
        */
         SELECT  @is_identity = @is_identity|columnproperty(object_id(@table), column_name, 'IsIdentity'),
                 @columns = @columns + ', ' + '[' + column_name + ']',
                 @values = @values + ' + '', '' + isnull(master.dbo.fn_varbintohexstr(cast(' + CASE data_type
                                                                                                 WHEN 'text' THEN 'cast([' + column_name + '] as varchar(max))'
                                                                                                 ELSE '[' + column_name + ']'
                                                                                               END + ' as varbinary(max))), ''null'')'
         FROM    information_schema.columns
         WHERE   table_name = substring(@table, charindex('.', @table) + 1, len(@table))
                 AND data_type != 'timestamp'
         ORDER BY ordinal_position ;
         SET @script = 'select ''insert into ' + @table + ' (' + substring(@columns, 3, len(@columns)) + ') values ('' + ' + substring(@values, 11, len(@values)) + ' + '');'' from ' + @table + ';' ;
         IF @is_identity = 1
            BEGIN
               PRINT ('set identity_insert ' + @table + ' on') ;
            END
        /* 
            generate insert statements. If the results to text option is set and the query results are
            completely fit then the prints are a part of the batch, but if the results to grid is set
            then the prints (identity insert related) can be gathered from the messages window.
        */ EXEC sp_executesql @script ;
         IF @is_identity = 1
            BEGIN
               PRINT ('set identity_insert ' + @table + ' off') ;
            END
      END
   SET NOCOUNT OFF
END
GO
-- test the proc
EXEC dbo.usp_generate_inserts 'Production.BillOfMaterials'
/*
 Here is the paste from few of the 2679 returned records:
 insert into Production.BillOfMaterials ([BillOfMaterialsID], [ProductAssemblyID] /* abridged */) values (0x0000037d, null, /* abridged */);
 insert into Production.BillOfMaterials ([BillOfMaterialsID], [ProductAssemblyID], /* abridged */) values (0x0000010f, null,/* abridged */);
 insert into Production.BillOfMaterials ([BillOfMaterialsID], [ProductAssemblyID], /* abridged */) values (0x00000022, null,/* abridged */);
 insert into Production.BillOfMaterials ([BillOfMaterialsID], [ProductAssemblyID], /* abridged */) values (0x0000033e, null,/* abridged */);
 insert into Production.BillOfMaterials ([BillOfMaterialsID], [ProductAssemblyID], /* abridged */) values (0x0000081a, null,/* abridged */);
 insert into Production.BillOfMaterials ([BillOfMaterialsID], [ProductAssemblyID], /* abridged */) values (0x0000079e, null,/* abridged */);

*/

-- clean up
IF EXISTS (SELECT  *
           FROM    sys.objects
           WHERE   [object_id] = object_id(N'[dbo].[usp_generate_inserts]')
                   AND type IN (N'P', N'PC'))
   BEGIN
      DROP PROC [dbo].[usp_generate_inserts] ;
   END
GO
