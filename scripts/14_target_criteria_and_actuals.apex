// ============================================================
// Seed Script: Target Criteria + Sample Target Actuals
// Includes: Category__c, Incentive_Weight__c, Prerequisite fields
// Prerequisites: Run 13_target_periods.apex first
// Run via: Execute Anonymous in Developer Console
// ============================================================

delete [SELECT Id FROM Target_Actual__c];
delete [SELECT Id FROM Target_Criteria__c];

// ═══════════════════════════════════════════════════════════════
// 1. CREATE TARGET CRITERIA (with PBIS fields)
// ═══════════════════════════════════════════════════════════════

List<Target_Criteria__c> criterias = new List<Target_Criteria__c>();

// Revenue — Primary KPI (60% weight)
criterias.add(new Target_Criteria__c(
    Name = 'Revenue',
    Object__c = 'Sales_Order__c',
    Operator__c = 'SUM',
    Field__c = 'Total_Net_Amount__c',
    Date_Field__c = 'Order_Date__c',
    User_Field__c = 'Salesperson__c',
    Active__c = true,
    Category__c = 'Revenue',
    Incentive_Weight__c = 60,
    Filters__c = '{"filters":[{"id":1,"field":"Status__c","operator":"IN","value":["Approved","Delivered"],"type":"Picklist"}]}',
    Filter_Logic__c = '1'
));

// Collection — Secondary KPI (10% weight)
criterias.add(new Target_Criteria__c(
    Name = 'Collection',
    Object__c = 'Collection__c',
    Operator__c = 'SUM',
    Field__c = 'Amount__c',
    Date_Field__c = 'Collection_Date__c',
    User_Field__c = 'Salesperson__c',
    Active__c = true,
    Category__c = 'Collection',
    Incentive_Weight__c = 10,
    Filters__c = '{"filters":[{"id":1,"field":"Status__c","operator":"=","value":"Confirmed","type":"String"}]}',
    Filter_Logic__c = '1'
));

// Volume — Order count (no weight — independent)
criterias.add(new Target_Criteria__c(
    Name = 'Volume',
    Object__c = 'Sales_Order__c',
    Operator__c = 'COUNT',
    Field__c = 'Id',
    Date_Field__c = 'Order_Date__c',
    User_Field__c = 'Salesperson__c',
    Active__c = true,
    Category__c = 'Activity'
));

// Coverage — Productive visits
criterias.add(new Target_Criteria__c(
    Name = 'Coverage',
    Object__c = 'Visit__c',
    Operator__c = 'COUNT',
    Field__c = 'Id',
    Date_Field__c = 'Visit_Date__c',
    User_Field__c = 'Salesperson__c',
    Active__c = true,
    Category__c = 'Coverage',
    Filters__c = '{"filters":[{"id":1,"field":"Visit_Status__c","operator":"=","value":"Completed","type":"String"},{"id":2,"field":"Is_Productive__c","operator":"=","value":"true","type":"Boolean"}]}',
    Filter_Logic__c = '1 AND 2'
));

// Focus Brand — S&D Parameter (15% weight, requires Revenue ≥ 90%)
criterias.add(new Target_Criteria__c(
    Name = 'Focus Brand',
    Object__c = 'Sales_Order__c',
    Operator__c = 'SUM',
    Field__c = 'Total_Net_Amount__c',
    Date_Field__c = 'Order_Date__c',
    User_Field__c = 'Salesperson__c',
    Active__c = true,
    Category__c = 'Revenue',
    Incentive_Weight__c = 15
    // Prerequisite will be set after insert (needs Revenue Id)
));

// Outlet Expansion — S&D Parameter (15% weight, requires Revenue ≥ 90%)
criterias.add(new Target_Criteria__c(
    Name = 'Outlet Expansion',
    Object__c = 'Account',
    Operator__c = 'COUNT',
    Field__c = 'Id',
    Date_Field__c = 'CreatedDate',
    User_Field__c = 'OwnerId',
    Active__c = true,
    Category__c = 'Coverage',
    Incentive_Weight__c = 15
    // Prerequisite will be set after insert
));

insert criterias;

// ── Set prerequisites (Focus Brand & Outlet Expansion require Revenue ≥ 90%) ──
Map<String, Id> criteriaMap = new Map<String, Id>();
for (Target_Criteria__c tc : criterias) {
    criteriaMap.put(tc.Name, tc.Id);
}

List<Target_Criteria__c> toUpdate = new List<Target_Criteria__c>();

Target_Criteria__c focusBrand = new Target_Criteria__c(
    Id = criteriaMap.get('Focus Brand'),
    Prerequisite_Criteria__c = criteriaMap.get('Revenue'),
    Prerequisite_Min_Percent__c = 90
);
toUpdate.add(focusBrand);

Target_Criteria__c outletExpansion = new Target_Criteria__c(
    Id = criteriaMap.get('Outlet Expansion'),
    Prerequisite_Criteria__c = criteriaMap.get('Revenue'),
    Prerequisite_Min_Percent__c = 90
);
toUpdate.add(outletExpansion);

update toUpdate;

System.debug('Created ' + criterias.size() + ' Target Criteria:');
for (Target_Criteria__c tc : criterias) {
    System.debug('  ' + tc.Name + ' | Category: ' + tc.Category__c + ' | Weight: ' + tc.Incentive_Weight__c + '%');
}

// ═══════════════════════════════════════════════════════════════
// 2. CREATE TARGET ACTUALS FOR CURRENT PERIOD
// ═══════════════════════════════════════════════════════════════

Target_Period__c currentPeriod;
try {
    currentPeriod = [
        SELECT Id, Name FROM Target_Period__c
        WHERE Start_Date__c <= TODAY AND End_Date__c >= TODAY
        AND Type__c = 'Monthly' LIMIT 1
    ];
} catch (Exception e) {
    System.debug('ERROR: No current monthly period found. Run 13_target_periods.apex first.');
    return;
}

Id currentUserId = UserInfo.getUserId();

Map<String, Decimal> targetValues = new Map<String, Decimal>{
    'Revenue' => 500000,
    'Collection' => 300000,
    'Volume' => 200,
    'Coverage' => 150,
    'Focus Brand' => 100000,
    'Outlet Expansion' => 20
};

// Simulate varying achievement percentages
Map<String, Decimal> achievementPercents = new Map<String, Decimal>{
    'Revenue' => 0.92,        // 92% — above prerequisite threshold
    'Collection' => 0.88,     // 88%
    'Volume' => 1.05,         // 105%
    'Coverage' => 0.75,       // 75%
    'Focus Brand' => 0.95,    // 95% — will qualify since Revenue > 90%
    'Outlet Expansion' => 1.10 // 110% — will qualify since Revenue > 90%
};

List<Target_Actual__c> actuals = new List<Target_Actual__c>();

for (Target_Criteria__c tc : criterias) {
    Decimal targetValue = targetValues.get(tc.Name);
    Decimal achPct = achievementPercents.get(tc.Name);
    if (targetValue == null) targetValue = 100;
    if (achPct == null) achPct = 0.5;

    actuals.add(new Target_Actual__c(
        Target_Criteria__c = tc.Id,
        Target_Period__c = currentPeriod.Id,
        User__c = currentUserId,
        Target_Value__c = targetValue,
        Achievement_Value__c = (targetValue * achPct).setScale(0, RoundingMode.HALF_UP)
    ));
}

insert actuals;

System.debug('');
System.debug('════════════════════════════════════════════');
System.debug('Created ' + actuals.size() + ' Target Actuals for ' + UserInfo.getName());
System.debug('Period: ' + currentPeriod.Name);
System.debug('');
for (Integer i = 0; i < criterias.size(); i++) {
    Target_Criteria__c tc = criterias[i];
    Target_Actual__c ta = actuals[i];
    Decimal pct = ta.Target_Value__c > 0 ? (ta.Achievement_Value__c / ta.Target_Value__c * 100) : 0;
    System.debug('  ' + tc.Name.rightPad(20) +
        'Target: ' + String.valueOf(ta.Target_Value__c).leftPad(10) +
        '  Actual: ' + String.valueOf(ta.Achievement_Value__c).leftPad(10) +
        '  (' + pct.setScale(1, RoundingMode.HALF_UP) + '%)');
}
System.debug('════════════════════════════════════════════');
