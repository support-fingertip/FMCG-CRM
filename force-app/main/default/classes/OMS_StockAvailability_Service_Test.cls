@isTest
private class OMS_StockAvailability_Service_Test {

    @isTest
    static void testStockAvailable() {
        Account acc = TestDataFactory.createAndInsertAccount('Test Retailer', 'Retailer');
        acc.Credit_Limit__c = 1000000;
        acc.Credit_Utilized__c = 0;
        update acc;

        Product_Extension__c prod = TestDataFactory.createProduct('Test Product', 'TP-001');
        insert prod;

        Sales_Order__c order = TestDataFactory.createSalesOrder(acc.Id, UserInfo.getUserId(), null);
        order.Status__c = 'Draft';
        insert order;

        Order_Line_Item__c li = TestDataFactory.createOrderLineItem(order.Id, prod.Id, 10, 100);
        insert li;

        Test.startTest();
        Map<Id, List<String>> results = OMS_StockAvailability_Service.validateStockAvailability(
            new Set<Id>{ order.Id }
        );
        Test.stopTest();

        // Without warehouse set, stock check should still return results
        System.assertNotEquals(null, results);
        System.assert(results.containsKey(order.Id));
    }

    @isTest
    static void testEmptyOrderIds() {
        Test.startTest();
        Map<Id, List<String>> results = OMS_StockAvailability_Service.validateStockAvailability(
            new Set<Id>()
        );
        Test.stopTest();

        System.assert(results.isEmpty());
    }
}
