/* Query uses string functions to split a single field into separate fields if it contains a CRLF character */

SELECT [ATE_Key],[EMP_KEY],[EMP_SSN],
case when charindex(char(13),ATE_AddressLine)>0 then 
	substring(ATE_AddressLine,1,charindex(char(13),ATE_AddressLine)-1) 
else 
	ATE_AddressLine 
end addr1, 
case when charindex(char(13),ATE_AddressLine)>0 then 
	substring(ATE_AddressLine,charindex(char(10),ATE_AddressLine)+1,len(ATE_AddressLine)-charindex(char(10),ATE_AddressLine)+1) 
else '' 
end addr2,
[ATE_City],[ATE_State],[ATE_Zip],[ATE_Country],[ATE_LastMod]
FROM [dbo].[address_table]