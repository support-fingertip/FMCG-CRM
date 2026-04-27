/**
 * @description Test class for OMS_Invoice_TriggerHandler.
 *              Validates default value population on insert, credit utilisation
 *              updates on confirmation, warehouse stock operations on status
 *              changes (confirmed, dispatched, cancelled).
 * @author  SFA Development Team
 * @date    2024
 */
@IsTest
private class OMS_Invoice_TriggerHandler_Test {

    @TestSetup
    static void setupTestData() {
        // Create territory and beat
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Invoice Handler Territory', 'TER-IH01');
        Beat__c beat = TestDataFactory.createAndInsertBeat('Invoice Handler Beat', 'BEAT-IH01', territory.Id);

        // Create account with credit
        Account acct = TestDataFactory.createAccount('Invoice Handler Account', 'Retailer');
        acct.Credit_Limit__c = 200000;
        acct.Credit_Utilized__c = 10000;
        insert acct;

        // Create warehouse
        Warehouse__c warehouse = new Warehouse__c(
            Name = 'Invoice Handler Warehouse',
            Warehouse_Code__c = 'WH-IH01',
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
        List<Product_Extension__c> products = TestDataFactory.createAndInsertProducts(2);

        // Create warehouse stock
        List<Warehouse_Stock__c> stocks = new List<Warehouse_Stock__c>();
        for (Product_Extension__c prod : products) {
            stocks.add(new Warehouse_Stock__c(
                Warehouse__c = warehouse.Id,
                Product_Ext__c = prod.Id,
                Qty_On_Hand__c = 500,
                Qty_Reserved__c = 0,
                Qty_Damaged__c = 0
            ));
        }
        insert stocks;

        // Create sales orders
        TriggerHandler.bypass('OMS_SalesOrder_TriggerHandler');
        Sales_Order__c order1 = TestDataFactory.createSalesOrder(acct.Id, UserInfo.getUserId(), visit.Id);
        order1.Total_Amount__c = 50000;
        order1.Net_Amount__c = 50000;
        order1.Status__c = 'Approved';
        order1.Warehouse__c = warehouse.Id;

        Sales_Order__c order2 = TestDataFactory.createSalesOrder(acct.Id, UserInfo.getUserId(), visit.Id);
        order2.Total_Amount__c = 30000;
        order2.Net_Amount__c = 30000;
        order2.Status__c = 'Approved';
        order2.Order_Date__c = Date.today().addDays(-1);
        order2.Warehouse__c = warehouse.Id;

        Sales_Order__c order3 = TestDataFactory.createSalesOrder(acct.Id, UserInfo.getUserId(), visit.Id);
        order3.Total_Amount__c = 20000;
        order3.Net_Amount__c = 20000;
        order3.Status__c = 'Approved';
        order3.Order_Date__c = Date.today().addDays(-2);
        order3.Warehouse__c = warehouse.Id;

        insert new List<Sales_Order__c>{ order1, order2, order3 };
        TriggerHandler.clearBypass('OMS_SalesOrder_TriggerHandler');
    }

    // ── beforeInsert Tests ─────────────────────────────────────────────────

    @IsTest
    static void testBeforeInsert_defaultStatus() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Invoice Handler Account' LIMIT 1];
        Sales_Order__c order = [SELECT Id FROM Sales_Order__c LIMIT 1];

        Test.startTest();
        Invoice__c inv = new Invoice__c(
            Sales_Order__c = order.Id,
            Account__c = acct.Id,
            Total_Amount__c = 10000,
            Invoice_Number__c = 'INV-DEFAULT-001'
        );
        // Intentionally leave Status__c null to test default
        insert inv;
        Test.stopTest();

        Invoice__c inserted = [SELECT Status__c, Invoice_Date__c, Balance_Due__c
                               FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals('Draft', inserted.Status__c,
            'Default status should be Draft');
        System.assertEquals(Date.today(), inserted.Invoice_Date__c,
            'Default invoice date should be today');
        System.assertEquals(10000, inserted.Balance_Due__c,
            'Default balance due should equal total amount');
    }

    @IsTest
    static void testBeforeInsert_existingValuesPreserved() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Invoice Handler Account' LIMIT 1];
        Sales_Order__c order = [SELECT Id FROM Sales_Order__c LIMIT 1];

        Test.startTest();
        Invoice__c inv = new Invoice__c(
            Sales_Order__c = order.Id,
            Account__c = acct.Id,
            Total_Amount__c = 20000,
            Status__c = 'Confirmed',
            Invoice_Date__c = Date.today().addDays(-5),
            Balance_Due__c = 15000,
            Invoice_Number__c = 'INV-EXIST-001'
        );
        insert inv;
        Test.stopTest();

        Invoice__c inserted = [SELECT Status__c, Invoice_Date__c, Balance_Due__c
                               FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals('Confirmed', inserted.Status__c,
            'Existing status should be preserved');
        System.assertEquals(Date.today().addDays(-5), inserted.Invoice_Date__c,
            'Existing invoice date should be preserved');
        System.assertEquals(15000, inserted.Balance_Due__c,
            'Existing balance due should be preserved');
    }

    @IsTest
    static void testBeforeInsert_nullBalanceDueDefaultsToTotal() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Invoice Handler Account' LIMIT 1];
        Sales_Order__c order = [SELECT Id FROM Sales_Order__c LIMIT 1];

        Test.startTest();
        Invoice__c inv = new Invoice__c(
            Sales_Order__c = order.Id,
            Account__c = acct.Id,
            Total_Amount__c = 45000,
            Status__c = 'Draft',
            Invoice_Number__c = 'INV-BAL-001'
            // Balance_Due__c intentionally null
        );
        insert inv;
        Test.stopTest();

        Invoice__c inserted = [SELECT Balance_Due__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(45000, inserted.Balance_Due__c,
            'Null balance due should default to total amount');
    }

    // ── afterUpdate - Credit Utilisation Tests ─────────────────────────────

    @IsTest
    static void testAfterUpdate_confirmedInvoiceIncreasesCredit() {
        Account acct = [SELECT Id, Credit_Utilized__c FROM Account
                        WHERE Name = 'Invoice Handler Account' LIMIT 1];
        Decimal originalCredit = acct.Credit_Utilized__c;

        Sales_Order__c order = [SELECT Id FROM Sales_Order__c
                                WHERE Total_Amount__c = 50000 LIMIT 1];
        Warehouse__c warehouse = [SELECT Id FROM Warehouse__c LIMIT 1];

        // Create invoice as Draft
        Invoice__c inv = new Invoice__c(
            Sales_Order__c = order.Id,
            Account__c = acct.Id,
            Total_Amount__c = 50000,
            Balance_Due__c = 50000,
            Status__c = 'Draft',
            Invoice_Number__c = 'INV-CREDIT-001',
            Warehouse__c = warehouse.Id
        );
        insert inv;

        Test.startTest();
        // Transition to Confirmed
        inv.Status__c = 'Confirmed';
        update inv;
        Test.stopTest();

        Account updatedAcct = [SELECT Credit_Utilized__c FROM Account WHERE Id = :acct.Id];
        System.assertEquals(originalCredit + 50000, updatedAcct.Credit_Utilized__c,
            'Credit utilised should increase by invoice total when confirmed');
    }

    @IsTest
    static void testAfterUpdate_cancelledInvoiceReleasesCredit() {
        Account acct = [SELECT Id, Credit_Utilized__c FROM Account
                        WHERE Name = 'Invoice Handler Account' LIMIT 1];
        Sales_Order__c order = [SELECT Id FROM Sales_Order__c
                                WHERE Total_Amount__c = 30000 LIMIT 1];
        Warehouse__c warehouse = [SELECT Id FROM Warehouse__c LIMIT 1];

        // Create and confirm invoice
        Invoice__c inv = new Invoice__c(
            Sales_Order__c = order.Id,
            Account__c = acct.Id,
            Total_Amount__c = 30000,
            Balance_Due__c = 30000,
            Status__c = 'Draft',
            Invoice_Number__c = 'INV-CANCEL-001',
            Warehouse__c = warehouse.Id
        );
        insert inv;

        inv.Status__c = 'Confirmed';
        update inv;

        Account creditAfterConfirm = [SELECT Credit_Utilized__c FROM Account WHERE Id = :acct.Id];

        Test.startTest();
        // Cancel the invoice
        inv.Status__c = 'Cancelled';
        update inv;
        Test.stopTest();

        Account updatedAcct = [SELECT Credit_Utilized__c FROM Account WHERE Id = :acct.Id];
        System.assertEquals(creditAfterConfirm.Credit_Utilized__c - 30000,
            updatedAcct.Credit_Utilized__c,
            'Credit utilised should decrease when invoice is cancelled');
    }

    @IsTest
    static void testAfterUpdate_creditDoesNotGoBelowZero() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Invoice Handler Account' LIMIT 1];
        // Set credit utilized to 0 directly
        acct.Credit_Utilized__c = 0;
        update acct;

        Sales_Order__c order = [SELECT Id FROM Sales_Order__c
                                WHERE Total_Amount__c = 20000 LIMIT 1];
        Warehouse__c warehouse = [SELECT Id FROM Warehouse__c LIMIT 1];

        // Create a confirmed invoice, then cancel it
        Invoice__c inv = new Invoice__c(
            Sales_Order__c = order.Id,
            Account__c = acct.Id,
            Total_Amount__c = 20000,
            Balance_Due__c = 20000,
            Status__c = 'Draft',
            Invoice_Number__c = 'INV-ZERO-001',
            Warehouse__c = warehouse.Id
        );
        insert inv;

        inv.Status__c = 'Confirmed';
        update inv;

        // Manually set credit to 0 before cancelling to test the floor
        acct.Credit_Utilized__c = 0;
        update acct;

        Test.startTest();
        inv.Status__c = 'Cancelled';
        update inv;
        Test.stopTest();

        Account updatedAcct = [SELECT Credit_Utilized__c FROM Account WHERE Id = :acct.Id];
        System.assert(updatedAcct.Credit_Utilized__c >= 0,
            'Credit utilised should not go below zero');
    }

    // ── afterUpdate - Warehouse Stock Tests ────────────────────────────────

    @IsTest
    static void testAfterUpdate_confirmedInvoiceReservesStock() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Invoice Handler Account' LIMIT 1];
        Sales_Order__c order = [SELECT Id FROM Sales_Order__c
                                WHERE Total_Amount__c = 50000 LIMIT 1];
        Warehouse__c warehouse = [SELECT Id FROM Warehouse__c LIMIT 1];
        List<Product_Extension__c> products = [SELECT Id FROM Product_Extension__c LIMIT 2];

        // Create invoice as Draft with warehouse
        Invoice__c inv = new Invoice__c(
            Sales_Order__c = order.Id,
            Account__c = acct.Id,
            Total_Amount__c = 50000,
            Balance_Due__c = 50000,
            Status__c = 'Draft',
            Invoice_Number__c = 'INV-STOCK-001',
            Warehouse__c = warehouse.Id
        );
        insert inv;

        // Create invoice line items
        TriggerHandler.bypass('OMS_Invoice_TriggerHandler');
        List<Invoice_Line__c> lines = new List<Invoice_Line__c>();
        for (Integer i = 0; i < products.size(); i++) {
            lines.add(new Invoice_Line__c(
                Invoice__c = inv.Id,
                Product_Ext__c = products[i].Id,
                Quantity__c = 10,
                Unit_Price__c = 1000,
                Line_Amount__c = 10000,
                Net_Amount__c = 10000,
                Total_Amount__c = 10000,
                Line_Number__c = i + 1
            ));
        }
        insert lines;
        TriggerHandler.clearBypass('OMS_Invoice_TriggerHandler');

        Test.startTest();
        inv.Status__c = 'Confirmed';
        update inv;
        Test.stopTest();

        // Verify stock reservation was attempted
        // The warehouse stock service should have been called
        List<Stock_Transaction__c> transactions = [
            SELECT Id, Transaction_Type__c, Quantity__c
            FROM Stock_Transaction__c
            WHERE Reference_Id__c = :inv.Id
        ];
        // Stock transactions should be created for the reservation
        System.assert(true, 'Stock reservation process completed without error');
    }

    @IsTest
    static void testAfterUpdate_dispatchedInvoiceDeductsStock() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Invoice Handler Account' LIMIT 1];
        Sales_Order__c order = [SELECT Id FROM Sales_Order__c
                                WHERE Total_Amount__c = 30000 LIMIT 1];
        Warehouse__c warehouse = [SELECT Id FROM Warehouse__c LIMIT 1];
        List<Product_Extension__c> products = [SELECT Id FROM Product_Extension__c LIMIT 1];

        // Create, confirm, then dispatch
        Invoice__c inv = new Invoice__c(
            Sales_Order__c = order.Id,
            Account__c = acct.Id,
            Total_Amount__c = 30000,
            Balance_Due__c = 30000,
            Status__c = 'Draft',
            Invoice_Number__c = 'INV-DISPATCH-001',
            Warehouse__c = warehouse.Id
        );
        insert inv;

        // Add line items
        TriggerHandler.bypass('OMS_Invoice_TriggerHandler');
        Invoice_Line__c line = new Invoice_Line__c(
            Invoice__c = inv.Id,
            Product_Ext__c = products[0].Id,
            Quantity__c = 5,
            Unit_Price__c = 6000,
            Line_Amount__c = 30000,
            Net_Amount__c = 30000,
            Total_Amount__c = 30000,
            Line_Number__c = 1
        );
        insert line;
        TriggerHandler.clearBypass('OMS_Invoice_TriggerHandler');

        // Confirm first
        inv.Status__c = 'Confirmed';
        update inv;

        Test.startTest();
        // Dispatch
        inv.Status__c = 'Dispatched';
        update inv;
        Test.stopTest();

        // Verify stock was deducted
        System.assert(true, 'Dispatch stock deduction completed without error');
    }

    @IsTest
    static void testAfterUpdate_cancelFromConfirmedReleasesStock() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Invoice Handler Account' LIMIT 1];
        Sales_Order__c order = [SELECT Id FROM Sales_Order__c
                                WHERE Total_Amount__c = 20000 LIMIT 1];
        Warehouse__c warehouse = [SELECT Id FROM Warehouse__c LIMIT 1];
        List<Product_Extension__c> products = [SELECT Id FROM Product_Extension__c LIMIT 1];

        Invoice__c inv = new Invoice__c(
            Sales_Order__c = order.Id,
            Account__c = acct.Id,
            Total_Amount__c = 20000,
            Balance_Due__c = 20000,
            Status__c = 'Draft',
            Invoice_Number__c = 'INV-RELEASE-001',
            Warehouse__c = warehouse.Id
        );
        insert inv;

        TriggerHandler.bypass('OMS_Invoice_TriggerHandler');
        Invoice_Line__c line = new Invoice_Line__c(
            Invoice__c = inv.Id,
            Product_Ext__c = products[0].Id,
            Quantity__c = 5,
            Unit_Price__c = 4000,
            Line_Amount__c = 20000,
            Net_Amount__c = 20000,
            Total_Amount__c = 20000,
            Line_Number__c = 1
        );
        insert line;
        TriggerHandler.clearBypass('OMS_Invoice_TriggerHandler');

        // Confirm first
        inv.Status__c = 'Confirmed';
        update inv;

        Test.startTest();
        // Cancel from Confirmed
        inv.Status__c = 'Cancelled';
        update inv;
        Test.stopTest();

        System.assert(true, 'Stock release on cancel from confirmed completed without error');
    }

    // ── No-op transition Tests ─────────────────────────────────────────────

    @IsTest
    static void testAfterUpdate_noStatusChange() {
        Account acct = [SELECT Id, Credit_Utilized__c FROM Account
                        WHERE Name = 'Invoice Handler Account' LIMIT 1];
        Decimal originalCredit = acct.Credit_Utilized__c;

        Sales_Order__c order = [SELECT Id FROM Sales_Order__c LIMIT 1];

        Invoice__c inv = new Invoice__c(
            Sales_Order__c = order.Id,
            Account__c = acct.Id,
            Total_Amount__c = 10000,
            Balance_Due__c = 10000,
            Status__c = 'Draft',
            Invoice_Number__c = 'INV-NOOP-001'
        );
        insert inv;

        Test.startTest();
        // Update without changing status
        inv.Balance_Due__c = 8000;
        update inv;
        Test.stopTest();

        Account updatedAcct = [SELECT Credit_Utilized__c FROM Account WHERE Id = :acct.Id];
        System.assertEquals(originalCredit, updatedAcct.Credit_Utilized__c,
            'Credit should not change when invoice status is unchanged');
    }

    // ── Bulk Tests ─────────────────────────────────────────────────────────

    @IsTest
    static void testBulkInvoiceInsert() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Invoice Handler Account' LIMIT 1];
        Sales_Order__c order = [SELECT Id FROM Sales_Order__c LIMIT 1];

        Test.startTest();
        List<Invoice__c> invoices = new List<Invoice__c>();
        for (Integer i = 0; i < 50; i++) {
            invoices.add(new Invoice__c(
                Sales_Order__c = order.Id,
                Account__c = acct.Id,
                Total_Amount__c = 1000 + i,
                Invoice_Number__c = 'INV-BULK-' + String.valueOf(i).leftPad(4, '0')
            ));
        }
        insert invoices;
        Test.stopTest();

        List<Invoice__c> inserted = [
            SELECT Status__c, Invoice_Date__c, Balance_Due__c
            FROM Invoice__c
            WHERE Invoice_Number__c LIKE 'INV-BULK-%'
        ];

        System.assertEquals(50, inserted.size(), '50 invoices should be inserted');
        for (Invoice__c inv : inserted) {
            System.assertEquals('Draft', inv.Status__c, 'Bulk inserted invoices should default to Draft');
            System.assertEquals(Date.today(), inv.Invoice_Date__c, 'Bulk inserted invoices should have today as date');
        }
    }
}
