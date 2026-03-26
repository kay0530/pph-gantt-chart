"""Convert raw SF CLI JSON output to pph_data_v5.json format."""
import json, os

script_dir = os.path.dirname(os.path.abspath(__file__))
raw_path = os.path.join(script_dir, 'raw_pph.json')
design_path = os.path.join(script_dir, 'raw_design.json')
out_path = os.path.join(script_dir, 'pph_data_v5.json')

with open(raw_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

records = data.get('result', {}).get('records', data.get('records', []))

# Load design request deadlines (Opportunity__c -> latest Deadline__c)
design_deadlines = {}
if os.path.exists(design_path):
    with open(design_path, 'r', encoding='utf-8') as f:
        dd = json.load(f)
    for r in dd.get('result', {}).get('records', dd.get('records', [])):
        opp_id = r.get('Opportunity__c')
        dl = r.get('Deadline__c')
        if opp_id and dl and opp_id not in design_deadlines:
            design_deadlines[opp_id] = dl


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

# Merge design deadlines
for rec in out:
    opp_id = rec.get('Id')
    if opp_id and opp_id in design_deadlines:
        rec['DesignDeadline__c'] = design_deadlines[opp_id]
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump({'totalSize': len(out), 'records': out}, f, ensure_ascii=False, indent=2)
print(f'  {len(out)} records -> pph_data_v5.json')
