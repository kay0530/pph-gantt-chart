"""MCP Salesforce出力をパースしてJSONファイルに保存"""
import json, os, sys, re
from datetime import datetime

sys.stdout.reconfigure(encoding='utf-8')

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MCP_FILE = r'C:\Users\石井理絵\.claude\projects\C--Users------Desktop-Claude-Code-Demo\370f5140-6c9c-4df8-88af-62792628b142\tool-results\mcp-salesforce-salesforce_query_records-1772507421436.txt'

# Field name mapping from MCP dotted format to flat format
FIELD_RENAMES = {
    'Location__r.State__c': 'Prefecture',
    'InvestigationUser__r.Name': 'InvestigationUserName',
    'ConstUser__r.Name': 'ConstUserName',
}

# Boolean fields
BOOL_FIELDS = {'SurveyKakutei__c', 'KojiSekouKakuteibi__c', 'KankoKakuteibi__c', 'StartKakutei__c'}

def parse_mcp_output(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        raw = json.load(f)
    text = raw[0]['text']

    records = []
    current = None

    for line in text.split('\n'):
        # Record header: "Record 1:", "Record 2:", etc.
        if re.match(r'^Record \d+:', line):
            if current:
                records.append(current)
            current = {}
            continue

        # Field line: "    FieldName: Value"
        m = re.match(r'^    ([A-Za-z_.\d]+): (.*)$', line)
        if m and current is not None:
            key = m.group(1)
            val = m.group(2).strip()

            # Handle null/None values
            if val in ('null', 'None', ''):
                val = None
            # Handle boolean
            elif key in BOOL_FIELDS:
                val = val.lower() == 'true'

            # Rename dotted fields
            out_key = FIELD_RENAMES.get(key, key)
            current[out_key] = val

    # Don't forget the last record
    if current:
        records.append(current)

    return records

def main():
    print('MCP出力をパース中...')
    records = parse_mcp_output(MCP_FILE)
    print(f'パース完了: {len(records)}件')

    if not records:
        print('エラー: レコードが0件です')
        sys.exit(1)

    out_path = os.path.join(SCRIPT_DIR, 'pph_data_v5.json')
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(records, f, ensure_ascii=False, indent=2)
    print(f'JSON保存: {out_path} ({len(records)}件)')

if __name__ == '__main__':
    main()
