 /*
Optimising Server-Side Paging - Part I
By Paul White, 2010/04/26 
http://www.sqlservercentral.com/articles/paging/69892/

Introduction
It is common to need to access rows from a table or result set one page at a time, perhaps 
for display purposes.This short series of articles explores a number of optimisations that 
can be applied to the basic technique of using the ROW_NUMBER ranking function to identify 
the rows to return for a requested page.

This series does not include an introduction to the core method, since there are a number 
of good articles already on SQL Server Central which do this. An excellent explanation can 
be found in this article by regular columnist Jacob Sebastian.

This first article takes a close look at an optimisation that is useful when paging through 
a wide data set. The next parts in the series will cover optimisations for returning the 
total number of pages available, and implementing custom ordering.

For layout reasons, the code samples in this article are rendered as images. A full test 
script with additional annotations can be found in the Resources section at the end of this 
article.
*/

USE     master;
GO
-- ========================
-- Create the test database
-- ========================

-- Drop the test database if it exists from a previous run
IF      DB_ID(N'166DEB4B-D616-4D0B-B3C4-96B13F065FDA')
        IS NOT NULL
        DROP DATABASE [166DEB4B-D616-4D0B-B3C4-96B13F065FDA];
GO
-- Create a user database to run the tests
CREATE  DATABASE [166DEB4B-D616-4D0B-B3C4-96B13F065FDA];
GO
-- Ensure the database is at least 64MB
IF      EXISTS
        (
        SELECT  * 
        FROM    sys.master_files
        WHERE   name = N'166DEB4B-D616-4D0B-B3C4-96B13F065FDA'
        AND     size < 64 * 128
        )
BEGIN
        EXECUTE (
                '
                ALTER   DATABASE [166DEB4B-D616-4D0B-B3C4-96B13F065FDA]
                MODIFY  FILE (
                        NAME = [166DEB4B-D616-4D0B-B3C4-96B13F065FDA],
                        SIZE = 64 MB,
                        MAXSIZE = 256 MB,
                        FILEGROWTH = 64 MB);
                ');
END;

-- Ensure the database log is at least 64MB
IF      EXISTS
        (
        SELECT  * 
        FROM    sys.master_files
        WHERE   name = N'166DEB4B-D616-4D0B-B3C4-96B13F065FDA_log'
        AND     size <= 64 * 128
        )
BEGIN
        EXECUTE (
                '
                ALTER   DATABASE [166DEB4B-D616-4D0B-B3C4-96B13F065FDA]
                MODIFY  FILE (
                        NAME = [166DEB4B-D616-4D0B-B3C4-96B13F065FDA_log],
                        SIZE = 64 MB,
                        MAXSIZE = 256 MB,
                        FILEGROWTH = 64 MB);
                ');
END;
GO
-- Switch to the test database
USE     [166DEB4B-D616-4D0B-B3C4-96B13F065FDA];
GO
-- Prevent use of mixed extents
-- (minimizes fragmentation of the non-clustered index)
DBCC    TRACEON (1118);

GO
-- ========================
-- Conditional object drops
-- ========================

-- Drop the test table
IF      OBJECT_ID(N'dbo.Post', N'U')
        IS NOT NULL
        DROP TABLE dbo.Post;

-- Drop the test procedures
IF      OBJECT_ID(N'dbo.ClearCaches', N'P')
        IS NOT NULL
        DROP PROCEDURE dbo.ClearCaches;

IF      OBJECT_ID(N'dbo.FetchPage', N'P')
        IS NOT NULL
        DROP PROCEDURE dbo.FetchPage;

IF      OBJECT_ID(N'dbo.FetchPageKeySeek', N'P')
        IS NOT NULL
        DROP PROCEDURE dbo.FetchPageKeySeek;

IF      OBJECT_ID(N'dbo.ShowBufferPool', N'P')
        IS NOT NULL
        DROP PROCEDURE dbo.ShowBufferPool;

IF      OBJECT_ID(N'dbo.ShowPerformanceStats', N'P')
        IS NOT NULL
        DROP PROCEDURE dbo.ShowPerformanceStats;
GO
-- ============================
-- Table creation and data load
-- ============================

-- Create the test table
CREATE  TABLE dbo.Post
        (
        post_id     INTEGER IDENTITY NOT NULL,
        thread_id   INTEGER NOT NULL,
        member_id   INTEGER NOT NULL,
        create_dt   DATETIME NOT NULL,
        title       NVARCHAR(100) NOT NULL,
        body        NVARCHAR(2500) NOT NULL,
        
        CONSTRAINT  [PK dbo.Post post_id]
            PRIMARY KEY CLUSTERED (post_id)
            WITH (FILLFACTOR = 100)
        );
GO
-- Add 10,000 rows of random data
WITH    Numbers (n)
AS      (
        -- Sequential numbers from 1 to 10,000
        SELECT  TOP (10000)
                ROW_NUMBER() OVER (
                ORDER BY (SELECT 0))
        FROM    master.sys.columns C1,
                master.sys.columns C2,
                master.sys.columns C3
        )
INSERT  dbo.Post WITH (TABLOCKX)
        (thread_id, member_id, create_dt, title, body)
SELECT  -- pseudo-random entries
        thread_id = ABS(CHECKSUM(NEWID())) % 16 + 1,
        member_id = ABS(CHECKSUM(NEWID())) % 16384 + 1,
        create_dt = DATEADD(MINUTE, Numbers.n * 60, '20020901'),
        title = REPLICATE
                (
                NCHAR(RAND(CHECKSUM(NEWID())) * 26 + 65), 
                RAND(CHECKSUM(NEWID())) * 70 + 30
                ),
        body = REPLICATE
                (
                NCHAR(RAND(CHECKSUM(NEWID())) * 26 + 65), 
                RAND(CHECKSUM(NEWID())) * 1750 + 750
                )
FROM    Numbers;

-- Non-clustered index for the Key Seek method
CREATE  UNIQUE NONCLUSTERED INDEX
        [UQ dbo.Post post_id]
ON      dbo.Post (post_id ASC)
WITH    (
        FILLFACTOR = 100,
        MAXDOP = 1,
        ONLINE = OFF,
        SORT_IN_TEMPDB = ON
        );

-- Finished creating objects
DBCC    TRACEOFF (1118);
GO

-- =====================
-- Test 1 implementation
-- =====================
CREATE  PROCEDURE dbo.FetchPage
        @PageSize   BIGINT,
        @PageNumber BIGINT
AS
        -- Normal paging algorithm
        WITH    Paging
        AS      (
                -- Number the rows in ascending order of post_id
                SELECT  rn = 
                            ROW_NUMBER() OVER (
                            ORDER BY P.post_id ASC),
                        P.post_id,
                        P.thread_id,
                        P.member_id,
                        P.create_dt,
                        P.title,
                        P.body
                FROM    dbo.Post P
                )
        SELECT  -- Just fetch one page of rows
                TOP (@PageSize)
                PG.rn,
                PG.post_id,
                PG.thread_id,
                PG.member_id,
                PG.create_dt,
                PG.title,
                PG.body
        FROM    Paging PG
        WHERE   -- Read the minimim number of rows necessary
                PG.rn > (@PageNumber * @PageSize) - @PageSize
        ORDER   BY
                PG.rn ASC;
GO

-- =====================
-- Test 2 implementation
-- =====================
CREATE  PROCEDURE dbo.FetchPageKeySeek
        @PageSize   BIGINT,
        @PageNumber BIGINT
AS
BEGIN
        -- Key-Seek algorithm
        WITH    Keys
        AS      (
                -- Step 1 : Number the rows from the non-clustered index
                -- Maximum number of rows = @PageNumber * @PageSize
                SELECT  TOP (@PageNumber * @PageSize)
                        rn = ROW_NUMBER() OVER (ORDER BY P1.post_id ASC),
                        P1.post_id
                FROM    dbo.Post P1
                ORDER   BY
                        P1.post_id ASC
                ),
                SelectedKeys
        AS      (
                -- Step 2 : Get the primary keys for the rows on the page we want
                -- Maximum number of rows from this stage = @PageSize
                SELECT  TOP (@PageSize)
                        SK.rn,
                        SK.post_id
                FROM    Keys SK
                WHERE   SK.rn > ((@PageNumber - 1) * @PageSize)
                ORDER   BY
                        SK.post_id ASC
                )
        SELECT  -- Step 3 : Retrieve the off-index data
                -- We will only have @PageSize rows by this stage
                SK.rn,
                P2.post_id,
                P2.thread_id,
                P2.member_id,
                P2.create_dt,
                P2.title,
                P2.body
        FROM    SelectedKeys SK
        JOIN    dbo.Post P2
                ON  P2.post_id = SK.post_id
        ORDER   BY
                SK.post_id ASC;
END;
GO


-- ==================
-- Testing Procedures
-- ==================
CREATE  PROCEDURE dbo.ClearCaches
AS
BEGIN
        -- Write all dirty memory pages to disk
        CHECKPOINT;

        -- Clear the buffer pool (data cache)
        -- now only contains clean buffers
        DBCC DROPCLEANBUFFERS;

        -- Clear the other system caches
        DBCC FREESYSTEMCACHE ('ALL');
END;
GO


CREATE  PROCEDURE dbo.ShowPerformanceStats
        @ObjectName SYSNAME
AS
BEGIN
        -- Show performance statistics for a test run
        SELECT  name = OBJECT_NAME(QT.objectid),
                QT.[text],
                QS.total_physical_reads,
                QS.total_logical_reads,
                worker_time_ms = QS.total_worker_time / 1000,
                elapsed_time_ms = QS.total_elapsed_time / 1000
        FROM    sys.dm_exec_query_stats QS
        CROSS
        APPLY   sys.dm_exec_sql_text (QS.[sql_handle]) QT
        WHERE   OBJECT_NAME(QT.objectid) = @ObjectName;
END;
GO


CREATE  PROCEDURE dbo.ShowBufferPool
AS
BEGIN
        -- Shows a summary of cached data and index pages
        -- for the test table only
        SELECT  BUF.page_type,
                rows_in_cache = SUM(BUF.row_count), -- rows in cached pages
                buffer_pages = COUNT_BIG(*),        -- pages used
                memory_used_KB = COUNT_BIG(*) * 8   -- memory used (8KB per page)
        FROM    sys.objects OBJ
        JOIN    sys.partitions PART
                ON  PART.[object_id] = OBJ.[object_id]
        JOIN    sys.allocation_units AU
                ON  AU.type = 1
                AND AU.container_id = PART.partition_id
        JOIN    sys.dm_os_buffer_descriptors BUF
                ON  BUF.allocation_unit_id = AU.allocation_unit_id
        WHERE   database_id = DB_ID()
        AND     OBJ.name = N'Post'
        AND     OBJ.[schema_id] = SCHEMA_ID(N'dbo')
        AND     OBJ.type_desc = N'USER_TABLE'
        AND     BUF.page_type IN (N'DATA_PAGE', N'INDEX_PAGE')
        GROUP   BY
                BUF.page_type
        ORDER   BY
                BUF.page_type;
END;
GO

-- ==========
-- TEST START
-- ==========

    -- Test parameters
    DECLARE @PageNumber BIGINT,     -- Page number to fetch
            @PageSize   BIGINT;     -- Rows per page

    -----------------------------
    -- Set the test parameters --
    -----------------------------
    SET     @PageSize = 50;
    SET     @PageNumber = 10;

    SET     NOCOUNT ON;         -- Suppress 'x row(s) affected' messages
    DBCC    TRACEON (652);      -- Disable read-ahead

    -- Traditional method
    EXECUTE dbo.ClearCaches;
    EXECUTE dbo.FetchPage @PageSize, @PageNumber;
    EXECUTE dbo.ShowPerformanceStats N'FetchPage';
    EXECUTE dbo.ShowBufferPool;

    -- Key Seek method
    EXECUTE dbo.ClearCaches;
    EXECUTE dbo.FetchPageKeySeek @PageSize, @PageNumber;
    EXECUTE dbo.ShowPerformanceStats N'FetchPageKeySeek';
    EXECUTE dbo.ShowBufferPool;

    -- Allow read ahead again
    DBCC    TRACEOFF (652);

    -- Restore NOCOUNT
    SET     NOCOUNT OFF;

-- ==========
-- TEST END
-- ==========

GO
USE     master;
DROP    DATABASE [166DEB4B-D616-4D0B-B3C4-96B13F065FDA];
GO