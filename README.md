ISSN-L-resolver
===============

With PostgreSQL, converts any ISSN to the correspondent ISSN-L, using a  lightweight structure,

  ````sql
   CREATE TABLE lib.issn_l (issn int not null primary key, issn_l int not null);
  ````

In order to have access to the txt data of correspondence ISSN/ISSN-L,  fill the form on ISSN-ORG website:

 http://www.issn.org/services/online-services/access-to-issn-l-table/
   
then, you download a 18Mb zip file, 

     issnltables.zip

but only a half (9Mb) is about "ISSN to ISSN-L" table, and as integers, you can use less space.

The resolver solution also offer PL/pgSQL funcions to format and to validate ISSNs.

## Synopsis ##

The PHP script converts the (updated) "ISSN to ISSN-L" TXT table, into a SQL table of integers (ISSN numbers without the *check digit*).
The `lib.sql` offers a resolver and all king of util convertion and ISSN handling, inclung *check digit* reconstruction.


## Instructions ##

 1. unzip issnltables.zip in a "issnltables"  folder
 2. test at terminal with `$ php issnltables2sql.php`
 3. run all with your database: `$ php issnltables2sql.php all | psql -h localhost -U postgres base`
 4. if you not using `lib` schema, create it at your database, `CREATE SCHEMA lib`
 5. install the lib: `$ psql -h localhost -U postgres base < lib.sql`
 6. if not use for another thing, `rm -r issnltables` and `rm issnltables.zip`
