param([string]$PreviewDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$script:appDir=Split-Path $PSScriptRoot -Parent
$script:dataDir=Join-Path ([IO.Path]::GetTempPath()) ('niang-characters-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $script:dataDir
$settingsFile=Join-Path $script:dataDir 'settings.json'
. (Join-Path $script:appDir 'runtime\characters.ps1')
. (Join-Path $script:appDir 'runtime\ui-settings.ps1')
$tokens=$null;$parseErrors=$null
$source=[IO.File]::ReadAllText((Join-Path $script:appDir 'widget.ps1'),[Text.Encoding]::UTF8)
$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw ($parseErrors|Out-String)}
foreach($name in @('Write-WidgetJson','Save-Settings','Test-GirlAlpha')){
  $definition=$ast.Find({param($node)$node-is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name-eq $name},$true)
  . ([ScriptBlock]::Create($definition.Extent.Text))
}
$script:window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $script:appDir 'widget.xaml'),[Text.Encoding]::UTF8))
$script:ui=@{}
foreach($name in @('Root','Girl','MenuButton','ShortLeft','WeekLeft','ShortReset','WeekReset','Header','QuoteText')){$script:ui[$name]=$script:window.FindName($name)}
$script:scale=1.0;$script:soundVolume=0.9;$script:side='right';$script:colorChance=0.5;$script:colorTextChance=3;$script:colorMode='original'
$script:characterId='deepseek-niang';$script:checks=0
function Assert($condition,[string]$label){if(!$condition){throw ('FAIL '+$label)};$script:checks++;Write-Output ('PASS '+$label)}
function Save-RolePreview([string]$Name){
  if(!$PreviewDirectory){return}
  $null=New-Item -ItemType Directory -Path $PreviewDirectory -Force
  $script:ui.Header.Text='额度布局预览';$script:ui.ShortLeft.Text='75%';$script:ui.WeekLeft.Text='90%'
  $script:ui.ShortReset.Text='示例 · 1 小时后重置';$script:ui.WeekReset.Text='示例 · 3 天后重置'
  $visual=$script:window.Content;$visual.Measure([Windows.Size]::new(512,512));$visual.Arrange([Windows.Rect]::new(0,0,512,512));$visual.UpdateLayout()
  $render=[Windows.Media.Imaging.RenderTargetBitmap]::new(512,512,96,96,[Windows.Media.PixelFormats]::Pbgra32);$render.Render($visual)
  $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($render))
  $stream=[IO.File]::Create((Join-Path $PreviewDirectory ($Name+'.png')));try{$encoder.Save($stream)}finally{$stream.Dispose()}
}
try{
  # Generate an isolated synthetic fixture; no DSH artwork is needed in the repository or CI.
  $sourceApp=$script:appDir;$script:appDir=Join-Path $script:dataDir 'app'
  $null=New-Item -ItemType Directory -Path (Join-Path $script:appDir 'assets') -Force
  Copy-Item -LiteralPath (Join-Path $sourceApp 'assets\gpt-dragon-niang-bust.png') -Destination (Join-Path $script:appDir 'assets\gpt-dragon-niang-bust.png')
  $fixtureArt=Join-Path $script:appDir 'assets\deepseek-niang.png'
  $visual=New-Object Windows.Media.DrawingVisual;$drawing=$visual.RenderOpen()
  try{$drawing.DrawRectangle([Windows.Media.Brushes]::Purple,$null,[Windows.Rect]::new(40,40,530,570))}finally{$drawing.Close()}
  $render=[Windows.Media.Imaging.RenderTargetBitmap]::new(610,610,96,96,[Windows.Media.PixelFormats]::Pbgra32);$render.Render($visual)
  $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($render))
  $stream=[IO.File]::Create($fixtureArt);try{$encoder.Save($stream)}finally{$stream.Dispose()}
  function Get-WidgetDeepSeekArtworkCandidates {return @((Join-Path $script:dataDir 'characters\deepseek-niang.png'),(Join-Path $script:appDir 'assets\deepseek-niang.png'))}
  Initialize-WidgetCharacters
  Assert ($script:characterId-eq 'deepseek-niang') 'DSH whale girl is the default'
  Assert ($script:bitmap.PixelWidth-eq 610 -and $script:alphaStride-eq 2440) '610-pixel fixture and hit-test map loaded'
  Save-RolePreview 'deepseek-niang'
  $originalHash=(Get-FileHash -LiteralPath (Join-Path $script:appDir 'assets\deepseek-niang.png')).Hash
  $null=Set-WidgetCharacter 'gpt-niang'
  Assert ($script:characterId-eq 'gpt-niang' -and $script:alphaStride-eq $script:bitmap.PixelWidth*4) 'switching reloads alpha data with the chosen bitmap'
  Save-RolePreview 'gpt-niang'
  Initialize-WidgetSettingsMenu
  $roleItem=@($script:settingsMenuUi.Characters.Items|Where-Object{$_.Tag-eq 'deepseek-niang'})[0]
  $roleItem.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent,$roleItem))
  Assert ($script:characterId-eq 'deepseek-niang') 'the actual character menu switches the visible image'
  $saved=Get-Content -LiteralPath $settingsFile -Raw|ConvertFrom-Json
  Assert ($saved.characterId-eq 'deepseek-niang') 'menu selection persists to settings'
  $script:characterId=[string]$saved.characterId;Initialize-WidgetCharacters
  Assert ($script:characterId-eq 'deepseek-niang') 'stored selection restores on startup'
  $checked=@($script:settingsMenuUi.Characters.Items|Where-Object{$_.IsChecked})
  Assert ($checked.Count-eq 1 -and $checked[0].Tag-eq 'deepseek-niang') 'the menu has exactly one selected character'
  $fixture=Join-Path $script:dataDir 'portrait [custom].png'
  $image=Read-WidgetCharacterBitmap (Join-Path $script:appDir 'assets\deepseek-niang.png')
  $cropped=[Windows.Media.Imaging.CroppedBitmap]::new($image,[Windows.Int32Rect]::new(0,0,305,610))
  $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($cropped))
  $stream=[IO.File]::Create($fixture);try{$encoder.Save($stream)}finally{$stream.Dispose()}
  $id=Import-WidgetCharacter $fixture
  [IO.File]::Delete($fixture)
  $null=Set-WidgetCharacter $id
  Assert ($script:characterId-eq $id -and $script:bitmap.PixelWidth-eq $script:bitmap.PixelHeight) 'custom portrait imports with padding and survives removal of source'
  Assert ($script:alphaPixels[3]-eq 0) 'letterbox padding stays transparent'
  Save-Settings;$saved=Get-Content -LiteralPath $settingsFile -Raw|ConvertFrom-Json
  $script:characterId=[string]$saved.characterId;Initialize-WidgetCharacters
  Assert ($script:characterId-eq $id) 'custom selection restores from the persistent catalog'
  $catalog=Get-Content -LiteralPath (Join-Path $script:dataDir 'characters.json') -Raw|ConvertFrom-Json
  Assert ($catalog.characters[0].name-eq 'portrait [custom]') 'custom name survives Unicode-safe JSON storage'
  $script:characterId='custom-00000000000000000000000000000000';Initialize-WidgetCharacters
  Assert ($script:characterId-eq 'deepseek-niang') 'missing custom image falls back to the default'
  $before=$script:bitmap
  $rejected=$false;try{$null=Set-WidgetCharacter '../../outside'}catch{$rejected=$true}
  Assert ($rejected -and [Object]::ReferenceEquals($before,$script:bitmap)) 'invalid IDs leave the active image intact'
  Assert ((Get-FileHash -LiteralPath (Join-Path $script:appDir 'assets\deepseek-niang.png')).Hash-eq $originalHash) 'switching and importing never modify original artwork'
  $null=Import-WidgetDeepSeekArtwork $fixtureArt
  $imported=Join-Path $script:dataDir 'characters\deepseek-niang.png'
  Assert ((Get-FileHash -LiteralPath $imported).Hash-eq $originalHash) 'DSH import preserves the exact original bytes'
  [IO.File]::Delete($fixtureArt)
  $null=Set-WidgetCharacter 'deepseek-niang'
  Assert ($script:characterId-eq 'deepseek-niang') 'local DSH import keeps its dedicated character and quote profile'
  [IO.File]::Delete($imported)
  $script:characterId='deepseek-niang';Initialize-WidgetCharacters
  Assert ($script:characterId-eq 'gpt-niang') 'public checkout works without DSH artwork'
  Assert (@(Get-WidgetCharacters|Where-Object{$_.id-eq 'deepseek-niang'}).Count-eq 0) 'missing optional artwork does not create a broken menu entry'
  Write-Output ('Character checks passed: '+$script:checks)
}finally{
  $script:window.Close()
  $resolved=[IO.Path]::GetFullPath($script:dataDir)
  $temporary=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  if($resolved.StartsWith($temporary,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf)-like 'niang-characters-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}