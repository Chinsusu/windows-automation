Param(
  [Parameter(Mandatory=$true)][string]$Version,
  [Parameter(Mandatory=$true)][string]$Bucket,
  [Parameter(Mandatory=$true)][string]$AccountId,
  [Parameter(Mandatory=$true)][string]$AccessKey,
  [Parameter(Mandatory=$true)][string]$SecretKey
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root ("dist\AutoAgent-{0}.exe" -f $Version)

if (!(Test-Path $exe)) { Write-Error "Missing $exe" }

$Endpoint = "https://$AccountId.r2.cloudflarestorage.com"
$env:AWS_ACCESS_KEY_ID = $AccessKey
$env:AWS_SECRET_ACCESS_KEY = $SecretKey

aws --endpoint-url $Endpoint s3 cp $exe "s3://$Bucket/AutoAgent-$Version.exe" --acl public-read

# Update manifest
$manifestPath = Join-Path $root "manifests\manifest.json"
$sha = (Get-FileHash $exe -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $exe).Length
$now = (Get-Date).ToString("s")

$manifest = @{
  name = "AutoAgent"
  latest = $Version
  files = @(@{
    version = $Version
    sha256 = $sha
    size = $size
    url = "https://$AccountId.r2.cloudflarestorage.com/public/$Bucket/AutoAgent-$Version.exe"
    released_at = $now
    notes = "Built from scripts"
  })
}
$manifest | ConvertTo-Json -Depth 5 | Out-File -Encoding utf8 $manifestPath
Write-Host "Manifest updated at $manifestPath"
