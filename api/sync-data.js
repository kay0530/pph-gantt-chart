import jsforce from 'jsforce';

const SOQL = `
SELECT Id, Name, StageName, Account.Name, Location__r.State__c, ConstractType__c, Probability__c,
  Owner.Name, InvestigationUser__r.Name, ConstUser__r.Name,
  TempSurveyDate__c, SurveyDate__c, SurveyKakutei__c,
  Naijibi__c, Field27__c, KojiSekouyoteibi__c, KojiSekouKakuteibi__c,
  ScheduleOfBlackoutDates__c, KojiKankobi__c, Kankobi__c, KankoKakuteibi__c,
  StartDate__c, StartKakutei__c, Jucyubi__c
FROM Opportunity
WHERE Location__c != null AND StageName NOT IN ('失注', '10_完工／引渡し', 'ペンディング') AND PPH__c = true
`.trim();

function renameFields(record) {
  const { Account, Location__r, Owner, InvestigationUser__r, ConstUser__r, ...rest } = record;
  return {
    ...rest,
    AccountName: Account?.Name ?? null,
    Prefecture: Location__r?.State__c ?? null,
    OwnerName: Owner?.Name ?? null,
    InvestigationUserName: InvestigationUser__r?.Name ?? null,
    ConstUserName: ConstUser__r?.Name ?? null,
  };
}

export default async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { SF_LOGIN_URL, SF_USERNAME, SF_PASSWORD, SF_SECURITY_TOKEN } = process.env;

  if (!SF_LOGIN_URL || !SF_USERNAME || !SF_PASSWORD || !SF_SECURITY_TOKEN) {
    return res.status(500).json({ error: 'Missing Salesforce environment variables' });
  }

  try {
    const conn = new jsforce.Connection({ loginUrl: SF_LOGIN_URL });
    await conn.login(SF_USERNAME, SF_PASSWORD + SF_SECURITY_TOKEN);

    let result = await conn.query(SOQL);
    let records = [...result.records];

    // Fetch remaining records if query has more
    while (!result.done) {
      result = await conn.queryMore(result.nextRecordsUrl);
      records = records.concat(result.records);
    }

    // Flatten nested relationship fields
    const data = records.map((r) => {
      const { attributes, ...fields } = r;
      return renameFields(fields);
    });

    res.setHeader('Cache-Control', 's-maxage=300, stale-while-revalidate=600');
    return res.status(200).json({ totalSize: data.length, records: data });
  } catch (err) {
    console.error('Salesforce sync error:', err);
    return res.status(500).json({ error: 'Failed to fetch data from Salesforce', detail: err.message });
  }
}
