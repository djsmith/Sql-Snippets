/*
Script    : Column Size Checker
Version   : 1.0 (March 2010)
Author    : Richard Doering
Email     : r3m1xn9@gmail.com
Web       : http://sqlsolace.blogspot.com
          : http://www.sqlservercentral.com/scripts/T-SQL/69859/

This is a utility to show how well your column sizes suit your data (or vice versa).

By default, the script will run for every table in the database you run it in.

This may prove quite time consuming so set the @SCHEMA and @TABLE variables at the 
top of the script to the schema and table name respectively to analyse only one table.

The output is fairly self explanatory i.e. the name of the name, it's rowcount and column details.

For each column, 3 length values are given (where appropriate)

   1. COLUMN_MAX_LENGTH is the defined length of the column.
   2. DATA_MIN_LENGTH is the lengthof the smallest data found in the column
   3. DATA_MAX_LENGTH is the length of the largest data found in the column
*/

SET NOCOUNT ON
SET ANSI_WARNINGS ON
DECLARE @SCHEMA varchar(50)
DECLARE @TABLE varchar(50)

SET @SCHEMA = ''
SET @TABLE = ''

DECLARE @CURRENTROW int
DECLARE @TOTALROWS int
DECLARE @COLUMNMAXSIZE int
DECLARE @COLUMNMINSIZE int
DECLARE @SQLSTRING nvarchar(max)
DECLARE @PARAMETER nvarchar(500) ;
DECLARE @TABLEDETAILS TABLE (UNIQUEROWID int IDENTITY(1,1),
                             TABLE_SCHEMA varchar(255),
                             TABLE_NAME varchar(255),
                             COLUMN_NAME varchar(255),
                             COLUMN_TYPE varchar(255),
                             TABLE_ROWS bigint,
                             MAX_LENGTH int,
                             DATA_MIN_LENGTH int,
                             DATA_MAX_LENGTH int)

INSERT  INTO @TABLEDETAILS (TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, TABLE_ROWS, MAX_LENGTH)
        SELECT  SCHEMA_NAME(O.SCHEMA_ID) AS TABLE_SCHEMA, OBJECT_NAME(O.OBJECT_ID) AS TABLE_NAME, C.NAME AS COLUMN_NAME, T.NAME AS COLUMN_TYPE, R.SUMROWS AS TABLE_ROWS, C.MAX_LENGTH
        FROM    SYS.TABLES O
                INNER JOIN SYS.COLUMNS C
                   ON C.OBJECT_ID = O.OBJECT_ID
                INNER JOIN SYS.TYPES T
                   ON C.SYSTEM_TYPE_ID = T.SYSTEM_TYPE_ID
                      AND T.NAME IN ('CHAR', 'VARCHAR', 'NCHAR', 'NVARCHAR')
                INNER JOIN (SELECT  OBJECT_ID, SUM(ROWS) AS SUMROWS
                            FROM    SYS.PARTITIONS
                            WHERE   INDEX_ID IN (0, 1)
                            GROUP BY OBJECT_ID) R
                   ON R.OBJECT_ID = O.OBJECT_ID
        WHERE   SCHEMA_NAME(O.SCHEMA_ID) <> 'sys'
                AND OBJECT_NAME(O.OBJECT_ID) = CASE WHEN @TABLE = '' THEN OBJECT_NAME(O.OBJECT_ID)
                                                    ELSE @TABLE
                                               END
                AND SCHEMA_NAME(O.SCHEMA_ID) = CASE WHEN @SCHEMA = '' THEN SCHEMA_NAME(O.SCHEMA_ID)
                                                    ELSE @SCHEMA
                                               END
                                
SELECT  @TOTALROWS = COUNT(*)
FROM    @TABLEDETAILS
SELECT  @CURRENTROW = 1
WHILE @CURRENTROW <= @TOTALROWS   
   BEGIN
      SET @COLUMNMAXSIZE = 0
      SET @COLUMNMINSIZE = 0  
      SELECT  @SQLSTRING = 'SELECT @COLUMNSIZEMIN = MIN(LEN([' + COLUMN_NAME + '])) ,@COLUMNSIZEMAX = MAX(LEN([' + COLUMN_NAME + '])) FROM [' + TABLE_SCHEMA + '].[' + TABLE_NAME + '] WITH (NOLOCK)'
      FROM    @TABLEDETAILS
      WHERE   UNIQUEROWID = @CURRENTROW
      SET @PARAMETER = N'@COLUMNSIZEMAX INT OUTPUT,@COLUMNSIZEMIN INT OUTPUT' ;          
      EXECUTE SP_EXECUTESQL       @SQLSTRING, @PARAMETER, @COLUMNSIZEMIN = @COLUMNMINSIZE OUTPUT, @COLUMNSIZEMAX = @COLUMNMAXSIZE OUTPUT      
      UPDATE  @TABLEDETAILS
      SET     DATA_MAX_LENGTH = ISNULL(@COLUMNMAXSIZE, 0),
              DATA_MIN_LENGTH = ISNULL(@COLUMNMINSIZE, 0)
      WHERE   UNIQUEROWID = @CURRENTROW

      SET @CURRENTROW = @CURRENTROW + 1   
   END      

SELECT  TABLE_SCHEMA, TABLE_NAME, TABLE_ROWS, COLUMN_NAME, COLUMN_TYPE, CASE MAX_LENGTH
                                                                          WHEN-1 THEN 'MAX'
                                                                          ELSE CONVERT(char(10), MAX_LENGTH)
                                                                        END AS COLUMN_MAX_LENGTH, DATA_MIN_LENGTH, DATA_MAX_LENGTH
FROM    @TABLEDETAILS
ORDER BY 1, 2, 3