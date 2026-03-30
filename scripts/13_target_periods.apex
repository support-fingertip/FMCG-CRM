// ============================================================
// Seed Script: Target Periods (Monthly + Quarterly + Annual)
// Includes: Is_Cumulative__c, Parent_Period__c for PBIS support
// Run via: Execute Anonymous in Developer Console
// ============================================================

delete [SELECT Id FROM Target_Period__c];

List<Target_Period__c> periods = new List<Target_Period__c>();

Integer currentYear = Date.today().year();
Integer startMonth = 4; // April (Indian fiscal year start)
Integer startYear = Date.today().month() < 4 ? currentYear - 1 : currentYear;

List<String> monthNames = new List<String>{
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
};

// ── Create Annual Period first ───────────────────────────────
Target_Period__c annualPeriod = new Target_Period__c(
    Name = 'FY ' + startYear + '-' + (startYear + 1),
    Start_Date__c = Date.newInstance(startYear, 4, 1),
    End_Date__c = Date.newInstance(startYear + 1, 3, 31),
    Type__c = 'Yearly',
    Is_Active__c = true,
    Is_Default__c = false,
    Is_Cumulative__c = true
);
insert annualPeriod;
System.debug('Created Annual Period: ' + annualPeriod.Name);

// ── Create Quarterly Periods ─────────────────────────────────
List<Target_Period__c> quarterlyPeriods = new List<Target_Period__c>();
for (Integer q = 0; q < 4; q++) {
    Integer qStartMonth = Math.mod(startMonth + (q * 3) - 1, 12) + 1;
    Integer qYear = qStartMonth >= 4 ? startYear : startYear + 1;

    Date qStart = Date.newInstance(qYear, qStartMonth, 1);
    Date qEnd = qStart.addMonths(3).addDays(-1);

    quarterlyPeriods.add(new Target_Period__c(
        Name = 'Q' + (q + 1) + ' FY' + startYear + '-' + (startYear + 1),
        Start_Date__c = qStart,
        End_Date__c = qEnd,
        Type__c = 'Quarterly',
        Is_Active__c = true,
        Is_Default__c = false,
        Is_Cumulative__c = true,
        Parent_Period__c = annualPeriod.Id
    ));
}
insert quarterlyPeriods;
System.debug('Created ' + quarterlyPeriods.size() + ' Quarterly Periods');

// ── Create Monthly Periods ───────────────────────────────────
List<Target_Period__c> monthlyPeriods = new List<Target_Period__c>();
for (Integer i = 0; i < 12; i++) {
    Integer month = Math.mod(startMonth + i - 1, 12) + 1;
    Integer year = month >= 4 ? startYear : startYear + 1;

    Date periodStart = Date.newInstance(year, month, 1);
    Date periodEnd = periodStart.addMonths(1).addDays(-1);
    Boolean isCurrent = (Date.today() >= periodStart && Date.today() <= periodEnd);

    // Find parent quarter
    Integer quarterIndex = i / 3;
    Id parentQuarterId = quarterlyPeriods[quarterIndex].Id;

    monthlyPeriods.add(new Target_Period__c(
        Name = monthNames[month - 1] + ' ' + year,
        Start_Date__c = periodStart,
        End_Date__c = periodEnd,
        Type__c = 'Monthly',
        Is_Active__c = true,
        Is_Default__c = isCurrent,
        Is_Cumulative__c = false,
        Parent_Period__c = parentQuarterId
    ));
}
insert monthlyPeriods;

System.debug('════════════════════════════════════════════');
System.debug('Created Target Periods:');
System.debug('  1 Annual: ' + annualPeriod.Name);
System.debug('  4 Quarterly (cumulative, parent=Annual)');
System.debug('  12 Monthly (parent=Quarter)');
System.debug('  Total: 17 periods');
System.debug('  Hierarchy: Monthly → Quarterly → Annual');
System.debug('════════════════════════════════════════════');
