# PPH Gantt Chart - One-command data update (PowerShell)
# Usage: .\update.ps1
# Requires: sf CLI (authenticated), python, git

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$SfOrg = "new_keisuke.tanaka@altenergy.co.jp"
$SoqlQuery = @"
SELECT Id, Name, StageName, Account.Id, Account.Name, Location__r.State__c, ConstractType__c, Probability__c, Owner.Name, InvestigationUser__r.Name, ConstUser__r.Name, TempSurveyDate__c, SurveyDate__c, SurveyKakutei__c, Naijibi__c, Field27__c, KojiSekouyoteibi__c, KojiSekouKakuteibi__c, ScheduleOfBlackoutDates__c, KojiKankobi__c, Kankobi__c, KankoKakuteibi__c, StartDate__c, StartKakutei__c, Jucyubi__c FROM Opportunity WHERE Location__c != null AND StageName NOT IN ('失注', '10_完工／引渡し', 'ペンディング') AND PPH__c = true ORDER BY Account.Name ASC
"@.Trim()

Write-Host "=== PPH データ更新 ===" -ForegroundColor Cyan

# 1. Fetch from Salesforce
Write-Host "[1/4] Salesforceからデータ取得中..." -ForegroundColor Yellow
sf data query --query "$SoqlQuery" --target-org "$SfOrg" --result-format json | Out-File -Encoding utf8NoBOM raw_pph.json
Write-Host "  取得完了" -ForegroundColor Green

# 2. Convert to pph_data_v5.json
Write-Host "[2/4] JSON変換中..." -ForegroundColor Yellow
$pythonScript = @'
import json, sys

with open('raw_pph.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

records = data.get('result', {}).get('records', data.get('records', []))

def flatten(rec):
    flat = {}
    for k, v in rec.items():
        if k == 'attributes':
            continue
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
            else:
                flat[k] = v
        else:
            flat[k] = v
    return flat

out = [flatten(r) for r in records]
with open('pph_data_v5.json', 'w', encoding='utf-8') as f:
    json.dump({'totalSize': len(out), 'records': out}, f, ensure_ascii=False, indent=2)
print(f'  {len(out)}件 -> pph_data_v5.json')
'@

$pythonScript | python -
Write-Host "  変換完了" -ForegroundColor Green

# 3. Cleanup
Remove-Item -Force raw_pph.json -ErrorAction SilentlyContinue

# 4. Git commit & push
Write-Host "[3/4] Git commit..." -ForegroundColor Yellow
git add pph_data_v5.json

$diff = git diff --cached --quiet 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  データに変更なし。スキップ" -ForegroundColor Gray
} else {
    $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm"
    git commit -m "data: Salesforceデータ更新 $timestamp"
    Write-Host "[4/4] Git push..." -ForegroundColor Yellow
    git push
    Write-Host "=== 完了! GitHub Pagesに数分で反映されます ===" -ForegroundColor Cyan
}
