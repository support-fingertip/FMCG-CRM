/**
 * @description Test class for INV_WarehouseStock_TriggerHandler.
 *              Tests unique constraint enforcement and default value setting.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class INV_WarehouseStock_TriggerHandler_Test {

    @TestSetup
    static void setupTestData() {
        Warehouse__c warehouse = new Warehouse__c(
            Name = 'Test Warehouse',
            Warehouse_Code__c = 'TW001',
            State__c = 'Maharashtra',
            Warehouse_Type__c = 'Central',
            Is_Active__c = true
        );
        insert warehouse;

        Product2 product = new Product2(Name = 'Test Product', ProductCode = 'TP001', IsActive = true);
        insert product;
    }

    @isTest
    static void testCreateStockWithDefaults() {
        Warehouse__c wh = [SELECT Id FROM Warehouse__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        Test.startTest();
        Warehouse_Stock__c stock = new Warehouse_Stock__c(
            Warehouse__c = wh.Id,
            Product__c = product.Id
        );
        insert stock;
        Test.stopTest();

        stock = [SELECT Qty_On_Hand__c, Qty_Reserved__c, Qty_Damaged__c FROM Warehouse_Stock__c WHERE Id = :stock.Id];
        System.assertEquals(0, stock.Qty_On_Hand__c, 'Default on hand should be 0');
        System.assertEquals(0, stock.Qty_Reserved__c, 'Default reserved should be 0');
        System.assertEquals(0, stock.Qty_Damaged__c, 'Default damaged should be 0');
    }

    @isTest
    static void testDuplicateWarehouseProductBatchFails() {
        Warehouse__c wh = [SELECT Id FROM Warehouse__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        Warehouse_Stock__c stock1 = new Warehouse_Stock__c(
            Warehouse__c = wh.Id,
            Product__c = product.Id,
            Batch_Number__c = 'BATCH001',
            Qty_On_Hand__c = 50
        );
        insert stock1;

        Test.startTest();
        Warehouse_Stock__c stock2 = new Warehouse_Stock__c(
            Warehouse__c = wh.Id,
            Product__c = product.Id,
            Batch_Number__c = 'BATCH001',
            Qty_On_Hand__c = 25
        );
        try {
            insert stock2;
            System.assert(false, 'Should have thrown duplicate error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('already exists') || e.getMessage().contains('duplicate'),
                'Error should mention duplicate: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testDifferentBatchesAllowed() {
        Warehouse__c wh = [SELECT Id FROM Warehouse__c LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];

        Warehouse_Stock__c stock1 = new Warehouse_Stock__c(
            Warehouse__c = wh.Id,
            Product__c = product.Id,
            Batch_Number__c = 'BATCH001',
            Qty_On_Hand__c = 50
        );
        insert stock1;

        Test.startTest();
        Warehouse_Stock__c stock2 = new Warehouse_Stock__c(
            Warehouse__c = wh.Id,
            Product__c = product.Id,
            Batch_Number__c = 'BATCH002',
            Qty_On_Hand__c = 25
        );
        insert stock2;
        Test.stopTest();

        List<Warehouse_Stock__c> stocks = [
            SELECT Id FROM Warehouse_Stock__c WHERE Warehouse__c = :wh.Id AND Product__c = :product.Id
        ];
        System.assertEquals(2, stocks.size(), 'Should allow different batches');
    }
}
