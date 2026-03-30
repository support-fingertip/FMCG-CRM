// ============================================================
// Incentive Slab Seed Data — Comprehensive
// Run via: Execute Anonymous in Developer Console
//
// Creates:
//   1. Universal slabs (apply to ALL criteria)
//   2. Criteria-specific slabs (Revenue, Collection, Volume, etc.)
//
// Prerequisites: Target_Criteria__c records must exist first.
//   Run 12_targets.apex or create criteria via Criteria Builder.
// ============================================================

// Delete existing slabs
delete [SELECT Id FROM Incentive_Slab__c];

// Load active criteria for linking
Map<String, Id> criteriaMap = new Map<String, Id>();
for (Target_Criteria__c tc : [SELECT Id, Name FROM Target_Criteria__c WHERE Active__c = true]) {
    criteriaMap.put(tc.Name.toLowerCase(), tc.Id);
}

List<Incentive_Slab__c> slabs = new List<Incentive_Slab__c>();

// ════════════════════════════════════════════════════════════
// 1. UNIVERSAL SLABS (apply to ALL criteria when no
//    criteria-specific slab matches)
// ════════════════════════════════════════════════════════════

slabs.add(new Incentive_Slab__c(
    Name = 'Below Threshold',
    Min_Percent__c = 0,
    Max_Percent__c = 49.99,
    Payout_Type__c = 'Fixed Amount',
    Payout_Value__c = 0,
    Multiplier__c = 0,
    Is_Active__c = true,
    Sort_Order__c = 1,
    Description__c = 'No incentive for achievement below 50%'
));

slabs.add(new Incentive_Slab__c(
    Name = 'Base Achiever',
    Min_Percent__c = 50,
    Max_Percent__c = 79.99,
    Payout_Type__c = 'Percentage',
    Payout_Value__c = 2,
    Multiplier__c = 0.5,
    Is_Active__c = true,
    Sort_Order__c = 2,
    Description__c = '2% of target value at 0.5x multiplier for 50-80% achievement'
));

slabs.add(new Incentive_Slab__c(
    Name = 'Standard Achiever',
    Min_Percent__c = 80,
    Max_Percent__c = 99.99,
    Payout_Type__c = 'Percentage',
    Payout_Value__c = 3,
    Multiplier__c = 1.0,
    Is_Active__c = true,
    Sort_Order__c = 3,
    Description__c = '3% of target value at 1x multiplier for 80-100% achievement'
));

slabs.add(new Incentive_Slab__c(
    Name = 'Target Achiever',
    Min_Percent__c = 100,
    Max_Percent__c = 119.99,
    Payout_Type__c = 'Percentage',
    Payout_Value__c = 4,
    Multiplier__c = 1.5,
    Is_Active__c = true,
    Sort_Order__c = 4,
    Description__c = '4% of target value at 1.5x multiplier for 100-120% achievement'
));

slabs.add(new Incentive_Slab__c(
    Name = 'Super Achiever',
    Min_Percent__c = 120,
    Max_Percent__c = 999,
    Payout_Type__c = 'Percentage',
    Payout_Value__c = 5,
    Multiplier__c = 2.0,
    Is_Active__c = true,
    Sort_Order__c = 5,
    Description__c = '5% of target value at 2x multiplier for 120%+ achievement'
));

// ════════════════════════════════════════════════════════════
// 2. REVENUE-SPECIFIC SLABS (higher payouts for revenue KPI)
//    Only created if a "Revenue" criteria exists
// ════════════════════════════════════════════════════════════

if (criteriaMap.containsKey('revenue')) {
    Id revId = criteriaMap.get('revenue');

    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue — Below Threshold',
        Target_Criteria__c = revId,
        Min_Percent__c = 0,
        Max_Percent__c = 59.99,
        Payout_Type__c = 'Fixed Amount',
        Payout_Value__c = 0,
        Multiplier__c = 0,
        Is_Active__c = true,
        Sort_Order__c = 10,
        Description__c = 'No revenue incentive below 60%'
    ));

    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue — Base',
        Target_Criteria__c = revId,
        Min_Percent__c = 60,
        Max_Percent__c = 79.99,
        Payout_Type__c = 'Percentage',
        Payout_Value__c = 1.5,
        Multiplier__c = 1.0,
        Is_Active__c = true,
        Sort_Order__c = 11,
        Description__c = '1.5% of revenue target at 1x for 60-80%'
    ));

    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue — Standard',
        Target_Criteria__c = revId,
        Min_Percent__c = 80,
        Max_Percent__c = 99.99,
        Payout_Type__c = 'Percentage',
        Payout_Value__c = 2.5,
        Multiplier__c = 1.0,
        Is_Active__c = true,
        Sort_Order__c = 12,
        Description__c = '2.5% of revenue target at 1x for 80-100%'
    ));

    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue — Achiever',
        Target_Criteria__c = revId,
        Min_Percent__c = 100,
        Max_Percent__c = 119.99,
        Payout_Type__c = 'Percentage',
        Payout_Value__c = 3.5,
        Multiplier__c = 1.5,
        Is_Active__c = true,
        Sort_Order__c = 13,
        Description__c = '3.5% of revenue target at 1.5x for 100-120%'
    ));

    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue — Super Achiever',
        Target_Criteria__c = revId,
        Min_Percent__c = 120,
        Max_Percent__c = 999,
        Payout_Type__c = 'Percentage',
        Payout_Value__c = 5,
        Multiplier__c = 2.0,
        Is_Active__c = true,
        Sort_Order__c = 14,
        Description__c = '5% of revenue target at 2x for 120%+'
    ));
}

// ════════════════════════════════════════════════════════════
// 3. COLLECTION-SPECIFIC SLABS (fixed bonuses)
//    Only created if a "Collection" criteria exists
// ════════════════════════════════════════════════════════════

if (criteriaMap.containsKey('collection')) {
    Id colId = criteriaMap.get('collection');

    slabs.add(new Incentive_Slab__c(
        Name = 'Collection — Below Threshold',
        Target_Criteria__c = colId,
        Min_Percent__c = 0,
        Max_Percent__c = 69.99,
        Payout_Type__c = 'Fixed Amount',
        Payout_Value__c = 0,
        Multiplier__c = 0,
        Is_Active__c = true,
        Sort_Order__c = 20,
        Description__c = 'No collection incentive below 70%'
    ));

    slabs.add(new Incentive_Slab__c(
        Name = 'Collection — Base',
        Target_Criteria__c = colId,
        Min_Percent__c = 70,
        Max_Percent__c = 89.99,
        Payout_Type__c = 'Fixed Amount',
        Payout_Value__c = 1000,
        Multiplier__c = 1.0,
        Is_Active__c = true,
        Sort_Order__c = 21,
        Description__c = 'Fixed 1,000 bonus for 70-90% collection'
    ));

    slabs.add(new Incentive_Slab__c(
        Name = 'Collection — Standard',
        Target_Criteria__c = colId,
        Min_Percent__c = 90,
        Max_Percent__c = 99.99,
        Payout_Type__c = 'Fixed Amount',
        Payout_Value__c = 2500,
        Multiplier__c = 1.0,
        Is_Active__c = true,
        Sort_Order__c = 22,
        Description__c = 'Fixed 2,500 bonus for 90-100% collection'
    ));

    slabs.add(new Incentive_Slab__c(
        Name = 'Collection — Full',
        Target_Criteria__c = colId,
        Min_Percent__c = 100,
        Max_Percent__c = 999,
        Payout_Type__c = 'Fixed Amount',
        Payout_Value__c = 5000,
        Multiplier__c = 1.0,
        Is_Active__c = true,
        Sort_Order__c = 23,
        Description__c = 'Fixed 5,000 bonus for 100%+ collection'
    ));
}

// ════════════════════════════════════════════════════════════
// 4. VOLUME / ACTIVITY SLABS (fixed per-unit bonuses)
//    Only created if a "Volume" criteria exists
// ════════════════════════════════════════════════════════════

if (criteriaMap.containsKey('volume')) {
    Id volId = criteriaMap.get('volume');

    slabs.add(new Incentive_Slab__c(
        Name = 'Volume — Below Target',
        Target_Criteria__c = volId,
        Min_Percent__c = 0,
        Max_Percent__c = 79.99,
        Payout_Type__c = 'Fixed Amount',
        Payout_Value__c = 0,
        Multiplier__c = 0,
        Is_Active__c = true,
        Sort_Order__c = 30,
        Description__c = 'No volume incentive below 80%'
    ));

    slabs.add(new Incentive_Slab__c(
        Name = 'Volume — On Track',
        Target_Criteria__c = volId,
        Min_Percent__c = 80,
        Max_Percent__c = 99.99,
        Payout_Type__c = 'Fixed Amount',
        Payout_Value__c = 1500,
        Multiplier__c = 1.0,
        Is_Active__c = true,
        Sort_Order__c = 31,
        Description__c = 'Fixed 1,500 bonus for 80-100% volume'
    ));

    slabs.add(new Incentive_Slab__c(
        Name = 'Volume — Exceeded',
        Target_Criteria__c = volId,
        Min_Percent__c = 100,
        Max_Percent__c = 999,
        Payout_Type__c = 'Fixed Amount',
        Payout_Value__c = 3000,
        Multiplier__c = 1.5,
        Is_Active__c = true,
        Sort_Order__c = 32,
        Description__c = 'Fixed 3,000 at 1.5x for 100%+ volume'
    ));
}

insert slabs;

System.debug('════════════════════════════════════════════');
System.debug('Inserted ' + slabs.size() + ' incentive slabs:');
System.debug('  Universal: 5 slabs');
System.debug('  Revenue-specific: ' + (criteriaMap.containsKey('revenue') ? '5' : '0 (no Revenue criteria found)'));
System.debug('  Collection-specific: ' + (criteriaMap.containsKey('collection') ? '4' : '0 (no Collection criteria found)'));
System.debug('  Volume-specific: ' + (criteriaMap.containsKey('volume') ? '3' : '0 (no Volume criteria found)'));
System.debug('════════════════════════════════════════════');
