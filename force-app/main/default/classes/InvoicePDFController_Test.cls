@IsTest
private class InvoicePDFController_Test {

    @TestSetup
    static void setupData() {
        Account acc = TestDataFactory.createAndInsertAccount('Test Customer', 'Retailer');

        Sales_Order__c so = TestDataFactory.createSalesOrder(acc.Id, UserInfo.getUserId(), null);
        so.Total_Net_Amount__c = 11800;
        insert so;

        Invoice__c inv = TestDataFactory.createInvoice(so.Id, acc.Id);
        insert inv;

        List<Product_Extension__c> products = TestDataFactory.createAndInsertProducts(2);

        List<Invoice_Line__c> lines = new List<Invoice_Line__c>();
        lines.add(new Invoice_Line__c(
            Invoice__c = inv.Id,
            Product_Ext__c = products[0].Id,
            Quantity__c = 10,
            Unit_Price__c = 500,
            Line_Total__c = 5000,
            HSN_SAC_Code__c = '19011010',
            CGST__c = 450,
            SGST__c = 450,
            IGST__c = 0,
            Tax_Amount__c = 900
        ));
        lines.add(new Invoice_Line__c(
            Invoice__c = inv.Id,
            Product_Ext__c = products[1].Id,
            Quantity__c = 5,
            Unit_Price__c = 1000,
            Line_Total__c = 5000,
            HSN_SAC_Code__c = '19011020',
            CGST__c = 450,
            SGST__c = 450,
            IGST__c = 0,
            Tax_Amount__c = 900
        ));
        insert lines;

        // Create a cleared collection so amountPaid is populated
        Collection__c col = TestDataFactory.createCollection(acc.Id, inv.Id, 3000);
        col.Status__c = 'Cleared';
        insert col;
    }

    @IsTest
    static void testConstructorPopulatesAllFields() {
        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];

        Test.startTest();
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(inv);
        InvoicePDFController controller = new InvoicePDFController(stdCtrl);
        Test.stopTest();

        System.assertNotEquals(null, controller.invoice, 'invoice should be populated');
        System.assertNotEquals(null, controller.invoice.Account__r.Name, 'Account name should be queried');
        System.assertNotEquals(null, controller.lineItems, 'lineItems should be populated');
        System.assertEquals(2, controller.lineItems.size(), 'Should have 2 line items');
        System.assertNotEquals(null, controller.amountInWords, 'amountInWords should be populated');
        System.assertEquals(30, controller.creditDays, 'creditDays should default to 30');
    }

    @IsTest
    static void testAmountPaidCalculated() {
        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];

        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(inv);
        InvoicePDFController controller = new InvoicePDFController(stdCtrl);

        System.assertEquals(3000, controller.amountPaid, 'amountPaid should aggregate cleared collections');
    }

    @IsTest
    static void testLineItemWrapperIndex() {
        Invoice__c inv = [SELECT Id FROM Invoice__c LIMIT 1];

        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(inv);
        InvoicePDFController controller = new InvoicePDFController(stdCtrl);

        System.assertEquals(1, controller.lineItems[0].index, 'First line item index should be 1');
        System.assertEquals(2, controller.lineItems[1].index, 'Second line item index should be 2');
        System.assertNotEquals(null, controller.lineItems[0].line, 'Line item record should be populated');
    }

    @IsTest
    static void testInvoiceWithNoCollections() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Sales_Order__c so = [SELECT Id FROM Sales_Order__c LIMIT 1];

        Invoice__c inv = new Invoice__c(
            Sales_Order__c = so.Id,
            Account__c = acc.Id,
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(30),
            Status__c = 'Confirmed',
            Total_Amount__c = 5000,
            Tax_Amount__c = 900,
            Net_Amount__c = 5900,
            Balance_Due__c = 5900
        );
        insert inv;

        Test.startTest();
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(inv);
        InvoicePDFController controller = new InvoicePDFController(stdCtrl);
        Test.stopTest();

        System.assertEquals(0, controller.amountPaid, 'amountPaid should be 0 when no cleared collections');
        System.assertEquals(0, controller.lineItems.size(), 'Should have no line items');
    }

    @IsTest
    static void testAmountInWordsZero() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Sales_Order__c so = [SELECT Id FROM Sales_Order__c LIMIT 1];

        Invoice__c inv = new Invoice__c(
            Sales_Order__c = so.Id,
            Account__c = acc.Id,
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(30),
            Status__c = 'Draft',
            Total_Amount__c = 0,
            Tax_Amount__c = 0,
            Net_Amount__c = 0,
            Balance_Due__c = 0
        );
        insert inv;

        Test.startTest();
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(inv);
        InvoicePDFController controller = new InvoicePDFController(stdCtrl);
        Test.stopTest();

        System.assertEquals('Zero', controller.amountInWords, 'Zero net amount should return "Zero"');
    }

    @IsTest
    static void testAmountInWordsNullNetAmount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Sales_Order__c so = [SELECT Id FROM Sales_Order__c LIMIT 1];

        Invoice__c inv = new Invoice__c(
            Sales_Order__c = so.Id,
            Account__c = acc.Id,
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(30),
            Status__c = 'Draft',
            Total_Amount__c = 0,
            Tax_Amount__c = 0,
            Net_Amount__c = null,
            Balance_Due__c = 0
        );
        insert inv;

        Test.startTest();
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(inv);
        InvoicePDFController controller = new InvoicePDFController(stdCtrl);
        Test.stopTest();

        System.assertEquals('Zero', controller.amountInWords, 'Null net amount should return "Zero"');
    }

    @IsTest
    static void testAmountInWordsLargeNumber() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Sales_Order__c so = [SELECT Id FROM Sales_Order__c LIMIT 1];

        Invoice__c inv = new Invoice__c(
            Sales_Order__c = so.Id,
            Account__c = acc.Id,
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(30),
            Status__c = 'Confirmed',
            Total_Amount__c = 20000000,
            Tax_Amount__c = 0,
            Net_Amount__c = 20000000,
            Balance_Due__c = 20000000
        );
        insert inv;

        Test.startTest();
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(inv);
        InvoicePDFController controller = new InvoicePDFController(stdCtrl);
        Test.stopTest();

        System.assert(controller.amountInWords.contains('Crore'), 'Should contain Crore for 2 crore');
    }
}
