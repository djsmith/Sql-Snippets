/*
Row counter in query
This query creates a row count column in a query. Additional examples use the Northwind database.

NOTE:  This is a controversial technique as it creates a triangular join forcing
the query engine to process multiple rows for each row in the record set.
http://www.sqlservercentral.com/articles/T-SQL/61539/

Newer versions of T-SQL (2008) has ranking functions for this kind of thing
see ROW_NUMBER() and others.
*/

-- Outer select statement shows what columns to display 
Select 
	/*
	Inner select statement counts the rows where the identity is 
	less than or equal to the current row from the outer select
	*/
	(Select Top 100 Percent Count(*) 
	From sysobjects soi
	Where soi.id <= sou.id 
		-- if a criteria is needed it must be in the inner and outer select statements
		And soi.xtype = 'P') As counter, 
	sou.*  
From sysobjects sou 
-- if a criteria is needed it must be in the inner and outer select statements
Where sou.xtype = 'P'
-- this query can only be sorted by the Identity column
Order by sou.id


USE Northwind
/*
Calculate row numbers based on the OrderID column. 
This technique is inefficient even if you have an index on 
orderid, because for each row, the number of index rows 
scanned is at least the result row number. For n rows in 
the table, SQL Server scans at least (1+n)/2*n index rows. 
*/
SELECT
  (SELECT COUNT(*)
  FROM dbo.Orders AS O2
  WHERE O2.orderid <= O1.orderid) AS rownum,
  OrderID, CONVERT(varchar(10), OrderDate, 120) AS OrderDate,
  EmployeeID, CustomerID, ShipVia
FROM dbo.Orders AS O1
ORDER BY orderid

/*
Calculate row numbers based on the OrderDate column, using OrderID as a tiebreaker
where France is the ShipCountry.
*/
SELECT
	(SELECT COUNT(*)
	FROM dbo.Orders AS O2
	WHERE (O2.OrderDate < O1.OrderDate
	OR (O2.OrderDate = O1.OrderDate
		AND O2.OrderID <= O1.OrderID))
	AND ShipCountry = 'France') AS RowNum,
	CONVERT(varchar(10), OrderDate, 120) AS OrderDate,
	OrderID, EmployeeID, CustomerID, ShipVia, ShipCountry
FROM dbo.Orders AS O1
WHERE ShipCountry = 'France'
ORDER BY OrderDate, OrderID

/*
Calculate row numbers partitioned by each Customer in the dataset.
To get reasonable performance, you need an index on custid and orderid. 
If c=number of customers and m=number of orders per customer (assuming 
an even distribution), the number of index rows SQL Server scans is 
at least c*(1+m)/2*m. 
*/
SELECT CustomerID,
  (SELECT COUNT(*)
  FROM dbo.Orders AS O2
  WHERE O2.CustomerID = O1.CustomerID
    AND O2.OrderID <= O1.OrderID) AS CustomerRowNum,
  OrderID, CONVERT(varchar(10), OrderDate, 120) AS OrderDate,
  EmployeeID, ShipVia
FROM dbo.Orders AS O1
ORDER BY CustomerID, OrderID
 