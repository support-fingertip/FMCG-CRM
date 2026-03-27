// ============================================================
// Seed Script: Target Periods (Monthly for current fiscal year)
// Run via: Execute Anonymous in Developer Console
// ============================================================

// Delete existing periods (optional — uncomment if needed)
// delete [SELECT Id FROM Target_Period__c];

List<Target_Period__c> periods = new List<Target_Period__c>();

Integer currentYear = Date.today().year();
Integer startMonth = 4; // April (Indian fiscal year start)
Integer startYear = Date.today().month() < 4 ? currentYear - 1 : currentYear;

// Create 12 monthly periods for the current fiscal year
List<String> monthNames = new List<String>{
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
};

for (Integer i = 0; i < 12; i++) {
    Integer month = Math.mod(startMonth + i - 1, 12) + 1;
    Integer year = month >= 4 ? startYear : startYear + 1;

    Date periodStart = Date.newInstance(year, month, 1);
    Date periodEnd = periodStart.addMonths(1).addDays(-1);

    Boolean isCurrent = (Date.today() >= periodStart && Date.today() <= periodEnd);

    Target_Period__c p = new Target_Period__c(
        Name = monthNames[month - 1] + ' ' + year,
        Start_Date__c = periodStart,
        End_Date__c = periodEnd,
        Type__c = 'Monthly',
        Is_Active__c = true,
        Is_Default__c = isCurrent
    );
    periods.add(p);
}

// Create quarterly periods
for (Integer q = 0; q < 4; q++) {
    Integer qStartMonth = Math.mod(startMonth + (q * 3) - 1, 12) + 1;
    Integer qYear = qStartMonth >= 4 ? startYear : startYear + 1;

    Date qStart = Date.newInstance(qYear, qStartMonth, 1);
    Date qEnd = qStart.addMonths(3).addDays(-1);

    Target_Period__c p = new Target_Period__c(
        Name = 'Q' + (q + 1) + ' FY' + startYear + '-' + (startYear + 1),
        Start_Date__c = qStart,
        End_Date__c = qEnd,
        Type__c = 'Quarterly',
        Is_Active__c = true,
        Is_Default__c = false
    );
    periods.add(p);
}

insert periods;
System.debug('Created ' + periods.size() + ' Target Periods');
