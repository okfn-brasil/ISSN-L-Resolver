<?php
/**
 * Run service as terminal command.
 * Commands  N2C,N2Ns,isN,isC,info, list
 * php resolve.php -j --n2n 1234567
 * http://localhost/gits/ISSN-L-resolver/webservice/
 */

//CONF
$PG_CONSTR = 'pgsql:host=localhost;port=5432;dbname=issnl';
$PG_USER = 'postgres';
$PG_PW   = 'postgres';


$optind = null;
$opts = getopt('hjx', ['N2N','N2Ns','N2C','N2Cs','N2U','N2Us','isN','isC','info'], $optind);
$extras = array_slice($argv, $optind);
$outFormat = isset($opts['x'])? 'x': 'j';  // x|j|t
unset($opts['x']);unset($opts['j']);
$cmd = array_keys($opts);
if (isset($opts['h']) || !count($extras) || count($cmd)!=1)
  die("\n---- ISSN-L RESOLVER -----
php resolve.php [output] command issn_value
  output:  -x=xml  -j=json  -t=txt
  issn_value: 7-digit integer or string
  command:
  --isC  = returns 1 for ISSN-L, NULL when exist, 0 otherelse.
  --isN  = returns the main URL of an input-URN.
  --N2L  = returns the main URL of an input-URN.
  --N2Ns = returns a set of URNs related to the input-URN.
  --N2Ls = returns all the URLs related to the input-URN.
  --N2C  = returns the canonical (preferred) URN of an input-URN.
  --list = retrieves all component URNs (or its metadata), when component entities exists.
  --info = retrieves catalographic information or metadata of the (entity of the) URN.

   'C': the canonic URN string (the 'official string' and unique identifier); non-RFC2169 jargon;
   'N': URN, canonical or 'reference URN' (a simplified non-ambiguous version of the canonical one);
   'L': URL (main URL is a http and secondary can by also ftp and mailto URLs, see RFC2368)
   'is': 'isX' stands 'is a kind of X' or 'is really a X';
   '2': stands 'to', for convertion services.
   \n");

$sval = $extras[0];
$opname = strtolower(trim($cmd[0]));
$outType   = 'int'; // int or std (ex. lib.issn_n2ns_formated(115))
echo "\nRESULT: ".issnLresolver($opname,$sval,$outType,$outFormat);
echo "\n";

//////////////////// LIB ////////////////////
function issnLresolver($opname,$sval,$vtype='str',$outFormat,$debug=false) {
	global $PG_CONSTR, $PG_USER, $PG_PW;
	$r = $sql = '';
	if ($opname) {
		switch ($opname) {
		case 'n2ns':
		case 'n2c':
		case 'n2cs':
		case 'isn':
		case 'isc':
    case 'n2n':
    case 'n2ns':
			$val = (!$vtype || $vtype=='str')? "'$sval'": $sval;
			$sqlFCall = "issn.{$outFormat}service($val,'$opname')";  // ex. issn_xservice(8755999,'n2ns');
			break;
		case 'info':
			$sqlFCall = "'... info formated text ...'";
			break;
		default:
			$sqlFCall = "'op-name not knowed'";
		} // switch
		$dbh = new PDO($PG_CONSTR, $PG_USER, $PG_PW);
		$sql = "SELECT $sqlFCall LIMIT 1";
    if ($debug) echo "\n$sql\n";
		$r = $dbh->query($sql)->fetchColumn();
	}
	return $debug? array($r, $sql): $r;
} // func

?>
