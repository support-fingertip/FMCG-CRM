@isTest
private class SPM_MustSellConfig_TriggerHandler_Test {

    @TestSetup
    static void setupData() {
        Product_Category__c cat = new Product_Category__c(
            Name = 'Test Category',
            Category_Code__c = 'TC001',
            Level__c = 'L1',
            Is_Active__c = true
        );
        insert cat;

        Product_Extension__c prod = new Product_Extension__c(
            Name = 'Test Product',
            SKU_Code__c = 'SKU001',
            Product_Category__c = cat.Id,
            Is_Active__c = true
        );
        insert prod;
    }

    @isTest
    static void testValidDateRange() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c LIMIT 1];

        Must_Sell_Config__c config = new Must_Sell_Config__c(
            Product_Ext__c = prod.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(30),
            Is_Active__c = true,
            Min_Qty__c = 1
        );

        Test.startTest();
        insert config;
        Test.stopTest();

        System.assertNotEquals(null, config.Id, 'Config should be inserted successfully');
    }

    @isTest
    static void testInvalidDateRange() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c LIMIT 1];

        Must_Sell_Config__c config = new Must_Sell_Config__c(
            Product_Ext__c = prod.Id,
            Start_Date__c = Date.today().addDays(30),
            End_Date__c = Date.today(),
            Is_Active__c = true,
            Min_Qty__c = 1
        );

        Test.startTest();
        try {
            insert config;
            System.assert(false, 'Should have thrown validation error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('End Date'), 'Error should mention End Date');
        }
        Test.stopTest();
    }

    @isTest
    static void testDuplicatePrevention() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c LIMIT 1];

        Must_Sell_Config__c config1 = new Must_Sell_Config__c(
            Product_Ext__c = prod.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(30),
            Is_Active__c = true,
            Min_Qty__c = 1,
            Channel__c = 'GT'
        );
        insert config1;

        Must_Sell_Config__c config2 = new Must_Sell_Config__c(
            Product_Ext__c = prod.Id,
            Start_Date__c = Date.today().addDays(15),
            End_Date__c = Date.today().addDays(45),
            Is_Active__c = true,
            Min_Qty__c = 2,
            Channel__c = 'GT'
        );

        Test.startTest();
        try {
            insert config2;
            System.assert(false, 'Should have thrown duplicate error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('active Priority Sell'), 'Error should mention duplicate config');
        }
        Test.stopTest();
    }

    @isTest
    static void testNonOverlappingDatesAllowed() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c LIMIT 1];

        Must_Sell_Config__c config1 = new Must_Sell_Config__c(
            Product_Ext__c = prod.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(10),
            Is_Active__c = true,
            Min_Qty__c = 1,
            Channel__c = 'GT'
        );
        insert config1;

        Must_Sell_Config__c config2 = new Must_Sell_Config__c(
            Product_Ext__c = prod.Id,
            Start_Date__c = Date.today().addDays(11),
            End_Date__c = Date.today().addDays(30),
            Is_Active__c = true,
            Min_Qty__c = 2,
            Channel__c = 'GT'
        );

        Test.startTest();
        insert config2;
        Test.stopTest();

        System.assertNotEquals(null, config2.Id, 'Non-overlapping config should be allowed');
    }

    @isTest
    static void testUpdateConfig() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c LIMIT 1];

        Must_Sell_Config__c config = new Must_Sell_Config__c(
            Product_Ext__c = prod.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(30),
            Is_Active__c = true,
            Min_Qty__c = 1
        );
        insert config;

        Test.startTest();
        config.Min_Qty__c = 5;
        update config;
        Test.stopTest();

        Must_Sell_Config__c updated = [SELECT Min_Qty__c FROM Must_Sell_Config__c WHERE Id = :config.Id];
        System.assertEquals(5, updated.Min_Qty__c, 'Min quantity should be updated');
    }
}
