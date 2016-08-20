/*
Formats a phone number by stripping out non-numeric characters
and then formatting the numbers as '123-456-7890 x11'

Examples:
select dbo.fnFormatPhone('800/456-3342 ext 399') --800-456-3342 x399
select dbo.fnFormatPhone('1-123-543-3323 x12') --123-543-3323 x12
select dbo.fnFormatPhone('(023) 543-3323 12235') --023-543-3323 x12235
*/

If Exists (Select * From dbo.sysobjects Where id = OBJECT_ID(N'[dbo].[fnFormatPhone]') AND xtype in (N'FN', N'IF', N'TF'))
	Drop Function [dbo].[fnFormatPhone]
Go

Create Function [dbo].[fnFormatPhone](
	@phone nvarchar(60)
)
Returns nvarchar(60)
as
Begin
	Declare 
		@PhoneExt nvarchar(30)
		
	-- Strip non-numeric chracters
	While PatIndex('%[^0-9]%', @phone) > 0 
	Begin
		Set @phone = Replace(@phone, SubString(@phone, PatIndex('%[^0-9]%', @phone),1), '') 
	End

	-- Remove Leading 1 on a full phone number
	If SubString(@phone, 1, 1) = '1' and Len(@phone) > 10
	Begin
		Set @phone = SubString(@phone, 2, Len(@phone)-1)
	End
	
	-- Get extension if available
	If Len(@phone) > 10 
	Begin
		Set @PhoneExt = ' x' + SubString(@phone, 11, Len(@phone))
	End

	--	Format @phone string to '000-000-0000 x0000'
	Set @phone = SubString(@phone,1,3) +'-'+ SubString(@phone,4,3) +'-'+ SubString(@phone,7,4)

	Return @phone + IsNull(@PhoneExt,'')
End

Go

