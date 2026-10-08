# Character-local quote pools. Original source notices remain in assets.
$script:widgetQuoteAssetDir=Join-Path $PSScriptRoot '..\assets'
$script:widgetQuotesBuiltInPath=Join-Path $script:widgetQuoteAssetDir 'quotes.json'
$script:widgetQuoteRandom=New-Object System.Random
$script:widgetQuoteLastByDataDir=@{}
$script:widgetQuoteSettingsCache=@{}
function Resolve-WidgetQuoteCharacter([string]$CharacterId) {
  if(!$CharacterId){$value=Get-Variable characterId -Scope Script -ErrorAction SilentlyContinue;if($value){$CharacterId=[string]$value.Value}}
  if($CharacterId-in @('deepseek-niang','gpt-niang') -or $CharacterId-match '^custom-[a-f0-9]{32}$'){return $CharacterId}
  return 'gpt-niang'
}
function Get-WidgetQuoteCharacterName([string]$CharacterId) {
  $id=Resolve-WidgetQuoteCharacter $CharacterId
  if($id-eq 'deepseek-niang'){return '大肥鱼娘'}
  if($id-eq 'gpt-niang'){return 'GPT 娘'}
  if(Get-Command Get-WidgetCharacters -ErrorAction SilentlyContinue){$role=Get-WidgetCharacters|Where-Object{$_.id-eq $id}|Select-Object -First 1;if($role){return $role.name}}
  return '自定义人物'
}
function Get-WidgetCharacterDataPath([string]$DataDir,[string]$Kind,[string]$CharacterId) {
  if($Kind-notin @('quotes','color-triggers')){throw 'Invalid character data kind'}
  $id=Resolve-WidgetQuoteCharacter $CharacterId
  return Join-Path (Join-Path $DataDir $Kind) ($id+'.json')
}
function ConvertTo-WidgetQuoteRows($Value) {
  if($null-eq $Value){return}
  if($Value -isnot [string] -and $Value.PSObject.Properties['quotes']){$Value=$Value.quotes}
  $rows=New-Object 'System.Collections.Generic.List[object]'
  foreach($entry in @($Value)){
    $text=$null;$weight=1.0
    if($entry -is [string]){$text=$entry}
    elseif($entry -is [Collections.IDictionary]){
      $text=$entry['text']
      if($entry.Contains('weight')){try{$weight=[double]$entry['weight']}catch{continue}}
    }elseif($null-ne $entry -and $entry.PSObject.Properties['text']){
      $text=$entry.text
      if($entry.PSObject.Properties['weight']){try{$weight=[double]$entry.weight}catch{continue}}
    }
    if($text -isnot [string]){continue}
    $text=$text.Trim()
    if(!$text -or $text.Length-gt 200 -or $text-match '[\x00-\x08\x0B\x0C\x0E-\x1F]'){continue}
    if([double]::IsNaN($weight) -or [double]::IsInfinity($weight) -or $weight-le 0 -or $weight-gt 1000){continue}
    $duplicate=$null
    foreach($row in $rows){if([string]::Equals($row.text,$text,[StringComparison]::Ordinal)){$duplicate=$row;break}}
    if($duplicate){$duplicate.weight=[Math]::Min(1000.0,$duplicate.weight+$weight)}
    else{$rows.Add([pscustomobject]@{text=$text;weight=$weight})}
  }
  foreach($row in $rows){$row}
}

function Read-WidgetQuoteFile([string]$Path) {
  $json=[IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
  @(ConvertTo-WidgetQuoteRows $json)
}

function Get-WidgetQuoteSettings([string]$DataDir,[string]$CharacterId,[switch]$Refresh) {
  $id=Resolve-WidgetQuoteCharacter $CharacterId
  $cacheKey=[IO.Path]::GetFullPath($DataDir)+'|'+$id
  if(!$Refresh -and $script:widgetQuoteSettingsCache.ContainsKey($cacheKey)){return $script:widgetQuoteSettingsCache[$cacheKey]}
  $customPath=Get-WidgetCharacterDataPath $DataDir 'quotes' $id
  $rows=@();$problem=$null;$source='built-in'
  if([IO.File]::Exists($customPath)){
    try{$rows=@(Read-WidgetQuoteFile $customPath);if($rows.Count-gt 0){$source='custom'}else{$problem='自定义语录没有有效条目，已使用此人物的内置语录。'}}
    catch{$problem='自定义语录无法读取，已使用此人物的内置语录。'}
  }
  if($rows.Count-eq 0 -and $id-in @('deepseek-niang','gpt-niang')){
    try{$rows=@(Read-WidgetQuoteFile (Join-Path $script:widgetQuoteAssetDir ('quotes-'+$id+'.json')))}catch{$rows=@()}
  }
  if($rows.Count-eq 0){
    $source='fallback'
    $text=if($id-eq 'deepseek-niang'){'DeepSleep...'}elseif($id-eq 'gpt-niang'){'Ciallo～ 今天也请多关照。'}else{'我在这儿，慢慢来就好。'}
    $rows=@([pscustomobject]@{text=$text;weight=1.0})
  }
  $result=[pscustomobject]@{source=$source;characterId=$id;characterName=(Get-WidgetQuoteCharacterName $id);quotes=@($rows);customPath=$customPath;error=$problem}
  $script:widgetQuoteSettingsCache[$cacheKey]=$result
  return $result
}
function Get-WidgetQuote([string]$DataDir,[string]$CharacterId) {
  $settings=Get-WidgetQuoteSettings $DataDir $CharacterId
  $key=[IO.Path]::GetFullPath($DataDir)+'|'+$settings.characterId
  $last=$script:widgetQuoteLastByDataDir[$key]
  $candidates=@(foreach($row in $settings.quotes){if(![string]::Equals($row.text,$last,[StringComparison]::Ordinal)){$row}})
  if($candidates.Count-eq 0){$candidates=@($settings.quotes)}
  $total=0.0;foreach($entry in $candidates){$total+=$entry.weight}
  $draw=$script:widgetQuoteRandom.NextDouble()*$total;$choice=$candidates[$candidates.Count-1]
  foreach($entry in $candidates){$draw-=$entry.weight;if($draw-lt 0){$choice=$entry;break}}
  $script:widgetQuoteLastByDataDir[$key]=$choice.text
  [string]$choice.text
}
function Save-WidgetQuotes([string]$DataDir,$Quotes,[string]$CharacterId) {
  $rows=@(ConvertTo-WidgetQuoteRows $Quotes)
  if($rows.Count-eq 0){throw '请至少填写一条有效语录；每条最多 200 字，权重须大于 0 且不超过 1000。'}
  $id=Resolve-WidgetQuoteCharacter $CharacterId
  $file=Get-WidgetCharacterDataPath $DataDir 'quotes' $id
  $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($file));$temp=$file+'.'+$PID+'.tmp'
  try{
    $json=@{version=2;characterId=$id;quotes=@($rows)}|ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($temp,$json,[Text.UTF8Encoding]::new($true))
    if([IO.File]::Exists($file)){[IO.File]::Replace($temp,$file,($file+'.bak'),$true)}else{[IO.File]::Move($temp,$file)}
  }finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
  Get-WidgetQuoteSettings $DataDir $id -Refresh
}
function Reset-WidgetQuotes([string]$DataDir,[string]$CharacterId) {
  $id=Resolve-WidgetQuoteCharacter $CharacterId;$file=Get-WidgetCharacterDataPath $DataDir 'quotes' $id
  if([IO.File]::Exists($file)){[IO.File]::Copy($file,($file+'.bak'),$true);[IO.File]::Delete($file)}
  Get-WidgetQuoteSettings $DataDir $id -Refresh
}
function Initialize-WidgetQuoteProfiles([string]$DataDir) {
  $marker=Join-Path $DataDir 'quotes-migration-v2.json'
  if(Test-Path -LiteralPath $marker){return}
  $legacy=Join-Path $DataDir 'quotes.json';$groups=@{'deepseek-niang'=@();'gpt-niang'=@()}
  $current=Resolve-WidgetQuoteCharacter ''
  if([IO.File]::Exists($legacy)){
    # Leave the old file intact, and preserve a separate original copy before splitting it.
    $backup=Join-Path $DataDir 'quotes-before-character-split.json'
    if(![IO.File]::Exists($backup)){[IO.File]::Copy($legacy,$backup,$false)}
    $ds=@(Read-WidgetQuoteFile (Join-Path $script:widgetQuoteAssetDir 'quotes-deepseek-niang.json')).text
    $gpt=@(Read-WidgetQuoteFile (Join-Path $script:widgetQuoteAssetDir 'quotes-gpt-niang.json')).text
    foreach($row in @(Read-WidgetQuoteFile $legacy)){
      $target=if($ds-contains $row.text){'deepseek-niang'}elseif($gpt-contains $row.text){'gpt-niang'}else{$current}
      if(!$groups.ContainsKey($target)){$groups[$target]=@()};$groups[$target]+=$row
    }
    foreach($id in @($groups.Keys)){
      if($groups[$id].Count-gt 0 -and ![IO.File]::Exists((Get-WidgetCharacterDataPath $DataDir 'quotes' $id))){$null=Save-WidgetQuotes $DataDir $groups[$id] $id}
    }
  }
  Write-WidgetJson $marker @{version=2;legacyPreserved=[IO.File]::Exists($legacy)}
}