<?php
//CONF
$PG_CONSTR = 'pgsql:host=localhost;port=5432;dbname=issnl';
$PG_USER = 'postgres';
$PG_PW   = 'postgres';

$is_cli = is_cli();

/**
 * Check if is terminal or not.
 * @return boolean true when is client (terminal).
 */
function is_cli() { return (php_sapi_name() === 'cli');  }

?>

