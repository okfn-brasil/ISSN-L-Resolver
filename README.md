ISSN-L-resolver
===============

## Introduction
**ISSN** is a standard public [opaque identifier](https://en.wikipedia.org/wiki/Unique_identifier) for [periodical publications](https://en.wikipedia.org/wiki/Periodical_publication)  &mdash; like  magazines, government gazettes, scientific journals,  and yearbooks  &mdash;, assigned by the [ISSN-ORG authority](http://www.issn.org). ISSN is also an valid URN, with [persistense assurance](https://www.iana.org/assignments/urn-formal/issn).

Its main function is to be a short alias for the [systematic name](https://en.wikipedia.org/wiki/Systematic_name) of the publication, uniquely identifying its [contents intellectual property](https://en.wikipedia.org/wiki/Indecs_Content_Model) (see ISSN-L) or its [published media types](https://en.wikipedia.org/wiki/Media_(communication)).

All media types of the same periodical (same systematic name and contents authority) are gruped as one unique ID, elected between the media's ISSNs, that is the [*ISSN-L*](https://en.wikipedia.org/wiki/ISSN#Linking_ISSN) (short for *linking ISSN*) of the periodical. In this context we can say that ISSN-L is the *canonical name* of the periodic.

ISSN-L is a unique identifier for all versions of the serial containing the same content across different media. As defined by ISO 3297:2007, the ISSN-L provides a mechanism for collocation or linking among the different media versions of the same continuing resource.

### URN resolution

Example from [iana.org/urn-formal/issn](https://www.iana.org/assignments/urn-formal/issn), the same journal can have an *eletronic-ISSN* and a *print-ISSN*, which identifies its electronic and printed publications separately:

> URN:ISSN:1234-1231 identifies the current print edition of "Medical News".

> URN:ISSN:1560-1560 identifies the current online edition of "Medical News".

> The ISSN-L linking both media versions of "Medical News" happens to be ISSN-L 1234-1231 (i.e based on the ISSN 1234-1231, designated as such in the framework of the management of the ISSN Register).

> The resolution of URN:ISSN:1234-1231 should be equivalent to the resolution of URN:ISSN:1560-1560; i.e., in both cases one should find a reference to the other media version.

The example make it clear, an **ISSN-L resolver** MUST to convert any ISSN to its corresponding [ISSN-L](https://en.wikipedia.org/wiki/ISSN#Linking_ISSN). In this project we adopted  a lightweight SQL structure:

```sql
   CREATE TABLE issn.intcode (
      issn integer NOT NULL PRIMARY KEY,
      issn_l integer NOT NULL
    );
```

The core of the *ISSN-L resolver* solution is a SQL script wrote for PostgreSQL, in PL/pgSQL language. It also offers functions to format and validate ISSN strings from the front-end, webservices or back-end.

## Synopsis ##

The project has three main issues:

  1. A (SQL+PHP) "installer" that converts the (updated) "ISSN to ISSN-L" TXT table into a SQL table of integers (ISSN numbers without the *check digit*).
  2. An SQL-service-kit for ISSN resolution.
  3. A webservice formalized by an OpenAPI description, and also implemented in SQL (+PHP+NGINX), for ISSN resolution.

The set of functions was implemented in modules named by is SQL-schemas:

 * The `lib.sql`, which offers a resolver with all "resolution operations" ([RFC2169](http://tools.ietf.org/html/rfc2169) inspired orthogonal instruction set), a converter and an ISSN handling system.

 * An Nginx application (here using an  PHP-middleware example) to expose the resolution into a simple and friendly set of webservice [endpoints](http://www.ibm.com/developerworks/webservices/library/ws-restwsdl/), encouraging its use as [intelligible permalinks](https://en.wikipedia.org/wiki/Permalink).

 * Schema API, with the webservice controller, implemented as SQL function, that mediate Apache and SQL.

## Installing database ##

Run all SQL steps of [`src`](src). For a default database connection, at Linux terminal, you can use:

```
git clone https://github.com/okfn-brasil/ISSN-L-Resolver.git
cd ISSN-L-Resolver
PGPASSWORD=postgres psql -h localhost -U postgres  issnl < src/step1-schema.sql
PGPASSWORD=postgres psql -h localhost -U postgres  issnl < src/step2-lib.sql
PGPASSWORD=postgres psql -h localhost -U postgres  issnl < src/step3-api.sql
```

You can test functions with no database check by `psql -n`, but do better using the test-kit after populating, with the `step5-assert.sql`, as in the instructions below.

## Populating ##

In order to have access to the txt data of correspondence ISSN/ISSN-L,  fill the form on ISSN-ORG website:

 http://www.issn.org/services/online-services/access-to-issn-l-table/

then, you download a 18Mb zip file,

     issnltables.zip

but only a half (9Mb) is about "ISSN to ISSN-L" table, and, at SQL database, with numbers as integers (4 bytes), you can use less space.
With `issnltables2sql.php` you can convert the file into SQL and then run `psql` to populate. See a test dump  [issnltables.zip](https://github.com/okfn-brasil/videos/raw/master/evento/issnltables.zip)

### Instructions for populating ###

For demo you can use non-regurlar-update from [this zip](https://github.com/okfn-brasil/videos/raw/master/projeto/ISSN-L-Resolver/ISSN-to-ISSN-L.txt.zip).

After install database (see above section) and test populating script with `$ php src/step4-issnltables2sql.php`,
the following summarize what will express as shell-script below:
 1. unzip your updated issnltables.zip in a "issnltables"  folder (or the demo zip cited above)
 2. run step4 with `all` parameter,  piping to database.
 3. optional, run and (visual) check tests.
 4. optional, `rm -r issnltables` and `rm issnltables.zip`


```sh
# cd ISSN-L-Resolver
unzip issnltables.zip -d issnltables
php src/step4-issnltables2sql.php all | PGPASSWORD=postgres psql -h localhost -U postgres  issnl
PGPASSWORD=postgres psql -h localhost -U postgres  issnl < src/step5-assert.sql | more
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

PS: in a next version we can include also URL of the periodic, for N2U, U2C, etc.

### With SQL ###

Typical uses for resolver functions (same as `step5-assert`  script):

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
  SELECT issn.n2ns(8755999);    SELECT issn.xservice_jspack(8755999,'n2ns');
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
