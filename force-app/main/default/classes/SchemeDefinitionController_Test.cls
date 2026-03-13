@IsTest
private class SchemeDefinitionController_Test {

    @TestSetup
    static void setup() {
        Product_Extension__c prod = new Product_Extension__c(
            Name = 'Test Product', SKU_Code__c = 'TST-001',
            MRP__c = 100, Unit_Price__c = 70, Is_Active__c = true
        );
        insert prod;

        Scheme__c scheme = TestDataFactory.createScheme(
            'Test Scheme', 'SCH-TEST-001', 'Free Products', 'Same Product (QTY)'
        );
        scheme.Free_Quantity__c = 1;
        scheme.Min_Quantity__c = 3;
        scheme.Budget_Amount__c = 10000;
        insert scheme;

        insert new Scheme_Product__c(
            Scheme__c = scheme.Id, Product_Ext__c = prod.Id,
            Is_Buy_Product__c = true, Is_Get_Product__c = false, Min_Quantity__c = 3
        );

        insert new Scheme_Slab__c(
            Scheme__c = scheme.Id, Slab_Type__c = 'Quantity',
            Min_Value__c = 10, Max_Value__c = 50,
            Discount_Type__c = 'Free Product', Free_Quantity__c = 2, Is_Active__c = true
        );

        insert new Scheme_Mapping__c(
            Scheme__c = scheme.Id, Zone__c = 'North', Customer_Type__c = 'D2R', Is_Active__c = true
        );
    }

    @IsTest
    static void testGetScheme() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c LIMIT 1];
        Test.startTest();
        Scheme__c result = SchemeDefinitionController.getScheme(scheme.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Test Scheme', result.Name);
        System.assertEquals(1, result.Scheme_Products__r.size());
        System.assertEquals(1, result.Scheme_Slabs__r.size());
        System.assertEquals(1, result.Scheme_Mappings__r.size());
    }

    @IsTest
    static void testGetSchemeNotFound() {
        try {
            Test.startTest();
            SchemeDefinitionController.getScheme('a0000000000FAKE');
            Test.stopTest();
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Scheme not found') || e.getMessage().length() > 0);
        }
    }

    @IsTest
    static void testSaveNewScheme() {
        Product_Extension__c prod = [SELECT Id FROM Product_Extension__c LIMIT 1];

        Scheme__c newScheme = new Scheme__c(
            Name = 'New Discount Scheme',
            Scheme_Code__c = 'SCH-TEST-NEW',
            Scheme_Category__c = 'Discount in %',
            Scheme_Type__c = 'Same Product (QTY)',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(3),
            Status__c = 'Draft',
            Discount_Percent__c = 5,
            Priority__c = 2
        );

        List<Scheme_Product__c> products = new List<Scheme_Product__c>{
            new Scheme_Product__c(
                Product_Ext__c = prod.Id, Is_Buy_Product__c = true,
                Is_Get_Product__c = false, Min_Quantity__c = 5
            )
        };

        List<Scheme_Slab__c> slabs = new List<Scheme_Slab__c>{
            new Scheme_Slab__c(
                Slab_Type__c = 'Value', Min_Value__c = 1000, Max_Value__c = 5000,
                Discount_Type__c = 'Percent', Discount_Value__c = 5, Is_Active__c = true
            )
        };

        List<Scheme_Mapping__c> mappings = new List<Scheme_Mapping__c>{
            new Scheme_Mapping__c(Zone__c = 'South', Customer_Type__c = 'D2R', Is_Active__c = true)
        };

        Test.startTest();
        Id schemeId = SchemeDefinitionController.saveScheme(
            newScheme, products, slabs, mappings,
            new List<Id>(), new List<Id>(), new List<Id>()
        );
        Test.stopTest();

        System.assertNotEquals(null, schemeId);
        Scheme__c saved = [SELECT Name, Scheme_Code__c FROM Scheme__c WHERE Id = :schemeId];
        System.assertEquals('New Discount Scheme', saved.Name);
    }

    @IsTest
    static void testSaveWithDeletes() {
        Scheme__c scheme = [SELECT Id FROM Scheme__c LIMIT 1];
        Scheme_Product__c prod = [SELECT Id FROM Scheme_Product__c WHERE Scheme__c = :scheme.Id LIMIT 1];
        Scheme_Slab__c slab = [SELECT Id FROM Scheme_Slab__c WHERE Scheme__c = :scheme.Id LIMIT 1];
        Scheme_Mapping__c mapping = [SELECT Id FROM Scheme_Mapping__c WHERE Scheme__c = :scheme.Id LIMIT 1];

        scheme.Name = 'Updated Scheme';

        Test.startTest();
        Id schemeId = SchemeDefinitionController.saveScheme(
            scheme,
            new List<Scheme_Product__c>(),
            new List<Scheme_Slab__c>(),
            new List<Scheme_Mapping__c>(),
            new List<Id>{ prod.Id },
            new List<Id>{ slab.Id },
            new List<Id>{ mapping.Id }
        );
        Test.stopTest();

        System.assertEquals(scheme.Id, schemeId);
        System.assertEquals(0, [SELECT COUNT() FROM Scheme_Product__c WHERE Scheme__c = :schemeId]);
        System.assertEquals(0, [SELECT COUNT() FROM Scheme_Slab__c WHERE Scheme__c = :schemeId]);
        System.assertEquals(0, [SELECT COUNT() FROM Scheme_Mapping__c WHERE Scheme__c = :schemeId]);
    }

    @IsTest
    static void testSearchProducts() {
        Test.startTest();
        List<Product_Extension__c> results = SchemeDefinitionController.searchProducts('Test');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Test Product', results[0].Name);
    }

    @IsTest
    static void testSearchProductsNoResults() {
        Test.startTest();
        List<Product_Extension__c> results = SchemeDefinitionController.searchProducts('ZZZZNOTFOUND');
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testGenerateSchemeCode() {
        Test.startTest();
        String code = SchemeDefinitionController.generateSchemeCode();
        Test.stopTest();

        System.assert(code.startsWith('SCH-'), 'Code should start with SCH-');
    }
}
