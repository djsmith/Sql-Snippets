CREATE FUNCTION dbo.PadNumber (
	@Number INT,
	@Length INT,
	@Position CHAR(1)
)  
	RETURNS 	VARCHAR(50) AS

BEGIN 
	IF	@Length >= @Number
		DECLARE	@PaddedNr VARCHAR(50)

	SELECT @PaddedNr = 
	CASE UPPER(@Position)
		WHEN 'L' THEN
			REPLACE(SPACE((@Length-LEN(@Number))), ' ', '0') + CAST(@Number AS VARCHAR(6))
		WHEN 'R'	THEN
			CAST(@Number AS VARCHAR(6)) + REPLACE(SPACE((@Length-LEN(@Number))), ' ', '0')
		ELSE
			'N/A'
	END
	
	RETURN @PaddedNr
END



 