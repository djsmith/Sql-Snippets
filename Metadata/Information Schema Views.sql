/*
Using Information Schema Views
01 October 2009
by Robert Sheldon
http://www.simple-talk.com/sql/t-sql-programming/using-information-schema-views/

Information schema views return information about the metadata in a SQL Server database. 
You can write code that uses these views to retrieve metadata, without worrying about 
changes to the system tables. For example, you can retrieve such metadata as the tables 
created in a database, the privileges granted on those tables, or the constraints 
defined on the tables.

SQL Server 2005 and 2008 automatically create 20 information schema views in every 
database. The views comply with the SQL-92 standard and are created in the schema 
INFORMATION_SCHEMA. Note, however, that in SQL Server an information schema view 
returns information only about those objects that the current user has permission 
to access. For example, if a user does not have the privileges necessary to access 
a particular table in a database, that user will not be able to view the columns 
from that table in the COLUMNS view.

When you call an information schema view, you must qualify the view name with the 
schema INFORMATION_SCHEMA. In addition, if you’re using the views to retrieve data 
from a database other than the current database, you must also qualify the name by 
including the database name as well as the schema name.

SQL Server uses SQL-92 metadata names for the information schema views and their 
columns. That means a database is referred to as a catalog, and a user-defined data 
type as a domain. However, most other metadata names are consistent between SQL Server 
and SQL-92.

The rest of the article describes each information schema view available in SQL 
Server 2005 and 2008 and provides examples that demonstrate how to use them. Note 
that these examples are based on the AdventureWorks2008 sample database in SQL 
Server 2008, although in many cases the statements are not specific to any one database.
*/

Use AdventureWorks

/*
CHECK_CONSTRAINTS

The CHECK_CONSTRAINTS information schema view displays the check constraints that 
exist in the current or specified database. The data includes the check expression 
that is part of the Transact-SQL constraint definition. In the following SELECT 
statement, I retrieve the schema, constraint, and constraint expression for each 
check constraint in the AdventureWorks2008 database:
*/

SELECT  CONSTRAINT_SCHEMA, CONSTRAINT_NAME, CHECK_CLAUSE
FROM    INFORMATION_SCHEMA.CHECK_CONSTRAINTS
ORDER BY CONSTRAINT_SCHEMA, CONSTRAINT_NAME

/*
The CHECK_CONSTRAINTS view does not include the table name. However, if the table 
name is part of the constraint name, as is the case in the AdventureWorks2008 
database, you can order the query according to constraint name. In the example 
above, I order the results first by schema name and then by constraint name so 
that tables are grouped together. (Ed: if you use the CONSTRAINT_SCHEMA, BOL  
for the 2008 version states 'The only reliable way to find the schema of a object 
is to query the sys.objects catalog view'. A bug?)
*/

/*
COLUMN_DOMAIN_USAGE

The COLUMN_DOMAIN_USAGE information schema view displays the columns that are 
configured with user-defined data types. For example, if your database contains a 
user-defined data type called IndName, the view will return a row for each column 
in a table or view defined with the IndName data type.

In the following SELECT statement, I retrieve the schema, table, column, and data 
type for each column configured with a user-defined data type in the 
AdventureWorks2008 database:
*/

SELECT  TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DOMAIN_NAME
FROM    INFORMATION_SCHEMA.COLUMN_DOMAIN_USAGE
ORDER BY TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DOMAIN_NAME

/*
COLUMN_PRIVILEGES

The COLUMN_PRIVILEGES information schema view displays information about each 
column-level privilege that has been granted to or granted by the current user. 
The view returns such details as who granted the privilege, who has been granted 
the privilege, the column on which the privilege is granted, and the type of privilege.

The following example retrieves the column-level privileges granted in the 
HumanResources schema of the AdvenureWorks2008 database:
*/

SELECT  GRANTOR, GRANTEE, TABLE_NAME, COLUMN_NAME, PRIVILEGE_TYPE
FROM    INFORMATION_SCHEMA.COLUMN_PRIVILEGES
WHERE   TABLE_SCHEMA = 'HumanResources'

/*
As you can see, the statement will return the grantor, grantee, table name, 
column names, and privilege type for each column-level privilege.
*/

/*
COLUMNS

The COLUMNS information schema view displays a list of columns in the specified 
database. As I indicated above, this data includes only columns that can be accessed 
by the current user (which is true for all information schema views). The COLUMNS view returns not only the object names that qualify the column (database, schema, table, and column names), but also information such as the ordinal position, default values, nullability, and data type.

In the following example, I retrieve the columns, their data types, nullability, 
and default values (if any) for the columns in the vEmployee view in the 
AdventureWorks2008 database:
*/
SELECT  COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
FROM    INFORMATION_SCHEMA.COLUMNS
WHERE   TABLE_NAME = 'vEmployee'
/*
CONSTRAINT_COLUMN_USAGE

The CONSTRAINT_COLUMN_USAGE information schema view displays a list of columns 
in the current or specified database on which constraints are defined. The view 
returns the object names that qualify the columns (database, schema, table, and 
column names) as well as the object names that qualify the constraints (database, 
schema, and constraint names).

The following example uses the CONSTRAINT_COLUMN_USAGE view to retrieve the 
constraints defined on columns in the HumanResources schema of the 
AdventureWorks2008 database:
*/
SELECT  TABLE_NAME, COLUMN_NAME, CONSTRAINT_NAME
FROM    INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE
WHERE   TABLE_SCHEMA = 'HumanResources'
ORDER BY TABLE_NAME, COLUMN_NAME, CONSTRAINT_NAME
/*
CONSTRAINT_TABLE_USAGE

The CONSTRAINT_TABLE_USAGE information schema view displays a list of tables in the 
current or specified database on which constraints are defined. The view returns the object names that qualify the tables (database, schema, and table names) as well as the object names that qualify the constraints (database, schema, and constraint names).

The following example uses the CONSTRAINT_TABLE_USAGE view to retrieve the constraints 
defined on tables in the HumanResources schema of the AdventureWorks2008 database:
*/

SELECT  TABLE_NAME, CONSTRAINT_NAME
FROM    INFORMATION_SCHEMA.CONSTRAINT_TABLE_USAGE
WHERE   TABLE_SCHEMA = 'HumanResources'
ORDER BY TABLE_NAME, CONSTRAINT_NAME

/*
DOMAIN_CONSTRAINTS

The DOMAIN_CONSTRAINTS information schema view displays a row for each user-defined 
data type in the current or specified database that has a constraint bound to it. 
The information includes the object names that qualify the constraints (database, 
schema, and constraint names) as well as the object names that qualify the user-defined 
data types (database, schema, and type names). The view also returns information about 
constraint deferability.

In the following example, I retrieve the constraint names and user-defined data type 
names for each data type in the HumanResources schema that has a constraint bound to it:
*/
SELECT  CONSTRAINT_NAME, DOMAIN_NAME
FROM    INFORMATION_SCHEMA.DOMAIN_CONSTRAINTS
WHERE   CONSTRAINT_SCHEMA = 'HumanResources'
ORDER BY CONSTRAINT_NAME

/*
DOMAINS

The DOMAINS information schema view displays a list of user-defined data types in the 
current or specified database. In the following example, I retrieve the name of the 
user-defined data types, the built-in data types on which they’re based, and the character 
length of the data types:
*/

SELECT  DOMAIN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM    INFORMATION_SCHEMA.DOMAINS

/*
KEY_COLUMN_USAGE

The KEY_COLUMN_USAGE information schema view displays each column that is configured 
as a key constraint. The information includes the object names that qualify the 
constraints (database, schema, and constraint names) as well as the object names that 
qualify the columns (database, schema, table, and column names). The view also returns 
the columns’ ordinal positions.

The following SELECT statement uses the KEY_COLUMN_USAGE view to retrieve the columns 
in the Employee table that are constrained by a key:
*/

SELECT  COLUMN_NAME, CONSTRAINT_NAME
FROM    INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE   TABLE_NAME = 'Employee'

/*
PARAMETERS

The PARAMETERS information schema view displays a list of parameters for user-defined 
functions and stored procedures in the current or specified database. For functions, 
the view displays additional rows for the return values. The PARAMETERS view is one of 
the meatier information schema views in terms of the amount of information it returns. 
There are of course the details you would expect—the name of the parameter, associated 
routine, schema, and database. But the view also returns such details as the parameter 
data type, its ordinal position, and collation and character information.

In the following SELECT statement, I retrieve the routine name (stored procedure or 
function), the parameter name, the data type, and the mode (IN or OUT) for all routine 
parameters in the HumanResources schema of the AdventureWorks2008 database:
*/

SELECT  SPECIFIC_NAME, PARAMETER_NAME, DATA_TYPE, PARAMETER_MODE
FROM    INFORMATION_SCHEMA.PARAMETERS
WHERE   SPECIFIC_SCHEMA = 'HumanResources'
ORDER BY SPECIFIC_NAME, PARAMETER_NAME
/*
REFERENTIAL_CONSTRAINTS

The REFERENTIAL_CONSTRAINTS information schema view displays a row for each FOREIGN KEY
constraint in the current or specified database. The information includes the object 
names that qualify the constraints (database, schema, and constraint names) as well as 
details about matching conditions, update rules, and delete rules. The view also returns 
details specific to UNIQUE constraints.

The following example uses the REFERENTIAL_CONSTRAINTS view to retrieve the FOREIGN KEY 
constraints in the Production schema of the AdventureWorks2008 database:
*/

SELECT  CONSTRAINT_NAME, MATCH_OPTION, UPDATE_RULE, DELETE_RULE
FROM    INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS
WHERE   CONSTRAINT_SCHEMA = 'Production'
ORDER BY CONSTRAINT_NAME
/*
As you can see, I retrieve the constraint name, match option, and details about update 
and delete rules.
*/

/*
ROUTINE_COLUMNS

The ROUTINE_COLUMNS information schema view displays details about each column returned 
by the table-valued functions in the current or specified database. The information 
includes the object names that qualify the columns (database, schema, function, and column names) as well as such details as ordinal position, column default, data type, and character and collation information.

In the following example, I retrieve the columns, their data types, and their nullability 
for the columns returned by the ufnGetContactInformation function in the AdventureWorks2008 database.
*/

SELECT  COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM    INFORMATION_SCHEMA.ROUTINE_COLUMNS
WHERE   TABLE_NAME = 'ufnGetContactInformation'

/*
ROUTINES

The ROUTINES information schema view displays information about the stored procedures 
and functions in the current or specified database. The information includes the object 
names that qualify the routines (database, schema, and routine names), the routine 
definition (Transact-SQL), and character and collation information. The view also 
includes several columns that return only null values. These columns are reserved for 
future use.

The following SELECT statement uses the ROUTINES view to return the routine names and 
their schemas, as well as the routine definitions:
*/

SELECT  ROUTINE_SCHEMA, ROUTINE_NAME, ROUTINE_DEFINITION
FROM    INFORMATION_SCHEMA.ROUTINES

/*
SCHEMATA

The SCHEMATA information schema view displays each schema in the current or specified 
database. The information includes the database and schema names, the schema owner, 
and details about the character set. The following example retrieves the name and 
owner of each schema in the AdventureWorks2008 database:
*/

SELECT  SCHEMA_NAME, SCHEMA_OWNER
FROM    AdventureWorks.INFORMATION_SCHEMA.SCHEMATA

/*
TABLE_CONSTRAINTS

The TABLE_CONSTRAINTS information schema view displays a list of table constraints 
in the current or specified database. The view returns the object names that qualify 
the table (database, schema, and table names) as well as the object names that qualify 
the constraints (database, schema, and constraint names). The view also returns the 
constraint type (CHECK, UNIQUE, PRIMARY KEY, or FOREIGN KEY) and provides information 
about whether constraint checking is deferrable and whether it is at first deferred.

The following example uses the TABLE_CONSTRAINTS view to retrieve the constraints 
defined the Production schema of the AdventureWorks2008 database:
*/
SELECT  TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE   TABLE_SCHEMA = 'Production'

/*
Notice that the SELECT statement retrieves the table names, constraint names, and 
constraint type for each table constraint.
*/

/*
TABLE_PRIVILEGES

The TABLE_PRIVILEGES information schema view displays information about each 
table-level privilege that has been granted to or granted by the current user. 
The view returns such details as who granted the privilege, who has been granted 
the privilege, the table on which the privilege is granted, and the type of privilege.

The following example retrieves the table-level privileges granted in the Production 
schema of the AdvenureWorks2008 database:
*/
SELECT  GRANTOR, GRANTEE, TABLE_NAME, PRIVILEGE_TYPE
FROM    INFORMATION_SCHEMA.TABLE_PRIVILEGES
WHERE   TABLE_SCHEMA = 'Production'

/*
As you can see, the SELECT statement returns the names of the grantors and grantees, 
as well as the table names and privilege types.
*/

/*
TABLES

The TABLES information schema view displays a list of tables in the current or 
specified database. The information includes the object names that qualify the 
table (database, schema, and table names) as well as the table type (BASE TABLE or 
VIEW). In the following SELECT statement, I retrieve the tables, their associated 
schemas, and the table type for the AdventureWorks2008 database:
*/
SELECT  TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM    INFORMATION_SCHEMA.TABLES
ORDER BY TABLE_TYPE, TABLE_SCHEMA, TABLE_NAME

/*
VIEW_COLUMN_USAGE

The VIEW_COLUMN_USAGE information schema view displays the columns defined in the 
views in the current or specified database. The information includes the object 
names that qualify the views (database, schema, and view names) as well as the 
objects names that qualify the source columns (database, schema, table, and column 
names). The following example returns a list of views along with their base tables, 
the tables’ schemas, and the source columns:
*/
SELECT  VIEW_NAME, TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME
FROM    INFORMATION_SCHEMA.VIEW_COLUMN_USAGE
WHERE   TABLE_SCHEMA = 'Person'
ORDER BY VIEW_NAME, TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME
/*
VIEW_TABLE_USAGE

The VIEW_TABLE_USAGE information schema view displays the tables that are used in 
the views in the current or specified database. The information includes the object 
names that qualify the views (database, schema, and view names) as well as the objects 
names that qualify the base tables (database, schema, and table names). The following 
example returns a list of views along with their base tables and the tables’ schemas:
*/
SELECT  VIEW_NAME, TABLE_SCHEMA, TABLE_NAME
FROM    INFORMATION_SCHEMA.VIEW_TABLE_USAGE
WHERE   TABLE_SCHEMA = 'Person'
ORDER BY VIEW_NAME, TABLE_SCHEMA, TABLE_NAME
/*
VIEWS

The VIEWS information schema view displays a list of views in the current or specified 
database. The information includes the object names that qualify the views (database, 
schema, and view names) as well as the view definitions (Transact-SQL). The view also 
returns the WITH CHECK OPTION setting and specifies whether the view is updateable.

In the following SELECT statement, I retrieve the views, their associated schemas, and 
the view definitions for the AdventureWorks2008 database:
*/
SELECT  TABLE_SCHEMA, TABLE_NAME, VIEW_DEFINITION
FROM    INFORMATION_SCHEMA.VIEWS
ORDER BY TABLE_SCHEMA, TABLE_NAME