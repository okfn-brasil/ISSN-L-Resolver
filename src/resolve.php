<?php
/**
 * Run as web-service or terminal command. Requires PHP v7.1.
 * Commands  N2C,N2Ns,isN,isC,info, list, ...
 * By terminal:
 *   php resolve.php -j --n2n 12345
 *   php resolver.php -j -q 12345/n2c
 * By Web:
 *  http://issn.oficial.news/123/N2C
 *  http://teste.oficial.news/resolve.php?opname=n2c&issn7=1
 *  http://teste.oficial.news/resolve.php?opname=N2Ns&issn=0001-3439&format=x
 */

include('conf.php');
$format_dft = 'j';
$debug = 0;

if ($is_cli) {
  $optind = null;
  $opts = getopt('hjxdq:', $cmdValid, $optind); // exige PHP7.1  -d=debug
  $extras = array_slice($argv, $optind);
  $outFormat = isset($opts['x'])? 'x': (isset($opts['t'])? 't': $format_dft);  // x|j|t
  unset($opts['x']);unset($opts['j']);
  $cmd = array_keys($opts);
  if (isset($opts['q']))
      list($opname,$sval,$outType,$outFormat) = apiGateway_parsePath($opts['q']);
  else {
  	if (isset($opts['h']) || !count($extras) || count($cmd)!=1)
    		die("\n---- ISSN-L RESOLVER -----\n".file_get_contents('synopsis.txt')." \n");
  	$sval = $extras[0];
  	$opname = strtolower(trim($cmd[0]));
  	$outType   = 'int';
	//$debug =0;
  }
} elseif (isset($_GET['q']))
  list($opname,$sval,$outType,$outFormat) = apiGateway_parsePath($_GET['q']);
else {
 	$opname = isset($_GET['opname'])? strtolower(trim($_GET['opname'])): '';
 	$sval = isset($_GET['sval'])? trim($_GET['sval']): ''; 				// string input
 	$outFormat = isset($_GET['format'])? trim($_GET['format']): 'x'; // h|x|j|t
 	$outType   = 'int';
        $debug = isset($_GET['debug'])? 1: 0;
}

if (!$sval)  {
  echo file_get_contents('index.htm');
  die("\n");
}
if (!$is_cli && !$debug) {
  if ($status!=200) http_response_code($status);
	header("Content-Type: $outFormatMime[$outFormat]");
}

//echo "\n\n-- $opname,$sval,$outType,$outFormat,$debug\n";
$output = issnLresolver($opname,$sval,$outType,$outFormat,$debug);
if ($debug)
  echo "issnLresolver($opname,$sval,$outType,$outFormat) = [\n\tstatus $status, \n\tout $output[0], \n\tsql $output[1] ]";
elseif ($outFormat=='j')
  echo json_encode($output);
else
  echo $output;

//////////////////// LIB ////////////////////

function apiGateway_parsePath($q) {
   if (preg_match('#^/?(\d+)/(n2ns|n2c|is[nc])(\.(?:js|json|xml|txt))?$#is', $q, $m))
      $inType   = 'int';
   elseif (preg_match('#^/?([0-9][\d\-]*X?)/(n2ns|n2c|is[nc])(\.(?:js|json|xml|txt))?$#is', $q, $m))
      $inType   = 'str';
   else
     die("\nERROR 23: '$q'\n");
   $sval = $m[1];
   $opname = strtolower($m[2]); // cmd
   $outFormat=isset($m[3])? substr($m[3],0,1): 'x';
   return [$opname,$sval,$inType,$outFormat];
  }

function issnLresolver($opname,$sval,$vtype='str',$outFormat,$debug=1) {
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
		//ja tem if ($debug) echo "\n-- SQL=$sql\n";
		$r = $dbh->query($sql)->fetchColumn();
		//$r = trim($r,'"');
  } //switch
	return $debug? array($r, $sql): $r;
} // func

?>
