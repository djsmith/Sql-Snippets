/********************************************************************************
 EXECute a string of T-SQL commands over the contents
 of a set, replacing token strings with column values as
 indicated. The set is defined by the @FROM parameter.
 Optionally allows for printing the final execution string,
 switching databases, and user-specified TRY-CATCH handling.
 Also allows the caller to switch quote characters, to ease
 quote-doubling problems.
 
 (c) 2010, RBarryYoung, Proactive Performance Solutions, Inc.
 http://www.sqlservercentral.com/scripts/Admin/69737/
********************************************************************************/

/********************************************************************************
 Example Usages
 
1) INSERT..EXECute:
Demonstrates capturing the SELECT output from an EXECUTE OVER_SET that
searches every database in the SQL Server Instance for routines with
the work "cursor" in them.
--

CREATE TABLE #temp (DB sysname, [Schema] sysname, Routine sysname);
INSERT INTO #temp
  EXECUTE OVER_SET '
    SELECT ROUTINE_CATALOG, ROUTINE_SCHEMA, ROUTINE_NAME
      FROM [{db}].INFORMATION_SCHEMA.ROUTINES
      WHERE ROUTINE_DEFINITION like "%cursor%"',
    @from = 'sys.sysdatabases WHERE dbid > 4',
    @subs1 = '{db}=name',
    @quote = '"'
;
SELECT * from #temp;
DROP table #temp;

--
The @from argument returns the list of non-system databases in the server, 
and the @susbs1 argument "{db}=name" tells it to replace every instance 
of "{db}" in the command strings with the value of the [name] column (from 
sys.sysdatabases). Note also the @quote argument's value (") allows us to 
use a single quotation mark in the quoted command text instead of having
to use double apostrophes (ie, ' "%cursor%" ', instead of ' ''%cursor%'' '). 

--======

2) Nested Example:
Demonstrates, nesting OVER_SET execution to operate against the combination
of to different sets, the second dependent on the first. Specifically,
it searches every non-system database for every user that is a windows 
user or group, and then attempts to map them back to a server Login of
the same name.
--

EXECUTE OVER_SET '
   EXECUTE OVER_SET "
        ALTER USER [{name}] WITH LOGIN = [{name}]; 
        PRINT `USER {name} has been mapped to its Login.`;",
     @from   = "sys.database_principals
            WHERE ( type_desc = ""WINDOWS_GROUP"" OR type_desc = ""WINDOWS_USER"" )
              AND name NOT like ""%dbo%"" AND name NOT LIKE ""%#%"" ",
     @use_db = "{db}",
     @subs1  = "{name}=name",
     @catch  = "continue",
     @print  = 1,
     @quote  = "`";
     ',
  @from  = 'sys.sysdatabases
       WHERE dbid > 4',
  @subs1 = '{db}=name',
  @catch = 'continue',
  @print = 0,
  @quote = '"';

--
The outer OVER_SET uses the @from argument to return the list of all databases
which the @subs1 argument "{db}=name", uses to modify the inner OVER_SET
commands @use_db argument, cuasing the inner execution to USE [{db}} to each
database in turn. The inner execution's @from argument returns the list
of database users that are WINDOWS_* user or group, and the @subs1 ({name}=name)
cause the "{name}" token to be replaced with the value of the [name] column
from the database_principals table.

Note that two different @quote characters are used ( ("), then (`) ), removing
the need for double or even quadruple apostrophes in the inner command text.
(also note, that the @from argument text does not benefit from this, and can
only use the outer command quote (") becuase it is part of the outer command
text argument.
********************************************************************************/

ALTER PROC 
  OVER_SET (
    @command AS NVARCHAR(MAX),       -- Template SQL command
    @from    AS NVARCHAR(MAX),       -- FROM..WHERE clause string
    @subs1   AS NVARCHAR(MAX) = N'', -- Substitution parameters, these are
    @subs2   AS NVARCHAR(MAX) = N'', -- of the form "<find>=<repl>" where:
    @subs3   AS NVARCHAR(MAX) = N'', -- <find> will be searched for in @command, and
                     -- <repl> will replace it, if it was found
                     -- (typically, <repl> should be a column name
                     -- returned by the FROM clause)
    @print   AS BIT = 1,             -- 0 = suppress PRINT of the SQL before executing
    @catch   AS VARCHAR(12) = 'continue',
                     -- TRY/CATCH option parameters. Choices are:
                     -- 'continue' on an error, print a message & continue
                     -- 'ignore' attempt to suppress all errors
                     -- 'fail' try to re-raise the error
                     -- 'none' no TRY/CATCH blocks
    @use_db  AS NVARCHAR(255) = N'', -- DB to switch to befor execution of the SQL text
    @quote   AS NVARCHAR(8)   = N''  -- search for this character & replace with (').
    )
AS
--
DECLARE @qt AS NVARCHAR(1), @cr AS NVARCHAR(1);
SELECT  @qt = N'''',        @cr = N'
';
DECLARE @find1  AS NVARCHAR(MAX), @prfx1  AS NVARCHAR(MAX), @sufx1 AS NVARCHAR(MAX)
DECLARE @find2  AS NVARCHAR(MAX), @prfx2  AS NVARCHAR(MAX), @sufx2 AS NVARCHAR(MAX)
DECLARE @find3  AS NVARCHAR(MAX), @prfx3  AS NVARCHAR(MAX), @sufx3 AS NVARCHAR(MAX)
DECLARE @prtst  AS NVARCHAR(MAX), @prfxC  AS NVARCHAR(MAX), @sufxC AS NVARCHAR(MAX)
DECLARE @newdb  AS NVARCHAR(MAX), @declr  AS NVARCHAR(MAX)
DECLARE @NewCmd AS NVARCHAR(MAX), @GenCmd AS NVARCHAR(MAX)
;
SELECT
 @find1 = CASE WHEN @subs1 = N'' THEN N'' ELSE LEFT(@subs1,CHARINDEX(N'=',@subs1)-1) END,
 @prfx1 = CASE WHEN @subs1 = N'' THEN N'' ELSE N'REPLACE(' END,
 @sufx1 = CASE WHEN @subs1 = N'' THEN N'' ELSE N',@find1,'+RIGHT(@subs1,LEN(@subs1)-CHARINDEX(N'=',@subs1))+N')' END,
 @find2 = CASE WHEN @subs2 = N'' THEN N'' ELSE LEFT(@subs2,CHARINDEX(N'=',@subs2)-1) END,
 @prfx2 = CASE WHEN @subs2 = N'' THEN N'' ELSE N'REPLACE(' END,
 @sufx2 = CASE WHEN @subs2 = N'' THEN N'' ELSE N',@find2,'+RIGHT(@subs2,LEN(@subs2)-CHARINDEX(N'=',@subs2))+N')' END,
 @find3 = CASE WHEN @subs3 = N'' THEN N'' ELSE LEFT(@subs3,CHARINDEX(N'=',@subs3)-1) END,
 @prfx3 = CASE WHEN @subs3 = N'' THEN N'' ELSE N'REPLACE(' END,
 @sufx3 = CASE WHEN @subs3 = N'' THEN N'' ELSE N',@find3,'+RIGHT(@subs3,LEN(@subs3)-CHARINDEX(N'=',@subs3))+N')' END,
 @newdb = CASE WHEN @use_db= N'' THEN N'' ELSE N'USE [' + @use_db + N'];' + @cr END,
 @declr = N'DECLARE @_Num AS INT, @_Lin AS INT, @_Err AS NVARCHAR(MAX), @_Msg AS NVARCHAR(MAX);'+@cr
;
;WITH
 [base] AS (SELECT cmd = @command),
 [quot] AS (SELECT cmd = CASE @quote WHEN N'' THEN cmd ELSE REPLACE(cmd, @quote, @qt) END FROM [base]),
 [dble] AS (SELECT cmd = N'N'+@qt+REPLACE(cmd, @qt, @qt+@qt)+@qt FROM [quot]),
 [prnt] AS (SELECT cmd = CASE @print WHEN 1 THEN N' PRINT '+cmd+';'+@cr ELSE N'' END
                       + N' EXEC('+cmd+N');' FROM [dble]),
 [ctch] AS (SELECT cmd = 
    CASE @catch WHEN N'none' THEN cmd 
    ELSE N'BEGIN TRY'+@cr+cmd+@cr+N'END TRY'+@cr+N'BEGIN CATCH'+@cr
    + N' SELECT @_Num=ERROR_NUMBER(), @_Lin=ERROR_LINE(), @_Err=ERROR_MESSAGE()'+@cr
    + CASE @catch
        WHEN N'continue' THEN 
                N' SELECT @_msg=''Continuing after Error(''+CAST(@_Num AS NVARCHAR)+'') at Line ''+CAST(@_Lin AS NVARCHAR)+'''
                         +@cr+' ''+@_Err;'+@cr
               +N' PRINT @_msg; '+@cr
               +N' PRINT '' ''; '+@cr
        WHEN N'ignore' THEN N' -- ignore = do nothing'+@cr
        WHEN N'fail' THEN
                N' SELECT @_msg=''Failing after Error(''+CAST(@_Num AS NVARCHAR)+'') at Line ''+CAST(@_Lin AS NVARCHAR)+'''
                         +@cr+' ''+@_Err;'+@cr
               +N' RAISERROR(@_Num, 16, 1);'+@cr
               +N' PRINT '' ''; '+@cr
        ELSE N' --BAD else branch, shouldnt get here' END
    + N'END CATCH;' END FROM [prnt])
SELECT 
    @NewCmd = @prfx1+@prfx2+@prfx3+ N'@command' +@sufx1+@sufx2+@sufx3,
    @command = cmd + @cr
FROM [ctch]
;
SELECT @GenCmd = '
DECLARE @sql AS NVARCHAR(MAX); SET @sql = '''+@newdb+ +@declr+ '''
;WITH 
  [-@from]  AS ( SELECT * FROM ' +@from+ ' )
, [-@subs]  AS ( SELECT [-NewCmd] = ' +@NewCmd+ ' FROM [-@from] )
, [-@print] AS ( SELECT [-NewCmd] = [-NewCmd] FROM [-@subs] )
SELECT 
  @sql = @sql + ''
'' + [-NewCmd]
FROM [-@subs]
;
EXEC sp_executesql @sql;
'
;
EXEC sp_executesql @GenCmd
, N'@command NVARCHAR(MAX), @from NVARCHAR(MAX), @find1 NVARCHAR(MAX), @find2 NVARCHAR(MAX), @find3 NVARCHAR(MAX)'
, @command, @from, @find1, @find2, @find3
;
 