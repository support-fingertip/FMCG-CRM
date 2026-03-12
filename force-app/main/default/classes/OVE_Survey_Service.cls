/**
 * @description Service class for Survey / Feedback during outlet visits.
 *              Handles survey applicability, question retrieval, response
 *              submission, and duplicate-check logic.
 *
 * @author  SFA Development Team
 * @date    2026
 */
public without sharing class OVE_Survey_Service {

    // ── Feature Codes ───────────────────────────────────────────────────────
    public static final String FEATURE_SURVEY = 'OVE-005';

    // ── Survey Applicability ────────────────────────────────────────────────

    /**
     * @description Returns active surveys whose date range covers today.
     *              Optionally filters by Outlet_Type__c matching the account.
     * @param accountId The outlet Account Id (used for Outlet_Type matching).
     * @return List of applicable Survey__c records.
     */
    public static List<Survey__c> getApplicableSurveys(Id accountId) {
        if (!BPM_FeatureToggle_Util.isEnabled(FEATURE_SURVEY)) {
            throw new AuraHandledException('Survey feature is currently disabled.');
        }

        Date today = Date.today();

        // Determine outlet type from the account for filtering
        String outletType = null;
        if (accountId != null) {
            List<Account> accounts = [
                SELECT Id, Type FROM Account WHERE Id = :accountId LIMIT 1
            ];
            if (!accounts.isEmpty()) {
                outletType = accounts[0].Type;
            }
        }

        String query = 'SELECT Id, Name, Survey_Code__c, Survey_Type__c, Description__c, ' +
                       'Outlet_Type__c, Effective_From__c, Effective_To__c, Is_Mandatory__c ' +
                       'FROM Survey__c ' +
                       'WHERE Is_Active__c = true ' +
                       'AND (Effective_From__c = null OR Effective_From__c <= :today) ' +
                       'AND (Effective_To__c = null OR Effective_To__c >= :today)';

        if (String.isNotBlank(outletType)) {
            query += ' AND (Outlet_Type__c = null OR Outlet_Type__c = :outletType)';
        }

        query += ' ORDER BY Name ASC';

        return Database.query(query);
    }

    // ── Survey With Questions ───────────────────────────────────────────────

    /**
     * @description Returns survey details along with ordered questions.
     * @param surveyId The Survey__c Id.
     * @return Map containing 'survey' (Survey__c) and 'questions' (List of Survey_Question__c).
     */
    public static Map<String, Object> getSurveyWithQuestions(Id surveyId) {
        if (!BPM_FeatureToggle_Util.isEnabled(FEATURE_SURVEY)) {
            throw new AuraHandledException('Survey feature is currently disabled.');
        }

        Map<String, Object> result = new Map<String, Object>();

        List<Survey__c> surveys = [
            SELECT Id, Name, Survey_Code__c, Survey_Type__c, Description__c,
                   Outlet_Type__c, Effective_From__c, Effective_To__c, Is_Mandatory__c
            FROM Survey__c
            WHERE Id = :surveyId
            LIMIT 1
        ];

        if (surveys.isEmpty()) {
            throw new AuraHandledException('Survey not found.');
        }

        result.put('survey', surveys[0]);

        List<Survey_Question__c> questions = [
            SELECT Id, Name, Question_Text__c, Question_Type__c, Options__c,
                   Sort_Order__c, Is_Required__c, Validation_Rule__c, Survey__c
            FROM Survey_Question__c
            WHERE Survey__c = :surveyId
            ORDER BY Sort_Order__c ASC NULLS LAST
        ];

        result.put('questions', questions);

        return result;
    }

    // ── Submit Survey Response ──────────────────────────────────────────────

    /**
     * @description Inner class for deserialising individual answer entries.
     */
    public class SurveyAnswerInput {
        public Id      questionId;
        public String  answerText;
        public String  answerChoice;
        public Decimal answerNumber;
        public Decimal ratingValue;
        public String  photoURL;
    }

    /**
     * @description Inner class for deserialising the full response payload.
     */
    public class SurveyResponseInput {
        public Id                     visitId;
        public Id                     accountId;
        public Id                     surveyId;
        public List<SurveyAnswerInput> answers;
    }

    /**
     * @description Creates a Survey_Response__c with child Survey_Answer__c records
     *              and marks the visit's Survey_Completed__c flag.
     * @param responseJson JSON string matching SurveyResponseInput structure.
     * @return The created Survey_Response__c record.
     */
    public static Survey_Response__c submitSurveyResponse(String responseJson) {
        if (!BPM_FeatureToggle_Util.isEnabled(FEATURE_SURVEY)) {
            throw new AuraHandledException('Survey feature is currently disabled.');
        }

        SurveyResponseInput input = (SurveyResponseInput)
            JSON.deserialize(responseJson, SurveyResponseInput.class);

        if (input.surveyId == null || input.visitId == null) {
            throw new AuraHandledException('Survey Id and Visit Id are required.');
        }

        // Check for duplicate submission
        List<Survey_Response__c> existing = [
            SELECT Id FROM Survey_Response__c
            WHERE Visit__c = :input.visitId
              AND Survey__c = :input.surveyId
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            throw new AuraHandledException('A response for this survey has already been submitted for this visit.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            // Create response header
            Survey_Response__c response = new Survey_Response__c();
            response.Visit__c        = input.visitId;
            response.Account__c      = input.accountId;
            response.Survey__c       = input.surveyId;
            response.Respondent__c   = UserInfo.getUserId();
            response.Response_Date__c = Date.today();
            response.Status__c       = 'Completed';
            insert response;

            // Create answer records
            if (input.answers != null && !input.answers.isEmpty()) {
                List<Survey_Answer__c> answers = new List<Survey_Answer__c>();
                for (SurveyAnswerInput ans : input.answers) {
                    Survey_Answer__c a = new Survey_Answer__c();
                    a.Survey_Response__c = response.Id;
                    a.Survey_Question__c = ans.questionId;
                    a.Answer_Text__c     = ans.answerText;
                    a.Answer_Choice__c   = ans.answerChoice;
                    a.Answer_Number__c   = ans.answerNumber;
                    a.Rating_Value__c    = ans.ratingValue;
                    a.Photo_URL__c       = ans.photoURL;
                    answers.add(a);
                }
                insert answers;
            }

            // Mark visit as survey completed
            Visit__c visit = new Visit__c(Id = input.visitId);
            visit.Survey_Completed__c = true;
            update visit;

            return response;
        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Failed to submit survey response: ' + e.getMessage());
        }
    }

    // ── Existing Response Check ─────────────────────────────────────────────

    /**
     * @description Checks whether a survey response already exists for the
     *              given visit and survey combination.
     * @param visitId  The Visit__c Id.
     * @param surveyId The Survey__c Id.
     * @return The existing Survey_Response__c record, or null if none exists.
     */
    public static Survey_Response__c getExistingSurveyResponse(Id visitId, Id surveyId) {
        List<Survey_Response__c> responses = [
            SELECT Id, Name, Survey__c, Visit__c, Account__c,
                   Respondent__c, Response_Date__c, Status__c, Total_Score__c
            FROM Survey_Response__c
            WHERE Visit__c = :visitId
              AND Survey__c = :surveyId
            LIMIT 1
        ];
        return responses.isEmpty() ? null : responses[0];
    }
}
