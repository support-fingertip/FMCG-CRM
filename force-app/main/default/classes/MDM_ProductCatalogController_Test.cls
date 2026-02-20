/**
 * @description Test class for MDM_ProductCatalogController.
 */
@isTest
private class MDM_ProductCatalogController_Test {

    @TestSetup
    static void setupTestData() {
        // Create category hierarchy
        Product_Category__c beverages = new Product_Category__c(
            Name = 'Beverages',
            Category_Code__c = 'BEV',
            Level__c = 'Category',
            Sort_Order__c = 1,
            Is_Active__c = true
        );
        insert beverages;

        Product_Category__c juices = new Product_Category__c(
            Name = 'Juices',
            Category_Code__c = 'BEV-JUI',
            Level__c = 'Sub-Category',
            Parent_Category__c = beverages.Id,
            Sort_Order__c = 1,
            Is_Active__c = true
        );
        insert juices;

        Product_Category__c brandA = new Product_Category__c(
            Name = 'Brand A Juices',
            Category_Code__c = 'BEV-JUI-BRA',
            Level__c = 'Brand',
            Parent_Category__c = juices.Id,
            Sort_Order__c = 1,
            Is_Active__c = true
        );
        insert brandA;

        // Create products
        List<Product2> products = new List<Product2>();
        for (Integer i = 1; i <= 5; i++) {
            products.add(new Product2(
                Name = 'Test Product ' + i,
                ProductCode = 'TP-' + String.valueOf(i).leftPad(3, '0'),
                IsActive = true,
                Family = 'Beverages'
            ));
        }
        products.add(new Product2(
            Name = 'Inactive Product',
            ProductCode = 'TP-INACTIVE',
            IsActive = false
        ));
        insert products;

        // Create product extensions
        List<Product_Extension__c> extensions = new List<Product_Extension__c>();
        for (Integer i = 0; i < 5; i++) {
            extensions.add(new Product_Extension__c(
                Name = products[i].Name + ' Ext',
                Product__c = products[i].Id,
                Product_Category__c = brandA.Id,
                Barcode_EAN__c = '1234567890123',
                HSN_SAC_Code__c = '22011010',
                Weight__c = 500,
                Weight_Unit__c = 'ml',
                Case_Size__c = 24,
                Min_Order_Qty__c = 5,
                Is_Active__c = true
            ));
        }
        insert extensions;

        // Create price list entries
        List<Price_List__c> prices = new List<Price_List__c>();
        for (Integer i = 0; i < 5; i++) {
            prices.add(new Price_List__c(
                Name = products[i].Name + ' MRP',
                Product__c = products[i].Id,
                Unit_Price__c = 100 + (i * 10),
                Price_Type__c = 'MRP',
                Channel__c = 'GT',
                Effective_From__c = Date.today().addDays(-30),
                Is_Active__c = true
            ));
        }
        insert prices;

        // Create test account and stock
        Account testAcc = new Account(Name = 'Stock Test Distributor', Is_Active__c = true);
        insert testAcc;

        Distributor_Stock__c stock = new Distributor_Stock__c(
            Account__c = testAcc.Id,
            Product__c = products[0].Id,
            Stock_Date__c = Date.today(),
            Opening_Stock__c = 100,
            Received_Qty__c = 50,
            Sold_Qty__c = 20,
            Is_Current__c = true
        );
        insert stock;

        // Create batch
        Batch_Master__c batch = new Batch_Master__c(
            Name = 'BATCH-001',
            Batch_Number__c = 'B-2024-001',
            Product__c = products[0].Id,
            Manufacturing_Date__c = Date.today().addDays(-90),
            Expiry_Date__c = Date.today().addDays(270),
            Status__c = 'Active',
            Quantity_Manufactured__c = 10000
        );
        insert batch;
    }

    @isTest
    static void testGetProducts_NoFilters() {
        Test.startTest();
        MDM_ProductCatalogController.ProductCatalogResult result =
            MDM_ProductCatalogController.getProducts(null, null, false, 50, 0);
        Test.stopTest();

        System.assert(result.totalCount >= 5, 'Should return all products');
        System.assertNotEquals(null, result.products, 'Products list should not be null');
    }

    @isTest
    static void testGetProducts_WithSearch() {
        Test.startTest();
        MDM_ProductCatalogController.ProductCatalogResult result =
            MDM_ProductCatalogController.getProducts('Test Product 1', null, true, 50, 0);
        Test.stopTest();

        System.assert(result.totalCount >= 1, 'Should find at least one product');
    }

    @isTest
    static void testGetProducts_ActiveOnly() {
        Test.startTest();
        MDM_ProductCatalogController.ProductCatalogResult result =
            MDM_ProductCatalogController.getProducts(null, null, true, 50, 0);
        Test.stopTest();

        for (MDM_ProductCatalogController.ProductWrapper pw : result.products) {
            System.assertEquals(true, pw.isActive, 'Only active products should be returned');
        }
    }

    @isTest
    static void testGetProducts_ByCategory() {
        Product_Category__c cat = [SELECT Id FROM Product_Category__c WHERE Category_Code__c = 'BEV' LIMIT 1];

        Test.startTest();
        MDM_ProductCatalogController.ProductCatalogResult result =
            MDM_ProductCatalogController.getProducts(null, cat.Id, true, 50, 0);
        Test.stopTest();

        System.assert(result.totalCount >= 1, 'Should return products in category hierarchy');
    }

    @isTest
    static void testGetCategoryTree() {
        Test.startTest();
        List<MDM_ProductCatalogController.CategoryNode> tree =
            MDM_ProductCatalogController.getCategoryTree();
        Test.stopTest();

        System.assert(!tree.isEmpty(), 'Category tree should not be empty');
        // Root should be "Beverages" with children
        Boolean foundBeverages = false;
        for (MDM_ProductCatalogController.CategoryNode node : tree) {
            if (node.name == 'Beverages') {
                foundBeverages = true;
                System.assert(!node.children.isEmpty(), 'Beverages should have sub-categories');
            }
        }
        System.assert(foundBeverages, 'Should find Beverages category at root');
    }

    @isTest
    static void testGetProductPricing() {
        Product2 product = [SELECT Id FROM Product2 WHERE ProductCode = 'TP-001' LIMIT 1];

        Test.startTest();
        List<Price_List__c> prices = MDM_ProductCatalogController.getProductPricing(product.Id);
        Test.stopTest();

        System.assert(!prices.isEmpty(), 'Should return pricing for product');
    }

    @isTest
    static void testGetProductDetail() {
        Product2 product = [SELECT Id FROM Product2 WHERE ProductCode = 'TP-001' LIMIT 1];

        Test.startTest();
        MDM_ProductCatalogController.ProductDetailWrapper detail =
            MDM_ProductCatalogController.getProductDetail(product.Id);
        Test.stopTest();

        System.assertEquals(product.Id, detail.productId, 'Should return correct product');
        System.assertNotEquals(null, detail.priceLists, 'Price lists should not be null');
        System.assert(detail.activeBatchCount >= 1, 'Should have active batch');
        System.assert(detail.totalDistributorStock > 0, 'Should have distributor stock');
    }

    @isTest
    static void testGetProducts_Pagination() {
        Test.startTest();
        MDM_ProductCatalogController.ProductCatalogResult page1 =
            MDM_ProductCatalogController.getProducts(null, null, true, 3, 0);
        MDM_ProductCatalogController.ProductCatalogResult page2 =
            MDM_ProductCatalogController.getProducts(null, null, true, 3, 3);
        Test.stopTest();

        System.assertEquals(3, page1.products.size(), 'Page 1 should have 3 products');
        System.assert(page2.products.size() >= 1, 'Page 2 should have remaining products');
    }
}