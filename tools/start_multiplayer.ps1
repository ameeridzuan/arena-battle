param(
    [string]$GodotPath = (Join-Path $PSScriptRoot '..\..\..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'),
    [ValidateRange(1024, 65535)][int]$Port = 24560,
    [ValidateSet(2, 8)][int]$Players = 8
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$binary = (Resolve-Path -LiteralPath $GodotPath).Path
$server = $null
$clients = @()
$scene = 'res://scenes/multiplayer/MultiplayerArena.tscn'
try {
    # The helper server is hidden; playable clients are intentionally visible.
    $server = Start-Process -FilePath $binary -ArgumentList @('--headless', '--path', ('"' + $projectRoot + '"'), $scene, '--', '--server', "--port=$Port", "--players=$Players") -WindowStyle Hidden -PassThru
    Start-Sleep -Milliseconds 750
    foreach ($index in 0..($Players - 1)) {
        $position = '{0},{1}' -f (($index % 4) * 240), ([math]::Floor($index / 4) * 250)
        $clients += Start-Process -FilePath $binary -ArgumentList @('--path', ('"' + $projectRoot + '"'), '--windowed', '--resolution', '1280x720', '--position', $position, $scene, '--', "--port=$Port", "--players=$Players") -PassThru
    }
    Write-Host "$Players local clients started. Close all windows to stop this test session."
    foreach ($client in $clients) { $client.WaitForExit() }
} finally {
    # Only stop children owned by this launcher, never another editor/game process.
    foreach ($client in $clients) { if (-not $client.HasExited) { $client.Kill() } }
    if ($null -ne $server -and -not $server.HasExited) { $server.Kill() }
}
