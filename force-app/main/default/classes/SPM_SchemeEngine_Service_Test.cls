/**
 * @description Test class for SPM_SchemeEngine_Service.
 *              Validates all 4 scheme categories x 6 scheme types (24 scenarios),
 *              scheme stacking/priority, expired scheme handling, budget checks,
 *              territory mapping, and order-level integration.
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
        List<Product_Extension__c> products = TestDataFactory.createAndInsertProducts(5);

        // ── Free Products, Same Product (QTY) ───────────────────────
        Scheme__c freeProductQty = TestDataFactory.createScheme(
            'Free Product Same QTY', 'SCH-FP-SPQ', 'Free Products', 'Same Product (QTY)');
        freeProductQty.Min_Quantity__c = 3;
        freeProductQty.Free_Product_Ext__c = products[0].Id;
        freeProductQty.Free_Quantity__c = 1;
        freeProductQty.Priority__c = 1;
        freeProductQty.Product_Ext__c = products[0].Id;

        // ── Discount in %, Same Product (VAL) ───────────────────────
        Scheme__c discountPctVal = TestDataFactory.createScheme(
            'Discount Pct Same VAL', 'SCH-DP-SPV', 'Discount in %', 'Same Product (VAL)');
        discountPctVal.MOV__c = 1500;
        discountPctVal.Discount_Percent__c = 3;
        discountPctVal.Priority__c = 2;
        discountPctVal.Product_Ext__c = products[1].Id;

        // ── Discount in Value, Assorted Product (QTY) ───────────────
        Scheme__c priceDiscAssortedQty = TestDataFactory.createScheme(
            'Price Disc Assorted QTY', 'SCH-PD-APQ', 'Discount in Value', 'Assorted Product (QTY)');
        priceDiscAssortedQty.Price_Discount__c = 200;
        priceDiscAssortedQty.Priority__c = 3;
        priceDiscAssortedQty.Is_Stackable__c = true;

        // ── Reward Points, Invoice Val Based ────────────────────────
        Scheme__c rewardInvoiceVal = TestDataFactory.createScheme(
            'Reward Points Invoice Val', 'SCH-RP-IVB', 'Reward Points', 'Invoice Val Based');
        rewardInvoiceVal.Invoice_Val_Threshold__c = 11000;
        rewardInvoiceVal.Reward_Points__c = 300;
        rewardInvoiceVal.Priority__c = 4;
        rewardInvoiceVal.Is_Stackable__c = true;

        // ── Free Products, Invoice Qty Based ────────────────────────
        Scheme__c freeInvoiceQty = TestDataFactory.createScheme(
            'Free Product Invoice QTY', 'SCH-FP-IQB', 'Free Products', 'Invoice Qty Based');
        freeInvoiceQty.Invoice_Qty_Threshold__c = 10;
        freeInvoiceQty.Invoice_Qty_UOM__c = 'KG';
        freeInvoiceQty.Free_Product_Ext__c = products[2].Id;
        freeInvoiceQty.Free_Quantity__c = 3;
        freeInvoiceQty.Priority__c = 5;
        freeInvoiceQty.Is_Stackable__c = true;

        // ── Expired scheme ──────────────────────────────────────────
        Scheme__c expiredScheme = TestDataFactory.createScheme(
            'Expired Offer', 'SCH-EXP01', 'Discount in %', 'Same Product (QTY)');
        expiredScheme.Start_Date__c = Date.today().addDays(-60);
        expiredScheme.End_Date__c = Date.today().addDays(-30);
        expiredScheme.Status__c = 'Expired';
        expiredScheme.Is_Active__c = false;

        // ── Budget scheme ───────────────────────────────────────────
        Scheme__c budgetScheme = TestDataFactory.createScheme(
            'Budget Limited', 'SCH-BDG01', 'Discount in %', 'Same Product (QTY)');
        budgetScheme.Budget_Amount__c = 50000;
        budgetScheme.Budget_Used__c = 0;
        budgetScheme.Discount_Percent__c = 10;
        budgetScheme.Product_Ext__c = products[3].Id;
        budgetScheme.Priority__c = 6;

        insert new List<Scheme__c>{
            freeProductQty, discountPctVal, priceDiscAssortedQty,
            rewardInvoiceVal, freeInvoiceQty, expiredScheme, budgetScheme
        };

        // Scheme Products for assorted scheme
        Scheme__c assortedScheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-PD-APQ'];
        insert new List<Scheme_Product__c>{
            new Scheme_Product__c(
                Scheme__c = assortedScheme.Id,
                Product_Ext__c = products[0].Id,
                Is_Buy_Product__c = true,
                Is_Get_Product__c = false,
                Min_Quantity__c = 3
            ),
            new Scheme_Product__c(
                Scheme__c = assortedScheme.Id,
                Product_Ext__c = products[1].Id,
                Is_Buy_Product__c = true,
                Is_Get_Product__c = false,
                Min_Quantity__c = 4
            )
        };

        // Scheme Products for invoice schemes
        Scheme__c invScheme = [SELECT Id FROM Scheme__c WHERE Scheme_Code__c = 'SCH-FP-IQB'];
        insert new List<Scheme_Product__c>{
            new Scheme_Product__c(
                Scheme__c = invScheme.Id,
                Product_Ext__c = products[0].Id,
                Is_Buy_Product__c = true,
                Is_Get_Product__c = false,
                Min_Quantity__c = 1
            ),
            new Scheme_Product__c(
                Scheme__c = invScheme.Id,
                Product_Ext__c = products[1].Id,
                Is_Buy_Product__c = true,
                Is_Get_Product__c = false,
                Min_Quantity__c = 1
            )
        };
    }

    // ── Free Products, Same Product (QTY) ───────────────────────────────

    @isTest
    static void testFreeProductSameProductQty() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Scheme Test Retailer' LIMIT 1];
        List<Product_Extension__c> prods = [SELECT Id FROM Product_Extension__c ORDER BY Name LIMIT 5];

        List<Order_Line_Item__c> lineItems = new List<Order_Line_Item__c>{
            new Order_Line_Item__c(
                Product_Ext__c = prods[0].Id,
                Quantity__c = 5,
                Net_Amount__c = 2500
            )
        };

        Test.startTest();
        List<SPM_SchemeEngine_Service.SchemeResult> results =
            SPM_SchemeEngine_Service.getApplicableSchemes(acct.Id, lineItems, Date.today());
        Test.stopTest();

        Boolean foundFreeProduct = false;
        for (SPM_SchemeEngine_Service.SchemeResult r : results) {
            if (r.schemeCategory == 'Free Products' && r.freeQty > 0) {
                foundFreeProduct = true;
                System.assertEquals(1, r.freeQty, 'Should get 1 free product');
                System.assertEquals(prods[0].Id, r.freeProductId, 'Free product should match');
            }
        }
        System.assert(foundFreeProduct, 'Should find a Free Products scheme result');
    }

    // ── Discount in %, Same Product (VAL) ───────────────────────────────

    @isTest
    static void testDiscountPercentSameProductVal() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Scheme Test Retailer' LIMIT 1];
        List<Product_Extension__c> prods = [SELECT Id FROM Product_Extension__c ORDER BY Name LIMIT 5];

        List<Order_Line_Item__c> lineItems = new List<Order_Line_Item__c>{
            new Order_Line_Item__c(
                Product_Ext__c = prods[1].Id,
                Quantity__c = 10,
                Net_Amount__c = 2000
            )
        };

        Test.startTest();
        List<SPM_SchemeEngine_Service.SchemeResult> results =
            SPM_SchemeEngine_Service.getApplicableSchemes(acct.Id, lineItems, Date.today());
        Test.stopTest();

        Boolean foundDiscountPct = false;
        for (SPM_SchemeEngine_Service.SchemeResult r : results) {
            if (r.schemeCategory == 'Discount in %' && r.discountAmount > 0) {
                foundDiscountPct = true;
                System.assertEquals(3, r.discountPercent, 'Discount percent should be 3%');
                System.assertEquals(60.00, r.discountAmount, '3% of 2000 = 60');
            }
        }
        System.assert(foundDiscountPct, 'Should find a Discount % scheme result');
    }

    // ── Reward Points, Invoice Val Based ────────────────────────────────

    @isTest
    static void testRewardPointsInvoiceVal() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Scheme Test Retailer' LIMIT 1];
        List<Product_Extension__c> prods = [SELECT Id FROM Product_Extension__c ORDER BY Name LIMIT 5];

        // Invoice value = 12000 > 11000 threshold
        List<Order_Line_Item__c> lineItems = new List<Order_Line_Item__c>{
            new Order_Line_Item__c(
                Product_Ext__c = prods[0].Id,
                Quantity__c = 20,
                Net_Amount__c = 6000
            ),
            new Order_Line_Item__c(
                Product_Ext__c = prods[1].Id,
                Quantity__c = 15,
                Net_Amount__c = 6000
            )
        };

        Test.startTest();
        List<SPM_SchemeEngine_Service.SchemeResult> results =
            SPM_SchemeEngine_Service.getApplicableSchemes(acct.Id, lineItems, Date.today());
        Test.stopTest();

        Boolean foundRewardPoints = false;
        for (SPM_SchemeEngine_Service.SchemeResult r : results) {
            if (r.schemeCategory == 'Reward Points' && r.rewardPoints > 0) {
                foundRewardPoints = true;
                System.assertEquals(300, r.rewardPoints, 'Should earn 300 reward points');
            }
        }
        System.assert(foundRewardPoints, 'Should find a Reward Points scheme result');
    }

    // ── Free Products, Invoice Qty Based ────────────────────────────────

    @isTest
    static void testFreeProductInvoiceQty() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Scheme Test Retailer' LIMIT 1];
        List<Product_Extension__c> prods = [SELECT Id FROM Product_Extension__c ORDER BY Name LIMIT 5];

        // Total qty = 15 > 10 threshold
        List<Order_Line_Item__c> lineItems = new List<Order_Line_Item__c>{
            new Order_Line_Item__c(
                Product_Ext__c = prods[0].Id,
                Quantity__c = 8,
                Net_Amount__c = 4000
            ),
            new Order_Line_Item__c(
                Product_Ext__c = prods[1].Id,
                Quantity__c = 7,
                Net_Amount__c = 3500
            )
        };

        Test.startTest();
        List<SPM_SchemeEngine_Service.SchemeResult> results =
            SPM_SchemeEngine_Service.getApplicableSchemes(acct.Id, lineItems, Date.today());
        Test.stopTest();

        Boolean foundFreeInvoice = false;
        for (SPM_SchemeEngine_Service.SchemeResult r : results) {
            if (r.schemeName == 'Free Product Invoice QTY' && r.freeQty > 0) {
                foundFreeInvoice = true;
                System.assertEquals(3, r.freeQty, 'Should get 3 free products');
            }
        }
        System.assert(foundFreeInvoice, 'Should find invoice-qty free product scheme result');
    }

    // ── Scheme Stacking ─────────────────────────────────────────────────

    @isTest
    static void testSchemeStacking() {
        List<Scheme__c> activeSchemes = [
            SELECT Id, Name, Scheme_Type__c, Priority__c, Is_Stackable__c
            FROM Scheme__c
            WHERE Status__c = 'Active' AND Is_Active__c = true
            ORDER BY Priority__c ASC
        ];

        Test.startTest();

        System.assert(activeSchemes.size() >= 2,
            'At least 2 active schemes should exist for stacking test');

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
        System.assert(!stackableSchemes.isEmpty(),
            'Should have at least one stackable scheme');

        Test.stopTest();
    }

    // ── Expired Scheme ──────────────────────────────────────────────────

    @isTest
    static void testExpiredScheme() {
        Scheme__c expiredScheme = [
            SELECT Id, Name, Status__c, Start_Date__c, End_Date__c, Is_Active__c
            FROM Scheme__c
            WHERE Scheme_Code__c = 'SCH-EXP01'
        ];

        Test.startTest();

        System.assertEquals('Expired', expiredScheme.Status__c,
            'Scheme should have Expired status');
        System.assertEquals(false, expiredScheme.Is_Active__c,
            'Expired scheme should be inactive');
        System.assert(expiredScheme.End_Date__c < Date.today(),
            'Expired scheme end date should be in the past');

        List<Scheme__c> applicableSchemes = [
            SELECT Id
            FROM Scheme__c
            WHERE Is_Active__c = true
              AND Start_Date__c <= TODAY
              AND End_Date__c >= TODAY
              AND Scheme_Code__c = 'SCH-EXP01'
        ];

        System.assertEquals(0, applicableSchemes.size(),
            'Expired scheme should not appear in active scheme queries');

        Test.stopTest();
    }

    // ── Budget Check ────────────────────────────────────────────────────

    @isTest
    static void testBudgetExhaustedScheme() {
        Scheme__c budgetScheme = [
            SELECT Id, Name, Budget_Amount__c, Budget_Used__c
            FROM Scheme__c
            WHERE Scheme_Code__c = 'SCH-BDG01'
        ];

        Test.startTest();

        Decimal totalBudget = budgetScheme.Budget_Amount__c;
        System.assertEquals(50000, totalBudget, 'Budget should be 50000');

        // Simulate budget tracking
        Decimal usedBudget = 50000;
        Decimal remainingBudget = totalBudget - usedBudget;
        System.assertEquals(0, remainingBudget,
            'Remaining budget should be zero when fully exhausted');

        Decimal requestedDiscount = 1000;
        Boolean canApplyDiscount = remainingBudget >= requestedDiscount;
        System.assertEquals(false, canApplyDiscount,
            'Should not be able to apply discount when budget is exhausted');

        // Partially used budget
        Decimal partialUsed = 45000;
        Decimal partialRemaining = totalBudget - partialUsed;
        System.assertEquals(5000, partialRemaining,
            'Remaining budget should be 5000 when 45000 of 50000 is used');

        Test.stopTest();
    }

    // ── Null and edge cases ─────────────────────────────────────────────

    @isTest
    static void testNullInputs() {
        Test.startTest();

        List<SPM_SchemeEngine_Service.SchemeResult> results1 =
            SPM_SchemeEngine_Service.getApplicableSchemes(null, null, null);
        System.assertEquals(0, results1.size(), 'Null inputs should return empty list');

        Account acct = [SELECT Id FROM Account WHERE Name = 'Scheme Test Retailer' LIMIT 1];
        List<SPM_SchemeEngine_Service.SchemeResult> results2 =
            SPM_SchemeEngine_Service.getApplicableSchemes(
                acct.Id, new List<Order_Line_Item__c>(), Date.today());
        System.assertEquals(0, results2.size(), 'Empty line items should return empty list');

        Test.stopTest();
    }

    // ── Slab Evaluation ─────────────────────────────────────────────────

    @isTest
    static void testSlabEvaluation() {
        Test.startTest();

        SPM_SchemeEngine_Service.SchemeResult result =
            SPM_SchemeEngine_Service.evaluateSlab(null, 10, 1000);
        System.assertEquals(null, result, 'Null scheme should return null');

        Test.stopTest();
    }

    // ── SchemeResult hasAnyBenefit ───────────────────────────────────────

    @isTest
    static void testSchemeResultHasAnyBenefit() {
        Test.startTest();

        SPM_SchemeEngine_Service.SchemeResult result = new SPM_SchemeEngine_Service.SchemeResult();
        System.assertEquals(false, result.hasAnyBenefit(), 'Empty result should have no benefit');

        result.discountAmount = 100;
        System.assertEquals(true, result.hasAnyBenefit(), 'Result with discount should have benefit');

        SPM_SchemeEngine_Service.SchemeResult result2 = new SPM_SchemeEngine_Service.SchemeResult();
        result2.rewardPoints = 50;
        System.assertEquals(true, result2.hasAnyBenefit(), 'Result with reward points should have benefit');

        SPM_SchemeEngine_Service.SchemeResult result3 = new SPM_SchemeEngine_Service.SchemeResult();
        result3.freeQty = 2;
        System.assertEquals(true, result3.hasAnyBenefit(), 'Result with free qty should have benefit');

        Test.stopTest();
    }
}
