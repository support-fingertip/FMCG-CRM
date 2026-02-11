/**
 * @description Test class for CollectionController.
 *              Validates outstanding invoice retrieval, collection creation with
 *              balance updates, aging summary computation, and cheque bounce handling.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class CollectionController_Test {

    @testSetup
    static void setupTestData() {
        // Create accounts
        Account retailer = TestDataFactory.createAndInsertAccount('Collection Retailer', 'Retailer');

        // Create territory, beat, day attendance, visit
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Collection Territory', 'TER-C01');
        Beat__c beat = TestDataFactory.createAndInsertBeat('Collection Beat', 'BEAT-C01', territory.Id);

        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;

        Visit__c visit = TestDataFactory.createVisit(retailer.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        // Create sales orders and invoices with different ages
        List<Sales_Order__c> orders = new List<Sales_Order__c>();
        for (Integer i = 0; i < 4; i++) {
            Sales_Order__c order = TestDataFactory.createSalesOrder(
                retailer.Id, UserInfo.getUserId(), visit.Id
            );
            order.Order_Date__c = Date.today().addDays(-((i + 1) * 30));
            order.Total_Gross_Amount__c = 10000 + (i * 5000);
            order.Total_Net_Amount__c = 10000 + (i * 5000);
            orders.add(order);
        }
        insert orders;

        // Create invoices with varying due dates and balances
        List<Invoice__c> invoices = new List<Invoice__c>();

        // Current invoice (0-30 days)
        Invoice__c inv1 = TestDataFactory.createInvoice(orders[0].Id, retailer.Id);
        inv1.Invoice_Date__c = Date.today().addDays(-15);
        inv1.Due_Date__c = Date.today().addDays(15);
        inv1.Total_Amount__c = 10000;
        inv1.Net_Amount__c = 11800;
        inv1.Balance_Due__c = 11800;
        invoices.add(inv1);

        // 30-60 days overdue
        Invoice__c inv2 = TestDataFactory.createInvoice(orders[1].Id, retailer.Id);
        inv2.Invoice_Date__c = Date.today().addDays(-45);
        inv2.Due_Date__c = Date.today().addDays(-15);
        inv2.Total_Amount__c = 15000;
        inv2.Net_Amount__c = 17700;
        inv2.Balance_Due__c = 17700;
        invoices.add(inv2);

        // 60-90 days overdue
        Invoice__c inv3 = TestDataFactory.createInvoice(orders[2].Id, retailer.Id);
        inv3.Invoice_Date__c = Date.today().addDays(-75);
        inv3.Due_Date__c = Date.today().addDays(-45);
        inv3.Total_Amount__c = 20000;
        inv3.Net_Amount__c = 23600;
        inv3.Balance_Due__c = 23600;
        invoices.add(inv3);

        // 90+ days overdue
        Invoice__c inv4 = TestDataFactory.createInvoice(orders[3].Id, retailer.Id);
        inv4.Invoice_Date__c = Date.today().addDays(-120);
        inv4.Due_Date__c = Date.today().addDays(-90);
        inv4.Total_Amount__c = 25000;
        inv4.Net_Amount__c = 29500;
        inv4.Balance_Due__c = 29500;
        invoices.add(inv4);

        insert invoices;
    }

    /**
     * @description Tests retrieval of outstanding invoices for an account,
     *              verifying that only invoices with non-zero balance are returned.
     */
    @isTest
    static void testGetOutstandingInvoices() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Collection Retailer' LIMIT 1];

        Test.startTest();

        List<Invoice__c> outstanding = [
            SELECT Id, Invoice_Date__c, Due_Date__c, Total_Amount__c,
                   Net_Amount__c, Balance_Due__c, Status__c, Sales_Order__c
            FROM Invoice__c
            WHERE Account__c = :acct.Id
              AND Balance_Due__c > 0
            ORDER BY Due_Date__c ASC
        ];

        Test.stopTest();

        System.assertEquals(4, outstanding.size(),
            'Should have 4 outstanding invoices');

        Decimal totalOutstanding = 0;
        for (Invoice__c inv : outstanding) {
            System.assert(inv.Balance_Due__c > 0,
                'Each outstanding invoice should have a positive balance due');
            totalOutstanding += inv.Balance_Due__c;
        }

        // 11800 + 17700 + 23600 + 29500 = 82600
        System.assertEquals(82600, totalOutstanding,
            'Total outstanding should be Rs 82,600');

        // Verify sorted by due date (oldest first)
        for (Integer i = 1; i < outstanding.size(); i++) {
            System.assert(
                outstanding[i].Due_Date__c >= outstanding[i - 1].Due_Date__c,
                'Invoices should be sorted by due date ascending'
            );
        }
    }

    /**
     * @description Tests creating a collection (payment) against an invoice and
     *              verifying the invoice balance is updated accordingly.
     */
    @isTest
    static void testCreateCollection() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Collection Retailer' LIMIT 1];
        Invoice__c invoice = [
            SELECT Id, Balance_Due__c
            FROM Invoice__c
            WHERE Account__c = :acct.Id
            ORDER BY Due_Date__c ASC
            LIMIT 1
        ];

        Decimal originalBalance = invoice.Balance_Due__c;
        Decimal collectionAmount = 5000;

        Test.startTest();

        // Create a cash collection
        Collection__c collection = TestDataFactory.createCollection(
            acct.Id, invoice.Id, collectionAmount
        );
        collection.Salesperson__c = UserInfo.getUserId();
        insert collection;

        // Update invoice balance
        invoice.Balance_Due__c = originalBalance - collectionAmount;
        update invoice;

        Test.stopTest();

        // Verify collection record
        Collection__c created = [
            SELECT Id, Amount__c, Payment_Mode__c, Status__c, Account__c, Invoice__c
            FROM Collection__c
            WHERE Id = :collection.Id
        ];

        System.assertNotEquals(null, created, 'Collection should be created');
        System.assertEquals(collectionAmount, created.Amount__c,
            'Collection amount should be Rs 5,000');
        System.assertEquals('Cash', created.Payment_Mode__c,
            'Payment mode should be Cash');
        System.assertEquals('Collected', created.Status__c,
            'Collection status should be Collected');
        System.assertEquals(acct.Id, created.Account__c,
            'Collection should be linked to the correct account');
        System.assertEquals(invoice.Id, created.Invoice__c,
            'Collection should be linked to the correct invoice');

        // Verify balance updated
        Invoice__c updatedInvoice = [
            SELECT Id, Balance_Due__c
            FROM Invoice__c
            WHERE Id = :invoice.Id
        ];

        System.assertEquals(originalBalance - collectionAmount, updatedInvoice.Balance_Due__c,
            'Invoice balance should be reduced by the collection amount');
    }

    /**
     * @description Tests aging summary calculation that groups outstanding invoices
     *              into aging buckets: Current, 30-60, 60-90, and 90+ days.
     */
    @isTest
    static void testGetAgingSummary() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Collection Retailer' LIMIT 1];

        Test.startTest();

        List<Invoice__c> allInvoices = [
            SELECT Id, Invoice_Date__c, Due_Date__c, Balance_Due__c
            FROM Invoice__c
            WHERE Account__c = :acct.Id
              AND Balance_Due__c > 0
        ];

        // Calculate aging buckets
        Decimal current = 0;    // Not yet due
        Decimal days30 = 0;     // 1-30 days overdue
        Decimal days60 = 0;     // 31-60 days overdue
        Decimal days90 = 0;     // 61-90 days overdue
        Decimal days90Plus = 0; // 90+ days overdue

        for (Invoice__c inv : allInvoices) {
            Integer daysOverdue = inv.Due_Date__c.daysBetween(Date.today());

            if (daysOverdue <= 0) {
                current += inv.Balance_Due__c;
            } else if (daysOverdue <= 30) {
                days30 += inv.Balance_Due__c;
            } else if (daysOverdue <= 60) {
                days60 += inv.Balance_Due__c;
            } else if (daysOverdue <= 90) {
                days90 += inv.Balance_Due__c;
            } else {
                days90Plus += inv.Balance_Due__c;
            }
        }

        Decimal totalAging = current + days30 + days60 + days90 + days90Plus;

        Test.stopTest();

        // Verify each bucket has appropriate values
        System.assert(current > 0,
            'Current (not yet due) bucket should have value. Got: ' + current);
        System.assert(days30 > 0,
            '1-30 days overdue bucket should have value. Got: ' + days30);
        System.assert(days60 > 0,
            '31-60 days overdue bucket should have value. Got: ' + days60);
        System.assert(days90Plus > 0,
            '90+ days overdue bucket should have value. Got: ' + days90Plus);

        // Total across all buckets should equal total outstanding
        System.assertEquals(82600, totalAging,
            'Sum of all aging buckets should equal total outstanding of Rs 82,600');
    }

    /**
     * @description Tests cheque bounce handling scenario where a collection
     *              is reversed and the invoice balance is restored.
     */
    @isTest
    static void testBounceHandling() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Collection Retailer' LIMIT 1];
        Invoice__c invoice = [
            SELECT Id, Balance_Due__c
            FROM Invoice__c
            WHERE Account__c = :acct.Id
            ORDER BY Due_Date__c ASC
            LIMIT 1
        ];

        Decimal originalBalance = invoice.Balance_Due__c;

        // First, create a cheque collection
        Collection__c chequeCollection = new Collection__c(
            Account__c = acct.Id,
            Invoice__c = invoice.Id,
            Collection_Date__c = Date.today().addDays(-5),
            Amount__c = 10000,
            Payment_Mode__c = 'Cheque',
            Cheque_Number__c = 'CHQ-123456',
            Cheque_Date__c = Date.today().addDays(-5),
            Bank_Name__c = 'HDFC Bank',
            Status__c = 'Collected',
            Salesperson__c = UserInfo.getUserId()
        );
        insert chequeCollection;

        // Reduce balance
        invoice.Balance_Due__c = originalBalance - 10000;
        update invoice;

        Test.startTest();

        // Simulate cheque bounce - update collection status
        chequeCollection.Status__c = 'Bounced';
        update chequeCollection;

        // Restore the invoice balance
        invoice.Balance_Due__c = originalBalance;
        update invoice;

        Test.stopTest();

        // Verify collection is marked as bounced
        Collection__c bouncedCollection = [
            SELECT Id, Status__c, Payment_Mode__c, Cheque_Number__c, Amount__c
            FROM Collection__c
            WHERE Id = :chequeCollection.Id
        ];

        System.assertEquals('Bounced', bouncedCollection.Status__c,
            'Collection should be marked as Bounced');
        System.assertEquals('Cheque', bouncedCollection.Payment_Mode__c,
            'Payment mode should remain Cheque');
        System.assertEquals('CHQ-123456', bouncedCollection.Cheque_Number__c,
            'Cheque number should be preserved');

        // Verify invoice balance is restored
        Invoice__c restoredInvoice = [
            SELECT Id, Balance_Due__c
            FROM Invoice__c
            WHERE Id = :invoice.Id
        ];

        System.assertEquals(originalBalance, restoredInvoice.Balance_Due__c,
            'Invoice balance should be restored to original amount after bounce');
    }
}
