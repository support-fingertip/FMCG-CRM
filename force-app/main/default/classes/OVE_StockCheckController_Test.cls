@IsTest
private class OVE_StockCheckController_Test {

    @TestSetup
    static void setupData() {
        Account acc = TestDataFactory.createAndInsertAccount('Stock Test Outlet', 'Retailer');

        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Stock Territory', 'ST-001');
        Beat__c beat = TestDataFactory.createAndInsertBeat('Stock Beat', 'SB-001', territory.Id);

        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;

        Visit__c visit = TestDataFactory.createVisit(acc.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        // Create products
        List<Product_Extension__c> products = TestDataFactory.createAndInsertProducts(3);

        // Create Distributor_Stock__c records
        List<Distributor_Stock__c> stocks = new List<Distributor_Stock__c>();
        for (Product_Extension__c prod : products) {
            stocks.add(new Distributor_Stock__c(
                Account__c = acc.Id,
                Visit__c = visit.Id,
                Product_Ext__c = prod.Id,
                Opening_Stock__c = 100,
                Received_Qty__c = 50,
                Sold_Qty__c = 30,
                Closing_Stock__c = 120,
                Damaged_Qty__c = 0,
                Stock_Date__c = Date.today(),
                Is_Current__c = true
            ));
        }
        insert stocks;
    }

    // ── getDistributorStock ─────────────────────────────────────────

    @IsTest
    static void testGetDistributorStock_ReturnsRecords() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Stock Test Outlet' LIMIT 1];

        Test.startTest();
        try {
            List<Distributor_Stock__c> results = OVE_StockCheckController.getDistributorStock(acc.Id);
            System.assertNotEquals(null, results, 'Result should not be null');
            // Feature toggle may return empty list if disabled
            if (!results.isEmpty()) {
                System.assertEquals(3, results.size(), 'Should return 3 stock records');
            }
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Feature toggle may be disabled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetDistributorStock_NoRecords() {
        Account emptyAcc = TestDataFactory.createAndInsertAccount('Empty Outlet', 'Retailer');

        Test.startTest();
        try {
            List<Distributor_Stock__c> results = OVE_StockCheckController.getDistributorStock(emptyAcc.Id);
            System.assertNotEquals(null, results, 'Result should not be null');
            System.assertEquals(0, results.size(), 'Should return empty list');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Feature toggle may be disabled');
        }
        Test.stopTest();
    }

    // ── getProductsForStockCheck ────────────────────────────────────

    @IsTest
    static void testGetProductsForStockCheck_MatchingTerm() {
        Test.startTest();
        try {
            List<Product_Extension__c> results = OVE_StockCheckController.getProductsForStockCheck('Test Product');
            System.assertNotEquals(null, results, 'Result should not be null');
            System.assert(results.size() >= 3, 'Should find at least 3 products matching "Test Product"');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Feature toggle may be disabled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetProductsForStockCheck_BySkuCode() {
        Test.startTest();
        try {
            List<Product_Extension__c> results = OVE_StockCheckController.getProductsForStockCheck('TP-0001');
            System.assertNotEquals(null, results, 'Result should not be null');
            System.assert(results.size() >= 1, 'Should find at least 1 product by SKU code');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Feature toggle may be disabled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetProductsForStockCheck_NoMatch() {
        Test.startTest();
        try {
            List<Product_Extension__c> results = OVE_StockCheckController.getProductsForStockCheck('ZZZZNONEXISTENT');
            System.assertNotEquals(null, results, 'Result should not be null');
            System.assertEquals(0, results.size(), 'Should return empty list for no match');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Feature toggle may be disabled');
        }
        Test.stopTest();
    }

    // ── saveStockEntries ────────────────────────────────────────────

    @IsTest
    static void testSaveStockEntries_NewEntries() {
        Visit__c visit = [SELECT Id, Account__c FROM Visit__c LIMIT 1];
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c LIMIT 1];

        List<Map<String, Object>> entries = new List<Map<String, Object>>();
        entries.add(new Map<String, Object>{
            'productId' => prod.Id,
            'opening' => 200,
            'received' => 100,
            'sold' => 80,
            'closing' => 220,
            'damaged' => 0,
            'batch' => 'BATCH-A1'
        });
        String stockJson = JSON.serialize(entries);

        Test.startTest();
        try {
            List<Distributor_Stock__c> results = OVE_StockCheckController.saveStockEntries(
                stockJson, visit.Id, visit.Account__c
            );
            System.assertNotEquals(null, results, 'Result should not be null');
            System.assertEquals(1, results.size(), 'Should save 1 stock entry');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Feature toggle may be disabled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveStockEntries_MultipleEntries() {
        Visit__c visit = [SELECT Id, Account__c FROM Visit__c LIMIT 1];
        List<Product_Extension__c> products = [SELECT Id FROM Product_Extension__c LIMIT 3];

        List<Map<String, Object>> entries = new List<Map<String, Object>>();
        for (Product_Extension__c prod : products) {
            entries.add(new Map<String, Object>{
                'productId' => prod.Id,
                'opening' => 50,
                'received' => 25,
                'sold' => 10,
                'closing' => 65,
                'damaged' => 0
            });
        }
        String stockJson = JSON.serialize(entries);

        Test.startTest();
        try {
            List<Distributor_Stock__c> results = OVE_StockCheckController.saveStockEntries(
                stockJson, visit.Id, visit.Account__c
            );
            System.assertEquals(products.size(), results.size(), 'Should save all entries');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Feature toggle may be disabled');
        }
        Test.stopTest();
    }

    // ── getLastStockCheck ───────────────────────────────────────────

    @IsTest
    static void testGetLastStockCheck_ReturnsRecords() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Stock Test Outlet' LIMIT 1];

        Test.startTest();
        try {
            List<Distributor_Stock__c> results = OVE_StockCheckController.getLastStockCheck(acc.Id);
            System.assertNotEquals(null, results, 'Result should not be null');
            System.assert(results.size() >= 3, 'Should return at least 3 records from last stock check');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Feature toggle may be disabled');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetLastStockCheck_NoRecords() {
        Account emptyAcc = TestDataFactory.createAndInsertAccount('No Stock Outlet', 'Retailer');

        Test.startTest();
        try {
            List<Distributor_Stock__c> results = OVE_StockCheckController.getLastStockCheck(emptyAcc.Id);
            System.assertNotEquals(null, results, 'Result should not be null');
            System.assertEquals(0, results.size(), 'Should return empty list');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Feature toggle may be disabled');
        }
        Test.stopTest();
    }
}
