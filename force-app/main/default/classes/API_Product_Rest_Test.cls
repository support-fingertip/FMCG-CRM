@isTest
private class API_Product_Rest_Test {

    @TestSetup
    static void setup() {
        Product_Category__c category = new Product_Category__c(
            Name = 'Grains',
            Category_Code__c = 'GRN',
            Is_Active__c = true,
            Level__c = 'Category'
        );
        insert category;

        Product2 prod = TestDataFactory.createProduct('Rice Premium 25kg', 'RICE-P-25');
        insert prod;

        Product_Extension__c pe = new Product_Extension__c(
            Name = 'Rice Premium 25kg',
            Product__c = prod.Id,
            Product_Category__c = category.Id,
            HSN_SAC_Code__c = 'RICE-P-25',
            Weight__c = 25,
            Weight_Unit__c = 'kg',
            Is_Active__c = true,
            Min_Order_Qty__c = 1,
            Barcode_EAN__c = '1234567890123'
        );
        insert pe;

        Scheme__c scheme = TestDataFactory.createScheme('Rice Discount', 'SCH-001', 'Percentage');
        scheme.Product__c = prod.Id;
        scheme.Discount_Percent__c = 5.00;
        insert scheme;
    }

    @isTest
    static void testProductList() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/product/list';
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Product_Rest.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String body = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(body);
        System.assertEquals(true, result.get('status'));

        List<Object> data = (List<Object>) result.get('data');
        System.assert(!data.isEmpty(), 'Should return at least one product');

        Map<String, Object> first = (Map<String, Object>) data[0];
        System.assertEquals('Product_sfa__c (Master Object)', first.get('_object_name'));
        System.assertEquals('Rice Premium 25kg', first.get('Name'));
        System.assertEquals('Grains', first.get('Category__c'));
    }

    @isTest
    static void testProductListNoDiscount() {
        // Delete schemes to test no-discount path
        delete [SELECT Id FROM Scheme__c];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/product/list';
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Product_Rest.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String body = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(body);
        System.assertEquals(true, result.get('status'));

        List<Object> data = (List<Object>) result.get('data');
        Map<String, Object> first = (Map<String, Object>) data[0];
        System.assertEquals(0, (Integer) first.get('Discount_Percentage__c'));
    }

    @isTest
    static void testInvalidEndpoint() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/product/unknown';
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Product_Rest.handleGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }
}
