# PPH Gantt Chart - One-command data update (PowerShell)
# Usage: .\update.ps1
# Requires: sf CLI (authenticated), python, git

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$SfOrg = "new_keisuke.tanaka@altenergy.co.jp"

Write-Host "=== PPH Data Update ===" -ForegroundColor Cyan

# 1. Fetch from Salesforce (use .soql file to avoid encoding issues)
Write-Host "[1/4] Fetching from Salesforce..." -ForegroundColor Yellow
$result = sf data query --file query.soql --target-org "$SfOrg" --result-format json
[System.IO.File]::WriteAllLines("$ScriptDir\raw_pph.json", $result)
Write-Host "  Done" -ForegroundColor Green

# 2. Convert to pph_data_v5.json
Write-Host "[2/4] Converting JSON..." -ForegroundColor Yellow
python convert_data.py
Write-Host "  Done" -ForegroundColor Green

# 3. Cleanup
Remove-Item -Force raw_pph.json -ErrorAction SilentlyContinue

# 4. Git commit & push
Write-Host "[3/4] Git commit..." -ForegroundColor Yellow
git add pph_data_v5.json

$null = git diff --cached --quiet 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  No changes. Skip." -ForegroundColor Gray
} else {
    $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm"
    git commit -m "data: update Salesforce data $timestamp"
    Write-Host "[4/4] Git push..." -ForegroundColor Yellow
    git push
    Write-Host "=== Done! GitHub Pages will update in a few minutes ===" -ForegroundColor Cyan
}
