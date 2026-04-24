public with sharing class SurveyManagerController {

    @AuraEnabled
    public static Map<String, Object> getStats() {
        Map<String, Object> stats = new Map<String, Object>();
        stats.put('totalSurveys', [SELECT COUNT() FROM Survey__c]);
        stats.put('activeSurveys', [SELECT COUNT() FROM Survey__c WHERE Is_Active__c = true]);
        stats.put('totalQuestions', [SELECT COUNT() FROM Survey_Question__c]);
        stats.put('totalResponses', [SELECT COUNT() FROM Survey_Response__c]);
        return stats;
    }

    @AuraEnabled
    public static List<Survey__c> getSurveys(Boolean activeOnly) {
        if (activeOnly == true) {
            return [
                SELECT Id, Name, Survey_Code__c, Survey_Type__c, Outlet_Type__c,
                       Is_Active__c, Is_Mandatory__c, Effective_From__c, Effective_To__c,
                       Description__c, (SELECT Id FROM Survey_Questions__r)
                FROM Survey__c
                WHERE Is_Active__c = true
                ORDER BY Name
            ];
        }
        return [
            SELECT Id, Name, Survey_Code__c, Survey_Type__c, Outlet_Type__c,
                   Is_Active__c, Is_Mandatory__c, Effective_From__c, Effective_To__c,
                   Description__c, (SELECT Id FROM Survey_Questions__r)
            FROM Survey__c
            ORDER BY Name
        ];
    }

    @AuraEnabled
    public static Survey__c saveSurvey(Survey__c survey) {
        upsert survey;
        return [
            SELECT Id, Name, Survey_Code__c, Survey_Type__c, Outlet_Type__c,
                   Is_Active__c, Is_Mandatory__c, Effective_From__c, Effective_To__c, Description__c
            FROM Survey__c WHERE Id = :survey.Id
        ];
    }

    @AuraEnabled
    public static void deleteSurvey(Id surveyId) {
        delete [SELECT Id FROM Survey__c WHERE Id = :surveyId];
    }

    @AuraEnabled
    public static List<Survey_Question__c> getQuestions(Id surveyId) {
        return [
            SELECT Id, Name, Question_Text__c, Question_Type__c, Options__c,
                   Is_Required__c, Sort_Order__c, Validation_Rule__c, Survey__c
            FROM Survey_Question__c
            WHERE Survey__c = :surveyId
            ORDER BY Sort_Order__c, Name
        ];
    }

    @AuraEnabled
    public static Survey_Question__c saveQuestion(Survey_Question__c question) {
        upsert question;
        return [
            SELECT Id, Name, Question_Text__c, Question_Type__c, Options__c,
                   Is_Required__c, Sort_Order__c, Validation_Rule__c, Survey__c
            FROM Survey_Question__c WHERE Id = :question.Id
        ];
    }

    @AuraEnabled
    public static void deleteQuestion(Id questionId) {
        delete [SELECT Id FROM Survey_Question__c WHERE Id = :questionId];
    }

    @AuraEnabled
    public static List<Survey_Response__c> getResponses(Id surveyId) {
        if (surveyId != null) {
            return [
                SELECT Id, Name, Survey__c, Survey__r.Name, Account__c, Account__r.Name,
                       Visit__c, Visit__r.Name, Respondent__c, Respondent__r.Name,
                       Response_Date__c, Status__c, Total_Score__c
                FROM Survey_Response__c
                WHERE Survey__c = :surveyId
                ORDER BY Response_Date__c DESC
                LIMIT 200
            ];
        }
        return [
            SELECT Id, Name, Survey__c, Survey__r.Name, Account__c, Account__r.Name,
                   Visit__c, Visit__r.Name, Respondent__c, Respondent__r.Name,
                   Response_Date__c, Status__c, Total_Score__c
            FROM Survey_Response__c
            ORDER BY Response_Date__c DESC
            LIMIT 200
        ];
    }
}
