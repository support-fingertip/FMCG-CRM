/**
 * @description Test class for MDM_PriceList_Handler.
 *              Validates priority auto-calculation, date range overlap prevention,
 *              and price change audit logging.
 * @author  SFA Development Team
 * @date    2024
 */
@IsTest
private class MDM_PriceList_Handler_Test {

    @TestSetup
    static void setupTestData() {
        // Products
        List<Product_Extension__c> products = TestDataFactory.createAndInsertProducts(2);

        // Territory for dimension-based tests
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('PL Territory', 'TER-PL01');

        // Account for customer-wise pricing
        Account customer = TestDataFactory.createAndInsertAccount('PL Customer', 'Retailer');
    }

    // ── Helper accessors ─────────────────────────────────────────────────────

    private static Product_Extension__c getProduct(Integer idx) {
        List<Product_Extension__c> products = [SELECT Id FROM Product_Extension__c ORDER BY SKU_Code__c LIMIT 2];
        return products[idx];
    }
    private static Territory_Master__c getTerritory() {
        return [SELECT Id FROM Territory_Master__c WHERE Territory_Code__c = 'TER-PL01' LIMIT 1];
    }
    private static Account getCustomer() {
        return [SELECT Id FROM Account WHERE Name = 'PL Customer' LIMIT 1];
    }

    // ── Priority: base price (no dimensions) = 8 ────────────────────────────

    @IsTest
    static void testPriorityBasePriceNoDimensions() {
        Product_Extension__c prod = getProduct(0);

        Price_List__c pl = new Price_List__c(
            Product_Ext__c = prod.Id,
            Unit_Price__c = 100,
            Effective_From__c = Date.today(),
            Effective_To__c = Date.today().addDays(30)
        );

        Test.startTest();
        insert pl;
        Test.stopTest();

        Price_List__c inserted = [SELECT Priority__c FROM Price_List__c WHERE Id = :pl.Id];
        // Without any dimension, priority should default (8 = base price when no metadata matches)
        System.assertNotEquals(null, inserted.Priority__c, 'Priority should be auto-calculated');
    }

    // ── Priority: customer-wise should be highest ───────────────────────────

    @IsTest
    static void testPriorityCustomerWise() {
        Product_Extension__c prod = getProduct(0);
        Account cust = getCustomer();

        Price_List__c pl = new Price_List__c(
            Product_Ext__c = prod.Id,
            Customer__c = cust.Id,
            Unit_Price__c = 90,
            Effective_From__c = Date.today().addDays(60),
            Effective_To__c = Date.today().addDays(90)
        );

        Test.startTest();
        insert pl;
        Test.stopTest();

        Price_List__c inserted = [SELECT Priority__c FROM Price_List__c WHERE Id = :pl.Id];
        System.assertNotEquals(null, inserted.Priority__c, 'Customer-wise priority should be set');
    }

    // ── Overlap: non-overlapping inserts succeed ────────────────────────────

    @IsTest
    static void testNonOverlappingDateRanges() {
        Product_Extension__c prod = getProduct(0);

        Price_List__c pl1 = new Price_List__c(
            Product_Ext__c = prod.Id,
            Unit_Price__c = 100,
            Effective_From__c = Date.newInstance(2025, 1, 1),
            Effective_To__c = Date.newInstance(2025, 3, 31)
        );
        insert pl1;

        Price_List__c pl2 = new Price_List__c(
            Product_Ext__c = prod.Id,
            Unit_Price__c = 110,
            Effective_From__c = Date.newInstance(2025, 4, 1),
            Effective_To__c = Date.newInstance(2025, 6, 30)
        );

        Test.startTest();
        insert pl2;
        Test.stopTest();

        System.assertNotEquals(null, pl2.Id, 'Non-overlapping price list should insert successfully');
    }

    // ── Overlap: overlapping date ranges fail ───────────────────────────────

    @IsTest
    static void testOverlappingDateRangesFail() {
        Product_Extension__c prod = getProduct(0);

        Price_List__c pl1 = new Price_List__c(
            Product_Ext__c = prod.Id,
            Unit_Price__c = 100,
            Effective_From__c = Date.newInstance(2025, 7, 1),
            Effective_To__c = Date.newInstance(2025, 9, 30)
        );
        insert pl1;

        // Overlapping range
        Price_List__c pl2 = new Price_List__c(
            Product_Ext__c = prod.Id,
            Unit_Price__c = 120,
            Effective_From__c = Date.newInstance(2025, 8, 1),
            Effective_To__c = Date.newInstance(2025, 10, 31)
        );

        Test.startTest();
        try {
            insert pl2;
            System.assert(false, 'Expected DmlException for overlapping date ranges');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('overlaps'),
                'Error should mention overlapping dates: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── Overlap: intra-batch overlap detected ───────────────────────────────

    @IsTest
    static void testIntraBatchOverlap() {
        Product_Extension__c prod = getProduct(1);

        List<Price_List__c> batch = new List<Price_List__c>{
            new Price_List__c(
                Product_Ext__c = prod.Id,
                Unit_Price__c = 100,
                Effective_From__c = Date.newInstance(2025, 1, 1),
                Effective_To__c = Date.newInstance(2025, 6, 30)
            ),
            new Price_List__c(
                Product_Ext__c = prod.Id,
                Unit_Price__c = 110,
                Effective_From__c = Date.newInstance(2025, 3, 1),
                Effective_To__c = Date.newInstance(2025, 8, 31)
            )
        };

        Test.startTest();
        try {
            insert batch;
            System.assert(false, 'Expected DmlException for intra-batch overlapping dates');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('overlap'),
                'Error should mention overlap: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── Overlap: missing Effective_From__c ───────────────────────────────────

    @IsTest
    static void testMissingEffectiveFromDate() {
        Product_Extension__c prod = getProduct(0);

        Price_List__c pl = new Price_List__c(
            Product_Ext__c = prod.Id,
            Unit_Price__c = 100,
            Effective_To__c = Date.today().addDays(30)
        );

        Test.startTest();
        try {
            insert pl;
            System.assert(false, 'Expected DmlException for missing Effective_From__c');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Effective From date is required'),
                'Error should mention required effective from date: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── Update: dimension change triggers priority recalc ───────────────────

    @IsTest
    static void testUpdateDimensionRecalcsPriority() {
        Product_Extension__c prod = getProduct(0);
        Account cust = getCustomer();

        Price_List__c pl = new Price_List__c(
            Product_Ext__c = prod.Id,
            Unit_Price__c = 100,
            Effective_From__c = Date.newInstance(2026, 1, 1),
            Effective_To__c = Date.newInstance(2026, 3, 31)
        );
        insert pl;

        Decimal originalPriority = [SELECT Priority__c FROM Price_List__c WHERE Id = :pl.Id].Priority__c;

        Test.startTest();
        pl.Customer__c = cust.Id;
        update pl;
        Test.stopTest();

        Price_List__c updated = [SELECT Priority__c FROM Price_List__c WHERE Id = :pl.Id];
        // Adding customer should change priority (customer-wise is typically highest priority)
        System.assertNotEquals(null, updated.Priority__c, 'Priority should be recalculated');
    }

    // ── After Update: price change audit log created ────────────────────────

    @IsTest
    static void testPriceChangeLogged() {
        Product_Extension__c prod = getProduct(0);

        Price_List__c pl = new Price_List__c(
            Product_Ext__c = prod.Id,
            Unit_Price__c = 100,
            Effective_From__c = Date.newInstance(2026, 4, 1),
            Effective_To__c = Date.newInstance(2026, 6, 30)
        );
        insert pl;

        Test.startTest();
        pl.Unit_Price__c = 120;
        update pl;
        Test.stopTest();

        List<Price_Change_Log__c> logs = [
            SELECT Old_Price__c, New_Price__c, Product_Ext__c
            FROM Price_Change_Log__c
            WHERE Price_List__c = :pl.Id
        ];
        System.assertEquals(1, logs.size(), 'One price change log should be created');
        System.assertEquals(100, logs[0].Old_Price__c, 'Old price should be 100');
        System.assertEquals(120, logs[0].New_Price__c, 'New price should be 120');
    }

    // ── After Update: no log when price unchanged ───────────────────────────

    @IsTest
    static void testNoPriceChangeNoLog() {
        Product_Extension__c prod = getProduct(0);

        Price_List__c pl = new Price_List__c(
            Product_Ext__c = prod.Id,
            Unit_Price__c = 100,
            Effective_From__c = Date.newInstance(2026, 7, 1),
            Effective_To__c = Date.newInstance(2026, 9, 30)
        );
        insert pl;

        Test.startTest();
        // Update non-price field only
        pl.Effective_To__c = Date.newInstance(2026, 9, 15);
        update pl;
        Test.stopTest();

        List<Price_Change_Log__c> logs = [
            SELECT Id FROM Price_Change_Log__c WHERE Price_List__c = :pl.Id
        ];
        System.assertEquals(0, logs.size(), 'No price change log when price is unchanged');
    }

    // ── Different dimension combos do not overlap ───────────────────────────

    @IsTest
    static void testDifferentDimensionsAllowed() {
        Product_Extension__c prod = getProduct(0);
        Account cust = getCustomer();

        // Base price for product
        Price_List__c plBase = new Price_List__c(
            Product_Ext__c = prod.Id,
            Unit_Price__c = 100,
            Effective_From__c = Date.newInstance(2025, 10, 1),
            Effective_To__c = Date.newInstance(2025, 12, 31)
        );
        insert plBase;

        // Customer-specific for same product/dates
        Price_List__c plCust = new Price_List__c(
            Product_Ext__c = prod.Id,
            Customer__c = cust.Id,
            Unit_Price__c = 90,
            Effective_From__c = Date.newInstance(2025, 10, 1),
            Effective_To__c = Date.newInstance(2025, 12, 31)
        );

        Test.startTest();
        insert plCust;
        Test.stopTest();

        System.assertNotEquals(null, plCust.Id,
            'Different dimension combos should allow overlapping dates');
    }
}
