/*
This procedure lists top tables by their size (row count, space reserved/used 
and index size), while also displaying the number of dependant objects of 
each table. This is providing an important hint about the table, because 
"big tables" might only be some kind of dumps of data, let's say images 
(lots of disk space), or some tally tables (lots of rows) etc. But knowing 
that one particular table is used in some views or stored procedures, one can 
more accurately narrow their focus.

Author: Gregor Borosa
http://www.sqlservercentral.com/articles/Data+Quality/65326/

*/

DECLARE @Id int   
DECLARE @Pages int   
DECLARE @Used dec(15)
DECLARE @TableName sysname

CREATE TABLE #spt_space (
	objid int not null,
	rows int null,
	reserved dec(15) null,
	data dec(15) null,
	indexp dec(15) null,
	unused dec(15) null,
	dependants int null
)

CREATE TABLE #tDepends (
	oType smallint, 
	oobjname sysname, 
	oowner varchar(50), 
	osequence smallint
)

SET NOCOUNT ON

--loop through user tables
DECLARE c_TABLEs CURSOR STATIC FORWARD_ONLY READ_ONLY
	FOR SELECT ID FROM sysobjects WHERE xtype = 'U'
OPEN c_TABLEs
FETCH NEXT FROM c_TABLEs INTO @Id
WHILE @@FETCH_STATUS = 0
BEGIN
	/* : from sp_spaceused */
	INSERT INTO #spt_space (objid, reserved)
	SELECT objid = @Id, SUM(reserved) FROM sysindexes WHERE indid in (0, 1, 255) AND id = @Id
	SELECT @Pages = SUM(dpages) FROM sysindexes WHERE indid < 2 AND id = @Id
	SELECT @Pages = @Pages + ISNULL(SUM(used), 0) FROM sysindexes WHERE indid = 255 AND id = @Id

	UPDATE #spt_space
		SET data = @Pages
		WHERE objid = @Id

	SET @Used = (SELECT SUM(used) FROM sysindexes WHERE indid in (0, 1, 255) AND id = @Id)

	UPDATE #spt_space
		SET indexp = @Used - data
		WHERE objid = @Id

	UPDATE #spt_space
		SET unused = reserved - @Used
		WHERE objid = @Id

	UPDATE #spt_space
		SET rows = i.rows FROM sysindexes i 
		WHERE i.indid < 2 AND i.id = @Id AND objid = @Id

	--You will receive the error below which is from sp_msdependencies using dump tran.
	-- Server: Msg 3021, Level 16, State 1, Line 1 -- Cannot perform a backup or restore operation within a transaction.
	-- Server: Msg 3013, Level 16, State 1, Line 1 -- BACKUP LOG is terminating abnormally.
    SET @TableName = (SELECT '['+SCHEMA_NAME(schema_id)+'].['+name+']' AS SchemaTable FROM sys.tables WHERE object_id=@Id)
	INSERT INTO #tDepends EXEC sp_MSdependencies @TableName, null, 1315327	

	UPDATE #spt_space
		SET dependants = (SELECT COUNT(*) FROM #tDepends)
	--USE this if you rely on sysdepends table or don't want errror from sp_MSdependencies, but covers less dependencies.
		--SET dependants = (
		--	SELECT COUNT(DISTINCT o.name) 
		--	FROM sysobjects o, master.dbo.spt_values v, sysdepends d 
		--	WHERE o.id = d.id and o.xtype = SUBSTRING(v.name,1,2) COLLATE database_default and v.type = 'O9T' AND d.depid = @Id and deptype < 2
		--)
	WHERE objid = @Id 
	TRUNCATE TABLE #tDepends
	FETCH NEXT FROM c_TABLEs INTO @Id
END

SELECT TOP 25
	[Table] = (SELECT '['+SCHEMA_NAME(schema_id)+'].['+name+']' AS SchemaTable FROM sys.tables WHERE object_id=objid),
	rows,
	[Reserved KB] = STR(reserved * d.low / 1024.) + ' ' + 'KB',
	[Data Percent] = STR(data / nullif(reserved,0) * 100) + ' %',
	[Index Percent] = STR(indexp / nullif(reserved,0) * 100) + ' %',
	[Unused Percent] = STR(unused/nullif(reserved,0) * 100) + ' %',
	Dependants
FROM  #spt_space, master.dbo.spt_values d
WHERE	d.number = 1
	AND  d.type = 'E' --page size
ORDER BY rows DESC

DROP TABLE #spt_space
DROP TABLE #tDepends
CLOSE c_TABLEs
DEALLOCATE c_TABLEs
GO

 