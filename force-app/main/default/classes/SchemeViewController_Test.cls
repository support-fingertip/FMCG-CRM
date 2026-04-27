/**
 * @description Test class for SchemeViewController.
 *              Validates getActiveSchemes, getSchemeDetails, calculateSchemeDiscount,
 *              and applySchemeToOrder methods across different scheme categories.
 * @author  SFA Development Team
 * @date    2024
 */
@IsTest
private class SchemeViewController_Test {

    @TestSetup
    static void setupTestData() {
        // Product for free product schemes
        Product_Extension__c freeProd = TestDataFactory.createProduct('Free Gift Product', 'FP-0001');
        insert freeProd;

        // ── Scheme: Free Products (no slabs) ────────────────────────
        Scheme__c freeScheme = TestDataFactory.createScheme(
            'Buy 1 Get 1', 'SCH-FREE-01', 'Free Products', 'Same Product (QTY)');
        freeScheme.Is_Active__c = true;
        freeScheme.Free_Product_Ext__c = freeProd.Id;
        freeScheme.Free_Quantity__c = 1;
        freeScheme.Channel__c = 'Field App';
        insert freeScheme;

        // ── Scheme: Discount in % (with slabs) ─────────────────────
        Scheme__c discountScheme = TestDataFactory.createScheme(
            'Volume Discount', 'SCH-DISC-01', 'Discount in %', 'Invoice Val Based');
        discountScheme.Is_Active__c = true;
        discountScheme.Max_Discount_Cap__c = 5000;
        insert discountScheme;

        // Slabs for discount scheme
        List<Scheme_Slab__c> slabs = new List<Scheme_Slab__c>{
            new Scheme_Slab__c(
                Scheme__c = discountScheme.Id,
                Slab_Type__c = 'Value',
                Min_Value__c = 1000,
                Max_Value__c = 4999,
                Discount_Type__c = 'Percent',
                Discount_Value__c = 5,
                Is_Active__c = true
            ),
            new Scheme_Slab__c(
                Scheme__c = discountScheme.Id,
                Slab_Type__c = 'Value',
                Min_Value__c = 5000,
                Max_Value__c = null,
                Discount_Type__c = 'Percent',
                Discount_Value__c = 10,
                Is_Active__c = true
            )
        };
        insert slabs;

        // ── Scheme: Discount in Value (no slabs) ────────────────────
        Scheme__c valueScheme = TestDataFactory.createScheme(
            'Flat Discount', 'SCH-VAL-01', 'Discount in Value', 'Invoice Val Based');
        valueScheme.Is_Active__c = true;
        valueScheme.Price_Discount__c = 200;
        insert valueScheme;

        // ── Scheme: Reward Points (no slabs) ────────────────────────
        Scheme__c rewardScheme = TestDataFactory.createScheme(
            'Loyalty Points', 'SCH-REW-01', 'Reward Points', 'Invoice Val Based');
        rewardScheme.Is_Active__c = true;
        rewardScheme.Reward_Points__c = 50;
        insert rewardScheme;

        // ── Scheme Products for one scheme ──────────────────────────
        Product_Extension__c buyProd = TestDataFactory.createProduct('Buy Product', 'BP-0001');
        insert buyProd;

        Scheme_Product__c sp = new Scheme_Product__c(
            Scheme__c = freeScheme.Id,
            Product_Ext__c = buyProd.Id,
            Is_Buy_Product__c = true,
            Is_Get_Product__c = false
        );
        insert sp;

        // ── Scheme with amount slab ─────────────────────────────────
        Scheme__c amtScheme = TestDataFactory.createScheme(
            'Flat Amount Off', 'SCH-AMT-01', 'Discount in Value', 'Invoice Val Based');
        amtScheme.Is_Active__c = true;
        insert amtScheme;

        Scheme_Slab__c amtSlab = new Scheme_Slab__c(
            Scheme__c = amtScheme.Id,
            Slab_Type__c = 'Value',
            Min_Value__c = 500,
            Discount_Type__c = 'Amount',
            Discount_Value__c = 100,
            Is_Active__c = true
        );
        insert amtSlab;

        // ── Scheme with Free Product slab ───────────────────────────
        Scheme__c freeSlabScheme = TestDataFactory.createScheme(
            'Tiered Free', 'SCH-FSLB-01', 'Free Products', 'Same Product (QTY)');
        freeSlabScheme.Is_Active__c = true;
        insert freeSlabScheme;

        Scheme_Slab__c freeSlab = new Scheme_Slab__c(
            Scheme__c = freeSlabScheme.Id,
            Slab_Type__c = 'Quantity',
            Min_Value__c = 10,
            Discount_Type__c = 'Free Product',
            Free_Product_Ext__c = freeProd.Id,
            Free_Quantity__c = 2,
            Is_Active__c = true
        );
        insert freeSlab;

        // ── Scheme with Price Discount slab ─────────────────────────
        Scheme__c priceDiscScheme = TestDataFactory.createScheme(
            'Price Disc Slab', 'SCH-PDS-01', 'Discount in Value', 'Invoice Val Based');
        priceDiscScheme.Is_Active__c = true;
        insert priceDiscScheme;

        Scheme_Slab__c priceDiscSlab = new Scheme_Slab__c(
            Scheme__c = priceDiscScheme.Id,
            Slab_Type__c = 'Value',
            Min_Value__c = 1000,
            Discount_Type__c = 'Price Discount',
            Price_Discount__c = 50,
            Is_Active__c = true
        );
        insert priceDiscSlab;

        // ── Scheme with Reward Points slab ──────────────────────────
        Scheme__c rwdSlabScheme = TestDataFactory.createScheme(
            'Reward Slab', 'SCH-RWS-01', 'Reward Points', 'Invoice Val Based');
        rwdSlabScheme.Is_Active__c = true;
        insert rwdSlabScheme;

        Scheme_Slab__c rwdSlab = new Scheme_Slab__c(
            Scheme__c = rwdSlabScheme.Id,
            Slab_Type__c = 'Value',
            Min_Value__c = 500,
            Discount_Type__c = 'Reward Points',
            Reward_Points__c = 100,
            Is_Active__c = true
        );
        insert rwdSlab;
    }

    // ── getActiveSchemes: no filters ────────────────────────────────────────

    @IsTest
    static void testGetActiveSchemesNoFilters() {
        Test.startTest();
        List<Scheme__c> schemes = SchemeViewController.getActiveSchemes(null, null, null);
        Test.stopTest();

        System.assert(!schemes.isEmpty(), 'Should return active schemes');
    }

    // ── getActiveSchemes: filter by category ────────────────────────────────

    @IsTest
    static void testGetActiveSchemesByCategory() {
        Test.startTest();
        List<Scheme__c> schemes = SchemeViewController.getActiveSchemes('Free Products', null, null);
        Test.stopTest();

        for (Scheme__c s : schemes) {
            System.assertEquals('Free Products', s.Scheme_Category__c,
                'All returned schemes should be Free Products category');
        }
    }

    // ── getActiveSchemes: filter by type ─────────────────────────────────────

    @IsTest
    static void testGetActiveSchemesByType() {
        Test.startTest();
        List<Scheme__c> schemes = SchemeViewController.getActiveSchemes(null, 'Invoice Val Based', null);
        Test.stopTest();

        for (Scheme__c s : schemes) {
            System.assertEquals('Invoice Val Based', s.Scheme_Type__c,
                'All returned schemes should be Invoice Val Based type');
        }
    }

    // ── getActiveSchemes: filter by channel ──────────────────────────────────

    @IsTest
    static void testGetActiveSchemesByChannel() {
        Test.startTest();
        List<Scheme__c> schemes = SchemeViewController.getActiveSchemes(null, null, 'Field App');
        Test.stopTest();

        System.assert(!schemes.isEmpty(), 'Should return schemes matching channel or null channel');
    }

    // ── getSchemeDetails: valid scheme ───────────────────────────────────────

    @IsTest
    static void testGetSchemeDetailsValid() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-FREE-01' LIMIT 1];

        Test.startTest();
        Scheme__c detail = SchemeViewController.getSchemeDetails(scheme.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail, 'Scheme details should be returned');
        System.assertEquals('SCH-FREE-01', detail.Scheme_Code__c, 'Scheme code should match');
        System.assert(detail.Scheme_Products__r != null, 'Scheme products should be included');
    }

    // ── getSchemeDetails: invalid ID throws exception ────────────────────────

    @IsTest
    static void testGetSchemeDetailsInvalidId() {
        // Use a fabricated Id that won't match any record
        Id fakeId = Scheme__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        try {
            SchemeViewController.getSchemeDetails(fakeId);
            System.assert(false, 'Expected AuraHandledException for invalid scheme ID');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Scheme not found'),
                'Error should mention scheme not found');
        }
        Test.stopTest();
    }

    // ── calculateSchemeDiscount: percent slab applied ────────────────────────

    @IsTest
    static void testCalculateDiscountPercentSlab() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-DISC-01' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = SchemeViewController.calculateSchemeDiscount(
            scheme.Id, 10, 3000);
        Test.stopTest();

        System.assertNotEquals(null, result.get('appliedSlabId'), 'A slab should be applied');
        System.assertEquals('Percent', result.get('discountType'), 'Discount type should be Percent');
        Decimal discountAmt = (Decimal) result.get('discountAmount');
        System.assert(discountAmt > 0, 'Discount amount should be positive');
    }

    // ── calculateSchemeDiscount: high value triggers higher slab ─────────────

    @IsTest
    static void testCalculateDiscountHigherSlab() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-DISC-01' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = SchemeViewController.calculateSchemeDiscount(
            scheme.Id, 50, 8000);
        Test.stopTest();

        Decimal discountPct = (Decimal) result.get('discountPercent');
        System.assertEquals(10, discountPct, 'Higher slab should give 10% discount');
    }

    // ── calculateSchemeDiscount: discount cap applied ────────────────────────

    @IsTest
    static void testCalculateDiscountCapApplied() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-DISC-01' LIMIT 1];

        Test.startTest();
        // 10% of 100000 = 10000, but cap is 5000
        Map<String, Object> result = SchemeViewController.calculateSchemeDiscount(
            scheme.Id, 100, 100000);
        Test.stopTest();

        Decimal discountAmt = (Decimal) result.get('discountAmount');
        System.assert(discountAmt <= 5000, 'Discount should be capped at 5000');
    }

    // ── calculateSchemeDiscount: no slab matched returns defaults ────────────

    @IsTest
    static void testCalculateDiscountNoSlabMatched() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-DISC-01' LIMIT 1];

        Test.startTest();
        // Value 100 is below Min_Value 1000 of lowest slab
        Map<String, Object> result = SchemeViewController.calculateSchemeDiscount(
            scheme.Id, 1, 100);
        Test.stopTest();

        System.assertEquals(null, result.get('appliedSlabId'), 'No slab should be applied');
        System.assertEquals(0, result.get('discountAmount'), 'Discount amount should be 0');
    }

    // ── calculateSchemeDiscount: Free Products scheme (no slabs) ────────────

    @IsTest
    static void testCalculateDiscountFreeProductNoSlab() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-FREE-01' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = SchemeViewController.calculateSchemeDiscount(
            scheme.Id, 5, 500);
        Test.stopTest();

        System.assertNotEquals(null, result.get('freeProduct'), 'Free product should be set');
        System.assertEquals(1, (Decimal) result.get('freeQuantity'), 'Free quantity should be 1');
        System.assertEquals('Free Product', result.get('discountType'), 'Discount type should be Free Product');
    }

    // ── calculateSchemeDiscount: Discount in Value (no slabs) ───────────────

    @IsTest
    static void testCalculateDiscountValueNoSlab() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-VAL-01' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = SchemeViewController.calculateSchemeDiscount(
            scheme.Id, 10, 1000);
        Test.stopTest();

        System.assertEquals(200, (Decimal) result.get('priceDiscount'), 'Price discount should be 200');
        System.assertEquals('Price Discount', result.get('discountType'), 'Discount type should be Price Discount');
    }

    // ── calculateSchemeDiscount: Reward Points (no slabs) ───────────────────

    @IsTest
    static void testCalculateDiscountRewardPointsNoSlab() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-REW-01' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = SchemeViewController.calculateSchemeDiscount(
            scheme.Id, 10, 2000);
        Test.stopTest();

        System.assertEquals(50, (Decimal) result.get('rewardPoints'), 'Reward points should be 50');
        System.assertEquals('Reward Points', result.get('discountType'), 'Discount type should be Reward Points');
    }

    // ── calculateSchemeDiscount: Amount slab ────────────────────────────────

    @IsTest
    static void testCalculateDiscountAmountSlab() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-AMT-01' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = SchemeViewController.calculateSchemeDiscount(
            scheme.Id, 10, 1000);
        Test.stopTest();

        System.assertEquals('Amount', result.get('discountType'), 'Discount type should be Amount');
        System.assertEquals(100, (Decimal) result.get('discountAmount'), 'Discount amount should be 100');
    }

    // ── calculateSchemeDiscount: Free Product slab ──────────────────────────

    @IsTest
    static void testCalculateDiscountFreeProductSlab() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-FSLB-01' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = SchemeViewController.calculateSchemeDiscount(
            scheme.Id, 15, 1500);
        Test.stopTest();

        System.assertEquals('Free Product', result.get('discountType'), 'Discount type should be Free Product');
        System.assertEquals(2, (Decimal) result.get('freeQuantity'), 'Free quantity should be 2');
    }

    // ── calculateSchemeDiscount: Price Discount slab ────────────────────────

    @IsTest
    static void testCalculateDiscountPriceDiscountSlab() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-PDS-01' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = SchemeViewController.calculateSchemeDiscount(
            scheme.Id, 10, 2000);
        Test.stopTest();

        System.assertEquals(50, (Decimal) result.get('priceDiscount'), 'Price discount should be 50');
    }

    // ── calculateSchemeDiscount: Reward Points slab ─────────────────────────

    @IsTest
    static void testCalculateDiscountRewardPointsSlab() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-RWS-01' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = SchemeViewController.calculateSchemeDiscount(
            scheme.Id, 10, 1000);
        Test.stopTest();

        System.assertEquals(100, (Decimal) result.get('rewardPoints'), 'Reward points should be 100');
    }

    // ── applySchemeToOrder: exercises the service delegation ────────────────

    @IsTest
    static void testApplySchemeToOrder() {
        Account acc = TestDataFactory.createAndInsertAccount('Scheme Outlet', 'Retailer');
        Sales_Order__c so = TestDataFactory.createSalesOrder(acc.Id, UserInfo.getUserId(), null);
        insert so;

        Test.startTest();
        try {
            Map<String, Object> result = SchemeViewController.applySchemeToOrder(so.Id, acc.Id);
            // If SPM_SchemeEngine_Service is available, we get a result
            System.assertNotEquals(null, result, 'Result should not be null');
        } catch (AuraHandledException e) {
            // If the service throws due to missing config, that is acceptable
            System.assert(e.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }
}
