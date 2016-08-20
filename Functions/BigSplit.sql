/*
This function will split a delimited list of values into a table of varchar values
Since this function uses TEXt as the data type for the list, it has a very large capacity.
*/
CREATE FUNCTION dbo.BigSplitVChar (
	@List  TEXT,
	@Delimiter VARCHAR(1)
)
RETURNS @ret TABLE (
	Number INT IDENTITY(0, 1) NOT NULL PRIMARY KEY,
	Value VARCHAR(8000)
)
AS
BEGIN

	DECLARE @Index INT
	SELECT @Index = 1
	DECLARE @Item VARCHAR(8000)

	WHILE @Index < (DATALENGTH(@List) + DATALENGTH(@Delimiter))
	BEGIN
		IF ((SUBSTRING(@List, @Index - DATALENGTH(@Delimiter), DATALENGTH(@Delimiter)) = @Delimiter AND @Index > 1) OR @Index = 1)
		BEGIN
			SELECT @Item = SUBSTRING(@List, @Index,
			CASE SIGN(CHARINDEX(@Delimiter, @List, @Index) - @Index)
			WHEN -1 THEN
				CASE PATINDEX('%' + @Delimiter + '%', SUBSTRING(@List, @Index, ABS(CHARINDEX(@Delimiter, @List, @Index) - @Index)))
				WHEN 0 THEN
					DATALENGTH(@List) - @Index + 1
				ELSE
					PATINDEX('%' + @Delimiter + '%', SUBSTRING(@List, @Index, ABS(CHARINDEX(@Delimiter, @List, @Index) - @Index))) - 1
				END
			ELSE
				ABS(CHARINDEX(@Delimiter, @List, @Index) - @Index)
			END)

			INSERT INTO @ret (Value)
			VALUES (@Item)
		END
		SELECT @Index = @Index + DATALENGTH(@Item) + DATALENGTH(@Delimiter)
	END
	RETURN
END
GO 