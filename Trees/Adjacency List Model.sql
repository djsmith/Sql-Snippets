/**********************************************************************
This script is based on the Managing Hierarchical Data in MySQL
by Mike Hillyer, and demonstrates the Adjacency List model of
creating a tree hierarchy in databases.
http://dev.mysql.com/tech-resources/articles/hierarchical-data.html

The article was originally written for MySql but I made minor syntax
changes for Sql Server 2008.

-------------------------------------------------------------------
The Adjacency List model is limited by many factors, while the
Nested Set model provides a better solution.  From the above article 
about the Adjacency List model:
	Working with the adjacency list model in pure SQL can be difficult at 
	best. Before being able to see the full path of a category we have to 
	know the level at which it resides. In addition, special care must be 
	taken when deleting nodes because of the potential for orphaning an 
	entire sub-tree in the process (delete the portable electronics category 
	and all of its children are orphaned). Some of these limitations can 
	be addressed through the use of client-side code or stored procedures. 
	With a procedural language we can start at the bottom of the tree and 
	iterate upwards to return the full tree or a single path. We can also 
	use procedural programming to delete nodes without orphaning entire 
	sub-trees by promoting one child element and re-ordering the remaining 
	children to point to the new parent.

***********************************************************************/

IF OBJECT_ID('dbo.Category') IS NOT NULL BEGIN
	DROP TABLE dbo.Category
END

CREATE TABLE Category(
	CategoryId INT IDENTITY (1,1) PRIMARY KEY,
	Name VARCHAR(20) NOT NULL,
	Parent INT DEFAULT NULL
);

INSERT INTO Category
VALUES
	('Electronics',NULL),
	('Televisions',1),
	('Tube',2),
	('LCD',2),
	('Plasma',2),
	('Portable Electronics',1),
	('MP3 Players',6),
	('Flash',7),
	('CD Players',6),
	('2 Way Radios',6);

SELECT * FROM Category ORDER BY CategoryId;

-- This query shows a grid of each level in the hierarchy.
-- This is awkward because we need to know ahead of time how
-- many levels there are to construct the query.  Also, with
-- each join made to the query, performance degrades
SELECT t1.name AS lev1, t2.name as lev2, t3.name as lev3, t4.name as lev4
FROM category AS t1
LEFT JOIN category AS t2 ON t2.parent = t1.CategoryId
LEFT JOIN category AS t3 ON t3.parent = t2.CategoryId
LEFT JOIN category AS t4 ON t4.parent = t3.CategoryId
WHERE t1.name = 'ELECTRONICS';

-- This query shows all leaf nodes, that is all nodes without
-- any children
SELECT t1.Name 
FROM Category AS t1 
LEFT JOIN category as t2
	ON t1.CategoryId = t2.Parent
WHERE t2.CategoryId IS NULL;

-- This query shows the levels in the hierarchy for a single
-- leaf node at the end of the tree. Again this is awkward 
SELECT t1.name AS lev1, t2.name as lev2, t3.name as lev3, t4.name as lev4
FROM category AS t1
LEFT JOIN category AS t2 ON t2.parent = t1.CategoryId
LEFT JOIN category AS t3 ON t3.parent = t2.CategoryId
LEFT JOIN category AS t4 ON t4.parent = t3.CategoryId
WHERE t4.name = 'FLASH';

IF OBJECT_ID('dbo.Category') IS NOT NULL BEGIN
	DROP TABLE dbo.Category
END
