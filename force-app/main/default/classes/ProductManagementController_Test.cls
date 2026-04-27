@IsTest
private class ProductManagementController_Test {

    @TestSetup
    static void setupData() {
        // Categories
        Product_Category__c parentCat = new Product_Category__c(
            Name = 'Foods',
            Category_Code__c = 'CAT-FOODS',
            Level__c = 'Category',
            Is_Active__c = true,
            Sort_Order__c = 1
        );
        insert parentCat;

        Product_Category__c childCat = new Product_Category__c(
            Name = 'Biscuits',
            Category_Code__c = 'CAT-BISC',
            Level__c = 'Sub-Category',
            Is_Active__c = true,
            Sort_Order__c = 2,
            Parent_Category__c = parentCat.Id
        );
        insert childCat;

        // Products
        Product_Extension__c prod1 = new Product_Extension__c(
            Name = 'Test Biscuit',
            SKU_Code__c = 'SKU-001',
            Brand__c = 'TestBrand',
            Is_Active__c = true,
            MRP__c = 50,
            Unit_Price__c = 40,
            GST_Rate__c = 18,
            Product_Category__c = childCat.Id,
            HSN_SAC_Code__c = '19011010'
        );
        Product_Extension__c prod2 = new Product_Extension__c(
            Name = 'Test Chips',
            SKU_Code__c = 'SKU-002',
            Brand__c = 'OtherBrand',
            Is_Active__c = true,
            MRP__c = 30,
            Unit_Price__c = 25,
            GST_Rate__c = 12,
            Product_Category__c = childCat.Id
        );
        Product_Extension__c prod3 = new Product_Extension__c(
            Name = 'Inactive Product',
            SKU_Code__c = 'SKU-003',
            Brand__c = 'TestBrand',
            Is_Active__c = false,
            MRP__c = 100,
            Unit_Price__c = 80
        );
        insert new List<Product_Extension__c>{ prod1, prod2, prod3 };

        // Territory
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Mumbai West', 'MW-001');

        // Account (customer)
        Account acc = TestDataFactory.createAndInsertAccount('Test Retailer', 'Retailer');

        // Price Lists
        Price_List__c pl1 = new Price_List__c(
            Product_Ext__c = prod1.Id,
            Channel__c = 'General Trade',
            Unit_Price__c = 42,
            Is_Active__c = true,
            Priority__c = 1,
            Effective_From__c = Date.today().addDays(-10),
            Effective_To__c = Date.today().addDays(90)
        );
        Price_List__c pl2 = new Price_List__c(
            Product_Ext__c = prod2.Id,
            Channel__c = 'Modern Trade',
            Unit_Price__c = 27,
            Is_Active__c = true,
            Priority__c = 2,
            Territory__c = territory.Id,
            Customer__c = acc.Id,
            Effective_From__c = Date.today().addDays(-5),
            Effective_To__c = Date.today().addDays(60)
        );
        insert new List<Price_List__c>{ pl1, pl2 };

        // Batch Master
        Batch_Master__c batch1 = new Batch_Master__c(
            Batch_Number__c = 'BATCH-001',
            Product_Ext__c = prod1.Id,
            Manufacturing_Date__c = Date.today().addDays(-30),
            Expiry_Date__c = Date.today().addDays(180),
            Status__c = 'Active',
            Quantity_Manufactured__c = 1000
        );
        Batch_Master__c batch2 = new Batch_Master__c(
            Batch_Number__c = 'BATCH-002',
            Product_Ext__c = prod1.Id,
            Manufacturing_Date__c = Date.today().addDays(-365),
            Expiry_Date__c = Date.today().addDays(-10),
            Status__c = 'Active',
            Quantity_Manufactured__c = 500
        );
        insert new List<Batch_Master__c>{ batch1, batch2 };

        // Must-Sell Config
        Must_Sell_Config__c msc = TestDataFactory.createMustSellConfig(
            prod1.Id, 'A', 5, territory.Id, 'General Trade', 'Retailer'
        );
        insert msc;

        // UOM Master
        UOM__c uomPieces = new UOM__c(
            Name = 'Pieces',
            UOM_Code__c = 'PCS',
            UOM_Type__c = 'Count',
            Is_Base_Unit__c = true,
            Is_Active__c = true
        );
        UOM__c uomCase = new UOM__c(
            Name = 'Case',
            UOM_Code__c = 'CS',
            UOM_Type__c = 'Count',
            Is_Base_Unit__c = false,
            Is_Active__c = true
        );
        insert new List<UOM__c>{ uomPieces, uomCase };

        // UOM Conversion
        UOM_Conversion__c conv = new UOM_Conversion__c(
            From_UOM__c = uomCase.Id,
            To_UOM__c = uomPieces.Id,
            Conversion_Factor__c = 24,
            Inverse_Conversion_Factor__c = 0.0417,
            Product__c = prod1.Id,
            Is_Active__c = true
        );
        insert conv;
    }

    // ─── getProducts ─────────────────────────────────────────────────

    @IsTest
    static void testGetProducts_NoFilters() {
        Test.startTest();
        ProductManagementController.ProductPageResult result =
            ProductManagementController.getProducts(null, null, null, null, null, null);
        Test.stopTest();

        System.assert(result.products.size() >= 3, 'Should return at least 3 products');
        System.assert(result.totalCount >= 3, 'Total count should be >= 3');
        System.assertEquals(1, result.pageNumber, 'Default page should be 1');
    }

    @IsTest
    static void testGetProducts_ActiveOnly() {
        Test.startTest();
        ProductManagementController.ProductPageResult result =
            ProductManagementController.getProducts(null, null, null, true, 1, 25);
        Test.stopTest();

        System.assertEquals(2, result.products.size(), 'Should return 2 active products');
    }

    @IsTest
    static void testGetProducts_SearchTerm() {
        Test.startTest();
        ProductManagementController.ProductPageResult result =
            ProductManagementController.getProducts('Biscuit', null, null, null, 1, 25);
        Test.stopTest();

        System.assert(result.products.size() >= 1, 'Should find at least 1 product matching "Biscuit"');
    }

    @IsTest
    static void testGetProducts_ByCategory() {
        Product_Category__c parentCat = [SELECT Id FROM Product_Category__c WHERE Name = 'Foods' LIMIT 1];

        Test.startTest();
        ProductManagementController.ProductPageResult result =
            ProductManagementController.getProducts(null, parentCat.Id, null, null, 1, 25);
        Test.stopTest();

        // Should include products from child category 'Biscuits' as well
        System.assert(result.products.size() >= 2, 'Should find products in parent + child categories');
    }

    @IsTest
    static void testGetProducts_ByBrand() {
        Test.startTest();
        ProductManagementController.ProductPageResult result =
            ProductManagementController.getProducts(null, null, 'TestBrand', null, 1, 25);
        Test.stopTest();

        System.assert(result.products.size() >= 1, 'Should find at least 1 product for TestBrand');
    }

    @IsTest
    static void testGetProducts_Pagination() {
        Test.startTest();
        ProductManagementController.ProductPageResult result =
            ProductManagementController.getProducts(null, null, null, null, 1, 1);
        Test.stopTest();

        System.assertEquals(1, result.products.size(), 'Page size 1 should return 1 product');
        System.assert(result.totalPages >= 3, 'Should have at least 3 pages with page size 1');
    }

    // ─── saveProduct ─────────────────────────────────────────────────

    @IsTest
    static void testSaveProduct_NewProduct() {
        Product_Extension__c newProd = new Product_Extension__c(
            Name = 'Brand New Product',
            SKU_Code__c = 'SKU-NEW',
            Brand__c = 'NewBrand',
            Is_Active__c = true,
            MRP__c = 200,
            Unit_Price__c = 170
        );

        Test.startTest();
        Product_Extension__c result = ProductManagementController.saveProduct(newProd);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Saved product should have an Id');
        System.assertEquals('Brand New Product', result.Name, 'Name should match');
    }

    @IsTest
    static void testSaveProduct_UpdateExisting() {
        Product_Extension__c existing = [SELECT Id, Name, MRP__c FROM Product_Extension__c WHERE SKU_Code__c = 'SKU-001' LIMIT 1];
        existing.MRP__c = 55;

        Test.startTest();
        Product_Extension__c result = ProductManagementController.saveProduct(existing);
        Test.stopTest();

        System.assertEquals(55, result.MRP__c, 'MRP should be updated');
    }

    // ─── deleteProduct ───────────────────────────────────────────────

    @IsTest
    static void testDeleteProduct() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'SKU-003' LIMIT 1];

        Test.startTest();
        ProductManagementController.deleteProduct(prod.Id);
        Test.stopTest();

        List<Product_Extension__c> remaining = [SELECT Id FROM Product_Extension__c WHERE Id = :prod.Id];
        System.assertEquals(0, remaining.size(), 'Product should be deleted');
    }

    // ─── getCategories ───────────────────────────────────────────────

    @IsTest
    static void testGetCategories() {
        Test.startTest();
        List<Product_Category__c> categories = ProductManagementController.getCategories();
        Test.stopTest();

        System.assert(categories.size() >= 2, 'Should return at least 2 categories');
    }

    // ─── saveCategory ────────────────────────────────────────────────

    @IsTest
    static void testSaveCategory_New() {
        Product_Category__c newCat = new Product_Category__c(
            Name = 'Beverages',
            Category_Code__c = 'CAT-BEV',
            Level__c = 'Category',
            Is_Active__c = true,
            Sort_Order__c = 3
        );

        Test.startTest();
        Product_Category__c result = ProductManagementController.saveCategory(newCat);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Category should have an Id');
        System.assertEquals('Beverages', result.Name, 'Name should match');
    }

    @IsTest
    static void testSaveCategory_Update() {
        Product_Category__c existing = [SELECT Id, Name FROM Product_Category__c WHERE Name = 'Foods' LIMIT 1];
        existing.Sort_Order__c = 10;

        Test.startTest();
        Product_Category__c result = ProductManagementController.saveCategory(existing);
        Test.stopTest();

        System.assertEquals(10, result.Sort_Order__c, 'Sort order should be updated');
    }

    // ─── deleteCategory ──────────────────────────────────────────────

    @IsTest
    static void testDeleteCategory() {
        // Create a standalone category to delete (no child dependencies)
        Product_Category__c cat = new Product_Category__c(
            Name = 'ToDelete',
            Category_Code__c = 'CAT-DEL',
            Level__c = 'Category',
            Is_Active__c = true,
            Sort_Order__c = 99
        );
        insert cat;

        Test.startTest();
        ProductManagementController.deleteCategory(cat.Id);
        Test.stopTest();

        List<Product_Category__c> remaining = [SELECT Id FROM Product_Category__c WHERE Id = :cat.Id];
        System.assertEquals(0, remaining.size(), 'Category should be deleted');
    }

    // ─── getPriceLists ───────────────────────────────────────────────

    @IsTest
    static void testGetPriceLists_NoFilters() {
        Test.startTest();
        ProductManagementController.PriceListPageResult result =
            ProductManagementController.getPriceLists(null, null, null, null, null, null, null, null, null, null);
        Test.stopTest();

        System.assert(result.priceLists.size() >= 2, 'Should return at least 2 price lists');
    }

    @IsTest
    static void testGetPriceLists_WithFilters() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'SKU-001' LIMIT 1];

        Test.startTest();
        ProductManagementController.PriceListPageResult result =
            ProductManagementController.getPriceLists(prod.Id, 'General Trade', null, null, null, null, null, true, 1, 25);
        Test.stopTest();

        System.assert(result.priceLists.size() >= 1, 'Should find at least 1 price list');
    }

    @IsTest
    static void testGetPriceLists_ByTerritory() {
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];

        Test.startTest();
        ProductManagementController.PriceListPageResult result =
            ProductManagementController.getPriceLists(null, null, null, null, territory.Id, null, null, null, 1, 25);
        Test.stopTest();

        System.assert(result.priceLists.size() >= 1, 'Should find price lists for territory');
    }

    @IsTest
    static void testGetPriceLists_ByCustomer() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        ProductManagementController.PriceListPageResult result =
            ProductManagementController.getPriceLists(null, null, null, null, null, acc.Id, null, null, 1, 25);
        Test.stopTest();

        System.assert(result.priceLists.size() >= 1, 'Should find price lists for customer');
    }

    @IsTest
    static void testGetPriceLists_ByPriority() {
        Test.startTest();
        ProductManagementController.PriceListPageResult result =
            ProductManagementController.getPriceLists(null, null, null, null, null, null, '1', null, 1, 25);
        Test.stopTest();

        System.assert(result.priceLists.size() >= 1, 'Should find price lists with priority 1');
    }

    // ─── savePriceList ───────────────────────────────────────────────

    @IsTest
    static void testSavePriceList_New() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'SKU-002' LIMIT 1];

        Price_List__c newPl = new Price_List__c(
            Product_Ext__c = prod.Id,
            Channel__c = 'General Trade',
            Unit_Price__c = 26,
            Is_Active__c = true,
            Priority__c = 3,
            Effective_From__c = Date.today(),
            Effective_To__c = Date.today().addDays(30)
        );

        Test.startTest();
        Price_List__c result = ProductManagementController.savePriceList(newPl);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Price list should have an Id');
    }

    // ─── deletePriceList ─────────────────────────────────────────────

    @IsTest
    static void testDeletePriceList() {
        Price_List__c pl = [SELECT Id FROM Price_List__c LIMIT 1];

        Test.startTest();
        ProductManagementController.deletePriceList(pl.Id);
        Test.stopTest();

        List<Price_List__c> remaining = [SELECT Id FROM Price_List__c WHERE Id = :pl.Id];
        System.assertEquals(0, remaining.size(), 'Price list should be deleted');
    }

    // ─── getDashboardStats ───────────────────────────────────────────

    @IsTest
    static void testGetDashboardStats() {
        Test.startTest();
        ProductManagementController.DashboardStats stats = ProductManagementController.getDashboardStats();
        Test.stopTest();

        System.assert(stats.totalProducts >= 3, 'Should have at least 3 total products');
        System.assert(stats.activeProducts >= 2, 'Should have at least 2 active products');
        System.assert(stats.totalCategories >= 2, 'Should have at least 2 categories');
        System.assert(stats.activePriceLists >= 2, 'Should have at least 2 active price lists');
        System.assert(stats.activeBatches >= 1, 'Should have at least 1 active batch');
        System.assert(stats.mustSellConfigs >= 1, 'Should have at least 1 must-sell config');
        System.assert(stats.totalUOMs >= 2, 'Should have at least 2 UOMs');
        System.assert(stats.totalConversions >= 1, 'Should have at least 1 conversion');
    }

    // ─── getBrands ───────────────────────────────────────────────────

    @IsTest
    static void testGetBrands() {
        Test.startTest();
        List<String> brands = ProductManagementController.getBrands();
        Test.stopTest();

        System.assert(brands.size() >= 2, 'Should return at least 2 brands');
        System.assert(brands.contains('TestBrand'), 'Should include TestBrand');
        System.assert(brands.contains('OtherBrand'), 'Should include OtherBrand');
    }

    // ─── getBatches ──────────────────────────────────────────────────

    @IsTest
    static void testGetBatches_NoFilters() {
        Test.startTest();
        List<Batch_Master__c> batches = ProductManagementController.getBatches(null, null);
        Test.stopTest();

        System.assert(batches.size() >= 2, 'Should return at least 2 batches');
    }

    @IsTest
    static void testGetBatches_ByProduct() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'SKU-001' LIMIT 1];

        Test.startTest();
        List<Batch_Master__c> batches = ProductManagementController.getBatches(prod.Id, null);
        Test.stopTest();

        System.assert(batches.size() >= 2, 'Should return batches for the product');
    }

    @IsTest
    static void testGetBatches_ByStatus() {
        Test.startTest();
        List<Batch_Master__c> batches = ProductManagementController.getBatches(null, 'Active');
        Test.stopTest();

        System.assert(batches.size() >= 1, 'Should return at least 1 active batch');
    }

    // ─── saveBatch / deleteBatch ─────────────────────────────────────

    @IsTest
    static void testSaveBatch_New() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'SKU-002' LIMIT 1];

        Batch_Master__c newBatch = new Batch_Master__c(
            Batch_Number__c = 'BATCH-NEW',
            Product_Ext__c = prod.Id,
            Manufacturing_Date__c = Date.today(),
            Expiry_Date__c = Date.today().addDays(365),
            Status__c = 'Active',
            Quantity_Manufactured__c = 2000
        );

        Test.startTest();
        Batch_Master__c result = ProductManagementController.saveBatch(newBatch);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Batch should have an Id');
        System.assertEquals('BATCH-NEW', result.Batch_Number__c, 'Batch number should match');
    }

    @IsTest
    static void testDeleteBatch() {
        Batch_Master__c batch = [SELECT Id FROM Batch_Master__c WHERE Batch_Number__c = 'BATCH-002' LIMIT 1];

        Test.startTest();
        ProductManagementController.deleteBatch(batch.Id);
        Test.stopTest();

        List<Batch_Master__c> remaining = [SELECT Id FROM Batch_Master__c WHERE Id = :batch.Id];
        System.assertEquals(0, remaining.size(), 'Batch should be deleted');
    }

    // ─── getMustSellConfigs ──────────────────────────────────────────

    @IsTest
    static void testGetMustSellConfigs_ActiveOnly() {
        Test.startTest();
        List<Must_Sell_Config__c> configs = ProductManagementController.getMustSellConfigs(true);
        Test.stopTest();

        System.assert(configs.size() >= 1, 'Should return at least 1 active must-sell config');
    }

    @IsTest
    static void testGetMustSellConfigs_All() {
        Test.startTest();
        List<Must_Sell_Config__c> configs = ProductManagementController.getMustSellConfigs(false);
        Test.stopTest();

        System.assert(configs.size() >= 1, 'Should return at least 1 must-sell config');
    }

    // ─── saveMustSellConfig / deleteMustSellConfig ───────────────────

    @IsTest
    static void testSaveMustSellConfig_New() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'SKU-002' LIMIT 1];
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];

        Must_Sell_Config__c newConfig = TestDataFactory.createMustSellConfig(
            prod.Id, 'B', 3, territory.Id, 'Modern Trade', 'Distributor'
        );

        Test.startTest();
        Must_Sell_Config__c result = ProductManagementController.saveMustSellConfig(newConfig);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Config should have an Id');
    }

    @IsTest
    static void testDeleteMustSellConfig() {
        Must_Sell_Config__c config = [SELECT Id FROM Must_Sell_Config__c LIMIT 1];

        Test.startTest();
        ProductManagementController.deleteMustSellConfig(config.Id);
        Test.stopTest();

        List<Must_Sell_Config__c> remaining = [SELECT Id FROM Must_Sell_Config__c WHERE Id = :config.Id];
        System.assertEquals(0, remaining.size(), 'Config should be deleted');
    }

    // ─── getUOMs ─────────────────────────────────────────────────────

    @IsTest
    static void testGetUOMs() {
        Test.startTest();
        List<UOM__c> uoms = ProductManagementController.getUOMs();
        Test.stopTest();

        System.assert(uoms.size() >= 2, 'Should return at least 2 UOMs');
    }

    // ─── saveUOM / deleteUOM ─────────────────────────────────────────

    @IsTest
    static void testSaveUOM_New() {
        UOM__c newUom = new UOM__c(
            Name = 'Kilogram',
            UOM_Code__c = 'KG',
            UOM_Type__c = 'Weight',
            Is_Base_Unit__c = true,
            Is_Active__c = true
        );

        Test.startTest();
        UOM__c result = ProductManagementController.saveUOM(newUom);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'UOM should have an Id');
        System.assertEquals('Kilogram', result.Name, 'Name should match');
    }

    @IsTest
    static void testDeleteUOM() {
        UOM__c uom = new UOM__c(
            Name = 'Deletable UOM',
            UOM_Code__c = 'DEL',
            UOM_Type__c = 'Count',
            Is_Active__c = true
        );
        insert uom;

        Test.startTest();
        ProductManagementController.deleteUOM(uom.Id);
        Test.stopTest();

        List<UOM__c> remaining = [SELECT Id FROM UOM__c WHERE Id = :uom.Id];
        System.assertEquals(0, remaining.size(), 'UOM should be deleted');
    }

    // ─── getUOMConversions ───────────────────────────────────────────

    @IsTest
    static void testGetUOMConversions_NoFilter() {
        Test.startTest();
        List<UOM_Conversion__c> convs = ProductManagementController.getUOMConversions(null);
        Test.stopTest();

        System.assert(convs.size() >= 1, 'Should return at least 1 conversion');
    }

    @IsTest
    static void testGetUOMConversions_ByProduct() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'SKU-001' LIMIT 1];

        Test.startTest();
        List<UOM_Conversion__c> convs = ProductManagementController.getUOMConversions(prod.Id);
        Test.stopTest();

        System.assert(convs.size() >= 1, 'Should return conversions for the product');
    }

    // ─── saveUOMConversion ───────────────────────────────────────────

    @IsTest
    static void testSaveUOMConversion_New() {
        UOM__c fromUom = [SELECT Id FROM UOM__c WHERE UOM_Code__c = 'PCS' LIMIT 1];
        UOM__c toUom = [SELECT Id FROM UOM__c WHERE UOM_Code__c = 'CS' LIMIT 1];

        UOM_Conversion__c newConv = new UOM_Conversion__c(
            From_UOM__c = fromUom.Id,
            To_UOM__c = toUom.Id,
            Conversion_Factor__c = 0.0417,
            Is_Active__c = true
        );

        Test.startTest();
        UOM_Conversion__c result = ProductManagementController.saveUOMConversion(newConv);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Conversion should have an Id');
        System.assertNotEquals(null, result.Inverse_Conversion_Factor__c, 'Inverse should be calculated');
    }

    @IsTest
    static void testSaveUOMConversion_SameFromTo() {
        UOM__c uom = [SELECT Id FROM UOM__c WHERE UOM_Code__c = 'PCS' LIMIT 1];

        UOM_Conversion__c conv = new UOM_Conversion__c(
            From_UOM__c = uom.Id,
            To_UOM__c = uom.Id,
            Conversion_Factor__c = 1,
            Is_Active__c = true
        );

        Test.startTest();
        try {
            ProductManagementController.saveUOMConversion(conv);
            System.assert(false, 'Should have thrown for same From/To UOM');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('different') ||
                          e.getMessage().contains('Script-thrown exception'),
                          'Should throw different UOM error');
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveUOMConversion_InvalidFactor() {
        UOM__c fromUom = [SELECT Id FROM UOM__c WHERE UOM_Code__c = 'PCS' LIMIT 1];
        UOM__c toUom = [SELECT Id FROM UOM__c WHERE UOM_Code__c = 'CS' LIMIT 1];

        UOM_Conversion__c conv = new UOM_Conversion__c(
            From_UOM__c = fromUom.Id,
            To_UOM__c = toUom.Id,
            Conversion_Factor__c = -1,
            Is_Active__c = true
        );

        Test.startTest();
        try {
            ProductManagementController.saveUOMConversion(conv);
            System.assert(false, 'Should have thrown for negative conversion factor');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('positive') ||
                          e.getMessage().contains('Script-thrown exception'),
                          'Should throw positive number error');
        }
        Test.stopTest();
    }

    // ─── deleteUOMConversion ─────────────────────────────────────────

    @IsTest
    static void testDeleteUOMConversion() {
        UOM_Conversion__c conv = [SELECT Id FROM UOM_Conversion__c LIMIT 1];

        Test.startTest();
        ProductManagementController.deleteUOMConversion(conv.Id);
        Test.stopTest();

        List<UOM_Conversion__c> remaining = [SELECT Id FROM UOM_Conversion__c WHERE Id = :conv.Id];
        System.assertEquals(0, remaining.size(), 'Conversion should be deleted');
    }

    // ─── Lookup methods ──────────────────────────────────────────────

    @IsTest
    static void testSearchProductsForLookup() {
        Test.startTest();
        List<Product_Extension__c> results = ProductManagementController.searchProductsForLookup('Test');
        Test.stopTest();

        System.assert(results.size() >= 1, 'Should find products matching "Test"');
    }

    @IsTest
    static void testSearchTerritoriesForLookup() {
        Test.startTest();
        List<Territory_Master__c> results = ProductManagementController.searchTerritoriesForLookup('Mumbai');
        Test.stopTest();

        System.assert(results.size() >= 1, 'Should find territories matching "Mumbai"');
    }

    @IsTest
    static void testSearchCategoriesForLookup() {
        Test.startTest();
        List<Product_Category__c> results = ProductManagementController.searchCategoriesForLookup('Foods');
        Test.stopTest();

        System.assert(results.size() >= 1, 'Should find categories matching "Foods"');
    }

    @IsTest
    static void testSearchCustomersForLookup() {
        Test.startTest();
        List<Account> results = ProductManagementController.searchCustomersForLookup('Test');
        Test.stopTest();

        System.assert(results.size() >= 1, 'Should find customers matching "Test"');
    }

    @IsTest
    static void testGetActiveUOMsForLookup() {
        Test.startTest();
        List<UOM__c> results = ProductManagementController.getActiveUOMsForLookup();
        Test.stopTest();

        System.assert(results.size() >= 2, 'Should return at least 2 active UOMs');
    }

    // ─── getPriceChangeLogs ──────────────────────────────────────────

    @IsTest
    static void testGetPriceChangeLogs_NoFilter() {
        Test.startTest();
        List<Price_Change_Log__c> logs = ProductManagementController.getPriceChangeLogs(null);
        Test.stopTest();

        System.assertNotEquals(null, logs, 'Should return a list (possibly empty)');
    }

    @IsTest
    static void testGetPriceChangeLogs_ByProduct() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'SKU-001' LIMIT 1];

        Test.startTest();
        List<Price_Change_Log__c> logs = ProductManagementController.getPriceChangeLogs(prod.Id);
        Test.stopTest();

        System.assertNotEquals(null, logs, 'Should return a list (possibly empty)');
    }

    // ─── getPricebookPriorities ──────────────────────────────────────

    @IsTest
    static void testGetPricebookPriorities() {
        Test.startTest();
        List<Pricebook_Priority__mdt> priorities = ProductManagementController.getPricebookPriorities();
        Test.stopTest();

        System.assertNotEquals(null, priorities, 'Should return a list (possibly empty for custom metadata)');
    }
}
