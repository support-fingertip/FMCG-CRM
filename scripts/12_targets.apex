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
        Name = 'Revenue Target - ' + terCode + ' - ' + currentMonth + '/' + currentYear,
        Territory__c = terMap.get(terCode),
        Period_Month__c = currentMonth,
        Period_Year__c = currentYear,
        Target_Type__c = 'Revenue',
        Target_Value__c = revTarget,
        Achievement_Value__c = revTarget * 0.35,
        Achievement_Percent__c = 35.0,
        Status__c = 'Active',
        KPI_Weight__c = 40
    ));

    // Collection target
    targets.add(new Target__c(
        Name = 'Collection Target - ' + terCode + ' - ' + currentMonth + '/' + currentYear,
        Territory__c = terMap.get(terCode),
        Period_Month__c = currentMonth,
        Period_Year__c = currentYear,
        Target_Type__c = 'Collection',
        Target_Value__c = revTarget * 0.9,
        Achievement_Value__c = revTarget * 0.28,
        Achievement_Percent__c = 31.1,
        Status__c = 'Active',
        KPI_Weight__c = 30
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
Map<String, Decimal> catSplit = new Map<String, Decimal>{
    'CAT-FOOD' => 0.40, 'CAT-BEV' => 0.20, 'CAT-PC' => 0.25, 'CAT-HC' => 0.15
};

for (Target__c t : revenueTargets) {
    for (String catCode : catSplit.keySet()) {
        if (!catMap.containsKey(catCode)) continue;
        Decimal splitValue = t.Target_Value__c * catSplit.get(catCode);

        targetLines.add(new Target_Line__c(
            Target__c = t.Id,
            Product_Category__c = catMap.get(catCode),
            Target_Value__c = splitValue,
            Achievement_Value__c = splitValue * 0.35,
            Achievement_Percent__c = 35.0
        ));
    }
}

insert targetLines;
System.debug('Targets setup complete. Targets: ' + targets.size() + ', Lines: ' + targetLines.size());
