DROP SCHEMA IF EXISTS api CASCADE;
CREATE SCHEMA api;

------------------------
-- API generic parsers


CREATE or replace FUNCTION api.parse1_uri(
  -- (aplicar o parse2 específico sobre o path!)
  -- Converts a URI of any API into 3 parts: api-name, api-path and api-output.
  -- Need to enconde here (future by database) the api-output-default.
  -- Example: api.parse1_uri('issn-v1.0.2/0004/n2ns');
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
		apivers_defaults := '{"issn":["1.0.2","1.0.0"],"getfrag":["1.0.0"]}'::json;

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
	 			RETURN array[NULL,'505','API name not exists - '||apiName||' - '||$1];
			END IF;
			apivers := (apivers_defaults->apiName)->>0;  -- JSON array starts with zero
		END IF;
		lastp := aux[array_length(aux,1)];
		vaux := regexp_matches(lastp,ext_rgx);
		IF (array_length(vaux,1)=1) THEN
			apiout := vaux[1];
			aux[array_length(aux,1)] := regexp_replace(lastp,ext_rgx,'');
		ELSE
			apiout := apiout_defaults->>apiName; -- validar caso null
		END IF;
		RETURN array[apiName, apivers, array_to_string(aux,'/'), apiout];
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
	-- Input example: 'issn','1.0.2','67/n2c','json'
  --
  p_apiname text,  -- a valid api-name (parsed from URI or endpoint)
  p_apivers text,  -- a valid api-version (parsed from URI or endpoint)
  p_path text,     -- the URI-path of api's endpint.
  p_out    text='json',    -- json, xml or txt
	p_status int=200         -- injected HTTP status
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
    apis_specs := '{"issn-v1.0.2":["isn","isc","n2c","n2ns"],"issn-v1.0.0":["isn","isc","n2c","n2ns"],"getfrag-v1.0.0":["xx"]}'::json;
    api := p_apiname||'-v'||	p_apivers; -- full name
    IF apis_specs->api IS NULL THEN
			RETURN json_build_object( 'status',532,  'result','nao achei specs de api='||api );
    END IF;
    CASE api
    WHEN 'issn-v1.0.2', 'issn-v1.0.0' THEN
			parts  := issn.parse2_path(p_path); -- returns cmd, arg1 (optional arg2, arg3, etc.)
      result := issn.run_api(parts[1], parts[2], p_out, p_status, p_apivers)::json;

    WHEN 'getfrag-v1.0.0' THEN
			result := json_build_object( 'status',555,  'result','under construction' );
    ELSE
      result := json_build_object( 'status',557,	'result','invalid api-full-name' );
    END CASE;
    RETURN result;
 END
$func$ LANGUAGE PLpgSQL IMMUTABLE;


------------------------
-- API generic

CREATE or replace FUNCTION api.run_byuri(text) RETURNS json AS $f$
  -- Wrap for join api.run_any() with api.parse1_uri().
  SELECT CASE
    WHEN s[1] IS NULL THEN -- avisa erro:
      json_build_object('status',s[2],  'result',s[3])
    ELSE
      api.run_any(s[1],s[2],s[3],s[4])
    END
  FROM  api.parse1_uri($1) t(s);  -- s1=apiName, s2=apivers, s3=path, s4=apiout
$f$ LANGUAGE sql IMMUTABLE;

------------

CREATE or replace FUNCTION api.assert_eq(
	have anyelement, want anyelement, message_onfail text=NULL, message_onsucess text='Assert is equal'
) RETURNS text AS $$
DECLARE
    msg text;
BEGIN
    IF($1 IS NOT DISTINCT FROM $2) THEN
        RETURN 'OK: '|| message_onsucess ||'.';
    END IF;
    msg := E'ASSERT IS_EQUAL FAILED.\n\nHave -> ' || COALESCE($1::text, 'NULL') || E'\nWant -> ' || COALESCE($2::text, 'NULL') || E'\n';
    RETURN 'ASSERT FAILED (' ||COALESCE(message_onfail,' ... ')|| E')\n'|| msg;
END
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE TABLE api.assert_test(
  categ text default 'general', -- category
  uri text,
  result text
);
