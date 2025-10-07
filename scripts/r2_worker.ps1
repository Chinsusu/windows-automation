Param(
  [Parameter(Mandatory=$true)][string]$WorkerUrl,
  [Parameter(Mandatory=$true)][string]$AuthToken
)

function Upload-R2File {
  Param(
    [Parameter(Mandatory=$true)][string]$LocalPath,
    [Parameter(Mandatory=$true)][string]$RemotePath
  )
  if (!(Test-Path $LocalPath)) { throw "Local file not found: $LocalPath" }
  Invoke-RestMethod -Uri "$($WorkerUrl)/upload/$RemotePath" -Method Put `
    -Headers @{ Authorization = "Bearer $AuthToken" } `
    -InFile $LocalPath -ContentType "application/octet-stream"
}

function List-R2 {
  Param([string]$Prefix = "")
  $u = if ($Prefix) { "$($WorkerUrl)/list?prefix=$Prefix" } else { "$($WorkerUrl)/list" }
  Invoke-RestMethod -Uri $u -Method Get
}

function Download-R2File {
  Param(
    [Parameter(Mandatory=$true)][string]$RemotePath,
    [Parameter(Mandatory=$true)][string]$OutFile
  )
  Invoke-RestMethod -Uri "$($WorkerUrl)/download/$RemotePath" -Method Get -OutFile $OutFile
}

function Remove-R2File {
  Param([Parameter(Mandatory=$true)][string]$RemotePath)
  Invoke-RestMethod -Uri "$($WorkerUrl)/file/$RemotePath" -Method Delete `
    -Headers @{ Authorization = "Bearer $AuthToken" }
}

<#
USAGE:

$WorkerUrl = $env:R2_WORKER_URL
$AuthToken = $env:R2_AUTH_TOKEN

# Upload a release file
Upload-R2File -LocalPath "..\dist\AutoAgent-0.2.0.exe" -RemotePath "releases/AutoAgent-0.2.0.exe"

# List objects
List-R2
List-R2 -Prefix "releases/"

# Download
Download-R2File -RemotePath "releases/AutoAgent-0.2.0.exe" -OutFile "..\dist\AutoAgent-0.2.0.exe"

# Delete
Remove-R2File -RemotePath "releases/AutoAgent-0.2.0.exe"
#>
