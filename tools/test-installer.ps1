param([Parameter(Mandatory=$true)][string]$TestRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$package=Split-Path $PSScriptRoot
$installer=Join-Path $package 'Install.ps1'
if(Test-Path -LiteralPath $TestRoot){throw 'Use a fresh Tactical fixture directory'}
New-Item -ItemType Directory -Path $TestRoot | Out-Null
$results=New-Object 'System.Collections.Generic.List[string]'
function Check($value,[string]$message){if(!$value){throw $message}}
function Write-File([string]$path,[string]$value){[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))|Out-Null;[IO.File]::WriteAllText($path,$value)}
function New-Game([string]$name){
    $g=Join-Path $TestRoot $name
    Write-File (Join-Path $g 'Titanfall.exe') 'fixture only; never executable'
    Write-File (Join-Path $g 'r1/GameInfo.txt') 'fixture'
    Write-File (Join-Path $g 'r1/cfg/config.cfg') 'personal binds'
    Write-File (Join-Path $g 'r1/profile/pilot.dat') 'personal profile'
    Write-File (Join-Path $g 'r1/addonlist.txt') 'OtherVisuals enabled'
    Write-File (Join-Path $g 'r1/addons/OtherVisuals/addoninfo.txt') 'visual metadata'
    return $g
}
function Snapshot([string]$g){$s=@{};foreach($p in Get-ChildItem -LiteralPath $g -Recurse -File){$s[$p.FullName]=(Get-FileHash -LiteralPath $p.FullName -Algorithm SHA256).Hash};return $s}
function Preserved($s){foreach($p in $s.Keys){Check ((Test-Path -LiteralPath $p)-and(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -eq $s[$p]) "Changed fixture file: $p"}}
function Refuses($g,[string]$name){$s=Snapshot $g;$refused=$false;try{& $installer -GamePath $g|Out-Null}catch{$refused=$true};Check $refused "Did not refuse $name";Preserved $s;Check (!(Test-Path -LiteralPath (Join-Path $g 'r1/addons/R1Delta.Tactical'))) 'Partial destination';$results.Add($name)}
$g=New-Game 'clean';$before=Snapshot $g
& $installer -GamePath $g|Out-Null;Preserved $before
$manifest=Get-Content -LiteralPath (Join-Path $package 'MANIFEST.json') -Raw|ConvertFrom-Json
foreach($file in $manifest.files.PSObject.Properties){Check ((Get-FileHash -LiteralPath (Join-Path $g ('r1/addons/R1Delta.Tactical/'+$file.Name)) -Algorithm SHA256).Hash -eq $file.Value) 'Installed hash mismatch'}
$results.Add('clean install preserves settings/profile/addonlist/other addons; all installed payload hashes match')
$before=Snapshot $g;$refused=$false;try{& $installer -GamePath $g|Out-Null}catch{$refused=$true};Check $refused 'Existing destination accepted';Preserved $before;$results.Add('existing destination refused')
$g=New-Game 'whatif';$before=Snapshot $g;& $installer -GamePath $g -WhatIf|Out-Null;Preserved $before;Check (!(Test-Path -LiteralPath (Join-Path $g 'r1/addons/R1Delta.Tactical'))) 'WhatIf wrote';$results.Add('WhatIf writes nothing')
foreach($controller in @('R1Delta.Cooldown','R1Delta.Powder','R1Delta.Sliding','R1Delta.PilotMovement')){
    $g=New-Game $controller;Write-File (Join-Path $g ('r1/addons/'+$controller+'/addoninfo.txt')) 'preserve controller';Refuses $g ($controller+' refused and preserved')
}
foreach($conflict in @('scripts/vscripts/_items.nut','scripts/vscripts/_pdef.nut','scripts/game_sounds_manifest.txt','scripts/vscripts/_menu_callbacks.nut','scripts/weapons/mp_ability_sonar.txt')){
    $name=([IO.Path]::GetFileName($conflict));$g=New-Game $name
    Write-File (Join-Path $g ('r1/addons/OtherConflict/'+$conflict)) 'preserve overlap';Refuses $g ($conflict+' overlap refused')
}
$g=New-Game 'wrong-game';Move-Item -LiteralPath (Join-Path $g 'Titanfall.exe') -Destination (Join-Path $g 'Titanfall2.exe');Refuses $g 'wrong game refused'
$bad=Join-Path $TestRoot 'tampered-package';New-Item -ItemType Directory -Path $bad|Out-Null
Copy-Item -LiteralPath (Join-Path $package 'R1Delta.Tactical') -Destination $bad -Recurse
Copy-Item -LiteralPath $installer,(Join-Path $package 'MANIFEST.json') -Destination $bad
Add-Content -LiteralPath (Join-Path $bad 'R1Delta.Tactical/cfg/tactical_commands.cfg') -Value 'tamper'
$g=New-Game 'tampered';$before=Snapshot $g;$refused=$false
try{& (Join-Path $bad 'Install.ps1') -GamePath $g|Out-Null}catch{$refused=$true};Check $refused 'Tampered payload accepted';Preserved $before;Check (!(Test-Path -LiteralPath (Join-Path $g 'r1/addons/R1Delta.Tactical'))) 'Tamper left files';$results.Add('tampered payload refused before writes')
@{passed=$true;powershell=$PSVersionTable.PSVersion.ToString();tests=@($results)}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $TestRoot 'results.json') -Encoding UTF8
Write-Output ('Passed '+$results.Count+' installer cases')
