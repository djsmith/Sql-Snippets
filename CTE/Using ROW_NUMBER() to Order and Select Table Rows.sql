/*
This script shows how to use the ROW_NUMBER() function and a CTE
to order rows in a table based on multiple columns then select
the rows with the highest value of those multiple columns for any
given "ProductID" field

http://www.sqlservercentral.com/articles/T-SQL/66512/
*/
use AdventureWorks;

--Create new table to store data
CREATE TABLE Production.ProductVersion
(
      ProductID int NOT NULL,
      Version int NOT NULL,
      MinorVersion int NOT NULL,
      ReleaseVersion int NOT NULL,
      StandardCost numeric(30, 4) NOT NULL,
      CONSTRAINT PK_ProductVersion PRIMARY KEY CLUSTERED 
      (
            ProductID ASC,
            Version ASC,
            MinorVersion ASC,
            ReleaseVersion ASC
      )
);

-- Insert data into new table based on data in the Production.ProductCostHistory table.
-- This CTE creates a row for every price change in a product and inserts that data
-- into the Production.ProductVersion table.
-- The query uses random numbers based on the NEWID() function to create the version numbers.
WITH ProductVersion
AS
(
   SELECT ProductID,
      1 AS Version,
      CAST((ABS(CHECKSUM(NEWID())) % 1001) AS INT) AS MinorVersion,
      CAST((ABS(CHECKSUM(NEWID())) % 20001) AS INT) AS ReleaseVersion,
      CAST(StandardCost  AS NUMERIC(30,4)) AS StandardCost
   FROM Production.ProductCostHistory WITH (NOLOCK)
   UNION ALL
   SELECT
      ProductID,
      ABS(CHECKSUM(NEWID())) % 3 AS Version,
      CAST((ABS(CHECKSUM(NEWID())) % 1001) AS INT) AS MinorVersion,
      CAST((ABS(CHECKSUM(NEWID())) % 20001) AS INT) AS ReleaseVersion,
      CAST((CAST(StandardCost  AS NUMERIC(30,4)) * 1.10) AS NUMERIC(30,4)) AS StandardCost
   FROM Production.ProductCostHistory WITH (NOLOCK)
   UNION ALL
   SELECT
      ProductID,
      ABS(CHECKSUM(NEWID())) % 5 AS Version,
      CAST((ABS(CHECKSUM(NEWID())) % 1001) AS INT) AS MinorVersion,
      CAST((ABS(CHECKSUM(NEWID())) % 20001) AS INT) AS ReleaseVersion,
      CAST((CAST(StandardCost  AS NUMERIC(30,4)) * 2.10) AS NUMERIC(30,4)) AS StandardCost
   FROM Production.ProductCostHistory WITH (NOLOCK)
)
INSERT INTO Production.ProductVersion
SELECT ProductID,
   Version,
   MinorVersion,
   ReleaseVersion,
   MAX(StandardCost) AS StandardCost
FROM ProductVersion
GROUP BY ProductID,
   Version,
   MinorVersion,
   ReleaseVersion;

-- Create a CTE to sort the table decending by Version, MinorVersion, and ReleaseVersion
-- columns and give each row a ROW_NUMBER() by ProductID.  This CTE is used by the 
-- Select query to return the rows with a MaxVersion column value of 1.
WITH RowExample1
AS
(
   SELECT ROW_NUMBER() OVER(PARTITION BY ProductID
                     ORDER BY ProductID,
                        Version DESC,
                        MinorVersion DESC,
                        ReleaseVersion DESC
      ) AS MaxVersion,
      ProductID,
      Version,
      MinorVersion,
      ReleaseVersion,
      StandardCost
   FROM Production.ProductVersion pv WITH (NOLOCK)
)
SELECT ProductID,
   Version,
   MinorVersion,
   ReleaseVersion,
   StandardCost
FROM RowExample1
WHERE MaxVersion = 1
ORDER BY ProductID;

-- Clean Up
if OBJECT_ID('Production.ProductVersion', 'U') is not null begin
	drop table Production.ProductVersion
end; 
