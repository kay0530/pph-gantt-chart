"""
Salesforceから最新PPH商談データを取得し、JSONファイルに保存するスクリプト。
GitHub Actionsまたはローカルから実行可能。

必要な環境変数:
  SF_USERNAME       - Salesforceユーザー名
  SF_PASSWORD       - Salesforceパスワード
  SF_SECURITY_TOKEN - Salesforceセキュリティトークン
  SF_DOMAIN         - Salesforceドメイン (login / test)

ローカル実行時:
  - .env ファイルから環境変数を読み込み可能
"""
import json, os, sys

sys.stdout.reconfigure(encoding='utf-8')

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

SOQL = """
SELECT
  Id, Name, StageName,
  Account.Id, Account.Name,
  Location__r.State__c,
  ConstractType__c, Probability__c,
  Owner.Name,
  InvestigationUser__r.Name, ConstUser__r.Name,
  TempSurveyDate__c, SurveyDate__c, SurveyKakutei__c,
  Naijibi__c, Field27__c,
  KojiSekouyoteibi__c, KojiSekouKakuteibi__c,
  ScheduleOfBlackoutDates__c,
  KojiKankobi__c, Kankobi__c, KankoKakuteibi__c,
  StartDate__c, StartKakutei__c, Jucyubi__c
FROM Opportunity
WHERE Location__c != null
  AND StageName NOT IN ('失注', '10_完工／引渡し', 'ペンディング')
  AND PPH__c = true
ORDER BY Account.Name ASC
""".strip()


def flatten_record(rec):
    """Salesforceレコードをフラットなdictに変換"""
    flat = {}
    for key, val in rec.items():
        if key == 'attributes':
            continue
        if isinstance(val, dict):
            nested = {k: v for k, v in val.items() if k != 'attributes'}
            if key == 'Account':
                flat['AccountId'] = nested.get('Id')
                flat['AccountName'] = nested.get('Name')
            elif key == 'Location__r':
                flat['Prefecture'] = nested.get('State__c')
            elif key == 'Owner':
                flat['OwnerName'] = nested.get('Name')
            elif key == 'InvestigationUser__r':
                flat['InvestigationUserName'] = nested.get('Name')
            elif key == 'ConstUser__r':
                flat['ConstUserName'] = nested.get('Name')
            else:
                flat[key] = val
        else:
            flat[key] = val
    return flat


def main():
    # .envファイルがあれば読み込み
    env_path = os.path.join(SCRIPT_DIR, '.env')
    if os.path.exists(env_path):
        with open(env_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    k, v = line.split('=', 1)
                    os.environ.setdefault(k.strip(), v.strip())

    # --- Salesforce接続 ---
    try:
        from simple_salesforce import Salesforce
    except ImportError:
        print('エラー: simple_salesforce がインストールされていません')
        print('  pip install simple-salesforce')
        sys.exit(1)

    sf_user = os.environ.get('SF_USERNAME', '')
    sf_pass = os.environ.get('SF_PASSWORD', '')
    sf_token = os.environ.get('SF_SECURITY_TOKEN', '')
    sf_domain = os.environ.get('SF_DOMAIN', 'login')

    if not sf_user or not sf_pass:
        print('エラー: Salesforce認証情報が設定されていません')
        print('  環境変数 SF_USERNAME, SF_PASSWORD, SF_SECURITY_TOKEN を設定してください')
        print('  または .env ファイルに記載してください')
        sys.exit(1)

    print('Salesforceに接続中...')
    sf = Salesforce(username=sf_user, password=sf_pass,
                    security_token=sf_token, domain=sf_domain)

    print('データ取得中...')
    result = sf.query_all(SOQL)
    records = [flatten_record(r) for r in result['records']]
    print(f'取得件数: {len(records)}')

    output = {'totalSize': len(records), 'records': records}
    out_path = os.path.join(SCRIPT_DIR, 'pph_data_v5.json')
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    print(f'JSON保存: {out_path} ({len(records)}件)')


if __name__ == '__main__':
    main()
