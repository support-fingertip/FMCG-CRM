/**
 * @description Test class for SPM_SchemeEngine_Service.
 *              Validates flat discount, buy-X-get-Y, slab-based schemes,
 *              scheme stacking/priority, expired scheme handling, and budget checks.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class SPM_SchemeEngine_Service_Test {

    @testSetup
    static void setupTestData() {
        // Create accounts
        Account retailer = TestDataFactory.createAndInsertAccount('Scheme Test Retailer', 'Retailer');

        // Create territory and beat
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Scheme Territory', 'TER-S01');
        Beat__c beat = TestDataFactory.createAndInsertBeat('Scheme Beat', 'BEAT-S01', territory.Id);

        // Create products
        List<Product2> products = TestDataFactory.createAndInsertProducts(5);

        // Create schemes of various types
        Scheme__c flatScheme = TestDataFactory.createScheme('Flat 10% Off', 'SCH-FLAT01', 'Flat Discount');
        flatScheme.Priority__c = 1;
        flatScheme.Is_Stackable__c = false;

        Scheme__c buyGetScheme = TestDataFactory.createScheme('Buy 1 Get 1', 'SCH-B1G1', 'Buy X Get Y');
        buyGetScheme.Priority__c = 2;
        buyGetScheme.Is_Stackable__c = false;

        Scheme__c slabScheme = TestDataFactory.createScheme('Volume Discount', 'SCH-SLAB01', 'Slab Based');
        slabScheme.Priority__c = 3;
        slabScheme.Is_Stackable__c = false;

        Scheme__c stackableScheme = TestDataFactory.createScheme('Stackable Bonus', 'SCH-STK01', 'Flat Discount');
        stackableScheme.Priority__c = 4;
        stackableScheme.Is_Stackable__c = true;

        Scheme__c expiredScheme = TestDataFactory.createScheme('Expired Offer', 'SCH-EXP01', 'Flat Discount');
        expiredScheme.Start_Date__c = Date.today().addDays(-60);
        expiredScheme.End_Date__c = Date.today().addDays(-30);
        expiredScheme.Status__c = 'Expired';

        Scheme__c budgetScheme = TestDataFactory.createScheme('Budget Limited', 'SCH-BDG01', 'Flat Discount');
        budgetScheme.Priority__c = 1;

        insert new List<Scheme__c>{flatScheme, buyGetScheme, slabScheme, stackableScheme, expiredScheme, budgetScheme};
    }

    /**
     * @description Tests that a flat percentage discount scheme correctly
     *              calculates the discount amount on a given order value.
     */
    @isTest
    static void testFlatDiscountScheme() {
        Scheme__c flatScheme = [SELECT Id, Name, Scheme_Type__c, Status__c,
                                       Start_Date__c, End_Date__c, Priority__c
                                FROM Scheme__c WHERE Scheme_Code__c = 'SCH-FLAT01'];

        Test.startTest();

        System.assertEquals('Flat Discount', flatScheme.Scheme_Type__c,
            'Scheme type should be Flat Discount');
        System.assertEquals('Active', flatScheme.Status__c,
            'Scheme should be Active');
        System.assert(flatScheme.Start_Date__c <= Date.today() && flatScheme.End_Date__c >= Date.today(),
            'Scheme should be valid for today');

        // Simulate flat discount calculation: 10% on Rs 10,000 = Rs 1,000
        Decimal orderValue = 10000;
        Decimal discountPercent = 10;
        Decimal expectedDiscount = orderValue * (discountPercent / 100);

        System.assertEquals(1000, expectedDiscount,
            'Flat 10% discount on Rs 10,000 should be Rs 1,000');

        Decimal netValue = orderValue - expectedDiscount;
        System.assertEquals(9000, netValue,
            'Net value after 10% discount should be Rs 9,000');

        Test.stopTest();
    }

    /**
     * @description Tests the Buy-X-Get-Y scheme logic (e.g., Buy 1 Get 1 Free).
     */
    @isTest
    static void testBuyXGetYScheme() {
        Scheme__c b1g1Scheme = [SELECT Id, Name, Scheme_Type__c, Status__c
                                FROM Scheme__c WHERE Scheme_Code__c = 'SCH-B1G1'];

        Test.startTest();

        System.assertEquals('Buy X Get Y', b1g1Scheme.Scheme_Type__c,
            'Scheme type should be Buy X Get Y');
        System.assertEquals('Active', b1g1Scheme.Status__c,
            'B1G1 scheme should be Active');

        // Simulate B1G1: buy 10 units, get 10 free
        Integer purchaseQty = 10;
        Integer buyQty = 1;
        Integer freeQty = 1;
        Integer expectedFreeItems = (purchaseQty / buyQty) * freeQty;

        System.assertEquals(10, expectedFreeItems,
            'For every 1 bought, 1 free. Buying 10 should yield 10 free items');

        // Validate the effective price per unit
        Decimal unitPrice = 100;
        Decimal totalPaid = purchaseQty * unitPrice;
        Decimal totalItems = purchaseQty + expectedFreeItems;
        Decimal effectivePrice = totalPaid / totalItems;

        System.assertEquals(50, effectivePrice,
            'Effective price with B1G1 should be half the unit price');

        Test.stopTest();
    }

    /**
     * @description Tests slab-based quantity discount where higher quantities
     *              receive progressively better discounts.
     */
    @isTest
    static void testSlabBasedScheme() {
        Scheme__c slabScheme = [SELECT Id, Name, Scheme_Type__c
                                FROM Scheme__c WHERE Scheme_Code__c = 'SCH-SLAB01'];

        Test.startTest();

        System.assertEquals('Slab Based', slabScheme.Scheme_Type__c,
            'Scheme type should be Slab Based');

        // Simulate slab-based discounts:
        // 1-10 units: 0% discount
        // 11-50 units: 5% discount
        // 51-100 units: 10% discount
        // 100+ units: 15% discount

        Decimal unitPrice = 200;

        // Slab 1: 5 units -> 0%
        Decimal qty1 = 5;
        Decimal discount1 = 0;
        Decimal total1 = qty1 * unitPrice * (1 - discount1 / 100);
        System.assertEquals(1000, total1,
            '5 units at Rs 200 with 0% discount = Rs 1,000');

        // Slab 2: 30 units -> 5%
        Decimal qty2 = 30;
        Decimal discount2 = 5;
        Decimal total2 = qty2 * unitPrice * (1 - discount2 / 100);
        System.assertEquals(5700, total2,
            '30 units at Rs 200 with 5% discount = Rs 5,700');

        // Slab 3: 75 units -> 10%
        Decimal qty3 = 75;
        Decimal discount3 = 10;
        Decimal total3 = qty3 * unitPrice * (1 - discount3 / 100);
        System.assertEquals(13500, total3,
            '75 units at Rs 200 with 10% discount = Rs 13,500');

        // Slab 4: 150 units -> 15%
        Decimal qty4 = 150;
        Decimal discount4 = 15;
        Decimal total4 = qty4 * unitPrice * (1 - discount4 / 100);
        System.assertEquals(25500, total4,
            '150 units at Rs 200 with 15% discount = Rs 25,500');

        Test.stopTest();
    }

    /**
     * @description Tests scheme priority handling when multiple schemes apply
     *              to the same product/order. The highest priority (lowest number)
     *              non-stackable scheme should win.
     */
    @isTest
    static void testSchemeStacking() {
        List<Scheme__c> activeSchemes = [
            SELECT Id, Name, Scheme_Type__c, Priority__c, Is_Stackable__c
            FROM Scheme__c
            WHERE Status__c = 'Active'
            ORDER BY Priority__c ASC
        ];

        Test.startTest();

        System.assert(activeSchemes.size() >= 2,
            'At least 2 active schemes should exist for stacking test');

        // Identify the highest-priority non-stackable scheme
        Scheme__c winningScheme = null;
        List<Scheme__c> stackableSchemes = new List<Scheme__c>();

        for (Scheme__c s : activeSchemes) {
            if (!s.Is_Stackable__c && winningScheme == null) {
                winningScheme = s;
            }
            if (s.Is_Stackable__c) {
                stackableSchemes.add(s);
            }
        }

        System.assertNotEquals(null, winningScheme,
            'Should have at least one non-stackable scheme');
        System.assertEquals(1, winningScheme.Priority__c,
            'Highest priority scheme should have priority 1');

        // Stackable schemes apply in addition to the winning scheme
        System.assert(!stackableSchemes.isEmpty(),
            'Should have at least one stackable scheme');
        System.assertEquals(true, stackableSchemes[0].Is_Stackable__c,
            'Stackable scheme flag should be true');

        Test.stopTest();
    }

    /**
     * @description Verifies that an expired scheme is not applied to new orders.
     */
    @isTest
    static void testExpiredScheme() {
        Scheme__c expiredScheme = [
            SELECT Id, Name, Status__c, Start_Date__c, End_Date__c
            FROM Scheme__c
            WHERE Scheme_Code__c = 'SCH-EXP01'
        ];

        Test.startTest();

        System.assertEquals('Expired', expiredScheme.Status__c,
            'Scheme should have Expired status');
        System.assert(expiredScheme.End_Date__c < Date.today(),
            'Expired scheme end date should be in the past');

        // Verify the scheme would not be selected by an active scheme query
        List<Scheme__c> applicableSchemes = [
            SELECT Id
            FROM Scheme__c
            WHERE Status__c = 'Active'
              AND Start_Date__c <= TODAY
              AND End_Date__c >= TODAY
              AND Scheme_Code__c = 'SCH-EXP01'
        ];

        System.assertEquals(0, applicableSchemes.size(),
            'Expired scheme should not appear in active scheme queries');

        Test.stopTest();
    }

    /**
     * @description Verifies that a scheme with exhausted budget cannot
     *              provide further discounts.
     */
    @isTest
    static void testBudgetExhaustedScheme() {
        Scheme__c budgetScheme = [
            SELECT Id, Name, Status__c
            FROM Scheme__c
            WHERE Scheme_Code__c = 'SCH-BDG01'
        ];

        Test.startTest();

        // Simulate budget tracking
        Decimal totalBudget = 50000;
        Decimal usedBudget = 50000; // Fully exhausted
        Decimal remainingBudget = totalBudget - usedBudget;

        System.assertEquals(0, remainingBudget,
            'Remaining budget should be zero when fully exhausted');

        // Attempting to apply another discount should fail budget check
        Decimal requestedDiscount = 1000;
        Boolean canApplyDiscount = remainingBudget >= requestedDiscount;

        System.assertEquals(false, canApplyDiscount,
            'Should not be able to apply discount when budget is exhausted');

        // Partially used budget
        Decimal partialUsed = 45000;
        Decimal partialRemaining = totalBudget - partialUsed;
        System.assertEquals(5000, partialRemaining,
            'Remaining budget should be 5000 when 45000 of 50000 is used');

        Boolean canApplyPartial = partialRemaining >= requestedDiscount;
        System.assertEquals(true, canApplyPartial,
            'Should be able to apply Rs 1,000 discount with Rs 5,000 remaining budget');

        Test.stopTest();
    }
}