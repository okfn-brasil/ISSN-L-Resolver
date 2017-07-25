
------------------------------------------

\echo '\n---- ----\n---- TESTING:\n'

SELECT	 api.assert_eq(issn.isN(115), true, 				'','isN(int)') as "isN"
        ,api.assert_eq(issn.isN('8755-9994'), true,	'','isN(text)') as "isN"
;
SELECT   api.assert_eq(issn.isC(115), true, 				'','isC(int)') as "isC"
        ,api.assert_eq(issn.isC('8755-9994'), true,	'','isC(text)') as "isC"
;
SELECT  api.assert_eq(issn.isN(8999999), null, 	'','isN(int out of range) returning null') as "isN ret"
       ,api.assert_eq(issn.isC(8999999), null, 	'','isC(int out of range) returning null') as "isC ret"
;
SELECT  api.assert_eq(issn.n2c(8755999), 8755999, 			'8755999','n2c(int)') as "N2C"
       ,api.assert_eq(issn.n2c('8755-9994'), 8755999,	'8755999','n2c(text)') as "N2C"
			 ,api.assert_eq(issn.n2c('8755-9994'), 8755999,	'8755999','n2c(text)') as "N2C"
;
SELECT  api.assert_eq( issn.n2c(8755999), 8755999, 			'8755999','n2c(int)' ) as "N2C"
       ,api.assert_eq( issn.n2c('8755-9994'), 8755999,	'8755999','n2c(text)'  ) as "N2C"
       ,api.assert_eq( issn.cast(issn.n2c(67)), '0000-1155', '67','cast(n2c(int))'  ) as "cast(N2C)"
;

SELECT api.assert_eq(
	issn.n2ns(115)::text,
	'{67,115,65759,68054,74682,1067816}',
	'115',
	'n2ns(int)'
) as "n2ns",
api.assert_eq(
	issn.n2ns_formated(115)::text,
	'{0000-0671,0000-1155,0065-759X,0068-0540,0074-6827,1067-8166}',
	'115',
	'n2ns_formated(int)'
) as "n2ns_formated";

SELECT  api.assert_eq( issn.jservice(67,'n2c')::text, '{"status" : 200, "result" : "0000-1155"}', 			'67','jservice(n2c(int))' ) as "jservice(N2C)";
SELECT  api.assert_eq( issn.tservice_jspack(67,'n2c')::text, '{"status" : "200", "result" : "0000-1155"}', 			'67','n2c(int)' ) as "tservice(N2C)";
SELECT  api.assert_eq( issn.xservice_jspack(67,'n2c')::text, '{"status" : 200, "result" : "<ret>115</ret>"}', 			'67','n2c(int)' ) as "xservice(N2C)";


---------------

DELETE FROM api.assert_test; -- ? outros? Usar planilha?
INSERT INTO api.assert_test(categ,uri,result) VALUES
  ('issn-n2ns', 'issn/67/n2c',     	'{"status" : 200, "result" : "0000-1155"}'),
  ('issn-n2ns', 'issn/int/1/n2ns',  	'{"status" : 200, "result" : [1,2150400]}'),
  ('issn-n2ns', 'issn/int/115/n2ns',  	'{"status" : 200, "result" : [67,115,65759,68054,74682,1067816]}'),
  ('issn-n2ns', 'issn/int/168/n2ns', 	'{"status" : 200, "result" : [168,173]}'),
  ('issn-n2ns', 'issn/int/168/n2ns', 	'{"status" : 200, "result" : [168,173]}'),
  ('issn-n2ns', 'issn/int/706465/n2ns',	'{"status" : 200, "result" : [706465,1200101,1200103,1207299,1207300]}'),
  ('issn-n2ns', 'issn/int/1120602/n2ns', '{"status" : 200, "result" : [1120602,1722786,1722787,2499313]}'),
  ('issn-n2ns', 'issn/1/n2ns',     	'{"status" : 200, "result" : ["0000-0019","2150-4008"]}'),
  ('issn-n2ns', 'issn/115/n2ns',   	'{"status" : 200, "result" : ["0000-0671","0000-1155","0065-759X","0068-0540","0074-6827","1067-8166"]}')
;

\echo '\n----- api.assert_tests, complete suite -----\n'

SELECT categ, api.assert_eq( api.run_byuri(uri)::text, result, uri, uri ) as result
FROM   api.assert_test ;

\echo '\n----- END TESTS -----\n'
