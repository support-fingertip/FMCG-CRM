/**
 * @description Test class for UOM_Conversion_Service.
 *              Tests conversion factor resolution, bulk conversion,
 *              product UOM options, and picklist-to-code mapping.
 *
 * @author  SFA Development Team
 * @date    2024
 */
@IsTest
private class UOM_Conversion_Service_Test {

    @TestSetup
    static void setupData() {
        // Create UOM master records
        UOM__c uomPC = new UOM__c(UOM_Code__c = 'PC', Name = 'Piece', UOM_Type__c = 'Count', Is_Base_Unit__c = true, Is_Active__c = true);
        UOM__c uomCS = new UOM__c(UOM_Code__c = 'CS', Name = 'Case', UOM_Type__c = 'Count', Is_Base_Unit__c = false, Is_Active__c = true);
        UOM__c uomBX = new UOM__c(UOM_Code__c = 'BX', Name = 'Box', UOM_Type__c = 'Count', Is_Base_Unit__c = false, Is_Active__c = true);
        UOM__c uomKG = new UOM__c(UOM_Code__c = 'KG', Name = 'Kilogram', UOM_Type__c = 'Weight', Is_Base_Unit__c = true, Is_Active__c = true);
        UOM__c uomDZ = new UOM__c(UOM_Code__c = 'DZ', Name = 'Dozen', UOM_Type__c = 'Count', Is_Base_Unit__c = false, Is_Active__c = true);
        insert new List<UOM__c>{ uomPC, uomCS, uomBX, uomKG, uomDZ };

        // Create a product
        Product_Extension__c product = new Product_Extension__c(
            Name = 'Test Product',
            SKU_Code__c = 'TST001',
            Is_Active__c = true,
            MRP__c = 100,
            Unit_Price__c = 90,
            GST_Rate__c = 18,
            Base_UOM__c = uomPC.Id,
            Secondary_UOM__c = uomCS.Id,
            Ordering_UOMs__c = 'PC,CS,BX',
            Unit_of_Measure__c = 'Piece'
        );
        insert product;

        // Create global conversion: DZ -> PC = 12
        UOM_Conversion__c globalConv = new UOM_Conversion__c(
            From_UOM__c = uomDZ.Id,
            To_UOM__c = uomPC.Id,
            Conversion_Factor__c = 12,
            Inverse_Conversion_Factor__c = 0.0833,
            Is_Active__c = true
        );

        // Create product-specific conversion: CS -> PC = 24 for test product
        UOM_Conversion__c prodConv = new UOM_Conversion__c(
            From_UOM__c = uomCS.Id,
            To_UOM__c = uomPC.Id,
            Conversion_Factor__c = 24,
            Inverse_Conversion_Factor__c = 0.0417,
            Product__c = product.Id,
            Is_Active__c = true
        );

        // Create global conversion: BX -> PC = 6
        UOM_Conversion__c globalBxConv = new UOM_Conversion__c(
            From_UOM__c = uomBX.Id,
            To_UOM__c = uomPC.Id,
            Conversion_Factor__c = 6,
            Inverse_Conversion_Factor__c = 0.1667,
            Is_Active__c = true
        );

        insert new List<UOM_Conversion__c>{ globalConv, prodConv, globalBxConv };
    }

    @IsTest
    static void testConvertProductSpecific() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'TST001' LIMIT 1];

        Test.startTest();
        UOM_Conversion_Service.clearCache();
        // 2 Cases = 48 Pieces (product-specific: 1 CS = 24 PC)
        Decimal result = UOM_Conversion_Service.convert(prod.Id, 'CS', 'PC', 2);
        Test.stopTest();

        System.assertEquals(48, result, 'Expected 2 CS = 48 PC for product-specific conversion');
    }

    @IsTest
    static void testConvertGlobalFallback() {
        Test.startTest();
        UOM_Conversion_Service.clearCache();
        // 3 Dozen = 36 Pieces (global: 1 DZ = 12 PC)
        Decimal result = UOM_Conversion_Service.convert(null, 'DZ', 'PC', 3);
        Test.stopTest();

        System.assertEquals(36, result, 'Expected 3 DZ = 36 PC for global conversion');
    }

    @IsTest
    static void testConvertReverse() {
        Test.startTest();
        UOM_Conversion_Service.clearCache();
        // 24 Pieces = 2 Dozen (reverse of global DZ->PC=12)
        Decimal result = UOM_Conversion_Service.convert(null, 'PC', 'DZ', 24);
        Test.stopTest();

        System.assertEquals(2, result, 'Expected 24 PC = 2 DZ for reverse conversion');
    }

    @IsTest
    static void testConvertSameUOM() {
        Test.startTest();
        UOM_Conversion_Service.clearCache();
        Decimal result = UOM_Conversion_Service.convert(null, 'PC', 'PC', 10);
        Test.stopTest();

        System.assertEquals(10, result, 'Same UOM should return same quantity');
    }

    @IsTest
    static void testConvertZeroQuantity() {
        Test.startTest();
        UOM_Conversion_Service.clearCache();
        Decimal result = UOM_Conversion_Service.convert(null, 'CS', 'PC', 0);
        Test.stopTest();

        System.assertEquals(0, result, 'Zero quantity should return zero');
    }

    @IsTest
    static void testConvertNullUOM() {
        Test.startTest();
        UOM_Conversion_Service.clearCache();
        Decimal result = UOM_Conversion_Service.convert(null, null, 'PC', 10);
        Test.stopTest();

        System.assertEquals(10, result, 'Null from UOM should return original quantity');
    }

    @IsTest
    static void testGetConversionFactor() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'TST001' LIMIT 1];

        Test.startTest();
        UOM_Conversion_Service.clearCache();
        Decimal factor = UOM_Conversion_Service.getConversionFactor(prod.Id, 'CS', 'PC');
        Test.stopTest();

        System.assertEquals(24, factor, 'Expected CS->PC factor of 24 for product');
    }

    @IsTest
    static void testGetConversionFactorNoRule() {
        Test.startTest();
        UOM_Conversion_Service.clearCache();
        // No conversion between KG and DZ
        Decimal factor = UOM_Conversion_Service.getConversionFactor(null, 'KG', 'DZ');
        Test.stopTest();

        System.assertEquals(1, factor, 'Missing conversion rule should return factor of 1');
    }

    @IsTest
    static void testBulkConvert() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'TST001' LIMIT 1];

        List<UOM_Conversion_Service.ConversionRequest> requests = new List<UOM_Conversion_Service.ConversionRequest>();

        UOM_Conversion_Service.ConversionRequest req1 = new UOM_Conversion_Service.ConversionRequest();
        req1.productId = prod.Id;
        req1.fromUomCode = 'CS';
        req1.toUomCode = 'PC';
        req1.quantity = 5;
        requests.add(req1);

        UOM_Conversion_Service.ConversionRequest req2 = new UOM_Conversion_Service.ConversionRequest();
        req2.productId = null;
        req2.fromUomCode = 'DZ';
        req2.toUomCode = 'PC';
        req2.quantity = 3;
        requests.add(req2);

        UOM_Conversion_Service.ConversionRequest req3 = new UOM_Conversion_Service.ConversionRequest();
        req3.productId = null;
        req3.fromUomCode = 'PC';
        req3.toUomCode = 'PC';
        req3.quantity = 10;
        requests.add(req3);

        Test.startTest();
        UOM_Conversion_Service.clearCache();
        List<UOM_Conversion_Service.ConvertedResult> results = UOM_Conversion_Service.bulkConvert(requests);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Should return 3 results');
        System.assertEquals(120, results[0].convertedQuantity, '5 CS = 120 PC');
        System.assertEquals(36, results[1].convertedQuantity, '3 DZ = 36 PC');
        System.assertEquals(10, results[2].convertedQuantity, 'Same UOM = same qty');
    }

    @IsTest
    static void testGetProductUOMOptions() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c WHERE SKU_Code__c = 'TST001' LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> options = UOM_Conversion_Service.getProductUOMOptions(prod.Id);
        Test.stopTest();

        System.assert(!options.isEmpty(), 'Should return at least one UOM option');
        // Should contain PC as base and CS, BX from Ordering_UOMs__c
        Set<String> codes = new Set<String>();
        for (Map<String, Object> opt : options) {
            codes.add((String) opt.get('value'));
        }
        System.assert(codes.contains('PC'), 'Should include base UOM PC');
        System.assert(codes.contains('CS'), 'Should include CS from ordering UOMs');
        System.assert(codes.contains('BX'), 'Should include BX from ordering UOMs');
    }

    @IsTest
    static void testGetProductUOMOptionsNull() {
        Test.startTest();
        List<Map<String, Object>> options = UOM_Conversion_Service.getProductUOMOptions(null);
        Test.stopTest();

        System.assert(!options.isEmpty(), 'Should return default UOM options for null product');
    }

    @IsTest
    static void testMapPicklistToCode() {
        System.assertEquals('PC', UOM_Conversion_Service.mapPicklistToCode('Pieces'));
        System.assertEquals('CS', UOM_Conversion_Service.mapPicklistToCode('Cases'));
        System.assertEquals('BX', UOM_Conversion_Service.mapPicklistToCode('Boxes'));
        System.assertEquals('KG', UOM_Conversion_Service.mapPicklistToCode('Kg'));
        System.assertEquals('LTR', UOM_Conversion_Service.mapPicklistToCode('Liters'));
        System.assertEquals('PC', UOM_Conversion_Service.mapPicklistToCode(null));
        System.assertEquals('PC', UOM_Conversion_Service.mapPicklistToCode('Unknown'));
    }

    @IsTest
    static void testMapCodeToPicklist() {
        System.assertEquals('Pieces', UOM_Conversion_Service.mapCodeToPicklist('PC'));
        System.assertEquals('Cases', UOM_Conversion_Service.mapCodeToPicklist('CS'));
        System.assertEquals('Boxes', UOM_Conversion_Service.mapCodeToPicklist('BX'));
        System.assertEquals('Kg', UOM_Conversion_Service.mapCodeToPicklist('KG'));
        System.assertEquals('Liters', UOM_Conversion_Service.mapCodeToPicklist('LTR'));
        System.assertEquals('Pieces', UOM_Conversion_Service.mapCodeToPicklist(null));
    }

    @IsTest
    static void testGetUOMIdByCode() {
        Test.startTest();
        UOM_Conversion_Service.clearCache();
        Id pcId = UOM_Conversion_Service.getUOMIdByCode('PC');
        Id nullId = UOM_Conversion_Service.getUOMIdByCode('NONEXISTENT');
        Test.stopTest();

        System.assertNotEquals(null, pcId, 'PC should resolve to a valid Id');
        System.assertEquals(null, nullId, 'Nonexistent code should return null');
    }

    @IsTest
    static void testClearCache() {
        UOM_Conversion_Service.clearCache();
        // After clear, calling convert should still work (re-builds cache)
        Decimal result = UOM_Conversion_Service.convert(null, 'DZ', 'PC', 1);
        System.assertEquals(12, result, 'Should work after cache clear');
    }
}