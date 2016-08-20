SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[fnSplitByDelimit]') and xtype in (N'FN', N'IF', N'TF'))
drop function [dbo].[fnSplitByDelimit]
GO

/**************************************************************
Returns a table of values from the @Text parameter split by 
the delimiter. 
If @Delim is null or an empty string each character in @Text
is split into a separate row.
Table contains a ValueCount column that ranges from 1 to the
number of items in the table
Example:
	Select * From dbo.fnSplitByDelimit('1,5,8,23,64', ',')
***************************************************************/
Create Function fnSplitByDelimit(@Text varchar(8000), @Delim varchar(20) = null)
Returns @retArray 
	Table (ValueCount smallint Primary Key, Value varchar(8000))
As
Begin

Declare @ValueCount smallint
Declare @Value varchar(8000)
Declare @Continue bit
Declare @Strike smallint
Declare @Delimlength tinyint

Set @ValueCount = 1
Set @Text = LTrim(RTrim(@Text))
Set @Delimlength = Datalength(@Delim)
Set @Continue = 1

If not ((@Delimlength = 0) or (@Delim Is Null))
Begin
	While @Continue = 1
	Begin

		--If you can find the delimiter in the text, retrieve the first element and
		--Insert it with its index into the return table.
		If Charindex(@Delim, @Text)>0
		Begin
			Set @Value = Substring(@Text,1, Charindex(@Delim,@Text)-1)
			Begin
				Insert @retArray (ValueCount, value)
				Values (@ValueCount, @Value)
			End
			
			--Trim the element and its delimiter from the front of the string.
			--Increment the index and loop.
			Set @Strike = Datalength(@Value) + @Delimlength
			Set @ValueCount = @ValueCount + 1
			Set @Text = LTrim(Right(@Text,Datalength(@Text) - @Strike))
		
		End
		Else
		Begin
			--If you canÆt find the delimiter in the text, @Text is the last value in
			--@retArray.
			Set @Value = @Text
			Begin
				Insert @retArray (ValueCount, value)
				Values (@ValueCount, @Value)
			End
			--Exit the While loop.
			Set @Continue = 0
		End
	End
End
Else
Begin
	While @Continue=1
	Begin
		--If the delimiter is null, check for remaining text
		--instead of a delimiter. Insert the first character into the
		--retArray table. Trim the character from the front of the string.
		--Increment the index and loop.
		IF Datalength(@Text)>1
		Begin
			Set @Value = Substring(@Text,1,1)
			Begin
				Insert @retArray (ValueCount, value)
				Values (@ValueCount, @Value)
			End
			Set @ValueCount = @ValueCount+1
			Set @Text = Substring(@Text,2,Datalength(@Text)-1)
			
		End
		Else
		Begin
			--One character remains.
			--Insert the character, and exit the While loop.
			Insert @retArray (ValueCount, value)
			Values (@ValueCount, @Text)
			Set @Continue = 0	
		End
	End
End

Return
End

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

 