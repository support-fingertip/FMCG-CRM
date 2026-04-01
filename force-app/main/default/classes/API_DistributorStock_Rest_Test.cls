/**
 * @description Test class for API_DistributorStock_Rest.
 *              Tests distributor stock creation endpoint with positive
 *              and negative scenarios.
 */
@isTest
private class API_DistributorStock_Rest_Test {

    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Distributor',
            Is_Active__c = true
        );
        insert testAccount;

        // Create test User and Employee
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'SalesRep',
            Email = 'testsalesrep@test.com',
            Username = 'testsalesrep@test.com.' + System.currentTimeMillis(),
            Alias = 'tsrep',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert testUser;

        Employee__c emp = new Employee__c(
            Name = 'USR001',
            User__c = testUser.Id
        );
        insert emp;

        // Create test Product Extension
        Product_Extension__c prodExt1 = new Product_Extension__c(
            Name = 'Roasted Pistachios',
            Is_Active__c = true
        );
        Product_Extension__c prodExt2 = new Product_Extension__c(
            Name = 'Medjool Dates Premium',
            Is_Active__c = true
        );
        insert new List<Product_Extension__c>{ prodExt1, prodExt2 };

        // Create test Visit
        Visit__c testVisit = new Visit__c(
            Account__c = testAccount.Id,
            Visit_Date__c = Date.today(),
            Visit_Status__c = 'Pending',
            Salesperson__c = testUser.Id
        );
        insert testVisit;
    }

    @isTest
    static void testCreateStockSuccess() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Distributor' LIMIT 1];
        Visit__c visit = [SELECT Id, Name FROM Visit__c LIMIT 1];

        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('userId', 'USR001');
        requestBody.put('accountId', acc.Id);
        requestBody.put('visitId', visit.Name);
        requestBody.put('products', new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => 'PROD001',
                'productName' => 'Roasted Pistachios',
                'openingStock' => 100,
                'closingStock' => 80,
                'damagedStock' => 5
            },
            new Map<String, Object>{
                'productId' => 'PROD002',
                'productName' => 'Medjool Dates Premium',
                'openingStock' => 50,
                'closingStock' => 40,
                'damagedStock' => 2
            }
        });

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/mobile/distributor-stock/create';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestBody));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        API_DistributorStock_Rest.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
            res.responseBody.toString()
        );
        System.assertEquals(200, res.statusCode, 'Should return 200');
        System.assertEquals(true, responseBody.get('status'), 'Status should be true');

        List<Distributor_Stock__c> stocks = [
            SELECT Id, Account__c, Opening_Stock__c, Damaged_Qty__c, Is_Current__c
            FROM Distributor_Stock__c
            WHERE Account__c = :acc.Id
        ];
        System.assertEquals(2, stocks.size(), 'Two stock records should be created');
    }

    @isTest
    static void testCreateStockWithTypoAccountId() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Distributor' LIMIT 1];

        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('userId', 'USR001');
        requestBody.put('accoutnId', acc.Id);
        requestBody.put('products', new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => 'PROD001',
                'productName' => 'Roasted Pistachios',
                'openingStock' => 50,
                'closingStock' => 45,
                'damagedStock' => 0
            }
        });

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/mobile/distributor-stock/create';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestBody));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        API_DistributorStock_Rest.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
            res.responseBody.toString()
        );
        System.assertEquals(200, res.statusCode, 'Should accept accoutnId typo');
        System.assertEquals(true, responseBody.get('status'), 'Status should be true');
    }

    @isTest
    static void testCreateStockMissingUserId() {
        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('userId', '');
        requestBody.put('accountId', '001000000000001');
        requestBody.put('products', new List<Object>());

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/mobile/distributor-stock/create';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestBody));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        API_DistributorStock_Rest.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 for missing userId');
    }

    @isTest
    static void testCreateStockInvalidUser() {
        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('userId', 'INVALID_USER');
        requestBody.put('accountId', '001000000000001');
        requestBody.put('products', new List<Object>());

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/mobile/distributor-stock/create';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestBody));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        API_DistributorStock_Rest.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 for invalid user');
    }

    @isTest
    static void testCreateStockMissingAccount() {
        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('userId', 'USR001');
        requestBody.put('accountId', '');
        requestBody.put('products', new List<Object>());

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/mobile/distributor-stock/create';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestBody));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        API_DistributorStock_Rest.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 for missing accountId');
    }

    @isTest
    static void testCreateStockEmptyProducts() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Distributor' LIMIT 1];

        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('userId', 'USR001');
        requestBody.put('accountId', acc.Id);
        requestBody.put('products', new List<Object>());

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/mobile/distributor-stock/create';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestBody));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        API_DistributorStock_Rest.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 for empty products');
    }

    @isTest
    static void testCreateStockProductNotFound() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Distributor' LIMIT 1];

        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('userId', 'USR001');
        requestBody.put('accountId', acc.Id);
        requestBody.put('products', new List<Map<String, Object>>{
            new Map<String, Object>{
                'productId' => 'PROD999',
                'productName' => 'Nonexistent Product',
                'openingStock' => 10,
                'closingStock' => 10,
                'damagedStock' => 0
            }
        });

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/mobile/distributor-stock/create';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestBody));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        API_DistributorStock_Rest.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 for product not found');
    }

    @isTest
    static void testInvalidEndpoint() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/mobile/distributor-stock/invalid';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        API_DistributorStock_Rest.handlePost();
        Test.stopTest();

        RestResponse res = RestContext.response;
        System.assertEquals(400, res.statusCode, 'Should return 400 for invalid endpoint');
    }
}
