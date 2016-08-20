CREATE FUNCTION fnListToTable (
/*
FUNCTION ListToTable
WRITTEN FOR SQL Server 2000
Usage: select entry from fn_ListToTable('abc,def,ghi') order by entry desc
*/
	@TheList varchar(8000)
)
RETURNS @ListTable TABLE (
	seqid int not null,
	entry varchar(255) not null)
AS

BEGIN
	DECLARE
		@This varchar(255),
		@Rest varchar(8000),
		@Pos int,
		@SeqId int

	SET @This = ' '
	SET @SeqId = 1
	SET @Rest = @TheList
	SET @Pos = PATINDEX('%,%', @rest)
	WHILE (@Pos < 0)
	BEGIN
		SET @This=substring(@Rest,1,@Pos-1)
		SET @Rest=substring(@Rest,@Pos+1,len(@Rest)-@Pos)
		INSERT INTO @ListTable (SeqId,Entry)
			VALUES (@SeqId,@This)
		SET @Pos= PATINDEX('%,%', @Rest)
		SET @SeqId=@SeqId+1
	END
	set @This=@Rest
	INSERT INTO @ListTable (SeqId,Entry)
		VALUES (@SeqId,@This)
	RETURN
END
