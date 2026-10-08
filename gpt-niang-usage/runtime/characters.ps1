# DSH artwork stays local: its provenance does not grant redistribution rights.
function Get-WidgetDeepSeekArtworkCandidates {
  $paths=@((Join-Path $script:dataDir 'characters\deepseek-niang.png'),(Join-Path $script:appDir 'assets\deepseek-niang.png'))
  if($env:USERPROFILE){$paths+=(Join-Path $env:USERPROFILE '.dsh\profiles\desktop\node_modules\dsh-whale-widget\assets\DSniang1.png')}
  return $paths
}
function Get-WidgetDeepSeekArtwork {
  foreach($path in @(Get-WidgetDeepSeekArtworkCandidates)){if(Test-Path -LiteralPath $path -PathType Leaf){return $path}}
  return $null
}
function Import-WidgetDeepSeekArtwork([string]$Path) {
  if([IO.Path]::GetExtension($Path).ToLowerInvariant()-ne '.png'){throw '请选择 DSH 的 DSniang1.png 原图。'}
  $null=Read-WidgetCharacterBitmap $Path
  $directory=Join-Path $script:dataDir 'characters';$null=New-Item -ItemType Directory -Path $directory -Force
  $destination=Join-Path $directory 'deepseek-niang.png'
  if([IO.Path]::GetFullPath($Path)-ne [IO.Path]::GetFullPath($destination)){Copy-Item -LiteralPath $Path -Destination $destination -Force}
  return 'deepseek-niang'
}
function Open-WidgetDeepSeekImport {
  $dialog=New-Object Microsoft.Win32.OpenFileDialog
  $dialog.Title='选择 DSH 大肥鱼娘原图 DSniang1.png';$dialog.Filter='PNG 原图 (*.png)|*.png';$dialog.CheckFileExists=$true;$dialog.Multiselect=$false
  if($dialog.ShowDialog($script:window)-ne $true){return}
  try{$id=Import-WidgetDeepSeekArtwork $dialog.FileName;$null=Set-WidgetCharacter $id;Save-Settings;Update-WidgetSettingsMenu}
  catch{[Windows.MessageBox]::Show($script:window,$_.Exception.Message,'未能导入大肥鱼娘')|Out-Null}
}
# Shared character selection for the original GPT widget and the DSH whale girl.
function Get-WidgetCharacters {
  $roles=@();$deepSeek=Get-WidgetDeepSeekArtwork
  if($deepSeek){$roles+=[pscustomobject]@{id='deepseek-niang';name='大肥鱼娘 · 蓝发女仆';path=$deepSeek;custom=$false}}
  $roles+=[pscustomobject]@{id='gpt-niang';name='GPT 娘 · 白发龙娘';path=(Join-Path $script:appDir 'assets\gpt-dragon-niang-bust.png');custom=$false}
  $catalog=Join-Path $script:dataDir 'characters.json'
  if(Test-Path -LiteralPath $catalog){
    try{
      $saved=Get-Content -LiteralPath $catalog -Raw -Encoding UTF8|ConvertFrom-Json
      foreach($entry in @($saved.characters)){
        if([string]$entry.id -notmatch '^custom-[a-f0-9]{32}$'){continue}
        $name=([string]$entry.name).Trim();if(!$name){continue}
        $file=Join-Path $script:dataDir ('characters\'+$entry.id+'.png')
        if(Test-Path -LiteralPath $file -PathType Leaf){$roles+=[pscustomobject]@{id=[string]$entry.id;name=$name;path=$file;custom=$true}}
      }
    }catch{}
  }
  return @($roles)
}
function Read-WidgetCharacterBitmap([string]$Path) {
  $file=Get-Item -LiteralPath $Path -ErrorAction Stop
  if($file.PSIsContainer -or $file.Length-le 0 -or $file.Length-gt 20MB){throw '人物图片须为不超过 20 MB 的图片文件。'}
  $image=New-Object Windows.Media.Imaging.BitmapImage
  $image.BeginInit();$image.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
  $image.UriSource=[Uri]$file.FullName;$image.EndInit();$image.Freeze()
  if($image.PixelWidth-le 0 -or $image.PixelHeight-le 0 -or $image.PixelWidth-gt 8192 -or $image.PixelHeight-gt 8192){throw '人物图片的宽和高须在 1 到 8192 像素之间。'}
  return $image
}
function Set-WidgetCharacter([string]$Id) {
  $role=@(Get-WidgetCharacters|Where-Object{$_.id-eq $Id})|Select-Object -First 1
  if(!$role){throw '找不到这个人物，请重新选择。'}
  # Decode and prepare the new alpha map before replacing the active image.
  $image=Read-WidgetCharacterBitmap $role.path
  $alpha=New-Object Windows.Media.Imaging.FormatConvertedBitmap($image,[Windows.Media.PixelFormats]::Bgra32,$null,0)
  $stride=$image.PixelWidth*4;$pixels=New-Object byte[] ($stride*$image.PixelHeight)
  $alpha.CopyPixels($pixels,$stride,0)
  $script:bitmap=$image;$script:alphaBitmap=$alpha;$script:alphaStride=$stride;$script:alphaPixels=$pixels
  $script:ui.Girl.Source=$image;$script:characterId=$role.id
  if($script:widgetColors){
    $mask=[Windows.Media.ImageBrush]::new($image);$mask.Stretch=[Windows.Media.Stretch]::Uniform
    $script:widgetColors.halo.OpacityMask=$mask;$script:widgetColors.tint.OpacityMask=$mask
  }
  if(Get-Command Read-WidgetColorTriggers -ErrorAction SilentlyContinue){Read-WidgetColorTriggers}
  # A visible speech bubble must switch along with its character, never keep the previous role's line.
  if(!$script:collapsed -and $script:bubbleMode-eq 'quote' -and (Get-Command Switch-Scene -ErrorAction SilentlyContinue)){Switch-Scene 'quote'}
  return $role
}
function Initialize-WidgetCharacters {
  try{$null=Set-WidgetCharacter $script:characterId}
  catch{
    try{$null=Set-WidgetCharacter 'deepseek-niang'}catch{$null=Set-WidgetCharacter 'gpt-niang'}
  }
}
function Import-WidgetCharacter([string]$Path) {
  if([IO.Path]::GetExtension($Path).ToLowerInvariant()-notin @('.png','.jpg','.jpeg','.bmp')){throw '请选择 PNG、JPG 或 BMP 人物图片。'}
  $image=Read-WidgetCharacterBitmap $Path
  # Transparent square padding preserves the whole image and the hit-test geometry.
  $size=[int][Math]::Min(2048,[Math]::Max($image.PixelWidth,$image.PixelHeight))
  $fit=[Math]::Min($size/$image.PixelWidth,$size/$image.PixelHeight)
  $width=$image.PixelWidth*$fit;$height=$image.PixelHeight*$fit
  $visual=New-Object Windows.Media.DrawingVisual;$drawing=$visual.RenderOpen()
  try{$drawing.DrawImage($image,[Windows.Rect]::new(($size-$width)/2,$size-$height,$width,$height))}finally{$drawing.Close()}
  $render=[Windows.Media.Imaging.RenderTargetBitmap]::new($size,$size,96,96,[Windows.Media.PixelFormats]::Pbgra32);$render.Render($visual)
  $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($render))
  $id='custom-'+[Guid]::NewGuid().ToString('N');$directory=Join-Path $script:dataDir 'characters'
  $null=New-Item -ItemType Directory -Path $directory -Force
  $destination=Join-Path $directory ($id+'.png');$stream=[IO.File]::Create($destination)
  try{$encoder.Save($stream)}finally{$stream.Dispose()}
  $name=[IO.Path]::GetFileNameWithoutExtension($Path);if($name.Length-gt 60){$name=$name.Substring(0,60)}
  $entries=@(Get-WidgetCharacters|Where-Object{$_.custom}|ForEach-Object{@{id=$_.id;name=$_.name}})
  $entries+=@{id=$id;name=$name}
  Write-WidgetJson (Join-Path $script:dataDir 'characters.json') @{version=1;characters=$entries}
  return $id
}
function Open-WidgetCharacterImport {
  $dialog=New-Object Microsoft.Win32.OpenFileDialog
  $dialog.Title='导入人物图片';$dialog.Filter='人物图片 (*.png;*.jpg;*.jpeg;*.bmp)|*.png;*.jpg;*.jpeg;*.bmp'
  $dialog.CheckFileExists=$true;$dialog.Multiselect=$false
  if($dialog.ShowDialog($script:window)-ne $true){return}
  try{
    $id=Import-WidgetCharacter $dialog.FileName;$null=Set-WidgetCharacter $id
    Save-Settings;Update-WidgetSettingsMenu
  }catch{[Windows.MessageBox]::Show($script:window,$_.Exception.Message,'未能导入人物')|Out-Null}
}
function Update-WidgetCharacterMenu {
  if(!$script:settingsMenuUi.Characters){return}
  $menu=$script:settingsMenuUi.Characters;$menu.Items.Clear()
  $previous=$script:settingsMenuTarget;$script:settingsMenuTarget=$menu
  try{
    foreach($role in @(Get-WidgetCharacters)){
      $item=Add-SettingsAction $role.name {
        param($sender,$event)
        try{$null=Set-WidgetCharacter ([string]$sender.Tag);Save-Settings;Update-WidgetSettingsMenu}
        catch{[Windows.MessageBox]::Show($script:window,$_.Exception.Message,'未能切换人物')|Out-Null}
        $event.Handled=$true
      } -Checkable -ReturnItem
      $item.Tag=$role.id;$item.IsChecked=$role.id-eq $script:characterId
      $header=New-Object Windows.Controls.StackPanel;$header.Orientation=[Windows.Controls.Orientation]::Horizontal
      $thumbnail=New-Object Windows.Controls.Image;$thumbnail.Width=38;$thumbnail.Height=38;$thumbnail.Margin=[Windows.Thickness]::new(0,0,10,0)
      try{$thumbnail.Source=Read-WidgetCharacterBitmap $role.path}catch{}
      $label=New-SettingsText $role.name 13.5 '#443552';$label.VerticalAlignment=[Windows.VerticalAlignment]::Center
      $header.Children.Add($thumbnail)|Out-Null;$header.Children.Add($label)|Out-Null;$item.Header=$header
    }
    Add-SettingsDivider
    Add-SettingsAction '从 DSH 导入大肥鱼娘原图…' {Open-WidgetDeepSeekImport} -Description '选择本机 DSH 的 DSniang1.png，使用独立的大肥鱼语录'
    Add-SettingsAction '导入自己的人物图片…' {Open-WidgetCharacterImport} -Description 'PNG / JPG / BMP；透明 PNG 效果最好'
  }finally{$script:settingsMenuTarget=$previous}
}