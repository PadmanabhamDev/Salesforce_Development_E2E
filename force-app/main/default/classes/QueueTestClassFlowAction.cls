public with sharing class QueueTestClassFlowAction {

    public class Request {
        @InvocableVariable(required=true)
        public String apexClassName;
    }

    public class Result {
        @InvocableVariable public String apexClassName;
        @InvocableVariable public String testClassName;
        @InvocableVariable public String status;
        @InvocableVariable public String message;
        @InvocableVariable public Id queueItemId;
        @InvocableVariable public Id coverageRunId; // Apex_Coverage_Run__c Id
    }

    @InvocableMethod(label='Queue Matching Test Class')
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();

        for (Request req : requests) {
            Result r = new Result();
            r.apexClassName = req.apexClassName;

            try {
                if (String.isBlank(req.apexClassName)) {
                    throw new AuraHandledException('apexClassName is required.');
                }

                // Verify target class exists
                ApexClass target = [
                    SELECT Id, Name
                    FROM ApexClass
                    WHERE Name = :req.apexClassName
                    LIMIT 1
                ];

                // Find test class by naming convention
                String expected = req.apexClassName + 'Test';
                List<ApexClass> tests = [
                    SELECT Id, Name
                    FROM ApexClass
                    WHERE Name = :expected
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
                } else {
                    ApexClass t = tests[0];
                    ApexTestQueueItem q = new ApexTestQueueItem(ApexClassId = t.Id);
                    insert q;

                    r.testClassName = t.Name;
                    r.queueItemId = q.Id;
                    r.status = 'QUEUED';
                    r.message = 'Test queued successfully.';
                }

            } catch (Exception e) {
                r.status = 'ERROR';
                r.message = e.getMessage();
            }

            // Create tracking record in Apex_Coverage_Run__c
            Apex_Coverage_Run__c runRec = new Apex_Coverage_Run__c();
            runRec.Name = 'ACR-' + String.valueOf(Datetime.now().getTime());
            runRec.ApexClassName__c = r.apexClassName;
            runRec.TestClassName__c = r.testClassName;
            runRec.Status__c = r.status;
            runRec.Message__c = r.message;
            insert runRec;

            r.coverageRunId = runRec.Id;
            out.add(r);
        }

        return out;
    }
}