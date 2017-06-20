
 CREATE SCHEMA IF NOT EXISTS lib;  -- general commom library.
 CREATE TABLE lib.issn_l (
    issn integer NOT NULL PRIMARY KEY,
    issn_l integer NOT NULL
  );
 CREATE INDEX issn_idx1 ON lib.issn_l(issn_l);     
 -- about need for indexes, see lib.issn_N2Ns() function.
