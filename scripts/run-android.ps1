param([string]$Serial)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $projectRoot '.local/android-sdk/platform-tools/adb.exe'
$apk = Join-Path $projectRoot 'godot/build/janggi-debug.apk'
if (!(Test-Path -LiteralPath $apk)) { throw 'Build the APK with scripts/build-android.ps1 first.' }
if (!(Test-Path -LiteralPath $adb)) { throw 'Android platform-tools missing.' }
$deviceList = & $adb devices
if ($LASTEXITCODE -ne 0) { throw 'Cannot query Android devices.' }
$devices = @($deviceList | Where-Object { $_ -match '^\S+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
if (!$Serial) {
    if ($devices.Count -ne 1) { throw 'Connect exactly one authorized Android device, or specify -Serial. Enable USB debugging and allow the PC on the phone.' }
    $Serial = $devices[0]
}
if ($Serial -notin $devices) { throw 'The selected device is not connected or not authorized.' }
$state = Invoke-RestMethod 'http://127.0.0.1:3000/api/game' -TimeoutSec 5
if ($state.variant -ne 'janggi') { throw 'Start the Janggi server with node server/index.js first.' }
& $adb -s $Serial install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'APK installation failed. Existing apps were not removed.' }
& $adb -s $Serial reverse tcp:3000 tcp:3000
if ($LASTEXITCODE -ne 0) { throw 'USB server forwarding failed.' }
& $adb -s $Serial shell am start -W -n com.janggiai.prototype/com.godot.game.GodotAppLauncher
if ($LASTEXITCODE -ne 0) { throw 'App launch failed.' }
Write-Output 'App launched. Keep USB connected and the PC server running. New games replace the shared board.'
