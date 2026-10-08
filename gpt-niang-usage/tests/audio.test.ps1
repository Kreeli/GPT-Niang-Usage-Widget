$ErrorActionPreference='Stop'
$app=Split-Path $PSScriptRoot -Parent
. (Join-Path $app 'runtime\audio.ps1')
$script:soundOn=$true;$script:soundVolume=0.01
Initialize-WidgetAudio $app
if(!$script:gptNiangAudio){throw 'PCM engine did not initialize'}
$engine=$script:gptNiangAudio.Engine
$deadline=[DateTime]::UtcNow.AddSeconds(3)
while(!$engine.Ready -and [DateTime]::UtcNow-lt $deadline){Start-Sleep -Milliseconds 5}
if(!$engine.Ready){throw ('Mixer not ready: '+$engine.LastError)}
function Pump-For([int]$Milliseconds){
  $clock=[Diagnostics.Stopwatch]::StartNew()
  while($clock.ElapsedMilliseconds-lt $Milliseconds){$engine.Pump();Start-Sleep -Milliseconds 5}
}
try{
  if($engine.ActiveVoices-ne 0 -or $engine.PressStarted-ne 0){throw 'Initialization must remain silent'}
  Play-WidgetPressSound;Play-WidgetReleaseSound
  if($engine.PressStarted-ne 1 -or $engine.ReleaseStarted-ne 0){throw 'Quick release must wait for the complete press segment'}
  Pump-For 600
  if($engine.PressCompleted-ne 1 -or $engine.ReleaseCompleted-ne 1 -or $engine.ActiveVoices-ne 0){throw ('Initial pair incomplete: '+$engine.LastError)}
  for($i=0;$i-lt 50;$i++){Play-WidgetPressSound;Play-WidgetReleaseSound;Pump-For 20}
  Pump-For 700
  if($engine.PressStarted-ne 51 -or $engine.PressCompleted-ne 51 -or $engine.ReleaseStarted-ne 51 -or $engine.ReleaseCompleted-ne 51 -or $engine.Cancelled-ne 0 -or $engine.Failed-ne 0 -or $engine.Rejected-ne 0 -or $engine.ActiveVoices-ne 0){throw ('Rapid clicks lost a segment: '+($engine|ConvertTo-Json))}
  Play-WidgetPressSound;Pump-For 300
  if($engine.ReleaseStarted-ne 51){throw 'Holding must not play the release segment'}
  Play-WidgetReleaseSound;Pump-For 400
  if($engine.ReleaseCompleted-ne 52){throw 'Held click did not finish'}
  Play-WidgetPressSound;Stop-WidgetAudio;Pump-For 400
  if($engine.ActiveVoices-ne 0 -or $engine.ReleaseStarted-ne 52){throw 'Stopping must cancel pending audio without a late release'}
  $before=$engine.PressStarted;$script:soundOn=$false;Play-WidgetPressSound;Play-WidgetReleaseSound
  if($engine.PressStarted-ne $before){throw 'Disabled audio should remain silent'}
  $script:soundOn=$true;Set-WidgetAudioVolume 0;Play-WidgetPressSound
  if($engine.PressStarted-ne $before){throw 'Zero volume should remain silent'}
  Set-WidgetAudioVolume 0.01;Play-WidgetPressSound;Play-WidgetReleaseSound;Pump-For 600
  if($engine.ReleaseCompleted-ne 53){throw ('Playback did not recover after mute/stop: '+($engine|ConvertTo-Json))}
  Write-Output 'PASS: actual Windows output completed 51 click pairs including 50 rapid overlapping clicks; held click, stop, mute and recovery passed; no lost or cancelled rapid segments'
}finally{Stop-WidgetAudio;$engine.Dispose();if(!$engine.WaitForExit(2000)){throw 'Mixer thread failed to exit'}}