<?php
/**
 * DEMO. Lists options and execute.
 * http://localhost/gits/ISSN-L-resolver/webservice/
 */

include('conf.php');
if ($is_client) die("\nthis script is for-Web-only\n");

$opname = isset($_GET['opname'])? strtolower(trim($_GET['opname'])): ''; // "N2N" | "N2Ns" | "N2C" | "N2Cs" | "N2U" | "N2Us" | "isN"| "isC" | "info"
$sval = isset($_GET['sval'])? trim($_GET['sval']): ''; 				// string input
$outFormat = isset($_GET['format'])? trim($_GET['format']): 'x'; // h|x|j|t
$outType   = 'int'; // int or std (ex. lib.issn_n2ns_formated(115))
?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
  <meta charset="utf-8">
  <title>ISSN-L RESOLVER</title>
</head>

<body>
<?php

if ($opname) {
	$vtype = preg_match('/^\d+$/',$sval)? 'int': 'str';
	list($r,$sql) = issnLresolver($opname,$sval,$vtype,$outFormat,true);
	print "<h1>RESULT</h1><code>$sql</code><br/>".'<textarea rows="6" cols="120">';
	print "$r</textarea><hr/>";

} // if opname
?>

<h1>ISSN-L RESOLVER (DEMO)</h1>

<form method="GET">
	<select name="opname">
		<option>N2C</option>
		<option>N2Ns</option>
		<option>isN</option>
		<option>isC</option>
		<option>info</option>
		<option>list</option>
	</select>
    &#160;<input type="text" name="sval" value="0065-910X" />
    &#160;<input type="submit"/> (outputs XML)
    <br/> Examples of ISSN values: 115, 8755999, 8755999, 8755-9994, 0065-910X
</form>
<hr/>

This is a simple information retrivial service that returns integer or canonical ISSNs as response.
The resolution operation names was inspired in the RFC2169 jargon, for generic URNs,
<ul>
	<li>N2L = returns the main URL of an input-URN.</li>
	<li>N2Ns = returns a set of URNs related to the input-URN.</li>
	<li>N2Ls = returns all the URLs related to the input-URN.</li>
	<li>N2C = returns the canonical (preferred) URN of an input-URN.</li>
	<li>list = retrieves all component URNs (or its metadata), when component entities exists.</li>
	<li>info (default) = retrieves catalographic information or metadata of the (entity of the) URN.</li>
</ul>
The letters in these standard operation names are used in the following sense:
<ul>
	<li>"C": the canonic URN string (the "official string" and unique identifier); non-RFC2169 jargon;</li>
	<li>"N": URN, canonical or "reference URN" (a simplified non-ambiguous version of the canonical one);</li>
	<li>"L": URL (main URL is a http and secondary can by also ftp and mailto URLs, see RFC2368)</li>
	<li>"is": "isX" stands "is a kind of X" or "is really a X";</li>
	<li>"2": stands "to", for convertion services.</li>
</ul>



</body>
</html>

<?php
//////////////////// LIB ////////////////////

function issnLresolver($opname,$sval,$vtype='str',$outFormat,$debug=true) {
	global $PG_CONSTR, $PG_USER, $PG_PW;
	$r = $sql = '';
	if ($opname) {
		switch ($opname) {
		case 'n2ns':
		case 'n2c':
		case 'n2cs':
		case 'isn':
		case 'isc':
			$val = (!$vtype || $vtype=='str')? "'$sval'": $sval;
			$sqlFCall = "lib.issn_{$outFormat}service($val,'$opname')";  // ex. issn_xservice(8755999,'n2ns');
			break;
		case 'info':
			$sqlFCall = "'... info formated text ...'";
			break;
		case 'n2n':
		case 'n2u':
		case 'n2us':
			$sqlFCall = "'... operation $opname not make sense in this context ...'";
			break;
		default:
			$sqlFCall = "'op-name not knowed'";
		} // switch
		$dbh = new PDO($PG_CONSTR, $PG_USER, $PG_PW);
		$sql = "SELECT $sqlFCall LIMIT 1";
		$r = $dbh->query($sql)->fetchColumn();
	}
	return $debug? array($r, $sql): $r;
} // func

?>
