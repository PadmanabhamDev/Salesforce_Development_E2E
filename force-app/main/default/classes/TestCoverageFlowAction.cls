public with sharing class TestCoverageFlowAction {

    public class Request {
        @InvocableVariable(required=true)
        public String apexClassName; // e.g. AccountService
    }

    public class Result {
        @InvocableVariable public String apexClassName;
        @InvocableVariable public String testClassName;
        @InvocableVariable public String status;
        @InvocableVariable public String message;
        @InvocableVariable public Integer coveredLines;
        @InvocableVariable public Integer uncoveredLines;
        @InvocableVariable public Decimal coveragePercent;
        @InvocableVariable public Integer charCountIncludingComments;
        @InvocableVariable public Integer lengthWithoutComments;
    }

    @InvocableMethod(label='Find Test Class and Show Coverage')
    public static List<Result> run(List<Request> requests) {
        List<Result> outputs = new List<Result>();

        for (Request req : requests) {
            Result r = new Result();
            r.apexClassName = req.apexClassName;

            try {
                if (String.isBlank(req.apexClassName)) {
                    throw new AuraHandledException('Apex class name is required.');
                }

                // 1) Verify target class exists
                ApexClass target = [
                    SELECT Id, Name, Body, LengthWithoutComments
                    FROM ApexClass
                    WHERE Name = :req.apexClassName
                    LIMIT 1
                ];

                // 2) Find matching test class (same name + Test)
                String expectedTestName = req.apexClassName + 'Test';
                List<ApexClass> tests = [
                    SELECT Id, Name
                    FROM ApexClass
                    WHERE Name = :expectedTestName
                    LIMIT 1
                ];

                if (tests.isEmpty()) {
                    tests = [
                        SELECT Id, Name
                        FROM ApexClass
                        WHERE Name LIKE :('%' + req.apexClassName + '%Test%')
                           OR Name LIKE :('Test%' + req.apexClassName + '%')
                        ORDER BY Name
                        LIMIT 1
                    ];
                }

                if (tests.isEmpty()) {
                    r.status = 'NOT_FOUND';
                    r.message = 'No matching test class found for ' + req.apexClassName;
                    r.testClassName = null;
                } else {
                    ApexClass testCls = tests[0];
                    r.testClassName = testCls.Name;

                    // 3) Queue test run
                    ApexTestQueueItem q = new ApexTestQueueItem(ApexClassId = testCls.Id);
                    insert q;

                    r.status = 'QUEUED';
                    r.message = 'Test queued: ' + testCls.Name + '. Coverage shown is latest available snapshot.';
                }

                // 4) Get coverage via Tooling API
                Map<String, Integer> cov = fetchCoverage(req.apexClassName);
                Integer covered = cov.get('covered');
                Integer uncovered = cov.get('uncovered');
                Integer total = covered + uncovered;
                Decimal pct = (total == 0) ? 0 : (Decimal.valueOf(covered) * 100) / Decimal.valueOf(total);

                r.coveredLines = covered;
                r.uncoveredLines = uncovered;
                r.coveragePercent = pct.setScale(2);

                // 5) Character counts
                r.charCountIncludingComments = (target.Body == null) ? 0 : target.Body.length();
                r.lengthWithoutComments = target.LengthWithoutComments;

                if (String.isBlank(r.status)) r.status = 'DONE';
                if (String.isBlank(r.message)) r.message = 'Success';

            } catch (Exception e) {
                r.status = 'ERROR';
                r.message = e.getMessage();
                r.coveredLines = 0;
                r.uncoveredLines = 0;
                r.coveragePercent = 0;
                r.charCountIncludingComments = 0;
                r.lengthWithoutComments = 0;
            }

            outputs.add(r);
        }

        return outputs;
    }

    private static Map<String, Integer> fetchCoverage(String className) {
        String soql =
            'SELECT ApexClassOrTrigger.Name, NumLinesCovered, NumLinesUncovered ' +
            'FROM ApexCodeCoverageAggregate ' +
            'WHERE ApexClassOrTrigger.Name = \'' + String.escapeSingleQuotes(className) + '\' ' +
            'LIMIT 1';

        String endpoint = URL.getOrgDomainUrl().toExternalForm()
            + '/services/data/v61.0/tooling/query/?q=' + EncodingUtil.urlEncode(soql, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = (new Http()).send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Coverage query failed: ' + res.getStatus());
        }

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> records = (List<Object>) payload.get('records');

        Integer covered = 0, uncovered = 0;
        if (records != null && !records.isEmpty()) {
            Map<String, Object> row = (Map<String, Object>) records[0];
            covered = toInt(row.get('NumLinesCovered'));
            uncovered = toInt(row.get('NumLinesUncovered'));
        }

        return new Map<String, Integer>{
            'covered' => covered,
            'uncovered' => uncovered
        };
    }

    private static Integer toInt(Object v) {
        if (v == null) return 0;
        return Integer.valueOf(String.valueOf(v));
    }
}