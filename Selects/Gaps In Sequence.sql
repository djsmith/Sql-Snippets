/*
This query will return a tabel listing any gaps in a sequence of numbers
along with the number of digits skipped
Based on http://www.sqlservercentral.com/columnists/slasham/findinggapsinasequentialnumbersequence.asp
Modified to HRi database's employee_main table
*/
Select LastSeqNumber, NextSeqNumber, FirstAvailable = LastSeqNumber + 1, 
LastAvailable = NextSeqNumber - 1, NumbersAvailable = NextSeqNumber - (LastSeqNumber + 1) 
From (
	Select LastSeqNumber = (
		Select IsNull(Max(m2.KeyID),0) as KeyID
		From employee_main m2
		Where m2.KeyID < m1.KeyID
		), NextSeqNumber = KeyID
	From employee_main m1
	) as A
Where NextSeqNumber - LastSeqNumber > 1
Order By LastSeqNumber

