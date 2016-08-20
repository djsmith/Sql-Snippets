/* 
This script demonstrates a robust way to generate unique numbers in a table.

Based on the Code Project Article 'Flexible numbering sequences in T-SQL' 
by Michael Abramovitch.
http://www.codeproject.com/KB/database/TSQL-Flexible-Sequences.aspx

*/

-- Create table to stores information about the sequences.  Each row contains data for 
-- a different sequence.
CREATE TABLE dbo.SequenceControl (
	SequenceKey 	VARCHAR(25) NOT NULL PRIMARY KEY CLUSTERED,
	LastSequence	INT NOT NULL CHECK( LastSequence<2000000000 AND LastSequence>-1),
	SequenceFormat	VARCHAR(20) NOT NULL DEFAULT('[#]') CHECK ( CHARINDEX('[#]',SequenceFormat)>0),
	ZeroPadToDigits INT NOT NULL DEFAULT(0) CHECK (ZeroPadToDigits>-1 AND ZeroPadToDigits<11),
	IncrementBy	INT NOT NULL DEFAULT(1) CHECK (IncrementBy>0),
	LongDescription	VARCHAR(200) NULL
)
GO


-- This should produce a number starting with a W, containing 8 digits (W-00000001, W-00000002)
INSERT INTO dbo.SequenceControl (SequenceKey, LastSequence, SequenceFormat, ZeroPadToDigits)
VALUES ('Online Donation',0, 'W-[#]', 8)
GO


SET QUOTED_IDENTIFIER OFF 
GO 
SET ANSI_NULLS OFF 
GO 

CREATE PROCEDURE dbo.pGetNextInSequence 
    @SequenceKey VARCHAR(20) -- e.g. 'Online Donation'
AS 
BEGIN 
	SET NOCOUNT ON 

	DECLARE @LastNumber INT
	DECLARE @NextNumber INT
	DECLARE @FormattedNumber VARCHAR(40) 
	DECLARE @MyKey VARCHAR(30) 
	
	IF NOT EXISTS(SELECT 'X' FROM SequenceControl WHERE SequenceControl.SequenceKey = @SequenceKey ) BEGIN 
		SELECT @SequenceKey AS SequenceKey, 
			CAST('' AS VARCHAR(30)) AS NextSequenceFormatted, 
			0 AS NextSequenceInt 
		RETURN 
	END 

	DECLARE @SeqFormat VARCHAR(30), @IncrementBy INT, @IncrementStep INT, @ZeroPadToDigits INT 

	SELECT 
		@SeqFormat = RTRIM(LTRIM(SequenceFormat)),
		@IncrementBy = IncrementBy, 
		@ZeroPadToDigits = ZeroPadToDigits 
	FROM SequenceControl 
	WHERE SequenceControl.SequenceKey = @SequenceKey 

	DECLARE @RowCount INT 
	SET @RowCount    = 0 

	BEGIN TRANSACTION T1
		WHILE ( @RowCount = 0 ) BEGIN 
			SELECT @LastNumber = LastSequence 
			FROM SequenceControl 
			WHERE SequenceControl.SequenceKey = @SequenceKey 

			UPDATE SequenceControl 
			SET LastSequence = @LastNumber + @IncrementBy 
			WHERE SequenceKey = @SequenceKey 
				AND LastSequence = @LastNumber --this guarantees that no one has updated it in the meantime 
	             
			SELECT @RowCount = @@ROWCOUNT    --if its zero, then we need to get the next number after that and try again 
		END 
	COMMIT TRANSACTION T1 

	--here, we format the number according to the pattern for this sequence 
	DECLARE @NumberPart VARCHAR(20) 
	SET @NextNumber = @LastNumber + @IncrementBy 
	IF ( @ZeroPadToDigits>0) 
		SET @NumberPart = RIGHT( REPLICATE('0', @ZeroPadToDigits) + CAST(@NextNumber AS VARCHAR(20)), @ZeroPadToDigits) 
	ELSE 
		SET @NumberPart = CAST(@NextNumber AS VARCHAR(10)) 

	SET @FormattedNumber = REPLACE(@SeqFormat, '[#]', @NumberPart ) 

	-- Return the new sequence key
	SELECT @SequenceKey AS SequenceKey, 
		CAST(@FormattedNumber AS VARCHAR(30)) AS NextSequenceFormatted, 
		@NextNumber AS NextSequenceInt 
END 
GO 

SET QUOTED_IDENTIFIER OFF 
GO 
SET ANSI_NULLS ON    
GO

-- Execute several times for test
EXEC dbo.pGetNextInSequence 'Online Donation';
EXEC dbo.pGetNextInSequence 'Online Donation';
EXEC dbo.pGetNextInSequence 'Online Donation';

-- Clean up
IF OBJECT_ID('dbo.pGetNextInSequence') IS NOT NULL BEGIN
	DROP PROC dbo.pGetNextInSequence
END
IF OBJECT_ID('dbo.SequenceControl') IS NOT NULL BEGIN
	DROP TABLE dbo.SequenceControl
END
