/*
Table Constraints with Functions
Some data constraints on tables are more complicated than what is 
possible with unique indexes and forign key relationships. This 
demonstrates using a SQL User Function to return if a given 
email address is already being used
*/

--Function determines if a given email address is already being used
-- in a different record
Create Function EmailUniqueDefault(
	@EML_Key int,
	@EML_ID varchar(200)
)
Returns bit
As
Begin
	Declare @ReturnUnique bit

	If Exists 
		(Select * 
			From employee_email_id 
			Where ((EML_Key <> @EML_Key) And (EML_ID = @EML_ID)))

		Set @ReturnUnique = 0  --email is not unique
	Else
		Set @ReturnUnique = 1  --email is unique

Return @ReturnUnique
End
Go

-- Alter a table to use the function in a constraint
-- The constraint is only invalid if the email address is the default 
--  address and it already exists in a different record
ALTER TABLE dbo.employee_email_id WITH NOCHECK ADD CONSTRAINT
	CK_employee_email_id CHECK (([eml_default] <> 1 or [eml_default] = 1 and [dbo].[EmailUniqueDefault]([eml_key], [eml_id]) = 1))
GO
