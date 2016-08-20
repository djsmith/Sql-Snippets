/*
Script:		Ordering database tables in SQL Server 2005

Purpose:	This script defines a 'level' for each 
		table that's involved in a relationship
		so that porting such tables by ascending level 
		will not violate referential integrity during
		data ports.

Note:		The tables tblPreorder and tblAnswer must
		not exist in the database (otherwise, rename
		them or use table variables).  Ditto for the
		value of @TableName below.  

http://www.sqlservercentral.com/articles/Database+Design/66071/
*/

-- No counting
SET NOCOUNT ON

-- Declarations
DECLARE @Level		INT
DECLARE @NumTables	INT
DECLARE @TableName	VARCHAR(255)

-- Arbitrarily set the name of a fictional table. 
-- This is used to insure that each table is 'less than' 
-- at least one table in the loop below (so we create a 
-- fictional one and later delete it from the answer).  
-- With this in place, the script can avoid awkward, 
-- special cases.
SET @TableName = 'Z'

-- Determine the number of tables.
-- This number is used to bound the maximum value of @Level. 
SET @NumTables = (SELECT COUNT(*) from dbo.sysobjects WHERE OBJECTPROPERTY(id, N'IsUserTable') = 1)

-- Drop preorder and answer tables
IF (SELECT TABLE_NAME FROM information_schema.tables WHERE TABLE_NAME = 'tblPreorder') IS NOT NULL
	DROP TABLE tblPreorder
IF (SELECT TABLE_NAME FROM information_schema.tables WHERE TABLE_NAME = 'tblAnswer') IS NOT NULL
	DROP TABLE tblAnswer

-- Create a preorder table using the database 
-- relationships between tables.  By definition,
-- a table A will be 'less than' a table B if 
-- B has a foreign key pointing to A.
SELECT A, B
INTO tblPreorder
FROM
(
SELECT
-- May be multiple relationships between two 
-- tables but we only need one
DISTINCT	
so1.name as B,
so2.name as A
FROM
sys.foreign_key_columns fk INNER JOIN
sys.objects so1 ON fk.parent_object_id = so1.object_id INNER JOIN
sys.objects so2 ON fk.referenced_object_id = so2.object_id INNER JOIN
sys.objects so3 ON fk.constraint_object_id = so3.object_id
) derived
ORDER BY A, B

-- Delete rows in preorder table involving pair of tables
-- that are less than each other, including self-joins.
-- Such pairs of tables are unlikely but it can happen if 
-- they're empty (and they'll always remain so).
-- Formally:
-- Delete rows R1 in preorder table 
-- where 
-- R1(A) = R2(B) and R1(B) = R2(A)
-- for some (possibly the same) row R2 
DELETE 
tblPreorder 
FROM
tblPreorder
INNER JOIN 
(
SELECT 
t1.A, 
t1.B 
FROM 
tblPreorder t1 INNER JOIN 
tblPreorder t2 ON 
t1.A = t2.B AND 
t1.B = t2.A
) derived
on 
tblPreorder.A = derived.A
and
tblPreorder.B = derived.B

-- Add the fictional table to the preorder.
-- For every table not less than some other table in the 
-- preorder, add an 'arrow' from it to the fictional table.
-- That way, every non-fictional table is now less than 
-- some other table (possibly fictional).
INSERT INTO 
tblPreorder(A,B)
SELECT DISTINCT 
B AS A, 
@TableName AS B
FROM tblPreorder
WHERE
B NOT IN (
SELECT A FROM tblPreorder
)

-- Create answer table
CREATE TABLE tblAnswer(
[Level]	INT,
A		VARCHAR(256)
)

-- Insert into answer table those tables that aren't 
-- less than any other table in the preorder.
-- Otherwise, they'll get missed in the loop below.
-- Of course, this will just be the fictional table.
-- Choose @NumTables as the level, since the levels of all 
-- other tables will have to be smaller, as a subsequent
-- recursive loop will show.
INSERT INTO tblAnswer(Level,A)
(
SELECT DISTINCT @NumTables AS 'Level', B
FROM tblPreorder
WHERE
B NOT IN (
SELECT A FROM tblPreorder
)
)

-- Recursively add tables in column A of preorder table 
-- to answer table if they don't appear anywhere in column B 
-- of preorder table, while deleting the rows of the preorder
-- table in which they appeared (so we don't do this again). 
-- Note that the fictional table guarantees that those
-- other tables not less than any other won't be prematurely 
-- dropped by the above deletions, preventing them
-- from eventually joining the answer table.
-- Furthermore, each table is added to the answer
-- table as soon as no table is less than it after
-- such deletions (just-in-time sequencing).
-- Increment the table level for each pass,
-- which cannot exceed the number of tables minus 1
-- since we're starting from 0.
SET @Level = 0
WHILE (SELECT COUNT(*) FROM tblPreorder) > 0
	BEGIN

	-- Add tables
	INSERT INTO tblAnswer(Level,A)
	(
	SELECT  @Level AS 'Level',A
	FROM tblPreorder
	WHERE
	A NOT IN (
	SELECT B FROM tblPreorder
	)
	)

	-- Delete them
	DELETE
	FROM tblPreorder
	WHERE
	A NOT IN (
	SELECT B FROM tblPreorder
	)

	-- Increment table level
	SET @Level = @Level + 1

	END

-- Delete fictional table from answer table
DELETE
tblAnswer
WHERE
A = @TableName

-- Display answer
SELECT DISTINCT * FROM tblAnswer

-- Drop tables
DROP TABLE tblPreorder
DROP TABLE tblAnswer
