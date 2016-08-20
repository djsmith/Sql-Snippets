SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS OFF 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[fnProperCase]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[fnProperCase]
GO

CREATE FUNCTION fnProperCase (@InputString		VARCHAR(8000))
RETURNS VARCHAR(8000)
AS
BEGIN

	DECLARE @Count			INT
	DECLARE @InputLen		INT
	DECLARE @OutPutString	VARCHAR(8000)
	DECLARE @CurrentChar	CHAR(1)
	DECLARE @ChangeCase		BIT
	DECLARE @NumSpace		INT

	SET @InputLen = LEN(@InputString)
	SET @OutPutString = ''
	SET @Count = 1
	SET @ChangeCase = 1
	SET @NumSpace = 0

	WHILE @Count <= @InputLen
	BEGIN

		SET @CurrentChar = SUBSTRING(@InputString, @Count, 1)

		IF @CurrentChar <> ' '
		BEGIN

			IF @ChangeCase = 1
			BEGIN
				SET @CurrentChar = UPPER(@CurrentChar)
			END
			ELSE
			BEGIN
				SET @CurrentChar = LOWER(@CurrentChar)
			END

			IF @NumSpace > 0
			BEGIN
				SET @OutPutString = @OutPutString + SPACE(@NumSpace) +
										@CurrentChar
			END
			ELSE
			BEGIN
				SET @OutPutString = @OutPutString + @CurrentChar
			END

			SET @NumSpace = 0
			SET @ChangeCase = 0

		END
		ELSE
		BEGIN
			SET @NumSpace = @NumSpace + 1
			SET @ChangeCase = 1
		END

		SET @Count = @Count + 1

	END

	RETURN(@OutPutString)

END


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

 