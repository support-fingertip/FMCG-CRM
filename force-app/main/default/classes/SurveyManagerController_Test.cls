@IsTest
private class SurveyManagerController_Test {

    @TestSetup
    static void setup() {
        // Create surveys
        Survey__c activeSurvey = new Survey__c(
            Name = 'Active Survey',
            Survey_Code__c = 'SRV-001',
            Survey_Type__c = 'Brand Audit',
            Is_Active__c = true,
            Is_Mandatory__c = false,
            Effective_From__c = Date.today().addDays(-10),
            Effective_To__c = Date.today().addDays(30),
            Description__c = 'Active test survey'
        );

        Survey__c inactiveSurvey = new Survey__c(
            Name = 'Inactive Survey',
            Survey_Code__c = 'SRV-002',
            Survey_Type__c = 'Customer Feedback',
            Is_Active__c = false,
            Is_Mandatory__c = false,
            Description__c = 'Inactive test survey'
        );

        insert new List<Survey__c>{ activeSurvey, inactiveSurvey };

        // Create questions for active survey
        List<Survey_Question__c> questions = new List<Survey_Question__c>();
        questions.add(new Survey_Question__c(
            Survey__c = activeSurvey.Id,
            Question_Text__c = 'How would you rate our product quality?',
            Question_Type__c = 'Rating',
            Is_Required__c = true,
            Sort_Order__c = 1
        ));
        questions.add(new Survey_Question__c(
            Survey__c = activeSurvey.Id,
            Question_Text__c = 'Which brand do you prefer?',
            Question_Type__c = 'Single Choice',
            Options__c = 'Brand A;Brand B;Brand C',
            Is_Required__c = true,
            Sort_Order__c = 2
        ));
        questions.add(new Survey_Question__c(
            Survey__c = activeSurvey.Id,
            Question_Text__c = 'Any additional comments?',
            Question_Type__c = 'Text',
            Is_Required__c = false,
            Sort_Order__c = 3
        ));
        insert questions;

        // Create an account for responses
        Account acc = TestDataFactory.createAndInsertAccount('Survey Outlet', 'Retailer');

        // Create a survey response
        Survey_Response__c response = new Survey_Response__c(
            Survey__c = activeSurvey.Id,
            Account__c = acc.Id,
            Response_Date__c = Date.today(),
            Status__c = 'Completed',
            Total_Score__c = 4
        );
        insert response;

        // Create answers
        List<Survey_Answer__c> answers = new List<Survey_Answer__c>();
        answers.add(new Survey_Answer__c(
            Survey_Response__c = response.Id,
            Survey_Question__c = questions[0].Id,
            Rating_Value__c = 4
        ));
        answers.add(new Survey_Answer__c(
            Survey_Response__c = response.Id,
            Survey_Question__c = questions[1].Id,
            Answer_Choice__c = 'Brand A'
        ));
        answers.add(new Survey_Answer__c(
            Survey_Response__c = response.Id,
            Survey_Question__c = questions[2].Id,
            Answer_Text__c = 'Great products!'
        ));
        insert answers;
    }

    static Survey__c getActiveSurvey() {
        return [SELECT Id FROM Survey__c WHERE Survey_Code__c = 'SRV-001' LIMIT 1];
    }

    static Survey__c getInactiveSurvey() {
        return [SELECT Id FROM Survey__c WHERE Survey_Code__c = 'SRV-002' LIMIT 1];
    }

    static Survey_Response__c getTestResponse() {
        return [SELECT Id FROM Survey_Response__c LIMIT 1];
    }

    // ── getStats ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetStats() {
        Test.startTest();
        Map<String, Object> stats = SurveyManagerController.getStats();
        Test.stopTest();

        System.assertNotEquals(null, stats, 'Stats should not be null');
        System.assertEquals(2, (Integer) stats.get('totalSurveys'), 'Should have 2 total surveys');
        System.assertEquals(1, (Integer) stats.get('activeSurveys'), 'Should have 1 active survey');
        System.assertEquals(3, (Integer) stats.get('totalQuestions'), 'Should have 3 total questions');
        System.assertEquals(1, (Integer) stats.get('totalResponses'), 'Should have 1 total response');
    }

    // ── getSurveys ───────────────────────────────────────────────────────────

    @IsTest
    static void testGetSurveysActiveOnly() {
        Test.startTest();
        List<Survey__c> surveys = SurveyManagerController.getSurveys(true);
        Test.stopTest();

        System.assertEquals(1, surveys.size(), 'Should return only 1 active survey');
        System.assertEquals(true, surveys[0].Is_Active__c, 'Survey should be active');
        System.assertEquals('Active Survey', surveys[0].Name, 'Should be the Active Survey');
    }

    @IsTest
    static void testGetSurveysAll() {
        Test.startTest();
        List<Survey__c> surveys = SurveyManagerController.getSurveys(false);
        Test.stopTest();

        System.assertEquals(2, surveys.size(), 'Should return all 2 surveys');
    }

    @IsTest
    static void testGetSurveysNullParam() {
        Test.startTest();
        List<Survey__c> surveys = SurveyManagerController.getSurveys(null);
        Test.stopTest();

        System.assertEquals(2, surveys.size(), 'Null activeOnly should return all surveys');
    }

    // ── saveSurvey: insert ───────────────────────────────────────────────────

    @IsTest
    static void testSaveSurveyInsert() {
        Survey__c newSurvey = new Survey__c(
            Name = 'New Survey',
            Survey_Code__c = 'SRV-NEW',
            Survey_Type__c = 'Shelf Audit',
            Is_Active__c = true,
            Is_Mandatory__c = true,
            Description__c = 'Newly created survey'
        );

        Test.startTest();
        Survey__c result = SurveyManagerController.saveSurvey(newSurvey);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Survey should be inserted');
        System.assertEquals('New Survey', result.Name, 'Name should match');
        System.assertEquals('SRV-NEW', result.Survey_Code__c, 'Code should match');
        System.assertEquals(true, result.Is_Mandatory__c, 'Should be mandatory');
    }

    // ── saveSurvey: update ───────────────────────────────────────────────────

    @IsTest
    static void testSaveSurveyUpdate() {
        Survey__c survey = getActiveSurvey();
        survey.Description__c = 'Updated description';

        Test.startTest();
        Survey__c result = SurveyManagerController.saveSurvey(survey);
        Test.stopTest();

        System.assertEquals('Updated description', result.Description__c,
            'Description should be updated');
    }

    // ── deleteSurvey ─────────────────────────────────────────────────────────

    @IsTest
    static void testDeleteSurvey() {
        Survey__c survey = getInactiveSurvey();

        Test.startTest();
        SurveyManagerController.deleteSurvey(survey.Id);
        Test.stopTest();

        List<Survey__c> remaining = [SELECT Id FROM Survey__c WHERE Id = :survey.Id];
        System.assertEquals(0, remaining.size(), 'Survey should be deleted');
    }

    // ── getQuestions ─────────────────────────────────────────────────────────

    @IsTest
    static void testGetQuestions() {
        Survey__c survey = getActiveSurvey();

        Test.startTest();
        List<Survey_Question__c> questions = SurveyManagerController.getQuestions(survey.Id);
        Test.stopTest();

        System.assertEquals(3, questions.size(), 'Should return 3 questions');
        // Verify sort order
        System.assertEquals(1, questions[0].Sort_Order__c, 'First question should have sort order 1');
        System.assertEquals(2, questions[1].Sort_Order__c, 'Second question should have sort order 2');
        System.assertEquals(3, questions[2].Sort_Order__c, 'Third question should have sort order 3');
    }

    @IsTest
    static void testGetQuestionsEmpty() {
        Survey__c survey = getInactiveSurvey();

        Test.startTest();
        List<Survey_Question__c> questions = SurveyManagerController.getQuestions(survey.Id);
        Test.stopTest();

        System.assertEquals(0, questions.size(), 'Inactive survey should have no questions');
    }

    // ── saveQuestion: insert ─────────────────────────────────────────────────

    @IsTest
    static void testSaveQuestionInsert() {
        Survey__c survey = getActiveSurvey();

        Survey_Question__c newQuestion = new Survey_Question__c(
            Survey__c = survey.Id,
            Question_Text__c = 'Is the product visible on shelf?',
            Question_Type__c = 'Yes/No',
            Is_Required__c = true,
            Sort_Order__c = 4
        );

        Test.startTest();
        Survey_Question__c result = SurveyManagerController.saveQuestion(newQuestion);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Question should be inserted');
        System.assertEquals('Is the product visible on shelf?', result.Question_Text__c,
            'Question text should match');
        System.assertEquals(4, result.Sort_Order__c, 'Sort order should be 4');
    }

    // ── saveQuestion: update ─────────────────────────────────────────────────

    @IsTest
    static void testSaveQuestionUpdate() {
        Survey__c survey = getActiveSurvey();
        Survey_Question__c question = [
            SELECT Id, Question_Text__c FROM Survey_Question__c
            WHERE Survey__c = :survey.Id AND Sort_Order__c = 1 LIMIT 1
        ];
        question.Question_Text__c = 'Updated: How would you rate quality?';

        Test.startTest();
        Survey_Question__c result = SurveyManagerController.saveQuestion(question);
        Test.stopTest();

        System.assertEquals('Updated: How would you rate quality?', result.Question_Text__c,
            'Question text should be updated');
    }

    // ── deleteQuestion ───────────────────────────────────────────────────────

    @IsTest
    static void testDeleteQuestion() {
        Survey__c survey = getActiveSurvey();
        Survey_Question__c question = [
            SELECT Id FROM Survey_Question__c
            WHERE Survey__c = :survey.Id AND Sort_Order__c = 3 LIMIT 1
        ];

        Test.startTest();
        SurveyManagerController.deleteQuestion(question.Id);
        Test.stopTest();

        List<Survey_Question__c> remaining = [
            SELECT Id FROM Survey_Question__c WHERE Id = :question.Id
        ];
        System.assertEquals(0, remaining.size(), 'Question should be deleted');
    }

    // ── getResponses: by survey ──────────────────────────────────────────────

    @IsTest
    static void testGetResponsesBySurvey() {
        Survey__c survey = getActiveSurvey();

        Test.startTest();
        List<Survey_Response__c> responses = SurveyManagerController.getResponses(survey.Id);
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should have 1 response for active survey');
        System.assertEquals('Completed', responses[0].Status__c, 'Response should be Completed');
    }

    // ── getResponses: all (null surveyId) ────────────────────────────────────

    @IsTest
    static void testGetResponsesAll() {
        Test.startTest();
        List<Survey_Response__c> responses = SurveyManagerController.getResponses(null);
        Test.stopTest();

        System.assert(responses.size() >= 1, 'Should return at least 1 response');
    }

    // ── getResponses: no responses ───────────────────────────────────────────

    @IsTest
    static void testGetResponsesEmpty() {
        Survey__c survey = getInactiveSurvey();

        Test.startTest();
        List<Survey_Response__c> responses = SurveyManagerController.getResponses(survey.Id);
        Test.stopTest();

        System.assertEquals(0, responses.size(), 'Inactive survey should have no responses');
    }

    // ── getResponseDetail ────────────────────────────────────────────────────

    @IsTest
    static void testGetResponseDetail() {
        Survey_Response__c response = getTestResponse();

        Test.startTest();
        Map<String, Object> detail = SurveyManagerController.getResponseDetail(response.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail, 'Response detail should not be null');
        System.assert(detail.containsKey('response'), 'Should have response key');
        System.assert(detail.containsKey('answers'), 'Should have answers key');

        Survey_Response__c resp = (Survey_Response__c) detail.get('response');
        System.assertEquals(response.Id, resp.Id, 'Response Id should match');

        List<Map<String, Object>> answers = (List<Map<String, Object>>) detail.get('answers');
        System.assertEquals(3, answers.size(), 'Should have 3 answers');

        // Verify answer display values
        Boolean foundRating = false;
        Boolean foundChoice = false;
        Boolean foundText = false;
        for (Map<String, Object> answer : answers) {
            String displayValue = (String) answer.get('displayValue');
            String questionType = (String) answer.get('questionType');

            if (questionType == 'Rating') {
                System.assertEquals('4 / 5', displayValue, 'Rating should be formatted as 4 / 5');
                foundRating = true;
            } else if (questionType == 'Single Choice') {
                System.assertEquals('Brand A', displayValue, 'Choice should be Brand A');
                foundChoice = true;
            } else if (questionType == 'Text') {
                System.assertEquals('Great products!', displayValue, 'Text should match');
                foundText = true;
            }
        }
        System.assert(foundRating, 'Should have a rating answer');
        System.assert(foundChoice, 'Should have a choice answer');
        System.assert(foundText, 'Should have a text answer');
    }

    // ── getResponseDetail: verify answer with number value ───────────────────

    @IsTest
    static void testGetResponseDetailWithNumberAnswer() {
        Survey__c survey = getActiveSurvey();
        Account acc = [SELECT Id FROM Account WHERE Name = 'Survey Outlet' LIMIT 1];

        // Create a question with number type
        Survey_Question__c numQuestion = new Survey_Question__c(
            Survey__c = survey.Id,
            Question_Text__c = 'How many facings?',
            Question_Type__c = 'Number',
            Sort_Order__c = 10
        );
        insert numQuestion;

        Survey_Response__c response = new Survey_Response__c(
            Survey__c = survey.Id,
            Account__c = acc.Id,
            Response_Date__c = Date.today(),
            Status__c = 'Completed'
        );
        insert response;

        Survey_Answer__c answer = new Survey_Answer__c(
            Survey_Response__c = response.Id,
            Survey_Question__c = numQuestion.Id,
            Answer_Number__c = 12
        );
        insert answer;

        Test.startTest();
        Map<String, Object> detail = SurveyManagerController.getResponseDetail(response.Id);
        Test.stopTest();

        List<Map<String, Object>> answers = (List<Map<String, Object>>) detail.get('answers');
        System.assertEquals(1, answers.size(), 'Should have 1 answer');
        System.assertEquals('12', (String) answers[0].get('displayValue'),
            'Number answer should be displayed as string');
    }

    // ── Verify stats after additional data ───────────────────────────────────

    @IsTest
    static void testGetStatsAfterAdditionalData() {
        // Add another survey and response
        Survey__c newSurvey = new Survey__c(
            Name = 'Extra Survey',
            Survey_Code__c = 'SRV-EXT',
            Survey_Type__c = 'Price Check',
            Is_Active__c = true
        );
        insert newSurvey;

        Survey_Question__c q = new Survey_Question__c(
            Survey__c = newSurvey.Id,
            Question_Text__c = 'Test question',
            Question_Type__c = 'Text',
            Sort_Order__c = 1
        );
        insert q;

        Account acc = [SELECT Id FROM Account WHERE Name = 'Survey Outlet' LIMIT 1];
        Survey_Response__c resp = new Survey_Response__c(
            Survey__c = newSurvey.Id,
            Account__c = acc.Id,
            Response_Date__c = Date.today(),
            Status__c = 'Completed'
        );
        insert resp;

        Test.startTest();
        Map<String, Object> stats = SurveyManagerController.getStats();
        Test.stopTest();

        System.assertEquals(3, (Integer) stats.get('totalSurveys'), 'Should now have 3 surveys');
        System.assertEquals(2, (Integer) stats.get('activeSurveys'), 'Should now have 2 active surveys');
        System.assertEquals(4, (Integer) stats.get('totalQuestions'), 'Should now have 4 questions');
        System.assertEquals(2, (Integer) stats.get('totalResponses'), 'Should now have 2 responses');
    }

    // ── saveSurvey with effective dates ──────────────────────────────────────

    @IsTest
    static void testSaveSurveyWithEffectiveDates() {
        Survey__c survey = new Survey__c(
            Name = 'Dated Survey',
            Survey_Code__c = 'SRV-DATE',
            Survey_Type__c = 'Shelf Audit',
            Is_Active__c = true,
            Effective_From__c = Date.today(),
            Effective_To__c = Date.today().addDays(60)
        );

        Test.startTest();
        Survey__c result = SurveyManagerController.saveSurvey(survey);
        Test.stopTest();

        System.assertEquals(Date.today(), result.Effective_From__c, 'From date should match');
        System.assertEquals(Date.today().addDays(60), result.Effective_To__c, 'To date should match');
    }

    // ── saveQuestion with validation rule and options ─────────────────────────

    @IsTest
    static void testSaveQuestionWithOptionsAndValidation() {
        Survey__c survey = getActiveSurvey();

        Survey_Question__c question = new Survey_Question__c(
            Survey__c = survey.Id,
            Question_Text__c = 'Select your region',
            Question_Type__c = 'Multi Choice',
            Options__c = 'North;South;East;West',
            Is_Required__c = true,
            Sort_Order__c = 5,
            Validation_Rule__c = 'required'
        );

        Test.startTest();
        Survey_Question__c result = SurveyManagerController.saveQuestion(question);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Question should be saved');
        System.assertEquals('North;South;East;West', result.Options__c, 'Options should match');
        System.assertEquals('required', result.Validation_Rule__c, 'Validation rule should match');
    }
}
