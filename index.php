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

<textarea rows="20" cols="120"><?php
	echo_fileFiltered();
?>
</textarea>



</body>
</html>

