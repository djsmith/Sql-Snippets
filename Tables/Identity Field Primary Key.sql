/*
Identity field is the table primary key
This query tests if the identity field in a table is the primary key. Remove the where 
clause to just get a listing of the constraints.
*/

select k.table_name, k.constraint_name, t.constraint_type, k.column_name, k.ordinal_position, 
	COLUMNPROPERTY(object_id(k.TABLE_NAME), k.COLUMN_NAME, 'IsIdentity') as IsIdentity
from INFORMATION_SCHEMA.KEY_COLUMN_USAGE k
inner join INFORMATION_SCHEMA.Columns c 
	on c.table_name = k.table_name 
		and c.column_name = k.column_name
inner join INFORMATION_SCHEMA.TABLE_CONSTRAINTS t
	on k.constraint_name = t.constraint_name
where t.constraint_type = 'PRIMARY KEY' 
	and COLUMNPROPERTY(object_id(k.TABLE_NAME), k.COLUMN_NAME, 'IsIdentity') != 1
 