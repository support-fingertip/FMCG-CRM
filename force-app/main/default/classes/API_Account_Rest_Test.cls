@isTest
private class API_Account_Rest_Test {

    @TestSetup
    static void setup() {
        Account acc = new Account(
            Name = 'ABC Wholesale',
            AccountNumber = 'OUT0001',
            Outlet_Type__c = 'Grocery',
            Region__c = 'North Region',
            BillingStreet = '123 Main St',
            BillingCity = 'Delhi',
            BillingState = 'Delhi',
            BillingPostalCode = '110001',
            Phone = '+91-9876543210',
            Outlet_Latitude__c = 28.6139,
            Outlet_Longitude__c = 77.2090,
            Credit_Limit__c = 100000.00,
            Outstanding_Balance__c = 45000.00,
            Is_Active__c = true
        );
        insert acc;
    }

    @isTest
    static void testAccountList() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/account/list';
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Account_Rest.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String body = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(body);
        System.assertEquals(true, result.get('status'));

        List<Object> data = (List<Object>) result.get('data');
        System.assert(!data.isEmpty(), 'Should return at least one account');

        Map<String, Object> first = (Map<String, Object>) data[0];
        System.assertEquals('Outlet_sfa__c (Master Object)', first.get('_object_name'));
        System.assertEquals('ABC Wholesale', first.get('Name'));
    }

    @isTest
    static void testAccountDetail() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/account/detail';
        req.httpMethod = 'GET';
        req.params.put('accountId', acc.Id);

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Account_Rest.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        String body = res.responseBody.toString();
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(body);
        System.assertEquals(true, result.get('status'));

        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertEquals('ABC Wholesale', data.get('Name'));
        System.assertEquals('OUT0001', data.get('Outlet_Code__c'));
    }

    @isTest
    static void testAccountDetailNotFound() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/account/detail';
        req.httpMethod = 'GET';
        req.params.put('accountId', '001000000000000AAA');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Account_Rest.handleGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testAccountDetailMissingParam() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/account/detail';
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Account_Rest.handleGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testInvalidEndpoint() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/mobile/account/unknown';
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        API_Account_Rest.handleGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }
}
