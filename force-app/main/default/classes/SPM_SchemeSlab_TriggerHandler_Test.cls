@isTest
private class SPM_SchemeSlab_TriggerHandler_Test {

    @TestSetup
    static void setupTestData() {
        Scheme__c scheme = TestDataFactory.createScheme('Slab Scheme', 'SCH-SLAB-001', 'Discount in %', 'Same Product (QTY)');
        scheme.Budget_Amount__c = 50000;
        insert scheme;
    }

    @isTest
    static void testValidSlabInsert() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c LIMIT 1];

        Scheme_Slab__c slab = new Scheme_Slab__c(
            Scheme__c = scheme.Id,
            Slab_Type__c = 'Quantity',
            Min_Quantity__c = 1,
            Max_Quantity__c = 10,
            Discount_Percent__c = 5,
            Is_Active__c = true
        );

        Test.startTest();
        insert slab;
        Test.stopTest();

        System.assertNotEquals(null, slab.Id);
    }

    @isTest
    static void testInvalidSlabRange() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c LIMIT 1];

        Scheme_Slab__c slab = new Scheme_Slab__c(
            Scheme__c = scheme.Id,
            Slab_Type__c = 'Quantity',
            Min_Quantity__c = 100,
            Max_Quantity__c = 10,
            Is_Active__c = true
        );

        Test.startTest();
        try {
            insert slab;
            System.assert(false, 'Should have thrown error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Max Quantity'));
        }
        Test.stopTest();
    }

    @isTest
    static void testSlabUpdate() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c LIMIT 1];

        Scheme_Slab__c slab = new Scheme_Slab__c(
            Scheme__c = scheme.Id,
            Slab_Type__c = 'Quantity',
            Min_Quantity__c = 1,
            Max_Quantity__c = 50,
            Discount_Percent__c = 10,
            Is_Active__c = true
        );
        insert slab;

        slab.Discount_Percent__c = 15;
        Test.startTest();
        update slab;
        Test.stopTest();

        Scheme_Slab__c updated = [SELECT Discount_Percent__c FROM Scheme_Slab__c WHERE Id = :slab.Id];
        System.assertEquals(15, updated.Discount_Percent__c);
    }
}
