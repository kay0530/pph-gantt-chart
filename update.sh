#!/bin/bash
# PPH Gantt Chart - One-command data update
# Usage: bash update.sh
# Requires: sf CLI (authenticated), python3, git

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

SF_ORG="new_keisuke.tanaka@altenergy.co.jp"
SOQL_QUERY="SELECT Id, Name, StageName, Account.Id, Account.Name, Location__r.State__c, ConstractType__c, Probability__c, Owner.Name, InvestigationUser__r.Name, ConstUser__r.Name, TempSurveyDate__c, SurveyDate__c, SurveyKakutei__c, Naijibi__c, Field27__c, KojiSekouyoteibi__c, KojiSekouKakuteibi__c, ScheduleOfBlackoutDates__c, KojiKankobi__c, Kankobi__c, KankoKakuteibi__c, StartDate__c, StartKakutei__c, Jucyubi__c FROM Opportunity WHERE Location__c != null AND StageName NOT IN ('失注', '10_完工／引渡し', 'ペンディング') AND PPH__c = true ORDER BY Account.Name ASC"

echo "=== PPH データ更新 ==="

# 1. Fetch from Salesforce
echo "[1/4] Salesforceからデータ取得中..."
sf data query --query "$SOQL_QUERY" --target-org "$SF_ORG" --result-format json > raw_pph.json
echo "  取得完了"

# 2. Convert to pph_data_v5.json format
echo "[2/4] JSON変換中..."
python3 -c "
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
print(f'  {len(out)}件 → pph_data_v5.json')
"

# 3. Cleanup
rm -f raw_pph.json

# 4. Git commit & push
echo "[3/4] Git commit..."
git add pph_data_v5.json
if git diff --cached --quiet; then
    echo "  データに変更なし。スキップ"
else
    git commit -m "data: Salesforceデータ更新 $(date '+%Y/%m/%d %H:%M')"
    echo "[4/4] Git push..."
    git push
    echo "=== 完了! GitHub Pagesに数分で反映されます ==="
fi
