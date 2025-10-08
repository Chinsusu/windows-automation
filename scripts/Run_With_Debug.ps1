# Run_With_Debug.ps1
# Wrapper to capture console output from AutoIt script

$logFile = "$env:TEMP\earnapp_debug_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$exePath = "C:\Users\Admin\Documents\automation\scripts\Install_Earnapp_WithImages.exe"

Write-Host "Starting Earnapp installer with debug logging..." -ForegroundColor Green
Write-Host "Log file: $logFile" -ForegroundColor Yellow
Write-Host ""

# Start process and redirect output
$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = $exePath
$processInfo.RedirectStandardOutput = $true
$processInfo.RedirectStandardError = $true
$processInfo.UseShellExecute = $false
$processInfo.CreateNoWindow = $false

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $processInfo

# Event handlers for output
$outputBuilder = New-Object System.Text.StringBuilder
$errorBuilder = New-Object System.Text.StringBuilder

$outputHandler = {
    if (-not [String]::IsNullOrEmpty($EventArgs.Data)) {
        $outputBuilder.AppendLine($EventArgs.Data)
        Write-Host $EventArgs.Data
    }
}

$errorHandler = {
    if (-not [String]::IsNullOrEmpty($EventArgs.Data)) {
        $errorBuilder.AppendLine($EventArgs.Data)
        Write-Host $EventArgs.Data -ForegroundColor Red
    }
}

$process.add_OutputDataReceived($outputHandler)
$process.add_ErrorDataReceived($errorHandler)

# Start and wait
$process.Start() | Out-Null
$process.BeginOutputReadLine()
$process.BeginErrorReadLine()
$process.WaitForExit()

# Save to log file
$output = $outputBuilder.ToString()
$errors = $errorBuilder.ToString()

$output | Out-File -FilePath $logFile -Encoding UTF8
if ($errors) {
    "`n=== ERRORS ===" | Out-File -FilePath $logFile -Append -Encoding UTF8
    $errors | Out-File -FilePath $logFile -Append -Encoding UTF8
}

Write-Host ""
Write-Host "Process completed with exit code: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -eq 0) { "Green" } else { "Red" })
Write-Host "Full log saved to: $logFile" -ForegroundColor Cyan

# Show log location
explorer.exe /select,$logFile
