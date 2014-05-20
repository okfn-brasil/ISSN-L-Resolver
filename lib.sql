--
-- lib.issnl_get() and some util functions
-- v1.0-2014 of https://github.com/ppKrauss/ISSN-L-resolver 
--


CREATE OR REPLACE FUNCTION lib.issn_format(text)
  RETURNS text AS
$func$
  SELECT CASE WHEN $1 is null OR trim($1)='' THEN NULL 
         ELSE regexp_replace(upper(regexp_replace($1, '[\- ]+', '')), '^(.{4,4})(.{4,4})', '\1-\2')
         END;
$func$ LANGUAGE sql IMMUTABLE;


CREATE OR REPLACE FUNCTION lib.issn_check(issn text)
  RETURNS boolean AS
$func$
DECLARE 
  pos INTEGER;
  casc INTEGER; 
  sum INTEGER DEFAULT 0;
  weight INTEGER[] DEFAULT '{8,7,6,5,4,3,2,1}';
  digits INTEGER DEFAULT 1;
BEGIN 
  ISSN := upper(translate(ISSN, '-', '')); -- without hiphen
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
    RETURN 'f';
  ELSE
    RETURN (sum % 11) = 0;
  END IF;
END;
$func$ LANGUAGE PLpgSQL IMMUTABLE;

-- int functions -- 

CREATE OR REPLACE FUNCTION lib.issnl_get(int)  RETURNS int AS $func$
  -- returns the integer ISSN-L of any "integer ISSN"  
  -- USE lib.issn_convert(lib.issnl_get(issn))
  SELECT issn_l FROM lib.issn_l WHERE issn=$1;
$func$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE FUNCTION lib.issn_convert(int)  RETURNS text AS $func$
  -- converts an "integer ISSN" into a standard ISSN
  SELECT to_char($1, '0000-000')||lib.issn_digit8($1);
$func$ LANGUAGE SQL IMMUTABLE;


CREATE OR REPLACE FUNCTION lib.issn_digit8(int)
  -- calculates the "check digit" of an integer ISSN
  RETURNS CHAR AS -- digit
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
  IF $1>9999999 OR $1<1 THEN 
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