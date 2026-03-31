// Script 16: Journey Plans with Plan Days
// Run: sf apex run -f scripts/16_journey_plans.apex
// Prerequisite: 02_territory_master.apex, 10_beats_and_outlets.apex

// Clean up (MasterDetail child first, then plans)
delete [SELECT Id FROM Journey_Plan_Day__c];
delete [SELECT Id FROM Journey_Plan__c];
System.debug('Cleaned up Journey_Plan__c');

// Fetch territories
Map<String, Id> terMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c FROM Territory_Master__c WHERE Is_Active__c = true]) {
    terMap.put(t.Territory_Code__c, t.Id);
}

// Fetch beats with their day-of-week assignments
Map<String, Beat__c> beatMap = new Map<String, Beat__c>();
for (Beat__c b : [SELECT Id, Beat_Code__c, Day_of_Week__c, Name, Territory__c
                   FROM Beat__c WHERE Is_Active__c = true]) {
    beatMap.put(b.Beat_Code__c, b);
}

// Resolve salesperson: prefer a test user, fall back to running user
Id currentUserId = UserInfo.getUserId();
List<User> testUsers = [SELECT Id FROM User WHERE IsActive = true AND Email LIKE '%@fmcg-test.com' ORDER BY FirstName LIMIT 1];
Id salespersonId = testUsers.isEmpty() ? currentUserId : testUsers[0].Id;

// Determine current month info
Integer currentMonth = Date.today().month();
Integer currentYear = Date.today().year();
String[] monthNames = new String[]{'', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'};
String monthName = monthNames[currentMonth];

// First day and last day of current month
Date firstDay = Date.newInstance(currentYear, currentMonth, 1);
Date lastDay = firstDay.addMonths(1).addDays(-1);

// Create Journey Plans — all as Draft first (trigger blocks day inserts on Approved/Active plans)
// Status will be updated after plan days are inserted
List<Journey_Plan__c> plans = new List<Journey_Plan__c>{
    new Journey_Plan__c(
        Name = 'PJP - Delhi - ' + monthName + ' ' + currentYear,
        Month__c = monthName,
        Year__c = String.valueOf(currentYear),
        Territory__c = terMap.get('TER-DEL-001'),
        Salesperson__c = salespersonId,
        User__c = salespersonId,
        Status__c = 'Draft',
        Plan_Date__c = Date.today(),
        Effective_From__c = firstDay,
        Effective_To__c = lastDay,
        Exclude_Holidays__c = true,
        Exclude_Leaves__c = true,
        Exclude_Week_Offs__c = true
    ),
    new Journey_Plan__c(
        Name = 'PJP - Mumbai - ' + monthName + ' ' + currentYear,
        Month__c = monthName,
        Year__c = String.valueOf(currentYear),
        Territory__c = terMap.get('TER-MUM-001'),
        Salesperson__c = salespersonId,
        User__c = salespersonId,
        Status__c = 'Draft',
        Plan_Date__c = Date.today(),
        Effective_From__c = firstDay,
        Effective_To__c = lastDay,
        Exclude_Holidays__c = true,
        Exclude_Leaves__c = true,
        Exclude_Week_Offs__c = true
    ),
    new Journey_Plan__c(
        Name = 'PJP - Bengaluru - ' + monthName + ' ' + currentYear,
        Month__c = monthName,
        Year__c = String.valueOf(currentYear),
        Territory__c = terMap.get('TER-BLR-001'),
        Salesperson__c = salespersonId,
        User__c = salespersonId,
        Status__c = 'Draft',
        Plan_Date__c = Date.today(),
        Effective_From__c = firstDay,
        Effective_To__c = lastDay,
        Exclude_Holidays__c = true,
        Exclude_Leaves__c = false,
        Exclude_Week_Offs__c = true
    )
};
insert plans;
System.debug('Inserted journey plans (all Draft): ' + plans.size());

// Day of week mapping
Map<String, Integer> dowMap = new Map<String, Integer>{
    'Monday' => 1, 'Tuesday' => 2, 'Wednesday' => 3,
    'Thursday' => 4, 'Friday' => 5, 'Saturday' => 6, 'Sunday' => 0
};

// Generate plan days for Delhi plan (beats BT-DEL-001, BT-DEL-002)
List<Journey_Plan_Day__c> planDays = new List<Journey_Plan_Day__c>();

// Beat-to-plan mapping
Map<String, List<String>> planBeats = new Map<String, List<String>>{
    plans[0].Id => new List<String>{'BT-DEL-001', 'BT-DEL-002'},
    plans[1].Id => new List<String>{'BT-MUM-001', 'BT-MUM-002'},
    plans[2].Id => new List<String>{'BT-BLR-001'}
};

for (Id planId : planBeats.keySet()) {
    List<String> beatCodes = planBeats.get(planId);
    Integer seq = 1;

    for (String beatCode : beatCodes) {
        Beat__c beat = beatMap.get(beatCode);
        if (beat == null) continue;

        // Parse beat days
        Set<String> beatDays = new Set<String>();
        if (beat.Day_of_Week__c != null) {
            for (String d : beat.Day_of_Week__c.split(';')) {
                beatDays.add(d.trim());
            }
        }

        // Iterate through month days
        Date d = firstDay;
        while (d <= lastDay) {
            // Get day of week name
            DateTime dt = DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0));
            String dayName = dt.format('EEEE');

            if (beatDays.contains(dayName)) {
                // Calculate week number
                Integer dayOfMonth = d.day();
                String weekNum = dayOfMonth <= 7 ? 'Week 1' : dayOfMonth <= 14 ? 'Week 2' : dayOfMonth <= 21 ? 'Week 3' : 'Week 4';

                // Count outlets for this beat
                Integer outletCount = [SELECT COUNT() FROM Beat_Outlet__c WHERE Beat__c = :beat.Id AND Is_Active__c = true];

                planDays.add(new Journey_Plan_Day__c(
                    Journey_Plan__c = planId,
                    Beat__c = beat.Id,
                    Beat_Name__c = beat.Name,
                    Plan_Date__c = d,
                    Day_of_Week__c = dayName,
                    Week_Number__c = weekNum,
                    Planned_Outlets__c = outletCount,
                    Visited_Outlets__c = 0,
                    Sequence_Order__c = seq,
                    Sequence__c = seq,
                    Status__c = d < Date.today() ? 'Completed' : 'Planned',
                    Notes__c = beat.Name + ' visit on ' + dayName + ' (' + weekNum + ')'
                ));
                seq++;
            }
            d = d.addDays(1);
        }
    }
}

if (!planDays.isEmpty()) {
    insert planDays;
}

// Update plan totals and set final statuses
// Delhi → Active, Mumbai → Approved, Bengaluru → stays Draft
for (Journey_Plan__c p : plans) {
    Integer totalDays = 0;
    Integer totalVisits = 0;
    for (Journey_Plan_Day__c pd : planDays) {
        if (pd.Journey_Plan__c == p.Id) {
            totalDays++;
            totalVisits += (pd.Planned_Outlets__c != null ? Integer.valueOf(pd.Planned_Outlets__c) : 0);
        }
    }
    p.Total_Planned_Days__c = totalDays;
    p.Total_Planned_Visits__c = totalVisits;
}

// Set final statuses — must follow valid transitions:
// Draft → Submitted → Approved → Active

// Step 1: Delhi + Mumbai → Submitted
plans[0].Status__c = 'Submitted';
plans[1].Status__c = 'Submitted';
update plans;

// Step 2: Delhi + Mumbai → Approved
plans[0].Status__c = 'Approved';
plans[0].Approval_Date__c = Date.today();
plans[0].Approved_By__c = currentUserId;
plans[1].Status__c = 'Approved';
plans[1].Approval_Date__c = Date.today();
plans[1].Approved_By__c = currentUserId;
update new List<Journey_Plan__c>{ plans[0], plans[1] };

// Step 3: Delhi → Active (Mumbai stays Approved, Bengaluru stays Draft)
plans[0].Status__c = 'Active';
update new List<Journey_Plan__c>{ plans[0] };

System.debug('Journey Plans setup complete. Plans: ' + plans.size() + ', Plan Days: ' + planDays.size());
