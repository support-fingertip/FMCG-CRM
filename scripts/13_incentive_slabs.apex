// ============================================================
// Incentive Slab Seed Data
// Run via: Execute Anonymous in Developer Console
// Creates sample incentive slabs for Revenue and Collection criteria
// ============================================================

// Delete existing slabs
delete [SELECT Id FROM Incentive_Slab__c];

List<Incentive_Slab__c> slabs = new List<Incentive_Slab__c>();

// ── Universal Slabs (apply to ALL criteria) ─────────────────
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

insert slabs;
System.debug('Inserted ' + slabs.size() + ' incentive slabs');
