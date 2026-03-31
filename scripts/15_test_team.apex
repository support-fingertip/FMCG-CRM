// ============================================================
// Seed Script: Test Team — Roles, Users, Employees, Targets
// Creates a 15-person FMCG sales hierarchy for testing:
//   1 NSM → 2 RSMs → 4 ASMs → 8 TSEs
//
// Prerequisites:
//   - Run 13_target_periods.apex first
//   - Run 14_target_criteria_and_actuals.apex first
//   - Run 13_incentive_slabs.apex first
//   - A profile named 'Standard' must exist
//
// Run via: Execute Anonymous in Developer Console
// NOTE: This script creates Users which requires System Admin access
// ============================================================

// ── Config ──────────────────────────────────────────────────
String emailDomain = '@fmcg-test.com';
String profileName = 'Standard';

// Get profile
Profile stdProfile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];

// Get current period
Target_Period__c currentPeriod;
try {
    currentPeriod = [
        SELECT Id, Name FROM Target_Period__c
        WHERE Is_Default__c = true AND Is_Active__c = true LIMIT 1
    ];
} catch(Exception e) {
    currentPeriod = [
        SELECT Id, Name FROM Target_Period__c
        WHERE Start_Date__c <= TODAY AND End_Date__c >= TODAY
        AND Is_Active__c = true ORDER BY Type__c ASC LIMIT 1
    ];
}

// Get criteria
Map<String, Id> criteriaMap = new Map<String, Id>();
for (Target_Criteria__c tc : [SELECT Id, Name FROM Target_Criteria__c WHERE Active__c = true]) {
    criteriaMap.put(tc.Name, tc.Id);
}

System.debug('Period: ' + currentPeriod.Name);
System.debug('Criteria: ' + criteriaMap.keySet());

// ═══════════════════════════════════════════════════════════
// 1. CREATE USERS (15 total)
// ═══════════════════════════════════════════════════════════

List<User> users = new List<User>();

// NSM (1)
users.add(new User(
    FirstName = 'Rajesh', LastName = 'Kapoor',
    Alias = 'rkapoor', Email = 'rajesh.kapoor' + emailDomain,
    Username = 'rajesh.kapoor' + emailDomain + '.' + UserInfo.getOrganizationId(),
    ProfileId = stdProfile.Id, TimeZoneSidKey = 'Asia/Kolkata',
    LocaleSidKey = 'en_IN', EmailEncodingKey = 'UTF-8',
    LanguageLocaleKey = 'en_US', IsActive = true
));

// RSMs (2)
users.add(new User(
    FirstName = 'Suresh', LastName = 'Menon',
    Alias = 'smenon', Email = 'suresh.menon' + emailDomain,
    Username = 'suresh.menon' + emailDomain + '.' + UserInfo.getOrganizationId(),
    ProfileId = stdProfile.Id, TimeZoneSidKey = 'Asia/Kolkata',
    LocaleSidKey = 'en_IN', EmailEncodingKey = 'UTF-8',
    LanguageLocaleKey = 'en_US', IsActive = true
));
users.add(new User(
    FirstName = 'Priya', LastName = 'Nair',
    Alias = 'pnair', Email = 'priya.nair' + emailDomain,
    Username = 'priya.nair' + emailDomain + '.' + UserInfo.getOrganizationId(),
    ProfileId = stdProfile.Id, TimeZoneSidKey = 'Asia/Kolkata',
    LocaleSidKey = 'en_IN', EmailEncodingKey = 'UTF-8',
    LanguageLocaleKey = 'en_US', IsActive = true
));

// ASMs (4)
String[] asmFirstNames = new String[]{ 'Amit', 'Deepa', 'Vikram', 'Shalini' };
String[] asmLastNames = new String[]{ 'Sharma', 'Pillai', 'Singh', 'Gupta' };
for (Integer i = 0; i < 4; i++) {
    String alias = asmFirstNames[i].substring(0,1).toLowerCase() + asmLastNames[i].substring(0,5).toLowerCase();
    users.add(new User(
        FirstName = asmFirstNames[i], LastName = asmLastNames[i],
        Alias = alias, Email = asmFirstNames[i].toLowerCase() + '.' + asmLastNames[i].toLowerCase() + emailDomain,
        Username = asmFirstNames[i].toLowerCase() + '.' + asmLastNames[i].toLowerCase() + emailDomain + '.' + UserInfo.getOrganizationId(),
        ProfileId = stdProfile.Id, TimeZoneSidKey = 'Asia/Kolkata',
        LocaleSidKey = 'en_IN', EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US', IsActive = true
    ));
}

// TSEs (8)
String[] tseFirstNames = new String[]{ 'Rahul', 'Anjali', 'Karthik', 'Meera', 'Arjun', 'Divya', 'Nikhil', 'Pooja' };
String[] tseLastNames = new String[]{ 'Kumar', 'Reddy', 'Nambiar', 'Iyer', 'Patel', 'Joshi', 'Rao', 'Desai' };
for (Integer i = 0; i < 8; i++) {
    String alias = tseFirstNames[i].substring(0,1).toLowerCase() + tseLastNames[i].substring(0, Math.min(5, tseLastNames[i].length())).toLowerCase();
    users.add(new User(
        FirstName = tseFirstNames[i], LastName = tseLastNames[i],
        Alias = alias, Email = tseFirstNames[i].toLowerCase() + '.' + tseLastNames[i].toLowerCase() + emailDomain,
        Username = tseFirstNames[i].toLowerCase() + '.' + tseLastNames[i].toLowerCase() + emailDomain + '.' + UserInfo.getOrganizationId(),
        ProfileId = stdProfile.Id, TimeZoneSidKey = 'Asia/Kolkata',
        LocaleSidKey = 'en_IN', EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US', IsActive = true
    ));
}

insert users;
System.debug('Created ' + users.size() + ' Users');

// ═══════════════════════════════════════════════════════════
// 2. SET MANAGER HIERARCHY
// ═══════════════════════════════════════════════════════════

// NSM = users[0]
// RSM1 = users[1], RSM2 = users[2]
// ASM1-2 under RSM1, ASM3-4 under RSM2
// TSE1-2 under ASM1, TSE3-4 under ASM2, TSE5-6 under ASM3, TSE7-8 under ASM4

Id nsmId = users[0].Id;
Id rsm1Id = users[1].Id;
Id rsm2Id = users[2].Id;

// RSMs report to NSM
users[1].ManagerId = nsmId;
users[2].ManagerId = nsmId;

// ASMs report to RSMs
users[3].ManagerId = rsm1Id; // ASM1 → RSM1
users[4].ManagerId = rsm1Id; // ASM2 → RSM1
users[5].ManagerId = rsm2Id; // ASM3 → RSM2
users[6].ManagerId = rsm2Id; // ASM4 → RSM2

// TSEs report to ASMs
users[7].ManagerId = users[3].Id;   // TSE1 → ASM1
users[8].ManagerId = users[3].Id;   // TSE2 → ASM1
users[9].ManagerId = users[4].Id;   // TSE3 → ASM2
users[10].ManagerId = users[4].Id;  // TSE4 → ASM2
users[11].ManagerId = users[5].Id;  // TSE5 → ASM3
users[12].ManagerId = users[5].Id;  // TSE6 → ASM3
users[13].ManagerId = users[6].Id;  // TSE7 → ASM4
users[14].ManagerId = users[6].Id;  // TSE8 → ASM4

update users;
System.debug('Set manager hierarchy');

// ═══════════════════════════════════════════════════════════
// 3. CREATE EMPLOYEE RECORDS (linked to Users)
// ═══════════════════════════════════════════════════════════

String[] designations = new String[]{
    'National Sales Manager',
    'Regional Sales Manager', 'Regional Sales Manager',
    'Area Sales Manager', 'Area Sales Manager', 'Area Sales Manager', 'Area Sales Manager',
    'Territory Sales Executive', 'Territory Sales Executive', 'Territory Sales Executive', 'Territory Sales Executive',
    'Territory Sales Executive', 'Territory Sales Executive', 'Territory Sales Executive', 'Territory Sales Executive'
};

Decimal[] salaries = new Decimal[]{
    150000,
    80000, 80000,
    50000, 50000, 50000, 50000,
    30000, 30000, 30000, 30000, 30000, 30000, 30000, 30000
};

String[] regions = new String[]{
    'National',
    'North', 'South',
    'Delhi', 'Mumbai', 'Chennai', 'Bangalore',
    'Delhi-1', 'Delhi-2', 'Mumbai-1', 'Mumbai-2',
    'Chennai-1', 'Chennai-2', 'Bangalore-1', 'Bangalore-2'
};

List<Employee__c> employees = new List<Employee__c>();
for (Integer i = 0; i < users.size(); i++) {
    employees.add(new Employee__c(
        First_Name__c = users[i].FirstName,
        Last_Name__c = users[i].LastName,
        Employee_Code__c = 'EMP-' + String.valueOf(i + 1).leftPad(3, '0'),
        Email__c = users[i].Email,
        Phone__c = '98' + String.valueOf(10000000 + i),
        Department__c = 'Sales',
        Designation__c = designations[i],
        Date_of_Joining__c = Date.newInstance(2023, 1, 1).addDays(i * 30),
        Is_Active__c = true,
        Region__c = regions[i],
        Gross_Salary__c = salaries[i],
        User__c = users[i].Id,
        Reporting_Manager__c = null // Will set after insert
    ));
}
insert employees;

// Set employee reporting hierarchy
employees[1].Reporting_Manager__c = employees[0].Id; // RSM1 → NSM
employees[2].Reporting_Manager__c = employees[0].Id; // RSM2 → NSM
employees[3].Reporting_Manager__c = employees[1].Id; // ASM1 → RSM1
employees[4].Reporting_Manager__c = employees[1].Id; // ASM2 → RSM1
employees[5].Reporting_Manager__c = employees[2].Id; // ASM3 → RSM2
employees[6].Reporting_Manager__c = employees[2].Id; // ASM4 → RSM2
for (Integer i = 7; i < 15; i++) {
    employees[i].Reporting_Manager__c = employees[3 + ((i - 7) / 2)].Id;
}
update employees;
System.debug('Created ' + employees.size() + ' Employees with hierarchy');

// ═══════════════════════════════════════════════════════════
// 4. CREATE TARGET ACTUALS FOR ALL TSEs (8 users × N criteria)
// ═══════════════════════════════════════════════════════════

// Target values by designation
Map<String, Decimal> revenueTargets = new Map<String, Decimal>{
    'Territory Sales Executive' => 300000,
    'Area Sales Manager' => 700000,
    'Regional Sales Manager' => 1500000,
    'National Sales Manager' => 3000000
};

// Varying achievement percentages for realistic data
Decimal[] achievementPcts = new Decimal[]{
    0.95, 0.88, 1.05, 0.78, 1.12, 0.92, 0.85, 1.08,
    0.97, 0.82, 1.15, 0.70, 0.99, 0.91, 0.86, 1.03
};

List<Target_Actual__c> allActuals = new List<Target_Actual__c>();

for (Integer i = 0; i < users.size(); i++) {
    Decimal baseTarget = revenueTargets.get(designations[i]);
    if (baseTarget == null) baseTarget = 300000;
    Decimal achPct = achievementPcts[Math.mod(i, achievementPcts.size())];

    // Revenue target
    if (criteriaMap.containsKey('Revenue')) {
        allActuals.add(new Target_Actual__c(
            Target_Criteria__c = criteriaMap.get('Revenue'),
            Target_Period__c = currentPeriod.Id,
            User__c = users[i].Id,
            Target_Value__c = baseTarget,
            Achievement_Value__c = (baseTarget * achPct).setScale(0, RoundingMode.HALF_UP)
        ));
    }

    // Collection target (70% of revenue target)
    if (criteriaMap.containsKey('Collection')) {
        Decimal colTarget = baseTarget * 0.7;
        allActuals.add(new Target_Actual__c(
            Target_Criteria__c = criteriaMap.get('Collection'),
            Target_Period__c = currentPeriod.Id,
            User__c = users[i].Id,
            Target_Value__c = colTarget,
            Achievement_Value__c = (colTarget * (achPct - 0.05)).setScale(0, RoundingMode.HALF_UP)
        ));
    }

    // Focus Brand (20% of revenue, only for TSEs)
    if (criteriaMap.containsKey('Focus Brand') && designations[i] == 'Territory Sales Executive') {
        Decimal fbTarget = baseTarget * 0.2;
        allActuals.add(new Target_Actual__c(
            Target_Criteria__c = criteriaMap.get('Focus Brand'),
            Target_Period__c = currentPeriod.Id,
            User__c = users[i].Id,
            Target_Value__c = fbTarget,
            Achievement_Value__c = (fbTarget * (achPct + 0.05)).setScale(0, RoundingMode.HALF_UP)
        ));
    }

    // Coverage (visits, only for TSEs and ASMs)
    if (criteriaMap.containsKey('Coverage') && (designations[i].contains('Territory') || designations[i].contains('Area'))) {
        Decimal coverageTarget = designations[i].contains('Territory') ? 150 : 50;
        allActuals.add(new Target_Actual__c(
            Target_Criteria__c = criteriaMap.get('Coverage'),
            Target_Period__c = currentPeriod.Id,
            User__c = users[i].Id,
            Target_Value__c = coverageTarget,
            Achievement_Value__c = (coverageTarget * achPct).setScale(0, RoundingMode.HALF_UP)
        ));
    }
}

insert allActuals;

// ═══════════════════════════════════════════════════════════
// 5. SET PARENT TARGETS (TSE → ASM → RSM → NSM)
// ═══════════════════════════════════════════════════════════

// Build lookup: userId+criteriaId → Target_Actual__c
Map<String, Target_Actual__c> actualMap = new Map<String, Target_Actual__c>();
for (Target_Actual__c ta : allActuals) {
    actualMap.put(ta.User__c + '-' + ta.Target_Criteria__c, ta);
}

List<Target_Actual__c> toUpdateParents = new List<Target_Actual__c>();

// TSEs parent → their ASM
for (Integer i = 7; i < 15; i++) {
    Id asmUserId = users[3 + ((i - 7) / 2)].Id;
    for (String criteriaName : criteriaMap.keySet()) {
        String tseKey = users[i].Id + '-' + criteriaMap.get(criteriaName);
        String asmKey = asmUserId + '-' + criteriaMap.get(criteriaName);
        Target_Actual__c tseActual = actualMap.get(tseKey);
        Target_Actual__c asmActual = actualMap.get(asmKey);
        if (tseActual != null && asmActual != null) {
            tseActual.Parent_Target__c = asmActual.Id;
            toUpdateParents.add(tseActual);
        }
    }
}

// ASMs parent → their RSM
for (Integer i = 3; i < 7; i++) {
    Id rsmUserId = (i < 5) ? rsm1Id : rsm2Id;
    for (String criteriaName : criteriaMap.keySet()) {
        String asmKey = users[i].Id + '-' + criteriaMap.get(criteriaName);
        String rsmKey = rsmUserId + '-' + criteriaMap.get(criteriaName);
        Target_Actual__c asmActual = actualMap.get(asmKey);
        Target_Actual__c rsmActual = actualMap.get(rsmKey);
        if (asmActual != null && rsmActual != null) {
            asmActual.Parent_Target__c = rsmActual.Id;
            toUpdateParents.add(asmActual);
        }
    }
}

// RSMs parent → NSM
for (Integer i = 1; i < 3; i++) {
    for (String criteriaName : criteriaMap.keySet()) {
        String rsmKey = users[i].Id + '-' + criteriaMap.get(criteriaName);
        String nsmKey = nsmId + '-' + criteriaMap.get(criteriaName);
        Target_Actual__c rsmActual = actualMap.get(rsmKey);
        Target_Actual__c nsmActual = actualMap.get(nsmKey);
        if (rsmActual != null && nsmActual != null) {
            rsmActual.Parent_Target__c = nsmActual.Id;
            toUpdateParents.add(rsmActual);
        }
    }
}

if (!toUpdateParents.isEmpty()) {
    update toUpdateParents;
}

// ═══════════════════════════════════════════════════════════
// SUMMARY
// ═══════════════════════════════════════════════════════════

System.debug('');
System.debug('════════════════════════════════════════════════════════════');
System.debug('TEST TEAM CREATED SUCCESSFULLY');
System.debug('════════════════════════════════════════════════════════════');
System.debug('');
System.debug('HIERARCHY:');
System.debug('  NSM: ' + users[0].FirstName + ' ' + users[0].LastName + ' (₹' + salaries[0]/1000 + 'K)');
System.debug('  ├── RSM: ' + users[1].FirstName + ' ' + users[1].LastName + ' (₹' + salaries[1]/1000 + 'K)');
System.debug('  │   ├── ASM: ' + users[3].FirstName + ' ' + users[3].LastName + ' (₹' + salaries[3]/1000 + 'K)');
System.debug('  │   │   ├── TSE: ' + users[7].FirstName + ' ' + users[7].LastName + ' (' + (achievementPcts[7]*100).setScale(0, RoundingMode.HALF_UP) + '%)');
System.debug('  │   │   └── TSE: ' + users[8].FirstName + ' ' + users[8].LastName + ' (' + (achievementPcts[8]*100).setScale(0, RoundingMode.HALF_UP) + '%)');
System.debug('  │   └── ASM: ' + users[4].FirstName + ' ' + users[4].LastName + ' (₹' + salaries[4]/1000 + 'K)');
System.debug('  │       ├── TSE: ' + users[9].FirstName + ' ' + users[9].LastName + ' (' + (achievementPcts[9]*100).setScale(0, RoundingMode.HALF_UP) + '%)');
System.debug('  │       └── TSE: ' + users[10].FirstName + ' ' + users[10].LastName + ' (' + (achievementPcts[10]*100).setScale(0, RoundingMode.HALF_UP) + '%)');
System.debug('  └── RSM: ' + users[2].FirstName + ' ' + users[2].LastName + ' (₹' + salaries[2]/1000 + 'K)');
System.debug('      ├── ASM: ' + users[5].FirstName + ' ' + users[5].LastName + ' (₹' + salaries[5]/1000 + 'K)');
System.debug('      │   ├── TSE: ' + users[11].FirstName + ' ' + users[11].LastName + ' (' + (achievementPcts[11]*100).setScale(0, RoundingMode.HALF_UP) + '%)');
System.debug('      │   └── TSE: ' + users[12].FirstName + ' ' + users[12].LastName + ' (' + (achievementPcts[12]*100).setScale(0, RoundingMode.HALF_UP) + '%)');
System.debug('      └── ASM: ' + users[6].FirstName + ' ' + users[6].LastName + ' (₹' + salaries[6]/1000 + 'K)');
System.debug('          ├── TSE: ' + users[13].FirstName + ' ' + users[13].LastName + ' (' + (achievementPcts[13]*100).setScale(0, RoundingMode.HALF_UP) + '%)');
System.debug('          └── TSE: ' + users[14].FirstName + ' ' + users[14].LastName + ' (' + (achievementPcts[14]*100).setScale(0, RoundingMode.HALF_UP) + '%)');
System.debug('');
System.debug('RECORDS CREATED:');
System.debug('  Users: ' + users.size());
System.debug('  Employees: ' + employees.size());
System.debug('  Target Actuals: ' + allActuals.size());
System.debug('  Parent links set: ' + toUpdateParents.size());
System.debug('');
System.debug('NEXT STEPS:');
System.debug('  1. Run 13_incentive_slabs.apex (if not already done)');
System.debug('  2. Go to Incentive Dashboard → Run Calculation');
System.debug('  3. Go to Target Allocation → Select a manager → Distribute');
System.debug('  4. Go to KPI Dashboard → Switch views (Self/Team/Org)');
System.debug('════════════════════════════════════════════════════════════');
