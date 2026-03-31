// Script 12: Sales Targets with Target Lines
// Run: sf apex run -f scripts/12_targets.apex
// Prerequisite: 02_territory_master.apex, 03_product_category.apex

// Clean up (MasterDetail child first, then targets)
delete [SELECT Id FROM Target_Line__c];
delete [SELECT Id FROM Target__c];
System.debug('Cleaned up Target__c and Target_Line__c');

// Fetch territories
Map<String, Id> terMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c, Name FROM Territory_Master__c WHERE Is_Active__c = true]) {
    terMap.put(t.Territory_Code__c, t.Id);
}

// Fetch L1 categories for target lines
Map<String, Id> catMap = new Map<String, Id>();
for (Product_Category__c pc : [SELECT Id, Category_Code__c FROM Product_Category__c WHERE Level__c = 'Category']) {
    catMap.put(pc.Category_Code__c, pc.Id);
}

Integer currentMonth = Date.today().month();
Integer currentYear = Date.today().year();

// Month name lookup
Map<Integer, String> monthNames = new Map<Integer, String>{
    1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April',
    5 => 'May', 6 => 'June', 7 => 'July', 8 => 'August',
    9 => 'September', 10 => 'October', 11 => 'November', 12 => 'December'
};
String currentMonthName = monthNames.get(currentMonth);
String currentYearStr = String.valueOf(currentYear);

// Period dates: full year and current month
Date yearStart = Date.newInstance(currentYear, 1, 1);
Date yearEnd = Date.newInstance(currentYear, 12, 31);
Date monthStart = Date.newInstance(currentYear, currentMonth, 1);
// Last day of current month
Date monthEnd = Date.newInstance(currentYear, currentMonth, 1).addMonths(1).addDays(-1);

Id runningUserId = UserInfo.getUserId();

// Create revenue and volume targets for each territory
List<Target__c> targets = new List<Target__c>();
Map<String, Decimal> territoryRevTargets = new Map<String, Decimal>{
    'TER-DEL-001' => 500000, 'TER-MUM-001' => 750000,
    'TER-BLR-001' => 400000, 'TER-CHN-001' => 350000,
    'TER-KOL-001' => 300000, 'TER-HYD-001' => 350000,
    'TER-PUN-001' => 250000, 'TER-AHM-001' => 280000
};

for (String terCode : territoryRevTargets.keySet()) {
    if (!terMap.containsKey(terCode)) continue;
    Decimal revTarget = territoryRevTargets.get(terCode);

    // Revenue target
    targets.add(new Target__c(
        Territory__c = terMap.get(terCode),
        Period_Month__c = currentMonthName,
        Period_Year__c = currentYearStr,
        Period_Start__c = monthStart,
        Period_End__c = monthEnd,
        Month__c = currentMonthName,
        Year__c = currentYearStr,
        Target_Type__c = 'Revenue',
        Target_Value__c = revTarget,
        Achievement_Value__c = revTarget * 0.35,
        Status__c = 'Active',
        KPI_Weight__c = 40,
        Set_By__c = runningUserId,
        Notes__c = 'Monthly revenue target for ' + terCode + ' - ' + currentMonthName + ' ' + currentYear
    ));

    // Collection target
    targets.add(new Target__c(
        Territory__c = terMap.get(terCode),
        Period_Month__c = currentMonthName,
        Period_Year__c = currentYearStr,
        Period_Start__c = monthStart,
        Period_End__c = monthEnd,
        Month__c = currentMonthName,
        Year__c = currentYearStr,
        Target_Type__c = 'Collection',
        Target_Value__c = revTarget * 0.9,
        Achievement_Value__c = revTarget * 0.28,
        Status__c = 'Active',
        KPI_Weight__c = 30,
        Set_By__c = runningUserId,
        Notes__c = 'Monthly collection target (90% of revenue) for ' + terCode + ' - ' + currentMonthName + ' ' + currentYear
    ));

    // Volume target (cases/units sold)
    targets.add(new Target__c(
        Territory__c = terMap.get(terCode),
        Period_Month__c = currentMonthName,
        Period_Year__c = currentYearStr,
        Period_Start__c = monthStart,
        Period_End__c = monthEnd,
        Month__c = currentMonthName,
        Year__c = currentYearStr,
        Target_Type__c = 'Volume',
        Target_Value__c = (revTarget / 250).setScale(0),
        Achievement_Value__c = ((revTarget / 250) * 0.35).setScale(0),
        Status__c = 'Active',
        KPI_Weight__c = 20,
        Set_By__c = runningUserId,
        Notes__c = 'Monthly volume target (cases) for ' + terCode + ' - ' + currentMonthName + ' ' + currentYear
    ));

    // Focus Brand target (annual)
    targets.add(new Target__c(
        Territory__c = terMap.get(terCode),
        Period_Month__c = null,
        Period_Year__c = currentYearStr,
        Period_Start__c = yearStart,
        Period_End__c = yearEnd,
        Month__c = null,
        Year__c = currentYearStr,
        Target_Type__c = 'Focus Brand',
        Target_Value__c = revTarget * 12 * 0.15,
        Achievement_Value__c = revTarget * 12 * 0.15 * 0.30,
        Status__c = 'Active',
        KPI_Weight__c = 15,
        Set_By__c = runningUserId,
        Notes__c = 'Annual focus brand push target for ' + terCode + ' - FY ' + currentYear
    ));

    // New Outlet Activation target (monthly)
    targets.add(new Target__c(
        Territory__c = terMap.get(terCode),
        Period_Month__c = currentMonthName,
        Period_Year__c = currentYearStr,
        Period_Start__c = monthStart,
        Period_End__c = monthEnd,
        Month__c = currentMonthName,
        Year__c = currentYearStr,
        Target_Type__c = 'New Outlet Activation',
        Target_Value__c = 10,
        Achievement_Value__c = 3,
        Status__c = 'Active',
        KPI_Weight__c = 10,
        Set_By__c = runningUserId,
        Notes__c = 'New outlet activation count target for ' + terCode + ' - ' + currentMonthName + ' ' + currentYear
    ));
}

insert targets;
System.debug('Inserted targets: ' + targets.size());

// Create target lines for revenue targets only (broken by L1 category)
List<Target__c> revenueTargets = [
    SELECT Id, Target_Value__c, Territory__c
    FROM Target__c
    WHERE Target_Type__c = 'Revenue' AND Period_Month__c = :currentMonth AND Period_Year__c = :currentYear
];

List<Target_Line__c> targetLines = new List<Target_Line__c>();

// Category split: Foods 40%, Beverages 20%, Personal Care 25%, Home Care 15%
// Approximate avg unit price per category to derive quantity targets
Map<String, Decimal> catSplit = new Map<String, Decimal>{
    'CAT-FOOD' => 0.40, 'CAT-BEV' => 0.20, 'CAT-PC' => 0.25, 'CAT-HC' => 0.15
};
// Avg selling price per case per category (INR)
Map<String, Decimal> catAvgPrice = new Map<String, Decimal>{
    'CAT-FOOD' => 320, 'CAT-BEV' => 180, 'CAT-PC' => 450, 'CAT-HC' => 280
};

for (Target__c t : revenueTargets) {
    for (String catCode : catSplit.keySet()) {
        if (!catMap.containsKey(catCode)) continue;
        Decimal splitValue = t.Target_Value__c * catSplit.get(catCode);
        Decimal avgPrice = catAvgPrice.get(catCode);
        Decimal targetQty = (splitValue / avgPrice).setScale(0);

        targetLines.add(new Target_Line__c(
            Target__c = t.Id,
            Product_Category__c = catMap.get(catCode),
            Target_Value__c = splitValue,
            Target_Qty__c = targetQty,
            Achievement_Value__c = splitValue * 0.35,
            Achievement_Qty__c = (targetQty * 0.35).setScale(0)
        ));
    }
}

insert targetLines;
System.debug('Targets setup complete. Targets: ' + targets.size() + ', Lines: ' + targetLines.size());
