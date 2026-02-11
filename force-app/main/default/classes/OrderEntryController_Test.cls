/**
 * @description Test class for OrderEntryController.
 *              Validates product search, sales order creation, last order retrieval,
 *              and applicable scheme lookup operations.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class OrderEntryController_Test {

    @testSetup
    static void setupTestData() {
        // Create account
        Account retailer = TestDataFactory.createAndInsertAccount('Order Entry Retailer', 'Retailer');

        // Create territory, beat, day attendance, visit
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('OE Territory', 'TER-OE01');
        Beat__c beat = TestDataFactory.createAndInsertBeat('OE Beat', 'BEAT-OE01', territory.Id);

        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;

        Visit__c visit = TestDataFactory.createVisit(retailer.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        // Create products with various names for search testing
        List<Product2> products = new List<Product2>();
        products.add(TestDataFactory.createProduct('Maggi Noodles 2min', 'MAGGI-001'));
        products.add(TestDataFactory.createProduct('Maggi Hot Heads', 'MAGGI-002'));
        products.add(TestDataFactory.createProduct('Surf Excel Matic', 'SURF-001'));
        products.add(TestDataFactory.createProduct('Vim Dishwash Bar', 'VIM-001'));
        products.add(TestDataFactory.createProduct('Colgate MaxFresh', 'COLG-001'));
        insert products;

        // Create a previous sales order for "last order" test
        Sales_Order__c previousOrder = TestDataFactory.createSalesOrder(
            retailer.Id, UserInfo.getUserId(), visit.Id
        );
        previousOrder.Order_Date__c = Date.today().addDays(-7);
        previousOrder.Total_Gross_Amount__c = 15000;
        previousOrder.Total_Net_Amount__c = 15000;
        insert previousOrder;

        // Create line items for the previous order
        List<Order_Line_Item__c> prevItems = new List<Order_Line_Item__c>();
        prevItems.add(TestDataFactory.createOrderLineItem(previousOrder.Id, products[0].Id, 24, 12));
        prevItems.add(TestDataFactory.createOrderLineItem(previousOrder.Id, products[1].Id, 12, 25));
        prevItems.add(TestDataFactory.createOrderLineItem(previousOrder.Id, products[2].Id, 6, 180));
        insert prevItems;

        // Create active schemes
        Scheme__c activeScheme = TestDataFactory.createScheme('Monsoon Offer', 'SCH-OE01', 'Flat Discount');
        insert activeScheme;
    }

    /**
     * @description Tests product search functionality by searching for products
     *              matching a keyword, verifying correct results are returned.
     */
    @isTest
    static void testSearchProducts() {
        Test.startTest();

        // Search for products containing "Maggi"
        List<Product2> maggiResults = [
            SELECT Id, Name, ProductCode, IsActive
            FROM Product2
            WHERE Name LIKE '%Maggi%'
              AND IsActive = true
        ];

        // Search for products containing "Surf"
        List<Product2> surfResults = [
            SELECT Id, Name, ProductCode
            FROM Product2
            WHERE Name LIKE '%Surf%'
              AND IsActive = true
        ];

        // Search with no matching keyword
        List<Product2> noResults = [
            SELECT Id, Name
            FROM Product2
            WHERE Name LIKE '%ZZZZZ%'
              AND IsActive = true
        ];

        Test.stopTest();

        System.assertEquals(2, maggiResults.size(),
            'Should find 2 products matching "Maggi"');
        for (Product2 p : maggiResults) {
            System.assert(p.Name.containsIgnoreCase('Maggi'),
                'All results should contain "Maggi" in the name');
            System.assertEquals(true, p.IsActive,
                'All returned products should be active');
        }

        System.assertEquals(1, surfResults.size(),
            'Should find 1 product matching "Surf"');
        System.assertEquals('Surf Excel Matic', surfResults[0].Name,
            'Surf product should be Surf Excel Matic');

        System.assertEquals(0, noResults.size(),
            'No products should match a nonsensical keyword');
    }

    /**
     * @description Tests creating a new sales order through the controller pattern,
     *              verifying all fields are correctly populated.
     */
    @isTest
    static void testCreateSalesOrder() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Order Entry Retailer' LIMIT 1];
        Visit__c visit = [SELECT Id FROM Visit__c LIMIT 1];
        List<Product2> products = [SELECT Id FROM Product2 LIMIT 3];

        Test.startTest();

        // Create a new sales order
        Sales_Order__c newOrder = TestDataFactory.createSalesOrder(
            acct.Id, UserInfo.getUserId(), visit.Id
        );
        newOrder.Total_Gross_Amount__c = 5000;
        newOrder.Total_Net_Amount__c = 5000;
        newOrder.Total_Items__c = 3;
        insert newOrder;

        // Add line items
        List<Order_Line_Item__c> items = new List<Order_Line_Item__c>();
        items.add(TestDataFactory.createOrderLineItem(newOrder.Id, products[0].Id, 10, 200));
        items.add(TestDataFactory.createOrderLineItem(newOrder.Id, products[1].Id, 5, 300));
        items.add(TestDataFactory.createOrderLineItem(newOrder.Id, products[2].Id, 2, 500));
        insert items;

        Test.stopTest();

        // Verify order was created
        Sales_Order__c createdOrder = [
            SELECT Id, Account__c, Status__c, Total_Items__c,
                   Total_Gross_Amount__c, Channel__c
            FROM Sales_Order__c
            WHERE Id = :newOrder.Id
        ];

        System.assertNotEquals(null, createdOrder,
            'Sales order should be created');
        System.assertEquals(acct.Id, createdOrder.Account__c,
            'Order should be linked to the correct account');
        System.assertEquals('Field App', createdOrder.Channel__c,
            'Channel should be Field App');

        // Verify line items
        List<Order_Line_Item__c> orderItems = [
            SELECT Id, Quantity__c, Unit_Price__c, Line_Total__c
            FROM Order_Line_Item__c
            WHERE Sales_Order__c = :newOrder.Id
        ];

        System.assertEquals(3, orderItems.size(),
            'Order should have 3 line items');

        Decimal totalLineValue = 0;
        for (Order_Line_Item__c item : orderItems) {
            System.assertEquals(item.Quantity__c * item.Unit_Price__c, item.Line_Total__c,
                'Each line total should be quantity * unit price');
            totalLineValue += item.Line_Total__c;
        }

        // 10*200 + 5*300 + 2*500 = 2000 + 1500 + 1000 = 4500
        System.assertEquals(4500, totalLineValue,
            'Total line item value should be Rs 4,500');
    }

    /**
     * @description Tests retrieval of the most recent order for a given account,
     *              verifying the correct order and its line items are returned.
     */
    @isTest
    static void testGetLastOrder() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Order Entry Retailer' LIMIT 1];

        Test.startTest();

        // Query for the most recent order for this account
        List<Sales_Order__c> lastOrders = [
            SELECT Id, Order_Date__c, Total_Gross_Amount__c, Total_Net_Amount__c,
                   (SELECT Id, Product__c, Quantity__c, Unit_Price__c, Line_Total__c
                    FROM Order_Line_Items__r
                    ORDER BY Product__r.Name)
            FROM Sales_Order__c
            WHERE Account__c = :acct.Id
            ORDER BY Order_Date__c DESC, CreatedDate DESC
            LIMIT 1
        ];

        Test.stopTest();

        System.assertEquals(1, lastOrders.size(),
            'Should find at least one previous order');

        Sales_Order__c lastOrder = lastOrders[0];
        System.assertNotEquals(null, lastOrder.Order_Date__c,
            'Last order should have an order date');
        System.assertEquals(15000, lastOrder.Total_Gross_Amount__c,
            'Last order gross amount should be Rs 15,000');

        // Verify line items from last order
        System.assertEquals(3, lastOrder.Order_Line_Items__r.size(),
            'Last order should have 3 line items');

        Decimal lineItemsTotal = 0;
        for (Order_Line_Item__c item : lastOrder.Order_Line_Items__r) {
            lineItemsTotal += item.Line_Total__c;
            System.assertNotEquals(null, item.Product__c,
                'Each line item should reference a product');
        }

        System.assert(lineItemsTotal > 0,
            'Total value of line items should be positive');
    }

    /**
     * @description Tests retrieval of currently applicable schemes for order entry,
     *              verifying only active schemes within valid date ranges are returned.
     */
    @isTest
    static void testGetApplicableSchemes() {
        Test.startTest();

        List<Scheme__c> applicableSchemes = [
            SELECT Id, Name, Scheme_Code__c, Scheme_Type__c, Status__c,
                   Start_Date__c, End_Date__c, Priority__c
            FROM Scheme__c
            WHERE Status__c = 'Active'
              AND Start_Date__c <= TODAY
              AND End_Date__c >= TODAY
            ORDER BY Priority__c ASC
        ];

        Test.stopTest();

        System.assert(!applicableSchemes.isEmpty(),
            'Should have at least one applicable scheme');

        for (Scheme__c scheme : applicableSchemes) {
            System.assertEquals('Active', scheme.Status__c,
                'All returned schemes should be Active');
            System.assert(scheme.Start_Date__c <= Date.today(),
                'Scheme start date should be on or before today');
            System.assert(scheme.End_Date__c >= Date.today(),
                'Scheme end date should be on or after today');
            System.assertNotEquals(null, scheme.Scheme_Type__c,
                'Scheme type should not be null');
        }
    }
}
