ISSN-L-resolver
===============

With SQL, converts any ISSN to the correspondent [ISSN-L](https://en.wikipedia.org/wiki/ISSN#Linking_ISSN), using a  lightweight structure,

  ````sql
   CREATE TABLE lib.issn_l (
      issn integer not null primary key, issn_l integer not null
    );
  ````

NOTE: the core of the resolver solution is a SQL script writed for PostgreSQL, in PL/pgSQL language. It  offer also funcions to format and to validate string-ISSNs of the front-end.

## Synopsis ##

The PHP script converts the (updated) "ISSN to ISSN-L" TXT table, into a SQL table of integers (ISSN numbers without the *check digit*).
The `lib.sql` offers a resolver and all king of util convertion and ISSN handling, inclung *check digit* reconstruction.

## Populating ##

In order to have access to the txt data of correspondence ISSN/ISSN-L,  fill the form on ISSN-ORG website:

 http://www.issn.org/services/online-services/access-to-issn-l-table/
   
then, you download a 18Mb zip file, 

     issnltables.zip

but only a half (9Mb) is about "ISSN to ISSN-L" table, and, at SQL database, with numbers as integers (4 bytes), you can use less space.
With `issnltables2sql.php` you can convert the file into SQL and then run `psql` to populate.

### Instructions for populating ###

 1. unzip issnltables.zip in a "issnltables"  folder
 2. test at terminal with `$ php issnltables2sql.php`
 3. run all with your database: `$ php issnltables2sql.php all | psql -h localhost -U postgres base`
 4. if you not using `lib` schema, create it at your database, `CREATE SCHEMA lib`
 5. install the lib: `$ psql -h localhost -U postgres base < lib.sql`
 6. if not use for another thing, `rm -r issnltables` and `rm issnltables.zip`

## Resolving ##
...

### With SQL ###

Use the function `lib.issnl_get()` ... Examples:

* SELECT lib.issnl_get(8755999);     -- returns 8755999
* SELECT lib.issnl_get('8755-9994'); -- returns 8755999
* SELECT lib.issnl_get(115);     -- returns 67
* SELECT lib.issn_convert(lib.issnl_get(8755999)) -- returns 8755-9994
* SELECT lib.issn_convert(lib.issnl_get(115))     -- returns 0000-0671

### As a webservice ###
The index.php is a simple issn resolver.
...
