@isTest
private class MDM_ProductExtension_TriggerHandler_Test {

    @isTest
    static void testDeactivateProductWithActiveScheme() {
        Product_Extension__c prod = TestDataFactory.createProduct('Active Product', 'AP-001');
        insert prod;

        Scheme__c scheme = TestDataFactory.createScheme('Active Scheme', 'SCH-001', 'Discount in %', 'Same Product (QTY)');
        scheme.Budget_Amount__c = 10000;
        insert scheme;

        Scheme_Product__c sp = new Scheme_Product__c(
            Scheme__c = scheme.Id,
            Product_Ext__c = prod.Id,
            Is_Buy_Product__c = true
        );
        insert sp;

        prod.Is_Active__c = false;
        Test.startTest();
        try {
            update prod;
            System.assert(false, 'Should have thrown error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('active schemes'));
        }
        Test.stopTest();
    }

    @isTest
    static void testDeactivateProductWithoutReferences() {
        Product_Extension__c prod = TestDataFactory.createProduct('Safe Product', 'SP-001');
        insert prod;

        prod.Is_Active__c = false;
        Test.startTest();
        update prod;
        Test.stopTest();

        Product_Extension__c updated = [SELECT Is_Active__c FROM Product_Extension__c WHERE Id = :prod.Id];
        System.assertEquals(false, updated.Is_Active__c);
    }
}
