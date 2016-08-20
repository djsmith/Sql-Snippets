 
USE [AdventureWorks]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[Person].[pAddressPaging]') AND type in (N'P', N'PC'))
DROP PROCEDURE [Person].[pAddressPaging]
GO

CREATE PROCEDURE Person.pAddressPaging (
      @SortCol NVARCHAR(25)='AddressID ASC',
      @City NVARCHAR(30)=NULL,
      @StateProvinceCode NCHAR(3)=NULL,
      @pgSize INT=25,
      @pgNbr INT=1
)
AS
BEGIN
 
/*==================================================
 I use the below code to get the total number of rows. If you do not need this functionality,
 you can remove this section of code and remove @NbrPages in the SELECT statements.
 
 Author: Adam Haines
 http://www.sqlservercentral.com/articles/SQL+Server+2005/65256/
==================================================*/
DECLARE @NbrPages INT

If (@pgSize is null) begin set @pgSize = 25 end
If (@pgNbr is null) begin set @pgNbr = 1 end

IF @City IS NULL AND @StateProvinceCode IS NULL
BEGIN
SELECT @NbrPages = CEILING(count(*)/(@pgSize*1.0))
FROM [Person].[Address] a
END
 
IF @City IS NOT NULL AND @StateProvinceCode IS NULL
BEGIN
SELECT @NbrPages = CEILING(count(*)/(@pgSize*1.0))
FROM [Person].[Address] a
WHERE a.City = @City
END
 
IF @City IS NULL AND @StateProvinceCode IS NOT NULL
BEGIN
SELECT @NbrPages = CEILING(count(*)/(@pgSize*1.0))
FROM [Person].[Address] a
Inner Join [Person].[StateProvince] s on a.StateProvinceID = s.StateProvinceID
WHERE s.StateProvinceCode = @StateProvinceCode
END
 
IF @City IS NOT NULL AND @StateProvinceCode IS NOT NULL
BEGIN
SELECT @NbrPages = CEILING(count(*)/(@pgSize*1.0))
FROM [Person].[Address] a
Inner Join [Person].[StateProvince] s on a.StateProvinceID = s.StateProvinceID
WHERE s.StateProvinceCode = @StateProvinceCode
	and a.City = @City
END
 
--NO filters, this will always TABLE/INDEX scan
IF @City IS NULL AND @StateProvinceCode IS NULL
BEGIN
 
      ;WITH PagingCTE (Row_ID,AddressId,City,StateProvinceCode)
      AS
      (
      SELECT
            ROW_NUMBER()
            OVER(ORDER BY
             CASE WHEN @SortCol='City DESC' THEN City END DESC,
             CASE WHEN @SortCol='City ASC'  THEN City END ASC,
             CASE WHEN @SortCol='StateProvinceCode ASC'   THEN StateProvinceCode  END ASC,
             CASE WHEN @SortCol='StateProvinceCode DESC'  THEN StateProvinceCode  END DESC,
             CASE WHEN @SortCol='AddressId ASC'  THEN AddressId END ASC,
             CASE WHEN @SortCol='AddressId DESC' THEN AddressId END DESC
            ) AS [Row_ID],
            a.AddressID,
            a.City,
            s.StateProvinceID
      FROM [Person].[Address] a
      Inner Join Person.StateProvince s 
		on a.StateProvinceID = s.StateProvinceID
      )
      SELECT
            Row_ID,
            AddressId,
            City,
            StateProvinceCode,
            @pgNbr AS PageNumber,
            @NbrPages AS TotalNbrPages
      FROM PagingCTE
      WHERE Row_ID >= (@pgSize * @pgNbr) - (@pgSize -1) AND
            Row_ID <= @pgSize * @pgNbr
END
 
--FIRST NAME ONLY
IF @City IS NOT NULL AND @StateProvinceCode IS NULL
BEGIN
 
      ;WITH PagingCTE (Row_ID,AddressId,City,StateProvinceCode)
      AS
      (
      SELECT
            ROW_NUMBER()
            OVER(ORDER BY
             CASE WHEN @SortCol='City DESC' THEN City END DESC,
             CASE WHEN @SortCol='City ASC'  THEN City END ASC,
             CASE WHEN @SortCol='StateProvinceCode ASC'   THEN StateProvinceCode  END ASC,
             CASE WHEN @SortCol='StateProvinceCode DESC'  THEN StateProvinceCode  END DESC,
             CASE WHEN @SortCol='AddressId ASC'  THEN AddressId END ASC,
             CASE WHEN @SortCol='AddressId DESC' THEN AddressId END DESC
            ) AS [Row_ID],
            a.AddressId,
            a.City,
            s.StateProvinceCode
      FROM [Person].[Address] a
      Inner Join Person.StateProvince s 
		on a.StateProvinceID = s.StateProvinceID
      WHERE a.[City] = @City
      )
      SELECT
            Row_ID,
            AddressId,
            City,
            StateProvinceCode,
            @pgNbr AS PageNumber,
            @NbrPages AS TotalNbrPages
      FROM PagingCTE
      WHERE Row_ID >= (@pgSize * @pgNbr) - (@pgSize -1) AND
            Row_ID <= @pgSize * @pgNbr
END
 
--LAST NAME ONLY
IF @City IS NULL AND @StateProvinceCode IS NOT NULL
BEGIN
 
      ;WITH PagingCTE (Row_ID,AddressId,City,StateProvinceCode)
      AS
      (
      SELECT
            ROW_NUMBER()
            OVER(ORDER BY
             CASE WHEN @SortCol='City DESC' THEN City END DESC,
             CASE WHEN @SortCol='City ASC'  THEN City END ASC,
             CASE WHEN @SortCol='StateProvinceCode ASC'   THEN StateProvinceCode  END ASC,
             CASE WHEN @SortCol='StateProvinceCode DESC'  THEN StateProvinceCode  END DESC,
             CASE WHEN @SortCol='AddressId ASC'  THEN AddressId END ASC,
             CASE WHEN @SortCol='AddressId DESC' THEN AddressId END DESC
            ) AS [Row_ID],
            a.AddressId,
            a.City,
            s.StateProvinceCode
      FROM [Person].[Address] a
      Inner Join Person.StateProvince s 
		on a.StateProvinceID = s.StateProvinceID
      WHERE s.[StateProvinceCode] = @StateProvinceCode
      )
      SELECT
            Row_ID,
            AddressId,
            City,
            StateProvinceCode,
            @pgNbr AS PageNumber,
            @NbrPages AS TotalNbrPages
      FROM PagingCTE
      WHERE Row_ID >= (@pgSize * @pgNbr) - (@pgSize -1) AND
            Row_ID <= @pgSize * @pgNbr
END
 
--FIRST AND LAST NAME
IF @City IS NOT NULL AND @StateProvinceCode IS NOT NULL
BEGIN
 
      ;WITH PagingCTE (Row_ID,AddressId,City,StateProvinceCode)
      AS
      (
      SELECT
            ROW_NUMBER()
            OVER(ORDER BY
             CASE WHEN @SortCol='City DESC' THEN City END DESC,
             CASE WHEN @SortCol='City ASC'  THEN City END ASC,
             CASE WHEN @SortCol='StateProvinceCode ASC'   THEN StateProvinceCode  END ASC,
             CASE WHEN @SortCol='StateProvinceCode DESC'  THEN StateProvinceCode  END DESC,
             CASE WHEN @SortCol='AddressId ASC'  THEN AddressId END ASC,
             CASE WHEN @SortCol='AddressId DESC' THEN AddressId END DESC
            ) AS [Row_ID],
            a.AddressId,
            a.City,
            s.StateProvinceCode
      FROM [Person].[Address] a
      Inner Join Person.StateProvince s 
		on a.StateProvinceID = s.StateProvinceID
      WHERE a.[City] = @City AND
            s.[StateProvinceCode] = @StateProvinceCode
      )
      SELECT
            Row_ID,
            AddressId,
            City,
            StateProvinceCode,
            @pgNbr AS PageNumber,
            @NbrPages AS TotalNbrPages
      FROM PagingCTE
      WHERE Row_ID >= (@pgSize * @pgNbr) - (@pgSize -1) AND
            Row_ID <= @pgSize * @pgNbr
END
 
END
GO
