$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$script:appDir=Split-Path $PSScriptRoot -Parent
$script:dataDir=Join-Path ([IO.Path]::GetTempPath()) ('niang-responsive-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $script:dataDir
$settingsFile=Join-Path $script:dataDir 'settings.json'
$source=[IO.File]::ReadAllText((Join-Path $script:appDir 'widget.ps1'),[Text.Encoding]::UTF8)
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
foreach($node in $ast.FindAll({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst]},$false)){. ([ScriptBlock]::Create($node.Extent.Text))}
$native=[regex]::Match($source,'(?s)using System;\s*using System.Text;.*?(?=\r?\n''@)').Value
$ease=[regex]::Match($source,'(?s)using System;\s*using System.Windows;\s*using System.Windows.Media.Animation;.*?(?=\r?\n''@)').Value
Add-Type -TypeDefinition $native
Add-Type -TypeDefinition $ease -ReferencedAssemblies ([Windows.Media.Animation.EasingFunctionBase].Assembly.Location),([Windows.Freezable].Assembly.Location)
foreach($name in @('quotes','quote-layout','color-theme','audio')){. (Join-Path $script:appDir ('runtime\'+$name+'.ps1'))}
$script:window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $script:appDir 'widget.xaml'),[Text.Encoding]::UTF8))
$script:window.ShowActivated=$false;$script:window.Opacity=0;$script:window.Show()
$script:widgetHandle=[Windows.Interop.WindowInteropHelper]::new($script:window).Handle
$script:ui=@{};foreach($name in @('Root','Bubble','Tail','TailNear','SceneText','QuotaText','QuoteText','BubbleShape','Girl','PressScale','FacingScale','TextFacingScale','Header','Refresh','MenuButton','Status','LiveDot','ShortRow','WeekRow','ShortLabel','WeekLabel','ShortUsed','ShortLeft','ShortReset','ShortBar','WeekUsed','WeekLeft','WeekReset','WeekBar')){$script:ui[$name]=$script:window.FindName($name)}
$script:collapsed=$true;$script:bubbleMode='quota';$script:bubbleTapAdvance=$true;$script:resetTimeMode='countdown';$script:sceneRevision=0;$script:scale=1.0;$script:side='right';$script:anchor='right';$script:characterId='deepseek-niang'
$script:soundOn=$true;$script:soundVolume=0.01;$script:statusStamp=0
$script:hostFollower=[pscustomobject]@{};$script:hostFollower|Add-Member ScriptMethod Suspend {}
$script:hostEventTimer=New-Object Windows.Threading.DispatcherTimer;$script:hostEventTimer.Interval=[TimeSpan]::FromMilliseconds(33);$script:hostEventTimer.Add_Tick({$script:hostEventTimer.Stop()})
$script:sender=[pscustomobject]@{};$script:sender|Add-Member ScriptMethod CaptureMouse {$true};$script:sender|Add-Member ScriptMethod ReleaseMouseCapture {}
$script:event=[pscustomobject]@{Handled=$false;Timestamp=[Environment]::TickCount}
foreach($name in @('pressDown','pressUp')){
 $assignment=$ast.Find({param($n)$n-is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text-eq ('$'+$name)},$true)
 . ([ScriptBlock]::Create($assignment.Extent.Text))
}
$now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
Write-WidgetJson (Join-Path $script:dataDir 'status.json') @{ok=$true;queryOk=$true;observedAt=$now;windows=@(@{minutes=300;used=25;remaining=75;resetsAt=[Math]::Floor($now/1000)+3600},@{minutes=10080;used=10;remaining=90;resetsAt=[Math]::Floor($now/1000)+345600})}
Initialize-WidgetQuoteLayouts $script:appDir;Warm-WidgetQuoteLayouts $script:dataDir;Initialize-WidgetAudio $script:appDir
$engine=$script:gptNiangAudio.Engine;$deadline=[DateTime]::UtcNow.AddSeconds(3)
while(!$engine.Ready -and [DateTime]::UtcNow-lt $deadline){Start-Sleep -Milliseconds 5}
if(!$engine.Ready){throw $engine.LastError}
Initialize-WidgetInteraction $pressDown $pressUp
$script:writeCount=0
$writeFunction=${function:Write-WidgetJson}
function Write-WidgetJson($file,$value){if($file-eq $settingsFile){$script:writeCount++}; & $writeFunction $file $value}
$script:clickTimes=New-Object 'System.Collections.Generic.List[double]'
$script:heartbeatGaps=New-Object 'System.Collections.Generic.List[double]'
$script:count=0;$script:frame=New-Object Windows.Threading.DispatcherFrame
$script:heartbeatClock=[Diagnostics.Stopwatch]::StartNew()
$heartbeat=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Render)
$heartbeat.Interval=[TimeSpan]::FromMilliseconds(16)
$heartbeat.Add_Tick({$script:heartbeatGaps.Add($script:heartbeatClock.Elapsed.TotalMilliseconds);$script:heartbeatClock.Restart()})
$clickTimer=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Input)
$clickTimer.Interval=[TimeSpan]::FromMilliseconds(20)
$clickTimer.Add_Tick({
 try{
  $watch=[Diagnostics.Stopwatch]::StartNew()
  $script:event.Timestamp=[Environment]::TickCount
  & $pressDown $script:sender $script:event
  & $pressUp $script:sender $script:event
  $script:clickTimes.Add($watch.Elapsed.TotalMilliseconds);$script:count++
  if($script:count-eq 200){$clickTimer.Stop();$script:frame.Continue=$false}
 }catch{$script:testError=$_;$clickTimer.Stop();$script:frame.Continue=$false}
})
try{
 $heartbeat.Start();$clickTimer.Start();[Windows.Threading.Dispatcher]::PushFrame($script:frame);$heartbeat.Stop()
 if($script:testError){throw $script:testError}
 $pendingWrites=$script:writeCount
 $drain=New-Object Windows.Threading.DispatcherFrame;$drainTimer=New-Object Windows.Threading.DispatcherTimer
 $drainTimer.Interval=[TimeSpan]::FromMilliseconds(750);$drainTimer.Add_Tick({$drainTimer.Stop();$drain.Continue=$false});$drainTimer.Start();[Windows.Threading.Dispatcher]::PushFrame($drain)
 $times=@($script:clickTimes|Sort-Object);$gaps=@($script:heartbeatGaps|Sort-Object)
 $result=[pscustomobject]@{Clicks=$script:count;ClickMedianMs=$times[100];ClickP95Ms=$times[189];ClickMaxMs=$times[-1];MaxUiRefreshGapMs=$gaps[-1];SettingsWritesDuringClicks=$pendingWrites;SettingsWritesAfterIdle=$script:writeCount;AudioDeviceOpens=$engine.DeviceOpenCount;AudioPressCompleted=$engine.PressCompleted;AudioReleaseCompleted=$engine.ReleaseCompleted;AudioFailed=$engine.Failed;AudioRejected=$engine.Rejected;AudioStaleDropped=$engine.DroppedStale;RemainingVoices=$engine.ActiveVoices;FinalScaleX=$script:ui.PressScale.ScaleX;FinalScaleY=$script:ui.PressScale.ScaleY}
 $result|ConvertTo-Json
 @($script:clickTimes|ForEach-Object -Begin {$i=0} -Process {[pscustomobject]@{Index=++$i;DurationMs=$_}}|Sort-Object DurationMs -Descending|Select-Object -First 8)|ConvertTo-Json
 if($result.ClickP95Ms-gt 25 -or $result.ClickMaxMs-gt 100 -or $result.MaxUiRefreshGapMs-gt 150){throw 'Combined UI click handlers exceeded the response budget'}
 if($result.AudioDeviceOpens-ne 1 -or $result.AudioReleaseCompleted-ne 200 -or $result.AudioFailed-ne 0 -or $result.AudioRejected-ne 0 -or $result.AudioStaleDropped-ne 0 -or $result.RemainingVoices-ne 0){throw 'Audio accumulated, failed, or lost a rapid click'}
 if($pendingWrites-ne 0 -or $script:writeCount-ne 1){throw 'Settings were not coalesced after the click burst'}
 if($result.FinalScaleX-ne 1 -or $result.FinalScaleY-ne 1){throw 'Animation stuck after rapid clicks'}
 $oldEvent=[pscustomobject]@{Handled=$false;Timestamp=([Environment]::TickCount-500)}
 $revision=$script:sceneRevision
 & $pressDown $script:sender $oldEvent;& $pressUp $script:sender $oldEvent
 if($engine.PressStarted-ne 200 -or $script:sceneRevision-ne $revision -or $script:staleInputIgnored-ne 1){throw 'Old queued input was replayed after a UI stall'}
 Write-Output 'PASS: stale mouse input does not produce a delayed animation or audio burst'
 Write-Output 'PASS: 200 production press/release handlers, real WPF animations and bubble changes, and real background sound; no device churn, no delayed audio backlog, one settings save after idle'
}finally{
 $clickTimer.Stop();$heartbeat.Stop();$engine.Dispose();$null=$engine.WaitForExit(2000)
 foreach($timer in @($script:settingsSaveTimer,$script:refreshSaveTimer,$script:sceneTimer,$script:closeTimer,$script:resetPhaseTimer,$script:hostEventTimer)){if($timer){$timer.Stop()}}
 $script:window.Close()
 $resolved=[IO.Path]::GetFullPath($script:dataDir);$prefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
 if($resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf)-like 'niang-responsive-*'){Remove-Item -LiteralPath $resolved -Recurse -Force}
}