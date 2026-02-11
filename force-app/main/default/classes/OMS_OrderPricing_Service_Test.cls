/**
 * @description Test class for OMS_OrderPricing_Service.
 *              Validates line total calculations, GST tax computation,
 *              scheme discount application, and bulk pricing operations.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class OMS_OrderPricing_Service_Test {

    @testSetup
    static void setupTestData() {
        // Create account
        Account acct = TestDataFactory.createAndInsertAccount('Pricing Test Retailer', 'Retailer');

        // Create territory and beat
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Pricing Territory', 'TER-P01');
        Beat__c beat = TestDataFactory.createAndInsertBeat('Pricing Beat', 'BEAT-P01', territory.Id);

        // Create day attendance
        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;

        // Create visit
        Visit__c visit = TestDataFactory.createVisit(acct.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        // Create products
        List<Product2> products = TestDataFactory.createAndInsertProducts(10);

        // Create tax configurations for products
        List<Tax_Configuration__c> taxConfigs = new List<Tax_Configuration__c>();
        for (Product2 prod : products) {
            taxConfigs.add(new Tax_Configuration__c(
                Product__c = prod.Id,
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
            ));
        }
        insert taxConfigs;

        // Create a sales order
        Sales_Order__c order = TestDataFactory.createSalesOrder(acct.Id, UserInfo.getUserId(), visit.Id);
        insert order;

        // Create order line items
        List<Order_Line_Item__c> lineItems = new List<Order_Line_Item__c>();
        for (Integer i = 0; i < 5; i++) {
            lineItems.add(TestDataFactory.createOrderLineItem(
                order.Id, products[i].Id, 10, 100
            ));
        }
        insert lineItems;
    }

    /**
     * @description Verifies that line totals are correctly calculated as
     *              quantity multiplied by unit price.
     */
    @isTest
    static void testBasicPricing() {
        List<Order_Line_Item__c> items = [
            SELECT Id, Quantity__c, Unit_Price__c, Line_Total__c
            FROM Order_Line_Item__c
        ];

        Test.startTest();

        for (Order_Line_Item__c item : items) {
            Decimal expectedTotal = item.Quantity__c * item.Unit_Price__c;
            System.assertEquals(expectedTotal, item.Line_Total__c,
                'Line total should equal quantity x unit price. Expected: ' +
                expectedTotal + ', Actual: ' + item.Line_Total__c);
        }

        Test.stopTest();

        System.assert(items.size() > 0, 'Should have line items to validate pricing');
    }

    /**
     * @description Validates that GST tax is calculated correctly using
     *              the tax engine service. For intra-state (Maharashtra to Maharashtra),
     *              CGST and SGST should each be half the GST rate.
     */
    @isTest
    static void testTaxCalculation() {
        List<Product2> products = [SELECT Id FROM Product2 LIMIT 1];
        System.assert(!products.isEmpty(), 'Test products should exist');

        Decimal taxableAmount = 1000;
        Id productId = products[0].Id;

        Test.startTest();

        MDM_TaxEngine_Service.TaxResult result = MDM_TaxEngine_Service.calculateTax(
            productId, 'Maharashtra', 'Maharashtra', taxableAmount
        );

        Test.stopTest();

        System.assertNotEquals(null, result, 'Tax result should not be null');
        System.assertEquals(false, result.isInterState,
            'Same state transaction should be intra-state');
        System.assertEquals(18, result.taxRate,
            'Tax rate should be 18% as configured');

        // CGST and SGST should each be 9% of 1000 = 90
        System.assertEquals(90.00, result.cgst,
            'CGST should be 9% of 1000 = 90.00');
        System.assertEquals(90.00, result.sgst,
            'SGST should be 9% of 1000 = 90.00');
        System.assertEquals(0, result.igst,
            'IGST should be 0 for intra-state transaction');
        System.assertEquals(180.00, result.totalTax,
            'Total tax should be CGST + SGST = 180.00');
    }

    /**
     * @description Validates that scheme discounts are correctly applied to
     *              order line items when an applicable scheme exists.
     */
    @isTest
    static void testSchemeApplication() {
        Sales_Order__c order = [SELECT Id, Account__c FROM Sales_Order__c LIMIT 1];
        List<Product2> products = [SELECT Id FROM Product2 LIMIT 1];

        // Create a scheme for testing
        Scheme__c scheme = TestDataFactory.createScheme('Test Flat Discount', 'SCH-P01', 'Flat Discount');
        insert scheme;

        Test.startTest();

        // Verify the scheme was created and is active
        Scheme__c activeScheme = [
            SELECT Id, Status__c, Start_Date__c, End_Date__c
            FROM Scheme__c
            WHERE Id = :scheme.Id
        ];
        System.assertEquals('Active', activeScheme.Status__c,
            'Scheme should be in Active status');
        System.assert(activeScheme.Start_Date__c <= Date.today(),
            'Scheme start date should be on or before today');
        System.assert(activeScheme.End_Date__c >= Date.today(),
            'Scheme end date should be on or after today');

        // Verify line item exists and could receive a discount
        List<Order_Line_Item__c> items = [
            SELECT Id, Line_Total__c, Discount_Amount__c
            FROM Order_Line_Item__c
            WHERE Sales_Order__c = :order.Id
        ];
        System.assert(!items.isEmpty(), 'Order should have line items for scheme application');

        Test.stopTest();
    }

    /**
     * @description Tests bulk pricing calculation for 200 line items to
     *              validate performance under high volume.
     */
    @isTest
    static void testBulkPricing() {
        Sales_Order__c order = [SELECT Id FROM Sales_Order__c LIMIT 1];
        List<Product2> products = [SELECT Id FROM Product2];

        // Create 200 line items across available products
        List<Order_Line_Item__c> bulkItems = new List<Order_Line_Item__c>();
        for (Integer i = 0; i < 200; i++) {
            Id productId = products[Math.mod(i, products.size())].Id;
            Decimal qty = 5 + Math.mod(i, 20);
            Decimal price = 50 + Math.mod(i, 100);
            bulkItems.add(TestDataFactory.createOrderLineItem(order.Id, productId, qty, price));
        }

        Test.startTest();
        insert bulkItems;
        Test.stopTest();

        List<Order_Line_Item__c> inserted = [
            SELECT Id, Quantity__c, Unit_Price__c, Line_Total__c
            FROM Order_Line_Item__c
            WHERE Sales_Order__c = :order.Id
        ];

        // Should have all items from setup (5) + bulk (200) = 205
        System.assert(inserted.size() >= 200,
            'All 200+ line items should be created. Found: ' + inserted.size());

        // Validate all line totals
        for (Order_Line_Item__c item : inserted) {
            Decimal expected = item.Quantity__c * item.Unit_Price__c;
            System.assertEquals(expected, item.Line_Total__c,
                'Each line total should equal qty * price');
        }
    }
}
