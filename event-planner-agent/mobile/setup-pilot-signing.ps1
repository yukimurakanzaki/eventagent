param(
  [string]$KeystorePath = (Join-Path $env:LOCALAPPDATA 'Wargakas\pilot-upload.jks'),
  # Required when key.properties survives but its keystore is gone. A new key
  # cannot upgrade APKs signed with the lost one; those need a reinstall.
  [switch]$ReplaceMissingKeystore
)

$ErrorActionPreference = 'Stop'
$propertiesPath = Join-Path $PSScriptRoot 'android\key.properties'
if ((Test-Path -LiteralPath $KeystorePath) -and (Test-Path -LiteralPath $propertiesPath)) {
  Write-Output 'Pilot signing is already configured.'
  exit 0
}
if (Test-Path -LiteralPath $KeystorePath) {
  throw 'The keystore exists but key.properties is missing. Restore its original credentials instead of replacing the key.'
}
if (Test-Path -LiteralPath $propertiesPath) {
  if (-not $ReplaceMissingKeystore) {
    throw "key.properties points to a keystore that is missing ($KeystorePath). Restore that keystore, or rerun with -ReplaceMissingKeystore to create a new key. Installed APKs signed with the old key must then be reinstalled."
  }
  $backupPath = "$propertiesPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
  Copy-Item -LiteralPath $propertiesPath -Destination $backupPath
  Write-Output "Previous key.properties backed up to $backupPath."
}

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if ($null -eq $keytool) {
  $androidStudioKeytool = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
  if (-not (Test-Path -LiteralPath $androidStudioKeytool)) {
    throw 'keytool was not found. Install Android Studio or add a JDK bin directory to PATH.'
  }
  $keytoolPath = $androidStudioKeytool
} else {
  $keytoolPath = $keytool.Source
}
$directory = Split-Path -Parent $KeystorePath
New-Item -ItemType Directory -Force -Path $directory | Out-Null
$password = ([Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N'))
$alias = 'wargakas-pilot'
& $keytoolPath -genkeypair -v `
  -keystore $KeystorePath `
  -storetype PKCS12 `
  -storepass $password `
  -keypass $password `
  -alias $alias `
  -keyalg RSA `
  -keysize 2048 `
  -validity 3650 `
  -dname 'CN=Wargakas Pilot, OU=Pilot, O=Wargakas, L=Jakarta, ST=DKI Jakarta, C=ID'
if ($LASTEXITCODE -ne 0) { throw "keytool failed with exit code $LASTEXITCODE." }

$escapedPath = $KeystorePath.Replace('\', '/')
$lines = @(
  "storeFile=$escapedPath"
  "storePassword=$password"
  "keyAlias=$alias"
  "keyPassword=$password"
)
# Windows PowerShell 5.1 has no utf8NoBOM encoding; write BOM-free UTF-8 directly.
[System.IO.File]::WriteAllLines(
  [System.IO.Path]::GetFullPath($propertiesPath),
  [string[]]$lines,
  (New-Object System.Text.UTF8Encoding($false))
)

Write-Output "Pilot keystore created at $KeystorePath."
Write-Output 'The ignored android/key.properties file contains the credentials; back up both files securely.'
