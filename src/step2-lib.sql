--
-- lib.issnl_get() and some util functions.
-- See Radme.md for CREATE TABLE and INDEX. Using "library" (lib) schema.
-- v1.0-2014 of https://github.com/ppKrauss/ISSN-L-resolver
--

CREATE SCHEMA IF NOT EXISTS issn;  -- general commom library.


CREATE OR REPLACE FUNCTION issn.info_refresh(date) RETURNS void AS $func$
  --
  -- DELETE and relace info by fresh one. Use only when updating.
  --
  DELETE FROM issn.info;
  INSERT INTO issn.info SELECT $1 AS updated_issn, * FROM issn.stats;
$func$ LANGUAGE SQL;


-- -- -- -- -- -- -- -- -- -- --
-- text ISSN util functions   --

CREATE OR REPLACE FUNCTION issn.format(text)
  --
  -- Transform a "free ISSN" string in a well-formated standard one.
  --
  RETURNS text AS       -- a formated ISSN
$func$
  SELECT CASE WHEN $1 is null OR trim($1)='' THEN NULL
         ELSE regexp_replace(upper(regexp_replace($1, '[\- ]+', '')), '^(.{4,4})(.{4,4})', '\1-\2')
         END;
$func$ LANGUAGE sql IMMUTABLE;


CREATE OR REPLACE FUNCTION issn.check(issn text)
  --
  -- Checks the check digit of a ISSN string (free or formated).
  --
  RETURNS boolean AS    -- true when check digit is correct
$func$
DECLARE
  pos INTEGER;
  casc INTEGER;
  sum INTEGER DEFAULT 0;
  weight INTEGER[] DEFAULT '{8,7,6,5,4,3,2,1}';
  digits INTEGER DEFAULT 1;
BEGIN
  issn := upper(translate(ISSN, '-', '')); -- without hiphen
  IF issn IS NULL or length(issn)!=8 THEN
    return NULL; -- error
  END IF;
  FOR pos IN 1..length(ISSN) LOOP
    casc := ascii(substr(ISSN,pos,1));
    IF casc=88 THEN -- control number X
      sum := sum + 10;
      digits := digits + 1;
    ELSIF casc >= 48 AND casc <= 57 THEN
      sum := sum + (casc - 48)*weight[digits];
      digits := digits + 1;
    END IF;
  END LOOP;
  IF digits <> 9 THEN
    RETURN false;
  ELSE
    RETURN (sum % 11) = 0;
  END IF;
END;
$func$ LANGUAGE PLpgSQL IMMUTABLE;

CREATE OR REPLACE FUNCTION issn.cast(text) RETURNS int AS $func$
  --
  -- Converts a "free ISSN string" into a integer ISSN.
  --
  SELECT  substr(translate(trim($1), '-', ''),1,7)::int
$func$ LANGUAGE SQL IMMUTABLE;

-- -- -- -- -- -- -- -- -- --
-- int ISSN util functions --

CREATE OR REPLACE FUNCTION issn.digit8(int)
  --
  -- Calculates the "check digit" of an integer ISSN.
  --
  RETURNS CHAR AS       -- check digit
$func$
DECLARE
  ISSN VARCHAR;
  pos INTEGER;
  casc INTEGER;
  sum INTEGER DEFAULT 0;
  weight INTEGER[] DEFAULT '{8,7,6,5,4,3,2,1}';
  digits INTEGER DEFAULT 1;
  aux text := '';
BEGIN
  ISSN := trim(to_char($1, '0000000'));
  IF $1 IS NULL OR $1>9999999 OR $1<1 THEN
	   RETURN NULL; -- ERROR
  END IF;
  FOR pos IN 1..length(ISSN) LOOP
    casc := ascii(substr(ISSN,pos,1));
    -- INT HAVE casc >= 48 AND casc <= 57 THEN
    aux:=aux||'.'||casc;
      sum := sum + (casc - 48)*weight[digits];
      digits := digits + 1;
  END LOOP;
  sum:=sum % 11; -- reuse sum for remainder
  IF sum=0 THEN
	RETURN '0';
  ELSE
	sum := 11-sum;
	RETURN CASE WHEN sum=10 THEN 'X' ELSE sum::char END;
  END IF;
END;
$func$ LANGUAGE PLpgSQL IMMUTABLE;

-- depends on digit8
CREATE OR REPLACE FUNCTION issn.cast(int)  RETURNS text AS $func$
  --
  -- Converts an "integer ISSN" into a standard text ISSN.
  -- Must be used only for database's oficial ISSNs.
  --
  SELECT trim(to_char($1, '0000-000')||issn.digit8($1));
$func$ LANGUAGE SQL IMMUTABLE;

-- -- -- -- -- -- -- -- -- -- -- --
-- ISSN resolving services       --
-- (complete and symmetric set)  --
-- isC, isN, N2C, N2Ns, N2Ns_formated

CREATE OR REPLACE FUNCTION issn.isC(int)  RETURNS smallint AS $func$
  --
  -- Returns 1 when input is an ISSN-L, NULL when is bigger than max, 0 otherwise.
  SELECT COALESCE(
    (SELECT  1::smallint as r  FROM issn.intcode WHERE issn_l=$1 LIMIT 1),
    (SELECT  CASE WHEN $1<=issn_max AND $1>0 THEN 0 ELSE NULL END  FROM issn.info)::smallint
  );
$func$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION issn.isC(text)  RETURNS smallint AS $func$
  --
  -- Same as issn.isC(int), but casting and checking text input.
  -- Returns 2 when digit is invalid or has no check-digit.
  --
  SELECT CASE WHEN NOT(issn.check($1)) THEN r*2::smallint ELSE r END
  FROM (
    SELECT issn.isC( issn.cast($1) ) as r
  ) as t;
$func$ LANGUAGE SQL IMMUTABLE;


CREATE OR REPLACE FUNCTION issn.isN(int)  RETURNS smallint AS $func$
  --
  -- Check if it is a valid name. Returns 1 when input is an ISSN,
  -- returns NULL when is bigger than max, 0 otherwise.
  -- NOTE: "isN service" in the RFC2169 jargon.
  SELECT COALESCE(
    (SELECT 1::smallint as r FROM issn.intcode WHERE issn=$1),
    (SELECT  CASE WHEN $1<=issn_max AND $1>0 THEN 0::smallint ELSE NULL::smallint END  FROM issn.info)
  );
$func$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION issn.isN(text)  RETURNS smallint AS $func$
  --
  -- Same as issn.isN(int), but casting and checking text input.
  -- Returns 2 when digit is invalid or has no check-digit.
  --
  SELECT CASE WHEN NOT(issn.check($1)) THEN r+1::smallint ELSE r END
  FROM (
    SELECT issn.isN( issn.cast($1) ) as r
  ) as t;
$func$ LANGUAGE SQL IMMUTABLE;


CREATE OR REPLACE FUNCTION issn.N2C(int)  RETURNS int AS $func$
  --
  -- Returns the integer ISSN-L of any integer ISSN.
  -- Returns NULL if the input not exists.
  -- NOTE: is a "N2N service" in the RFC2169 jargon,
  --       but specifically a "N2C" because returns the Canonic URN.
  --
  SELECT issn_l FROM issn.intcode WHERE issn=$1;
$func$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION issn.N2C(text)  RETURNS int AS $func$
  --
  -- Same as issn.N2C(int), but casting text inputs.
  --
  SELECT issn.N2C( issn.cast($1) );
$func$ LANGUAGE SQL IMMUTABLE;


CREATE OR REPLACE FUNCTION issn.N2Ns(int)  RETURNS int[] AS $func$
  --
  -- Returns all ISSNs linked to a ISSN.
  -- Returns NULL if the input not exists.
  -- Is a "N2Ns service" in the RFC2169 jargon.
  -- NOTE: very slow if not using issn_idx1.
  --
  SELECT array_agg(issn ORDER BY issn)
  FROM issn.intcode
  WHERE issn_l=issn.N2C($1);
$func$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION issn.N2Ns(text)  RETURNS int[] AS $func$
  --
  -- Same as issn.N2Ns(int), but casting text input.
  --
  SELECT issn.N2Ns( issn.cast($1) );
$func$ LANGUAGE SQL IMMUTABLE;


CREATE OR REPLACE FUNCTION issn.N2Ns_formated(int)  RETURNS text[] AS $func$
  --
  -- Same as issn.N2Ns(int), but returning text formated ISSNs
  --
  SELECT array_agg(issn.cast(issn) ORDER BY issn)
  FROM issn.intcode
  WHERE issn_l=issn.N2C($1);
$func$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION issn.N2Ns_formated(text)  RETURNS text[] AS $func$
  --
  -- Same as issn.N2Ns_formated(int), but casting text input.
  --
  SELECT issn.N2Ns_formated( issn.cast($1) );
$func$ LANGUAGE SQL IMMUTABLE;


-- -- -- -- -- -- -- -- -- -- --
-- Services, T=text, X=XML and J=JSON --

CREATE OR REPLACE FUNCTION issn.tservice(
  --
  -- Performs a "issn.*()" function and returns into a plain text.
  --
  int,        -- $1 the command argument
  cmd   text  -- $2 the command (isC, isN, N2C, N2Ns, N2Ns_formated)
)  RETURNS text AS $func$
BEGIN
  cmd := lower(cmd);
  RETURN COALESCE(
  CASE WHEN cmd='isc' THEN  issn.isc($1)::text
       WHEN cmd='isn' THEN  issn.isn($1)::text
       WHEN cmd='n2c' THEN  issn.cast(issn.n2c($1))::text
  -- erro falta fixar delimitador com join_array
       WHEN cmd='n2ns' THEN trim( issn.n2ns_formated($1)::text, '{}')
       ELSE 'unknowing command'
   END, ''); -- case
END;
$func$ LANGUAGE plpgsql IMMUTABLE;
CREATE OR REPLACE FUNCTION issn.tservice(text,text)  RETURNS text AS $func$
  --
  -- Same as issn.tservice(int,text), but casting text input.
  --
  SELECT issn.tservice( issn.cast($1), $2 );
$func$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION issn.xservice(
  --
  -- Performs a "issn.*()" function and returns into a XML.
  --
  int,        -- $1 the command argument
  cmd   text  -- $2 the command (isC, isN, N2C, N2Ns, N2Ns_formated)
)  RETURNS xml  AS $func$
BEGIN
  cmd := lower(cmd);
  RETURN CASE
   WHEN cmd='isc' THEN
    xmlelement(  name ret,  COALESCE(issn.isc($1)::text,'') )
   WHEN cmd='isn' THEN
    xmlelement(  name ret,  COALESCE(issn.isn($1)::text,'') )
   WHEN cmd='n2c' THEN
    xmlelement(  name ret,   COALESCE(issn.cast(issn.n2c($1)),'') )
   WHEN cmd='n2ns' THEN (
      SELECT xmlelement(  name ret,  xmlattributes('sucess' as status),  xmlagg(xmlelement(name issn,i))  )
      FROM  (SELECT unnest( issn.n2ns_formated($1) ) as i ) as t
     )
   ELSE
        xmlelement(  name ret,  xmlattributes('error' as status, 1 as cod), 'unknowing command' )
   END; -- case
END;
$func$ LANGUAGE plpgsql IMMUTABLE;
CREATE OR REPLACE FUNCTION issn.xservice(text,text)  RETURNS xml AS $fwrap$
  --
  -- Same as issn.xservice(int,text), but casting text input.
  --
  SELECT issn.xservice( issn.cast($1), $2 );
$fwrap$ LANGUAGE SQL IMMUTABLE;


CREATE OR REPLACE FUNCTION issn.jservice(
  --
  -- Performs a "issn.*()" function and returns into a JSON.
  --
  int,        -- $1 the command argument
  cmd   text  -- $2 the command (isC, isN, N2C, N2Ns, N2Ns_formated)
)  RETURNS JSONb  AS $func$
BEGIN
  cmd := lower(cmd);
  RETURN
  CASE WHEN cmd='isc' THEN
    to_jsonb(  COALESCE(issn.isc($1),null) )
   WHEN cmd='isn' THEN
    to_jsonb(  COALESCE(issn.isn($1),null) )
   WHEN cmd='n2c' THEN
    to_jsonb(  COALESCE(issn.cast(issn.n2c($1)),null) )
   WHEN cmd='n2ns' THEN (
     SELECT to_jsonb( xmlagg(xmlelement(name issn,i)) )
     FROM  (SELECT unnest( issn.n2ns_formated($1) ) as i ) as t
    )
   ELSE
      jsonb_build_object('status','error',  'cod',1,  'error_message','unknowing command')
   END; -- case
END;
$func$ LANGUAGE plpgsql IMMUTABLE;
CREATE OR REPLACE FUNCTION issn.jservice(text,text)  RETURNS jsonb AS $fwrap$
  --
  -- Same as issn.jservice(int,text), but casting text input.
  --
  SELECT issn.jservice( issn.cast($1), $2 );
$fwrap$ LANGUAGE SQL IMMUTABLE;

---- API parsers



CREATE OR REPLACE FUNCTION array_pop_off(ANYARRAY) RETURNS ANYARRAY AS $f$
    SELECT $1[2:array_length($1,1)];
$f$ LANGUAGE sql IMMUTABLE;





CREATE OR REPLACE FUNCTION issn.parse1_uri(
  --
  -- Converts a URI of any API into 3 parts: api-name, api-path and api-output.
  -- Need to enconde here (future by database) the api-output-default.
  --
	text  -- an URI, ex. from NGINX's proxy parsing.
)   RETURNS text[] AS
$func$
	DECLARE
		aux text[];
		vaux text[];
		apiname text;
		apivers text;
		apivers_defaults json;
		apiout text;
		apiout_defaults json;
		ext_rgx text;
		vers_rgx text;
		lastp text;
	BEGIN
		vers_rgx := '\-[vV]?(\d[\d\.]*)$';
		ext_rgx := '\.(json|xml|txt)$';
		apiout_defaults := '{"issn":"json","getfrag":"json"}'::json;
		apivers_defaults := '{"issn":["1.0.1","1.0.0"],"getfrag":["1.0.0"]}'::json;

		aux := regexp_split_to_array($1, '/');
		IF array_length(aux,1)<2 THEN 
			RETURN array[NULL,'1','path need more itens'];
		END IF;
		apiName := lower(aux[1]);
		aux := array_pop_off(aux);
		vaux := regexp_matches(apiname,vers_rgx);
		IF (array_length(vaux,1)=1) THEN 
			apivers := vaux[1];
			apiName := regexp_replace(apiName,vers_rgx,''); 
		ELSE
			IF apivers_defaults->apiName IS NULL THEN
	 			RETURN array[NULL,'2','name not exists'];
			END IF;
			apivers = (apivers_defaults->apiName)->>1;
		END IF;
		lastp := aux[array_length(aux,1)];
		vaux := regexp_matches(lastp,ext_rgx);
		IF (array_length(vaux,1)=1) THEN 
			apiout := vaux[1];
			aux[array_length(aux,1)] := regexp_replace(lastp,ext_rgx,'');
		ELSE
			apiout := apiout_defaults->>apiName; -- validar caso null
		END IF;
		RETURN array[apiName, apivers, apiout, array_to_string(aux,'/')];
	END;
$func$ LANGUAGE PLpgSQL IMMUTABLE;
