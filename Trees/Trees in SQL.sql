/************************************************************************
This code is taken from Joe Celko's article 'Trees in SQL' which is 
extracted from his book 'Sql for Smarties'
http://www.intelligententerprise.com/001020/celko.jhtml

The code demonstrates different ways of organizing trees 
	- adjacency list model (bad model)
	- nested sets (better model)

Other techniques include the path model, which can use the HierarchyID
data type in Sql Server 2008;
http://technet.microsoft.com/en-us/library/bb677290.aspx

NOTE: The code that converts an adjacency list model into a nested 
set model doesn't work properly

NOTE: I really don't think this code is 100% correct, some inserts don't
result in a properly ordered set of tree nodes.  
See the code \Trees\Adjacency List Model.sql for better examples
************************************************************************/
-- Drop any objects created in a previous run of the batch
IF OBJECT_ID('dbo.Employees') IS NOT NULL BEGIN
	DROP TABLE dbo.Employees
END
IF OBJECT_ID('dbo.Salaries') IS NOT NULL BEGIN
	DROP TABLE dbo.Salaries
END
IF OBJECT_ID('dbo.Tree') IS NOT NULL BEGIN
	DROP TABLE dbo.Tree
END
IF OBJECT_ID('dbo.Stack') IS NOT NULL BEGIN
	DROP TABLE dbo.Stack
END


/* For some reason intellisense won't work with a non dbo schema */
--IF SCHEMA_ID('Trees') IS NOT NULL BEGIN
--	DROP SCHEMA Trees
--END
--GO

--CREATE SCHEMA Trees AUTHORIZATION dbo
--GO

/*************************************************/
-- Create table for adjacency list model
CREATE TABLE dbo.Employees (
	emp CHAR(10) NOT NULL PRIMARY KEY,
	boss CHAR(10) DEFAULT NULL REFERENCES dbo.Employees(emp),
	salary DECIMAL(6,2) NOT NULL DEFAULT 100.00
);
GO

INSERT INTO dbo.Employees (emp, boss, salary)
VALUES 
	('Amy', NULL, 1000.00),
	('Bert', 'Amy', 900.00),
	('Chuck', 'Amy', 800.00),
	('Donna', 'Chuck', 700.00),
	('Eddie', 'Chuck', 600.00),
	('Fred', 'Chuck', 500.00)

-- Simple query with a recursive join to connect the employee's data with their boss's data
SELECT e.emp AS [Employee], b.emp AS [Boss], 
e.salary AS [EmployeeSalary], b.salary AS [BossSalary], b.salary- e.salary AS [SalaryDiff]
FROM dbo.Employees e
LEFT OUTER JOIN dbo.Employees b
ON e.boss = b.emp

/*
The problem with adjacent list model is that the table is 
demormalized in that the table is storing information about the 
employees and about the organizational structure.  It also
repeates alot of data. If for example 'Chuck' is replaced
by 'Chris' we have to update a lot of rows.  Another problem
is that the hiearchy does not adequately show levels of 
subordination. If Chuck is removed then Amy only has one
subordinate (Bert) while Donna, Eddie and Fred are removed
from the hiearchy.
*/

-- Clean up
IF OBJECT_ID('dbo.Employees') IS NOT NULL BEGIN
	DROP TABLE dbo.Employees
END

/*************************************************/
-- Create table for nested sets model.
--  The leftNode and rightNode column indicate the range of 
--	elements that are 
CREATE TABLE dbo.Employees (
	emp CHAR(10) NOT NULL PRIMARY KEY,
	leftNode INTEGER NOT NULL UNIQUE CHECK (leftNode >0),
	rightNode INTEGER NOT NULL UNIQUE CHECK (rightNode > 1),
	CONSTRAINT SetOrderCheck CHECK (leftNode < rightNode)
);
GO

CREATE TABLE dbo.Salaries (
	emp CHAR(10) NOT NULL PRIMARY KEY, 
	salary DECIMAL(6,2) NOT NULL DEFAULT 0.00
)

INSERT INTO dbo.Employees (emp, leftNode, rightNode)
VALUES 
	('Amy', 1, 12),
	('Bert', 2, 3),
	('Chuck', 4, 11),
	('Donna', 5, 6),
	('Eddie', 7, 8),
	('Fred', 9, 10)

INSERT INTO dbo.Salaries (emp, salary)
VALUES 
	('Amy', 1000.00),
	('Bert', 900.00),
	('Chuck', 800.00),
	('Donna', 700.00),
	('Eddie', 600.00),
	('Fred', 500.00)


-- Find an employee and all their supervisors no matter how deep the tree
DECLARE @emp CHAR(10) SET @emp = 'Eddie'
SELECT supervisors.*
FROM dbo.Employees, dbo.Employees supervisors
WHERE Employees.leftNode BETWEEN supervisors.leftNode AND supervisors.rightNode
	AND Employees.emp = @emp
ORDER BY supervisors.leftNode DESC

-- Find the employee and all their subordinates
SET @emp = 'Chuck'
SELECT Employees.*
FROM dbo.Employees, dbo.Employees supervisor
WHERE Employees.leftNode BETWEEN supervisor.leftNode AND supervisor.rightNode
	AND supervisor.emp = @emp
ORDER BY Employees.leftNode

-- Find the salary of each employee sumed with their subordinates
SELECT subordinates.emp, SUM(Salaries.salary) EmpAndSubordinateSalarySum
FROM dbo.Employees, dbo.Employees subordinates, dbo.Salaries
WHERE Employees.leftNode BETWEEN subordinates.leftNode AND subordinates.rightNode
	AND Employees.emp = Salaries.emp
GROUP BY subordinates.emp

-- Use Group By and Count aggregate to show the level in the hiearchy 
--	for each employee
SELECT COUNT(subordinates.emp) AS [LEVEL], Employees.emp
FROM Employees, Employees subordinates
WHERE Employees.leftNode BETWEEN subordinates.leftNode AND subordinates.rightNode
GROUP BY Employees.emp, Employees.leftNode
ORDER BY Employees.leftNode

-- Insert a new node as the rightmost sibling
-- Show the table before adding the new employee
SELECT * FROM Employees
BEGIN TRANSACTION
	SET @emp = 'Chuck'
	DECLARE @newNode INTEGER

	SELECT @newNode = rightNode
	FROM Employees 
	WHERE emp = @emp

	UPDATE Employees SET
		leftNode = CASE WHEN leftNode > @newNode THEN leftNode+2 ELSE leftNode END,
		rightNode = CASE WHEN rightNode >= @newNode THEN rightNode+2 ELSE rightNode END
	WHERE rightNode >= @newNode

	-- Corrected from the original article
	INSERT INTO Employees (emp, leftNode, rightNode)
	VALUES ('Gary', @newNode, @newNode+1)
	
	INSERT INTO Salaries (emp, salary)
	VALUES ('Gary', 400.00)
COMMIT TRANSACTION
-- Run the query again to show the new employee	
SELECT * FROM Employees

-- Converting a nested set model into a adjacency list model, which
--  matches the adjecent query shown above
select Employees.emp as Employee, supervisor.emp as Boss, 
EmpSalaries.salary as EmployeeSalary, BossSalaries.salary as BossSalary,
BossSalaries.salary - EmpSalaries.salary as SalaryDiff
from dbo.Employees
left outer join dbo.Employees supervisor
	on supervisor.leftNode = (select MAX(leftNode)
								from dbo.Employees subordinate
								where Employees.leftNode > subordinate.leftNode
									and Employees.leftNode < subordinate.rightNode)
inner join dbo.Salaries EmpSalaries
	on Employees.emp = EmpSalaries.emp
left outer join dbo.Salaries BossSalaries 
	on supervisor.emp = BossSalaries.emp
	
-- Clean up before next set of queries
IF OBJECT_ID('dbo.Employees') IS NOT NULL BEGIN
	DROP TABLE dbo.Employees
END
IF OBJECT_ID('dbo.Salaries') IS NOT NULL BEGIN
	DROP TABLE dbo.Salaries
END

/**********************************************************	
Converting an adjacency list model into a nested set model
by using a push down stack algorithm	

NOTE: This code doesn't work properly, but I can't figure
out what is wrong.  It doesn't get the LeftNode setting right
**********************************************************/
-- Create an adjacency list model table (same as above)
CREATE TABLE dbo.Tree (
	Emp CHAR(10) NOT NULL PRIMARY KEY,
	Boss CHAR(10) DEFAULT NULL REFERENCES dbo.Tree(Emp)
);
GO

INSERT INTO dbo.Tree (Emp, Boss)
VALUES 
	('Amy', NULL),
	('Bert', 'Amy'),
	('Chuck', 'Amy'),
	('Donna', 'Chuck'),
	('Eddie', 'Chuck'),
	('Fred', 'Chuck')

select * from dbo.Tree

-- Create a table to hole the nested set model
CREATE TABLE dbo.Stack (
	StackTop INTEGER NOT NULL,
	Emp CHAR(10) NOT NULL,
	LeftNode INTEGER,
	RightNode INTEGER
);
GO

-- First must drop or disable the recursive reference in the tree table
declare @name sysname
set @name = (select constraint_name 
			from INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE
			where TABLE_SCHEMA = 'dbo'
				and TABLE_NAME = 'Tree'
				and COLUMN_NAME = 'Boss')
				
if (OBJECT_ID(@name) is not null) begin
	declare @sql nvarchar(1000)
	set @sql = N'alter table [Tree] drop constraint [' + @name + ']'
	exec sp_executesql @sql
end


BEGIN TRANSACTION
	DECLARE @Counter INTEGER;
	DECLARE @Max INTEGER;
	DECLARE @Current INTEGER;
	SET @Counter = 2;
	SET @Max = 2 * (SELECT COUNT(*) FROM Tree);
	SET @Current = 1;

	INSERT INTO Stack
	SELECT 1, emp, 1, NULL
	FROM Tree
	WHERE boss IS NULL;

	DELETE FROM Tree
	WHERE boss IS NULL;

	WHILE @Counter <= (@Max - 2) BEGIN
		IF EXISTS (SELECT * FROM Stack AS S1, Tree AS T1 WHERE S1.emp = T1.boss AND S1.StackTop = @Current) BEGIN
			-- push when top has subordinates, set LeftNode value
			INSERT INTO Stack
			SELECT (@Current + 1), MIN(T1.emp), @Counter, NULL
			FROM Stack AS S1, Tree AS T1
			WHERE S1.emp = T1.boss
			AND S1.StackTop = @Current;
			DELETE FROM Tree
			WHERE emp = (SELECT emp
			FROM Stack
			WHERE StackTop = @Current + 1);
			SET @Counter = @Counter + 1;
			SET @Current = @Current + 1;
		END
		ELSE
		BEGIN -- pop the stack and set RightNode value
			UPDATE Stack
			SET RightNode = @Counter,
			StackTop = -StackTop -- pops the stack
			WHERE StackTop = @Current
			SET @Counter = @Counter + 1;
			SET @Current = @Current - 1;
		END
	END

COMMIT TRANSACTION


select * from dbo.Tree
select * from dbo.Stack

-- Clean up
IF OBJECT_ID('dbo.Employees') IS NOT NULL BEGIN
	DROP TABLE dbo.Employees
END
IF OBJECT_ID('dbo.Salaries') IS NOT NULL BEGIN
	DROP TABLE dbo.Salaries
END
IF OBJECT_ID('dbo.Tree') IS NOT NULL BEGIN
	DROP TABLE dbo.Tree
END
IF OBJECT_ID('dbo.Stack') IS NOT NULL BEGIN
	DROP TABLE dbo.Stack
END


--IF SCHEMA_ID('Trees') IS NOT NULL BEGIN
--	DROP SCHEMA Trees
--END
--GO

/*************************************************/
