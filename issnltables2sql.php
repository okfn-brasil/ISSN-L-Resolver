<?php
/**
 * Conversor de arquivo ISSN-to-ISSNL para SQL PostgresSQL.
 * v1.0-2014 of https://github.com/ppKrauss/ISSN-L-resolver 
 * Usar em modo shell:
 * % php issnltables2sql.php | more
 * % php issnltables2sql.php tudo | psql -h localhost -U postgres base
 */

/* Utilização de dados no postgreSQL: 36205156-36103452= 101704 blocos de 1k,
   comando df antes e depois:
	Sist. Arq.     1K-blocos    Usado Disponível 
	/dev/sda6       83258952 42824420   36205156 
	/dev/sda6       83258952 42926124   36103452 
*/
function echo_fileFiltered(
		$folder='issnltables',  // noma da pasta do unzip issnltables.zip
		$MAX = 200,             // 0 (indica TUDO) ou numero de itens desejado para amostra.
		$table='lib.issn_l',  // nome da tabela que receberá os dados
		$frag=90000             // numero de dados por fragmento de INSERT  (important para nao estourar memoria do psql) 
		) {
	$file='';
	echo "\n---debug $folder\n";
	foreach(scandir($folder) as $f)
		if (preg_match('/ISSN.to.ISSN.L/i', $f))   $file = "$folder/$f";
	$handle = fopen($file, "r");
	$sep = '';
	if ($handle) {
		echo "\nDROP TABLE IF EXISTS $table;";
		echo "\nCREATE TABLE $table (issn int not null primary key, issn_l int not null);";
		echo "\nINSERT INTO $table (issn, issn_l) VALUES ";
	    for($n=0; (!$MAX || $n<$MAX) && ($line = fgets($handle, 4096)) !== false;  $n++) {
	    	preg_match('/^\s*(\d+)\-(\d{3,3})[X\d]\s(\d+)\-(\d{3,3})[X\d]$/i',$line,$m);
	        if (isset($m[1])) {
	        	echo "$sep\n($m[1]$m[2],$m[3]$m[4])";
	        	$sep = ',';
	        }
	        if ($n>10 && ($n%$frag)==0) {
	        	echo ";\n\nINSERT INTO $table (issn, issn_l) VALUES ";
	        	$sep='';	        	
	        }
	    }
	    if ((!$MAX || $n!=$MAX)  && !feof($handle)) {
	        echo "\n##Error: unexpected fgets() fail\n";
	    } else 
	    	echo ";";
	    fclose($handle);
	}	
}

if (isset($argv[0])) {
	// cuisado: usar comando shell
	$n = isset($argv[1])? 0: 20;
	echo_fileFiltered('issnltables', $n, 'lib.issn_l',90000);
}


?>