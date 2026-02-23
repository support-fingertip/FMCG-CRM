/**
 * @description Test class for INV_StockTransferController.
 *              Tests transfer CRUD operations, submit, and receive flows.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class INV_StockTransferController_Test {

    @TestSetup
    static void setupTestData() {
        Warehouse__c sourceWh = new Warehouse__c(
            Name = 'Source Warehouse',
            Warehouse_Code__c = 'SRC01',
            State__c = 'Maharashtra',
            Warehouse_Type__c = 'Central',
            Is_Active__c = true
        );
        Warehouse__c destWh = new Warehouse__c(
            Name = 'Destination Warehouse',
            Warehouse_Code__c = 'DST01',
            State__c = 'Gujarat',
            Warehouse_Type__c = 'Regional',
            Is_Active__c = true
        );
        insert new List<Warehouse__c>{ sourceWh, destWh };

        Product2 product = new Product2(Name = 'Transfer Product', ProductCode = 'TRP01', IsActive = true);
        insert product;

        Warehouse_Stock__c stock = new Warehouse_Stock__c(
            Warehouse__c = sourceWh.Id,
            Product__c = product.Id,
            Qty_On_Hand__c = 200,
            Qty_Reserved__c = 0,
            Qty_Damaged__c = 0
        );
        insert stock;
    }

    @isTest
    static void testCreateTransfer() {
        Warehouse__c sourceWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'SRC01'];
        Warehouse__c destWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'DST01'];
        Product2 product = [SELECT Id FROM Product2 WHERE ProductCode = 'TRP01'];

        String lineItemsJson = '[{"productId":"' + product.Id + '","batchNumber":null,"requestedQty":50}]';

        Test.startTest();
        Id transferId = INV_StockTransferController.createTransfer(
            sourceWh.Id, destWh.Id, Date.today(), 'Test transfer', lineItemsJson
        );
        Test.stopTest();

        System.assertNotEquals(null, transferId, 'Transfer ID should not be null');

        Stock_Transfer__c transfer = [SELECT Status__c FROM Stock_Transfer__c WHERE Id = :transferId];
        System.assertEquals('Draft', transfer.Status__c, 'Transfer should be in Draft');

        List<Stock_Transfer_Line__c> lines = [
            SELECT Requested_Qty__c FROM Stock_Transfer_Line__c WHERE Stock_Transfer__c = :transferId
        ];
        System.assertEquals(1, lines.size(), 'Should have 1 line item');
        System.assertEquals(50, lines[0].Requested_Qty__c, 'Requested qty should be 50');
    }

    @isTest
    static void testGetTransfers() {
        // Create a transfer
        Warehouse__c sourceWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'SRC01'];
        Warehouse__c destWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'DST01'];

        Stock_Transfer__c transfer = new Stock_Transfer__c(
            Source_Warehouse__c = sourceWh.Id,
            Destination_Warehouse__c = destWh.Id,
            Transfer_Date__c = Date.today(),
            Status__c = 'Draft',
            Requested_By__c = UserInfo.getUserId()
        );
        insert transfer;

        Test.startTest();
        List<Stock_Transfer__c> transfers = INV_StockTransferController.getTransfers(sourceWh.Id, 'all');
        Test.stopTest();

        System.assertEquals(1, transfers.size(), 'Should find 1 transfer');
    }

    @isTest
    static void testGetTransferDetail() {
        Warehouse__c sourceWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'SRC01'];
        Warehouse__c destWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'DST01'];
        Product2 product = [SELECT Id FROM Product2 WHERE ProductCode = 'TRP01'];

        Stock_Transfer__c transfer = new Stock_Transfer__c(
            Source_Warehouse__c = sourceWh.Id,
            Destination_Warehouse__c = destWh.Id,
            Transfer_Date__c = Date.today(),
            Status__c = 'Draft'
        );
        insert transfer;

        Stock_Transfer_Line__c line = new Stock_Transfer_Line__c(
            Stock_Transfer__c = transfer.Id,
            Product__c = product.Id,
            Requested_Qty__c = 30
        );
        insert line;

        Test.startTest();
        INV_StockTransferController.TransferDetail detail =
            INV_StockTransferController.getTransferDetail(transfer.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail.transfer, 'Transfer should not be null');
        System.assertEquals(1, detail.lineItems.size(), 'Should have 1 line item');
    }

    @isTest
    static void testSubmitTransfer() {
        Warehouse__c sourceWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'SRC01'];
        Warehouse__c destWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'DST01'];

        Stock_Transfer__c transfer = new Stock_Transfer__c(
            Source_Warehouse__c = sourceWh.Id,
            Destination_Warehouse__c = destWh.Id,
            Transfer_Date__c = Date.today(),
            Status__c = 'Draft'
        );
        insert transfer;

        Test.startTest();
        INV_StockTransferController.submitTransfer(transfer.Id);
        Test.stopTest();

        transfer = [SELECT Status__c FROM Stock_Transfer__c WHERE Id = :transfer.Id];
        System.assertEquals('Submitted', transfer.Status__c, 'Should be Submitted');
    }

    @isTest
    static void testSubmitNonDraftFails() {
        Warehouse__c sourceWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'SRC01'];
        Warehouse__c destWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'DST01'];

        Stock_Transfer__c transfer = new Stock_Transfer__c(
            Source_Warehouse__c = sourceWh.Id,
            Destination_Warehouse__c = destWh.Id,
            Transfer_Date__c = Date.today(),
            Status__c = 'Submitted'
        );
        insert transfer;

        Test.startTest();
        try {
            INV_StockTransferController.submitTransfer(transfer.Id);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('draft'), 'Error should mention draft');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetAvailableProducts() {
        Warehouse__c sourceWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'SRC01'];

        Test.startTest();
        List<Warehouse_Stock__c> products =
            INV_StockTransferController.getAvailableProducts(sourceWh.Id, null);
        Test.stopTest();

        System.assertEquals(1, products.size(), 'Should find 1 available product');
    }

    @isTest
    static void testGetAvailableProductsWithSearch() {
        Warehouse__c sourceWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'SRC01'];

        Test.startTest();
        List<Warehouse_Stock__c> products =
            INV_StockTransferController.getAvailableProducts(sourceWh.Id, 'Transfer');
        Test.stopTest();

        System.assertEquals(1, products.size(), 'Should find 1 product matching search');
    }

    @isTest
    static void testReceiveTransfer() {
        Warehouse__c sourceWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'SRC01'];
        Warehouse__c destWh = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'DST01'];
        Product2 product = [SELECT Id FROM Product2 WHERE ProductCode = 'TRP01'];

        Stock_Transfer__c transfer = new Stock_Transfer__c(
            Source_Warehouse__c = sourceWh.Id,
            Destination_Warehouse__c = destWh.Id,
            Transfer_Date__c = Date.today(),
            Status__c = 'Approved'
        );
        insert transfer;

        Stock_Transfer_Line__c line = new Stock_Transfer_Line__c(
            Stock_Transfer__c = transfer.Id,
            Product__c = product.Id,
            Requested_Qty__c = 40,
            Approved_Qty__c = 40
        );
        insert line;

        String receivedJson = '[{"lineItemId":"' + line.Id + '","receivedQty":38}]';

        Test.startTest();
        INV_StockTransferController.receiveTransfer(transfer.Id, receivedJson);
        Test.stopTest();

        transfer = [SELECT Status__c FROM Stock_Transfer__c WHERE Id = :transfer.Id];
        System.assertEquals('Received', transfer.Status__c, 'Should be Received');

        line = [SELECT Received_Qty__c FROM Stock_Transfer_Line__c WHERE Id = :line.Id];
        System.assertEquals(38, line.Received_Qty__c, 'Received qty should be 38');
    }
}
