DROP SCHEMA IF EXISTS api CASCADE;
CREATE SCHEMA api;

------------------------
-- API generic parsers



CREATE or replace FUNCTION api.parse1_uri(
  --
  -- Converts a URI of any API into 3 parts: api-name, api-path and api-output.
  -- Need to enconde here (future by database) the api-output-default.
  -- Example: api.parse1_uri('issn-v1.0.0/0004/n2ns');
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

		aux := regexp_split_to_array(trim($1,'/'), '/'); -- not need regex
		IF array_length(aux,1)<2 THEN
			RETURN array[NULL,'1','path need more itens'];
		END IF;
		apiName := lower(aux[1]);
		aux := lib.array_pop_off(aux);
		vaux := regexp_matches(apiname,vers_rgx);
		IF (array_length(vaux,1)=1) THEN
			apivers := vaux[1];
			apiName := regexp_replace(apiName,vers_rgx,'');
		ELSE
			IF apivers_defaults->apiName IS NULL THEN
	 			RETURN array[NULL,'2','name not exists - '||apiName];
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


------------------------
-- API generic joining specifics

CREATE or replace FUNCTION api.run_any(
  --
  -- FINAL RESULT for API.
  -- Run an standard API (see Open API definitions) by its name and path-parameters.
  -- Is a kind of command-proxy for SQL functions.
  -- Seems a Strategy design pattern (also Proxy, Composite or Interpreter)
  --
  p_apiname text,  -- a valid api-name (parsed from URI or endpoint)
  p_apivers text,  -- a valid api-version (parsed from URI or endpoint)
  p_path text,     -- the URI-path of api's endpint
  p_out  text DEFAULT 'json'    -- json, xml or txt
)   RETURNS json AS    -- returns HTTP status
$func$
 DECLARE
    status int; -- 200
    apis_specs json; -- array by apiname
    api text;
    cmd text;
    parts text[];
    arg1 text;
    arg2 text;
    result json;
 BEGIN   -- do openApi viria mais informações, mas por hora imaginar que só isso.
    apis_specs := '{"issn-v1.0.1":["isn","isc","n2c","n2ns"],"issn-v1.0.0":["isn","isc","n2c","n2ns"],"getfrag-v1.0.0":["xx"]}'::json;
    api := p_apiname||'-v'||	p_apivers; -- full name
    IF apis_specs->api IS NULL THEN
        RETURN json_build_object('error',2,  'msg','nao achei specs de api='||api);
    END IF;
    parts   := regexp_split_to_array(p_path, '/');
    CASE api
    WHEN 'issn-v1.0.1', 'issn-v1.0.0' THEN
      result := issn.run_api(parts[2],parts[1],p_out,p_apivers)::json;

    WHEN 'getfrag-v1.0.0' THEN
      result := json_build_object('error',10,  'msg','under construction');

    ELSE
      result := json_build_object('error',4,  'msg','invalid api-full-name');

    END CASE;
    RETURN result;
 END
$func$ LANGUAGE PLpgSQL IMMUTABLE;


------------------------
-- API generic

CREATE or replace FUNCTION api.run_byuri(text) RETURNS json AS $f$
  -- Wrap for join api.run_any() with api.parse1_uri().
  SELECT CASE
    WHEN s[1] IS NULL THEN
      json_build_object('error',s[2],  'msg',s[3])
    ELSE
      api.run_any(s[1],s[2],s[4],s[3])
    END
  FROM  api.parse1_uri($1) t(s);
$f$ LANGUAGE sql IMMUTABLE;



------------

CREATE or replace FUNCTION api.assert_eq(
	have anyelement, want anyelement, message text
) RETURNS text AS $$
DECLARE
    msg text;
BEGIN
    IF($1 IS NOT DISTINCT FROM $2) THEN
        RETURN 'OK: Assert is equal.';
    END IF;
    msg := E'ASSERT IS_EQUAL FAILED.\n\nHave -> ' || COALESCE($1::text, 'NULL') || E'\nWant -> ' || COALESCE($2::text, 'NULL') || E'\n';
    RETURN 'ASSERT FAILED (' ||message|| E')\n'|| msg;
END
$$ LANGUAGE plpgsql IMMUTABLE;


CREATE TABLE api.assert_test(
  categ text default 'general', -- category
  uri text,
  result text
);

INSERT INTO api.assert_test VALUES
	('n2ns-toInt-json','issn/1/n2ns', 	'{2150400,1}'),
	('n2ns-toInt-json','issn/115/n2ns', '{1067816,74682,68054,65759,115,67}'),
	('n2ns-toInt-json','issn/168/n2ns', '{173,168}'),
	('n2ns-toInt-json','issn/168/n2ns',	'{173,168}'),
	('n2ns-toInt-json','issn/706465/n2ns', 	'{1207300,1207299,1200103,1200101,706465}'),
	('n2ns-toInt-json','issn/1120602/n2ns',	'{2499313,1722787,1722786,1120602}'),
;
