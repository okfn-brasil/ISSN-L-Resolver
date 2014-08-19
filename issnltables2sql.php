<?php
/**
 * ISSN-to-ISSNL file conversor, PostgresSQL tested implementation.
 * 
 * v1.0-2014 of https://github.com/ppKrauss/ISSN-L-resolver 
 * Use at terminal:
 *  % unzip issnltables.zip
 *  % php issnltables2sql.php | more
 *  % php issnltables2sql.php ALL | psql -h localhost -U postgres base
 * Cost at postgreSQL: ~ 101700 blocks ok 1k (df command). 
 */
function echo_fileFiltered(
	$folder='issnltables',  // name of the folder produced by    unzip issnltables.zip
	$MAX = 200,             // 0 (for ALL) or number of items for sample.
	$table='lib.issn_l',    // name of the table that will be the recipient of "echoated data"
	$frag=90000             // number of records per fragment, important to avoid some "psql overflow" 
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
	   } // for
	   if ((!$MAX || $n!=$MAX)  && !feof($handle)) {
	        echo "\n##Error: unexpected fgets() fail\n";
	   } else 
	    	echo ";";
	   fclose($handle);
	} // if	
} // func

if (isset($argv[0])) {
	// alert: using at terminal (shell)
	$n = isset($argv[1])? 0: 20;
	echo_fileFiltered('issnltables', $n, 'lib.issn_l',90000);
}


?>
