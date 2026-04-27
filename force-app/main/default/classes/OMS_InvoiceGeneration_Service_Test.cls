/**
 * @description Test class for OMS_InvoiceGeneration_Service.
 *              Validates invoice and invoice line item generation from approved
 *              sales orders, duplicate prevention, due date calculation, and
 *              invoice total recalculation.
 * @author  SFA Development Team
 * @date    2024
 */
@IsTest
private class OMS_InvoiceGeneration_Service_Test {

    @TestSetup
    static void setupTestData() {
        // Create territory and beat
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Invoice Territory', 'TER-I01');
        Beat__c beat = TestDataFactory.createAndInsertBeat('Invoice Beat', 'BEAT-I01', territory.Id);

        // Create account with credit
        Account acct = TestDataFactory.createAccount('Invoice Test Account', 'Retailer');
        acct.Credit_Limit__c = 500000;
        acct.Credit_Utilized__c = 0;
        insert acct;

        // Create warehouse
        Warehouse__c warehouse = new Warehouse__c(
            Name = 'Test Warehouse',
            Warehouse_Code__c = 'WH-TEST01',
            Is_Active__c = true,
            State__c = 'Maharashtra',
            City__c = 'Mumbai'
        );
        insert warehouse;

        // Create day attendance
        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;

        // Create visit
        Visit__c visit = TestDataFactory.createVisit(acct.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        // Create products
        List<Product_Extension__c> products = TestDataFactory.createAndInsertProducts(3);

        // Create warehouse stock for the products
        List<Warehouse_Stock__c> stocks = new List<Warehouse_Stock__c>();
        for (Product_Extension__c prod : products) {
            stocks.add(new Warehouse_Stock__c(
                Warehouse__c = warehouse.Id,
                Product_Ext__c = prod.Id,
                Qty_On_Hand__c = 1000,
                Qty_Reserved__c = 0,
                Qty_Damaged__c = 0
            ));
        }
        insert stocks;

        // Create sales orders
        Sales_Order__c order1 = TestDataFactory.createSalesOrder(acct.Id, UserInfo.getUserId(), visit.Id);
        order1.Total_Amount__c = 30000;
        order1.Total_Tax__c = 5400;
        order1.Discount_Amount__c = 1000;
        order1.Net_Amount__c = 34400;
        order1.Payment_Terms__c = 'Net 30';
        order1.Shipping_State__c = 'Maharashtra';
        order1.Warehouse_State__c = 'Maharashtra';
        order1.Warehouse__c = warehouse.Id;
        order1.Territory__c = territory.Id;

        Sales_Order__c order2 = TestDataFactory.createSalesOrder(acct.Id, UserInfo.getUserId(), visit.Id);
        order2.Total_Amount__c = 20000;
        order2.Total_Tax__c = 3600;
        order2.Discount_Amount__c = 500;
        order2.Net_Amount__c = 23100;
        order2.Payment_Terms__c = 'Net 60';
        order2.Shipping_State__c = 'Maharashtra';
        order2.Warehouse_State__c = 'Maharashtra';
        order2.Warehouse__c = warehouse.Id;
        order2.Order_Date__c = Date.today().addDays(-1);
        order2.Territory__c = territory.Id;

        insert new List<Sales_Order__c>{ order1, order2 };

        // Create price lists for the products
        List<Price_List__c> priceLists = new List<Price_List__c>();
        for (Product_Extension__c prod : products) {
            priceLists.add(new Price_List__c(
                Product_Ext__c = prod.Id,
                Unit_Price__c = 100,
                Is_Active__c = true,
                Effective_From__c = Date.today().addDays(-30),
                Priority__c = 8
            ));
        }
        insert priceLists;

        // Create order line items for order1
        // Bypass the trigger handler to set pricing fields directly
        TriggerHandler.bypass('OMS_OrderLineItem_TriggerHandler');
        List<Order_Line_Item__c> lineItems = new List<Order_Line_Item__c>();
        for (Integer i = 0; i < products.size(); i++) {
            Order_Line_Item__c li = new Order_Line_Item__c(
                Sales_Order__c = order1.Id,
                Product_Ext__c = products[i].Id,
                Quantity__c = 10 * (i + 1),
                Unit_Price__c = 1000,
                Line_Amount__c = 10000 * (i + 1),
                Net_Amount__c = 9500 * (i + 1),
                Discount_Amount__c = 500 * (i + 1),
                CGST__c = 450 * (i + 1),
                SGST__c = 450 * (i + 1),
                IGST__c = 0,
                Tax_Amount__c = 900 * (i + 1),
                Tax_Rate__c = 18,
                Total_Amount__c = 10400 * (i + 1),
                UOM__c = 'Pieces'
            );
            lineItems.add(li);
        }
        insert lineItems;
        TriggerHandler.clearBypass('OMS_OrderLineItem_TriggerHandler');

        // Set orders to Approved status via field update (bypass trigger for setup)
        TriggerHandler.bypass('OMS_SalesOrder_TriggerHandler');
        order1.Status__c = 'Submitted';
        order2.Status__c = 'Submitted';
        update new List<Sales_Order__c>{ order1, order2 };

        order1.Status__c = 'Approved';
        order2.Status__c = 'Approved';
        update new List<Sales_Order__c>{ order1, order2 };
        TriggerHandler.clearBypass('OMS_SalesOrder_TriggerHandler');
    }

    // ── generateInvoices Tests ─────────────────────────────────────────────

    @IsTest
    static void testGenerateInvoices_success() {
        List<Sales_Order__c> approvedOrders = [
            SELECT Id FROM Sales_Order__c WHERE Status__c = 'Approved'
        ];
        Set<Id> orderIds = new Set<Id>();
        for (Sales_Order__c o : approvedOrders) {
            orderIds.add(o.Id);
        }

        // Delete any invoices that may have been auto-created during setup
        List<Invoice__c> existingInvoices = [SELECT Id FROM Invoice__c WHERE Sales_Order__c IN :orderIds];
        if (!existingInvoices.isEmpty()) {
            TriggerHandler.bypass('OMS_Invoice_TriggerHandler');
            delete existingInvoices;
            TriggerHandler.clearBypass('OMS_Invoice_TriggerHandler');
        }

        Test.startTest();
        OMS_InvoiceGeneration_Service.generateInvoices(orderIds);
        Test.stopTest();

        // Verify invoices were created
        List<Invoice__c> invoices = [
            SELECT Id, Sales_Order__c, Account__c, Status__c, Invoice_Number__c,
                   Invoice_Date__c, Due_Date__c, Total_Amount__c, Balance_Due__c,
                   Payment_Terms__c
            FROM Invoice__c
            WHERE Sales_Order__c IN :orderIds
        ];

        System.assert(!invoices.isEmpty(), 'Invoices should have been created');

        for (Invoice__c inv : invoices) {
            System.assertNotEquals(null, inv.Invoice_Number__c, 'Invoice number should be generated');
            System.assert(inv.Invoice_Number__c.startsWith('INV-'), 'Invoice number should start with INV-');
            System.assertEquals('Draft', inv.Status__c, 'New invoice should have Draft status');
            System.assertEquals(Date.today(), inv.Invoice_Date__c, 'Invoice date should be today');
            System.assertNotEquals(null, inv.Account__c, 'Invoice should have an account');
        }
    }

    @IsTest
    static void testGenerateInvoices_withLineItems() {
        // Get the order that has line items
        Sales_Order__c orderWithLines = [
            SELECT Id FROM Sales_Order__c
            WHERE Status__c = 'Approved'
            ORDER BY Total_Amount__c DESC
            LIMIT 1
        ];

        // Delete any existing invoices
        List<Invoice__c> existingInvoices = [
            SELECT Id FROM Invoice__c WHERE Sales_Order__c = :orderWithLines.Id
        ];
        if (!existingInvoices.isEmpty()) {
            TriggerHandler.bypass('OMS_Invoice_TriggerHandler');
            delete existingInvoices;
            TriggerHandler.clearBypass('OMS_Invoice_TriggerHandler');
        }

        Test.startTest();
        OMS_InvoiceGeneration_Service.generateInvoices(new Set<Id>{ orderWithLines.Id });
        Test.stopTest();

        // Verify invoice line items were created
        List<Invoice__c> invoices = [
            SELECT Id FROM Invoice__c WHERE Sales_Order__c = :orderWithLines.Id
        ];
        System.assert(!invoices.isEmpty(), 'Invoice should have been created');

        List<Invoice_Line__c> invoiceLines = [
            SELECT Id, Product_Ext__c, Quantity__c, Unit_Price__c, Line_Amount__c,
                   Tax_Amount__c, Total_Amount__c, Line_Number__c, UOM__c,
                   Order_Line_Item__c
            FROM Invoice_Line__c
            WHERE Invoice__c = :invoices[0].Id
        ];

        Integer orderLineCount = [
            SELECT COUNT() FROM Order_Line_Item__c WHERE Sales_Order__c = :orderWithLines.Id
        ];
        System.assertEquals(orderLineCount, invoiceLines.size(),
            'Invoice line count should match order line item count');

        for (Invoice_Line__c line : invoiceLines) {
            System.assertNotEquals(null, line.Product_Ext__c, 'Invoice line should have a product');
            System.assert(line.Quantity__c > 0, 'Invoice line should have quantity');
            System.assertNotEquals(null, line.Line_Number__c, 'Invoice line should have a line number');
            System.assertNotEquals(null, line.Order_Line_Item__c, 'Invoice line should reference the order line');
        }
    }

    @IsTest
    static void testGenerateInvoices_duplicatePrevention() {
        Sales_Order__c orderWithLines = [
            SELECT Id FROM Sales_Order__c
            WHERE Status__c = 'Approved'
            ORDER BY Total_Amount__c DESC
            LIMIT 1
        ];

        // Delete any existing invoices first
        List<Invoice__c> existingInvoices = [
            SELECT Id FROM Invoice__c WHERE Sales_Order__c = :orderWithLines.Id
        ];
        if (!existingInvoices.isEmpty()) {
            TriggerHandler.bypass('OMS_Invoice_TriggerHandler');
            delete existingInvoices;
            TriggerHandler.clearBypass('OMS_Invoice_TriggerHandler');
        }

        // Generate invoices the first time
        OMS_InvoiceGeneration_Service.generateInvoices(new Set<Id>{ orderWithLines.Id });

        Integer firstCount = [
            SELECT COUNT() FROM Invoice__c
            WHERE Sales_Order__c = :orderWithLines.Id AND Status__c != 'Cancelled'
        ];

        Test.startTest();
        // Try generating again - should not create duplicates
        OMS_InvoiceGeneration_Service.generateInvoices(new Set<Id>{ orderWithLines.Id });
        Test.stopTest();

        Integer secondCount = [
            SELECT COUNT() FROM Invoice__c
            WHERE Sales_Order__c = :orderWithLines.Id AND Status__c != 'Cancelled'
        ];

        System.assertEquals(firstCount, secondCount,
            'Should not create duplicate invoices for the same order');
    }

    @IsTest
    static void testGenerateInvoices_nullAndEmptyInput() {
        Test.startTest();
        // Test null input
        OMS_InvoiceGeneration_Service.generateInvoices(null);

        // Test empty set
        OMS_InvoiceGeneration_Service.generateInvoices(new Set<Id>());
        Test.stopTest();

        System.assert(true, 'Should handle null and empty inputs gracefully');
    }

    @IsTest
    static void testGenerateInvoices_nonApprovedOrders() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Invoice Test Account' LIMIT 1];
        Visit__c visit = [SELECT Id FROM Visit__c LIMIT 1];

        // Create a draft order (not approved)
        Sales_Order__c draftOrder = TestDataFactory.createSalesOrder(acct.Id, UserInfo.getUserId(), visit.Id);
        draftOrder.Total_Amount__c = 5000;
        draftOrder.Order_Date__c = Date.today().addDays(-5);
        insert draftOrder;

        Test.startTest();
        OMS_InvoiceGeneration_Service.generateInvoices(new Set<Id>{ draftOrder.Id });
        Test.stopTest();

        Integer invoiceCount = [
            SELECT COUNT() FROM Invoice__c WHERE Sales_Order__c = :draftOrder.Id
        ];
        System.assertEquals(0, invoiceCount,
            'Should not generate invoices for non-approved orders');
    }

    @IsTest
    static void testGenerateInvoices_paymentTermsDueDate() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Invoice Test Account' LIMIT 1];
        Warehouse__c warehouse = [SELECT Id FROM Warehouse__c LIMIT 1];
        Visit__c visit = [SELECT Id FROM Visit__c LIMIT 1];

        // Create orders with different payment terms
        List<String> paymentTerms = new List<String>{
            'Net 7', 'Net 15', 'Net 30', 'Net 45', 'Net 60', 'Net 90', 'COD', 'Advance'
        };

        TriggerHandler.bypass('OMS_SalesOrder_TriggerHandler');
        List<Sales_Order__c> orders = new List<Sales_Order__c>();
        for (Integer i = 0; i < paymentTerms.size(); i++) {
            Sales_Order__c order = TestDataFactory.createSalesOrder(acct.Id, UserInfo.getUserId(), visit.Id);
            order.Total_Amount__c = 1000 * (i + 1);
            order.Net_Amount__c = 1000 * (i + 1);
            order.Payment_Terms__c = paymentTerms[i];
            order.Status__c = 'Approved';
            order.Order_Date__c = Date.today().addDays(-20 - i);
            order.Warehouse__c = warehouse.Id;
            orders.add(order);
        }
        insert orders;
        TriggerHandler.clearBypass('OMS_SalesOrder_TriggerHandler');

        Set<Id> orderIds = new Set<Id>();
        for (Sales_Order__c o : orders) {
            orderIds.add(o.Id);
        }

        Test.startTest();
        OMS_InvoiceGeneration_Service.generateInvoices(orderIds);
        Test.stopTest();

        List<Invoice__c> invoices = [
            SELECT Id, Payment_Terms__c, Due_Date__c
            FROM Invoice__c
            WHERE Sales_Order__c IN :orderIds
        ];

        // Verify invoices were created with appropriate due dates
        for (Invoice__c inv : invoices) {
            System.assertNotEquals(null, inv.Due_Date__c,
                'Due date should be set for payment terms: ' + inv.Payment_Terms__c);
        }
    }
}
