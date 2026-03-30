// ============================================================
// Incentive Slab Seed Data — Full PBIS Configuration
// Run via: Execute Anonymous in Developer Console
//
// Creates slabs for a typical FMCG PBIS structure:
//   1. Universal slabs (fallback for all)
//   2. Revenue-specific slabs (salary-based, by profile)
//   3. Collection-specific slabs (fixed bonuses)
//   4. Volume-specific slabs (fixed bonuses)
//   5. S&D Parameter slabs (salary-based, by profile)
//
// New schema fields used:
//   - Payout_Type__c: 'Salary Percentage' (% of gross salary)
//   - Profile_Name__c: Profile-based slab targeting
//   - Territory__c: Region-specific slabs (optional)
//
// Prerequisites:
//   - Target_Criteria__c records must exist (Revenue, Collection, etc.)
//   - Profiles must exist in the org
//   - Territory_Master__c records (optional, for region-specific slabs)
// ============================================================

// Clean slate
delete [SELECT Id FROM Incentive_Slab__c];

// ── Load criteria ──────────────────────────────────────────
Map<String, Id> criteriaMap = new Map<String, Id>();
for (Target_Criteria__c tc : [SELECT Id, Name FROM Target_Criteria__c WHERE Active__c = true]) {
    criteriaMap.put(tc.Name.toLowerCase(), tc.Id);
}

// ── Load territories (optional) ────────────────────────────
Map<String, Id> territoryMap = new Map<String, Id>();
for (Territory_Master__c tm : [SELECT Id, Name FROM Territory_Master__c WHERE Is_Active__c = true]) {
    territoryMap.put(tm.Name.toLowerCase(), tm.Id);
}

List<Incentive_Slab__c> slabs = new List<Incentive_Slab__c>();

// ════════════════════════════════════════════════════════════
// 1. UNIVERSAL SLABS (fallback — no criteria, profile, territory)
//    Payout: % of target value
// ════════════════════════════════════════════════════════════

slabs.add(new Incentive_Slab__c(
    Name = 'Universal — Below Threshold',
    Min_Percent__c = 0, Max_Percent__c = 89.99,
    Payout_Type__c = 'Fixed Amount', Payout_Value__c = 0,
    Multiplier__c = 0, Is_Active__c = true, Sort_Order__c = 1,
    Description__c = 'No incentive below 90% achievement (universal fallback)'
));

slabs.add(new Incentive_Slab__c(
    Name = 'Universal — Base',
    Min_Percent__c = 90, Max_Percent__c = 94.99,
    Payout_Type__c = 'Percentage', Payout_Value__c = 3,
    Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 2,
    Description__c = '3% of target value for 90-95% achievement'
));

slabs.add(new Incentive_Slab__c(
    Name = 'Universal — Standard',
    Min_Percent__c = 95, Max_Percent__c = 99.99,
    Payout_Type__c = 'Percentage', Payout_Value__c = 8,
    Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 3,
    Description__c = '8% of target value for 95-100% achievement'
));

slabs.add(new Incentive_Slab__c(
    Name = 'Universal — Achiever',
    Min_Percent__c = 100, Max_Percent__c = 109.99,
    Payout_Type__c = 'Percentage', Payout_Value__c = 15,
    Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 4,
    Description__c = '15% of target value for 100-110% achievement'
));

slabs.add(new Incentive_Slab__c(
    Name = 'Universal — Super Achiever',
    Min_Percent__c = 110, Max_Percent__c = 999,
    Payout_Type__c = 'Percentage', Payout_Value__c = 15,
    Multiplier__c = 1.3, Is_Active__c = true, Sort_Order__c = 5,
    Description__c = '15% of target at 1.3x multiplier for 110%+ achievement'
));


// ════════════════════════════════════════════════════════════
// 2. REVENUE — SALARY-BASED SLABS BY PROFILE
//    Payout: % of gross salary (standard FMCG PBIS)
//    Profile: Field Sales Rep (TSE), Area Sales Manager (ASM), Regional Sales Manager (RSM)
// ════════════════════════════════════════════════════════════

if (criteriaMap.containsKey('revenue')) {
    Id revId = criteriaMap.get('revenue');

    // ── Field Sales Rep / TSE slabs ──
    String tsePf = 'Custom: Sales Profile'; // Adjust to your org's profile name

    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue TSE — Below', Target_Criteria__c = revId, Profile_Name__c = tsePf,
        Min_Percent__c = 0, Max_Percent__c = 89.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 0,
        Multiplier__c = 0, Is_Active__c = true, Sort_Order__c = 10,
        Description__c = 'No incentive for TSE below 90%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue TSE — 90-95%', Target_Criteria__c = revId, Profile_Name__c = tsePf,
        Min_Percent__c = 90, Max_Percent__c = 94.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 4.5,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 11,
        Description__c = '4.5% of monthly salary for TSE at 90-95% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue TSE — 95-100%', Target_Criteria__c = revId, Profile_Name__c = tsePf,
        Min_Percent__c = 95, Max_Percent__c = 99.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 10,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 12,
        Description__c = '10% of monthly salary for TSE at 95-100% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue TSE — 100-110%', Target_Criteria__c = revId, Profile_Name__c = tsePf,
        Min_Percent__c = 100, Max_Percent__c = 109.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 17.75,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 13,
        Description__c = '17.75% of monthly salary for TSE at 100-110% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue TSE — 110%+', Target_Criteria__c = revId, Profile_Name__c = tsePf,
        Min_Percent__c = 110, Max_Percent__c = 999,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 20,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 14,
        Description__c = '20% of monthly salary for TSE at 110%+ revenue'
    ));

    // ── Area Sales Manager slabs ──
    String asmPf = 'Standard'; // Adjust to your org's ASM profile name

    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue ASM — Below', Target_Criteria__c = revId, Profile_Name__c = asmPf,
        Min_Percent__c = 0, Max_Percent__c = 89.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 0,
        Multiplier__c = 0, Is_Active__c = true, Sort_Order__c = 20,
        Description__c = 'No incentive for ASM below 90%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue ASM — 90-95%', Target_Criteria__c = revId, Profile_Name__c = asmPf,
        Min_Percent__c = 90, Max_Percent__c = 94.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 3.75,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 21,
        Description__c = '3.75% of monthly salary for ASM at 90-95% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue ASM — 95-100%', Target_Criteria__c = revId, Profile_Name__c = asmPf,
        Min_Percent__c = 95, Max_Percent__c = 99.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 8.25,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 22,
        Description__c = '8.25% of monthly salary for ASM at 95-100% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue ASM — 100-110%', Target_Criteria__c = revId, Profile_Name__c = asmPf,
        Min_Percent__c = 100, Max_Percent__c = 109.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 14.5,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 23,
        Description__c = '14.5% of monthly salary for ASM at 100-110% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue ASM — 110%+', Target_Criteria__c = revId, Profile_Name__c = asmPf,
        Min_Percent__c = 110, Max_Percent__c = 999,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 17,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 24,
        Description__c = '17% of monthly salary for ASM at 110%+ revenue'
    ));
}


// ════════════════════════════════════════════════════════════
// 3. COLLECTION — FIXED BONUSES (same for all profiles)
// ════════════════════════════════════════════════════════════

if (criteriaMap.containsKey('collection')) {
    Id colId = criteriaMap.get('collection');

    slabs.add(new Incentive_Slab__c(
        Name = 'Collection — Below', Target_Criteria__c = colId,
        Min_Percent__c = 0, Max_Percent__c = 69.99,
        Payout_Type__c = 'Fixed Amount', Payout_Value__c = 0,
        Multiplier__c = 0, Is_Active__c = true, Sort_Order__c = 40,
        Description__c = 'No collection incentive below 70%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Collection — 70-90%', Target_Criteria__c = colId,
        Min_Percent__c = 70, Max_Percent__c = 89.99,
        Payout_Type__c = 'Fixed Amount', Payout_Value__c = 1000,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 41,
        Description__c = 'Fixed Rs. 1,000 bonus for 70-90% collection'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Collection — 90-100%', Target_Criteria__c = colId,
        Min_Percent__c = 90, Max_Percent__c = 99.99,
        Payout_Type__c = 'Fixed Amount', Payout_Value__c = 2500,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 42,
        Description__c = 'Fixed Rs. 2,500 bonus for 90-100% collection'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Collection — 100%+', Target_Criteria__c = colId,
        Min_Percent__c = 100, Max_Percent__c = 999,
        Payout_Type__c = 'Fixed Amount', Payout_Value__c = 5000,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 43,
        Description__c = 'Fixed Rs. 5,000 bonus for 100%+ collection'
    ));
}


// ════════════════════════════════════════════════════════════
// 4. VOLUME — FIXED BONUSES WITH MULTIPLIER
// ════════════════════════════════════════════════════════════

if (criteriaMap.containsKey('volume')) {
    Id volId = criteriaMap.get('volume');

    slabs.add(new Incentive_Slab__c(
        Name = 'Volume — Below', Target_Criteria__c = volId,
        Min_Percent__c = 0, Max_Percent__c = 79.99,
        Payout_Type__c = 'Fixed Amount', Payout_Value__c = 0,
        Multiplier__c = 0, Is_Active__c = true, Sort_Order__c = 50,
        Description__c = 'No volume incentive below 80%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Volume — 80-100%', Target_Criteria__c = volId,
        Min_Percent__c = 80, Max_Percent__c = 99.99,
        Payout_Type__c = 'Fixed Amount', Payout_Value__c = 1500,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 51,
        Description__c = 'Fixed Rs. 1,500 for 80-100% volume'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Volume — 100%+', Target_Criteria__c = volId,
        Min_Percent__c = 100, Max_Percent__c = 999,
        Payout_Type__c = 'Fixed Amount', Payout_Value__c = 3000,
        Multiplier__c = 1.5, Is_Active__c = true, Sort_Order__c = 52,
        Description__c = 'Fixed Rs. 3,000 at 1.5x multiplier for 100%+ volume'
    ));
}


// ════════════════════════════════════════════════════════════
// 5. S&D PARAMETERS — SALARY-BASED BY PROFILE
//    (Focus Brands, Outlet Expansion, Visibility)
// ════════════════════════════════════════════════════════════

// Check for common S&D criteria names
List<String> sdNames = new List<String>{ 'focus brand', 'outlet expansion', 's&d', 'visibility' };
for (String sdName : sdNames) {
    if (!criteriaMap.containsKey(sdName)) continue;
    Id sdId = criteriaMap.get(sdName);
    String label = sdName.capitalize();

    slabs.add(new Incentive_Slab__c(
        Name = label + ' — Below', Target_Criteria__c = sdId,
        Min_Percent__c = 0, Max_Percent__c = 89.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 0,
        Multiplier__c = 0, Is_Active__c = true, Sort_Order__c = 60,
        Description__c = 'No ' + label + ' incentive below 90%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = label + ' — 90-95%', Target_Criteria__c = sdId,
        Min_Percent__c = 90, Max_Percent__c = 94.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 4.5,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 61,
        Description__c = '4.5% of salary for ' + label + ' at 90-95%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = label + ' — 95-100%', Target_Criteria__c = sdId,
        Min_Percent__c = 95, Max_Percent__c = 99.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 10,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 62,
        Description__c = '10% of salary for ' + label + ' at 95-100%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = label + ' — 100%+', Target_Criteria__c = sdId,
        Min_Percent__c = 100, Max_Percent__c = 999,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 17.75,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 63,
        Description__c = '17.75% of salary for ' + label + ' at 100%+'
    ));
}


// ════════════════════════════════════════════════════════════
// INSERT & REPORT
// ════════════════════════════════════════════════════════════

insert slabs;

// Count by type
Integer universal = 0, revenue = 0, collection = 0, volume = 0, sd = 0;
for (Incentive_Slab__c s : slabs) {
    if (s.Target_Criteria__c == null) { universal++; }
    else if (s.Name.startsWith('Revenue')) { revenue++; }
    else if (s.Name.startsWith('Collection')) { collection++; }
    else if (s.Name.startsWith('Volume')) { volume++; }
    else { sd++; }
}

System.debug('════════════════════════════════════════════');
System.debug('Inserted ' + slabs.size() + ' incentive slabs:');
System.debug('  Universal (fallback):     ' + universal);
System.debug('  Revenue (salary-based):   ' + revenue);
System.debug('  Collection (fixed):       ' + collection);
System.debug('  Volume (fixed):           ' + volume);
System.debug('  S&D Parameters (salary):  ' + sd);
System.debug('════════════════════════════════════════════');
System.debug('');
System.debug('Payout Types Used:');
System.debug('  Percentage (of target):   For universal slabs');
System.debug('  Fixed Amount:             For collection & volume');
System.debug('  Salary Percentage:        For revenue & S&D (PBIS standard)');
System.debug('');
System.debug('Profile-specific slabs: ' + [SELECT COUNT() FROM Incentive_Slab__c WHERE Profile_Name__c != null]);
System.debug('Territory-specific slabs: ' + [SELECT COUNT() FROM Incentive_Slab__c WHERE Territory__c != null]);
System.debug('════════════════════════════════════════════');
