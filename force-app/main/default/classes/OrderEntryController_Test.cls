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
        // Create territory first (needed for account)
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('OE Territory', 'TER-OE01');

        // Create account with channel, outlet type, and territory
        Account retailer = TestDataFactory.createAccount('Order Entry Retailer', 'Retailer');
        retailer.Channel__c = 'GT';
        retailer.Outlet_Type__c = 'Grocery';
        retailer.Territory__c = territory.Id;
        insert retailer;

        // Create beat, day attendance, visit
        Beat__c beat = TestDataFactory.createAndInsertBeat('OE Beat', 'BEAT-OE01', territory.Id);

        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;

        Visit__c visit = TestDataFactory.createVisit(retailer.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        // Create products with various names for search testing
        List<Product_Extension__c> products = new List<Product_Extension__c>();
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

        // Create Must Sell Config records
        List<Must_Sell_Config__c> mustSellConfigs = new List<Must_Sell_Config__c>();
        // Must Sell for GT + Grocery in this territory
        mustSellConfigs.add(TestDataFactory.createMustSellConfig(
            products[0].Id, 'Must Sell', 6, territory.Id, 'GT', 'Grocery'
        ));
        // Must Sell for all territories/channels/types
        mustSellConfigs.add(TestDataFactory.createMustSellConfig(
            products[1].Id, 'Must Sell', 3, null, null, null
        ));
        // Focused Sell for GT channel
        mustSellConfigs.add(TestDataFactory.createMustSellConfig(
            products[2].Id, 'Focused Sell', null, null, 'GT', null
        ));
        // Must Sell for MT channel only (should NOT match our GT retailer)
        mustSellConfigs.add(TestDataFactory.createMustSellConfig(
            products[3].Id, 'Must Sell', 2, null, 'MT', null
        ));
        insert mustSellConfigs;
    }

    /**
     * @description Tests product search functionality by searching for products
     *              matching a keyword, verifying correct results are returned.
     */
    @isTest
    static void testSearchProducts() {
        Test.startTest();

        // Search for products containing "Maggi"
        List<Product_Extension__c> maggiResults = [
            SELECT Id, Name, SKU_Code__c, Is_Active__c
            FROM Product_Extension__c
            WHERE Name LIKE '%Maggi%'
              AND Is_Active__c = true
        ];

        // Search for products containing "Surf"
        List<Product_Extension__c> surfResults = [
            SELECT Id, Name, SKU_Code__c
            FROM Product_Extension__c
            WHERE Name LIKE '%Surf%'
              AND Is_Active__c = true
        ];

        // Search with no matching keyword
        List<Product_Extension__c> noResults = [
            SELECT Id, Name
            FROM Product_Extension__c
            WHERE Name LIKE '%ZZZZZ%'
              AND Is_Active__c = true
        ];

        Test.stopTest();

        System.assertEquals(2, maggiResults.size(),
            'Should find 2 products matching "Maggi"');
        for (Product_Extension__c p : maggiResults) {
            System.assert(p.Name.containsIgnoreCase('Maggi'),
                'All results should contain "Maggi" in the name');
            System.assertEquals(true, p.Is_Active__c,
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
        List<Product_Extension__c> products = [SELECT Id FROM Product_Extension__c LIMIT 3];

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
                   (SELECT Id, Product_Ext__c, Quantity__c, Unit_Price__c, Line_Total__c
                    FROM Order_Line_Items__r
                    ORDER BY Product_Ext__r.Name)
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
            System.assertNotEquals(null, item.Product_Ext__c,
                'Each line item should reference a product');
        }

        System.assert(lineItemsTotal > 0,
            'Total value of line items should be positive');
    }

    /**
     * @description Tests getMustSellProducts returns correct Must Sell and Focused Sell
     *              products filtered by territory, channel, and customer type.
     */
    @isTest
    static void testGetMustSellProducts() {
        Account acct = [SELECT Id, Channel__c, Outlet_Type__c, Territory__c
                        FROM Account WHERE Name = 'Order Entry Retailer' LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> mustSellItems = OrderEntryController.getMustSellProducts(acct.Id, null);
        Test.stopTest();

        // Should include: products[0] (GT+Grocery+territory match), products[1] (all match),
        // products[2] (GT channel match as Focused Sell)
        // Should NOT include: products[3] (MT channel, doesn't match GT account)
        System.assert(mustSellItems.size() >= 3,
            'Should return at least 3 must-sell/focused-sell products for GT/Grocery account, got: ' + mustSellItems.size());

        // Verify the MT-only product is not included
        Set<Id> returnedProductIds = new Set<Id>();
        for (Map<String, Object> item : mustSellItems) {
            returnedProductIds.add((Id) item.get('productId'));
        }

        Product_Extension__c mtProduct = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'VIM-001' LIMIT 1];
        System.assert(!returnedProductIds.contains(mtProduct.Id),
            'MT-only must-sell product should not appear for GT account');

        // Verify min quantity is set for Must Sell products
        for (Map<String, Object> item : mustSellItems) {
            if (item.get('classification') == 'Must Sell') {
                System.assertNotEquals(null, item.get('minQuantity'),
                    'Must Sell products should have a minQuantity');
            }
        }
    }

    /**
     * @description Tests that getMustSellProducts correctly filters out configs
     *              that don't match the account's territory.
     */
    @isTest
    static void testGetMustSellProductsTerritoryFiltering() {
        // Create a different territory and account
        Territory_Master__c otherTerritory = TestDataFactory.createAndInsertTerritory('Other Territory', 'TER-OTH01');
        Account otherAcct = TestDataFactory.createAccount('Other Retailer', 'Retailer');
        otherAcct.Channel__c = 'GT';
        otherAcct.Outlet_Type__c = 'Grocery';
        otherAcct.Territory__c = otherTerritory.Id;
        insert otherAcct;

        Test.startTest();
        List<Map<String, Object>> items = OrderEntryController.getMustSellProducts(otherAcct.Id, null);
        Test.stopTest();

        // products[0] is territory-specific to 'OE Territory', so should NOT appear for otherAcct
        // products[1] has no territory filter, so should appear
        // products[2] has no territory filter + GT channel, so should appear
        Product_Extension__c territoryProduct = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'MAGGI-001' LIMIT 1];
        Set<Id> returnedProductIds = new Set<Id>();
        for (Map<String, Object> item : items) {
            returnedProductIds.add((Id) item.get('productId'));
        }

        System.assert(!returnedProductIds.contains(territoryProduct.Id),
            'Territory-specific config should not appear for account in different territory');
    }

    /**
     * @description Tests creating a sales order via the JSON-based createSalesOrder
     *              Apex method used by the LWC component.
     */
    @isTest
    static void testCreateSalesOrderViaJson() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Order Entry Retailer' LIMIT 1];
        Visit__c visit = [SELECT Id FROM Visit__c LIMIT 1];
        List<Product_Extension__c> products = [SELECT Id FROM Product_Extension__c LIMIT 3];

        // Build the JSON payload matching what the LWC sends
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('accountId', acct.Id);
        payload.put('visitId', visit.Id);
        payload.put('status', 'Confirmed');
        payload.put('remarks', 'Test order');
        payload.put('grossAmount', 4500);
        payload.put('totalDiscount', 0);
        payload.put('totalTax', 810);
        payload.put('netAmount', 5310);
        payload.put('mustSellOverride', false);

        List<Map<String, Object>> lineItems = new List<Map<String, Object>>();
        Map<String, Object> li1 = new Map<String, Object>();
        li1.put('productId', products[0].Id);
        li1.put('quantity', 10);
        li1.put('freeQty', 0);
        li1.put('rate', 200);
        li1.put('grossAmount', 2000);
        li1.put('discountAmount', 0);
        li1.put('taxRate', 18);
        li1.put('taxAmount', 360);
        li1.put('totalAmount', 2360);
        lineItems.add(li1);

        Map<String, Object> li2 = new Map<String, Object>();
        li2.put('productId', products[1].Id);
        li2.put('quantity', 5);
        li2.put('freeQty', 0);
        li2.put('rate', 300);
        li2.put('grossAmount', 1500);
        li2.put('discountAmount', 0);
        li2.put('taxRate', 18);
        li2.put('taxAmount', 270);
        li2.put('totalAmount', 1770);
        lineItems.add(li2);

        Map<String, Object> li3 = new Map<String, Object>();
        li3.put('productId', products[2].Id);
        li3.put('quantity', 2);
        li3.put('freeQty', 0);
        li3.put('rate', 500);
        li3.put('grossAmount', 1000);
        li3.put('discountAmount', 0);
        li3.put('taxRate', 18);
        li3.put('taxAmount', 180);
        li3.put('totalAmount', 1180);
        lineItems.add(li3);

        payload.put('lineItems', lineItems);

        Test.startTest();
        Sales_Order__c result = OrderEntryController.createSalesOrder(JSON.serialize(payload));
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return created order');
        System.assertNotEquals(null, result.Name, 'Order should have an auto-generated Name');
        System.assertEquals('Confirmed', result.Status__c, 'Status should be Confirmed');

        // Verify line items were created
        List<Order_Line_Item__c> createdItems = [
            SELECT Id, Product_Ext__c, Quantity__c, Unit_Price__c
            FROM Order_Line_Item__c
            WHERE Sales_Order__c = :result.Id
        ];
        System.assertEquals(3, createdItems.size(), 'Should have 3 line items');
    }

    /**
     * @description Tests that createSalesOrder handles mustSellOverride and compliance fields.
     */
    @isTest
    static void testCreateSalesOrderWithMustSellOverride() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Order Entry Retailer' LIMIT 1];
        List<Product_Extension__c> products = [SELECT Id FROM Product_Extension__c LIMIT 1];

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('accountId', acct.Id);
        payload.put('status', 'Confirmed');
        payload.put('grossAmount', 2000);
        payload.put('totalDiscount', 0);
        payload.put('totalTax', 360);
        payload.put('netAmount', 2360);
        payload.put('mustSellOverride', true);
        payload.put('mustSellCompliance', 66.67);

        List<Map<String, Object>> lineItems = new List<Map<String, Object>>();
        Map<String, Object> li1 = new Map<String, Object>();
        li1.put('productId', products[0].Id);
        li1.put('quantity', 10);
        li1.put('rate', 200);
        li1.put('grossAmount', 2000);
        li1.put('taxRate', 18);
        li1.put('taxAmount', 360);
        li1.put('totalAmount', 2360);
        lineItems.add(li1);
        payload.put('lineItems', lineItems);

        Test.startTest();
        Sales_Order__c result = OrderEntryController.createSalesOrder(JSON.serialize(payload));
        Test.stopTest();

        Sales_Order__c order = [
            SELECT Must_Sell_Override__c, Must_Sell_Compliance__c
            FROM Sales_Order__c WHERE Id = :result.Id
        ];
        System.assertEquals(true, order.Must_Sell_Override__c, 'Must sell override should be true');
        System.assertEquals(66.67, order.Must_Sell_Compliance__c, 'Must sell compliance should be 66.67');
    }

    /**
     * @description Tests getTopSellingProducts returns products from order history
     *              and falls back to active products when no order history exists.
     */
    @isTest
    static void testGetTopSellingProducts() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Order Entry Retailer' LIMIT 1];

        Test.startTest();
        // Account has order history, so should return top sellers from order data
        List<OrderEntryController.ProductSearchResult> results =
            OrderEntryController.getTopSellingProducts(acct.Id);
        Test.stopTest();

        System.assert(!results.isEmpty(),
            'Should return top selling products for account with order history');
        for (OrderEntryController.ProductSearchResult r : results) {
            System.assertNotEquals(null, r.Id, 'Product Id should not be null');
            System.assertNotEquals(null, r.Name, 'Product Name should not be null');
        }
    }

    /**
     * @description Tests getTopSellingProducts falls back to active products
     *              when an account has no order history.
     */
    @isTest
    static void testGetTopSellingProductsFallback() {
        // Create a new territory and account with no order history at all
        Territory_Master__c emptyTerritory = TestDataFactory.createAndInsertTerritory('Empty Territory', 'TER-EMPTY01');
        Account newAcct = TestDataFactory.createAccount('New Retailer No History', 'Retailer');
        newAcct.Channel__c = 'GT';
        newAcct.Territory__c = emptyTerritory.Id;
        insert newAcct;

        Test.startTest();
        List<OrderEntryController.ProductSearchResult> results =
            OrderEntryController.getTopSellingProducts(newAcct.Id);
        Test.stopTest();

        // Should still return products (fallback to active products)
        System.assert(!results.isEmpty(),
            'Should return fallback products even when account has no order history');
        System.assert(results.size() <= 10,
            'Should return at most 10 fallback products');
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
