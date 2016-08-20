/*  This is an aid in estimating, the accuracy of this script is not guarenteed or implied.

In database planning and design it is essential to plan out how much HD space you are going 
to need to store your data. If you use BOL and do a search for "Estimating Table Size" you 
get three articles:
- Estimating the size of a table
- Estimating the size of a table with a Clustered Index
- Estimating the size of a table without a Clustered Index
These articles cover step by step how to estimate how much space your table's data and indexes 
are going to utilize. The problem; they aren't translated into T-SQL so the calculation is manual.

The UDFs installed with this script automate the calculation. All you need to do is create your 
table and its indexes and execute the fnTableSize function which returns the number of bytes 
used for the table's data, the table's indexes, and the total table size.

Function usage:
Select * from dbo.fnTableSize (
	'[Name of table]',
	[Number of rows to be stored],
	[Percentage of variable data types filled]
)

Note: @rVarPercentUsed refers to the average amount of data stored in variable fields. For 
example if a varchar(40), on average, contains 20 characters the @rVarPercentUsed is 50.

*/


IF EXISTS (Select * from sysobjects where id = OBJECT_ID(N'fnTableDataSize'))
	DROP FUNCTION fnTableDataSize

GO

CREATE FUNCTION dbo.fnTableDataSize (@vcTableName VARCHAR(255),@rTableRows REAL,@rVarPercentageUsed REAL)
	RETURNS REAL
	
AS

BEGIN
	SET @rVarPercentageUsed = @rVarPercentageUsed / 100

	IF EXISTS(Select * from sysobjects where id = OBJECT_ID(@vcTableName))
	BEGIN
		DECLARE @rFixedColumns REAL
		DECLARE @rVariableColumns REAL
		DECLARE @rTotalColumns REAL
		
		DECLARE @rFixedDataSize REAL
		DECLARE @rMaxVarSize REAL
		DECLARE @rVarDataSize REAL
		DECLARE @rNullBitmap REAL
		
		DECLARE @rBytesPerRow REAL
		DECLARE @rRowsPerPage REAL
		DECLARE @rNumPages REAL
	
		DECLARE @rTableBytes REAL
		DECLARE @rTableKBytes REAL
		DECLARE @rTableMBytes REAL
		DECLARE @rTableGBytes REAL
		
		DECLARE @rFreeRowsPerPage REAL
		DECLARE @rFillFactor REAL
	
		SET @rFixedColumns = (select count(*) from syscolumns sc INNER JOIN systypes st ON sc.xtype = st.xtype Where sc.id = OBJECT_ID(@vcTableName) and st.variable = 0)
		SET @rFixedDataSize = (select sum(sc.length) from syscolumns sc INNER JOIN systypes st ON sc.xtype = st.xtype Where sc.id = OBJECT_ID(@vcTableName) and st.variable = 0)
		SET @rNullBitmap = ROUND(2 + ((@rFixedColumns + 7) / 8),0,1)
	
		SET @rVariableColumns = (select count(*) from syscolumns sc INNER JOIN systypes st ON sc.xtype = st.xtype Where sc.id = OBJECT_ID(@vcTableName) and st.variable = 1)
		SET @rMaxVarSize = (Select SUM(sc.length) from syscolumns sc INNER JOIN systypes st ON sc.xtype = st.xtype where sc.id = OBJECT_ID(@vcTableName) and st.Variable = 1)
	
		IF @rVariableColumns = 0 
			SET @rVarDataSize = 0
		ELSE
			SET @rVarDataSize = (2 + (@rVariableColumns * 2) + @rMaxVarSize) * @rVarPercentageUsed
		
		SET @rBytesPerRow = @rFixedDataSize + @rVarDataSize + @rNullBitmap + 4
		IF 8096 / (@rBytesPerRow + 2) < 1
			SET @rRowsPerPage = CEILING(8096 / (@rBytesPerRow + 2))
		ELSE
			SET @rRowsPerPage = FLOOR(8096 / (@rBytesPerRow + 2))

		SET @rFillFactor = 100
	
		IF EXISTS(select * from sysindexes where id = OBJECT_ID(@vcTableName) and INDEXPROPERTY(OBJECT_ID(@vcTableName),name,'IsClustered') = 1)
			SET @rFillFactor = (select INDEXPROPERTY(OBJECT_ID(@vcTableName),name,'IndexFillFactor') from sysindexes where id = OBJECT_ID(@vcTableName) and INDEXPROPERTY(OBJECT_ID(@vcTableName),name,'IsClustered') = 1)
		
		IF @rFillFactor = 0 SET @rFillFactor = 100
	
		SET @rFreeRowsPerPage = CEILING(8096 * ((100 - @rFillFactor) / 100) / (@rBytesPerRow + 2))
		SET @rNumPages = CEILING(@rTableRows / (@rRowsPerPage - @rFreeRowsPerPage))
		
		SET @rTableBytes = 8192 * @rNumPages
	END
	ELSE
	BEGIN
		RETURN -1
	END

	RETURN @rTableBytes
END

GO

IF EXISTS(Select * from sysobjects where id = OBJECT_ID(N'fnTableIndexSize'))
	DROP FUNCTION fnTableIndexSize

GO

CREATE FUNCTION dbo.fnTableIndexSize (@vcTableName VARCHAR(255),@rDataSize REAL,@rTableRows REAL,@rVarPercentageUsed REAL)
	RETURNS REAL
	
AS

BEGIN
	DECLARE @vcIndexName VARCHAR(255)
	
	DECLARE @rFixedColumns REAL
	DECLARE @rFixedCKeySize REAL
	DECLARE @rNullBitmap REAL

	DECLARE @rVarColumns REAL
	DECLARE @rMaxVarSize REAL
	DECLARE @rVarCKeySize REAL

	DECLARE @rCIndexRowSize REAL
	DECLARE @rCIndexRowsPerPage REAL

	DECLARE @rCLevel0 REAL
	DECLARE @rCLevel1 REAL
	DECLARE @rCLevel2 REAL
   DECLARE @rPrevCLevel REAL
   DECLARE @rCurCLevel REAL
   DECLARE @rCumCLevel REAL
	DECLARE @rCIndexPages REAL

	DECLARE @tblIndexes TABLE (iRowId INT IDENTITY(1,1),vcIndexName VARCHAR(255))
	DECLARE @iRowId INT
	DECLARE @iRowCount INT

	DECLARE @rNLIndexRowSize REAL
	DECLARE @rNLIndexRowsPerPage REAL

	DECLARE @rLIndexRowSize REAL
	DECLARE @rLIndexRowsPerPage REAL

	DECLARE @rLFreeIndexRowsPerPage REAL
	DECLARE @rFillFactor REAL

	DECLARE @rLLevel0 REAL
	DECLARE @rLLevel1 REAL
	DECLARE @rLLevel2 REAL
   DECLARE @rPrevLLevel REAL
   DECLARE @rCurLLevel REAL
   DECLARE @rCumLLevel REAL
	DECLARE @rLIndexPages REAL

	DECLARE @rCIndexBytes REAL
	DECLARE @rNIndexBytes REAL
	DECLARE @rTotalIndexBytes REAL
	
	DECLARE @rIndexRowSize REAL
	DECLARE @rIndexRowsPerPage REAL
	DECLARE @rFreeIndexRowsPerPage REAL
	DECLARE @rIndexPages REAL
	DECLARE @rIndexBytes REAL

	SET @rVarPercentageUsed = @rVarPercentageUsed / 100

	IF EXISTS(Select * from sysindexes where id = OBJECT_ID(@vcTableName) and INDEXPROPERTY(OBJECT_ID(@vcTableName),name,'IsClustered') = 1)
	BEGIN
		SET @vcIndexName = (Select name from sysindexes where id = OBJECT_ID(@vcTableName) and INDEXPROPERTY(OBJECT_ID(@vcTableName),name,'IsClustered') = 1)
		
		SET @rFixedColumns = (Select count(*) from sysobjects so 
						INNER JOIN sysindexes si ON so.id = si.id 
						INNER JOIN sysindexkeys sk ON so.id = sk.id and sk.indid = si.indid 
						INNER JOIN syscolumns sc on so.id = sc.id and sc.colorder = sk.colid and si.id = sc.id 
					Where sc.id = OBJECT_ID(@vcTableName) 
					and si.name = @vcIndexName)

		SET @rFixedCKeySize = (Select IsNull(sum(sc.length),0) From sysobjects so 
						INNER JOIN sysindexes si ON so.id = si.id 
						INNER JOIN sysindexkeys sk ON so.id = sk.id and sk.indid = si.indid 
						INNER JOIN syscolumns sc ON sc.id = so.id and sc.colorder = sk.colid and si.id = sc.id 
					WHERE sc.id = OBJECT_ID(@vcTableName) 
					and si.name = @vcIndexName 
					and sc.xtype in (select xtype from systypes where variable = 0))

		SET @rNullBitmap = ROUND(2 + ((@rFixedColumns + 7) / 8),0,1)
		
		SET @rVarColumns = (Select count(*) from sysobjects so INNER JOIN sysindexes si ON so.id = si.id
						INNER JOIN sysindexkeys sk ON so.id = sk.id and sk.indid = si.indid
						INNER JOIN syscolumns sc ON sc.id = so.id and sc.colorder = sk.colid and si.id = sc.id
					WHERE sc.id = OBJECT_ID(@vcTableName)
					and si.name = @vcIndexName
					and sc.xtype in (select xtype from systypes where variable = 1))
		
		SET @rMaxVarSize = (Select IsNull(sum(length),0) From sysobjects so INNER JOIN sysindexes si ON so.id = si.id
						INNER JOIN sysindexkeys sk ON so.id = sk.id and sk.indid = si.indid
						INNER JOIN syscolumns sc ON sc.id = so.id and sc.colorder = sk.colid and si.id = sc.id
					WHERE sc.id = OBJECT_ID(@vcTableName)
					and si.name = @vcIndexName
					and sc.xtype in (select xtype from systypes where variable = 1))
		
		IF @rVarColumns = 0 
			SET @rVarCKeySize = 0
		ELSE
			SET @rVarCKeySize = (2 + (@rVarColumns * 2) + @rMaxVarSize) * @rVarPercentageUsed

		SET @rCIndexRowSize = @rFixedCKeySize + @rVarCKeySize + @rNullBitmap + 1 + 8
		IF (8096 / (@rCIndexRowSize + 2)) < 1
			SET @rCIndexRowsPerPage = CEILING(8096 / (@rCIndexRowSize + 2))
		ELSE
			SET @rCIndexRowsPerPage = FLOOR(8096 / (@rCIndexRowSize + 2))

		SET @rCLevel0 = CEILING((@rDataSize / 8192) / @rCIndexRowsPerPage)
		SET @rCLevel1 = CEILING(@rCLevel0 / @rCIndexRowsPerPage)
		SET @rCLevel2 = CEILING(@rCLevel1 / @rCIndexRowsPerPage)
		
		SET @rPrevCLevel = @rCLevel2
		SET @rCurCLevel = @rPrevCLevel
		
		WHILE @rCurCLevel > 1
		BEGIN
			SET @rCurCLevel = CEILING(@rPrevCLevel / @rCIndexRowsPerPage)
			SET @rCumCLevel = IsNull(@rCumCLevel,0) + @rCurCLevel
			SET @rPrevCLevel = @rCurCLevel
		END
		
		SET @rCIndexPages = @rCLevel0 + @rCLevel1 + @rCLevel2 + IsNull(@rCumCLevel,0)
		SET @rCIndexBytes = 8192 * @rCIndexPages

		INSERT INTO @tblIndexes Select name from sysindexes where id = OBJECT_ID(@vcTableName) and INDEXPROPERTY(OBJECT_ID(@vcTableName),name,'IsClustered') = 0 and INDEXPROPERTY(OBJECT_ID(@vcTableName),name,'IsHypothetical') = 0 and INDEXPROPERTY(OBJECT_ID(@vcTableName),name,'IsAutoStatistics') = 0
		SET @iRowId = @@ROWCOUNT
	
		WHILE @iRowId > 0 
		BEGIN
			SET @vcIndexName = (Select vcIndexName from @tblIndexes where iRowId = @iRowId)
	
			SET @rFixedColumns = (Select count(*) from sysobjects so 
							INNER JOIN sysindexes si ON so.id = si.id 
							INNER JOIN sysindexkeys sk ON so.id = sk.id and sk.indid = si.indid 
							INNER JOIN syscolumns sc on so.id = sc.id and sc.colorder = sk.colid and si.id = sc.id 
						Where sc.id = OBJECT_ID(@vcTableName) 
						and si.name = @vcIndexName)
	
			SET @rFixedCKeySize = (Select IsNull(sum(sc.length),0) From sysobjects so 
							INNER JOIN sysindexes si ON so.id = si.id 
							INNER JOIN sysindexkeys sk ON so.id = sk.id and sk.indid = si.indid 
							INNER JOIN syscolumns sc ON sc.id = so.id and sc.colorder = sk.colid and si.id = sc.id 
						WHERE sc.id = OBJECT_ID(@vcTableName) 
						and si.name = @vcIndexName 
						and sc.xtype in (select xtype from systypes where variable = 0))
	
			SET @rNullBitmap = ROUND(2 + ((@rFixedColumns + 7) / 8 ),0,1)
	
			SET @rVarColumns = (Select count(*) from sysobjects so INNER JOIN sysindexes si ON so.id = si.id
							INNER JOIN sysindexkeys sk ON so.id = sk.id and sk.indid = si.indid
							INNER JOIN syscolumns sc ON sc.id = so.id and sc.colorder = sk.colid and si.id = sc.id
						WHERE sc.id = OBJECT_ID(@vcTableName)
						and si.name = @vcIndexName
						and sc.xtype in (select xtype from systypes where variable = 1))
			
			SET @rMaxVarSize = (Select IsNull(sum(length),0) From sysobjects so INNER JOIN sysindexes si ON so.id = si.id
							INNER JOIN sysindexkeys sk ON so.id = sk.id and sk.indid = si.indid
							INNER JOIN syscolumns sc ON sc.id = so.id and sc.colorder = sk.colid and si.id = sc.id
						WHERE sc.id = OBJECT_ID(@vcTableName)
						and si.name = @vcIndexName
						and sc.xtype in (select xtype from systypes where variable = 1))
			
			IF @rVarColumns = 0 
				SET @rVarCKeySize = 0
			ELSE
				SET @rVarCKeySize = (2 + (@rVarColumns * 2) + @rMaxVarSize) * @rVarPercentageUsed
	
			SET @rNLIndexRowSize = @rFixedCKeySize + @rVarCKeySize + @rNullBitmap + 1 + 8
			IF 8096 / (@rNLIndexRowSize + 2) < 1
				SET @rNLIndexRowsPerPage  = CEILING(8096 / (@rNLIndexRowSize + 2))
			ELSE
				SET @rNLIndexRowsPerPage  = FLOOR(8096 / (@rNLIndexRowSize + 2))
	
			SET @rLIndexRowSize = @rCIndexRowSize + @rFixedCKeySize + @rVarCKeySize + @rNullBitmap + 1
			IF 8096 / (@rLIndexRowSize + 2) < 1
				SET @rLIndexRowsPerPage = CEILING(8096 / (@rLIndexRowSize + 2))
			ELSE
				SET @rLIndexRowsPerPage = FLOOR(8096 / (@rLIndexRowSize + 2))

			SET @rFillFactor = 100
			IF EXISTS(select * from sysindexes where id = OBJECT_ID(@vcTableName) and name = @vcIndexName)
				SET @rFillFactor = (select INDEXPROPERTY(OBJECT_ID(@vcTableName),name,'IndexFillFactor') from sysindexes where id = OBJECT_ID(@vcTableName) and name = @vcIndexName)
			IF @rFillFactor = 0 SET @rFillFactor = 100	
			
			IF 8096 * ((100 - @rFillFactor) / 100) / @rLIndexRowsPerPage < 1
				SET @rLFreeIndexRowsPerPage = CEILING(8096 * ((100 - @rFillFactor) / 100) / @rLIndexRowsPerPage)
			ELSE
				SET @rLFreeIndexRowsPerPage = FLOOR(8096 * ((100 - @rFillFactor) / 100) / @rLIndexRowsPerPage)
			
			SET @rLLevel0 = CEILING(@rTableRows / (@rLIndexRowsPerPage - @rLFreeIndexRowsPerPage))
			SET @rLLevel1 = CEILING(@rLLevel0 / @rNLIndexRowsPerPage)
			SET @rLLevel2 = CEILING(@rLLevel1 / @rNLIndexRowsPerPage)
	
			SET @rPrevLLevel = @rLLevel2
			SET @rCurLLevel = @rPrevLLevel
	
			WHILE @rCurLLevel > 1
			BEGIN
				SET @rCurLLevel = CEILING(@rPrevLLevel / @rNLIndexRowsPerPage)
				SET @rCumLLevel = IsNull(@rCumLLevel,0) + @rCurLLevel
				SET @rPrevLLevel = @rCurLLevel
			END
	
			SET @rLIndexPages = @rLLevel0 + @rLLevel1 + @rLLevel2 + IsNull(@rCumLLevel,0)
	
			SET @rNIndexBytes = IsNull(@rNIndexBytes,0) + (8192 * @rLIndexPages)
	
			SET @iRowId = @iRowId - 1
		END

		SET @rTotalIndexBytes = @rNIndexBytes + @rCIndexBytes
		
	END
	ELSE
	BEGIN
		INSERT INTO @tblIndexes Select name from sysindexes where id = OBJECT_ID(@vcTableName) and INDEXPROPERTY(OBJECT_ID(@vcTableName),name,'IsClustered') = 0 and INDEXPROPERTY(OBJECT_ID(@vcTableName),name,'IsHypothetical') = 0 and INDEXPROPERTY(OBJECT_ID(@vcTableName),name,'IsAutoStatistics') = 0
		SET @iRowId = @@ROWCOUNT
	
		WHILE @iRowId > 0 
		BEGIN
			SET @vcIndexName = (Select vcIndexName from @tblIndexes where iRowId = @iRowId)
			
			SET @rFixedColumns = (Select count(*) from sysobjects so 
							INNER JOIN sysindexes si ON so.id = si.id 
							INNER JOIN sysindexkeys sk ON so.id = sk.id and sk.indid = si.indid 
							INNER JOIN syscolumns sc on so.id = sc.id and sc.colorder = sk.colid and si.id = sc.id 
						Where sc.id = OBJECT_ID(@vcTableName) 
						and si.name = @vcIndexName)
	
			SET @rFixedCKeySize = (Select IsNull(sum(sc.length),0) From sysobjects so 
							INNER JOIN sysindexes si ON so.id = si.id 
							INNER JOIN sysindexkeys sk ON so.id = sk.id and sk.indid = si.indid 
							INNER JOIN syscolumns sc ON sc.id = so.id and sc.colorder = sk.colid and si.id = sc.id 
						WHERE sc.id = OBJECT_ID(@vcTableName) 
						and si.name = @vcIndexName 
						and sc.xtype in (select xtype from systypes where variable = 0))
	
			SET @rNullBitmap = ROUND(2 + ((@rFixedColumns + 7) / 8 ),0,1)
	
			SET @rVarColumns = (Select count(*) from sysobjects so INNER JOIN sysindexes si ON so.id = si.id
							INNER JOIN sysindexkeys sk ON so.id = sk.id and sk.indid = si.indid
							INNER JOIN syscolumns sc ON sc.id = so.id and sc.colorder = sk.colid and si.id = sc.id
						WHERE sc.id = OBJECT_ID(@vcTableName)
						and si.name = @vcIndexName
						and sc.xtype in (select xtype from systypes where variable = 1))
			
			SET @rMaxVarSize = (Select IsNull(sum(length),0) From sysobjects so INNER JOIN sysindexes si ON so.id = si.id
							INNER JOIN sysindexkeys sk ON so.id = sk.id and sk.indid = si.indid
							INNER JOIN syscolumns sc ON sc.id = so.id and sc.colorder = sk.colid and si.id = sc.id
						WHERE sc.id = OBJECT_ID(@vcTableName)
						and si.name = @vcIndexName
						and sc.xtype in (select xtype from systypes where variable = 1))
			
			IF @rVarColumns = 0 
				SET @rVarCKeySize = 0
			ELSE
				SET @rVarCKeySize = (2 + (@rVarColumns * 2) + @rMaxVarSize) * @rVarPercentageUsed

			SET @rIndexRowSize = @rFixedCKeySize + @rVarCKeySize + @rNullBitmap + 1 + 8
			IF 8096 / (@rIndexRowSize + 2) < 1
				SET @rIndexRowsPerPage = CEILING(8096 / (@rIndexRowSize + 2))
			ELSE
				SET @rIndexRowsPerPage = FLOOR(8096 / (@rIndexRowSize + 2))

			SET @rFillFactor = 100
			IF EXISTS(select * from sysindexes where id = OBJECT_ID(@vcTableName) and name = @vcIndexName)
				SET @rFillFactor = (select INDEXPROPERTY(OBJECT_ID(@vcTableName),name,'IndexFillFactor') from sysindexes where id = OBJECT_ID(@vcTableName) and name = @vcIndexName)
			IF @rFillFactor = 0 SET @rFillFactor = 100	
			
			IF 8096 * ((100 - @rFillFactor) / 100) / @rIndexRowsPerPage < 1
				SET @rFreeIndexRowsPerPage = CEILING(8096 * ((100 - @rFillFactor) / 100) / @rIndexRowsPerPage)
			ELSE
				SET @rFreeIndexRowsPerPage = FLOOR(8096 * ((100 - @rFillFactor) / 100) / @rIndexRowsPerPage)
			
			SET @rCLevel0 = CEILING(@rTableRows / (@rIndexRowsPerPage - @rFreeIndexRowsPerPage))
			SET @rCLevel1 = CEILING(@rCLevel0 / @rIndexRowsPerPage)

			SET @rPrevCLevel = @rCLevel1
			SET @rCurCLevel = @rPrevCLevel
			
			WHILE @rCurCLevel > 1
			BEGIN
				SET @rCurCLevel = CEILING(@rPrevCLevel / @rIndexRowsPerPage)
				SET @rCumCLevel = IsNull(@rCumCLevel,0) + @rCurCLevel
				SET @rPrevCLevel = @rCurCLevel
			END
			
			SET @rIndexPages = @rCLevel0 + @rCLevel1 + @rCLevel2 + IsNull(@rCumCLevel,0)
			SET @rIndexBytes = 8192 * @rIndexPages
			
			SET @rTotalIndexBytes = IsNull(@rTotalIndexBytes,0) + @rIndexBytes

			SET @iRowId = @iRowId - 1
		END
	END
	RETURN @rTotalIndexBytes
END

GO

IF EXISTS(Select * from sysobjects where id = OBJECT_ID('fnTableSize'))
	DROP FUNCTION fnTableSize

GO

CREATE FUNCTION dbo.fnTableSize (@vcTableName VARCHAR(255),@rTableRows REAL = 0,@rVarPercentUsed REAL)
	RETURNS @tblTableSize TABLE (vcTableName VARCHAR(255),rTableRows REAL,rDataSize REAL,rIndexSize REAL,rTableSize REAL)
	
AS

BEGIN
	DECLARE @rDataSize REAL
	DECLARE @rIndexSize REAL
	DECLARE @rTableSize REAL

	SET @rDataSize = (select dbo.fnTableDataSize(@vcTableName,@rTableRows,@rVarPercentUsed))
	SET @rIndexSize = (select dbo.fnTableIndexSize(@vcTableName,@rDataSize,@rTableRows,@rVarPercentUsed))
	SET @rTableSize = (@rDataSize + @rIndexSize)

	INSERT INTO @tblTableSize (vcTableName,rTableRows,rDataSize,rIndexSize,rTableSize)
		VALUES (@vcTableName,@rTableRows,@rDataSize,@rIndexSize,@rTableSize)

	RETURN
END

GO

 