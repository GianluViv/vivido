# Builds the app in release mode and collects everything needed to run it
# (exe, DLLs, data folder) into a "release" folder at the project root.

$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$buildOutput = Join-Path $root "build\windows\x64\runner\Release"
$releaseDir = Join-Path $root "release"

Write-Host "Building Windows release..." -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    throw "flutter build windows failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path $buildOutput)) {
    throw "Build output not found at: $buildOutput"
}

if (Test-Path $releaseDir) {
    Write-Host "Cleaning existing release folder..." -ForegroundColor Cyan
    Remove-Item -Path $releaseDir -Recurse -Force
}
New-Item -ItemType Directory -Path $releaseDir | Out-Null

Write-Host "Copying build output to $releaseDir ..." -ForegroundColor Cyan
Copy-Item -Path (Join-Path $buildOutput "*") -Destination $releaseDir -Recurse -Force

Write-Host "Done. Release folder ready at: $releaseDir" -ForegroundColor Green

# Pacchettizza in un unico exe portabile (richiede Enigma Virtual Box installato).
# Eseguito come processo figlio separato: se il tool manca, lo script termina con
# "exit 1" al suo interno, e questo non deve interrompere anche release.ps1.
$portableExe = Join-Path $root "release_portable\flutter_viz.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\pack_portable_exe.ps1") -ReleaseDir $releaseDir -OutputExe $portableExe
if ($LASTEXITCODE -eq 0) {
    Write-Host "Exe portabile pronto: $portableExe" -ForegroundColor Green
}
else {
    Write-Host "Packaging exe portabile saltato (vedi avviso sopra). La cartella $releaseDir resta comunque utilizzabile." -ForegroundColor Yellow
}
