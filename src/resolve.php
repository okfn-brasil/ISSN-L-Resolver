<?php
/**
 * Index or include for console.  Basic GENERIC APP SERVER for SQL-defined services.
 * For OpenAPI implementation of a SQL-based set of services.
 * Best alternative: PostGraphQL
 * @see https://github.com/okfn-brasil/ISSN-L-Resolver
 * @see future, output accept content negotiation...
 */


$isCli = (php_sapi_name() === 'cli');
$res = new app($isCli? (isset($argv[1])? $argv[1]: 'issn/67/n2ns'): $_SERVER['QUERY_STRING']);

class app {

  // CONFIGS:
  var $PG_CONSTR = 'pgsql:host=localhost;port=5432;dbname=issnl';
  var $PG_USER = 'postgres';
  var $PG_PW   = 'postgres';

  // INITS:
  var $status = 200;  // 404 - has not found the input issn.  416 - issn format is invalid.
                      // but 404 is also service-not-found.
  var $isCli;         // set with true when is client (terminal), else false.
  var $outFormat_dft='j';

  var $outFormat;     // j=json|x=xml|t=txt
  var $dbh; // database PDF connection.

  function __construct($uri=NULL) {
    global $isCli;
    $this->isCli = isset($isCli)? $isCli: (php_sapi_name() === 'cli');
    $this->outFormat = $this->isCli? 't': $this->outFormat_dft;
    $this->dbh = new PDO($this->PG_CONSTR, $this->PG_USER, $this->PG_PW);
    if ($uri) $this->runByUri($uri); // dies returing output
  }

  function runByUri($uri) {
    //if ($this->isCli) $uri.=".".$this->outFormat; // enforce ... future content negotiation.
    //echo "\n SELECT api.run_byuri('$uri')";
    $sth = $this->dbh->prepare('SELECT api.run_byuri(?)');
    $sth->bindParam(1, $uri, PDO::PARAM_STR);
    $sth->execute();
    $a = json_decode( $sth->fetchColumn(), true); // even XML is into a JSON package.
    if (isset($a['status']) && $a['status']>0) {
      $this->status = $a['status'];
      $r = $a['result'];
    } else
      $r = $a;
    $this->die(json_encode($r)); // need error code?
  }

  /**
   * Ending API by die() with no message or with an error.
   * @param $msg string with returning data from API (or standard error package).
   * @param $errCode integer, used as ERRROR when $this->status!=200 or as WARNING when $errCode!=0.
   * @param $newStatus integer optional change of HTTP-status.
   */
  function die($msg,$errCode=0,$newStatus=0) {
    $outFormatMime = ['j'=>'application/json', 'x'=>'application/xml', 't'=>'text/plain'];  // MIME
    if ($newStatus)
      $this->status = $newStatus;
    if ($this->status==200 || !$this->status)
      $OUT = ($this->outFormat!='x')? (($this->outFormat=='t')? "\n$msg\n": $msg): "<api>$msg</api>";
    elseif ($this->isCli)
        die("\nERROR (status {$this->status}) $errCode: $msg\n");
    else {
      http_response_code($this->status);
      if ($errCode)
        $OUT = ($this->outFormat=='j')?
          "{'errCode':$errCode,'errMsg':'$msg'}":
          "<api errCode='$errCode'><errMsg>$msg</errMsg></api>";
      else
        $OUT = ($this->outFormat=='j')? $msg: "<api>$msg</api>";
    }
    if (!$this->isCli) header("Content-Type: {$outFormatMime[$this->outFormat]}");
    die($OUT);
  } // func

} // class

?>
