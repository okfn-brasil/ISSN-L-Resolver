<?php
// CONFIG
$folder='issnltables';


/**
 * ISSN-to-ISSNL file conversor, PostgresSQL tested implementation.
 *
 * v1.1-2017, v1.0-2014 at https://github.com/ppKrauss/ISSN-L-resolver
 * Use at terminal:
 *  % cd ..; unzip issnltables.zip -d issnltables
 *  % php src/issnltables2sql.php | more
 *  % php src/issnltables2sql.php ALL | psql -h localhost -U postgres base
 * Memory cost at postgreSQL: ~ 101700 blocks ok 1k (df command).
 */
function echo_fileFiltered(
	$folder='issnltables',  // name of the folder produced by    unzip issnltables.zip
	$MAX = 200,             // 0 (for ALL) or number of items for sample.
	$table='issn.intcode',  // name of the table that will be the recipient of "echoated data"
	$frag=90000            // number of records per fragment, important to avoid some "psql overflow"
	//$biggertham = 1715000   // check if bigger tham last
) {
	echo "\n---debug $folder\n";
	$fnames = "$folder/*.ISSN-to-ISSN-L.txt";
	$fs = glob($fnames);
	if (count($fs)!=1)  die("\nERROR: check  $fnames.\n");
	if (preg_match('|/((\d\d\d\d)(\d\d)(\d\d).+\.txt)$|',$fs[0],$m)) {
		$filename = $m[1];
		$dbdate   = "$m[2]-$m[3]-$m[4]";
	} else
		die("\nISSN filename format changed, please correct software to the new format.\n");
	$biggertham = exec("wc -l ".realpath($fs[0])); // check BUG at https://stackoverflow.com/a/3819422/287948
	$biggertham = ((int) preg_replace('/\s.+/s','',$biggertham)) -1;
	$handle = fopen($fs[0], "r");
	$sep = '';
	if ($handle) {
	   echo "\nDELETE FROM $table;";
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
		 echo "\nSELECT issn.info_refresh('$dbdate','$filename');";  // CONFERIR nome tabela info
		 echo "\nSELECT api.assert_eq(
			 	(select COUNT(*) from issn.intcode),
				$biggertham::bigint,
				'count must be the same as wc -l $filename'
			) AS check_count;\n";
		 echo "\n--- END OF INSERTS ---\n";
	} // if
} // func

if (isset($argv[0])) {
	// alert: using at terminal (shell)
	$n = isset($argv[1])? 0: 20;
	echo_fileFiltered($folder, $n);
}


?>
