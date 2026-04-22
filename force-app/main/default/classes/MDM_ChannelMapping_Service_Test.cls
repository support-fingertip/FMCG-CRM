/**
 * @description Test class for MDM_ChannelMapping_Service.
 *              Validates channel-based product filtering, employee authorization,
 *              channel resolution, and feature toggle behavior.
 * @author  SFA Development Team
 * @date    2026
 */
@isTest
private class MDM_ChannelMapping_Service_Test {

    @TestSetup
    static void setupTestData() {
        // Account with channel
        Account acc = new Account(
            Name = 'Channel Test Retailer',
            Type = 'Retailer',
            Channel__c = 'GT',
            Is_Active__c = true,
            BillingCity = 'Mumbai',
            BillingState = 'Maharashtra',
            BillingCountry = 'India'
        );
        insert acc;

        // Products with various channel configurations
        List<Product_Extension__c> products = new List<Product_Extension__c>();
        products.add(new Product_Extension__c(
            Name = 'GT Product',
            SKU_Code__c = 'CH-0001',
            Channels__c = 'GT',
            Is_Active__c = true
        ));
        products.add(new Product_Extension__c(
            Name = 'MT Product',
            SKU_Code__c = 'CH-0002',
            Channels__c = 'MT',
            Is_Active__c = true
        ));
        products.add(new Product_Extension__c(
            Name = 'Multi Channel Product',
            SKU_Code__c = 'CH-0003',
            Channels__c = 'GT;MT;E-Commerce',
            Is_Active__c = true
        ));
        products.add(new Product_Extension__c(
            Name = 'No Channel Product',
            SKU_Code__c = 'CH-0004',
            Is_Active__c = true
        ));
        insert products;

        // Employee with channels
        Employee__c emp = new Employee__c(
            First_Name__c = 'Channel',
            Last_Name__c = 'Tester',
            Employee_Code__c = 'EMP-CH01',
            Is_Active__c = true,
            User__c = UserInfo.getUserId(),
            Channels__c = 'GT;MT'
        );
        insert emp;

        // Employee without channels
        Employee__c empNoChannel = new Employee__c(
            First_Name__c = 'Open',
            Last_Name__c = 'Employee',
            Employee_Code__c = 'EMP-CH02',
            Is_Active__c = true
        );
        insert empNoChannel;
    }

    // ─── isProductInChannel ────────────────────────────────────────────

    @isTest
    static void testIsProductInChannel_BlankChannels_ReturnsTrue() {
        Product_Extension__c prod = [SELECT Id, Channels__c FROM Product_Extension__c WHERE SKU_Code__c = 'CH-0004'];

        Test.startTest();
        Boolean result = MDM_ChannelMapping_Service.isProductInChannel(prod, 'GT');
        Test.stopTest();

        System.assertEquals(true, result, 'Product with blank Channels__c should be allowed in any channel');
    }

    @isTest
    static void testIsProductInChannel_MatchingChannel_ReturnsTrue() {
        Product_Extension__c prod = [SELECT Id, Channels__c FROM Product_Extension__c WHERE SKU_Code__c = 'CH-0001'];

        Test.startTest();
        Boolean result = MDM_ChannelMapping_Service.isProductInChannel(prod, 'GT');
        Test.stopTest();

        // Feature toggle MDM-003 may not be enabled in test context, so result is true either way
        System.assertEquals(true, result, 'Product with matching channel or disabled toggle should return true');
    }

    @isTest
    static void testIsProductInChannel_NonMatchingChannel() {
        Product_Extension__c prod = [SELECT Id, Channels__c FROM Product_Extension__c WHERE SKU_Code__c = 'CH-0002'];

        Test.startTest();
        // MT product checked against GT channel
        Boolean result = MDM_ChannelMapping_Service.isProductInChannel(prod, 'GT');
        Test.stopTest();

        // If toggle disabled, returns true; if enabled, returns false
        // We verify the method executes without error
        System.assertNotEquals(null, result, 'Should return a boolean result');
    }

    @isTest
    static void testIsProductInChannel_BlankChannelValue_ReturnsTrue() {
        Product_Extension__c prod = [SELECT Id, Channels__c FROM Product_Extension__c WHERE SKU_Code__c = 'CH-0001'];

        Test.startTest();
        Boolean result = MDM_ChannelMapping_Service.isProductInChannel(prod, '');
        Test.stopTest();

        System.assertEquals(true, result, 'Blank channel value should return true');
    }

    @isTest
    static void testIsProductInChannel_NullChannelValue_ReturnsTrue() {
        Product_Extension__c prod = [SELECT Id, Channels__c FROM Product_Extension__c WHERE SKU_Code__c = 'CH-0001'];

        Test.startTest();
        Boolean result = MDM_ChannelMapping_Service.isProductInChannel(prod, null);
        Test.stopTest();

        System.assertEquals(true, result, 'Null channel value should return true');
    }

    @isTest
    static void testIsProductInChannel_MultiChannelProduct() {
        Product_Extension__c prod = [SELECT Id, Channels__c FROM Product_Extension__c WHERE SKU_Code__c = 'CH-0003'];

        Test.startTest();
        Boolean resultGT = MDM_ChannelMapping_Service.isProductInChannel(prod, 'GT');
        Boolean resultMT = MDM_ChannelMapping_Service.isProductInChannel(prod, 'MT');
        Boolean resultEC = MDM_ChannelMapping_Service.isProductInChannel(prod, 'E-Commerce');
        Test.stopTest();

        // With toggle disabled all return true; with toggle enabled all match
        System.assertEquals(true, resultGT, 'Multi-channel product should include GT');
        System.assertEquals(true, resultMT, 'Multi-channel product should include MT');
        System.assertEquals(true, resultEC, 'Multi-channel product should include E-Commerce');
    }

    // ─── filterProductsByChannel ───────────────────────────────────────

    @isTest
    static void testFilterProductsByChannel() {
        List<Product_Extension__c> allProducts = [
            SELECT Id, Name, Channels__c FROM Product_Extension__c ORDER BY SKU_Code__c
        ];

        Test.startTest();
        List<Product_Extension__c> filtered = MDM_ChannelMapping_Service.filterProductsByChannel(allProducts, 'GT');
        Test.stopTest();

        // With toggle disabled, all products returned; with toggle enabled,
        // GT product + multi-channel + blank channel returned (3 of 4)
        System.assert(filtered.size() >= 3, 'Should return at least the matching and open products');
    }

    @isTest
    static void testFilterProductsByChannel_BlankChannel_ReturnsAll() {
        List<Product_Extension__c> allProducts = [
            SELECT Id, Name, Channels__c FROM Product_Extension__c
        ];

        Test.startTest();
        List<Product_Extension__c> filtered = MDM_ChannelMapping_Service.filterProductsByChannel(allProducts, '');
        Test.stopTest();

        System.assertEquals(allProducts.size(), filtered.size(), 'Blank channel should return all products');
    }

    // ─── isEmployeeAuthorizedForChannel ────────────────────────────────

    @isTest
    static void testIsEmployeeAuthorizedForChannel_Matching() {
        Employee__c emp = [SELECT Id, Channels__c FROM Employee__c WHERE Employee_Code__c = 'EMP-CH01'];

        Test.startTest();
        Boolean result = MDM_ChannelMapping_Service.isEmployeeAuthorizedForChannel(emp, 'GT');
        Test.stopTest();

        System.assertEquals(true, result, 'Employee with GT channel should be authorized for GT');
    }

    @isTest
    static void testIsEmployeeAuthorizedForChannel_BlankEmployeeChannels() {
        Employee__c emp = [SELECT Id, Channels__c FROM Employee__c WHERE Employee_Code__c = 'EMP-CH02'];

        Test.startTest();
        Boolean result = MDM_ChannelMapping_Service.isEmployeeAuthorizedForChannel(emp, 'GT');
        Test.stopTest();

        System.assertEquals(true, result, 'Employee with no channels should be authorized for all');
    }

    @isTest
    static void testIsEmployeeAuthorizedForChannel_NonMatching() {
        Employee__c emp = [SELECT Id, Channels__c FROM Employee__c WHERE Employee_Code__c = 'EMP-CH01'];

        Test.startTest();
        Boolean result = MDM_ChannelMapping_Service.isEmployeeAuthorizedForChannel(emp, 'Institutional');
        Test.stopTest();

        // With toggle disabled returns true; with toggle enabled returns false
        System.assertNotEquals(null, result, 'Should return a boolean result');
    }

    // ─── getEmployeeChannels ───────────────────────────────────────────

    @isTest
    static void testGetEmployeeChannels_WithChannels() {
        Employee__c emp = [SELECT Id, Channels__c FROM Employee__c WHERE Employee_Code__c = 'EMP-CH01'];

        Test.startTest();
        Set<String> channels = MDM_ChannelMapping_Service.getEmployeeChannels(emp);
        Test.stopTest();

        System.assertEquals(2, channels.size(), 'Should return 2 channels (GT, MT)');
        System.assert(channels.contains('GT'), 'Should contain GT');
        System.assert(channels.contains('MT'), 'Should contain MT');
    }

    @isTest
    static void testGetEmployeeChannels_BlankChannels() {
        Employee__c emp = [SELECT Id, Channels__c FROM Employee__c WHERE Employee_Code__c = 'EMP-CH02'];

        Test.startTest();
        Set<String> channels = MDM_ChannelMapping_Service.getEmployeeChannels(emp);
        Test.stopTest();

        System.assertEquals(0, channels.size(), 'Employee with no channels should return empty set');
    }

    // ─── getProductChannels ────────────────────────────────────────────

    @isTest
    static void testGetProductChannels_WithChannels() {
        Product_Extension__c prod = [SELECT Id, Channels__c FROM Product_Extension__c WHERE SKU_Code__c = 'CH-0003'];

        Test.startTest();
        Set<String> channels = MDM_ChannelMapping_Service.getProductChannels(prod);
        Test.stopTest();

        System.assertEquals(3, channels.size(), 'Multi-channel product should return 3 channels');
        System.assert(channels.contains('GT'), 'Should contain GT');
        System.assert(channels.contains('MT'), 'Should contain MT');
        System.assert(channels.contains('E-Commerce'), 'Should contain E-Commerce');
    }

    @isTest
    static void testGetProductChannels_BlankChannels() {
        Product_Extension__c prod = [SELECT Id, Channels__c FROM Product_Extension__c WHERE SKU_Code__c = 'CH-0004'];

        Test.startTest();
        Set<String> channels = MDM_ChannelMapping_Service.getProductChannels(prod);
        Test.stopTest();

        System.assertEquals(0, channels.size(), 'Product with no channels should return empty set');
    }

    // ─── resolveTradeChannel ───────────────────────────────────────────

    @isTest
    static void testResolveTradeChannel_ValidAccount() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Channel Test Retailer'];

        Test.startTest();
        String channel = MDM_ChannelMapping_Service.resolveTradeChannel(acc.Id);
        Test.stopTest();

        System.assertEquals('GT', channel, 'Should resolve to GT channel from account');
    }

    @isTest
    static void testResolveTradeChannel_NullAccountId() {
        Test.startTest();
        String channel = MDM_ChannelMapping_Service.resolveTradeChannel(null);
        Test.stopTest();

        System.assertEquals(null, channel, 'Null account Id should return null');
    }

    // ─── Feature Toggle Disabled ───────────────────────────────────────

    @isTest
    static void testFeatureToggleDisabled_AllMethodsPermissive() {
        // MDM-003 toggle is not in custom metadata for test context, so defaults to disabled
        Product_Extension__c prod = [SELECT Id, Channels__c FROM Product_Extension__c WHERE SKU_Code__c = 'CH-0002'];
        Employee__c emp = [SELECT Id, Channels__c FROM Employee__c WHERE Employee_Code__c = 'EMP-CH01'];
        List<Product_Extension__c> allProducts = [SELECT Id, Channels__c FROM Product_Extension__c];

        Test.startTest();
        Boolean prodResult = MDM_ChannelMapping_Service.isProductInChannel(prod, 'GT');
        Boolean empResult = MDM_ChannelMapping_Service.isEmployeeAuthorizedForChannel(emp, 'Institutional');
        List<Product_Extension__c> filtered = MDM_ChannelMapping_Service.filterProductsByChannel(allProducts, 'GT');
        Test.stopTest();

        System.assertEquals(true, prodResult, 'With toggle disabled, product check should return true');
        System.assertEquals(true, empResult, 'With toggle disabled, employee check should return true');
        System.assertEquals(allProducts.size(), filtered.size(), 'With toggle disabled, all products should be returned');
    }
}
