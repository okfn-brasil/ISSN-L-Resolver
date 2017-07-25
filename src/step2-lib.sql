/**
 * Library of all ISSN-Resolver functions as an orthogonal set of commands, its API methodos and util functions.
 * See Radme.md for CREATE TABLE and INDEX. Depends ons 'issn', 'lib' and 'api' schemas.
 * See https://github.com/okfn-brasil/ISSN-L-Resolver
 */

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
-- info, isC, isN, N2C, N2Ns, N2Ns_formated

CREATE or replace FUNCTION issn.info()  RETURNS json AS $func$
  -- General database information.
  SELECT to_json(t)
  FROM (SELECT  *  FROM issn.info LIMIT 1) t;
$func$ LANGUAGE SQL IMMUTABLE;

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


-- -- -- --

CREATE or replace FUNCTION issn.info(int)  RETURNS json AS $func$
  -- All informations about ISSN code
  SELECT to_json(t)
  FROM (
    SELECT  issn.isN($1) as "isN", issn.isC($1) as "isC",
      (SELECT t1 FROM (values(issn.cast(issn.N2C($1)), issn.N2Ns_formated($1))) as t1("N2C","N2Ns")) AS "convertions",
      (SELECT t2 FROM (values(issn.N2C($1), issn.N2Ns($1))) as t2("N2C","N2Ns")) AS "int-convertions"
  ) t;
$func$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION issn.info(text) RETURNS json AS $fwrap$
  SELECT issn.info( issn.cast($1) );
$fwrap$ LANGUAGE SQL IMMUTABLE;


-- -- -- -- -- -- -- -- -- -- --
-- Services, T=text, X=XML and J=JSON --

CREATE or replace FUNCTION issn.jservice(
  --
  -- Performs a "issn.*()" function and returns into a JSON.
  -- returns as standard jspack
  --
  int,        -- $1 the command argument
  cmd   text,  -- $2 the command (isC, isN, N2C, N2Ns, N2Ns_formated)
  p_status  int=200,   -- for returning warnings by status code.
  p_apivers text DEFAULT '1.0.2'  -- version (can be discard)
)  RETURNS JSON  AS $func$
DECLARE
  ret json;
BEGIN
  cmd := lower(cmd);
  ret := CASE
    WHEN cmd='info' AND $1 IS NOT NULL AND $1::text>'' THEN issn.info($1)  -- code info
    WHEN cmd='info' THEN issn.info()  -- database info
    WHEN cmd='isc-int' OR cmd='isc' THEN to_json(issn.isc($1))
    WHEN cmd='isn-int' OR cmd='isn' THEN to_json(issn.isn($1))
    WHEN cmd='n2c-int'  THEN to_json(issn.n2c($1))
    WHEN cmd='n2ns-int' THEN to_json(issn.n2ns($1))
    WHEN cmd='n2c'      THEN to_json(issn.cast(issn.n2c($1)))
    WHEN cmd='n2ns'     THEN to_json(issn.n2ns_formated($1))
    ELSE to_json(text '_ERROR_')
  END; -- case
  IF ret#>>'{}' = '_ERROR_' THEN
    RETURN json_build_object( 'status',520,  'result','Unknowing ISSN-API method: '||COALESCE(cmd,'?null?'));
  ELSEIF ret IS NULL THEN
    RETURN json_build_object( 'status',404,  'result','has not found the requested ISSN code '||COALESCE($1::text,'null') ); -- and 416?
  ELSE
    RETURN json_build_object('status',p_status, 'result',ret);
  END IF;
END;
$func$ LANGUAGE plpgsql IMMUTABLE;

CREATE or replace FUNCTION issn.jservice(text,text,int=200,text DEFAULT '1.0.2') RETURNS json AS $fwrap$
  SELECT issn.jservice( issn.cast($1), $2, $3, $4 );
$fwrap$ LANGUAGE SQL IMMUTABLE;


CREATE or replace FUNCTION issn.tservice_jspack(
  --
  -- Performs a "issn.*()" function and returns into a plain text. Or Null when error.
  --
  int,         -- $1 the command argument
  cmd   text,  -- $2 the command (isC, isN, N2C, N2Ns, N2Ns_formated)
  p_status  int=200,   -- for returning warnings by status code.
  p_apivers text DEFAULT '1.0.2'  -- version (can be discard)
)  RETURNS json AS $func$
  SELECT json_build_object('status',r->>'status', 'result', CASE
      WHEN json_typeof(r->'result')='array' THEN array_to_string(lib.json_array_castext(r->'result'),',')
      ELSE r->>'result'
      END)
  FROM (SELECT issn.jservice($1,$2,$3,$4)) t(r);
$func$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION issn.tservice_jspack(text, text, int=200, text DEFAULT '1.0.2') RETURNS json AS $fwrap$
  SELECT issn.tservice_jspack( issn.cast($1), $2, $3, $4 );
$fwrap$ LANGUAGE SQL IMMUTABLE;


CREATE or replace FUNCTION issn.xservice_jspack(
  --
  -- Performs a "issn.*()" function and returns into a XML.
  --
  int,  -- $1 the command argument
  cmd       text,                -- $2 the command (isC, isN, N2C, N2Ns, N2Ns_formated)
  p_status  int=200,     -- for returning warnings by status code.
  p_apivers text DEFAULT '1.0.2' -- version (can be discard)
)  RETURNS json  AS $func$
DECLARE
  ret xml;
  retstr text;
BEGIN
  cmd := lower(cmd);
  ret := CASE
    -- need XML convertion WHEN cmd='info' AND $1 IS NOT NULL AND $1::text>'' THEN issn.info($1)
    -- ... WHEN cmd='info' THEN issn.info()
    WHEN cmd='isc-int' OR cmd='isc' THEN
      xmlelement(  name ret,  COALESCE( issn.isc($1)::text,'') )
    WHEN cmd='isn-int' OR cmd='isn' THEN
      xmlelement(  name ret,  COALESCE( issn.isn($1)::text,'') )
    WHEN cmd='n2c-int' THEN
      xmlelement(  name ret,   COALESCE( issn.n2c($1),0) )
    WHEN cmd='n2c' THEN
      xmlelement(  name ret,   COALESCE( issn.cast(issn.n2c($1)),0) )
    WHEN cmd='n2ns-int' OR cmd='n2ns' THEN (
      SELECT xmlelement(  name ret,  xmlagg( xmlelement(name issn,COALESCE(i,'')) )  )
      FROM  ( -- need check when null
        SELECT unnest( CASE WHEN cmd='n2ns-int' THEN issn.n2ns($1)::text[] ELSE issn.n2ns_formated($1) END )
      ) t(i)
     )
    ELSE (text '<_ERROR_/>')::xml
  END; -- case
  retstr := ret::text;
  IF retstr = '<_ERROR_/>' THEN
    RETURN json_build_object('status',520,  'result','Unknowing ISSN-API method: '||COALESCE(cmd,'?null?'));
  ELSEIF retstr = '<ret></ret>' THEN
    RETURN json_build_object('status',404,  'result','has not found the requested issn');
  ELSE
    RETURN json_build_object('status',p_status, 'result',retstr);
  END IF;
END;
$func$ LANGUAGE plpgsql IMMUTABLE;

CREATE or replace FUNCTION issn.xservice_jspack(text,text,int=200, text DEFAULT '1.0.2') RETURNS json AS $fwrap$
  SELECT issn.xservice_jspack( issn.cast($1), $2, $3, $4 );
$fwrap$ LANGUAGE SQL IMMUTABLE;



------------------------
-- ANY service

CREATE or replace FUNCTION issn.any_service(
  --
  -- Executes a service. Selector for issn.jservice(), issn.xservice_jspack(), etc.
  -- See also fwrap for text.
  -- Example: issn.any_service('n2c',1234,'xml');
  p_cmd text,      -- command
  p_issn7 int,     -- ISSN integer. (see also text for full ISSN code)
  p_out text DEFAULT 'json',      -- output datatype.
  p_status  int=200,   -- for returning warnings by status code. See any_service(text,text).
  p_apivers text DEFAULT '1.0.2'  -- version (can be discard)
)  RETURNS json AS $f$
  SELECT (r::jsonb || jsonb_build_object( 'outFormat', ('{"x":"xml","j":"json","t":"txt"}'::json)->out ))::json -- gambi, revisar
  FROM (
    SELECT CASE
      WHEN out='t' THEN issn.tservice_jspack(p_issn7,p_cmd,p_status,p_apivers)
      WHEN out='x' THEN issn.xservice_jspack(p_issn7,p_cmd,p_status,p_apivers)
      WHEN out='j' THEN issn.Jservice(p_issn7,p_cmd,p_status,p_apivers)
      ELSE
        json_build_object('status',520,  'result','Unknowing ISSN-API output parameter, '|| out)
      END, out
    FROM ( SELECT coalesce(substr(p_out, 1, 1),'?null?') ) t1(out)
  ) t2(r);
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION issn.any_service(text,text,text,int,text DEFAULT '1.0.2') RETURNS json AS $fwrap$
  SELECT issn.any_service(
    $1, issn.cast($2), $3, CASE WHEN issn.check($2) THEN 200 ELSE $4 END, $5
  );
$fwrap$ LANGUAGE SQL IMMUTABLE;

------------------------
-- API specialized wrap for api.run_any()

CREATE or replace FUNCTION issn.parse2_path(
  text  --  input as 'int/123/n2c' or '123/n2c'
  -- returns cmd,arg1 para run_api().
) RETURNS text[] AS $func$
DECLARE
  parts text[];
  parts_n int;
  aux text;
BEGIN
  -- IF $1 IS NULL THEN RETURN array['',''];
  parts := regexp_matches($1, '^(int/)?(\d+.+|info)$');
  IF parts IS NULL OR parts[2] IS NULL THEN
    RETURN array[NULL,NULL]; -- revisar se melhor null,error
  END IF;
  aux   := parts[2] || CASE WHEN parts[1] IS NULL THEN '' ELSE '-int' END;
  parts := regexp_split_to_array(aux, '/');
  parts_n := array_length(parts,1);
  IF parts IS NULL OR parts_n>2 THEN
    RETURN array[NULL,NULL]; -- revisar
  ELSEIF parts_n=1 THEN
    RETURN array['info',NULL];
  ELSE
    RETURN array[parts[2],parts[1]]; -- cmd, arg1. Example ('n2c',123)
  END IF;
END
$func$ LANGUAGE PLpgSQL IMMUTABLE;


CREATE or replace FUNCTION issn.run_api(
  cmd  text,  -- main command
  arg1 text,  -- parameters
  p_out text      ='json',  -- output type
  p_status  int   =200,  -- precisa?
  p_apivers text  ='1.0.2'
) RETURNS json AS $func$
-- NAO PODE RETORNAR NULL
DECLARE
  api text; -- API full-name
  cmds_specs json;
  cmdlist text[];
BEGIN
  cmds_specs := '{"issn-v1.0.2":1}'::json;
  api := 'issn-v'||	COALESCE(p_apivers,'_?_'); -- full name
  IF cmds_specs->api IS NULL THEN
    RETURN json_build_object( 'status',520,  'result','Unknowing ISSN-API or version: '||api );
  END IF;
  --cmdlist := lib.json_array_castext(cmds_specs->api);
  --IF cmd IS NULL OR NOT(cmd = ANY(cmdlist)) THEN
  --  RETURN json_build_object( 'status',534,  'result','Unknowing method '||COALESCE(cmd,'_?_')||' at ISSN-API '||api );
  --END IF;
  IF POSITION('-' in arg1)>0 OR char_length(arg1)>7 THEN  -- parsing ISSN string!
    RETURN issn.any_service(cmd, arg1,     p_out,  p_status, p_apivers);
  ELSE -- same except cast to int
    RETURN issn.any_service(cmd, arg1::int,p_out, p_status, p_apivers);
  END IF;
END
$func$ LANGUAGE PLpgSQL IMMUTABLE;
