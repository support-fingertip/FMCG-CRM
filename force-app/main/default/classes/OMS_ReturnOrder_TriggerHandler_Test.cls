/**
 * @description Test class for OMS_ReturnOrder_TriggerHandler.
 *              Validates return quantity enforcement, credit note generation,
 *              and warehouse stock restoration upon approval.
 * @author  SFA Development Team
 * @date    2024
 */
@IsTest
private class OMS_ReturnOrder_TriggerHandler_Test {

    @TestSetup
    static void setupTestData() {
        // Account
        Account acc = TestDataFactory.createAndInsertAccount('RO Test Outlet', 'Retailer');

        // Product
        Product_Extension__c prod = TestDataFactory.createProduct('RO Product', 'RO-0001');
        insert prod;

        // Warehouse
        Warehouse__c wh = new Warehouse__c(
            Name = 'RO Warehouse',
            Warehouse_Code__c = 'WH-RO01',
            Is_Active__c = true
        );
        insert wh;

        // Sales Order
        Sales_Order__c so = TestDataFactory.createSalesOrder(acc.Id, UserInfo.getUserId(), null);
        so.Status__c = 'Confirmed';
        insert so;

        // Invoice linked to warehouse
        Invoice__c inv = TestDataFactory.createInvoice(so.Id, acc.Id);
        inv.Warehouse__c = wh.Id;
        insert inv;

        // Invoice Line
        Invoice_Line__c invLine = new Invoice_Line__c(
            Invoice__c = inv.Id,
            Product_Ext__c = prod.Id,
            Quantity__c = 100,
            Unit_Price__c = 50,
            Line_Total__c = 5000
        );
        insert invLine;
    }

    // ── Helper accessors ─────────────────────────────────────────────────────

    private static Account getAccount() {
        return [SELECT Id FROM Account WHERE Name = 'RO Test Outlet' LIMIT 1];
    }
    private static Invoice__c getInvoice() {
        return [SELECT Id, Balance_Due__c FROM Invoice__c LIMIT 1];
    }
    private static Invoice_Line__c getInvoiceLine() {
        return [SELECT Id, Quantity__c, Product_Ext__c FROM Invoice_Line__c LIMIT 1];
    }

    // ── Before Insert: valid quantity ────────────────────────────────────────

    @IsTest
    static void testInsertValidReturnQuantity() {
        Account acc = getAccount();
        Invoice__c inv = getInvoice();
        Invoice_Line__c invLine = getInvoiceLine();

        Return_Order__c ro = new Return_Order__c(
            Account__c = acc.Id,
            Invoice__c = inv.Id,
            Invoice_Line__c = invLine.Id,
            Return_Quantity__c = 10,
            Return_Amount__c = 500,
            Return_Date__c = Date.today(),
            Status__c = 'Draft',
            Return_Reason__c = 'Damaged'
        );

        Test.startTest();
        insert ro;
        Test.stopTest();

        Return_Order__c inserted = [SELECT Id, Return_Quantity__c FROM Return_Order__c WHERE Id = :ro.Id];
        System.assertEquals(10, inserted.Return_Quantity__c, 'Return order should be inserted with quantity 10');
    }

    // ── Before Insert: quantity exceeds available ────────────────────────────

    @IsTest
    static void testInsertExceedingReturnQuantity() {
        Account acc = getAccount();
        Invoice__c inv = getInvoice();
        Invoice_Line__c invLine = getInvoiceLine();

        Return_Order__c ro = new Return_Order__c(
            Account__c = acc.Id,
            Invoice__c = inv.Id,
            Invoice_Line__c = invLine.Id,
            Return_Quantity__c = 999,
            Return_Amount__c = 49950,
            Return_Date__c = Date.today(),
            Status__c = 'Draft',
            Return_Reason__c = 'Damaged'
        );

        Test.startTest();
        try {
            insert ro;
            System.assert(false, 'Expected DmlException for exceeding quantity');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('exceeds available returnable quantity'),
                'Error should mention exceeding returnable quantity: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── Before Insert: zero/null quantity ────────────────────────────────────

    @IsTest
    static void testInsertZeroReturnQuantity() {
        Account acc = getAccount();
        Invoice__c inv = getInvoice();
        Invoice_Line__c invLine = getInvoiceLine();

        Return_Order__c ro = new Return_Order__c(
            Account__c = acc.Id,
            Invoice__c = inv.Id,
            Invoice_Line__c = invLine.Id,
            Return_Quantity__c = 0,
            Return_Amount__c = 0,
            Return_Date__c = Date.today(),
            Status__c = 'Draft',
            Return_Reason__c = 'Damaged'
        );

        Test.startTest();
        try {
            insert ro;
            System.assert(false, 'Expected DmlException for zero quantity');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('greater than zero'),
                'Error should mention quantity must be greater than zero: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ── Before Update: re-validates on quantity change ──────────────────────

    @IsTest
    static void testUpdateReturnQuantityRevalidation() {
        Account acc = getAccount();
        Invoice__c inv = getInvoice();
        Invoice_Line__c invLine = getInvoiceLine();

        Return_Order__c ro = new Return_Order__c(
            Account__c = acc.Id,
            Invoice__c = inv.Id,
            Invoice_Line__c = invLine.Id,
            Return_Quantity__c = 10,
            Return_Amount__c = 500,
            Return_Date__c = Date.today(),
            Status__c = 'Draft',
            Return_Reason__c = 'Damaged'
        );
        insert ro;

        Test.startTest();
        ro.Return_Quantity__c = 50;
        ro.Return_Amount__c = 2500;
        update ro;
        Test.stopTest();

        Return_Order__c updated = [SELECT Return_Quantity__c FROM Return_Order__c WHERE Id = :ro.Id];
        System.assertEquals(50, updated.Return_Quantity__c, 'Quantity should update to 50 (within limit)');
    }

    // ── Before Update: quantity change exceeds available ─────────────────────

    @IsTest
    static void testUpdateReturnQuantityExceeds() {
        Account acc = getAccount();
        Invoice__c inv = getInvoice();
        Invoice_Line__c invLine = getInvoiceLine();

        Return_Order__c ro = new Return_Order__c(
            Account__c = acc.Id,
            Invoice__c = inv.Id,
            Invoice_Line__c = invLine.Id,
            Return_Quantity__c = 10,
            Return_Amount__c = 500,
            Return_Date__c = Date.today(),
            Status__c = 'Draft',
            Return_Reason__c = 'Damaged'
        );
        insert ro;

        Test.startTest();
        try {
            ro.Return_Quantity__c = 999;
            update ro;
            System.assert(false, 'Expected DmlException for exceeding quantity on update');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('exceeds available returnable quantity'),
                'Error should mention exceeding returnable quantity');
        }
        Test.stopTest();
    }

    // ── After Update: approval generates credit note and updates balance ────

    @IsTest
    static void testApprovalGeneratesCreditNote() {
        Account acc = getAccount();
        Invoice__c inv = getInvoice();
        Invoice_Line__c invLine = getInvoiceLine();

        Return_Order__c ro = new Return_Order__c(
            Account__c = acc.Id,
            Invoice__c = inv.Id,
            Invoice_Line__c = invLine.Id,
            Return_Quantity__c = 10,
            Return_Amount__c = 500,
            Return_Date__c = Date.today(),
            Status__c = 'Draft',
            Return_Reason__c = 'Damaged'
        );
        insert ro;

        Test.startTest();
        ro.Status__c = 'Approved';
        update ro;
        Test.stopTest();

        // Verify credit note ledger entry created
        List<Ledger_Entry__c> entries = [
            SELECT Id, Entry_Type__c, Amount__c, Account__c, Invoice__c
            FROM Ledger_Entry__c
            WHERE Reference_Id__c = :ro.Id
        ];
        System.assertEquals(1, entries.size(), 'One credit note ledger entry should be created');
        System.assertEquals('Credit Note', entries[0].Entry_Type__c, 'Entry type should be Credit Note');
        System.assertEquals(500, entries[0].Amount__c, 'Credit amount should match return amount');

        // Verify invoice balance reduced
        Invoice__c updatedInv = [SELECT Balance_Due__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assert(updatedInv.Balance_Due__c < inv.Balance_Due__c,
            'Invoice balance should be reduced after credit note');
    }

    // ── After Update: non-approval status change should NOT generate credit ──

    @IsTest
    static void testNonApprovalStatusNoCredit() {
        Account acc = getAccount();
        Invoice__c inv = getInvoice();
        Invoice_Line__c invLine = getInvoiceLine();

        Return_Order__c ro = new Return_Order__c(
            Account__c = acc.Id,
            Invoice__c = inv.Id,
            Invoice_Line__c = invLine.Id,
            Return_Quantity__c = 5,
            Return_Amount__c = 250,
            Return_Date__c = Date.today(),
            Status__c = 'Draft',
            Return_Reason__c = 'Damaged'
        );
        insert ro;

        Test.startTest();
        ro.Status__c = 'Rejected';
        update ro;
        Test.stopTest();

        List<Ledger_Entry__c> entries = [
            SELECT Id FROM Ledger_Entry__c WHERE Reference_Id__c = :ro.Id
        ];
        System.assertEquals(0, entries.size(), 'No ledger entries should be created for rejected returns');
    }

    // ── Insert without invoice line (no validation on line) ─────────────────

    @IsTest
    static void testInsertWithoutInvoiceLine() {
        Account acc = getAccount();
        Invoice__c inv = getInvoice();

        Return_Order__c ro = new Return_Order__c(
            Account__c = acc.Id,
            Invoice__c = inv.Id,
            Return_Quantity__c = 5,
            Return_Amount__c = 250,
            Return_Date__c = Date.today(),
            Status__c = 'Draft',
            Return_Reason__c = 'Damaged'
        );

        Test.startTest();
        insert ro;
        Test.stopTest();

        System.assertNotEquals(null, ro.Id, 'Return order without invoice line should still insert');
    }

    // ── Multiple returns against same invoice line ──────────────────────────

    @IsTest
    static void testMultipleReturnsAgainstSameLine() {
        Account acc = getAccount();
        Invoice__c inv = getInvoice();
        Invoice_Line__c invLine = getInvoiceLine();

        // First return - 60 units
        Return_Order__c ro1 = new Return_Order__c(
            Account__c = acc.Id,
            Invoice__c = inv.Id,
            Invoice_Line__c = invLine.Id,
            Return_Quantity__c = 60,
            Return_Amount__c = 3000,
            Return_Date__c = Date.today(),
            Status__c = 'Draft',
            Return_Reason__c = 'Damaged'
        );
        insert ro1;

        // Second return - 50 units (total 110, exceeds 100 invoiced)
        Return_Order__c ro2 = new Return_Order__c(
            Account__c = acc.Id,
            Invoice__c = inv.Id,
            Invoice_Line__c = invLine.Id,
            Return_Quantity__c = 50,
            Return_Amount__c = 2500,
            Return_Date__c = Date.today(),
            Status__c = 'Draft',
            Return_Reason__c = 'Expired'
        );

        Test.startTest();
        try {
            insert ro2;
            System.assert(false, 'Expected DmlException for cumulative return exceeding invoiced qty');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('exceeds available returnable quantity'),
                'Error should mention exceeding available returnable quantity');
        }
        Test.stopTest();
    }
}
