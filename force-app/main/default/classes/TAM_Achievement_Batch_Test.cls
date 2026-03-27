/**
 * @description Test class for TAM_Achievement_Batch.
 *              Validates batch execution for achievement calculation.
 */
@isTest
private class TAM_Achievement_Batch_Test {

    @testSetup
    static void setupTestData() {
        // Create Target Criteria pointing to Account with COUNT of Id
        Target_Criteria__c criteria = new Target_Criteria__c(
            Name = 'Account Count Criteria',
            Object__c = 'Account',
            Operator__c = 'COUNT',
            Field__c = 'Id',
            Date_Field__c = 'CreatedDate',
            User_Field__c = 'OwnerId',
            Active__c = true
        );
        insert criteria;

        // Create Target Period covering today
        Target_Period__c period = new Target_Period__c(
            Name = 'Current Month',
            Start_Date__c = Date.today().addDays(-15),
            End_Date__c = Date.today().addDays(15),
            Is_Active__c = true,
            Type__c = 'Monthly'
        );
        insert period;

        // Create Target Actual linked to criteria and period
        Target_Actual__c ta = new Target_Actual__c(
            User__c = UserInfo.getUserId(),
            Target_Criteria__c = criteria.Id,
            Target_Period__c = period.Id,
            Target_Value__c = 50,
            Achievement_Value__c = 0
        );
        insert ta;

        // Create some Account records owned by the running user so COUNT yields results
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(
                Name = 'Batch Test Account ' + i,
                OwnerId = UserInfo.getUserId()
            ));
        }
        insert accounts;
    }

    /**
     * @description Executes the batch and verifies it completes without error.
     *              The Achievement_Value__c should be updated based on Account COUNT.
     */
    @isTest
    static void testBatchExecution() {
        Test.startTest();
        Id batchId = Database.executeBatch(new TAM_Achievement_Batch(), 200);
        Test.stopTest();

        // Verify the batch job completed
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :batchId
        ];
        System.assertEquals('Completed', job.Status,
            'Batch should complete successfully');
        System.assertEquals(0, job.NumberOfErrors,
            'Batch should have zero errors');

        // Verify achievement was updated
        Target_Actual__c ta = [
            SELECT Id, Achievement_Value__c, Last_Updated__c
            FROM Target_Actual__c
            LIMIT 1
        ];
        System.assertNotEquals(null, ta.Last_Updated__c,
            'Last_Updated__c should be stamped after batch execution');
        System.assertNotEquals(null, ta.Achievement_Value__c,
            'Achievement_Value__c should be populated after batch run');
    }

    /**
     * @description When no Target_Actual__c records match the active period query,
     *              the batch should complete without error.
     */
    @isTest
    static void testBatchEmptyScope() {
        // Delete all Target_Actual__c so start() returns empty scope
        delete [SELECT Id FROM Target_Actual__c];

        Test.startTest();
        Id batchId = Database.executeBatch(new TAM_Achievement_Batch(), 200);
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :batchId
        ];
        System.assertEquals('Completed', job.Status,
            'Batch should complete even with no records');
        System.assertEquals(0, job.NumberOfErrors,
            'Batch should have zero errors with empty scope');
    }
}
