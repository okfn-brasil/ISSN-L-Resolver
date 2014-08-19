<?php
/**
 * Conversor de arquivo ISSN-to-ISSNL para SQL PostgresSQL.
 */
include('issnltables2sql.php');

?>
<html>
  <head>
	<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
	<title>ISSN-to-ISSNL </title>
  </head>
<body>

Teste por amostragem: 

<textarea rows="20" cols="120"><?php
	echo_fileFiltered();
?>
</textarea>
Para usar, confira o "issnltables2sql.php" ou https://github.com/ppKrauss/ISSN-L-resolver


</body>
</html>

