<?php
//CONF
$PG_CONSTR = 'pgsql:host=localhost;port=5432;dbname=issnl';
$PG_USER = 'postgres';
$PG_PW   = 'postgres';

$is_cli = (php_sapi_name() === 'cli');  // true when is client (terminal).

$outFormatMime = ['j'=>'application/json', 'x'=>'application/xml', 't'=>'text/plain'];
$status = 200;
  // 404 - has not found the input issn.
  // 416 - issn format is invalid.

$cmdValid = ['N2N','N2Ns','N2C','N2Cs','N2U','N2Us','isN','isC','info', 'infodb'];

?>
