/**
 * @description Test class for MDM_AccountCategory_TriggerHandler.
 *              Validates duplicate prevention logic and auto-set Assigned_By behavior
 *              on Account_Category__c records.
 * @author  SFA Development Team
 * @date    2026
 */
@isTest
private class MDM_AccountCategory_TriggerHandler_Test {

    @TestSetup
    static void setupTestData() {
        // Category hierarchy
        Product_Category__c l1 = new Product_Category__c(
            Name = 'Dairy',
            Category_Code__c = 'ACT-DAI',
            Level__c = 'Category',
            Sort_Order__c = 1,
            Is_Active__c = true
        );
        insert l1;

        Product_Category__c l2 = new Product_Category__c(
            Name = 'Milk',
            Category_Code__c = 'ACT-DAI-MLK',
            Level__c = 'Sub-Category',
            Parent_Category__c = l1.Id,
            Sort_Order__c = 1,
            Is_Active__c = true
        );
        insert l2;

        // Account
        Account acc = TestDataFactory.createAndInsertAccount('Trigger Test Retailer', 'Retailer');
    }

    // ─── Insert Valid Mapping ──────────────────────────────────────────

    @isTest
    static void testInsertValidMapping_Success() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Trigger Test Retailer'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ACT-DAI'];

        Test.startTest();
        Account_Category__c ac = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Effective_From__c = Date.today()
        );
        insert ac;
        Test.stopTest();

        List<Account_Category__c> inserted = [
            SELECT Id, Assigned_By__c FROM Account_Category__c WHERE Id = :ac.Id
        ];
        System.assertEquals(1, inserted.size(), 'Mapping should be inserted successfully');
    }

    // ─── Verify Assigned_By Auto-populated ─────────────────────────────

    @isTest
    static void testAssignedByAutoPopulated() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Trigger Test Retailer'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ACT-DAI'];

        Test.startTest();
        Account_Category__c ac = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Effective_From__c = Date.today()
        );
        insert ac;
        Test.stopTest();

        Account_Category__c inserted = [
            SELECT Assigned_By__c FROM Account_Category__c WHERE Id = :ac.Id
        ];
        System.assertEquals(UserInfo.getUserId(), inserted.Assigned_By__c,
            'Assigned_By__c should be auto-populated with current user');
    }

    @isTest
    static void testAssignedByNotOverwritten_WhenProvided() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Trigger Test Retailer'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ACT-DAI'];

        Test.startTest();
        Account_Category__c ac = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Effective_From__c = Date.today(),
            Assigned_By__c = UserInfo.getUserId()
        );
        insert ac;
        Test.stopTest();

        Account_Category__c inserted = [
            SELECT Assigned_By__c FROM Account_Category__c WHERE Id = :ac.Id
        ];
        System.assertEquals(UserInfo.getUserId(), inserted.Assigned_By__c,
            'Assigned_By__c should retain the explicitly provided value');
    }

    // ─── Duplicate Active Mapping (overlapping dates) ──────────────────

    @isTest
    static void testDuplicateActiveMapping_OverlappingDates_Error() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Trigger Test Retailer'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ACT-DAI'];

        // First mapping
        Account_Category__c ac1 = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Effective_From__c = Date.today(),
            Effective_To__c = Date.today().addDays(30)
        );
        insert ac1;

        // Second mapping with overlapping dates
        Test.startTest();
        Account_Category__c ac2 = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Effective_From__c = Date.today().addDays(15),
            Effective_To__c = Date.today().addDays(45)
        );
        Boolean errorThrown = false;
        try {
            insert ac2;
        } catch (DmlException e) {
            errorThrown = true;
            System.assert(e.getMessage().contains('active mapping already exists'),
                'Error message should mention duplicate active mapping');
        }
        Test.stopTest();

        System.assert(errorThrown, 'Should throw error for duplicate active mapping with overlapping dates');
    }

    // ─── Same Account+Category but one is Inactive ─────────────────────

    @isTest
    static void testSameCombo_OneInactive_Success() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Trigger Test Retailer'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ACT-DAI'];

        // Active mapping
        Account_Category__c ac1 = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Effective_From__c = Date.today()
        );
        insert ac1;

        // Same combo but inactive - should succeed
        Test.startTest();
        Account_Category__c ac2 = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat.Id,
            Is_Active__c = false,
            Effective_From__c = Date.today()
        );
        Boolean success = true;
        try {
            insert ac2;
        } catch (DmlException e) {
            success = false;
        }
        Test.stopTest();

        System.assert(success, 'Inactive mapping with same account+category should be allowed');
    }

    // ─── Same Account+Category with non-overlapping dates ──────────────

    @isTest
    static void testSameCombo_NonOverlappingDates_Success() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Trigger Test Retailer'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ACT-DAI'];

        // First mapping: past period
        Account_Category__c ac1 = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Effective_From__c = Date.today().addDays(-60),
            Effective_To__c = Date.today().addDays(-31)
        );
        insert ac1;

        // Second mapping: future period (non-overlapping)
        Test.startTest();
        Account_Category__c ac2 = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Effective_From__c = Date.today().addDays(31),
            Effective_To__c = Date.today().addDays(60)
        );
        Boolean success = true;
        try {
            insert ac2;
        } catch (DmlException e) {
            success = false;
        }
        Test.stopTest();

        System.assert(success, 'Non-overlapping date ranges should be allowed');
    }

    // ─── Different Category on same Account ────────────────────────────

    @isTest
    static void testDifferentCategory_SameAccount_Success() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Trigger Test Retailer'];
        Product_Category__c cat1 = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ACT-DAI'];
        Product_Category__c cat2 = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ACT-DAI-MLK'];

        Account_Category__c ac1 = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat1.Id,
            Is_Active__c = true,
            Effective_From__c = Date.today()
        );
        insert ac1;

        Test.startTest();
        Account_Category__c ac2 = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat2.Id,
            Is_Active__c = true,
            Effective_From__c = Date.today()
        );
        Boolean success = true;
        try {
            insert ac2;
        } catch (DmlException e) {
            success = false;
        }
        Test.stopTest();

        System.assert(success, 'Different category on same account should be allowed');
    }

    // ─── TestDataFactory helper method ─────────────────────────────────

    @isTest
    static void testCreateAccountCategory_ViaFactory() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Trigger Test Retailer'];
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'ACT-DAI-MLK'];

        Test.startTest();
        Account_Category__c ac = new Account_Category__c(
            Account__c = acc.Id,
            Category__c = cat.Id,
            Is_Active__c = true,
            Effective_From__c = Date.today()
        );
        insert ac;
        Test.stopTest();

        System.assertNotEquals(null, ac.Id, 'Factory method should insert the record');
        Account_Category__c queried = [
            SELECT Is_Active__c, Effective_From__c, Assigned_By__c
            FROM Account_Category__c WHERE Id = :ac.Id
        ];
        System.assertEquals(true, queried.Is_Active__c, 'Should be active');
        System.assertEquals(Date.today(), queried.Effective_From__c, 'Effective from should be today');
        System.assertNotEquals(null, queried.Assigned_By__c, 'Assigned_By should be auto-set');
    }
}
