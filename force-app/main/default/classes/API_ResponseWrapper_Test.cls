@isTest
private class API_ResponseWrapper_Test {

    @isTest
    static void testSuccessResponse() {
        Map<String, Object> data = new Map<String, Object>();
        data.put('key', 'value');

        String json = API_ResponseWrapper.success('Test success', data);
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(json);

        System.assertEquals(true, result.get('status'));
        System.assertEquals('Test success', result.get('message'));
        System.assertNotEquals(null, result.get('data'));
    }

    @isTest
    static void testSuccessResponseNullData() {
        String json = API_ResponseWrapper.success('No data', null);
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(json);

        System.assertEquals(true, result.get('status'));
        System.assertEquals(false, result.containsKey('data'));
    }

    @isTest
    static void testErrorResponse() {
        String json = API_ResponseWrapper.error('Something went wrong');
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(json);

        System.assertEquals(false, result.get('status'));
        System.assertEquals('Something went wrong', result.get('message'));
    }

    @isTest
    static void testSendSuccess() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        API_ResponseWrapper.sendSuccess('OK', new Map<String, Object>{ 'id' => '123' });

        System.assertEquals(200, res.statusCode);
        System.assert(res.responseBody != null);
    }

    @isTest
    static void testSendError() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        API_ResponseWrapper.sendError('Bad request');

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testSendServerError() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        API_ResponseWrapper.sendServerError('Internal error');

        System.assertEquals(500, res.statusCode);
    }

    @isTest
    static void testSendResponseWithNullContext() {
        RestContext.response = null;

        API_ResponseWrapper.sendResponse(200, '{"status":true}');

        System.assertNotEquals(null, RestContext.response);
        System.assertEquals(200, RestContext.response.statusCode);
    }
}
