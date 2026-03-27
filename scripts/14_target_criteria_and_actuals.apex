// ============================================================
// Seed Script: Target Criteria + Sample Target Actuals
// Prerequisites: Run 13_target_periods.apex first
// Run via: Execute Anonymous in Developer Console
// ============================================================

// ── 1. Create Target Criteria ──────────────────────────────────

List<Target_Criteria__c> criterias = new List<Target_Criteria__c>();

// Revenue criteria — SUM of Total_Net_Amount__c on Sales_Order__c
criterias.add(new Target_Criteria__c(
    Name = 'Revenue',
    Object__c = 'Sales_Order__c',
    Operator__c = 'SUM',
    Field__c = 'Total_Net_Amount__c',
    Date_Field__c = 'Order_Date__c',
    User_Field__c = 'Salesperson__c',
    Active__c = true
));

// Volume criteria — COUNT of Orders
criterias.add(new Target_Criteria__c(
    Name = 'Volume',
    Object__c = 'Sales_Order__c',
    Operator__c = 'COUNT',
    Field__c = 'Id',
    Date_Field__c = 'Order_Date__c',
    User_Field__c = 'Salesperson__c',
    Active__c = true
));

// Collection criteria — SUM of Amount on Collection__c
criterias.add(new Target_Criteria__c(
    Name = 'Collection',
    Object__c = 'Collection__c',
    Operator__c = 'SUM',
    Field__c = 'Amount__c',
    Date_Field__c = 'Collection_Date__c',
    User_Field__c = 'Salesperson__c',
    Active__c = true,
    Filters__c = '{"filters":[{"id":1,"field":"Status__c","operator":"=","value":"Confirmed","type":"String"}]}',
    Filter_Logic__c = '1'
));

// Coverage criteria — COUNT of Visits
criterias.add(new Target_Criteria__c(
    Name = 'Coverage',
    Object__c = 'Visit__c',
    Operator__c = 'COUNT',
    Field__c = 'Id',
    Date_Field__c = 'Visit_Date__c',
    User_Field__c = 'Salesperson__c',
    Active__c = true,
    Filters__c = '{"filters":[{"id":1,"field":"Visit_Status__c","operator":"=","value":"Completed","type":"String"},{"id":2,"field":"Is_Productive__c","operator":"=","value":true,"type":"Boolean"}]}',
    Filter_Logic__c = '1 AND 2'
));

// New Outlets criteria — COUNT of new Accounts
criterias.add(new Target_Criteria__c(
    Name = 'New Outlets',
    Object__c = 'Account',
    Operator__c = 'COUNT',
    Field__c = 'Id',
    Date_Field__c = 'CreatedDate',
    User_Field__c = 'OwnerId',
    Active__c = true
));

insert criterias;
System.debug('Created ' + criterias.size() + ' Target Criteria records');

// ── 2. Create Sample Target Actuals ─────────────────────────────

// Get current period
Target_Period__c currentPeriod = [
    SELECT Id FROM Target_Period__c
    WHERE Start_Date__c <= TODAY AND End_Date__c >= TODAY
    AND Type__c = 'Monthly'
    LIMIT 1
];

// Get running user
Id currentUserId = UserInfo.getUserId();

// Target values by criteria
Map<String, Decimal> targetValues = new Map<String, Decimal>{
    'Revenue' => 500000,
    'Volume' => 200,
    'Collection' => 400000,
    'Coverage' => 150,
    'New Outlets' => 20
};

List<Target_Actual__c> actuals = new List<Target_Actual__c>();

for (Target_Criteria__c tc : criterias) {
    Decimal targetValue = targetValues.get(tc.Name);
    if (targetValue == null) targetValue = 100;

    actuals.add(new Target_Actual__c(
        Target_Criteria__c = tc.Id,
        Target_Period__c = currentPeriod.Id,
        User__c = currentUserId,
        Target_Value__c = targetValue,
        Achievement_Value__c = targetValue * 0.35  // 35% initial achievement
    ));
}

insert actuals;
System.debug('Created ' + actuals.size() + ' Target Actual records for user ' + UserInfo.getName());

// ── 3. Verify ───────────────────────────────────────────────────

System.debug('=== Summary ===');
System.debug('Target Criteria: ' + [SELECT COUNT() FROM Target_Criteria__c WHERE Active__c = true]);
System.debug('Target Periods: ' + [SELECT COUNT() FROM Target_Period__c WHERE Is_Active__c = true]);
System.debug('Target Actuals: ' + [SELECT COUNT() FROM Target_Actual__c]);
