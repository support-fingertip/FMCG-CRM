/**
 * @description Test class for TAM_TargetAllocation_Controller.
 *              Validates target allocation data retrieval and save operations.
 */
@isTest
private class TAM_TargetAllocation_Controller_Test {

    @testSetup
    static void setupTestData() {
        // Create Target Criteria
        Target_Criteria__c criteria = new Target_Criteria__c(
            Name = 'Allocation Test Criteria',
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
            Name = 'Current Allocation Period',
            Start_Date__c = Date.today().addDays(-15),
            End_Date__c = Date.today().addDays(15),
            Is_Active__c = true,
            Type__c = 'Monthly'
        );
        insert period;

        // Create Target Actual for the running user
        Target_Actual__c ta = new Target_Actual__c(
            User__c = UserInfo.getUserId(),
            Target_Criteria__c = criteria.Id,
            Target_Period__c = period.Id,
            Target_Value__c = 100,
            Achievement_Value__c = 25
        );
        insert ta;
    }

    /**
     * @description getAllData should return a non-null DataBox with populated lists.
     */
    @isTest
    static void testGetAllData() {
        Test.startTest();
        TAM_TargetAllocation_Controller.DataBox result = TAM_TargetAllocation_Controller.getAllData();
        Test.stopTest();

        System.assertNotEquals(null, result, 'DataBox should not be null');
        System.assertNotEquals(null, result.periodsList, 'periodsList should not be null');
        System.assertNotEquals(null, result.userList, 'userList should not be null');
        System.assertNotEquals(null, result.targetActuals, 'targetActuals should not be null');
    }

    /**
     * @description getTargetActuals should return records for a valid period.
     */
    @isTest
    static void testGetTargetActuals_WithPeriod() {
        Target_Period__c period = [SELECT Id FROM Target_Period__c LIMIT 1];

        Test.startTest();
        List<Target_Actual__c> result = TAM_TargetAllocation_Controller.getTargetActuals(
            period.Id, UserInfo.getUserId()
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result list should not be null');
        System.assert(result.size() > 0, 'Should return at least one target actual');
    }

    /**
     * @description getTargetActuals should handle null period gracefully.
     */
    @isTest
    static void testGetTargetActuals_NullPeriod() {
        Test.startTest();
        List<Target_Actual__c> result = TAM_TargetAllocation_Controller.getTargetActuals(
            null, UserInfo.getUserId()
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null even with null period');
    }

    /**
     * @description getUserTargets should return a DataBox with criteria list.
     */
    @isTest
    static void testGetUserTargets() {
        Target_Period__c period = [SELECT Id FROM Target_Period__c LIMIT 1];

        Test.startTest();
        TAM_TargetAllocation_Controller.DataBox result = TAM_TargetAllocation_Controller.getUserTargets(
            period.Id, UserInfo.getUserId()
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'DataBox should not be null');
        System.assertNotEquals(null, result.targetCriterias, 'targetCriterias should not be null');
        System.assert(result.targetCriterias.size() > 0,
            'Should return at least one active criteria');
        System.assertNotEquals(null, result.targetActuals, 'targetActuals should not be null');
    }

    /**
     * @description saveTargets should upsert targets from JSON and return updated list.
     */
    @isTest
    static void testSaveTargets() {
        Target_Criteria__c criteria = [SELECT Id FROM Target_Criteria__c LIMIT 1];
        Target_Period__c period = [SELECT Id FROM Target_Period__c LIMIT 1];

        // Build a JSON array of Target_Actual__c records to save
        List<Target_Actual__c> toSave = new List<Target_Actual__c>();
        Target_Actual__c newTa = new Target_Actual__c(
            Target_Criteria__c = criteria.Id,
            Target_Value__c = 250,
            User__c = UserInfo.getUserId()
        );
        toSave.add(newTa);
        String jsonPayload = JSON.serialize(toSave);

        Test.startTest();
        List<Target_Actual__c> result = TAM_TargetAllocation_Controller.saveTargets(
            jsonPayload, period.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Returned list should not be null');
        System.assert(result.size() > 0, 'Should return saved target actuals');
    }

    /**
     * @description saveAdminTargets should perform an admin bulk update with period and user.
     */
    @isTest
    static void testSaveAdminTargets() {
        Target_Criteria__c criteria = [SELECT Id FROM Target_Criteria__c LIMIT 1];
        Target_Period__c period = [SELECT Id FROM Target_Period__c LIMIT 1];
        Id currentUserId = UserInfo.getUserId();

        List<Target_Actual__c> adminTargets = new List<Target_Actual__c>();
        Target_Actual__c adminTa = new Target_Actual__c(
            Target_Criteria__c = criteria.Id,
            Target_Value__c = 500
        );
        adminTargets.add(adminTa);

        Test.startTest();
        List<Target_Actual__c> result = TAM_TargetAllocation_Controller.saveAdminTargets(
            adminTargets, period.Id, period.Id, currentUserId
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Returned list should not be null');

        // Verify the admin target was created with correct period and user
        List<Target_Actual__c> saved = [
            SELECT Id, Target_Value__c, User__c, Target_Period__c
            FROM Target_Actual__c
            WHERE Target_Value__c = 500
        ];
        System.assert(saved.size() > 0, 'Admin target should have been saved');
        System.assertEquals(currentUserId, saved[0].User__c,
            'User should be set to the specified userId');
        System.assertEquals(period.Id, saved[0].Target_Period__c,
            'Period should be set to the admin-selected period');
    }
}
