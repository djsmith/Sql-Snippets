/**********************************************************************
This script is based on the Managing Hierarchical Data in MySQL
by Mike Hillyer, which demonstrates the Nested Set model for 
hierarchies in databases as an improvement over the Adjacency 
List model.
http://dev.mysql.com/tech-resources/articles/hierarchical-data.html

The article was originally written for MySql but I made minor syntax
changes for Sql Server 2008.

**********************************************************************/

IF OBJECT_ID('tempdb..#Categories') IS NOT NULL BEGIN
	DROP TABLE #Categories
END
IF OBJECT_ID('dbo.Categories') IS NOT NULL BEGIN
	DROP TABLE dbo.Categories
END
IF OBJECT_ID('dbo.Product') IS NOT NULL BEGIN
	DROP TABLE dbo.Product
END

-- Create a table for the Categories hierarchy. The hierarchy
--  can be created in a separate table with a forign key
--  relation to the entity, and a hierarchy can be considered
--  a different domain entity from the entities being put into
--  a hierarchy.
CREATE TABLE Categories (
	CategoryId INT IDENTITY(1,1) PRIMARY KEY,
	Name VARCHAR(20) NOT NULL,
	LeftNode INT NOT NULL,
	RightNode INT NOT NULL
);

-- Insert values into table, mix up the order just for the demonstration
--  and make sure none of the queries rely on the CategoryId field
--  (which probably shouldn't even be in the table).
INSERT INTO Categories
VALUES
	('2 Way Radios',17,18),
	('Electronics',1,20),
	('Plasma',7,8),
	('Tube',3,4),
	('CD Players',15,16),
	('Portable Electronics',10,19),
	('MP3 Players',11,14),
	('Televisions',2,9),
	('Flash',12,13),
	('LCD',5,6);

--GOTO a

SELECT * FROM Categories ORDER BY CategoryId

-- Retrieve the full tree starting with the root node ordered by the left node
--  NOTE: does the root of a nested set always have a LeftNode value of 1?
SELECT node.Name
FROM Categories AS node, Categories AS parent
WHERE node.LeftNode BETWEEN parent.LeftNode AND parent.RightNode
	AND parent.LeftNode = 1
ORDER BY node.LeftNode;

-- Retrieve all leaf nodes (nodes without children) by 
-- testing if the left and right node columns have a difference of 1
SELECT Name
FROM Categories
WHERE RightNode = LeftNode + 1;

-- Retrieve the path for a single node
SELECT parent.name
FROM Categories AS node, Categories AS parent
WHERE node.LeftNode BETWEEN parent.LeftNode AND parent.RightNode
	AND node.name = 'Flash'
ORDER BY parent.LeftNode;

-- Alternative way to output the path for a single node
DECLARE @Path VARCHAR(8000)
--Select @Path = IsNull(@Path + '", "', '"') + Code From CT_State Order By Code
SELECT @Path = ISNULL(@Path + '\', '') + parent.Name
FROM Categories AS node, Categories AS parent
WHERE node.LeftNode BETWEEN parent.LeftNode AND parent.RightNode
	AND node.name = 'Flash'
ORDER BY parent.LeftNode;
SELECT @Path AS NodePath;

-- Finding the level of each node
SELECT COUNT(parent.Name) AS [LEVEL], node.Name
FROM Categories AS node,
Categories AS parent
WHERE node.LeftNode BETWEEN parent.LeftNode AND parent.RightNode
GROUP BY node.name, node.LeftNode
ORDER BY node.LeftNode;

-- Using the level of each node to format the output
SELECT COUNT(parent.Name) AS [LEVEL], LTRIM(REPLICATE('-', COUNT(parent.Name)-1) + ' ' + node.Name) AS Name
FROM Categories AS node,
Categories AS parent
WHERE node.LeftNode BETWEEN parent.LeftNode AND parent.RightNode
GROUP BY node.name, node.LeftNode
ORDER BY node.LeftNode;

-- Finding the level of a sub-tree.  This requires using a sub-query to 
--  define the subset of records we want to show, executed within a
--  query of the full tree
SELECT node.Name, COUNT(parent.Name) AS FullTreeLevel, (COUNT(parent.Name) - sub_tree.[LEVEL] + 1) AS SubTreeLevel
FROM Categories AS node,
	Categories AS parent,
	Categories AS sub_parent,
	(
		SELECT node.Name, (COUNT(parent.Name)) AS [LEVEL]
		FROM Categories AS node,
		Categories AS parent
		WHERE node.LeftNode BETWEEN parent.LeftNode AND parent.RightNode
		AND node.Name = 'Portable Electronics'
		GROUP BY node.Name
	)AS sub_tree
WHERE node.LeftNode BETWEEN parent.LeftNode AND parent.RightNode
	AND node.LeftNode BETWEEN sub_parent.LeftNode AND sub_parent.RightNode
	AND sub_parent.Name = sub_tree.Name
GROUP BY node.Name, node.LeftNode, sub_tree.[LEVEL]
ORDER BY node.LeftNode;

-- Simple query to get a node and all of it's subordinate nodes
SELECT node.Name
FROM Categories AS node,
	Categories AS parent
WHERE node.LeftNode BETWEEN parent.LeftNode AND parent.RightNode
AND parent.Name = 'Portable Electronics'
ORDER BY node.LeftNode

-- More complicated query to get a node and all of it's subordinate nodes
-- including showing the sub-tree's level.
-- To exclude the selected node and only show the subordinate nodes 
-- change the HAVING clause to: > 1
SELECT node.Name, COUNT(parent.Name) AS FullTreeLevel, (COUNT(parent.Name) - sub_tree.[LEVEL] + 1) AS SubTreeLevel
FROM Categories AS node,
	Categories AS parent,
	Categories AS sub_parent,
	(
		SELECT node.Name, (COUNT(parent.Name)) AS [LEVEL]
		FROM Categories AS node,
		Categories AS parent
		WHERE node.LeftNode BETWEEN parent.LeftNode AND parent.RightNode
		AND node.Name = 'Portable Electronics'
		GROUP BY node.Name
	)AS sub_tree
WHERE node.LeftNode BETWEEN parent.LeftNode AND parent.RightNode
	AND node.LeftNode BETWEEN sub_parent.LeftNode AND sub_parent.RightNode
	AND sub_parent.Name = sub_tree.Name
GROUP BY node.Name, node.LeftNode, sub_tree.[LEVEL]
HAVING (COUNT(parent.Name) - sub_tree.[LEVEL] + 1) > 1
ORDER BY node.LeftNode;


/************* Aggregates with Nested Sets ***************************/

a:

-- Create a table for products so we can do some aggregate queries
CREATE TABLE Product(
	ProductId INT IDENTITY(1,1) PRIMARY KEY,
	Name VARCHAR(40),
	CategoryId INT NOT NULL
);


INSERT INTO Product(Name, CategoryId) 
VALUES
	('20" TV',3),
	('36" TV',3),
	('Super-LCD 42"',4),
	('Ultra-Plasma 62"',5),
	('Value Plasma 38"',5),
	('Power-MP3 5gb',7),
	('Super-Player 1gb',8),
	('Porta CD',9),
	('CD To go!',9),
	('Family Talk 360',10);

--GOTO b
SELECT * FROM product;

-- Lists the categories and the cumulative product count in the categories
SELECT Categories.Name, Counts.ProductCount 
FROM Categories
INNER JOIN (
	SELECT parent.CategoryId, COUNT(product.Name) AS ProductCount
	FROM Categories AS node,
		Categories AS parent,
		Product
	WHERE node.LeftNode BETWEEN parent.LeftNode AND parent.RightNode
		AND node.CategoryId = product.CategoryId
	GROUP BY parent.CategoryId
) AS Counts
	ON Categories.CategoryId = Counts.CategoryId
ORDER BY Categories.LeftNode;

b:

/*********** Adding items to nested sets **********************/
-- Here we add a new node to the Categories table between Televisions
-- and Portable Electronics.  That it the new node is a sibling of 
-- Televisions and Portable Electronics and a child of Electronics.

-- Store the Categories table before the insert
CREATE TABLE #Categories (
	CategoryId INT PRIMARY KEY,
	Name VARCHAR(20) NOT NULL,
	LeftNode INT NOT NULL,
	RightNode INT NOT NULL
);
INSERT INTO #Categories
SELECT * FROM Categories

-- Get the right node value from the left side sibling
DECLARE @NewNode INTEGER 
SELECT @NewNode = RightNode FROM Categories
WHERE Name = 'Televisions';

-- Wrap the whole thing in a transaction
BEGIN TRANSACTION
	-- Make room in the node sets for the new node by increasing the values where needed
	UPDATE Categories SET RightNode = RightNode + 2 WHERE RightNode > @NewNode
	UPDATE Categories SET LeftNode = LeftNode + 2 WHERE LeftNode > @NewNode

	INSERT INTO Categories (Name, LeftNode, RightNode)
	VALUES ('Game Consoles', @NewNode+1, @NewNode+2)
COMMIT TRANSACTION

--GOTO c

-- Compare the table before and after
SELECT Categories.*, 
#Categories.CategoryId AS OldId, #Categories.Name AS OldName, #Categories.LeftNode AS OldLeft, #Categories.RightNode AS OldRight
FROM Categories
FULL JOIN #Categories
ON Categories.CategoryId = #Categories.CategoryId
ORDER BY Categories.LeftNode;

-- Show the new data along with the level of the categories
SELECT COUNT(parent.Name) AS [LEVEL], node.Name
FROM Categories AS node,
Categories AS parent
WHERE node.LeftNode BETWEEN parent.LeftNode AND parent.RightNode
GROUP BY node.name, node.LeftNode
ORDER BY node.LeftNode;

c:

-- Add another new node as a child of a node that currently has no children.
-- Here we get the left node of the intended parent node for the new node
SELECT @NewNode = LeftNode FROM Categories
WHERE Name='2 Way Radios'

-- Wrap the whole thing in a transaction
BEGIN TRANSACTION
	-- The rest of the steps are the same; make room for the new node 
	UPDATE Categories SET RightNode = RightNode + 2 WHERE RightNode > @NewNode
	UPDATE Categories SET LeftNode = LeftNode + 2 WHERE LeftNode > @NewNode

	INSERT INTO Categories(Name, LeftNode, RightNode)
	VALUES ('FRS', @NewNode+1, @NewNode+2)
COMMIT TRANSACTION

--GOTO d

-- Compare the new data in the Categories table to the original
SELECT Categories.*, 
#Categories.CategoryId AS OldId, #Categories.Name AS OldName, #Categories.LeftNode AS OldLeft, #Categories.RightNode AS OldRight
FROM Categories
FULL JOIN #Categories
ON Categories.CategoryId = #Categories.CategoryId
ORDER BY Categories.LeftNode;

-- Show the new data along with the level of the categories
SELECT COUNT(parent.Name) AS [LEVEL], node.Name
FROM Categories AS node,
Categories AS parent
WHERE node.LeftNode BETWEEN parent.LeftNode AND parent.RightNode
GROUP BY node.name, node.LeftNode
ORDER BY node.LeftNode;

d:
/************** Deleting nodes from nested sets ***********/
-- Here we delete a node that is a leaf node with no children
DECLARE @DeadLeftNode INTEGER,
	@DeadRightNode INTEGER,
	@DeadWidth INTEGER

-- Get the locations of the node to be deleted
SELECT @DeadLeftNode = LeftNode, @DeadRightNode = RightNode, @DeadWidth = RightNode - LeftNode + 1
FROM Categories
WHERE Name = 'Game Consoles'

-- Wrap the whole thing in a transaction
BEGIN TRANSACTION
	DELETE FROM Categories WHERE LeftNode BETWEEN @DeadLeftNode AND @DeadRightNode
	
	-- Compact the node	values for the removed node
	UPDATE Categories SET RightNode = RightNode - @DeadWidth WHERE RightNode > @DeadRightNode
	UPDATE Categories SET LeftNode = LeftNode - @DeadWidth WHERE LeftNode > @DeadLeftNode
COMMIT TRANSACTION

--GOTO e

-- Compare the new data in the Categories table to the original, now 
-- Game Consoles should be removed from the table, just like the original 
SELECT Categories.*, 
#Categories.CategoryId AS OldId, #Categories.Name AS OldName, #Categories.LeftNode AS OldLeft, #Categories.RightNode AS OldRight
FROM Categories
FULL JOIN #Categories
ON Categories.CategoryId = #Categories.CategoryId
ORDER BY Categories.LeftNode;

e:

-- Another example where we delete a node and all of it's children
-- Here we delete the MP3 Players node which will also delete the Flash node
SELECT @DeadLeftNode = LeftNode, @DeadRightNode = RightNode, @DeadWidth = RightNode - LeftNode + 1
FROM Categories
WHERE Name = 'MP3 Players'

BEGIN TRANSACTION
	DELETE FROM Categories WHERE LeftNode BETWEEN @DeadLeftNode AND @DeadRightNode

	UPDATE Categories SET RightNode = RightNode - @DeadWidth WHERE RightNode > @DeadRightNode
	UPDATE Categories SET LeftNode = LeftNode - @DeadWidth WHERE LeftNode > @DeadLeftNode
COMMIT TRANSACTION

--GOTO f

-- Comapre the changes to the original
SELECT Categories.*, 
#Categories.CategoryId AS OldId, #Categories.Name AS OldName, #Categories.LeftNode AS OldLeft, #Categories.RightNode AS OldRight
FROM Categories
FULL JOIN #Categories
ON Categories.CategoryId = #Categories.CategoryId
ORDER BY Categories.LeftNode;

f:

-- Now we want to delete a node but not delete any of the node's childres
-- and instead assign the children to the deleted node's parent
SELECT @DeadLeftNode = LeftNode, @DeadRightNode = RightNode, @DeadWidth = RightNode - LeftNode + 1
FROM Categories
WHERE Name = 'Portable Electronics'

BEGIN TRANSACTION
	-- Only delete a single node instead of a range of nodes
	DELETE FROM Categories WHERE LeftNode = @DeadLeftNode
	
	-- update the children of the deleted node to be assigned to that node's parent
	UPDATE Categories SET LeftNode = LeftNode - 1, RightNode = RightNode - 1 WHERE LeftNode BETWEEN @DeadLeftNode AND @DeadRightNode
	
	-- update the other nodes to the right of the deleted node to account for the deleted node
	UPDATE Categories SET RightNode = RightNode - 2 WHERE RightNode > @DeadRightNode
	UPDATE Categories SET LeftNode = LeftNode - 2 WHERE LeftNode > @DeadRightNode

COMMIT TRANSACTION

-- Comapre the changes to the original
SELECT Categories.*, 
#Categories.CategoryId AS OldId, #Categories.Name AS OldName, #Categories.LeftNode AS OldLeft, #Categories.RightNode AS OldRight
FROM Categories
FULL JOIN #Categories
ON Categories.CategoryId = #Categories.CategoryId
ORDER BY Categories.LeftNode;

z:

IF OBJECT_ID('tempdb..#Categories') IS NOT NULL BEGIN
	DROP TABLE #Categories
END
IF OBJECT_ID('dbo.Categories') IS NOT NULL BEGIN
	DROP TABLE dbo.Categories
END
IF OBJECT_ID('dbo.Product') IS NOT NULL BEGIN
	DROP TABLE dbo.Product
END
