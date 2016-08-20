CREATE TABLE [Main] (
	[MainID] [int] IDENTITY (1, 1) NOT NULL ,
	[Name] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
	[StartDate] [datetime] NULL ,
	CONSTRAINT [PK_Main] PRIMARY KEY  CLUSTERED 
	(
		[MainID]
	)  ON [PRIMARY] 
) ON [PRIMARY]
GO

CREATE TABLE [TableA] (
	[TableAID] [int] IDENTITY (1, 1) NOT NULL ,
	[MainID] [int] NOT NULL ,
	[Date] [datetime] NULL ,
	[Amount] [decimal](10, 4) NULL ,
	CONSTRAINT [FK_TableA_Main] FOREIGN KEY 
	(
		[MainID]
	) REFERENCES [Main] (
		[MainID]
	)
) ON [PRIMARY]
GO

CREATE TABLE [TableB] (
	[TableBID] [int] IDENTITY (1, 1) NOT NULL ,
	[MainID] [int] NOT NULL ,
	[Date] [datetime] NULL ,
	[Amount] [decimal](10, 4) NULL ,
	CONSTRAINT [FK_TableB_Main] FOREIGN KEY 
	(
		[MainID]
	) REFERENCES [Main] (
		[MainID]
	)
) ON [PRIMARY]
GO

Select IsNull(ta.MainID,tb.MainID) as MainID, IsNull(ta.Name,tb.Name) as Name, IsNull(ta.StartDate,tb.StartDate) as StartDate,
 	(IsDate(ta.Date)*IsDate(tb.Date)) as Sorter,
   TableAID, ta.Date as DateA, ta.Amount as AmountA, tb.TableBID, tb.Date as DateB, tb.Amount as AmountB
FROM 
	(SELECT m.MainID, m.Name, m.StartDate, a.TableAID, a.Date, a.Amount
	FROM Main m 
	INNER JOIN TableA a 
		ON m.MainID = a.MainID) ta
FULL OUTER JOIN 
	(SELECT m.MainID, m.Name, m.StartDate, b.TableBID, b.Date, b.Amount
	FROM Main m 
	INNER JOIN TableB b 
		ON m.MainID = b.MainID) tb
On ta.MainID = tb.MainID 
  		AND ta.TableAID = tb.TableBID
ORDER BY MainID, Sorter Desc 
