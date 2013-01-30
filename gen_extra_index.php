<?php

function FilenameInfix($filename) {
  $base_filename = basename($filename);
  $base_filename = preg_replace("/LCIDC01_/", "", $base_filename); 
  $base_filename = preg_replace("/\.html/", "", $base_filename); 
  return $base_filename;
}

function IndexParseKey($content) {
  return $content['gazette'] . $content['book'] . sprintf("%03d", $content['seq']);
}

function Index() {
  if(isset($GLOBALS['INDEX'])) return $GLOBALS['INDEX'];

  $content = file_get_contents("data/index.json");
  $content_st = json_decode($content, true);

  $result = array();
  foreach($content_st as $each_content) {
    $the_key = IndexParseKey($each_content);
    $result[$the_key] = $each_content;
  }

  $GLOBALS['INDEX'] = $result;
  return $result;
}

function IndexMapping($index) {
  if(isset($GLOBALS['INDEX_MAPPING'])) return $GLOBALS['INDEX_MAPPING'];

  $result = array();

  foreach($index as $each_index) {
    if(empty($each_index['files'])) continue;
    $gazette = $each_index['gazette'];
    $url = $each_index['files'][0];
    $filename = preg_replace("/.*\//smu", "", $url); 
    $filename_infix = substr($filename, 8);
    $mapping = substr($filename_infix, 0, -12);
    $result[$mapping] = $gazette;
  }

  $result['9824'] = 3710;
  $result['9997'] = 3828;
  $result['9999'] = 3828;

  $GLOBALS['INDEX_MAPPING'] = $result;
  return $result;
}

function Gazette($filename_infix, $index_mapping) {
  $mapping = substr($filename_infix, 0, -8);
  return $index_mapping[$mapping];
}

function Book($filename_infix) {
  $result = substr($filename_infix, -8, 2);
  return $result;
}

function Seq($filename_infix) {
  $result = substr($filename_infix, -5, 5);
  $result = (int)$result;
  $result = (string)$result;

  return $result;
}

function TheType($content, $filename_infix) {
  $pattern_ary = array("立法院公報\s+第.*?卷\s+第.*?期\s+(.*?)<\/SPAN>",
                         "<TITLE>(.*?)<\/TITLE>");

  $match_ary = array();
  foreach($pattern_ary as $each_pattern) {
    $the_pattern = "/" . $each_pattern . "/smu";
    if(preg_match($the_pattern, $content, $match_ary)) {
      $result = $match_ary[1];
      $result = preg_replace("/\s+/u", "", $result); 
      break;
    }
  }

  $special_ary = array('903004_00003' => '議事錄',
                       '910201_00004' => '議事錄',
                       '982401_00005' => '質詢事項',
                       '982401_00006' => '質詢事項'
    );
  if(isset($special_ary[$filename_infix])) $result = $special_ary[$filename_infix];

  return $result;
}

function Summary($content, $the_type, $filename_infix) {
  $pattern_ary = array(
    "<P STYLE=\"margin-left.*?SIZE=4>(.*?)<\/FONT><\/P>",
    "SIZE=4>(.*?)<\/FONT><\/P>",
    "<TITLE>(.*?)<\/TITLE>");

  $result = $the_type;
  $match_ary = array();

  $special_char_ary = array(json_decode('"\ue8f6"'), json_decode('"\ue8f4"'));

  foreach($pattern_ary as $each_pattern) {
    $the_pattern = "/" . $each_pattern . "/smu";
    if(preg_match($the_pattern, $content, $match_ary)) {
      $result = $match_ary[1];
      $result = preg_replace("/\s+/u", "", $result); 
      $result = preg_replace("/<.*?>/smu", "", $result); 
      $result = preg_replace("/會議紀錄.*/smu", "會議紀錄", $result); 
      $result = preg_replace("/勘誤表.*/smu", "勘誤表", $result); 
      $result = preg_replace("/.*、/u", "", $result);
      $result = preg_replace("/[ \p{C}]/u", "", $result);

      if($the_type == "委員會紀錄" && $result == "報告事項") continue;
      break;
    }
  }
  if(preg_match("/補\s*?刊：?.*?<\/FONT><\/P>/smu", $content)) $result = "補刊";
  if(preg_match("/補\s*<.*?>\s*刊：?.*?<\/FONT><\/P>/smu", $content)) $result = "補刊";

  $result = trim($result);
  if($result === "") $result = $the_type;

  $special_ary = array(
                       '916701_00007' => '補刊',
                       '916801_00003' => '補刊',
                       '943001_00005' => '繼續開會（17時20分）',
                       '982401_00005' => '甲、行政院答復部分'
    );
  if(isset($special_ary[$filename_infix])) $result = $special_ary[$filename_infix];

  return $result;
}

function Url($filename_infix) {
  $year = substr($filename_infix, 0, -10);
  $vol = substr($filename_infix, -10, 2);
  $url_prefix = $year >= 100 ? "http://lci.ly.gov.tw/LyLCEW/communique1/work" : "http://lci.ly.gov.tw/LyLCEW/communique/work";
  $filename = "LCIDC01_" . $filename_infix . ".doc";
  $url = $url_prefix . "/" . $year . "/" . $vol . "/" . $filename;
  return $url;
}

function TheTypeBySummary($summary, $the_type) {
  if($summary == "本期委員發言紀錄索引") $the_type = "索引";

  return $the_type;
}

function ProcessFile($filename) {
  $content = file_get_contents($filename);
  $filename_infix = FilenameInfix($filename);

  $index = Index();
  $index_mapping = IndexMapping($index);

  $gazette = Gazette($filename_infix, $index_mapping);
  $book = Book($filename_infix);
  $seq = Seq($filename_infix);
  $the_type = TheType($content, $filename_infix);
  $summary = Summary($content, $the_type, $filename_infix);
  $the_type = TheTypeBySummary($summary, $the_type);
  $url = Url($filename_infix);
  
  $files = array($url);
  
  $result = array('gazette' => $gazette,
                  'book' => $book,
                  'seq' => $seq,
                  'type' => $the_type,
                  'summary' => $summary,
                  'files' => $files);
  return $result;
}

function Main($argv) {
  $filename_list = $argv[1];
  $content = file_get_contents($filename_list);
  $lines = preg_split("/\n/u", $content);

  $result_ary = array();
  foreach($lines as $each_filename) {
    if($each_filename === "") continue;
    $result_ary[] = ProcessFile($each_filename);
  }

  echo json_encode($result_ary, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
}

if(count($argv) != 2) {
  echo "usage: php gen_extra_index.php [filename_list]\n";
  exit;
}

Main($argv);

?>