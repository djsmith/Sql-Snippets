/*

http://www.simple-talk.com/sql/learn-sql-server/full-text-indexing-workbench/

After you set up a full-text index on a table in a SQL Server 2005 or SQL Server
2008 database, you can perform a full-text search on the indexed columns in the
table. To perform a full-text search, you can use the CONTAINS predicate or the
FREETEXT predicate in your query's WHERE clause.

This workbench provides you with examples of how to use these predicates to
perform a full-text search. (Note that SQL Server also supports two full-text
functions, CONTAINSTABLE and FREETEXT table, but this workbench focuses only on
the predicates.)

When you include the CONTAINS or FREETEXT predicate in your WHERE clause, the
query engine searches the columns that are specified in the predicate arguments.
These columns must be included in the full-text index that is defined on the
specified table. The predicates also let you make use ofthe thesaurus that is
available for any of the supported languages.

If you're new to full-text indexes and searches, you should first review the
Simple-Talk article "Understanding Full-Text Indexing in SQL Server," published
December 29, 2008. The article describes how full-text indexes are implemented
in SQL Server 2005 and 2008, and provides examples of how to create those
indexes.
http://www.simple-talk.com/sql/learn-sql-server/understanding-full-text-indexing-in-sql-server/

*/

/*
To run the examples in this workbench, you should first set up the necessary
environment to test the full-text queries. The following T-SQL statements create
the StormyWeather table, populate the table, create the ftcStormyWeather full-
text catalog, and then create a full text index on the table. The index is added
to the ftcStormyWeather catalog.
*/

-- Create the StormyWeather table.
USE AdventureWorks2008 --replace with correct DB name
GO

IF OBJECT_ID (N'StormyWeather', N'U') IS NOT NULL
DROP TABLE StormyWeather
GO
CREATE TABLE StormyWeather (
  StormID INT NOT NULL IDENTITY,
  StormHead NVARCHAR(50) NOT NULL,
  StormBody NVARCHAR(MAX) NOT NULL,
  CONSTRAINT [PK_StormyWeather_StormID] PRIMARY KEY CLUSTERED (StormID ASC)
)
GO
-- Populate the StormyWeather table with data
-- that supports various full-text query types.
INSERT INTO StormyWeather (StormHead, StormBody)
VALUES('Stormy Weather Delays Travel',
  'The stormy weather made travel by motor vehicle difficult.')
INSERT INTO StormyWeather (StormHead, StormBody)
VALUES('Stormier Weather on Monday',
  'The stormier weather on Monday made vehicle travel difficult.')
INSERT INTO StormyWeather (StormHead, StormBody)
VALUES('Stormiest Weather in December',
  'December can be the stormiest month, making automobile travel difficult.')
INSERT INTO StormyWeather (StormHead, StormBody)
VALUES('Storm Grows Strong',
  'The storm is growing strong.')
INSERT INTO StormyWeather (StormHead, StormBody)
VALUES('Storms Crossing the Pacific',
  'The storms are lining up across the Pacific Ocean.')
INSERT INTO StormyWeather (StormHead, StormBody)
VALUES('Storm''s Wind Delays Travel',
  'The storm''s wind made car travel difficult on Tuesday.')
INSERT INTO StormyWeather (StormHead, StormBody)
VALUES('Storms'' Flooding Delays Travel',
  'The storms'' flooding made auto travel difficult throughout December.')
INSERT INTO StormyWeather (StormHead, StormBody)
VALUES('Children Run from Room',
  'The children often storm out of the room when upset.')
INSERT INTO StormyWeather (StormHead, StormBody)
VALUES('Boy Runs from Room',
  'The boy storms out of the room when his sister changes the channel.')
INSERT INTO StormyWeather (StormHead, StormBody)
VALUES('Girl Ran from Room',
  'The girl stormed out of the room when her brother ate the cookie.')
INSERT INTO StormyWeather (StormHead, StormBody)
VALUES('Children Running from Room',
  'The children were storming out of the room when the lights went out.')
GO
-- Create a full-text catalog and set it as the default.
CREATE FULLTEXT CATALOG ftcStormyWeather
AS DEFAULT
GO
-- Create a full-text index on the StormyWeather table.
-- Add the index to the ftcStormyWeather catalog.
CREATE FULLTEXT INDEX ON StormyWeather(StormHead, StormBody)
KEY INDEX PK_StormyWeather_StormID
ON ftcStormyWeather
GO

/*
Use the CONTAINS predicate to search the columns included in the full-text
index. The CONTAINS arguments must be enclosed in parentheses. Multiple columns
must be separated by a comma and enclosed in parentheses. The search condition (
the term or terms) must be enclosed in single quotes.
*/

-- Search a single column for a single term.
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE CONTAINS(StormHead, 'storm')

/*
The statement returns the following results:
4  Storm Grows Strong            The storm is growing strong.
6  Storm's Wind Delays Travel    The storm's wind made car travel difficult on Tuesday.
*/

-- Search multiple columns for a single term.
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE CONTAINS((StormHead, StormBody), 'storm')

/*
The statement returns the following results:
4  Storm Grows Strong            The storm is growing strong.
6  Storm's Wind Delays Travel    The storm's wind made car travel difficult on Tuesday.
8  Children Run from Room        The children often storm out of the room when upset.

The next statement returns the same results.
*/

-- Use an asterisk (*) wildcard instead of column names
-- to search all full-text columns.
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE CONTAINS(*, 'storm')

-- When searching multiple terms, use a comparative
-- operator, such as OR or AND, to separate the terms.
-- Individual terms should be enclosed in double quotes.
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE CONTAINS(StormHead, '"storm" OR "storms" OR "stormy" OR "stormier" OR "stormiest"')

/*
The statement returns the following results:
1  Stormy Weather Delays Travel   The stormy weather made travel by motor vehicle difficult.
2  Stormier Weather on Monday     The stormier weather on Monday made vehicle travel difficult.
3  Stormiest Weather in December  December can be the stormiest month, making automobile travel difficult.
4  Storm Grows Strong             The storm is growing strong.
5  Storms Crossing the Pacific    The storms are lining up across the Pacific Ocean.
6  Storm's Wind Delays Travel     The storm's wind made car travel difficult on Tuesday.
7  Storms' Flooding Delays Travel The storms' flooding made auto travel difficult throughout December.
*/

/*
Rather than specify multiple terms, you can use a 'prefix term' if the terms
begin with the same characters.

To use a prefix term, specify the beginning characters, then add an asterisk (*)
wildcard to the end of the term. Enclose the prefix term in double quotes.

The following statement returns the same results as the previous one.
*/

-- Search for all terms that begin with 'storm'
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE CONTAINS(StormHead, '"storm*"')

/*
Not all related terms can be effectively consolidated into a prefix term. For
example, 'run' and 'ran' would require "r*", which would match all words
beginning with 'r'. In these cases, you can specify each inflection of the word,
such as '"run" OR "ran" OR "runs"', or you can use FORMSOF in your CONTAINS
predicate.
*/

-- Specify each inflection.
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE CONTAINS(StormHead, '"run" OR "runs" OR "ran" OR "running"')

/*
The statement returns the following results:
8  Children Run from Room     The children often storm out of the room when upset.
9  Boy Runs from Room         The boy storms out of the room when his sister changes the channel.
10 Girl Ran from Room         The girl stormed out of the room when her brother ate the cookie.
11 Children Running from Room The children were storming out of the room when the lights went out.

The following statement returns the same results as the previous one.
*/

-- Use the FORMSOF and INFLECTIONAL keywords, along with the root word.
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE CONTAINS(StormHead, 'FORMSOF(INFLECTIONAL, run)')

/*
As you can see in the previous examples, the CONTAINS predicate returns an exact
match, unless you specify a prefix term or FORMSOF. However, these methods will
not work for different words with similar meanings, such as 'car' and
'automobile'. In these cases, you can use a thesaurus to match these types of
terms.

For example, you can update the tsenu.xml thesaurus file (for LCID 1033) by
adding the following elements:

    <thesaurus xmlns="x-schema:tsSchema.xml">
      <diacritics_sensitive>0</diacritics_sensitive>
        <expansion>
            <sub>car</sub>
            <sub>auto</sub>
            <sub>automobile</sub>
            <sub>vehicle</sub>
            <sub>motor vehicle</sub>
        </expansion>
    </thesaurus>

When you add these elements to your thesaurus file, the full-text search engine
can then treat these terms the same. For example, if you search on 'car', 'auto'
and 'automobile' will also be included in your search.

After you update a thesaurus file, you might need to reload it. In SQL Server
2008, you can use the sp_fulltext_load_thesaurus_file system stored procedure to
reload the thesaurus file after you've updated it. In SQL Server 2005, you must
restart the full-text search service.

Now when you search on car and specify the FORMSOF and THESAURUS keywords, your
search will return all rows that include any of the terms specified in the
thesaurus file.
*/

-- Use the term as is to return an exact match.
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE CONTAINS(StormBody, 'car')

/*
The statement returns the following results:
6  Storm's Wind Delays Travel     The storm's wind made car travel difficult on Tuesday.
*/

-- Use the FORMSOF and THESAURUS keywords to use the thesaurus files.
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE CONTAINS(StormBody, 'FORMSOF(THESAURUS, car)')

/*
The statement returns the following results:
1  Stormy Weather Delays Travel   The stormy weather made travel by motor vehicle difficult.
2  Stormier Weather on Monday     The stormier weather on Monday made vehicle travel difficult.
3  Stormiest Weather in December  December can be the stormiest month, making automobile travel difficult.
6  Storm's Wind Delays Travel     The storm's wind made car travel difficult on Tuesday.
7  Storms' Flooding Delays Travel The storms' flooding made auto travel difficult throughout December.
*/

/*
You can also use the NEAR keyword between terms in your search condition to
specify words or phrases that must be near to each other.
*/

-- Use near to return rows in which 'travel' is near forms of 'storm'.
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE CONTAINS(StormBody, '"storm*" NEAR travel')

/*
The statement returns the following results:
1  Stormy Weather Delays Travel   The stormy weather made travel by motor vehicle difficult.
2  Stormier Weather on Monday     The stormier weather on Monday made vehicle travel difficult.
3  Stormiest Weather in December  December can be the stormiest month, making automobile travel difficult.
6  Storm's Wind Delays Travel     The storm's wind made car travel difficult on Tuesday.
7  Storms' Flooding Delays Travel The storms' flooding made auto travel difficult throughout December.
*/

-- You can use NEAR to chain together multiple terms.
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE CONTAINS(StormBody, '"storm*" NEAR travel NEAR Tuesday')

/*
The statement returns the following results:
6  Storm's Wind Delays Travel    The storm's wind made car travel difficult on Tuesday.
*/

/*
The full-text queries in the examples here are relatively straightforward.
However, these queries can get quite complicated. Fortunately, the CONTAINS
predicate supports a number of methods that let you simplify your queries (such
as the prefix term). In addition, you can use the FREETEXT predicate to simplify
your queries even more. FREETEXT treats each word in a phrase as a separate term
and automatically finds different inflections for that term and applies the
appropriate thesaurus files.
*/

-- Define each form of a term in your search condition.
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE CONTAINS(StormBody, '"weather" OR "flood"
  OR "flooding" OR "car" OR "auto" OR "automobile" OR "vehicle" OR "motor vehicle"')

/*
The statement returns the following results:
1  Stormy Weather Delays Travel   The stormy weather made travel by motor vehicle difficult.
2  Stormier Weather on Monday     The stormier weather on Monday made vehicle travel difficult.
3  Stormiest Weather in December  December can be the stormiest month, making automobile travel difficult.
6  Storm's Wind Delays Travel     The storm's wind made car travel difficult on Tuesday.
7  Storms' Flooding Delays Travel The storms' flooding made auto travel difficult throughout December.

The following two statements return the same results as the previous one.
*/

-- When possible, use prefix terms, thesaurus files, or other devices
-- to simplify your full-text queries.
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE CONTAINS(StormBody, '"weather" OR "flood*" OR FORMSOF(THESAURUS, car)')

-- You can also use FREETEXT when applicable to search for terms.
SELECT StormID, StormHead, StormBody FROM StormyWeather
WHERE FREETEXT(StormBody, 'weather flood car')

/*
That's all there is to using the CONTAINS and FREETEXT predicates. Keep in mind
that CONTAINS is more precise than FREETEXT. And, of course, a full-text search
can be much more complex than shown in the examples here. Be sure to check out
SQL Server Books Online for more details about both of these predicates.
*/

