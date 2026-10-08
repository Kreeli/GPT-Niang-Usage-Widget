# The PCM mixer owns its background thread and persistent device. UI handlers never open or service devices.
if($null-eq (Get-Variable gptNiangAudio -Scope Script -ErrorAction SilentlyContinue)){$script:gptNiangAudio=$null}
function Get-WidgetAudioEnabled {
 $setting=Get-Variable soundOn -Scope Script -ErrorAction SilentlyContinue
 return ($null-eq $setting -or $setting.Value-ne $false)
}
function Get-WidgetAudioVolume {
 $setting=Get-Variable soundVolume -Scope Script -ErrorAction SilentlyContinue;$value=0.9
 if($null-ne $setting){try{$value=[double]$setting.Value}catch{}}
 if([double]::IsNaN($value) -or [double]::IsInfinity($value)){$value=0.9}
 return [Math]::Min(1.0,[Math]::Max(0.0,$value))
}
function Set-WidgetAudioVolume {
 param([double]$Volume=-1)
 if($Volume-ge 0 -and ![double]::IsNaN($Volume) -and ![double]::IsInfinity($Volume)){$script:soundVolume=[Math]::Min(1.0,[Math]::Max(0.0,$Volume))}
 if($script:gptNiangAudio){$script:gptNiangAudio.Engine.Volume=Get-WidgetAudioVolume;if($script:gptNiangAudio.Engine.Volume-le 0){Stop-WidgetAudio}}
}
function Stop-WidgetAudio {if($script:gptNiangAudio){$script:gptNiangAudio.Engine.Stop()}}
function Initialize-WidgetAudio {
 param([Parameter(Mandatory=$true)][string]$AppDir)
 if($script:gptNiangAudio){$script:gptNiangAudio.Engine.Dispose()}
 $script:gptNiangAudio=$null
 try{
  if(!('NiangClickAudio' -as [type])){Add-Type -Path (Join-Path $AppDir 'runtime\audio-native.cs')}
  $engine=[NiangClickAudio]::new((Join-Path $AppDir 'assets\press.wav'),(Join-Path $AppDir 'assets\release.wav'))
  $script:gptNiangAudio=@{Engine=$engine};Set-WidgetAudioVolume
 }catch{$script:gptNiangAudio=$null}
}
function Play-WidgetPressSound {
 if(!$script:gptNiangAudio -or !(Get-WidgetAudioEnabled) -or (Get-WidgetAudioVolume)-le 0){return}
 $script:gptNiangAudio.Engine.Press()
}
function Play-WidgetReleaseSound {
 if(!$script:gptNiangAudio){return}
 if(!(Get-WidgetAudioEnabled) -or (Get-WidgetAudioVolume)-le 0){Stop-WidgetAudio;return}
 $script:gptNiangAudio.Engine.Release()
}