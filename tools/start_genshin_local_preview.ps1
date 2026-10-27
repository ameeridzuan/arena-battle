param([string]$GodotPath, [switch]$Showcase)
$ErrorActionPreference = 'Stop'
$previewProject = Split-Path -Parent $PSScriptRoot
$previewWorkspace = Split-Path -Parent $previewProject
if (-not $GodotPath) {
    $GodotPath = Join-Path (Split-Path -Parent $previewWorkspace) 'Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw "Godot executable not found. Pass -GodotPath with its full path." }
$previewAsset = Join-Path $previewWorkspace 'assets\characters\protagonist\genshin-concept-match\protagonist-local-styled.glb'
if (-not (Test-Path -LiteralPath $previewAsset)) { throw "Local character GLB is missing: $previewAsset" }
$previewUserData = Join-Path $previewWorkspace 'assets\characters\protagonist\genshin-concept-match\game-userdata'
New-Item -ItemType Directory -Force -Path $previewUserData | Out-Null
$env:APPDATA = $previewUserData
$env:LOCALAPPDATA = $previewUserData
$previewArgs = @('--path', ('"' + $previewProject + '"'), '--rendering-method', 'gl_compatibility', '--resolution', '1280x720', 'res://scenes/characters/GenshinLocalArena.tscn')
if ($Showcase) { $previewArgs += @('--', '--genshin-showcase') }
Start-Process -FilePath $GodotPath -ArgumentList $previewArgs -WorkingDirectory $previewProject -WindowStyle Normal
