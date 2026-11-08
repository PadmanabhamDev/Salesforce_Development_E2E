public with sharing class CloudVisionController {
    public CloudVisionController() {

    }

    @AuraEnabled
    public static string getImageInfo(){
        try {
            string apiKey  = 'AIzaSyBCStN8rmROY5rDKg0AQEzU1VyB5ba9Y-Y';  
            string body = '''
            {
                "requests": [
                    {
                        "features": [
                            {
                                "maxResults": 5,
                                "type": "LABEL_DETECTION"
                            }
                        ],
                        "image": {
                            "source": {
                                "imageUri": "gs://cloud-samples-data/vision/label/setagaya.jpeg"
                            }
                        }
                    }
                ]
            }''';          
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://vision.googleapis.com/v1/images:annotate?key=' + apiKey);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(body);
            HttpResponse res = new Http().send(req);
            if(res.getStatusCode()== 200){
                return res.getBody();
            } else {
                throw new AuraHandledException('Error from Cloud Vision API: ' + res.getStatus());
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}