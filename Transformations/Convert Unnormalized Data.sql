/*
Convert Unnormalized Data to Normalized Table
    Example data;
TableA: StudentID, StudentName, Mark1, Mark2, Mark3
TableB is normalized with the following columns: 
TableB: StudentID, StudentName, SubjectID, Marks
Use the following SQL in SQL Server: 
*/

Insert into TableB (StudentID, StudentName,  SubjectID, Marks)
	Select StudentID, StudentName, 'S1',  Mark1
	From TableA
	Union All
	Select StudentID, StudentName, 'S2',  Mark2
	From TableA
	Union All
	Select StudentID, StudentName, 'S3',  Mark3
	From TableA
	Order by 1,2,3,4
