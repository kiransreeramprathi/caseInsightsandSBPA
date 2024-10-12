public with sharing class ChatGptAPIService {
    @AuraEnabled
    public static String getChatGptResponse(String caseId) {
        system.debug('caseId:: ' + caseId);
        
        // Retrieve the case record
        Case caseRecord = [SELECT Id, Subject, Description FROM Case WHERE Id = :caseId LIMIT 1];
        system.debug('Case Record: ' + caseRecord);
        
        try {
            String promptTemplate = System.Label.Case_Insight_Prompt;
            String prompt = promptTemplate.replace('{caseSubject}', caseRecord.Subject);
            String apiKey = System.Label.AI_API_Key;
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('https://api.openai.com/v1/chat/completions');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Authorization', 'Bearer ' + apiKey);
            
            String body = JSON.serialize(new Map<String, Object>{
                'model' => 'gpt-3.5-turbo',
                'messages' => new List<Object>{
                    new Map<String, Object>{
                        'role' => 'user',
                        'content' => prompt
                    }
                },
                'max_tokens' => 150
            });
            request.setBody(body);
            system.debug('request body:: ' + body);
            
            HttpResponse response = http.send(request);
            system.debug('Response status:: ' + response.getStatusCode());
            system.debug('Response body:: ' + response.getBody());
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> result = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
                List<Object> choices = (List<Object>)result.get('choices');
                if (choices != null && !choices.isEmpty()) {
                    Map<String, Object> firstChoice = (Map<String, Object>)choices[0];
                    Map<String, Object> message = (Map<String, Object>)firstChoice.get('message');
                    return (String)message.get('content');
                } else {
                    throw new AuraHandledException('No response received from ChatGPT.');
                }
            } else if (response.getStatusCode() == 429) { // Handling quota exceeded
                throw new AuraHandledException('Quota exceeded: Please check your OpenAI plan and billing details.');
            } else {
                throw new AuraHandledException('Error communicating with ChatGPT: ' + response.getStatusCode() + ' - ' + response.getStatus());
            }
        } catch (Exception e) {
            system.debug('Exception: ' + e.getMessage());
            throw new AuraHandledException('An error occurred: ' + e.getMessage());
        }
    }
}