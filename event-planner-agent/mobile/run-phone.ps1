param(
  [string]$DeviceId = '',
  [switch]$BuildApk,
  [switch]$BuildPilotApk
)

$ErrorActionPreference = 'Stop'

$configPath = Join-Path $PSScriptRoot 'supabase.local.json'
$config = @{}
if (Test-Path -LiteralPath $configPath) {
  $parsedConfig = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
  foreach ($name in @('SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY')) {
    $property = $parsedConfig.PSObject.Properties[$name]
    if ($null -ne $property -and -not [string]::IsNullOrWhiteSpace($property.Value)) {
      $config[$name] = [string]$property.Value
    }
  }
}
foreach ($name in @('SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY')) {
  $value = [Environment]::GetEnvironmentVariable($name)
  if (-not [string]::IsNullOrWhiteSpace($value)) { $config[$name] = $value }
  if ([string]::IsNullOrWhiteSpace($config[$name])) {
    throw "Set $name in this PowerShell session or in $configPath before building."
  }
}
if ($config.SUPABASE_PUBLISHABLE_KEY.StartsWith('sb_secret_')) {
  throw 'Use a publishable app key, never a Supabase secret key.'
}
if ($BuildApk -and $BuildPilotApk) {
  throw 'Choose either -BuildApk or -BuildPilotApk.'
}
if ($BuildPilotApk -and -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'android/key.properties'))) {
  throw 'Pilot signing is not configured. Run .\setup-pilot-signing.ps1 first.'
}
$flutterArgs = @(
  if ($BuildPilotApk) {
    'build', 'apk', '--release'
  } elseif ($BuildApk) {
    'build', 'apk', '--debug'
  } else {
    'run'
  }
)
$flutterArgs += @(
  '--dart-define=WARGAKAS_APP_MODE=hosted',
  "--dart-define=SUPABASE_URL=$($config.SUPABASE_URL)",
  "--dart-define=SUPABASE_PUBLISHABLE_KEY=$($config.SUPABASE_PUBLISHABLE_KEY)"
)

if (-not $BuildApk -and -not $BuildPilotApk -and -not [string]::IsNullOrWhiteSpace($DeviceId)) {
  $flutterArgs += @('-d', $DeviceId)
}

Push-Location $PSScriptRoot
try {
  & flutter @flutterArgs
  if ($LASTEXITCODE -ne 0) { throw "Flutter failed with exit code $LASTEXITCODE." }
} finally {
  Pop-Location
}
