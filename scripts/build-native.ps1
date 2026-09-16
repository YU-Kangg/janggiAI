param(
    [ValidateSet('arm64', 'x86_64')][string[]]$Architectures = @('arm64', 'x86_64'),
    [int]$Jobs = 4
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
$previousNdk = $env:ANDROID_NDK_ROOT
try {
    $pins = @{
        '.local/fairy-source' = '226c7f18c854372d5612be2a7d7f14449ae5a239'
        '.local/godot-cpp' = 'b0e3b1e4b78a606f48d162898afb5eeda533d2a9'
    }
    foreach ($source in $pins.Keys) {
        if (!(Test-Path "$source/.git")) { throw "Missing $source. See native/README.md." }
        $revision = & git -C $source rev-parse HEAD
        if ($LASTEXITCODE -ne 0 -or $revision -ne $pins[$source]) { throw "Unexpected source revision: $source" }
        $changes = & git -C $source status --porcelain --untracked-files=no
        if ($LASTEXITCODE -ne 0 -or $changes) { throw "Modified source: $source" }
    }
    $env:ANDROID_NDK_ROOT = (Resolve-Path '.local/android-ndk-r28b').Path
    $properties = Get-Content "$env:ANDROID_NDK_ROOT/source.properties"
    if (!($properties -match 'Pkg.Revision\s*=\s*28\.1\.13356709')) { throw 'Expected NDK r28b.' }
    if (!(Test-Path '.local/python/python.exe')) { throw 'Missing .local/python/python.exe. See native/README.md.' }
    foreach ($architecture in $Architectures) {
        & .local/python/python.exe -m SCons -C native platform=android "arch=$architecture" target=template_release 'ANDROID_HOME=' build_profile=build-profile.json "-j$Jobs"
        if ($LASTEXITCODE -ne 0) { throw "Native build failed: $architecture" }
        $library = "godot/native/bin/libjanggi.android.$architecture.so"
        if (!(Test-Path $library)) { throw "Missing output: $library" }
        $symbols = & "$env:ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-nm.exe" -D --defined-only $library
        if ($LASTEXITCODE -ne 0 -or !($symbols -match '\bjanggi_library_init$')) { throw "Missing GDExtension entry point: $library" }
        Write-Host "Validated native library: $library"
    }
} finally {
    $env:ANDROID_NDK_ROOT = $previousNdk
    Pop-Location
}
