/**
 * @description Test class for TAM_FilterEngine_Service.
 *              Validates WHERE clause generation and JSON filter parsing.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class TAM_FilterEngine_Service_Test {

    @testSetup
    static void setupData() {
        Target_Period__c period = new Target_Period__c(
            Name = 'Test Period',
            Start_Date__c = Date.today().toStartOfMonth(),
            End_Date__c = Date.today().toStartOfMonth().addMonths(1).addDays(-1),
            Is_Active__c = true,
            Type__c = 'Monthly'
        );
        insert period;

        Target_Criteria__c criteria = new Target_Criteria__c(
            Name = 'Test Criteria',
            Object__c = 'Sales_Order__c',
            Operator__c = 'SUM',
            Field__c = 'Amount__c',
            Date_Field__c = 'Order_Date__c',
            User_Field__c = 'OwnerId',
            Active__c = true
        );
        insert criteria;
    }

    @isTest
    static void testBuildWhereClause_NullInput() {
        Test.startTest();
        String result = TAM_FilterEngine_Service.buildWhereClause(null, null);
        Test.stopTest();

        System.assertEquals('', result, 'Null input should return empty string');
    }

    @isTest
    static void testBuildWhereClause_BlankInput() {
        Test.startTest();
        String result = TAM_FilterEngine_Service.buildWhereClause('', '');
        Test.stopTest();

        System.assertEquals('', result, 'Blank input should return empty string');
    }

    @isTest
    static void testBuildWhereClause_SingleStringFilter() {
        String json = '{"filters": [{"id": 1, "field": "Status__c", "operator": "=", "value": "Active", "type": "String"}]}';

        Test.startTest();
        String result = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();

        System.assert(result.contains('Status__c'), 'Result should contain field name');
        System.assert(result.contains('Active'), 'Result should contain filter value');
        System.assert(result.startsWith(' AND ('), 'Result should start with AND');
    }

    @isTest
    static void testBuildWhereClause_MultipleFiltersWithLogic() {
        String json = '{"filters": ['
            + '{"id": 1, "field": "Status__c", "operator": "=", "value": "Active", "type": "String"},'
            + '{"id": 2, "field": "Region__c", "operator": "=", "value": "North", "type": "String"}'
            + ']}';

        Test.startTest();
        String result = TAM_FilterEngine_Service.buildWhereClause(json, '1 AND 2');
        Test.stopTest();

        System.assert(result.contains('Status__c'), 'Result should contain first field');
        System.assert(result.contains('Region__c'), 'Result should contain second field');
        System.assert(result.contains('AND'), 'Result should contain AND logic');
    }

    @isTest
    static void testBuildWhereClause_PicklistFilter() {
        String json = '{"filters": [{"id": 1, "field": "Type__c", "operator": "=", "value": "Wholesale", "type": "Picklist"}]}';

        Test.startTest();
        String result = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();

        System.assert(result.contains('Type__c'), 'Result should contain picklist field');
        System.assert(result.contains('Wholesale'), 'Result should contain picklist value');
    }

    @isTest
    static void testBuildWhereClause_NumberFilter() {
        String json = '{"filters": [{"id": 1, "field": "Amount__c", "operator": ">", "value": 1000, "type": "Number"}]}';

        Test.startTest();
        String result = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();

        System.assert(result.contains('Amount__c'), 'Result should contain number field');
        System.assert(result.contains('1000'), 'Result should contain number value');
    }

    @isTest
    static void testBuildWhereClause_DateFilter() {
        String json = '{"filters": [{"id": 1, "field": "Order_Date__c", "operator": ">=", "value": "2024-01-01", "type": "Date"}]}';

        Test.startTest();
        String result = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();

        System.assert(result.contains('Order_Date__c'), 'Result should contain date field');
        System.assertNotEquals('', result, 'Date filter should produce non-empty result');
    }

    @isTest
    static void testBuildWhereClause_BooleanFilter() {
        String json = '{"filters": [{"id": 1, "field": "Is_Active__c", "operator": "=", "value": true, "type": "Boolean"}]}';

        Test.startTest();
        String result = TAM_FilterEngine_Service.buildWhereClause(json, null);
        Test.stopTest();

        System.assert(result.contains('Is_Active__c'), 'Result should contain boolean field');
        System.assert(result.contains('TRUE'), 'Result should contain TRUE for boolean true');
    }

    @isTest
    static void testParseFilters_EmptyJson() {
        Test.startTest();
        TAM_FilterEngine_Service.FilterDefinition def = TAM_FilterEngine_Service.parseFilters('');
        Test.stopTest();

        System.assertNotEquals(null, def, 'FilterDefinition should not be null');
        System.assertEquals(0, def.filters.size(), 'Empty JSON should produce empty filter list');
    }

    @isTest
    static void testParseFilters_ValidJson() {
        String json = '{"filters": ['
            + '{"id": 1, "field": "Status__c", "operator": "=", "value": "Active", "type": "String"},'
            + '{"id": 2, "field": "Amount__c", "operator": ">", "value": 500, "type": "Number"}'
            + ']}';

        Test.startTest();
        TAM_FilterEngine_Service.FilterDefinition def = TAM_FilterEngine_Service.parseFilters(json);
        Test.stopTest();

        System.assertEquals(2, def.filters.size(), 'Should parse 2 filters');
        System.assertEquals('Status__c', def.filters[0].field, 'First filter field should be Status__c');
        System.assertEquals('String', def.filters[0].type, 'First filter type should be String');
        System.assertEquals('Amount__c', def.filters[1].field, 'Second filter field should be Amount__c');
        System.assertEquals('Number', def.filters[1].type, 'Second filter type should be Number');
    }
}
