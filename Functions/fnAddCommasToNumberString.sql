IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fnAddCommasToNumberString]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
	DROP FUNCTION [dbo].[fnAddCommasToNumberString]
GO

/*********************************************************************************
** File: fnAddCommasToNumberString.sql
** Desc: This function will add commas to a given number passed as a string.
** 
** Examples:
** ---------
** PRINT dbo.fnAddCommasToNumberString('20123.12')  -- 20,123.12
** PRINT dbo.fnAddCommasToNumberString('2012312')   -- 2,012,312
** PRINT dbo.fnAddCommasToNumberString('23')        -- 23
** 
** NOTE: A decimal or float input value will implicitly be cast to a
**       VARCHAR(MAX)
** PRINT dbo.fnAddCommasToNumberString(20123.12)    -- 20,123.12
** 
** Return values: VARCHAR(MAX)
** 
** Called by: 
** 
** Parameters:
** Input
** ----------
** @InputNumberStr VARCHAR(MAX)
**
** Output
** -----------
** none
**
** Auth: Jesse McLain
** Email: mailto:jesse@jessemclain.com
** Web: http://www.jessemclain.com
** Blog: http://www.jessesql.blogspot.com
**
** Date: 03/30/2009
**
*********************************************************************************
** Change History
*********************************************************************************
** Date:       Author:             Description:
** --------    --------            -------------------------------------------
** 20090330    Jesse McLain        Created script
*********************************************************************************
** ToDo List
*********************************************************************************
** Date:       Author:             Description:
** --------    --------            -------------------------------------------
** 20090330    Jesse McLain        Created script
*********************************************************************************
** Notes
*********************************************************************************
** 3/30/09 - This function works by taking the input number (as a string), reversing it, and 
** then adding in commas after every third digit. When it reaches the end, it re-reverses the
** result and returns it. It also accounts for any decimal place digits by use of @Offset - 
** this variable stores this info by finding the position of the decimal place after string
** reversal. After counting off 3 non-decimal place digits, the function stuffs a comma into
** the reversed string, and increment @Offset and @CharIdx, because we are increasing the size
** of the string by one char. 
**        
*********************************************************************************/

CREATE FUNCTION dbo.fnAddCommasToNumberString
	(@InputNumberStr VARCHAR(MAX))
RETURNS VARCHAR(MAX) 
AS BEGIN
	DECLARE @OutputStr VARCHAR(MAX)
	DECLARE @CharIdx INT
	DECLARE @OffSet INT

	SET @OutputStr = REVERSE(@InputNumberStr)

	SET @CharIdx = CHARINDEX('.', @OutputStr)
	SET @Offset = @CharIdx
	SET @CharIdx = CASE WHEN @CharIdx = 0 THEN 1 ELSE @CharIdx END

	WHILE @CharIdx <= LEN(@OutputStr) BEGIN
		IF @CharIdx - @Offset > 3 AND (@CharIdx - @Offset - 1) % 3 = 0 BEGIN
			SET @OutputStr = STUFF(@OutputStr, @CharIdx, 0, ',')
			SET @Offset = @Offset + 1
			SET @CharIdx = @CharIdx + 1
		END

		SET @CharIdx = @CharIdx + 1
	END

	RETURN REVERSE(@OutputStr)
END
GO
 