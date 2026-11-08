@RestResource(urlMapping ='/opportunities')
global with sharing class OpportunityRestService {
    
    @HttpPatch
    global  static ResponseWrapper patchOpportunity(PatchRequestWrapper requestBody){
        RestRequest req = RestContext.request;
        String OpportunityId = req.params.get('id');

        if(String.IsBlank(OpportunityId)){
            RestContext.response.statusCode = 400;
            return new ResponseWrapper(false,'Opportunity Id is Required',null);
        }
        List<Opportunity> existingOpp = [Select Id,Amount,StageName From Opportunity Where Id =: OpportunityId];
        if(existingOpp.IsEmpty()){
            return new ResponseWrapper(false,'No Opportunity Record Found ',null);
        }
        Opportunity opp = existingOpp[0];
        opp.StageName = requestBody.StageName;
        opp.Amount = requestBody.Amount;

        try{
            update opp;
            return new ResponseWrapper(true,'Opportunity has been updated ',opp.Id);
        }catch(DmlException ex){
            RestContext.response.statusCode = 500;
            return new ResponseWrapper(false,'Error in Updating Opportunity '+ex.getMessage(),null);
        }
        
    }

    global class PatchRequestWrapper{
        public String StageName;
        public Decimal Amount;
        
    }

    global class ResponseWrapper{
        public Boolean success;
        public String message;
        public String recordId;

        public ResponseWrapper(Boolean success, String message, String recordId){
        this.success = success;
        this.message = message;
        this.recordId = recordId;
        }
    }
}