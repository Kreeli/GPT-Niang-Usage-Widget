$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$app=Split-Path $PSScriptRoot -Parent
$source=[IO.File]::ReadAllText((Join-Path $app 'widget.ps1'),[Text.Encoding]::UTF8)
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
$easeSource=[regex]::Match($source,'(?s)using System;\s*using System.Windows;\s*using System.Windows.Media.Animation;.*?(?=\r?\n''@)').Value
if(!$easeSource){throw 'Missing production easing type'}
Add-Type -TypeDefinition $easeSource -ReferencedAssemblies ([Windows.Media.Animation.EasingFunctionBase].Assembly.Location),([Windows.Freezable].Assembly.Location)
foreach($name in @('New-WidgetPressAnimation','Animate-Press')){
 $definition=$ast.Find({param($node)$node-is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name-eq $name},$true)
 . ([ScriptBlock]::Create($definition.Extent.Text))
}
$script:window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $app 'widget.xaml'),[Text.Encoding]::UTF8))
$script:ui=@{PressScale=$script:window.FindName('PressScale')}
$script:window.Opacity=0;$script:window.Show()
$script:checks=0
function Assert($condition,[string]$label){if(!$condition){throw ('FAIL '+$label)};$script:checks++;Write-Output ('PASS '+$label)}
function Pump([int]$milliseconds){
 $frame=New-Object Windows.Threading.DispatcherFrame

 $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds($milliseconds)
 $callback={param($sender,$event)$sender.Stop();$frame.Continue=$false}.GetNewClosure();$timer.Add_Tick($callback)
 $timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
}
function Observe([int]$milliseconds){
 $clock=[Diagnostics.Stopwatch]::StartNew();$minY=1.0;$maxX=1.0;$maxY=1.0
 while($clock.ElapsedMilliseconds-lt $milliseconds){Pump 12;$minY=[Math]::Min($minY,$script:ui.PressScale.ScaleY);$maxX=[Math]::Max($maxX,$script:ui.PressScale.ScaleX);$maxY=[Math]::Max($maxY,$script:ui.PressScale.ScaleY)}
 return @{minY=$minY;maxX=$maxX;maxY=$maxY;finalY=$script:ui.PressScale.ScaleY;finalX=$script:ui.PressScale.ScaleX}
}
try{
 $release=New-WidgetPressAnimation 1.0 0.88 $false 0
 Assert ($release.KeyFrames.Count-eq 3 -and $release.KeyFrames[1].Value-eq 0.88 -and $release.KeyFrames[1].KeyTime.TimeSpan.TotalMilliseconds-ge 45) 'a zero-duration tap includes an explicit squash before rebound'
 Animate-Press $true;Animate-Press $false
 $tap=Observe 500
 Assert ($tap.minY-lt 0.92 -and $tap.maxX-gt 1.03) ('an immediate tap visibly squashes the real WPF transform: '+($tap|ConvertTo-Json -Compress))
 Assert ($tap.maxY-gt 1.005) 'the tap produces a visible elastic rebound'
 Assert ([Math]::Abs($tap.finalY-1)-lt 0.001 -and [Math]::Abs($tap.finalX-1)-lt 0.001) 'the tap finishes at the exact original scale'
 Animate-Press $true;Pump 250
 Assert ([Math]::Abs($script:ui.PressScale.ScaleY-0.88)-lt 0.002) 'holding the mouse keeps the pressed pose'
 Animate-Press $false;$held=Observe 420
 Assert ($held.finalY-eq 1 -and $held.finalX-eq 1) 'releasing a held press restores the pose'
 for($i=0;$i-lt 10;$i++){Animate-Press $true;Animate-Press $false;Pump 20}
 $rapid=Observe 500
 Assert ($rapid.minY-lt 0.92 -and $rapid.finalY-eq 1 -and $rapid.finalX-eq 1) 'rapid taps still complete the last squash and never stick'
 Animate-Press $true;Start-Sleep -Milliseconds 180;Animate-Press $false
 $blocked=Observe 500
 Assert ($blocked.minY-lt 0.94 -and $blocked.finalY-eq 1) 'a delayed first render cannot erase the single-click animation'
 Write-Output ('Press animation checks passed: '+$script:checks)
}finally{$script:window.Close()}