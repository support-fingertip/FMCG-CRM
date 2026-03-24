@isTest
private class SPM_Scheme_TriggerHandler_Test {

    @TestSetup
    static void setupTestData() {
        Product_Extension__c prod = TestDataFactory.createProduct('Test Product', 'TP-0001');
        insert prod;
    }

    @isTest
    static void testValidDateRanges() {
        Scheme__c scheme = TestDataFactory.createScheme('Valid Scheme', 'SCH-TEST-001', 'Discount in %', 'Same Product (QTY)');
        scheme.Start_Date__c = Date.today();
        scheme.End_Date__c = Date.today().addDays(30);

        Test.startTest();
        insert scheme;
        Test.stopTest();

        System.assertNotEquals(null, scheme.Id, 'Scheme should be created');
    }

    @isTest
    static void testInvalidDateRange() {
        Scheme__c scheme = TestDataFactory.createScheme('Invalid Scheme', 'SCH-TEST-002', 'Discount in %', 'Same Product (QTY)');
        scheme.Start_Date__c = Date.today().addDays(30);
        scheme.End_Date__c = Date.today();

        Test.startTest();
        try {
            insert scheme;
            System.assert(false, 'Should have thrown error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('End Date'), 'Error should mention End Date');
        }
        Test.stopTest();
    }

    @isTest
    static void testInvalidBudget() {
        Scheme__c scheme = TestDataFactory.createScheme('Budget Scheme', 'SCH-TEST-003', 'Discount in %', 'Same Product (QTY)');
        scheme.Budget_Amount__c = -100;

        Test.startTest();
        try {
            insert scheme;
            System.assert(false, 'Should have thrown error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Budget'), 'Error should mention Budget');
        }
        Test.stopTest();
    }

    @isTest
    static void testPreventActiveSchemeTypeChange() {
        Scheme__c scheme = TestDataFactory.createScheme('Active Scheme', 'SCH-TEST-004', 'Discount in %', 'Same Product (QTY)');
        scheme.Status__c = 'Active';
        scheme.Budget_Amount__c = 10000;
        insert scheme;

        scheme.Scheme_Type__c = 'Invoice Val Based';

        Test.startTest();
        try {
            update scheme;
            System.assert(false, 'Should have thrown error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Scheme Type'), 'Error should mention Scheme Type');
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateDatesOnActiveScheme() {
        Scheme__c scheme = TestDataFactory.createScheme('Scheme A', 'SCH-TEST-005', 'Discount in %', 'Same Product (QTY)');
        scheme.Status__c = 'Active';
        scheme.Budget_Amount__c = 50000;
        insert scheme;

        scheme.End_Date__c = Date.today().addDays(60);

        Test.startTest();
        update scheme;
        Test.stopTest();

        Scheme__c updated = [SELECT End_Date__c FROM Scheme__c WHERE Id = :scheme.Id];
        System.assertEquals(Date.today().addDays(60), updated.End_Date__c);
    }
}