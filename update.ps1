# PPH Gantt Chart - One-command data update (PowerShell)
# Usage: .\update.ps1
# Requires: sf CLI (authenticated), python, git

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$SfOrg = "new_keisuke.tanaka@altenergy.co.jp"
$SoqlQuery = @"
SELECT Id, Name, StageName, Account.Id, Account.Name, Location__r.State__c, ConstractType__c, Probability__c, Owner.Name, InvestigationUser__r.Name, ConstUser__r.Name, TempSurveyDate__c, SurveyDate__c, SurveyKakutei__c, Naijibi__c, Field27__c, KojiSekouyoteibi__c, KojiSekouKakuteibi__c, ScheduleOfBlackoutDates__c, KojiKankobi__c, Kankobi__c, KankoKakuteibi__c, StartDate__c, StartKakutei__c, Jucyubi__c FROM Opportunity WHERE Location__c != null AND StageName NOT IN ('失注', '10_完工／引渡し', 'ペンディング') AND PPH__c = true ORDER BY Account.Name ASC
"@.Trim()

Write-Host "=== PPH Data Update ===" -ForegroundColor Cyan

# 1. Fetch from Salesforce
Write-Host "[1/4] Fetching from Salesforce..." -ForegroundColor Yellow
$jsonResult = sf data query --query "$SoqlQuery" --target-org "$SfOrg" --result-format json
[System.IO.File]::WriteAllText("$ScriptDir\raw_pph.json", ($jsonResult -join "`n"), [System.Text.UTF8Encoding]::new($false))
Write-Host "  Done" -ForegroundColor Green

# 2. Convert to pph_data_v5.json
Write-Host "[2/4] Converting JSON..." -ForegroundColor Yellow
python -c @"
import json
with open('raw_pph.json', 'r', encoding='utf-8') as f:
    data = json.load(f)
records = data.get('result', {}).get('records', data.get('records', []))
def flatten(rec):
    flat = {}
    for k, v in rec.items():
        if k == 'attributes': continue
        if isinstance(v, dict):
            nested = {nk: nv for nk, nv in v.items() if nk != 'attributes'}
            if k == 'Account':
                flat['AccountId'] = nested.get('Id')
                flat['AccountName'] = nested.get('Name')
            elif k == 'Location__r':
                flat['Prefecture'] = nested.get('State__c')
            elif k == 'Owner':
                flat['OwnerName'] = nested.get('Name')
            elif k == 'InvestigationUser__r':
                flat['InvestigationUserName'] = nested.get('Name')
            elif k == 'ConstUser__r':
                flat['ConstUserName'] = nested.get('Name')
            else: flat[k] = v
        else: flat[k] = v
    return flat
out = [flatten(r) for r in records]
with open('pph_data_v5.json', 'w', encoding='utf-8') as f:
    json.dump({'totalSize': len(out), 'records': out}, f, ensure_ascii=False, indent=2)
print(f'  {len(out)} records -> pph_data_v5.json')
"@
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
