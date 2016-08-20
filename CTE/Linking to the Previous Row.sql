 /*
This demonstrates using a common table expression (CTE) to effectively
create a temporary table that can be used in a select statement, joining
to itself so each row can refer to the previous and the next row as needed.

This example creates a PriceHistory table that shows the previous price, 
the new price, and the date range that the new price was valid, before being 
replaced with an even newer price.

http://www.sqlservercentral.com/articles/T-SQL/62159/
By David McKinney
*/

-- Wrap the entire thing in a transaction and rollback at the end to clean up
BEGIN TRAN

-- temp data of Items and Prices that change over time
create table #Items (
	Id int,
	Item varchar(20))
	
create table #Prices (
	ItemId int,
	PriceStartDate date,
	Price money)
	
insert into #Items (Id, Item)
values
	(1,'vaccum cleaner'),
	(2,'washing machine'),
	(3,'toothbrush')
	
insert into #Prices (ItemId, PriceStartDate, Price)
values 
	(1,'2004-03-01',250.00),
	(1,'2005-06-15',219.99),
	(1,'2007-01-03',189.99),
	(1,'2007-02-03',200.00),
	(2,'2006-07-12',650.00),
	(2,'2007-01-03',550.00),
	(3,'2005-01-01',1.99),
	(3,'2006-01-01',1.79),
	(3,'2007-01-01',1.59),
	(3,'2008-01-01',1.49)

--select * from #Items
--select * from #Prices


--CTE creates table with row numbers showing the items and 
-- how the price changed over time
;WITH PriceCompare AS (
SELECT i.Item, ph.ItemId, ph.PriceStartDate, ph.Price,
ROW_NUMBER() OVER (Partition BY ph.ItemId ORDER BY PriceStartDate) AS rownum 
FROM #Items i INNER JOIN #Prices ph 
ON i.Id = ph.ItemId) 

--SELECT * FROM PriceCompare 

--Select statement that joins the PriceCompare table to itself using
-- the row number column plus and minus 1 to join to the previous and 
-- next row.  This allows the query to get the OldPrice from the 
-- previous row and the EndDate from the next row for each item.
SELECT currow.Item, prevrow.Price AS OldPrice, currow.Price AS RangePrice, currow.PriceStartDate AS StartDate, nextrow.PriceStartDate AS EndDate 
FROM PriceCompare currow 
LEFT JOIN PriceCompare nextrow 
	ON currow.rownum = nextrow.rownum - 1
		AND currow.ItemId = nextrow.ItemId
LEFT JOIN PriceCompare prevrow
	ON currow.rownum = prevrow.rownum + 1
		AND currow.ItemId = prevrow.ItemId

ROLLBACK