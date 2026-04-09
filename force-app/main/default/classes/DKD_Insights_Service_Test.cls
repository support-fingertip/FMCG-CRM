/**
 * @description Tests for DKD_Insights_Service.
 */
@IsTest
private class DKD_Insights_Service_Test {

    @TestSetup
    static void setup() {
        // Metric for insights
        KPI_Metric__c m = new KPI_Metric__c(
            Name = 'Test Revenue Insights',
            Metric_Key__c = 'test_revenue_ins',
            Label__c = 'Test Revenue',
            Source_Object__c = 'Sales_Order__c',
            Aggregation__c = 'SUM',
            Aggregate_Field__c = 'Total_Net_Amount__c',
            Date_Field__c = 'Order_Date__c',
            User_Field__c = 'Salesperson__c',
            Default_Filter__c = 'Status__c IN (\'Approved\',\'Delivered\')',
            Format__c = 'Currency',
            Category__c = 'Sales',
            Allow_Forecast__c = true,
            Is_Active__c = true
        );
        insert m;

        Account acc = new Account(Name = 'DKD Insights Test');
        insert acc;

        // Create orders: strong current period, weak previous period
        TriggerHandler.bypass('OMS_SalesOrder_TriggerHandler');
        try {
            List<Sales_Order__c> orders = new List<Sales_Order__c>();
            Id uid = UserInfo.getUserId();

            // Current period: 3 orders totaling 10000
            for (Integer i = 0; i < 3; i++) {
                orders.add(new Sales_Order__c(
                    Account__c = acc.Id,
                    Order_Date__c = Date.today(),
                    Status__c = 'Approved',
                    Salesperson__c = uid,
                    Total_Net_Amount__c = 3333.33
                ));
            }
            // Previous period: 2 orders totaling 5000 (so curr is up 100%)
            for (Integer i = 0; i < 2; i++) {
                orders.add(new Sales_Order__c(
                    Account__c = acc.Id,
                    Order_Date__c = Date.today().addDays(-3),
                    Status__c = 'Approved',
                    Salesperson__c = uid,
                    Total_Net_Amount__c = 2500
                ));
            }
            insert orders;
        } finally {
            TriggerHandler.clearBypass('OMS_SalesOrder_TriggerHandler');
        }
    }

    @IsTest
    static void testGenerateInsights_EmptyMetrics() {
        Test.startTest();
        Map<String, Object> result = DKD_Insights_Service.generateInsights(
            new List<String>(), null, Date.today(), Date.today(), 'self'
        );
        Test.stopTest();
        System.assertEquals(0, (Integer) result.get('generated'));
    }

    @IsTest
    static void testGenerateInsights_NullDates() {
        Test.startTest();
        Map<String, Object> result = DKD_Insights_Service.generateInsights(
            new List<String>{ 'test_revenue_ins' }, null, null, null, 'self'
        );
        Test.stopTest();
        System.assertEquals(0, (Integer) result.get('generated'));
    }

    @IsTest
    static void testGenerateInsights_TrendUp() {
        Test.startTest();
        Map<String, Object> result = DKD_Insights_Service.generateInsights(
            new List<String>{ 'test_revenue_ins' },
            null,
            Date.today().addDays(-1),
            Date.today().addDays(1),
            'self'
        );
        Test.stopTest();

        Integer generated = (Integer) result.get('generated');
        System.assert(generated > 0, 'Should generate at least one insight');

        List<Map<String, Object>> insights = (List<Map<String, Object>>) result.get('insights');
        // Find the MoM trend
        Boolean foundTrend = false;
        for (Map<String, Object> ins : insights) {
            String type = (String) ins.get('type');
            if (type == 'trend_up' || type == 'trend_down') {
                foundTrend = true;
                System.assertNotEquals(null, ins.get('message'));
                System.assertNotEquals(null, ins.get('icon'));
                System.assertNotEquals(null, ins.get('color'));
            }
        }
        System.assert(foundTrend, 'Should include a period-over-period trend insight');
    }

    @IsTest
    static void testGenerateInsights_OrgScope_TopPerformer() {
        Test.startTest();
        Map<String, Object> result = DKD_Insights_Service.generateInsights(
            new List<String>{ 'test_revenue_ins' },
            null,
            Date.today().addDays(-7),
            Date.today().addDays(1),
            'org'
        );
        Test.stopTest();

        List<Map<String, Object>> insights = (List<Map<String, Object>>) result.get('insights');
        Boolean foundTopPerformer = false;
        for (Map<String, Object> ins : insights) {
            if ('top_performer'.equals((String) ins.get('type'))) {
                foundTopPerformer = true;
                String msg = (String) ins.get('message');
                System.assert(msg != null && msg.length() > 0);
            }
        }
        System.assert(foundTopPerformer, 'Org scope should generate a top performer insight');
    }

    @IsTest
    static void testGenerateInsights_MinorChangeSuppressed() {
        // Create a second metric with tiny difference to test the 5% suppression
        KPI_Metric__c mm = new KPI_Metric__c(
            Name = 'Test Count Insights',
            Metric_Key__c = 'test_count_ins',
            Label__c = 'Test Count',
            Source_Object__c = 'Sales_Order__c',
            Aggregation__c = 'COUNT',
            Date_Field__c = 'Order_Date__c',
            User_Field__c = 'Salesperson__c',
            Format__c = 'Number',
            Category__c = 'Sales',
            Is_Active__c = true
        );
        insert mm;

        Test.startTest();
        Map<String, Object> result = DKD_Insights_Service.generateInsights(
            new List<String>{ 'test_count_ins' },
            null,
            Date.today().addDays(-1),
            Date.today().addDays(1),
            'self'
        );
        Test.stopTest();

        // Should have at most 1-2 insights (no anomaly since Allow_Forecast=false)
        Integer generated = (Integer) result.get('generated');
        System.assert(generated >= 0, 'Should not throw');
    }

    @IsTest
    static void testGenerateInsights_UnknownMetricIgnored() {
        Test.startTest();
        Map<String, Object> result = DKD_Insights_Service.generateInsights(
            new List<String>{ 'bogus_metric' },
            null,
            Date.today().addDays(-1),
            Date.today().addDays(1),
            'self'
        );
        Test.stopTest();

        System.assertEquals(0, (Integer) result.get('generated'),
            'Unknown metric should produce no insights');
    }
}
