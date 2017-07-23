--
-- lib.issnl_get() and some util functions.
-- See Radme.md for CREATE TABLE and INDEX. Using "library" (lib) schema.
-- v1.0-2014 of https://github.com/ppKrauss/ISSN-L-resolver
--


CREATE SCHEMA IF NOT EXISTS issn; -- ISSN-only library.

CREATE SCHEMA IF NOT EXISTS lib;  -- general commom library.

------------------------
-- General-use array functions from (std) LIB

CREATE or replace FUNCTION lib.array_pop_off(ANYARRAY) RETURNS ANYARRAY AS $f$
    SELECT $1[2:array_length($1,1)];
$f$ LANGUAGE sql IMMUTABLE;

CREATE or replace FUNCTION lib.json_array_castext(json) RETURNS text[] AS $f$
  SELECT array_agg(x)
  FROM json_array_elements_text($1) t(x);
$f$ LANGUAGE sql IMMUTABLE;

-- -- -- -- -- -- -- -- -- -- --

CREATE or replace FUNCTION issn.info_refresh(
  p_updated_date date,
  p_updated_file text
) RETURNS void AS $func$
  --
  -- DELETE and relace info by fresh one. Use only when updating.
  --
  DELETE FROM issn.info;
  INSERT INTO issn.info
    SELECT
        NULL::jsonb as api_spec,
        now() AS thisrecord_created,
        $1 AS updated_date,
        $2 AS updated_file,
        *
    FROM issn.stats;
$func$ LANGUAGE SQL;


-- -- -- -- -- -- -- -- -- -- --
-- text ISSN util functions   --

CREATE or replace FUNCTION issn.format(text)
  --
  -- Transform a "free ISSN" string in a well-formated standard one.
  --
  RETURNS text AS       -- a formated ISSN
$func$
  SELECT CASE WHEN $1 is null OR trim($1)='' THEN NULL
         ELSE regexp_replace(upper(regexp_replace($1, '[\- ]+', '')), '^(.{4,4})(.{4,4})', '\1-\2')
         END;
$func$ LANGUAGE sql IMMUTABLE;


CREATE or replace FUNCTION issn.check(issn text)
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

CREATE or replace FUNCTION issn.cast(text) RETURNS int AS $func$
  --
  -- Converts a "free ISSN string" into a integer ISSN.
  --
  SELECT  substr(translate(trim($1), '-', ''),1,7)::int
$func$ LANGUAGE SQL IMMUTABLE;

-- -- -- -- -- -- -- -- -- --
-- int ISSN util functions --

CREATE or replace FUNCTION issn.digit8(int)
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
CREATE or replace FUNCTION issn.cast(int)  RETURNS text AS $func$
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

CREATE or replace FUNCTION issn.isC(int)  RETURNS boolean AS $func$
  --
  -- Returns 1 when input is an ISSN-L, NULL when is bigger than max, 0 otherwise.
  SELECT COALESCE(
    (SELECT  true  FROM issn.intcode WHERE issn_l=$1 LIMIT 1),
    (SELECT  CASE WHEN $1<=issn_max AND $1>0 THEN false ELSE NULL::boolean END  FROM issn.info)
  );
$func$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION issn.isC(text)  RETURNS boolean AS $func$
  --
  -- Same as issn.isC(int), but casting and checking text input.
  -- Returns NULL when input is out of range or check-digit is invalid.
  --
  SELECT CASE WHEN NOT(issn.check($1)) THEN NULL ELSE r END
  FROM (
    SELECT issn.isC( issn.cast($1) ) as r
  ) as t;
$func$ LANGUAGE SQL IMMUTABLE;


CREATE or replace FUNCTION issn.isN(int) RETURNS boolean AS $func$
  --
  -- Check if it is a valid name. Returns 1 when input is an ISSN,
  -- returns NULL when is bigger than max, 0 otherwise.
  -- NOTE: "isN service" in the RFC2169 jargon.
  SELECT COALESCE(
    (SELECT true FROM issn.intcode WHERE issn=$1),
    (SELECT  CASE WHEN $1<=issn_max AND $1>0 THEN false ELSE NULL::boolean END  FROM issn.info)
  );
$func$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION issn.isN(text)  RETURNS boolean AS $func$
  --
  -- Same as issn.isN(int), but casting and checking text input.
  -- Returns NULL when input is out of range or check-digit is invalid.
  --
  SELECT CASE WHEN NOT(issn.check($1)) THEN NULL::boolean ELSE r END
  FROM (
    SELECT issn.isN( issn.cast($1) ) as r
  ) as t;
$func$ LANGUAGE SQL IMMUTABLE;


CREATE or replace FUNCTION issn.N2C(int)  RETURNS int AS $func$
  --
  -- Returns the integer ISSN-L of any integer ISSN.
  -- Returns NULL if the input not exists.
  -- NOTE: is a "N2N service" in the RFC2169 jargon,
  --       but specifically a "N2C" because returns the Canonic URN.
  --
  SELECT issn_l FROM issn.intcode WHERE issn=$1;
$func$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION issn.N2C(text)  RETURNS int AS $func$
  --
  -- Same as issn.N2C(int), but casting text inputs.
  -- Returns NULL when input is out of range or check-digit is invalid.
  --
  SELECT issn.N2C( issn.cast($1) );
$func$ LANGUAGE SQL IMMUTABLE;


CREATE or replace FUNCTION issn.N2Ns(int)  RETURNS int[] AS $func$
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

CREATE or replace FUNCTION issn.N2Ns(text)  RETURNS int[] AS $func$
  --
  -- Same as issn.N2Ns(int), but casting text input.
  --
  SELECT issn.N2Ns( issn.cast($1) );
$func$ LANGUAGE SQL IMMUTABLE;


CREATE or replace FUNCTION issn.N2Ns_formated(int)  RETURNS text[] AS $func$
  --
  -- Same as issn.N2Ns(int), but returning text formated ISSNs
  --
  SELECT array_agg(issn.cast(issn) ORDER BY issn)
  FROM issn.intcode
  WHERE issn_l=issn.N2C($1);
$func$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION issn.N2Ns_formated(text)  RETURNS text[] AS $func$
  --
  -- Same as issn.N2Ns_formated(int), but casting text input.
  --
  SELECT issn.N2Ns_formated( issn.cast($1) );
$func$ LANGUAGE SQL IMMUTABLE;


-- -- -- -- -- -- -- -- -- -- --
-- Services, T=text, X=XML and J=JSON --

CREATE or replace FUNCTION issn.tservice(
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
CREATE or replace FUNCTION issn.tservice(text,text)  RETURNS text AS $func$
  --
  -- Same as issn.tservice(int,text), but casting text input.
  --
  SELECT issn.tservice( issn.cast($1), $2 );
$func$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION issn.xservice(
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
CREATE or replace FUNCTION issn.xservice(text,text)  RETURNS xml AS $fwrap$
  --
  -- Same as issn.xservice(int,text), but casting text input.
  --
  SELECT issn.xservice( issn.cast($1), $2 );
$fwrap$ LANGUAGE SQL IMMUTABLE;


CREATE or replace FUNCTION issn.jservice(
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
    to_jsonb(  issn.isc($1) )
   WHEN cmd='isn' THEN
    to_jsonb(  issn.isn($1) )
   WHEN cmd='n2c' THEN
    to_jsonb(  issn.cast(issn.n2c($1)) )
   WHEN cmd='n2ns' THEN (
     SELECT to_jsonb( array_agg(i) )
     FROM  (SELECT unnest( issn.n2ns_formated($1) ) as i ) as t
    )
   ELSE
      jsonb_build_object('status','error',  'cod',1,  'error_message','unknowing command')
   END; -- case
END;
$func$ LANGUAGE plpgsql IMMUTABLE;

CREATE or replace FUNCTION issn.jservice(text,text)  RETURNS jsonb AS $fwrap$
  --
  -- Same as issn.jservice(int,text), but casting text input.
  --
  SELECT issn.jservice( issn.cast($1), $2 );
$fwrap$ LANGUAGE SQL IMMUTABLE;


------------------------
-- ANY service

CREATE or replace FUNCTION issn.any_service(
  --
  -- Executes a service. Selector for issn.jservice(), issn.xservice(), etc.
  -- Example: issn.any_service('n2c',1234,'xml');
  p_cmd text,      -- command
  p_issn7 int,     -- ISSN integer. (see also text for full ISSN code)
  p_out text DEFAULT 'json',      -- output datatype.
  p_apivers text DEFAULT '1.0.0',  -- version (can be discard)
  p_status  int DEFAULT 200   -- for returning warnings by status code.
)  RETURNS jsonb AS $f$
  SELECT jsonb_build_object('status',p_status,  'result',result)
  FROM (
    SELECT CASE
      WHEN out='j' THEN issn.Jservice(p_issn7,p_cmd)  -- carregar o status? p_apivers?
      WHEN out='t' THEN to_jsonb(issn.Tservice(p_issn7,p_cmd))
      ELSE to_jsonb(issn.Xservice(p_issn7,p_cmd))
      END AS result
    FROM (SELECT substr(p_out, 1, 1) as out) t1
  ) t2;
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION issn.any_service(text,text,text,text DEFAULT '1.0.0') RETURNS jsonb AS $fwrap$
  --
  -- Same as issn.any_service(text,int,...), but casting text input.
  -- Example: issn.any_service('n2ns','0000-0043','j'); -- or 0000-004X to change status
  --
  SELECT issn.any_service(
    $1, issn.cast($2), $3, $4, CASE WHEN issn.check($2) THEN 200 ELSE 250 END
  );
$fwrap$ LANGUAGE SQL IMMUTABLE;

------------------------
-- API specialized wrap for issn.any_service()

CREATE or replace FUNCTION issn.run_api(
  cmd text,   --
  arg1 text,  -- main command
  p_out text,  -- output type
  p_apivers text
) RETURNS jsonb AS $func$
-- NAO PODE RETORNAR NULL
DECLARE
  api text; -- API full-name
  arg1 text;
  apis_specs json;
  cmd  text;
  cmdlist text[];
BEGIN
  apis_specs := '{"issn-v1.0.1":["isn","isc","n2c","n2ns"],"issn-v1.0.0":["isn","isc","n2c","n2ns"]}'::json;
  api := 'issn-v'||	p_apivers; -- full name
  IF apis_specs->api IS NULL THEN
      RETURN json_build_object('error',533,  'msg','nao achei specs de api='||api);
  END IF;
  cmdlist := lib.json_array_castext(apis_specs->api);
  arg1 := parts[1]; -- ISSN code-string or code-integer.
  IF NOT(cmd = ANY(cmdlist)) THEN
    RETURN jsonb_build_object('error',3,  'msg','nao achei cmd='||cmd );
  END IF;
  IF  POSITION('-' in arg1)>0 OR char_length(arg1)>7 THEN
    RETURN issn.any_service(cmd,arg1,p_out,p_apivers);
  ELSE -- same except cast to int
    RETURN issn.any_service(cmd,arg1::int,p_out,p_apivers);
  END IF;
END
$func$ LANGUAGE PLpgSQL IMMUTABLE;
