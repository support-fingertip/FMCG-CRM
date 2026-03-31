// ============================================================
// Seed Script: Leave Policies + Initialize Balances
// Prerequisites: Employees must exist
// Run via: Execute Anonymous in Developer Console
// ============================================================

delete [SELECT Id FROM Leave_Balance__c];
delete [SELECT Id FROM Leave_Policy__c];

List<Leave_Policy__c> policies = new List<Leave_Policy__c>();

// ── Universal Policies (all designations) ────────────────
policies.add(new Leave_Policy__c(
    Name = 'CL — All Staff', Leave_Type__c = 'Casual Leave',
    Annual_Entitlement__c = 12, Monthly_Accrual__c = 0,
    Max_Carry_Forward__c = 0, Is_Active__c = true,
    Encashable__c = false
));

policies.add(new Leave_Policy__c(
    Name = 'SL — All Staff', Leave_Type__c = 'Sick Leave',
    Annual_Entitlement__c = 7, Monthly_Accrual__c = 0,
    Max_Carry_Forward__c = 0, Is_Active__c = true,
    Encashable__c = false
));

policies.add(new Leave_Policy__c(
    Name = 'EL — All Staff', Leave_Type__c = 'Earned Leave',
    Annual_Entitlement__c = 15, Monthly_Accrual__c = 1.25,
    Max_Carry_Forward__c = 30, Is_Active__c = true,
    Encashable__c = true
));

policies.add(new Leave_Policy__c(
    Name = 'CO — All Staff', Leave_Type__c = 'Compensatory Off',
    Annual_Entitlement__c = 0, Monthly_Accrual__c = 0,
    Max_Carry_Forward__c = 0, Is_Active__c = true,
    Encashable__c = false
));

// ── Manager-specific overrides ───────────────────────────
policies.add(new Leave_Policy__c(
    Name = 'CL — Managers', Leave_Type__c = 'Casual Leave',
    Designation__c = 'Area Sales Manager',
    Annual_Entitlement__c = 15, Monthly_Accrual__c = 0,
    Max_Carry_Forward__c = 0, Is_Active__c = true
));

policies.add(new Leave_Policy__c(
    Name = 'CL — RSM+', Leave_Type__c = 'Casual Leave',
    Designation__c = 'Regional Sales Manager',
    Annual_Entitlement__c = 18, Monthly_Accrual__c = 0,
    Max_Carry_Forward__c = 3, Is_Active__c = true
));

policies.add(new Leave_Policy__c(
    Name = 'EL — RSM+', Leave_Type__c = 'Earned Leave',
    Designation__c = 'Regional Sales Manager',
    Annual_Entitlement__c = 21, Monthly_Accrual__c = 1.75,
    Max_Carry_Forward__c = 45, Is_Active__c = true,
    Encashable__c = true
));

insert policies;
System.debug('Created ' + policies.size() + ' Leave Policies');

// ── Initialize balances for current fiscal year ──────────
String currentYear = LeaveBalanceService.getCurrentFiscalYear();
LeaveBalanceService.initializeYearlyBalances(currentYear);

// Run accrual for months already passed in the fiscal year
Integer currentMonth = Date.today().month();
Integer fiscalMonthsPassed = currentMonth >= 4 ? currentMonth - 3 : currentMonth + 9;

for (Integer m = 0; m < fiscalMonthsPassed; m++) {
    LeaveBalanceService.runMonthlyAccrual(currentYear);
}

System.debug('');
System.debug('════════════════════════════════════════════');
System.debug('Leave Policies: ' + policies.size());
System.debug('Fiscal Year: ' + currentYear);
System.debug('Months accrued: ' + fiscalMonthsPassed);
System.debug('Balances created: ' + [SELECT COUNT() FROM Leave_Balance__c WHERE Year__c = :currentYear]);
System.debug('');
System.debug('Sample balances:');
for (Leave_Balance__c lb : [
    SELECT Employee__r.First_Name__c, Employee__r.Last_Name__c,
           Leave_Type__c, Entitled__c, Accrued__c, Carry_Forward__c, Used__c, Pending__c
    FROM Leave_Balance__c WHERE Year__c = :currentYear
    ORDER BY Employee__r.Last_Name__c, Leave_Type__c LIMIT 20
]) {
    System.debug('  ' + lb.Employee__r.First_Name__c + ' ' + lb.Employee__r.Last_Name__c +
        ' | ' + lb.Leave_Type__c + ' | Entitled: ' + lb.Entitled__c +
        ' | Accrued: ' + lb.Accrued__c + ' | Available: ' + (lb.Accrued__c + lb.Carry_Forward__c - lb.Used__c - lb.Pending__c));
}
System.debug('════════════════════════════════════════════');
