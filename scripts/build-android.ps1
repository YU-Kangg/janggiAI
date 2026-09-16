param(
    [string]$JavaSdkPath = $env:JAVA_HOME
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $projectRoot '.local/godot/Godot_v4.7.2-stable_win64_console.exe'
$sdk = Join-Path $projectRoot '.local/android-sdk'
$templates = Join-Path $projectRoot '.local/android-templates'
if (!$JavaSdkPath) {
    $JavaSdkPath = Split-Path -Parent (Split-Path -Parent (Get-Command java.exe -ErrorAction Stop).Source)
}
foreach ($required in @($godot, "$sdk/platform-tools/adb.exe", "$templates/android_debug.apk", "$JavaSdkPath/bin/keytool.exe")) {
    if (!(Test-Path -LiteralPath $required)) { throw "Missing build dependency: $required" }
}
# Keep editor settings and debug signing material inside the ignored local directory.
Set-Content -LiteralPath (Join-Path (Split-Path $godot) '_sc_') -Value ''
$env:JAVA_HOME = $JavaSdkPath.TrimEnd('\','/').Replace('\','/')
$editorData = Join-Path (Split-Path $godot) 'editor_data'
New-Item -ItemType Directory -Force -Path $editorData | Out-Null
$settingsPath = Join-Path $editorData 'editor_settings-4.7.tres'
$settingsText = if (Test-Path -LiteralPath $settingsPath) { [IO.File]::ReadAllText($settingsPath) } else { "[gd_resource type=`"EditorSettings`" format=3]`n`n[resource]`n" }
foreach ($setting in @(@('export/android/java_sdk_path', $env:JAVA_HOME), @('export/android/android_sdk_path', $sdk.Replace('\','/')))) {
    $line = $setting[0] + ' = ' + (ConvertTo-Json -InputObject $setting[1] -Compress)
    $pattern = '(?m)^' + [regex]::Escape($setting[0]) + ' = [^\r\n]*'
    if ([regex]::IsMatch($settingsText, $pattern)) { $settingsText = [regex]::Replace($settingsText, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $line }) }
    else { $settingsText += "`n$line`n" }
}
[IO.File]::WriteAllText($settingsPath, $settingsText, (New-Object Text.UTF8Encoding($false)))
$keystore = Join-Path $projectRoot '.local/android-debug.keystore'
if (!(Test-Path -LiteralPath $keystore)) {
    & "$JavaSdkPath/bin/keytool.exe" -genkeypair -keystore $keystore -storepass android -alias androiddebugkey -keypass android -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -validity 10000
    if ($LASTEXITCODE -ne 0) { throw 'Debug keystore creation failed' }
}
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = $keystore
$env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = 'androiddebugkey'
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = 'android'
$outputDirectory = Join-Path $projectRoot 'godot/build'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$apk = Join-Path $outputDirectory 'janggi-debug.apk'
& $godot --headless --path (Join-Path $projectRoot 'godot') --export-debug 'Android Debug' $apk
if ($LASTEXITCODE -ne 0) { throw 'Android export failed' }
$signer = Get-ChildItem -LiteralPath "$sdk/build-tools" -Filter apksigner.bat -Recurse | Select-Object -First 1
if (!$signer) { throw 'apksigner missing' }
& $signer.FullName verify --verbose $apk
if ($LASTEXITCODE -ne 0) { throw 'APK signature validation failed' }
Get-Item -LiteralPath $apk | Select-Object FullName, Length
