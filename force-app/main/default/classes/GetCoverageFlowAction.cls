public with sharing class GetCoverageFlowAction {

    public class Request {
        @InvocableVariable(required=true)
        public String apexClassName;

        @InvocableVariable(required=true)
        public Id coverageRunId; // Apex_Coverage_Run__c record to update
    }

    public class Result {
        @InvocableVariable public String apexClassName;
        @InvocableVariable public Id coverageRunId;
        @InvocableVariable public Integer coveredLines;
        @InvocableVariable public Integer uncoveredLines;
        @InvocableVariable public Decimal coveragePercent;
        @InvocableVariable public Integer charCount;
        @InvocableVariable public Integer lengthWithoutComments;
        @InvocableVariable public String status;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Get Apex Coverage and Update Coverage Run')
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();

        for (Request req : requests) {
            Result r = new Result();
            r.apexClassName = req.apexClassName;
            r.coverageRunId = req.coverageRunId;

            try {
                if (String.isBlank(req.apexClassName)) {
                    throw new AuraHandledException('apexClassName is required.');
                }
                if (req.coverageRunId == null) {
                    throw new AuraHandledException('coverageRunId is required.');
                }

                ApexClass target = [
                    SELECT Id, Name, Body, LengthWithoutComments
                    FROM ApexClass
                    WHERE Name = :req.apexClassName
                    LIMIT 1
                ];

                Map<String, Integer> cov = fetchCoverage(req.apexClassName);
                Integer covered = cov.get('covered');
                Integer uncovered = cov.get('uncovered');
                Integer total = covered + uncovered;
                Decimal pct = (total == 0) ? 0 : (Decimal.valueOf(covered) * 100) / Decimal.valueOf(total);

                Integer charCount = (target.Body == null) ? 0 : target.Body.length();
                Integer lenWithoutComments = (target.LengthWithoutComments == null)
                    ? 0
                    : Integer.valueOf(target.LengthWithoutComments);

                // Fill result
                r.coveredLines = covered;
                r.uncoveredLines = uncovered;
                r.coveragePercent = pct.setScale(2);
                r.charCount = charCount;
                r.lengthWithoutComments = lenWithoutComments;
                r.status = 'COMPLETED';
                r.message = 'Coverage fetched successfully.';

                // Update tracking record
                Apex_Coverage_Run__c runRec = [
                    SELECT Id
                    FROM Apex_Coverage_Run__c
                    WHERE Id = :req.coverageRunId
                    LIMIT 1
                ];

                runRec.CoveredLines__c = covered;
                runRec.UncoveredLines__c = uncovered;
                runRec.CoveragePercent__c = pct.setScale(0); // field is Percent(3,0)
                runRec.CharCount__c = charCount;
                runRec.LengthWithoutComments__c = lenWithoutComments;
                runRec.Status__c = 'COMPLETED';
                runRec.Message__c = r.message;
                update runRec;

            } catch (Exception e) {
                r.status = 'ERROR';
                r.message = e.getMessage();
                r.coveredLines = 0;
                r.uncoveredLines = 0;
                r.coveragePercent = 0;
                r.charCount = 0;
                r.lengthWithoutComments = 0;

                // Try to update record status to ERROR
                if (req.coverageRunId != null) {
                    try {
                        Apex_Coverage_Run__c errRec = new Apex_Coverage_Run__c(
                            Id = req.coverageRunId,
                            Status__c = 'ERROR',
                            Message__c = e.getMessage()
                        );
                        update errRec;
                    } catch (Exception ignoreMe) {
                        // swallow secondary error
                    }
                }
            }

            out.add(r);
        }

        return out;
    }

    private static Map<String, Integer> fetchCoverage(String className) {
        String soql =
            'SELECT ApexClassOrTrigger.Name, NumLinesCovered, NumLinesUncovered ' +
            'FROM ApexCodeCoverageAggregate ' +
            'WHERE ApexClassOrTrigger.Name = \'' + String.escapeSingleQuotes(className) + '\' ' +
            'LIMIT 1';

        String endpoint = URL.getOrgDomainUrl().toExternalForm()
            + '/services/data/v61.0/tooling/query/?q='
            + EncodingUtil.urlEncode(soql, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = (new Http()).send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Tooling API error: ' + res.getStatus() + ' | ' + res.getBody());
        }

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> records = (List<Object>) payload.get('records');

        Integer covered = 0;
        Integer uncovered = 0;

        if (records != null && !records.isEmpty()) {
            Map<String, Object> row = (Map<String, Object>) records[0];
            covered = toInt(row.get('NumLinesCovered'));
            uncovered = toInt(row.get('NumLinesUncovered'));
        }

        return new Map<String, Integer>{ 'covered' => covered, 'uncovered' => uncovered };
    }

    private static Integer toInt(Object v) {
        if (v == null) return 0;
        return Integer.valueOf(String.valueOf(v));
    }
}