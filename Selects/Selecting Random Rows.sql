/*
Selecting Random Rows
You can use the NewID() function to generate a GUID for a row and then order the rows by the GUID and selecting the top X number of rows. The GUID field doesn’t have to be in the table, it can just be part of the select query’s return set. This way a different set of rows will be selected each time.
*/
SELECT TOP 10 OrderID, NewID() as Random
FROM Orders
ORDER BY Random
