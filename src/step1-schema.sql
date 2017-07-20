
 CREATE SCHEMA IF NOT EXISTS issn;  -- for ISSN library and dataset.
 CREATE TABLE issn.intcode (
    issn integer NOT NULL PRIMARY KEY,
    issn_l integer NOT NULL
  );
 CREATE INDEX issnl_idx ON issn.intcode(issn_l);     --  run again later,  is a bug
 -- about need for indexes, see issn.N2Ns() function.

 CREATE VIEW issn.stats AS  -- counting for statistics
  WITH cts AS (
  	SELECT len, count(*) as records
  	FROM (
  		SELECT count(*) as len
  		FROM issn.intcode
  		GROUP BY issn_l
  	) t
  	GROUP BY len
  	ORDER BY records DESC, len DESC
  )
  SELECT issn_min, issn_max, numof_issn, numof_issnl, issnl_countings
  FROM
        ( SELECT to_jsonb(array_agg(cts)) AS issnl_countings FROM cts ) t1,
        ( SELECT max(issn) AS issn_max, min(issn) AS issn_min,
                 count(distinct issn) AS numof_issn, count(distinct issn_l) AS numof_issnl
          FROM issn.intcode
        ) t2
 ;

CREATE TABLE issn.info AS -- all zero here, delete and run with issn.info_refresh()
  SELECT '2017-06-19'::date AS updated_issn, *, ''::jsonb as api_spec
  FROM issn.stats
;

-- wget https://raw.githubusercontent.com/okfn-brasil/ISSN-L-Resolver/master/swagger.json
-- COPY  UPDATE issn.info SET api_spec=new file.

CREATE VIEW issn.intcode_demo AS
  SELECT issn_l, count(*) as len, array_agg(issn) as issn_set
  FROM issn.intcode group by 1 having count(*)>1
;
