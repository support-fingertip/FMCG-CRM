// ============================================================
// Seed Script: KPI Metrics (Dynamic KPI Dashboard - Sprint 1)
// Creates 15 reusable KPI metric definitions for the Dynamic
// KPI Dashboard. Admins can add more from the KPI Metrics tab.
// Run via: sf apex run -f scripts/18_kpi_metrics.apex
// ============================================================

delete [SELECT Id FROM KPI_Metric__c];
System.debug('Cleaned up existing KPI Metrics');

List<KPI_Metric__c> metrics = new List<KPI_Metric__c>();

// ── SALES CATEGORY (5 metrics) ───────────────────────────────
metrics.add(new KPI_Metric__c(
    Name = 'Total Revenue',
    Metric_Key__c = 'revenue_total',
    Label__c = 'Total Revenue',
    Description__c = 'Sum of Total Net Amount across approved/delivered sales orders.',
    Source_Object__c = 'Sales_Order__c',
    Aggregation__c = 'SUM',
    Aggregate_Field__c = 'Total_Net_Amount__c',
    Date_Field__c = 'Order_Date__c',
    User_Field__c = 'Salesperson__c',
    Default_Filter__c = 'Status__c IN (\'Approved\',\'Delivered\')',
    Format__c = 'Currency',
    Icon__c = 'utility:money',
    Color__c = '#0176d3',
    Category__c = 'Sales',
    Allow_Forecast__c = true,
    Is_Active__c = true,
    Sort_Order__c = 1
));
metrics.add(new KPI_Metric__c(
    Name = 'Order Count',
    Metric_Key__c = 'order_count',
    Label__c = 'Order Count',
    Description__c = 'Total number of approved/delivered orders.',
    Source_Object__c = 'Sales_Order__c',
    Aggregation__c = 'COUNT',
    Date_Field__c = 'Order_Date__c',
    User_Field__c = 'Salesperson__c',
    Default_Filter__c = 'Status__c IN (\'Approved\',\'Delivered\')',
    Format__c = 'Number',
    Icon__c = 'standard:orders',
    Color__c = '#2e844a',
    Category__c = 'Sales',
    Allow_Forecast__c = true,
    Is_Active__c = true,
    Sort_Order__c = 2
));
metrics.add(new KPI_Metric__c(
    Name = 'Average Order Value',
    Metric_Key__c = 'avg_order_value',
    Label__c = 'Average Order Value',
    Description__c = 'Average total net amount per order (AOV).',
    Source_Object__c = 'Sales_Order__c',
    Aggregation__c = 'AVG',
    Aggregate_Field__c = 'Total_Net_Amount__c',
    Date_Field__c = 'Order_Date__c',
    User_Field__c = 'Salesperson__c',
    Default_Filter__c = 'Status__c IN (\'Approved\',\'Delivered\')',
    Format__c = 'Currency',
    Icon__c = 'utility:trending',
    Color__c = '#7b61ff',
    Category__c = 'Sales',
    Allow_Forecast__c = false,
    Is_Active__c = true,
    Sort_Order__c = 3
));
metrics.add(new KPI_Metric__c(
    Name = 'Discount Given',
    Metric_Key__c = 'discount_given',
    Label__c = 'Total Discount Given',
    Description__c = 'Sum of all discounts applied across orders (line + scheme).',
    Source_Object__c = 'Sales_Order__c',
    Aggregation__c = 'SUM',
    Aggregate_Field__c = 'Total_Discount__c',
    Date_Field__c = 'Order_Date__c',
    User_Field__c = 'Salesperson__c',
    Default_Filter__c = 'Status__c IN (\'Approved\',\'Delivered\')',
    Format__c = 'Currency',
    Icon__c = 'utility:discounts',
    Color__c = '#dd7a01',
    Category__c = 'Sales',
    Is_Active__c = true,
    Sort_Order__c = 4
));
metrics.add(new KPI_Metric__c(
    Name = 'Largest Order',
    Metric_Key__c = 'max_order_value',
    Label__c = 'Largest Single Order',
    Description__c = 'Highest single-order net amount in the period.',
    Source_Object__c = 'Sales_Order__c',
    Aggregation__c = 'MAX',
    Aggregate_Field__c = 'Total_Net_Amount__c',
    Date_Field__c = 'Order_Date__c',
    User_Field__c = 'Salesperson__c',
    Default_Filter__c = 'Status__c IN (\'Approved\',\'Delivered\')',
    Format__c = 'Currency',
    Icon__c = 'utility:trophy',
    Color__c = '#ffa41c',
    Category__c = 'Sales',
    Is_Active__c = true,
    Sort_Order__c = 5
));

// ── VISITS CATEGORY (4 metrics) ──────────────────────────────
metrics.add(new KPI_Metric__c(
    Name = 'Total Visits',
    Metric_Key__c = 'visit_count',
    Label__c = 'Total Visits',
    Description__c = 'Total number of completed visits.',
    Source_Object__c = 'Visit__c',
    Aggregation__c = 'COUNT',
    Date_Field__c = 'Visit_Date__c',
    User_Field__c = 'Salesperson__c',
    Default_Filter__c = 'Visit_Status__c = \'Completed\'',
    Format__c = 'Number',
    Icon__c = 'standard:visit',
    Color__c = '#0176d3',
    Category__c = 'Visits',
    Allow_Forecast__c = true,
    Is_Active__c = true,
    Sort_Order__c = 1
));
metrics.add(new KPI_Metric__c(
    Name = 'Productive Visits',
    Metric_Key__c = 'productive_visit_count',
    Label__c = 'Productive Visits',
    Description__c = 'Completed visits that resulted in an order or meaningful outcome.',
    Source_Object__c = 'Visit__c',
    Aggregation__c = 'COUNT',
    Date_Field__c = 'Visit_Date__c',
    User_Field__c = 'Salesperson__c',
    Default_Filter__c = 'Visit_Status__c = \'Completed\' AND Is_Productive__c = true',
    Format__c = 'Number',
    Icon__c = 'utility:success',
    Color__c = '#2e844a',
    Category__c = 'Visits',
    Allow_Forecast__c = true,
    Is_Active__c = true,
    Sort_Order__c = 2
));
metrics.add(new KPI_Metric__c(
    Name = 'Average Visit Duration',
    Metric_Key__c = 'avg_visit_duration',
    Label__c = 'Avg Visit Duration',
    Description__c = 'Average time spent per visit in minutes.',
    Source_Object__c = 'Visit__c',
    Aggregation__c = 'AVG',
    Aggregate_Field__c = 'Duration_Minutes__c',
    Date_Field__c = 'Visit_Date__c',
    User_Field__c = 'Salesperson__c',
    Default_Filter__c = 'Visit_Status__c = \'Completed\'',
    Format__c = 'Duration',
    Icon__c = 'utility:clock',
    Color__c = '#7b61ff',
    Category__c = 'Visits',
    Is_Active__c = true,
    Sort_Order__c = 3
));
metrics.add(new KPI_Metric__c(
    Name = 'Skipped Visits',
    Metric_Key__c = 'skipped_visit_count',
    Label__c = 'Skipped Visits',
    Description__c = 'Planned visits that were skipped (not completed).',
    Source_Object__c = 'Visit__c',
    Aggregation__c = 'COUNT',
    Date_Field__c = 'Visit_Date__c',
    User_Field__c = 'Salesperson__c',
    Default_Filter__c = 'Visit_Status__c = \'Skipped\'',
    Format__c = 'Number',
    Icon__c = 'utility:warning',
    Color__c = '#c23934',
    Category__c = 'Visits',
    Is_Active__c = true,
    Sort_Order__c = 4
));

// ── COLLECTIONS CATEGORY (3 metrics) ─────────────────────────
metrics.add(new KPI_Metric__c(
    Name = 'Total Collections',
    Metric_Key__c = 'collection_total',
    Label__c = 'Total Collections',
    Description__c = 'Sum of all collected payments in the period.',
    Source_Object__c = 'Collection__c',
    Aggregation__c = 'SUM',
    Aggregate_Field__c = 'Amount__c',
    Date_Field__c = 'Collection_Date__c',
    User_Field__c = 'Salesperson__c',
    Default_Filter__c = 'Status__c = \'Collected\'',
    Format__c = 'Currency',
    Icon__c = 'utility:moneybag',
    Color__c = '#2e844a',
    Category__c = 'Collections',
    Allow_Forecast__c = true,
    Is_Active__c = true,
    Sort_Order__c = 1
));
metrics.add(new KPI_Metric__c(
    Name = 'Collection Count',
    Metric_Key__c = 'collection_count',
    Label__c = 'Collection Transactions',
    Description__c = 'Number of individual collection records in the period.',
    Source_Object__c = 'Collection__c',
    Aggregation__c = 'COUNT',
    Date_Field__c = 'Collection_Date__c',
    User_Field__c = 'Salesperson__c',
    Default_Filter__c = 'Status__c = \'Collected\'',
    Format__c = 'Number',
    Icon__c = 'standard:task',
    Color__c = '#0176d3',
    Category__c = 'Collections',
    Is_Active__c = true,
    Sort_Order__c = 2
));
metrics.add(new KPI_Metric__c(
    Name = 'Average Collection',
    Metric_Key__c = 'avg_collection',
    Label__c = 'Avg Collection Amount',
    Description__c = 'Average value per collection transaction.',
    Source_Object__c = 'Collection__c',
    Aggregation__c = 'AVG',
    Aggregate_Field__c = 'Amount__c',
    Date_Field__c = 'Collection_Date__c',
    User_Field__c = 'Salesperson__c',
    Default_Filter__c = 'Status__c = \'Collected\'',
    Format__c = 'Currency',
    Icon__c = 'utility:currency',
    Color__c = '#7b61ff',
    Category__c = 'Collections',
    Is_Active__c = true,
    Sort_Order__c = 3
));

// ── OUTLETS CATEGORY (2 metrics) ─────────────────────────────
metrics.add(new KPI_Metric__c(
    Name = 'New Outlets',
    Metric_Key__c = 'new_outlets',
    Label__c = 'New Outlets Added',
    Description__c = 'Number of new accounts created in the period.',
    Source_Object__c = 'Account',
    Aggregation__c = 'COUNT',
    Date_Field__c = 'CreatedDate',
    User_Field__c = 'OwnerId',
    Default_Filter__c = 'Type IN (\'Retailer\',\'Distributor\',\'Super Stockist\',\'Modern Trade\')',
    Format__c = 'Number',
    Icon__c = 'utility:add',
    Color__c = '#2e844a',
    Category__c = 'Outlets',
    Allow_Forecast__c = true,
    Is_Active__c = true,
    Sort_Order__c = 1
));
metrics.add(new KPI_Metric__c(
    Name = 'Active Outlets',
    Metric_Key__c = 'active_outlets',
    Label__c = 'Active Outlets',
    Description__c = 'Count of active accounts in the CRM.',
    Source_Object__c = 'Account',
    Aggregation__c = 'COUNT',
    Date_Field__c = 'CreatedDate',
    User_Field__c = 'OwnerId',
    Default_Filter__c = 'Is_Active__c = true',
    Format__c = 'Number',
    Icon__c = 'standard:account',
    Color__c = '#0176d3',
    Category__c = 'Outlets',
    Is_Active__c = true,
    Sort_Order__c = 2
));

// ── SCHEMES CATEGORY (1 metric) ──────────────────────────────
metrics.add(new KPI_Metric__c(
    Name = 'Scheme Discount Given',
    Metric_Key__c = 'scheme_discount',
    Label__c = 'Scheme Discount Given',
    Description__c = 'Total scheme-based discount across orders.',
    Source_Object__c = 'Sales_Order__c',
    Aggregation__c = 'SUM',
    Aggregate_Field__c = 'Scheme_Discount__c',
    Date_Field__c = 'Order_Date__c',
    User_Field__c = 'Salesperson__c',
    Default_Filter__c = 'Status__c IN (\'Approved\',\'Delivered\') AND Scheme_Discount__c > 0',
    Format__c = 'Currency',
    Icon__c = 'utility:percent',
    Color__c = '#dd7a01',
    Category__c = 'Schemes',
    Is_Active__c = true,
    Sort_Order__c = 1
));

insert metrics;

// ── Summary ──────────────────────────────────────────────────
Map<String, Integer> catCount = new Map<String, Integer>();
for (KPI_Metric__c m : metrics) {
    Integer c = catCount.containsKey(m.Category__c) ? catCount.get(m.Category__c) : 0;
    catCount.put(m.Category__c, c + 1);
}

System.debug('');
System.debug('═══════════════════════════════════════════');
System.debug('KPI Metric Seed Complete: ' + metrics.size() + ' metrics');
for (String cat : catCount.keySet()) {
    System.debug('  ' + cat + ': ' + catCount.get(cat));
}
System.debug('═══════════════════════════════════════════');
System.debug('Manage metrics from the KPI Metrics tab.');
