// ============================================================
// Script 13: Incentive Slab Seed Data — Full PBIS Configuration
// Run: sf apex run -f scripts/13_incentive_slabs.apex
//
// Creates slabs for a typical FMCG PBIS structure:
//   1. Universal slabs (fallback for all)
//   2. Revenue-specific slabs (salary-based, by profile: TSE/ASM/RSM/NSM)
//   3. Collection-specific slabs (fixed bonuses)
//   4. Volume-specific slabs (fixed bonuses)
//   5. S&D Parameter slabs (salary-based, by profile)
//
// Profiles used (must match User.Profile.Name):
//   FSCRM_TSE — Territory Sales Executive (field sales rep)
//   FSCRM_ASM — Area Sales Manager
//   FSCRM_RSM — Regional Sales Manager
//   FSCRM_NSM — National Sales Manager
//
// Prerequisites:
//   - Target_Criteria__c records (14_target_criteria_and_actuals.apex)
//   - FSCRM profiles deployed to org
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
for (Territory_Master__c tm : [SELECT Id, Territory_Code__c, Name FROM Territory_Master__c WHERE Is_Active__c = true]) {
    territoryMap.put(tm.Territory_Code__c, tm.Id);
}

// ── Profile names (must match User.Profile.Name exactly) ───
String PF_TSE = 'FSCRM_TSE';
String PF_ASM = 'FSCRM_ASM';
String PF_RSM = 'FSCRM_RSM';
String PF_NSM = 'FSCRM_NSM';

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
//    All 4 profiles: TSE, ASM, RSM, NSM
// ════════════════════════════════════════════════════════════

if (criteriaMap.containsKey('revenue')) {
    Id revId = criteriaMap.get('revenue');

    // ── TSE (Territory Sales Executive) — highest slab rates ──
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue TSE — Below', Target_Criteria__c = revId, Profile_Name__c = PF_TSE,
        Min_Percent__c = 0, Max_Percent__c = 89.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 0,
        Multiplier__c = 0, Is_Active__c = true, Sort_Order__c = 10,
        Description__c = 'No incentive for TSE below 90%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue TSE — 90-95%', Target_Criteria__c = revId, Profile_Name__c = PF_TSE,
        Min_Percent__c = 90, Max_Percent__c = 94.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 4.5,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 11,
        Description__c = '4.5% of monthly salary for TSE at 90-95% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue TSE — 95-100%', Target_Criteria__c = revId, Profile_Name__c = PF_TSE,
        Min_Percent__c = 95, Max_Percent__c = 99.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 10,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 12,
        Description__c = '10% of monthly salary for TSE at 95-100% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue TSE — 100-110%', Target_Criteria__c = revId, Profile_Name__c = PF_TSE,
        Min_Percent__c = 100, Max_Percent__c = 109.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 17.75,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 13,
        Description__c = '17.75% of monthly salary for TSE at 100-110% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue TSE — 110%+', Target_Criteria__c = revId, Profile_Name__c = PF_TSE,
        Min_Percent__c = 110, Max_Percent__c = 999,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 20,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 14,
        Description__c = '20% of monthly salary for TSE at 110%+ revenue'
    ));

    // ── ASM (Area Sales Manager) — slightly lower rates ──
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue ASM — Below', Target_Criteria__c = revId, Profile_Name__c = PF_ASM,
        Min_Percent__c = 0, Max_Percent__c = 89.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 0,
        Multiplier__c = 0, Is_Active__c = true, Sort_Order__c = 20,
        Description__c = 'No incentive for ASM below 90%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue ASM — 90-95%', Target_Criteria__c = revId, Profile_Name__c = PF_ASM,
        Min_Percent__c = 90, Max_Percent__c = 94.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 3.75,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 21,
        Description__c = '3.75% of monthly salary for ASM at 90-95% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue ASM — 95-100%', Target_Criteria__c = revId, Profile_Name__c = PF_ASM,
        Min_Percent__c = 95, Max_Percent__c = 99.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 8.25,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 22,
        Description__c = '8.25% of monthly salary for ASM at 95-100% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue ASM — 100-110%', Target_Criteria__c = revId, Profile_Name__c = PF_ASM,
        Min_Percent__c = 100, Max_Percent__c = 109.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 14.5,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 23,
        Description__c = '14.5% of monthly salary for ASM at 100-110% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue ASM — 110%+', Target_Criteria__c = revId, Profile_Name__c = PF_ASM,
        Min_Percent__c = 110, Max_Percent__c = 999,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 17,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 24,
        Description__c = '17% of monthly salary for ASM at 110%+ revenue'
    ));

    // ── RSM (Regional Sales Manager) — team performance based ──
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue RSM — Below', Target_Criteria__c = revId, Profile_Name__c = PF_RSM,
        Min_Percent__c = 0, Max_Percent__c = 89.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 0,
        Multiplier__c = 0, Is_Active__c = true, Sort_Order__c = 30,
        Description__c = 'No incentive for RSM below 90%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue RSM — 90-95%', Target_Criteria__c = revId, Profile_Name__c = PF_RSM,
        Min_Percent__c = 90, Max_Percent__c = 94.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 3,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 31,
        Description__c = '3% of monthly salary for RSM at 90-95% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue RSM — 95-100%', Target_Criteria__c = revId, Profile_Name__c = PF_RSM,
        Min_Percent__c = 95, Max_Percent__c = 99.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 7,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 32,
        Description__c = '7% of monthly salary for RSM at 95-100% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue RSM — 100-110%', Target_Criteria__c = revId, Profile_Name__c = PF_RSM,
        Min_Percent__c = 100, Max_Percent__c = 109.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 12,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 33,
        Description__c = '12% of monthly salary for RSM at 100-110% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue RSM — 110%+', Target_Criteria__c = revId, Profile_Name__c = PF_RSM,
        Min_Percent__c = 110, Max_Percent__c = 999,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 15,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 34,
        Description__c = '15% of monthly salary for RSM at 110%+ revenue'
    ));

    // ── NSM (National Sales Manager) — strategic level ──
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue NSM — Below', Target_Criteria__c = revId, Profile_Name__c = PF_NSM,
        Min_Percent__c = 0, Max_Percent__c = 89.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 0,
        Multiplier__c = 0, Is_Active__c = true, Sort_Order__c = 35,
        Description__c = 'No incentive for NSM below 90%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue NSM — 90-95%', Target_Criteria__c = revId, Profile_Name__c = PF_NSM,
        Min_Percent__c = 90, Max_Percent__c = 94.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 2.5,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 36,
        Description__c = '2.5% of monthly salary for NSM at 90-95% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue NSM — 95-100%', Target_Criteria__c = revId, Profile_Name__c = PF_NSM,
        Min_Percent__c = 95, Max_Percent__c = 99.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 5.5,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 37,
        Description__c = '5.5% of monthly salary for NSM at 95-100% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue NSM — 100-110%', Target_Criteria__c = revId, Profile_Name__c = PF_NSM,
        Min_Percent__c = 100, Max_Percent__c = 109.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 10,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 38,
        Description__c = '10% of monthly salary for NSM at 100-110% revenue'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue NSM — 110%+', Target_Criteria__c = revId, Profile_Name__c = PF_NSM,
        Min_Percent__c = 110, Max_Percent__c = 999,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 12.5,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 39,
        Description__c = '12.5% of monthly salary for NSM at 110%+ revenue'
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
// 5. S&D PARAMETERS — SALARY-BASED BY PROFILE (TSE & ASM only)
//    (Focus Brands, Outlet Expansion, Visibility, etc.)
// ════════════════════════════════════════════════════════════

List<String> sdNames = new List<String>{ 'focus brand', 'outlet expansion', 's&d', 'visibility', 'new outlets' };
for (String sdName : sdNames) {
    if (!criteriaMap.containsKey(sdName)) continue;
    Id sdId = criteriaMap.get(sdName);
    String label = sdName.capitalize();

    // TSE S&D slabs
    slabs.add(new Incentive_Slab__c(
        Name = label + ' TSE — Below', Target_Criteria__c = sdId, Profile_Name__c = PF_TSE,
        Min_Percent__c = 0, Max_Percent__c = 89.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 0,
        Multiplier__c = 0, Is_Active__c = true, Sort_Order__c = 60,
        Description__c = 'No ' + label + ' incentive for TSE below 90%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = label + ' TSE — 90-95%', Target_Criteria__c = sdId, Profile_Name__c = PF_TSE,
        Min_Percent__c = 90, Max_Percent__c = 94.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 4.5,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 61,
        Description__c = '4.5% of salary for TSE ' + label + ' at 90-95%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = label + ' TSE — 95-100%', Target_Criteria__c = sdId, Profile_Name__c = PF_TSE,
        Min_Percent__c = 95, Max_Percent__c = 99.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 10,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 62,
        Description__c = '10% of salary for TSE ' + label + ' at 95-100%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = label + ' TSE — 100%+', Target_Criteria__c = sdId, Profile_Name__c = PF_TSE,
        Min_Percent__c = 100, Max_Percent__c = 999,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 17.75,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 63,
        Description__c = '17.75% of salary for TSE ' + label + ' at 100%+'
    ));

    // ASM S&D slabs
    slabs.add(new Incentive_Slab__c(
        Name = label + ' ASM — Below', Target_Criteria__c = sdId, Profile_Name__c = PF_ASM,
        Min_Percent__c = 0, Max_Percent__c = 89.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 0,
        Multiplier__c = 0, Is_Active__c = true, Sort_Order__c = 70,
        Description__c = 'No ' + label + ' incentive for ASM below 90%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = label + ' ASM — 90-95%', Target_Criteria__c = sdId, Profile_Name__c = PF_ASM,
        Min_Percent__c = 90, Max_Percent__c = 94.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 3.75,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 71,
        Description__c = '3.75% of salary for ASM ' + label + ' at 90-95%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = label + ' ASM — 95-100%', Target_Criteria__c = sdId, Profile_Name__c = PF_ASM,
        Min_Percent__c = 95, Max_Percent__c = 99.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 8.25,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 72,
        Description__c = '8.25% of salary for ASM ' + label + ' at 95-100%'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = label + ' ASM — 100%+', Target_Criteria__c = sdId, Profile_Name__c = PF_ASM,
        Min_Percent__c = 100, Max_Percent__c = 999,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 14.5,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 73,
        Description__c = '14.5% of salary for ASM ' + label + ' at 100%+'
    ));
}


// ════════════════════════════════════════════════════════════
// 6. TERRITORY-SPECIFIC SLABS (Delhi — higher incentive zone)
//    Revenue criteria with premium multiplier
// ════════════════════════════════════════════════════════════

if (criteriaMap.containsKey('revenue') && territoryMap.containsKey('TER-DEL-001')) {
    Id revId = criteriaMap.get('revenue');
    Id delTer = territoryMap.get('TER-DEL-001');

    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue Delhi TSE — 100-110%', Target_Criteria__c = revId,
        Profile_Name__c = PF_TSE, Territory__c = delTer,
        Min_Percent__c = 100, Max_Percent__c = 109.99,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 20,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 80,
        Description__c = '20% of salary for Delhi TSE at 100-110% (premium zone)'
    ));
    slabs.add(new Incentive_Slab__c(
        Name = 'Revenue Delhi TSE — 110%+', Target_Criteria__c = revId,
        Profile_Name__c = PF_TSE, Territory__c = delTer,
        Min_Percent__c = 110, Max_Percent__c = 999,
        Payout_Type__c = 'Salary Percentage', Payout_Value__c = 22.5,
        Multiplier__c = 1.0, Is_Active__c = true, Sort_Order__c = 81,
        Description__c = '22.5% of salary for Delhi TSE at 110%+ (premium zone)'
    ));
}


// ════════════════════════════════════════════════════════════
// INSERT & REPORT
// ════════════════════════════════════════════════════════════

insert slabs;

// Count by type
Integer universal = 0, revenue = 0, collection = 0, volume = 0, sd = 0, territory = 0;
for (Incentive_Slab__c s : slabs) {
    if (s.Territory__c != null) { territory++; }
    else if (s.Target_Criteria__c == null) { universal++; }
    else if (s.Name.startsWith('Revenue')) { revenue++; }
    else if (s.Name.startsWith('Collection')) { collection++; }
    else if (s.Name.startsWith('Volume')) { volume++; }
    else { sd++; }
}

System.debug('');
System.debug('════════════════════════════════════════════');
System.debug('Inserted ' + slabs.size() + ' incentive slabs:');
System.debug('  Universal (fallback):       ' + universal);
System.debug('  Revenue (salary, 4 roles):  ' + revenue);
System.debug('  Collection (fixed):         ' + collection);
System.debug('  Volume (fixed):             ' + volume);
System.debug('  S&D Parameters (salary):    ' + sd);
System.debug('  Territory-specific (Delhi):  ' + territory);
System.debug('════════════════════════════════════════════');
System.debug('');
System.debug('Profile Breakdown:');
System.debug('  FSCRM_TSE slabs: ' + [SELECT COUNT() FROM Incentive_Slab__c WHERE Profile_Name__c = :PF_TSE]);
System.debug('  FSCRM_ASM slabs: ' + [SELECT COUNT() FROM Incentive_Slab__c WHERE Profile_Name__c = :PF_ASM]);
System.debug('  FSCRM_RSM slabs: ' + [SELECT COUNT() FROM Incentive_Slab__c WHERE Profile_Name__c = :PF_RSM]);
System.debug('  FSCRM_NSM slabs: ' + [SELECT COUNT() FROM Incentive_Slab__c WHERE Profile_Name__c = :PF_NSM]);
System.debug('  Universal (no profile): ' + [SELECT COUNT() FROM Incentive_Slab__c WHERE Profile_Name__c = null]);
System.debug('════════════════════════════════════════════');
