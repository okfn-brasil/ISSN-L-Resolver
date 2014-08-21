ISSN-L-resolver
===============

An **ISSN** is a standard public [opaque identifier](https://en.wikipedia.org/wiki/Unique_identifier) for [journals](https://en.wikipedia.org/wiki/Periodical_publication), assigned by the [ISSN-ORG authority](http://www.issn.org). It's most frequent use, is to be a short alias name for the [systematic name](https://en.wikipedia.org/wiki/Systematic_name) of the journal, uniquely identifying  the publication content (*ISSN-L*) or specific [media type](https://en.wikipedia.org/wiki/Media_(communication)) of the publication (other ISSNs like *eletronic-ISSN* and *print-ISSN*).

The **ISSN-L resolver** converts, with SQL, any ISSN to it's correspondent [ISSN-L](https://en.wikipedia.org/wiki/ISSN#Linking_ISSN) ("linking ISSN"), using a  lightweight structure,

  ````sql
   CREATE TABLE lib.issn_l (
      issn integer NOT NULL PRIMARY KEY,
      issn_l integer NOT NULL
    );
   CREATE INDEX issn_idx1 ON lib.issn_l(issn_l);     
   -- about need for indexes, see lib.issn_N2Ns() function.
  ````

The core of the *ISSN-L resolver* solution is a SQL script writed for PostgreSQL, in PL/pgSQL language. It  offer also funcions to format and to validate string-ISSNs of the front-end, webservices or back-services.

## Synopsis ##
The project have 3 issues:

 1. A PHP script that converts the (updated) "ISSN to ISSN-L" TXT table, into a SQL table of integers (ISSN numbers without the *check digit*).

 2. The `lib.sql`, that offers a resolver and all king of util convertion and ISSN handling, inclung *check digit* reconstruction.

 3. An Apache2 aplication (here with a PHP example) to expose the resolution into a simple and friendly set of web-service endpoints.

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
The "ISSN resolver" is a simple information retrivial service that returns integer or canonical ISSNs as response. 
The resolution operation names was inspired in the [RFC2169 jargon](http://tools.ietf.org/html/rfc2169), for generic URNs,

* N2L  = returns the main URL of an input-URN.
* N2Ns = returns a set of URNs related to the input-URN. 
* N2Ls = returns all the URLs related to the input-URN.
* N2C  = returns the canonical (preferred) URN of an input-URN.
* list = retrieves all component URNs (or its metadata), when component entities exists.
* info (default) = retrieves catalographic information or metadata of the (entity of the) URN.

The letters in these *standard operation names* are used in the following sense:

 * "C": the canonic URN string (the "official string" and unique identifier); non-RFC2169 jargon;
 * "N": URN, *canonical* or *"reference URN"* (a simplified non-ambiguous version of the canonical one);
 * "L": URL (main URL is a http and secondary can by also ftp and mailto URLs, see RFC2368)
 * "is": "isX" stands "is a kind of X" or "is really a X";
 * "2": stands "to", for convertion services.

### With SQL ###

Typical uses for resolver functions:

```sql
  SELECT lib.issn_isC(115);         SELECT lib.issn_isC('8755-9994');
  -- returns          NULL          1
  SELECT lib.issn_isN(115);         SELECT lib.issn_isN('8755-9995');
  -- returns             1          2
  SELECT lib.issn_n2c(8755999);     SELECT lib.issn_n2c('8755-9994');
  -- returns           8755999      8755999
  SELECT lib.issn_n2c(115);         SELECT lib.issn_cast(lib.issnl_n2c(8755999));
  -- returns            67          8755-9994
  SELECT lib.issn_n2c(8755999);     SELECT lib.issn_cast(lib.issnl_n2c(115));
  -- returns           8755999      0000-0671
  SELECT lib.issn_n2ns(8755999);    
  -- returns        {8755999}
  SELECT lib.issn_n2ns_formated(115);
  -- returns {0000-0671,0000-1155,0065-759X,0065-910X,0068-0540,0074-6827,1067-8166}
```

### With webservice ###

At a webservice's endpoint, ex. `http://ws.myDomain/issn-resolver`, use `xws.` for XML-webservice, `jws.` for JSON-webservice.

**Standard [endpoint](http://www.w3.org/TR/wsdl20/#Endpoint) rule syntax**:

```
    http://<subdomain> "." <domain> "/" <query>
      <subdomain> =  [<catalog-name> "."] <ws-format> 
      <ws-format> = "tws" | "hws" | "jws" | "xws" | "ws"
      <query>     = <urn> | <operation> "/" <urn>
      <urn>       = "urn:" <urn-schema> ":" <urn-value> | <urn-value>
```

that webservice endpoint's are "short URLs", like this request in a "journal" catalog, `http://jou.tws.myExample.org/n2n/123456`.

Another option, if you can not change subdomain, is a not-so-short-URL, with the same information in the path part of [URL](https://en.wikipedia.org/wiki/Uniform_Resource_Locator):

```
    http://"ws." <domain> "/" <query>
      <query>     = <io-format> "/" <operation> "/" <urn>
      <operation> = <io-format> "." <catalog-name> "." <op-name> | <io-format> "." <op-name>
      <io-format> = "text" | "html" | "json" | "xml" | "auto"
      <catalog-name>  = "jou" | "art" | "issue" | "auto"
      <op-name>   = "N2N" | "N2Ns" | "N2C" | "N2Cs" | "N2U" | "N2Us" | "isN"| "isC" | "info"
      <urn>       = "urn:" <urn-schema> ":" <urn-value> | <urn-value>
```

any other bigger or complex parameter, must use HTTP POST, or send GET parameters in an usual query-URL (using ex. the [OpenURL standard](https://en.wikipedia.org/wiki/OpenURL)).

The alone `<urn-value>` is for local default URN schemas, when exist (ex. a subdomain where only ISSN is used, not need to express all "urn:issn:" prefix). The `<operation> "/" <urn>` option is usual in contexts where is difficult to solicitate more `<specific-name>` subdomains for each operation.

The `<ws-format>` convention is
 * "h" for HTML format, in a "human readable" usual context.
 * "x" for XML format in a WSDL2 webservice context.
 * "j" for JSON format, in a JOSN-RPC or similar context.
 * "t" for old *MIME text/plain* output format, a simplification of the XML output, for tests and terminal debuging.

The "ws" `<ws-format>` is a "web-service catalog describer" endpoint, describing each endpoint, by some format (in a `/html`, `/txt`, `/json`, or `/xml` format).

Example: `http://issn.jws.example.org/1234-9223` returns the default operation for the standard query, that is something like a [catalog card](https://en.wikipedia.org/wiki/Library_catalog#Catalog_card) of the corresponding journal.

**Standard operations**: a [WSDL file](https://en.wikipedia.org/wiki/WSDL#Example_WSDL_file) describes services as collections of network endpoints, so, in the same intention, this document describes a set of interoperable endpoints focusing on the handling of ISSN-URNs. As suggested by the [old IETF's RFC-2169](http://tools.ietf.org/html/rfc2169), some typical *"ISSN resolution"* services can be offered, in response to the `<query>`,

 * *N2C*: the *ISSN-L* of the input. See SQL `lib.issnl_n2c()`.
 * *N2Ns*: all the ISSNs grouped by a ISSN-L associated with the input. See SQL `lib.issnl_n2ns()`.
 * *N2U*: the "journal's official URL", where "official" is in the context of the webservice server entity. No implementation here, only an illustrative operation.
 * *N2Us*: all the "journal's URLs", when exist more than one. No implementation here, only an illustrative operation.
 * *isN*: check if a query string is a valid ISSN (registered in the database).
 * *isC*: like *isN* but also checking format. See SQL `lib.issn_check()`.
 * *info*: the *card catalog* of the object pointed by the URN. Illustrative.

These basic ISSN resolution operations, solves most of the commom interoperability problems. Of course, any other simple (1 operand) operation can be add as new `op-name` or a (2 or more operands) as a complete URL.

#### Endpoint URL examples
URL example and description:

 * `http://jou.tws.myExample.org/n2n/123456` - Context="journal", io-format="text", operation="n2n" (resolve name replaying name), URN=123456 (using default URN-schema=issn and reference-URN). 
 * `http://ws.myExample.org/text.jou.n2n/123456` - idem above, but with context and format at path. 
 * `http://ws.myExample.org/text.auto/0123-456X` - similar to above, but with default operation (`info`) and default (or auto-detect) URN-schema.
 * ...
 * `http://jou.tws.myExample.org/n2n/urn:issn:123456` - ...
 * ...
 * `http://jou.tws.myExample.org/?cmd=n2n&q=urn:issn:123456` - ...
 * ...
 
## Implementations ##
Some notes about each specific implementation.

### PostgreSQL library ###
...

### Apache2 .htaccess ###
On the VirtualHost's `DocumentRoot` directory of the mapped `ServerName` (`<subdomain>.<domain>`), add the folowing `.htaccess` file, for an `<operation> "/" <urn>` endpoint syntax option:

```
RewriteEngine on

# If requested url is an existing file or folder, don't touch it
RewriteCond %{REQUEST_FILENAME} -d [OR]
RewriteCond %{REQUEST_FILENAME} -f
RewriteRule . - [L]

# If we reach here, this means it's not a file or folder, we can rewrite...
RewriteRule ^(?:urn:(issn):)?([0-9][\d\-]*X?)$                           index.php?cmd=std&urn_schema=$1&q=$2 [L]
RewriteRule ^(n2ns?|n2us?|isn|isc)/(?:urn:(issn):)?([0-9][\d\-]*X?)$     index.php?cmd=$1&urn_schema=$2&q=$3 [L]
```

### PHP webservices ###
... index.php ...
