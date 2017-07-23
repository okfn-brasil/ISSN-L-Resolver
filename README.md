ISSN-L-resolver
===============

**ISSN** is a standard public [opaque identifier](https://en.wikipedia.org/wiki/Unique_identifier) for [journals](https://en.wikipedia.org/wiki/Periodical_publication), assigned by the [ISSN-ORG authority](http://www.issn.org). Its main function is to be a short alias for the [systematic name](https://en.wikipedia.org/wiki/Systematic_name) of the journal, uniquely identifying the publication content (*ISSN-L*) or a specific [media type](https://en.wikipedia.org/wiki/Media_(communication)) of the publication. In the latter case, for example, the same journal can have an *eletronic-ISSN* and a *print-ISSN*, which identifies its electronic and printed publications separately.

The **ISSN-L resolver** converts any ISSN to its corresponding [ISSN-L](https://en.wikipedia.org/wiki/ISSN#Linking_ISSN) ("linking ISSN") using a lightweight SQL structure:

  ````sql
   CREATE TABLE issn.intcode (
      issn integer NOT NULL PRIMARY KEY,
      issn_l integer NOT NULL
    );
   CREATE INDEX issn_idx1 ON issn.intcode(issn_l);     
  ````

The core of the *ISSN-L resolver* solution is a SQL script wrote for PostgreSQL, in PL/pgSQL language. It also offers functions to format and validate ISSN strings from the front-end, webservices or back-end.

## Synopsis ##
The project has two main issues:

  * A (PHP) "installer" that converts the (updated) "ISSN to ISSN-L" TXT table into a SQL table of integers (ISSN numbers without the *check digit*).
  * A webservice for ISSN resolution.

The webservice was implemented in three parts:

 1. The `lib.sql`, which offers a resolver with all "resolution operations" ([RFC2169](http://tools.ietf.org/html/rfc2169) inspired orthogonal instruction set), a converter and an ISSN handling system.

 2. An Apache2 application (here `.httpAccess` pointing to the PHP example) to expose the resolution into a simple and friendly set of webservice [endpoints](http://www.ibm.com/developerworks/webservices/library/ws-restwsdl/), encouraging its use as [intelligible permalinks](https://en.wikipedia.org/wiki/Permalink).

 3. The webservice controller, implemented as a PHP script, that mediate Apache and SQL.

## Installing database ##

Run all SQL steps of [`src`](src). For a default database connection, at Linux terminal, you can use:

```
git clone https://github.com/okfn-brasil/ISSN-L-Resolver.git
cd ISSN-L-Resolver
PGPASSWORD=postgres psql -h localhost -U postgres  issnl < src/step1-schema.sql
PGPASSWORD=postgres psql -h localhost -U postgres  issnl < src/step2-lib.sql
PGPASSWORD=postgres psql -h localhost -U postgres  issnl < src/step3-api.sql
```
To test populating script use `php src/step4-issnltables2sql.php`, to test functions with no database check by ` psql`.

## Populating ##

In order to have access to the txt data of correspondence ISSN/ISSN-L,  fill the form on ISSN-ORG website:

 http://www.issn.org/services/online-services/access-to-issn-l-table/

then, you download a 18Mb zip file,

     issnltables.zip

but only a half (9Mb) is about "ISSN to ISSN-L" table, and, at SQL database, with numbers as integers (4 bytes), you can use less space.
With `issnltables2sql.php` you can convert the file into SQL and then run `psql` to populate. See a test dump  [issnltables.zip](https://github.com/okfn-brasil/videos/raw/master/evento/issnltables.zip)

### Instructions for populating ###

For demo you can use non-regurlar-update from [this zip](https://github.com/okfn-brasil/videos/raw/master/projeto/ISSN-L-Resolver/ISSN-to-ISSN-L.txt.zip).

Sumary of the shell-script that will following,

 1. after install database (see above section).
 2. unzip your updated issnltables.zip in a "issnltables"  folder (or the demo zip cited above)
 3. test populating script with `$ php src/step4-issnltables2sql.php`
 4. run with `all` parameter,  piping to database.
 5. optional, `rm -r issnltables` and `rm issnltables.zip`

So, **start to install**. With `PGPASSWORD=postgres psql -h localhost -U postgres` run `CREATE database issnl;` to create a database. Go to the working folder and run his shell script:

```sh
cd ISSN-L-Resolver
unzip issnltables.zip -d issnltables
php src/step4-issnltables2sql.php all | PGPASSWORD=postgres psql -h localhost -U postgres  issnl
```

## Resolving ##
The "ISSN resolver" is a simple information retrivial service that returns integer or canonical ISSNs as response.
The resolution operation names was inspired in the [RFC2169 jargon](http://tools.ietf.org/html/rfc2169), for generic URNs,

* N2C  = returns the canonical (preferred) URN of an input-URN.
* N2Ns = returns a set of URNs related to the input-URN.
* N2L  = [not implemented] returns or redirects to the main URL of an input-URN.
* N2Ls = [not implemented] returns all the URLs related to the input-URN.
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
  SELECT issn.isC(115);         SELECT issn.isC('8755-9994');
  -- returns          NULL          1
  SELECT issn.isN(115);         SELECT issn.isN('8755-9995');
  -- returns             1          2
  SELECT issn.n2c(8755999);     SELECT issn.n2c('8755-9994');
  -- returns           8755999      8755999
  SELECT issn.n2c(115);         SELECT issn.cast(issn.n2c(8755999));
  -- returns            67          8755-9994
  SELECT issn.n2c(8755999);     SELECT issn.cast(issn.n2c(115));
  -- returns           8755999      0000-0671
  SELECT issn.n2ns(8755999);    SELECT issn.xservice(8755999,'n2ns');
  -- returns          {8755999}     <ret status="sucess"><issn>8755-9994</issn></ret>
  SELECT issn.n2ns_formated(115);
  -- returns {0000-0671,0000-1155,0065-759X,0065-910X,0068-0540,0074-6827,1067-8166}
```
### With the DEMO ###
See  `/demo` folder or a *live demo* at  [`api.ok.org.br`](http://api.ok.org.br) <!--or [`cta.if.ufrgs.br/ISSN-L`](http://cta.if.ufrgs.br/ISSN-L/index.php).-->

### With webservice (API) ###


For [OpenApi](http://openapis.org)'s ISSN-API definition, see [swagger.yaml](swagger.yaml) (from [*ISSN-L-resolver/1.0.1*](https://app.swaggerhub.com/apis/ppKrauss/ISSN-L-resolver/1.0.1)) or http://api.ok.org.br#issn.

For server resolver middleware, see [src/resolve.php](src/resolve.php). The middleware can serverd by [NGINX](NGINX.org) with other API's (eg. `getdoc`, `getfrag`, etc.) as this Nginx configurartion script:

```sh
server {
        server_name api.myexample.org;
        root   /var/www/api.myexample.org;
        index  index.php index.html index.htm;
        location / {
                try_files $uri $uri/ @rewriteIt;
        }
        location  @rewriteIt {
                rewrite ^/?(issn|getfrag|trazdia|getdoc)/
                        /resolver.php?$uri  last;
                rewrite ^/?(.*)$
                        /error.php?$1       last;
        }
        location ~ \.php$ {
                try_files $uri =404;
                include /etc/nginx/fastcgi.conf;
                fastcgi_pass unix:/run/php/php7.0-fpm.sock;
        }
        # optional include snippets/ssl-myexample.org.conf;
} #end server
```
