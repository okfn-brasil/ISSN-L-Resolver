--
-- lib.issnl_get() and some util functions
-- v1.0-2014 of https://github.com/ppKrauss/ISSN-L-resolver 
--

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


-- -- -- -- -- -- -- -- -- --
-- ISSN resolving services -- 

CREATE FUNCTION lib.issn_N2C(int)  RETURNS int AS $func$
  -- 
  -- Returns the integer ISSN-L of any integer ISSN. 
  -- Returns NULL if the input not exists. 
  -- NOTE: Is a "N2N service" in the RFC2169 jargon, 
  --       but specifically a "N2C" because returns the Canonic URN.
  --
  SELECT issn_l FROM lib.issn_l WHERE issn=$1;
$func$ LANGUAGE SQL IMMUTABLE;
CREATE FUNCTION lib.issn_N2C(text)  RETURNS int AS $func$
  -- 
  -- Same as lib.issn_N2C(int), but casting text inputs. 
  -- Overloads the main function.
  --
  SELECT lib.issn_N2C( lib.issn_cast($1) );
$func$ LANGUAGE SQL IMMUTABLE;


CREATE FUNCTION lib.issn_N2Ns(int)  RETURNS int[] AS $func$
  -- 
  -- Returns all ISSNs linked to a ISSN. 
  -- Returns NULL if the input not exists. 
  -- Is a "N2Ns service" in the RFC2169 jargon.
  -- NOTE: very slow, even when indexed,
  --       CREATE UNIQUE INDEX issn_idx ON lib.issn_l(issn);
  --
  SELECT array_agg(issn) 
  FROM lib.issn_l 
  WHERE issn_l=lib.issn_N2C($1);
$func$ LANGUAGE SQL IMMUTABLE;
CREATE FUNCTION lib.issn_N2Ns(text)  RETURNS int[] AS $func$
  -- 
  -- Overloads the main function by casting for text inputs.
  --
  SELECT lib.issn_N2Ns( lib.issn_cast($1) );
$func$ LANGUAGE SQL IMMUTABLE;

