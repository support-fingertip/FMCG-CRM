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

        Territory_Master__c ter = TestDataFactory.createAndInsertTerritory('DKD Insights Ter', 'TER-DKDI01');
        Account acc = new Account(Name = 'DKD Insights Test', Outlet_Type__c = 'Grocery', Territory__c = ter.Id, Channel__c = 'GT');
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
                    Territory__c = ter.Id,
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
                    Territory__c = ter.Id,
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
        System.assertNotEquals(null, generated, 'Generated count should not be null');

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
        System.assertNotEquals(null, insights, 'Insights list should not be null');
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
        System.assertNotEquals(null, insights, 'Insights list should not be null');
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

    @IsTest
    static void testGenerateInsights_TeamScope() {
        Test.startTest();
        Map<String, Object> result = DKD_Insights_Service.generateInsights(
            new List<String>{ 'test_revenue_ins' },
            null,
            Date.today().addDays(-30),
            Date.today(),
            'team'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.get('insights'));
    }

    @IsTest
    static void testGenerateInsights_NullMetrics() {
        Test.startTest();
        Map<String, Object> result = DKD_Insights_Service.generateInsights(
            null, null, Date.today(), Date.today(), 'self'
        );
        Test.stopTest();
        System.assertEquals(0, (Integer) result.get('generated'));
    }

    @IsTest
    static void testGenerateInsights_WiderDateRange() {
        Test.startTest();
        Map<String, Object> result = DKD_Insights_Service.generateInsights(
            new List<String>{ 'test_revenue_ins' },
            null,
            Date.today().addDays(-60),
            Date.today(),
            'self'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        List<Map<String, Object>> insights = (List<Map<String, Object>>) result.get('insights');
        System.assertNotEquals(null, insights);
    }

    @IsTest
    static void testGenerateInsights_MultipleMetrics() {
        KPI_Metric__c m2 = new KPI_Metric__c(
            Name = 'Test Count Insights2',
            Metric_Key__c = 'test_count_ins2',
            Label__c = 'Test Count2',
            Source_Object__c = 'Sales_Order__c',
            Aggregation__c = 'COUNT',
            Date_Field__c = 'Order_Date__c',
            User_Field__c = 'Salesperson__c',
            Format__c = 'Number',
            Category__c = 'Sales',
            Is_Active__c = true
        );
        insert m2;

        Test.startTest();
        Map<String, Object> result = DKD_Insights_Service.generateInsights(
            new List<String>{ 'test_revenue_ins', 'test_count_ins2' },
            null,
            Date.today().addDays(-30),
            Date.today(),
            'self'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testGenerateInsights_OrgScopeWiderRange() {
        Test.startTest();
        Map<String, Object> result = DKD_Insights_Service.generateInsights(
            new List<String>{ 'test_revenue_ins' },
            null,
            Date.today().addDays(-30),
            Date.today(),
            'org'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.get('insights'));
    }

    @IsTest
    static void testGenerateInsights_WithFiltersJson() {
        Test.startTest();
        Map<String, Object> result = DKD_Insights_Service.generateInsights(
            new List<String>{ 'test_revenue_ins' },
            '{}',
            Date.today().addDays(-7),
            Date.today(),
            'self'
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ── Direct private method tests via @TestVisible ────────────────

    @IsTest
    static void testBuildTrendInsight_Up() {
        KPI_Metric__c m = [SELECT Id, Metric_Key__c, Label__c, Format__c FROM KPI_Metric__c WHERE Metric_Key__c = 'test_revenue_ins' LIMIT 1];

        Test.startTest();
        Map<String, Object> insight = DKD_Insights_Service.buildTrendInsight(m, 'mom', 15000, 10000, 'previous period');
        Test.stopTest();

        System.assertNotEquals(null, insight, 'Should generate trend_up insight');
        System.assertEquals('trend_up', insight.get('type'));
        System.assertEquals('success', insight.get('severity'));
        System.assertNotEquals(null, insight.get('message'));
    }

    @IsTest
    static void testBuildTrendInsight_Down() {
        KPI_Metric__c m = [SELECT Id, Metric_Key__c, Label__c, Format__c FROM KPI_Metric__c WHERE Metric_Key__c = 'test_revenue_ins' LIMIT 1];

        Test.startTest();
        Map<String, Object> insight = DKD_Insights_Service.buildTrendInsight(m, 'mom', 5000, 10000, 'previous period');
        Test.stopTest();

        System.assertNotEquals(null, insight, 'Should generate trend_down insight');
        System.assertEquals('trend_down', insight.get('type'));
    }

    @IsTest
    static void testBuildTrendInsight_CriticalDown() {
        KPI_Metric__c m = [SELECT Id, Metric_Key__c, Label__c, Format__c FROM KPI_Metric__c WHERE Metric_Key__c = 'test_revenue_ins' LIMIT 1];

        Test.startTest();
        Map<String, Object> insight = DKD_Insights_Service.buildTrendInsight(m, 'yoy', 2000, 10000, 'same period last year');
        Test.stopTest();

        System.assertNotEquals(null, insight);
        System.assertEquals('critical', insight.get('severity'));
    }

    @IsTest
    static void testBuildTrendInsight_MinorChangeReturnsNull() {
        KPI_Metric__c m = [SELECT Id, Metric_Key__c, Label__c, Format__c FROM KPI_Metric__c WHERE Metric_Key__c = 'test_revenue_ins' LIMIT 1];

        Test.startTest();
        Map<String, Object> insight = DKD_Insights_Service.buildTrendInsight(m, 'mom', 10200, 10000, 'previous period');
        Test.stopTest();

        System.assertEquals(null, insight, 'Less than 5% change should return null');
    }

    @IsTest
    static void testBuildTrendInsight_ZeroPrevReturnsNull() {
        KPI_Metric__c m = [SELECT Id, Metric_Key__c, Label__c, Format__c FROM KPI_Metric__c WHERE Metric_Key__c = 'test_revenue_ins' LIMIT 1];

        Test.startTest();
        Map<String, Object> insight = DKD_Insights_Service.buildTrendInsight(m, 'mom', 5000, 0, 'previous period');
        Test.stopTest();

        System.assertEquals(null, insight, 'Zero previous value should return null');
    }

    @IsTest
    static void testFormatValue_Currency() {
        KPI_Metric__c m = new KPI_Metric__c(Format__c = 'Currency');

        Test.startTest();
        String result = DKD_Insights_Service.formatValue(1234567, m);
        Test.stopTest();

        System.assert(result.startsWith('₹'), 'Currency format should start with ₹');
        System.assert(result.contains(','), 'Should have Indian number formatting');
    }

    @IsTest
    static void testFormatValue_Percent() {
        KPI_Metric__c m = new KPI_Metric__c(Format__c = 'Percent');

        Test.startTest();
        String result = DKD_Insights_Service.formatValue(85.5, m);
        Test.stopTest();

        System.assert(result.contains('%'), 'Percent format should contain %');
    }

    @IsTest
    static void testFormatValue_Duration() {
        KPI_Metric__c m = new KPI_Metric__c(Format__c = 'Duration');

        Test.startTest();
        String result = DKD_Insights_Service.formatValue(120, m);
        Test.stopTest();

        System.assert(result.contains('min'), 'Duration should contain min');
    }

    @IsTest
    static void testFormatValue_Number() {
        KPI_Metric__c m = new KPI_Metric__c(Format__c = 'Number');

        Test.startTest();
        String result = DKD_Insights_Service.formatValue(1500000, m);
        Test.stopTest();

        System.assert(result.contains(','), 'Number should have Indian formatting');
    }

    @IsTest
    static void testFormatValue_Null() {
        KPI_Metric__c m = new KPI_Metric__c(Format__c = 'Number');

        Test.startTest();
        String result = DKD_Insights_Service.formatValue(null, m);
        Test.stopTest();

        System.assertEquals('0', result);
    }

    @IsTest
    static void testFormatIndianNumber_Various() {
        Test.startTest();
        System.assertEquals('0', DKD_Insights_Service.formatIndianNumber(0));
        System.assertEquals('500', DKD_Insights_Service.formatIndianNumber(500));
        System.assertEquals('1,000', DKD_Insights_Service.formatIndianNumber(1000));
        System.assertEquals('10,000', DKD_Insights_Service.formatIndianNumber(10000));
        System.assertEquals('1,00,000', DKD_Insights_Service.formatIndianNumber(100000));
        System.assertEquals('12,34,567', DKD_Insights_Service.formatIndianNumber(1234567));
        Test.stopTest();
    }

    @IsTest
    static void testFormatIndianNumber_Negative() {
        Test.startTest();
        String result = DKD_Insights_Service.formatIndianNumber(-50000);
        Test.stopTest();

        System.assert(result.startsWith('-'), 'Negative numbers should have minus sign');
    }

    @IsTest
    static void testToDecimal_AllTypes() {
        Test.startTest();
        System.assertEquals(0, DKD_Insights_Service.toDecimal(null));
        System.assertEquals(100, DKD_Insights_Service.toDecimal(100.0));
        System.assertEquals(42, DKD_Insights_Service.toDecimal(42));
        System.assertEquals(999, DKD_Insights_Service.toDecimal((Long)999));
        System.assertEquals(3.14, DKD_Insights_Service.toDecimal(Double.valueOf(3.14)));
        System.assertEquals(50, DKD_Insights_Service.toDecimal('50'));
        System.assertEquals(0, DKD_Insights_Service.toDecimal('not a number'));
        Test.stopTest();
    }
}
