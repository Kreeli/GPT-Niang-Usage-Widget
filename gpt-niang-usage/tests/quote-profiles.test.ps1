$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$script:appDir=Split-Path $PSScriptRoot -Parent
$script:dataDir=Join-Path ([IO.Path]::GetTempPath()) ('niang-profiles-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $script:dataDir
. (Join-Path $script:appDir 'runtime\quotes.ps1')
. (Join-Path $script:appDir 'runtime\characters.ps1')
. (Join-Path $script:appDir 'runtime\ui-settings.ps1')
. (Join-Path $script:appDir 'runtime\color-theme.ps1')
. (Join-Path $script:appDir 'runtime\quote-layout.ps1')
Initialize-WidgetQuoteLayouts $script:appDir
$source=[IO.File]::ReadAllText((Join-Path $script:appDir 'widget.ps1'),[Text.Encoding]::UTF8)
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
foreach($name in @('Write-WidgetJson','Switch-Scene')){
 $definition=$ast.Find({param($node)$node-is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name-eq $name},$true)
 . ([ScriptBlock]::Create($definition.Extent.Text))
}
function Animate-Value {}
function Restart-SceneTtl {}
$script:window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $script:appDir 'widget.xaml'),[Text.Encoding]::UTF8))
$script:ui=@{};foreach($name in @('Girl','QuoteText','SceneText')){$script:ui[$name]=$script:window.FindName($name)}
$script:characterId='deepseek-niang';$script:collapsed=$true;$script:checks=0
function Assert($condition,[string]$label){if(!$condition){throw ('FAIL '+$label)};$script:checks++;Write-Output ('PASS '+$label)}
try{
 $ds=Get-WidgetQuoteSettings $script:dataDir 'deepseek-niang';$gpt=Get-WidgetQuoteSettings $script:dataDir 'gpt-niang'
 Assert ($ds.quotes.Count-ge 35 -and $gpt.quotes.Count-ge 20) 'both characters load their own full built-in pools'
 Assert ($ds.customPath-ne $gpt.customPath -and $ds.quotes.text-contains '没吃饱喵' -and $gpt.quotes.Count-eq 33) 'each role has its own source file; cute DSH lines and all 33 original GPT lines are retained'
 Assert (($ds.quotes.text-contains 'DeepSleep...') -and !($gpt.quotes.text-contains 'DeepSleep...') -and ($gpt.quotes.text-contains '我是啥龙？')) 'whale and dragon identity lines stay with the correct character'
 for($i=0;$i-lt 100;$i++){
   $script:characterId=if($i%2){'gpt-niang'}else{'deepseek-niang'}
   $text=Get-WidgetQuote $script:dataDir
   $expected=if($script:characterId-eq 'gpt-niang'){$gpt.quotes.text}else{$ds.quotes.text}
   if($expected-notcontains $text){throw 'Cross-character quote leak'}
 }
 Assert $true '100 alternating selections never draw from the other character'
 $null=Save-WidgetQuotes $script:dataDir @('DeepSeek 自定义 A','DeepSeek 自定义 B') 'deepseek-niang'
 $null=Save-WidgetQuotes $script:dataDir @('GPT 自定义 A','GPT 自定义 B') 'gpt-niang'
 Assert ((Get-WidgetQuoteSettings $script:dataDir 'deepseek-niang').quotes[0].text-eq 'DeepSeek 自定义 A' -and (Get-WidgetQuoteSettings $script:dataDir 'gpt-niang').quotes[0].text-eq 'GPT 自定义 A') 'custom lists save independently'
 $null=Reset-WidgetQuotes $script:dataDir 'gpt-niang'
 Assert ((Get-WidgetQuoteSettings $script:dataDir 'gpt-niang').source-eq 'built-in' -and (Get-WidgetQuoteSettings $script:dataDir 'deepseek-niang').source-eq 'custom') 'reset affects only one character'
 $custom='custom-0123456789abcdef0123456789abcdef';$null=Save-WidgetQuotes $script:dataDir @('我自己的角色') $custom
 Assert ((Get-WidgetQuoteSettings $script:dataDir $custom).quotes[0].text-eq '我自己的角色') 'imported character has independent local quotes'
 $badPath=Get-WidgetCharacterDataPath $script:dataDir 'quotes' '../../outside'
 Assert ((Split-Path $badPath -Leaf)-eq 'gpt-niang.json') 'unsafe profile identifiers cannot escape the state directory'
 $script:characterId='deepseek-niang';$script:collapsed=$false;$script:bubbleMode='quote'
 $null=Set-WidgetCharacter 'gpt-niang'
 Assert ((Get-WidgetQuoteSettings $script:dataDir 'gpt-niang').quotes.text-contains [string]$script:ui.QuoteText.Tag) 'switching character replaces the actual visible speech text'
 $script:sceneTimer.Stop();$script:collapsed=$true
 $null=[Windows.Interop.WindowInteropHelper]::new($script:window).EnsureHandle()
 $script:characterId='deepseek-niang';Open-QuoteEditor;$script:quoteEditor.Hide()
 Assert ($script:quoteEditor.Title-like '大肥鱼娘*' -and $script:quoteEditor.Tag-eq 'deepseek-niang') 'quote editor names and captures its character'
 $script:characterId='gpt-niang';$script:quoteEditor.FindName('Lines').Text='编辑器保存给原人物'
 $button=$script:quoteEditor.FindName('Save');$button.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent,$button))
 Assert ((Get-WidgetQuoteSettings $script:dataDir 'deepseek-niang').quotes[0].text-eq '编辑器保存给原人物' -and (Get-WidgetQuoteSettings $script:dataDir 'gpt-niang').source-eq 'built-in') 'changing character behind an open editor cannot save into the wrong list'
 $script:quoteEditor.Close();$script:quoteEditor=$null
 $migration=Join-Path $script:dataDir 'migration';$null=New-Item -ItemType Directory -Path $migration
 Write-WidgetJson (Join-Path $migration 'quotes.json') @{version=1;quotes=@(@{text='DeepSleep...';weight=3},@{text='我是啥龙？';weight=2},@{text='我的新句子';weight=4})}
 $hash=(Get-FileHash (Join-Path $migration 'quotes.json')).Hash
 $script:characterId='deepseek-niang';Initialize-WidgetQuoteProfiles $migration
 Assert ((Get-WidgetQuoteSettings $migration 'deepseek-niang').quotes.text-contains '我的新句子' -and (Get-WidgetQuoteSettings $migration 'gpt-niang').quotes.text-notcontains '我的新句子') 'legacy known lines split by origin and new custom lines follow the selected character'
 Assert ((Get-FileHash (Join-Path $migration 'quotes.json')).Hash-eq $hash -and (Get-FileHash (Join-Path $migration 'quotes-before-character-split.json')).Hash-eq $hash) 'migration preserves the exact original and backup bytes'
 $null=Save-WidgetQuotes $migration @('后来改的 GPT 台词') 'gpt-niang';Initialize-WidgetQuoteProfiles $migration
 Assert ((Get-WidgetQuoteSettings $migration 'gpt-niang').quotes[0].text-eq '后来改的 GPT 台词') 'migration runs once and cannot overwrite later edits'
 $script:characterId='deepseek-niang';Read-WidgetColorTriggers
 Assert ($script:colorSpecialQuotes-contains 'DeepSleep...') 'special triggers follow the selected character'
 $script:characterId='gpt-niang';Read-WidgetColorTriggers
 Assert ($script:colorSpecialQuotes-notcontains 'DeepSleep...') 'special triggers do not leak into GPT'
 Write-Output ('Character quote checks passed: '+$script:checks)
}finally{
 if($script:sceneTimer){$script:sceneTimer.Stop()};if($script:quoteEditor){$script:quoteEditor.Close()};$script:window.Close()
 $resolved=[IO.Path]::GetFullPath($script:dataDir);$prefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
 if($resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf)-like 'niang-profiles-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}