# Canonical FixPose release builder (round-9+).
#
# Why this script exists: v1.1.0 and the b19 round-8 build were both built
# WITHOUT --dart-define-from-file, so GROQ_API_KEY was empty on the phone and
# Veda chat / plan generation / progress reports all failed. Never build a
# release APK by hand again — run this instead:
#
#   powershell -File tools/build_release.ps1
#
# Output: build/app/outputs/flutter-apk/app-release.apk
# Also prints size + SHA-256 and verifies (boolean only) that the API key
# actually made it into the AOT snapshot.

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$defines = "secrets/dart_defines.json"
if (-not (Test-Path $defines)) {
    throw "Missing $defines - release builds without it ship a dead AI stack."
}
$json = Get-Content $defines -Raw | ConvertFrom-Json
if (-not $json.GROQ_API_KEY -or $json.GROQ_API_KEY -notlike "gsk_*") {
    throw "$defines does not contain a valid GROQ_API_KEY (gsk_...)."
}

Write-Host "Building release APK with --dart-define-from-file=$defines ..."
# --target-platform: fat APK limited to phone ABIs (drops x86/x86_64 emulator
# natives — a gradle ndk.abiFilters alone is overridden by the Flutter plugin).
flutter build apk --release --target-platform android-arm,android-arm64 "--dart-define-from-file=$defines"
if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)" }

$apk = "build/app/outputs/flutter-apk/app-release.apk"
$size = (Get-Item $apk).Length
$hash = (Get-FileHash $apk -Algorithm SHA256).Hash

# Verify the key string made it into the AOT snapshot (prints a boolean only).
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $apk))
$baked = $false
try {
    $entry = $zip.Entries | Where-Object { $_.FullName -like "lib/arm64-v8a/libapp.so" }
    if ($entry) {
        $ms = New-Object System.IO.MemoryStream
        $s = $entry.Open()
        $s.CopyTo($ms)
        $s.Close()
        $text = [System.Text.Encoding]::ASCII.GetString($ms.ToArray())
        $baked = $text.Contains("gsk_")
        $ms.Dispose()
    }
} finally {
    $zip.Dispose()
}

Write-Host ""
Write-Host "APK:    $apk"
Write-Host ("Size:   {0:N0} bytes" -f $size)
Write-Host "SHA256: $hash"
Write-Host "GROQ key baked in: $baked"
if (-not $baked) {
    throw "GROQ_API_KEY was NOT found in libapp.so - do not ship this APK."
}
