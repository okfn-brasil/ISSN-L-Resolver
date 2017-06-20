--
-- lib.issnl_get() and some util functions.
-- See Radme.md for CREATE TABLE and INDEX. Using "library" (lib) schema.
-- v1.0-2014 of https://github.com/ppKrauss/ISSN-L-resolver 
--

CREATE SCHEMA IF NOT EXISTS lib;  -- general commom library.
-- -- -- -- -- -- -- -- -- -- --
-- text ISSN util functions   -- 

CREATE FUNCTION lib.issn_format(text)
  -- 
  -- Transform a "free ISSN" string in a well-formated standard one.
  --
  RETURNS text AS       -- a formated ISSN
$func$
  SELECT CASE WHEN $1 is null OR trim($1)='' THEN NULL 
         ELSE regexp_replace(upper(regexp_replace($1, '[\- ]+', '')), '^(.{4,4})(.{4,4})', '\1-\2')
         END;
$func$ LANGUAGE sql IMMUTABLE;


CREATE FUNCTION lib.issn_check(issn text)
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

CREATE FUNCTION lib.issn_cast(text) RETURNS int AS $func$
  -- 
  -- Converts a "free ISSN string" into a integer ISSN.
  --  
  SELECT  substr(translate(trim($1), '-', ''),1,7)::int
$func$ LANGUAGE SQL IMMUTABLE;


-- -- -- -- -- -- -- -- -- --
-- int ISSN util functions -- 

CREATE FUNCTION lib.issn_digit8(int)
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

CREATE FUNCTION lib.issn_cast(int)  RETURNS text AS $func$
  -- 
  -- Converts an "integer ISSN" into a standard text ISSN.
  -- Must be used only for database's oficial ISSNs.
  --  
  SELECT trim(to_char($1, '0000-000')||lib.issn_digit8($1));
$func$ LANGUAGE SQL IMMUTABLE;


-- -- -- -- -- -- -- -- -- -- -- --
-- ISSN resolving services       -- 
-- (complete and symmetric set)  -- 
-- isC, isN, N2C, N2Ns, N2Ns_formated

CREATE FUNCTION lib.issn_isC(int)  RETURNS smallint AS $func$
  -- 
  -- Returns 1 when input is an ISSN-L.
  -- Only mirros or authority can return (coalesced) 0, 
  -- other databases must return NULL when not found...
  -- ... but not so practical: SELECT 1::smallint FROM lib.issn_l WHERE issn_l=$1 LIMIT 1;
  SELECT COALESCE((SELECT 1::smallint as r FROM lib.issn_l WHERE issn_l=$1 LIMIT 1), 0::smallint);
$func$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION lib.issn_isC(text)  RETURNS smallint AS $func$
  -- 
  -- Same as lib.issn_isC(int), but casting and checking text input.
  -- Returns 2 when digit is invalid or has no check-digit.
  --
  SELECT CASE WHEN NOT(lib.issn_check($1)) THEN r+1::smallint ELSE r END
  FROM (
    SELECT lib.issn_isC( lib.issn_cast($1) ) as r
  ) as t;
$func$ LANGUAGE SQL IMMUTABLE;


CREATE FUNCTION lib.issn_isN(int)  RETURNS smallint AS $func$
  -- 
  -- Returns 1 when input is an (any) ISSN.
  -- Only mirros or authority can return (coalesced) 0, 
  -- other databases must return NULL when not found...
  -- ... but not so practical:  SELECT 1::smallint FROM lib.issn_l WHERE issn=$1;
  -- NOTE: "isN service" in the RFC2169 jargon.
  SELECT COALESCE((SELECT 1::smallint as r FROM lib.issn_l WHERE issn=$1), 0::smallint);
$func$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION lib.issn_isN(text)  RETURNS smallint AS $func$
  -- 
  -- Same as lib.issn_isN(int), but casting and checking text input.
  -- Returns 2 when digit is invalid or has no check-digit.
  --
  SELECT CASE WHEN NOT(lib.issn_check($1)) THEN r+1::smallint ELSE r END
  FROM (
    SELECT lib.issn_isN( lib.issn_cast($1) ) as r
  ) as t;
$func$ LANGUAGE SQL IMMUTABLE;


CREATE FUNCTION lib.issn_N2C(int)  RETURNS int AS $func$
  -- 
  -- Returns the integer ISSN-L of any integer ISSN. 
  -- Returns NULL if the input not exists. 
  -- NOTE: is a "N2N service" in the RFC2169 jargon, 
  --       but specifically a "N2C" because returns the Canonic URN.
  --
  SELECT issn_l FROM lib.issn_l WHERE issn=$1;
$func$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION lib.issn_N2C(text)  RETURNS int AS $func$
  -- 
  -- Same as lib.issn_N2C(int), but casting text inputs. 
  --
  SELECT lib.issn_N2C( lib.issn_cast($1) );
$func$ LANGUAGE SQL IMMUTABLE;


CREATE FUNCTION lib.issn_N2Ns(int)  RETURNS int[] AS $func$
  -- 
  -- Returns all ISSNs linked to a ISSN. 
  -- Returns NULL if the input not exists. 
  -- Is a "N2Ns service" in the RFC2169 jargon.
  -- NOTE: very slow if not using issn_idx1.
  --       
  SELECT array_agg(issn ORDER BY issn) 
  FROM lib.issn_l 
  WHERE issn_l=lib.issn_N2C($1);
$func$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION lib.issn_N2Ns(text)  RETURNS int[] AS $func$
  -- 
  -- Same as lib.issn_N2Ns(int), but casting text input. 
  --
  SELECT lib.issn_N2Ns( lib.issn_cast($1) );
$func$ LANGUAGE SQL IMMUTABLE;


CREATE FUNCTION lib.issn_N2Ns_formated(int)  RETURNS text[] AS $func$
  -- 
  -- Same as lib.issn_N2Ns(int), but returning text formated ISSNs
  --
  SELECT array_agg(lib.issn_cast(issn) ORDER BY issn) 
  FROM lib.issn_l 
  WHERE issn_l=lib.issn_N2C($1);
$func$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION lib.issn_N2Ns_formated(text)  RETURNS text[] AS $func$
  -- 
  -- Same as lib.issn_N2Ns_formated(int), but casting text input. 
  --
  SELECT lib.issn_N2Ns_formated( lib.issn_cast($1) );
$func$ LANGUAGE SQL IMMUTABLE;


-- -- -- -- -- -- -- -- -- -- --
-- Services, T=text, X=XML and J=JSON --

CREATE OR REPLACE FUNCTION lib.issn_tservice(
  -- 
  -- Performs a "lib.issn_*()" function and returns into a plain text.
  --
  int,        -- $1 the command argument
  cmd   text  -- $2 the command (isC, isN, N2C, N2Ns, N2Ns_formated)
)  RETURNS text AS $func$
BEGIN
  cmd := lower(cmd);
  RETURN COALESCE(
  CASE WHEN cmd='isc' THEN  lib.issn_isc($1)::text 
       WHEN cmd='isn' THEN  lib.issn_isn($1)::text
       WHEN cmd='n2c' THEN  lib.issn_cast(lib.issn_n2c($1))::text
  -- erro falta fixar delimitador com join_array     
       WHEN cmd='n2ns' THEN trim( lib.issn_n2ns_formated($1)::text, '{}')
       ELSE 'unknowing command'
   END, ''); -- case
END;
$func$ LANGUAGE plpgsql IMMUTABLE;
CREATE FUNCTION lib.issn_tservice(text,text)  RETURNS text AS $func$
  -- 
  -- Same as lib.issn_tservice(int,text), but casting text input. 
  --
  SELECT lib.issn_tservice( lib.issn_cast($1), $2 );
$func$ LANGUAGE SQL IMMUTABLE;

CREATE FUNCTION lib.issn_xservice(
  -- 
  -- Performs a "lib.issn_*()" function and returns into a XML.
  --
  int,        -- $1 the command argument
  cmd   text  -- $2 the command (isC, isN, N2C, N2Ns, N2Ns_formated)
)  RETURNS xml  AS $func$
BEGIN
  cmd := lower(cmd);
  RETURN 
  CASE WHEN cmd='isc' THEN 
     xmlelement(  name ret,  
                  xmlattributes('sucess' as status), 
                  COALESCE(lib.issn_isc($1)::text,'') 
     )
   WHEN cmd='isn' THEN
     xmlelement(  name ret,  
                  xmlattributes('sucess' as status), 
                  COALESCE(lib.issn_isn($1)::text,'') 
     )
   WHEN cmd='n2c' THEN
     xmlelement(  name ret,  
                  xmlattributes('sucess' as status), 
                  COALESCE(lib.issn_cast(lib.issn_n2c($1)),'') 
     )
   WHEN cmd='n2ns' THEN 
     (
      SELECT xmlelement(  name ret,  xmlattributes('sucess' as status),  xmlagg(xmlelement(name issn,i))  )
      FROM  (SELECT unnest( lib.issn_n2ns_formated($1) ) as i ) as t
     )
   ELSE
        xmlelement(  name ret,  xmlattributes('error' as status, 1 as cod), 'unknowing command' )
   END; -- case
END;
$func$ LANGUAGE plpgsql IMMUTABLE;
CREATE FUNCTION lib.issn_xservice(text,text)  RETURNS xml AS $func$
  -- 
  -- Same as lib.issn_xservice(int,text), but casting text input. 
  --
  SELECT lib.issn_xservice( lib.issn_cast($1), $2 );
$func$ LANGUAGE SQL IMMUTABLE;


-- JSON need POstgreSQL 9.2+  --


----------------------------------------
--- testing context for integer outoput
CREATE FUNCTION issn_tservice_int(char,text,text)  RETURNS INT[] AS $func$
  -- 
  -- Performs a "lib.issn_*()" function and returns into a plain text.
  --
  int,        -- $1 the command argument
  cmd   text  -- $2 the command (isC, isN, N2C, N2Ns, N2Ns_formated)
)  RETURNS text AS $func$
BEGIN
  cmd := lower(cmd);
  RETURN COALESCE(
  CASE WHEN cmd='isc' THEN  lib.issn_isc($1) 
       WHEN cmd='isn' THEN  lib.issn_isn($1)
       WHEN cmd='n2c' THEN  lib.issn_cast(lib.issn_n2c($1))
  -- erro falta fixar delimitador com join_array     
       WHEN cmd='n2ns' THEN lib.issn_n2ns_formated($1)
       ELSE -1
   END, -2); -- case
END;
$func$ LANGUAGE plpgsql IMMUTABLE;
CREATE FUNCTION lib.issn_tservice_int(text,text)  RETURNS text AS $func$
  -- 
  -- Same as lib.issn_xws(int,text), but casting text input. 
  --
  SELECT lib.issn_tservice( lib.issn_cast($1), $2 );
$func$ LANGUAGE SQL IMMUTABLE;
