/****************************************************
This code demonstrates a hybrid hierarchical model that 
combines the Adjacent List and the Nested Sets models.
This is taken from an article by GSquared;
http://www.sqlservercentral.com/articles/T-SQL/65540/

The goal is to have a hierarchy as useful as Nested Sets 
but without the maintenance overhead that can cause
performance problems with rapidly changing hierarchies.

The technique improves performance when doing inserts
updates and deletes to the hieararchy by skipping the
RangeStart and RangeEnd fields which contain the nested
set data and relying on the ParentID field to form
a standard adjencency list.

Then a job is run every few minutes that walks the
ID/ParentID adjencency list and creates values for the
TempRangeStart and TempRangeEnd field, which then 
batch updates the RangeStart and RangeEnd fields.

Unfortunately the batch job code ins't included in the
article.  Also there is no test data.
****************************************************/

if OBJECT_ID('dbo.HierarchyHybrid') is not null begin
	drop table dbo.HierarchyHybrid
end
 
-- Table for storeing the hybrid hierarchy
CREATE TABLE dbo.HierarchyHybrid (
	ID INT IDENTITY PRIMARY KEY,
	Name VARCHAR(100),
	-- Null when the root node
	ParentID INT NULL REFERENCES dbo.HierarchyHybrid(ID),
	TopParentID INT NULL REFERENCES dbo.HierarchyHybrid(ID),
	-- Range fields are left as null when row is inserted
	RangeStart INT NULL,
	RangeEnd INT NULL,
	TempRangeStart INT NULL,
	TempRangeEnd INT NULL,
	CONSTRAINT CK_RangeValid CHECK (RangeStart < RangeEnd)
);
GO

/************************************
Need test data for hieararchy table
************************************/
declare @NodeID_in INT
WITH
TopSet (SS, SE) AS -- Get the range for the requested node
	(SELECT RangeStart, RangeEnd
	FROM dbo.HierarchyHybrid
	WHERE ID = @NodeID_in),
SETS (RangeStart, RangeEnd, NodeID) as-- Nested Sets QuerY
	(SELECT RangeStart, RangeEnd, ID
	FROM dbo.HierarchyHybrid
	inner join TopSet
		ON RangeStart BETWEEN ss AND se
		AND RangeEnd BETWEEN ss AND se),
Adjacency (NodeID, ParentID) AS -- Adjacency Query
	(SELECT ID, ParentID
	FROM dbo.HierarchyHybrid
	WHERE ID = @NodeID_in
	and exists
		(SELECT*
		FROM dbo.HierarchyHybrid h2
		WHERE h2.TopParentID = HierarchyHybrid.TopParentID
		AND RangeStart IS NULL)
	UNION ALL
	SELECT h3.ID, h3.ParentID
	FROM dbo.HierarchyHybrid h3
	inner join Adjacency
		ON h3.ParentID = Adjacency.NodeID)

SELECT NodeID
FROM SETS
UNION
SELECT NodeID
FROM Adjacency;

-- The above query written out as a table function
/*
CREATE FUNCTION [dbo].[udf_Hierarchy] (
	@NodeID_in INT)
RETURNS TABLE
AS
RETURN
	(WITH
	TopSet (SS, SE) AS -- Get the range for the requested node
		(SELECT RangeStart, RangeEnd
		FROM dbo.HierarchyHybrid
		WHERE ID = @NodeID_in),
	SETS (RangeStart, RangeEnd, NodeID) as-- Nested Sets QuerY
		(SELECT RangeStart, RangeEnd, ID
		FROM dbo.HierarchyHybrid
		inner join TopSet
			ON RangeStart BETWEEN ss AND se
			AND RangeEnd BETWEEN ss AND se),
	Adjacency (NodeID, ParentID) AS -- Adjacency Query
		(SELECT 0, ID, ParentID
		FROM dbo.HierarchyHybrid
		WHERE ID = @NodeID_in
		and exists
			(SELECT*
			FROM dbo.HierarchyHybrid h2
			WHERE h2.TopParentID = HierarchyHybrid.TopParentID
			AND RangeStart IS NULL)
		UNION ALL
		SELECT h3.ID, h3.ParentID
		FROM dbo.HierarchyHybrid h3
		inner join Adjacency
			ON h3.ParentID = Adjacency.NodeID)
	SELECT NodeID
	FROM SETS
	UNION
	SELECT NodeID
	FROM Adjacency);
GO
*/

if OBJECT_ID('dbo.HierarchyHybrid') is not null begin
	drop table dbo.HierarchyHybrid
end
