/**
 * @description Tests for DKD_QueryEngine_Service. Inserts a small set of
 *              Sales_Order__c records with known values and verifies the
 *              query engine returns expected aggregations, groupings, and
 *              time series.
 */
@IsTest
private class DKD_QueryEngine_Service_Test {

    @TestSetup
    static void setup() {
        // ── Metrics ──
        List<KPI_Metric__c> metrics = new List<KPI_Metric__c>();
        metrics.add(new KPI_Metric__c(
            Name = 'Test Revenue',
            Metric_Key__c = 'test_revenue',
            Label__c = 'Test Revenue',
            Source_Object__c = 'Sales_Order__c',
            Aggregation__c = 'SUM',
            Aggregate_Field__c = 'Total_Net_Amount__c',
            Date_Field__c = 'Order_Date__c',
            User_Field__c = 'Salesperson__c',
            Default_Filter__c = 'Status__c IN (\'Approved\',\'Delivered\')',
            Format__c = 'Currency',
            Category__c = 'Sales',
            Is_Active__c = true
        ));
        metrics.add(new KPI_Metric__c(
            Name = 'Test Order Count',
            Metric_Key__c = 'test_order_count',
            Label__c = 'Test Order Count',
            Source_Object__c = 'Sales_Order__c',
            Aggregation__c = 'COUNT',
            Date_Field__c = 'Order_Date__c',
            User_Field__c = 'Salesperson__c',
            Default_Filter__c = 'Status__c IN (\'Approved\',\'Delivered\')',
            Format__c = 'Number',
            Category__c = 'Sales',
            Is_Active__c = true
        ));
        metrics.add(new KPI_Metric__c(
            Name = 'Test AOV',
            Metric_Key__c = 'test_avg_order',
            Label__c = 'Test AOV',
            Source_Object__c = 'Sales_Order__c',
            Aggregation__c = 'AVG',
            Aggregate_Field__c = 'Total_Net_Amount__c',
            Date_Field__c = 'Order_Date__c',
            User_Field__c = 'Salesperson__c',
            Default_Filter__c = 'Status__c IN (\'Approved\',\'Delivered\')',
            Format__c = 'Currency',
            Category__c = 'Sales',
            Is_Active__c = true
        ));
        metrics.add(new KPI_Metric__c(
            Name = 'Test No UserField',
            Metric_Key__c = 'test_no_user_field',
            Label__c = 'Test No User Field',
            Source_Object__c = 'Sales_Order__c',
            Aggregation__c = 'COUNT',
            Date_Field__c = 'Order_Date__c',
            Format__c = 'Number',
            Category__c = 'Sales',
            Is_Active__c = true
        ));
        insert metrics;

        // ── Account ──
        Account acc = new Account(Name = 'DKD Test Account');
        insert acc;

        // ── Sales Orders ──
        // Bypass order triggers to avoid complex rollups during test setup
        TriggerHandler.bypass('OMS_SalesOrder_TriggerHandler');
        try {
            List<Sales_Order__c> orders = new List<Sales_Order__c>();
            Id uid = UserInfo.getUserId();

            // 3 Approved orders in this month (total 6000, avg 2000)
            orders.add(new Sales_Order__c(
                Account__c = acc.Id,
                Order_Date__c = Date.today(),
                Status__c = 'Approved',
                Salesperson__c = uid,
                Total_Net_Amount__c = 1000
            ));
            orders.add(new Sales_Order__c(
                Account__c = acc.Id,
                Order_Date__c = Date.today(),
                Status__c = 'Approved',
                Salesperson__c = uid,
                Total_Net_Amount__c = 2000
            ));
            orders.add(new Sales_Order__c(
                Account__c = acc.Id,
                Order_Date__c = Date.today(),
                Status__c = 'Approved',
                Salesperson__c = uid,
                Total_Net_Amount__c = 3000
            ));

            // 1 Draft order — should be excluded by default filter
            orders.add(new Sales_Order__c(
                Account__c = acc.Id,
                Order_Date__c = Date.today(),
                Status__c = 'Draft',
                Salesperson__c = uid,
                Total_Net_Amount__c = 9999
            ));

            // 1 Approved order outside the date range (should be excluded)
            orders.add(new Sales_Order__c(
                Account__c = acc.Id,
                Order_Date__c = Date.today().addMonths(-6),
                Status__c = 'Approved',
                Salesperson__c = uid,
                Total_Net_Amount__c = 5000
            ));

            insert orders;
        } finally {
            TriggerHandler.clearBypass('OMS_SalesOrder_TriggerHandler');
        }
    }

    // ── queryMetric ─────────────────────────────────────────────────────────

    @IsTest
    static void testQueryMetric_Sum_NoGroupBy() {
        Test.startTest();
        List<Map<String, Object>> results = DKD_QueryEngine_Service.queryMetric(
            'test_revenue',
            null,
            null,
            Date.today().addDays(-1),
            Date.today().addDays(1),
            'self'
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Single grand total row expected');
        Decimal value = (Decimal) results[0].get('value');
        System.assertEquals(6000, value, 'SUM should be 1000 + 2000 + 3000 = 6000');
    }

    @IsTest
    static void testQueryMetric_Count() {
        Test.startTest();
        List<Map<String, Object>> results = DKD_QueryEngine_Service.queryMetric(
            'test_order_count',
            null,
            null,
            Date.today().addDays(-1),
            Date.today().addDays(1),
            'self'
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        Integer cnt = Integer.valueOf(results[0].get('value'));
        System.assertEquals(3, cnt, 'COUNT should be 3 (only Approved in range)');
    }

    @IsTest
    static void testQueryMetric_Avg() {
        Test.startTest();
        List<Map<String, Object>> results = DKD_QueryEngine_Service.queryMetric(
            'test_avg_order',
            null,
            null,
            Date.today().addDays(-1),
            Date.today().addDays(1),
            'self'
        );
        Test.stopTest();

        Decimal avg = (Decimal) results[0].get('value');
        System.assertEquals(2000, avg, 'AVG should be (1000+2000+3000)/3 = 2000');
    }

    @IsTest
    static void testQueryMetric_GroupBy() {
        Test.startTest();
        List<Map<String, Object>> results = DKD_QueryEngine_Service.queryMetric(
            'test_revenue',
            null,
            'Status__c',
            Date.today().addDays(-1),
            Date.today().addDays(1),
            'self'
        );
        Test.stopTest();

        System.assertEquals(1, results.size(),
            'Only Approved status should remain after default filter');
        System.assertEquals('Approved', results[0].get('groupKey'));
        System.assertEquals(6000, (Decimal) results[0].get('value'));
    }

    @IsTest
    static void testQueryMetric_DateRangeExclusion() {
        Test.startTest();
        // Use a very narrow date range that excludes the today records
        List<Map<String, Object>> results = DKD_QueryEngine_Service.queryMetric(
            'test_revenue',
            null,
            null,
            Date.today().addMonths(-7),
            Date.today().addMonths(-5),
            'self'
        );
        Test.stopTest();

        Decimal value = (Decimal) results[0].get('value');
        System.assertEquals(5000, value,
            'Only the 6-month-old order (5000) should match');
    }

    @IsTest
    static void testQueryMetric_UserScope_Org() {
        Test.startTest();
        List<Map<String, Object>> results = DKD_QueryEngine_Service.queryMetric(
            'test_revenue',
            null,
            null,
            Date.today().addDays(-1),
            Date.today().addDays(1),
            'org'
        );
        Test.stopTest();

        Decimal value = (Decimal) results[0].get('value');
        System.assertEquals(6000, value,
            'Org scope should return all records in range');
    }

    @IsTest
    static void testQueryMetric_UserScope_Team() {
        Test.startTest();
        List<Map<String, Object>> results = DKD_QueryEngine_Service.queryMetric(
            'test_revenue',
            null,
            null,
            Date.today().addDays(-1),
            Date.today().addDays(1),
            'team'
        );
        Test.stopTest();

        // Team scope at minimum includes the current user
        Decimal value = (Decimal) results[0].get('value');
        System.assertEquals(6000, value, 'Team scope should at least include self');
    }

    @IsTest
    static void testQueryMetric_MetricNotFound() {
        Boolean thrown = false;
        Test.startTest();
        try {
            DKD_QueryEngine_Service.queryMetric(
                'nonexistent_metric', null, null, Date.today(), Date.today(), 'self'
            );
        } catch (DKD_QueryEngine_Service.DKD_QueryException e) {
            thrown = true;
            System.assert(e.getMessage().contains('not found'));
        }
        Test.stopTest();
        System.assert(thrown, 'Should throw DKD_QueryException for missing metric');
    }

    @IsTest
    static void testQueryMetric_EmptyResult() {
        Test.startTest();
        // Future date range — no orders
        List<Map<String, Object>> results = DKD_QueryEngine_Service.queryMetric(
            'test_revenue',
            null,
            null,
            Date.today().addYears(5),
            Date.today().addYears(5).addDays(30),
            'self'
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Empty result should return a zero row');
        System.assertEquals(0, (Integer) results[0].get('value'));
    }

    @IsTest
    static void testQueryMetric_NoUserField() {
        Test.startTest();
        // Metric with no user field — userScope should be ignored
        List<Map<String, Object>> results = DKD_QueryEngine_Service.queryMetric(
            'test_no_user_field',
            null,
            null,
            Date.today().addDays(-1),
            Date.today().addDays(1),
            'self'
        );
        Test.stopTest();

        Integer cnt = Integer.valueOf(results[0].get('value'));
        System.assertEquals(3, cnt, 'Should count all 3 approved orders regardless of scope');
    }

    // ── queryMultipleMetrics ────────────────────────────────────────────────

    @IsTest
    static void testQueryMultipleMetrics() {
        Test.startTest();
        Map<String, Decimal> results = DKD_QueryEngine_Service.queryMultipleMetrics(
            new List<String>{ 'test_revenue', 'test_order_count', 'test_avg_order' },
            null,
            Date.today().addDays(-1),
            Date.today().addDays(1),
            'self'
        );
        Test.stopTest();

        System.assertEquals(3, results.size());
        System.assertEquals(6000, results.get('test_revenue'));
        System.assertEquals(3, results.get('test_order_count'));
        System.assertEquals(2000, results.get('test_avg_order'));
    }

    @IsTest
    static void testQueryMultipleMetrics_EmptyList() {
        Test.startTest();
        Map<String, Decimal> results = DKD_QueryEngine_Service.queryMultipleMetrics(
            new List<String>(), null, Date.today(), Date.today(), 'self'
        );
        Test.stopTest();
        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testQueryMultipleMetrics_FailsSoft() {
        Test.startTest();
        Map<String, Decimal> results = DKD_QueryEngine_Service.queryMultipleMetrics(
            new List<String>{ 'test_revenue', 'bogus_key' },
            null,
            Date.today().addDays(-1),
            Date.today().addDays(1),
            'self'
        );
        Test.stopTest();
        System.assertEquals(6000, results.get('test_revenue'));
        System.assertEquals(0, results.get('bogus_key'),
            'Bad key should return 0, not throw');
    }

    // ── queryTimeSeries ─────────────────────────────────────────────────────

    @IsTest
    static void testQueryTimeSeries_Month() {
        Test.startTest();
        List<Map<String, Object>> series = DKD_QueryEngine_Service.queryTimeSeries(
            'test_revenue',
            null,
            Date.today().addMonths(-12),
            Date.today().addDays(1),
            'MONTH',
            'self'
        );
        Test.stopTest();

        System.assert(series.size() >= 1, 'Should return at least one month bucket');
        // Verify each row has the expected keys
        Map<String, Object> first = series[0];
        System.assert(first.containsKey('period'));
        System.assert(first.containsKey('label'));
        System.assert(first.containsKey('value'));
        System.assert(first.containsKey('count'));
    }

    @IsTest
    static void testQueryTimeSeries_InvalidInterval() {
        Boolean thrown = false;
        Test.startTest();
        try {
            DKD_QueryEngine_Service.queryTimeSeries(
                'test_revenue', null, Date.today(), Date.today(), 'FORTNIGHT', 'self'
            );
        } catch (DKD_QueryEngine_Service.DKD_QueryException e) {
            thrown = true;
            System.assert(e.getMessage().contains('interval'));
        }
        Test.stopTest();
        System.assert(thrown);
    }

    @IsTest
    static void testQueryTimeSeries_DefaultInterval() {
        Test.startTest();
        // Blank interval should default to MONTH
        List<Map<String, Object>> series = DKD_QueryEngine_Service.queryTimeSeries(
            'test_revenue',
            null,
            Date.today().addMonths(-12),
            Date.today().addDays(1),
            null,
            'self'
        );
        Test.stopTest();
        System.assert(series != null);
    }

    @IsTest
    static void testQueryTimeSeries_MetricNotFound() {
        Boolean thrown = false;
        Test.startTest();
        try {
            DKD_QueryEngine_Service.queryTimeSeries(
                'nope', null, Date.today(), Date.today(), 'MONTH', 'self'
            );
        } catch (DKD_QueryEngine_Service.DKD_QueryException e) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown);
    }

    // ── SOQL Injection Safety ───────────────────────────────────────────────

    @IsTest
    static void testSoqlInjection_GroupBy() {
        Boolean thrown = false;
        Test.startTest();
        try {
            DKD_QueryEngine_Service.queryMetric(
                'test_revenue',
                null,
                'Status__c OR 1=1',  // injection attempt
                Date.today().addDays(-1),
                Date.today().addDays(1),
                'self'
            );
        } catch (DKD_QueryEngine_Service.DKD_QueryException e) {
            thrown = true;
            System.assert(e.getMessage().contains('Invalid field name'));
        }
        Test.stopTest();
        System.assert(thrown, 'Malicious groupBy should be rejected');
    }
}
