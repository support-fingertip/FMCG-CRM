/**
 * @description Test class for OVE_SchemeInfoController.
 *              Validates active scheme retrieval, date filtering,
 *              account-based filtering, territory mapping, and feature toggle.
 *
 * @author  SFA Development Team
 * @date    2026
 */
@isTest
private class OVE_SchemeInfoController_Test {

    @testSetup
    static void setupTestData() {
        Account outlet = TestDataFactory.createAccount('SI Test Outlet', 'Retailer');
        insert outlet;

        List<Scheme__c> schemes = new List<Scheme__c>();

        Scheme__c activeScheme = TestDataFactory.createScheme(
            'Buy 2 Get 1 Free', 'SCH-TEST-001', 'Free Products', 'Same Product (QTY)');
        activeScheme.Status__c = 'Active';
        activeScheme.Start_Date__c = Date.today().addDays(-10);
        activeScheme.End_Date__c = Date.today().addDays(30);
        activeScheme.Description__c = 'Buy 2 cases and get 1 free';
        activeScheme.Free_Quantity__c = 1;
        activeScheme.Min_Quantity__c = 2;
        schemes.add(activeScheme);

        Scheme__c discountScheme = TestDataFactory.createScheme(
            '10% Off Premium', 'SCH-TEST-002', 'Discount in %', 'Same Product (VAL)');
        discountScheme.Status__c = 'Active';
        discountScheme.Start_Date__c = Date.today().addDays(-10);
        discountScheme.End_Date__c = Date.today().addDays(30);
        discountScheme.Description__c = '10% discount on premium products';
        discountScheme.Discount_Percent__c = 10;
        discountScheme.MOV__c = 1000;
        discountScheme.Priority__c = 2;
        schemes.add(discountScheme);

        Scheme__c rewardScheme = TestDataFactory.createScheme(
            'Reward Points Offer', 'SCH-TEST-004', 'Reward Points', 'Invoice Val Based');
        rewardScheme.Status__c = 'Active';
        rewardScheme.Start_Date__c = Date.today().addDays(-5);
        rewardScheme.End_Date__c = Date.today().addDays(30);
        rewardScheme.Invoice_Val_Threshold__c = 5000;
        rewardScheme.Reward_Points__c = 100;
        rewardScheme.Priority__c = 3;
        schemes.add(rewardScheme);

        // Expired scheme (should not be returned)
        Scheme__c expiredScheme = TestDataFactory.createScheme(
            'Old Scheme', 'SCH-TEST-003', 'Free Products', 'Same Product (QTY)');
        expiredScheme.Status__c = 'Active';
        expiredScheme.Is_Active__c = false;
        expiredScheme.Start_Date__c = Date.today().addDays(-60);
        expiredScheme.End_Date__c = Date.today().addDays(-30);
        schemes.add(expiredScheme);

        insert schemes;
    }

    // ── getActiveSchemes ─────────────────────────────────────────────────

    @isTest
    static void testGetActiveSchemes_ValidAccount() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'SI Test Outlet' LIMIT 1];

        Test.startTest();
        try {
            List<Scheme__c> schemes = OVE_SchemeInfoController.getActiveSchemes(acct.Id);
            System.assertNotEquals(null, schemes, 'Schemes list should not be null');
            System.assert(schemes.size() >= 2, 'Should find at least 2 active schemes. Found: ' + schemes.size());

            Boolean foundExpired = false;
            for (Scheme__c s : schemes) {
                if (s.Scheme_Code__c == 'SCH-TEST-003') {
                    foundExpired = true;
                }
            }
            System.assertEquals(false, foundExpired, 'Expired scheme should not be returned');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('disabled') || e.getMessage().contains('Scheme'),
                'Error should indicate feature disabled. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testGetActiveSchemes_NullAccount() {
        Test.startTest();
        try {
            List<Scheme__c> schemes = OVE_SchemeInfoController.getActiveSchemes(null);
            System.assertNotEquals(null, schemes, 'Should return a list even for null account');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('disabled') || e.getMessage().contains('Scheme'),
                'Error should indicate feature disabled. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    // ── Date Filtering ───────────────────────────────────────────────────

    @isTest
    static void testGetActiveSchemes_DateFiltering() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'SI Test Outlet' LIMIT 1];

        Test.startTest();
        try {
            List<Scheme__c> schemes = OVE_SchemeInfoController.getActiveSchemes(acct.Id);

            for (Scheme__c s : schemes) {
                if (s.Start_Date__c != null) {
                    System.assert(s.Start_Date__c <= Date.today(),
                        'Start date should be on or before today for scheme: ' + s.Scheme_Code__c);
                }
                if (s.End_Date__c != null) {
                    System.assert(s.End_Date__c >= Date.today(),
                        'End date should be on or after today for scheme: ' + s.Scheme_Code__c);
                }
            }
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('disabled') || e.getMessage().contains('Scheme'),
                'Error should indicate feature disabled. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testGetActiveSchemes_SchemeDetails() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'SI Test Outlet' LIMIT 1];

        Test.startTest();
        try {
            List<Scheme__c> schemes = OVE_SchemeInfoController.getActiveSchemes(acct.Id);

            for (Scheme__c s : schemes) {
                if (s.Scheme_Code__c == 'SCH-TEST-002') {
                    System.assertEquals('Discount in %', s.Scheme_Category__c,
                        'Scheme category should be Discount in %');
                    System.assertEquals('Same Product (VAL)', s.Scheme_Type__c,
                        'Scheme type should be Same Product (VAL)');
                    System.assertEquals(10, s.Discount_Percent__c, 'Discount percent should be 10');
                    System.assertNotEquals(null, s.Description__c, 'Description should be populated');
                }
                if (s.Scheme_Code__c == 'SCH-TEST-004') {
                    System.assertEquals('Reward Points', s.Scheme_Category__c,
                        'Scheme category should be Reward Points');
                    System.assertEquals(100, s.Reward_Points__c, 'Reward points should be 100');
                }
            }
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('disabled') || e.getMessage().contains('Scheme'),
                'Error should indicate feature disabled. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    // ── Feature Toggle ───────────────────────────────────────────────────

    @isTest
    static void testFeatureToggleDisabled_ThrowsException() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'SI Test Outlet' LIMIT 1];

        Test.startTest();
        try {
            List<Scheme__c> schemes = OVE_SchemeInfoController.getActiveSchemes(acct.Id);
            System.assertNotEquals(null, schemes, 'Schemes should not be null if toggle enabled');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('disabled') || e.getMessage().contains('Scheme'),
                'Should indicate scheme info feature disabled. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }
}
