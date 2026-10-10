# InPoint Check-in - IIS Self-Contained Publish Script
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " Building .NET 8 Self-Contained Release for IIS...        " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

if (Test-Path "./publish") {
    Remove-Item -Path "./publish" -Recurse -Force
}

dotnet publish -c Release -r win-x64 --self-contained true -o "./publish"

if (!(Test-Path "./publish/logs")) {
    New-Item -ItemType Directory -Path "./publish/logs" | Out-Null
}

if (!(Test-Path "./publish/data")) {
    New-Item -ItemType Directory -Path "./publish/data" | Out-Null
}

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[SUCCESS] Publish completed successfully!" -ForegroundColor Green
    Write-Host "[PATH] Output Directory: $((Get-Item ./publish).FullName)" -ForegroundColor Cyan
    Write-Host "[INFO] Please copy all files in ./publish to your IIS Website folder." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "[ERROR] Publish failed. Please check error logs." -ForegroundColor Red
}
