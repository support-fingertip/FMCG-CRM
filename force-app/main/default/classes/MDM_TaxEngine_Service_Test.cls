/**
 * @description Test class for MDM_TaxEngine_Service.
 *              Covers intra-state (CGST+SGST), inter-state (IGST) tax calculations,
 *              amount verification, missing configuration handling, and bulk operations.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class MDM_TaxEngine_Service_Test {

    @testSetup
    static void setupTestData() {
        // Create products
        List<Product2> products = TestDataFactory.createAndInsertProducts(5);

        // Create tax configurations
        List<Tax_Configuration__c> taxConfigs = new List<Tax_Configuration__c>();
        for (Integer i = 0; i < products.size(); i++) {
            Tax_Configuration__c tc = new Tax_Configuration__c(
                Product__c = products[i].Id,
                Tax_Rate__c = 18,
                HSN_SAC_Code__c = '2106',
                CGST_Rate__c = 9,
                SGST_Rate__c = 9,
                IGST_Rate__c = 18,
                Is_Active__c = true,
                Effective_From__c = Date.today().addDays(-30),
                Effective_To__c = Date.today().addDays(365),
                State__c = 'Maharashtra',
                Tax_Type__c = 'GST'
            );
            taxConfigs.add(tc);
        }
        insert taxConfigs;

        // Create a product with 5% GST (essential commodity)
        Product2 essentialProd = TestDataFactory.createProduct('Essential Item', 'ESS-001');
        insert essentialProd;

        Tax_Configuration__c essentialTax = new Tax_Configuration__c(
            Product__c = essentialProd.Id,
            Tax_Rate__c = 5,
            HSN_SAC_Code__c = '1905',
            CGST_Rate__c = 2.5,
            SGST_Rate__c = 2.5,
            IGST_Rate__c = 5,
            Is_Active__c = true,
            Effective_From__c = Date.today().addDays(-30),
            Effective_To__c = Date.today().addDays(365),
            State__c = 'Maharashtra',
            Tax_Type__c = 'GST'
        );
        insert essentialTax;

        // Create a product with no tax config (for missing config test)
        Product2 noTaxProd = TestDataFactory.createProduct('No Tax Product', 'NOTAX-001');
        insert noTaxProd;
    }

    /**
     * @description Tests intra-state tax calculation (same state).
     *              When seller and buyer are in Maharashtra, CGST and SGST should
     *              each be half of the total GST rate.
     */
    @isTest
    static void testIntraStateTax() {
        Product2 product = [SELECT Id FROM Product2 WHERE ProductCode = 'TP-0000' LIMIT 1];

        Test.startTest();

        MDM_TaxEngine_Service.TaxResult result = MDM_TaxEngine_Service.calculateTax(
            product.Id,
            'Maharashtra',
            'Maharashtra',
            10000
        );

        Test.stopTest();

        System.assertNotEquals(null, result, 'Tax result should not be null');
        System.assertEquals(false, result.isInterState,
            'Maharashtra to Maharashtra should be intra-state');
        System.assertEquals(18, result.taxRate,
            'Tax rate should be 18%');

        // CGST = 9% of 10000 = 900
        System.assertEquals(900.00, result.cgst,
            'CGST should be 9% of Rs 10,000 = Rs 900.00');

        // SGST = 9% of 10000 = 900
        System.assertEquals(900.00, result.sgst,
            'SGST should be 9% of Rs 10,000 = Rs 900.00');

        // IGST = 0 for intra-state
        System.assertEquals(0, result.igst,
            'IGST should be 0 for intra-state transactions');

        // Total tax = 1800
        System.assertEquals(1800.00, result.totalTax,
            'Total tax should be Rs 1,800.00 (CGST 900 + SGST 900)');
    }

    /**
     * @description Tests inter-state tax calculation (different states).
     *              When seller is in Maharashtra and buyer is in Gujarat,
     *              IGST should be applied at the full GST rate.
     */
    @isTest
    static void testInterStateTax() {
        Product2 product = [SELECT Id FROM Product2 WHERE ProductCode = 'TP-0000' LIMIT 1];

        Test.startTest();

        MDM_TaxEngine_Service.TaxResult result = MDM_TaxEngine_Service.calculateTax(
            product.Id,
            'Maharashtra',
            'Gujarat',
            10000
        );

        Test.stopTest();

        System.assertNotEquals(null, result, 'Tax result should not be null');
        System.assertEquals(true, result.isInterState,
            'Maharashtra to Gujarat should be inter-state');
        System.assertEquals(18, result.taxRate,
            'Tax rate should be 18%');

        // IGST = 18% of 10000 = 1800
        System.assertEquals(1800.00, result.igst,
            'IGST should be 18% of Rs 10,000 = Rs 1,800.00');

        // CGST and SGST should be 0
        System.assertEquals(0, result.cgst,
            'CGST should be 0 for inter-state transactions');
        System.assertEquals(0, result.sgst,
            'SGST should be 0 for inter-state transactions');

        // Total tax = 1800
        System.assertEquals(1800.00, result.totalTax,
            'Total tax should be Rs 1,800.00 (IGST only)');
    }

    /**
     * @description Validates exact tax amount calculations for a product with
     *              5% GST rate (essential commodity) under both intra-state and
     *              inter-state scenarios.
     */
    @isTest
    static void testTaxCalculation() {
        Product2 essentialProd = [SELECT Id FROM Product2 WHERE ProductCode = 'ESS-001' LIMIT 1];
        Decimal amount = 5000;

        Test.startTest();

        // Intra-state 5% GST
        MDM_TaxEngine_Service.TaxResult intraResult = MDM_TaxEngine_Service.calculateTax(
            essentialProd.Id, 'Maharashtra', 'Maharashtra', amount
        );

        // Inter-state 5% GST
        MDM_TaxEngine_Service.TaxResult interResult = MDM_TaxEngine_Service.calculateTax(
            essentialProd.Id, 'Maharashtra', 'Karnataka', amount
        );

        Test.stopTest();

        // Intra-state: CGST = 2.5% of 5000 = 125, SGST = 125, Total = 250
        System.assertEquals(125.00, intraResult.cgst,
            'Intra-state CGST should be 2.5% of Rs 5,000 = Rs 125.00');
        System.assertEquals(125.00, intraResult.sgst,
            'Intra-state SGST should be 2.5% of Rs 5,000 = Rs 125.00');
        System.assertEquals(250.00, intraResult.totalTax,
            'Intra-state total tax should be Rs 250.00');

        // Inter-state: IGST = 5% of 5000 = 250
        System.assertEquals(250.00, interResult.igst,
            'Inter-state IGST should be 5% of Rs 5,000 = Rs 250.00');
        System.assertEquals(250.00, interResult.totalTax,
            'Inter-state total tax should be Rs 250.00');

        // Both should yield same total tax amount
        System.assertEquals(intraResult.totalTax, interResult.totalTax,
            'Total tax should be same for intra-state and inter-state at same rate');
    }

    /**
     * @description Verifies that the tax engine gracefully handles a product
     *              with no active Tax_Configuration__c record.
     */
    @isTest
    static void testNoTaxConfig() {
        Product2 noTaxProd = [SELECT Id FROM Product2 WHERE ProductCode = 'NOTAX-001' LIMIT 1];

        Test.startTest();

        MDM_TaxEngine_Service.TaxResult result = MDM_TaxEngine_Service.calculateTax(
            noTaxProd.Id,
            'Maharashtra',
            'Maharashtra',
            10000
        );

        Test.stopTest();

        System.assertNotEquals(null, result, 'Tax result should not be null even without config');
        System.assertEquals(0, result.taxRate,
            'Tax rate should be 0 when no configuration exists');
        System.assertEquals(0, result.cgst,
            'CGST should be 0 when no tax config exists');
        System.assertEquals(0, result.sgst,
            'SGST should be 0 when no tax config exists');
        System.assertEquals(0, result.igst,
            'IGST should be 0 when no tax config exists');
        System.assertEquals(0, result.totalTax,
            'Total tax should be 0 when no tax config exists');
    }

    /**
     * @description Tests bulk tax calculation to verify the service handles
     *              multiple products efficiently.
     */
    @isTest
    static void testBulkTaxCalculation() {
        List<Product2> products = [SELECT Id FROM Product2 WHERE ProductCode LIKE 'TP-%' ORDER BY ProductCode];
        List<Id> productIds = new List<Id>();
        List<Decimal> amounts = new List<Decimal>();

        for (Product2 p : products) {
            productIds.add(p.Id);
            amounts.add(1000);
        }

        Test.startTest();

        List<MDM_TaxEngine_Service.TaxResult> results = MDM_TaxEngine_Service.calculateTaxBulk(
            productIds, 'Maharashtra', 'Maharashtra', amounts
        );

        Test.stopTest();

        System.assertEquals(productIds.size(), results.size(),
            'Should return one result per product');

        for (MDM_TaxEngine_Service.TaxResult r : results) {
            System.assertEquals(false, r.isInterState,
                'All should be intra-state');
            System.assertEquals(180.00, r.totalTax,
                'Each product should have 18% of Rs 1,000 = Rs 180 total tax');
        }
    }

    /**
     * @description Tests that null/zero amounts return zero tax.
     */
    @isTest
    static void testZeroAndNullAmounts() {
        Product2 product = [SELECT Id FROM Product2 WHERE ProductCode = 'TP-0000' LIMIT 1];

        Test.startTest();

        MDM_TaxEngine_Service.TaxResult zeroResult = MDM_TaxEngine_Service.calculateTax(
            product.Id, 'Maharashtra', 'Maharashtra', 0
        );

        MDM_TaxEngine_Service.TaxResult nullResult = MDM_TaxEngine_Service.calculateTax(
            product.Id, 'Maharashtra', 'Maharashtra', null
        );

        MDM_TaxEngine_Service.TaxResult negativeResult = MDM_TaxEngine_Service.calculateTax(
            product.Id, 'Maharashtra', 'Maharashtra', -100
        );

        Test.stopTest();

        System.assertEquals(0, zeroResult.totalTax,
            'Zero amount should produce zero tax');
        System.assertEquals(0, nullResult.totalTax,
            'Null amount should produce zero tax');
        System.assertEquals(0, negativeResult.totalTax,
            'Negative amount should produce zero tax');
    }
}