/**
 * @description Service class for the Expense Management (EXP) module.
 *              Encapsulates all business logic for expense lifecycle,
 *              eligibility calculation engine, and approval workflow.
 *              Designed to be called from ExpenseController and TriggerHandler layers.
 *
 * @author  SFA Development Team
 * @date    2026
 */
public without sharing class EXP_Expense_Service {

    // ── Feature Codes ───────────────────────────────────────────────────────
    public static final String FEATURE_EXPENSE          = 'EXP-001';
    public static final String FEATURE_AUTO_CALC        = 'EXP-002';
    public static final String FEATURE_FINANCE_APPROVAL = 'EXP-003';

    // ── Config Keys ─────────────────────────────────────────────────────────
    private static final String CFG_ALLOW_FUTURE_DATES    = 'ALLOW_FUTURE_DATES';
    private static final String CFG_MAX_OVERRIDE_PERCENT  = 'MAX_OVERRIDE_PERCENT';
    private static final String CFG_REPORT_LOCK_DAY       = 'REPORT_LOCK_DAY';

    // ── Month Helpers ─────────────────────────────────────────────────────
    private static final Map<String, Integer> MONTH_MAP = new Map<String, Integer>{
        'January' => 1, 'February' => 2, 'March' => 3, 'April' => 4,
        'May' => 5, 'June' => 6, 'July' => 7, 'August' => 8,
        'September' => 9, 'October' => 10, 'November' => 11, 'December' => 12
    };
    private static final List<String> MONTH_NAMES = new List<String>{
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
    };

    // ── Eligibility Cache ─────────────────────────────────────────────────
    private static Map<String, List<Expense_Eligibility__c>> eligibilityCache =
        new Map<String, List<Expense_Eligibility__c>>();

    // ── App Config Cache ──────────────────────────────────────────────────
    private static Map<String, String> configCache;

    // ── Status Transitions ────────────────────────────────────────────────
    private static final Map<String, Set<String>> VALID_TRANSITIONS = new Map<String, Set<String>>{
        'Draft'             => new Set<String>{ 'Submitted' },
        'Submitted'         => new Set<String>{ 'Manager Approved', 'Rejected' },
        'Manager Approved'  => new Set<String>{ 'Finance Approved', 'Rejected' },
        'Rejected'          => new Set<String>{ 'Draft' },
        'Finance Approved'  => new Set<String>{ 'Paid' }
    };

    // ═══════════════════════════════════════════════════════════════════════
    // REPORT LIFECYCLE
    // ═══════════════════════════════════════════════════════════════════════

    public static Expense__c getOrCreateReport(Id userId, String month, Integer year) {
        Employee__c emp = getEmployeeForUser(userId);

        List<Expense__c> existing = [
            SELECT Id, Name, Month__c, Year__c, Status__c, Employee__c, User__c,
                   Period_Start__c, Period_End__c, Working_Days__c, Total_Distance_KM__c,
                   Total_Claimed__c, Total_Approved__c, Total_Eligible__c,
                   Submitted_Date__c, Rejection_Reason__c
            FROM Expense__c
            WHERE Employee__c = :emp.Id AND Month__c = :month AND Year__c = :year
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            return existing[0];
        }

        Integer monthNum = MONTH_MAP.get(month);
        Date periodStart = Date.newInstance(year, monthNum, 1);
        Date periodEnd = periodStart.addMonths(1).addDays(-1);

        // Count working days from attendance
        Integer workingDays = [
            SELECT COUNT()
            FROM Day_Attendance__c
            WHERE Employee__c = :emp.Id
              AND Attendance_Date__c >= :periodStart
              AND Attendance_Date__c <= :periodEnd
        ];

        // Sum GPS distance
        AggregateResult[] distResult = [
            SELECT SUM(Distance_Traveled_Km__c) totalDist
            FROM Day_Attendance__c
            WHERE Employee__c = :emp.Id
              AND Attendance_Date__c >= :periodStart
              AND Attendance_Date__c <= :periodEnd
        ];
        Decimal totalDist = distResult[0].get('totalDist') != null
            ? (Decimal) distResult[0].get('totalDist') : 0;

        Expense__c report = new Expense__c(
            Employee__c = emp.Id,
            User__c = userId,
            Month__c = month,
            Year__c = year,
            Period_Start__c = periodStart,
            Period_End__c = periodEnd,
            Status__c = 'Draft',
            Working_Days__c = workingDays,
            Total_Distance_KM__c = totalDist
        );
        insert report;

        return [
            SELECT Id, Name, Month__c, Year__c, Status__c, Employee__c, User__c,
                   Period_Start__c, Period_End__c, Working_Days__c, Total_Distance_KM__c,
                   Total_Claimed__c, Total_Approved__c, Total_Eligible__c,
                   Submitted_Date__c, Rejection_Reason__c
            FROM Expense__c
            WHERE Id = :report.Id
        ];
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ELIGIBLE DATES
    // ═══════════════════════════════════════════════════════════════════════

    public static List<Map<String, Object>> getEligibleDates(Id userId, String month, Integer year) {
        Employee__c emp = getEmployeeForUser(userId);
        Integer monthNum = MONTH_MAP.get(month);
        Date periodStart = Date.newInstance(year, monthNum, 1);
        Date periodEnd = periodStart.addMonths(1).addDays(-1);

        // Get leave dates
        Set<Date> leaveDates = new Set<Date>();
        for (Leave_Request__c lr : [
            SELECT Start_Date__c, End_Date__c
            FROM Leave_Request__c
            WHERE Employee__c = :emp.Id
              AND Status__c = 'Approved'
              AND Start_Date__c <= :periodEnd
              AND End_Date__c >= :periodStart
        ]) {
            Date d = lr.Start_Date__c < periodStart ? periodStart : lr.Start_Date__c;
            Date endD = lr.End_Date__c > periodEnd ? periodEnd : lr.End_Date__c;
            while (d <= endD) {
                leaveDates.add(d);
                d = d.addDays(1);
            }
        }

        // Get attendance records
        List<Day_Attendance__c> attendances = [
            SELECT Id, Attendance_Date__c, Check_In_Time__c, Check_Out_Time__c,
                   Distance_Traveled_Km__c
            FROM Day_Attendance__c
            WHERE Employee__c = :emp.Id
              AND Attendance_Date__c >= :periodStart
              AND Attendance_Date__c <= :periodEnd
            ORDER BY Attendance_Date__c ASC
        ];

        // Get existing expense item counts per date
        Map<Date, Integer> expenseCountByDate = new Map<Date, Integer>();
        for (AggregateResult ar : [
            SELECT Expense_Date__c dt, COUNT(Id) cnt
            FROM Expense_Item__c
            WHERE Expense__r.Employee__c = :emp.Id
              AND Expense__r.Month__c = :month
              AND Expense__r.Year__c = :year
            GROUP BY Expense_Date__c
        ]) {
            expenseCountByDate.put((Date) ar.get('dt'), (Integer) ar.get('cnt'));
        }

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Day_Attendance__c att : attendances) {
            if (leaveDates.contains(att.Attendance_Date__c)) {
                continue;
            }
            Map<String, Object> dateInfo = new Map<String, Object>();
            dateInfo.put('date', att.Attendance_Date__c);
            dateInfo.put('attendanceId', att.Id);
            dateInfo.put('checkIn', att.Check_In_Time__c);
            dateInfo.put('checkOut', att.Check_Out_Time__c);
            dateInfo.put('gpsDistance', att.Distance_Traveled_Km__c != null ? att.Distance_Traveled_Km__c : 0);
            dateInfo.put('expenseCount', expenseCountByDate.containsKey(att.Attendance_Date__c)
                ? expenseCountByDate.get(att.Attendance_Date__c) : 0);
            result.add(dateInfo);
        }
        return result;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ELIGIBILITY RULES
    // ═══════════════════════════════════════════════════════════════════════

    public static List<Expense_Eligibility__c> getEligibilityRules(String band) {
        if (eligibilityCache.containsKey(band)) {
            return eligibilityCache.get(band);
        }
        List<Expense_Eligibility__c> rules = [
            SELECT Id, Band__c, Expense_Type__c, Expense_Category__c,
                   Rate_Type__c, Rate_Amount__c, Max_Per_Day__c, Max_Per_Month__c,
                   Min_Distance_KM__c, Receipt_Required__c, Receipt_Threshold__c,
                   Is_Active__c, Sort_Order__c, Description__c
            FROM Expense_Eligibility__c
            WHERE Band__c = :band AND Is_Active__c = true
            ORDER BY Sort_Order__c ASC, Expense_Type__c ASC
        ];
        eligibilityCache.put(band, rules);
        return rules;
    }

    public static String getEmployeeBand(Id userId) {
        List<Employee__c> emps = [
            SELECT Band__c FROM Employee__c WHERE User__c = :userId LIMIT 1
        ];
        return emps.isEmpty() ? null : emps[0].Band__c;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ELIGIBILITY CALCULATION ENGINE
    // ═══════════════════════════════════════════════════════════════════════

    public static Decimal calculateEligibleAmount(Expense_Item__c item, Expense_Eligibility__c rule, Integer workingDays) {
        if (rule == null || !rule.Is_Active__c) {
            return 0;
        }

        // Check minimum distance
        Decimal appliedDistance = item.Manual_Distance_KM__c != null
            ? item.Manual_Distance_KM__c
            : (item.GPS_Distance_KM__c != null ? item.GPS_Distance_KM__c : 0);

        if (rule.Min_Distance_KM__c != null && rule.Min_Distance_KM__c > 0
            && appliedDistance < rule.Min_Distance_KM__c) {
            return 0;
        }

        Decimal eligible = 0;
        String rateType = rule.Rate_Type__c;

        if (rateType == 'Per Day') {
            eligible = rule.Rate_Amount__c != null ? rule.Rate_Amount__c : 0;
        } else if (rateType == 'Per KM') {
            eligible = appliedDistance * (rule.Rate_Amount__c != null ? rule.Rate_Amount__c : 0);
        } else if (rateType == 'Flat Monthly') {
            if (workingDays > 0 && rule.Rate_Amount__c != null) {
                eligible = (rule.Rate_Amount__c / workingDays).setScale(2, RoundingMode.HALF_UP);
            }
        } else if (rateType == 'Actual') {
            eligible = item.Claimed_Amount__c != null ? item.Claimed_Amount__c : 0;
        }

        // Apply daily cap
        if (rule.Max_Per_Day__c != null && rule.Max_Per_Day__c > 0 && eligible > rule.Max_Per_Day__c) {
            eligible = rule.Max_Per_Day__c;
        }

        return eligible;
    }

    public static void populateEligibilityFields(List<Expense_Item__c> items, Id expenseId) {
        // Get the expense record for employee band + working days
        Expense__c expense = [
            SELECT Id, Employee__c, Employee__r.Band__c, Working_Days__c
            FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];

        String band = expense.Employee__r.Band__c;
        if (String.isBlank(band)) return;

        Integer workingDays = expense.Working_Days__c != null
            ? (Integer) expense.Working_Days__c : 0;

        List<Expense_Eligibility__c> rules = getEligibilityRules(band);
        Map<String, Expense_Eligibility__c> ruleByType = new Map<String, Expense_Eligibility__c>();
        for (Expense_Eligibility__c rule : rules) {
            ruleByType.put(rule.Expense_Type__c, rule);
        }

        // Get attendance records for GPS distance
        Set<Id> attendanceIds = new Set<Id>();
        Set<Date> expenseDates = new Set<Date>();
        for (Expense_Item__c item : items) {
            if (item.Day_Attendance__c != null) attendanceIds.add(item.Day_Attendance__c);
            if (item.Expense_Date__c != null) expenseDates.add(item.Expense_Date__c);
        }

        Map<Id, Day_Attendance__c> attMap = new Map<Id, Day_Attendance__c>();
        Map<Date, Day_Attendance__c> attByDate = new Map<Date, Day_Attendance__c>();
        if (!attendanceIds.isEmpty() || !expenseDates.isEmpty()) {
            for (Day_Attendance__c att : [
                SELECT Id, Attendance_Date__c, Distance_Traveled_Km__c
                FROM Day_Attendance__c
                WHERE (Id IN :attendanceIds OR Attendance_Date__c IN :expenseDates)
                  AND Employee__c = :expense.Employee__c
            ]) {
                attMap.put(att.Id, att);
                attByDate.put(att.Attendance_Date__c, att);
            }
        }

        // Calculate monthly running totals for cap enforcement
        Map<String, Decimal> monthlyTotals = new Map<String, Decimal>();
        for (AggregateResult ar : [
            SELECT Expense_Type__c typ, SUM(Eligible_Amount__c) total
            FROM Expense_Item__c
            WHERE Expense__c = :expenseId
              AND Id NOT IN :getItemIds(items)
            GROUP BY Expense_Type__c
        ]) {
            monthlyTotals.put((String) ar.get('typ'), (Decimal) ar.get('total'));
        }

        for (Expense_Item__c item : items) {
            Expense_Eligibility__c rule = ruleByType.get(item.Expense_Type__c);

            // Auto-populate GPS distance
            if (item.GPS_Distance_KM__c == null) {
                Day_Attendance__c att = item.Day_Attendance__c != null
                    ? attMap.get(item.Day_Attendance__c)
                    : attByDate.get(item.Expense_Date__c);
                if (att != null && att.Distance_Traveled_Km__c != null) {
                    item.GPS_Distance_KM__c = att.Distance_Traveled_Km__c;
                }
            }

            if (rule != null) {
                item.Rate_Type__c = rule.Rate_Type__c;
                item.Rate_Amount__c = rule.Rate_Amount__c;
                item.Expense_Category__c = rule.Expense_Category__c;
                item.Receipt_Required__c = rule.Receipt_Required__c;
                item.Is_Eligible__c = true;

                Decimal eligible = calculateEligibleAmount(item, rule, workingDays);

                // Enforce monthly cap
                if (rule.Max_Per_Month__c != null && rule.Max_Per_Month__c > 0) {
                    Decimal alreadyUsed = monthlyTotals.containsKey(item.Expense_Type__c)
                        ? monthlyTotals.get(item.Expense_Type__c) : 0;
                    Decimal remaining = rule.Max_Per_Month__c - alreadyUsed;
                    if (remaining < 0) remaining = 0;
                    if (eligible > remaining) {
                        eligible = remaining;
                    }
                    monthlyTotals.put(item.Expense_Type__c, alreadyUsed + eligible);
                }

                item.Eligible_Amount__c = eligible;

                // Check min distance eligibility
                Decimal appliedDist = item.Manual_Distance_KM__c != null
                    ? item.Manual_Distance_KM__c
                    : (item.GPS_Distance_KM__c != null ? item.GPS_Distance_KM__c : 0);
                if (rule.Min_Distance_KM__c != null && rule.Min_Distance_KM__c > 0
                    && appliedDist < rule.Min_Distance_KM__c) {
                    item.Is_Eligible__c = false;
                    item.Eligible_Amount__c = 0;
                }
            } else {
                item.Is_Eligible__c = false;
                item.Eligible_Amount__c = 0;
            }
        }
    }

    private static Set<Id> getItemIds(List<Expense_Item__c> items) {
        Set<Id> ids = new Set<Id>();
        for (Expense_Item__c item : items) {
            if (item.Id != null) ids.add(item.Id);
        }
        return ids;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // EXPENSE ITEM CRUD
    // ═══════════════════════════════════════════════════════════════════════

    public static List<Expense_Item__c> getExpenseItemsForDate(Id expenseId, Date expenseDate) {
        return [
            SELECT Id, Expense__c, Day_Attendance__c, Expense_Date__c,
                   Expense_Type__c, Expense_Category__c, GPS_Distance_KM__c,
                   Manual_Distance_KM__c, Distance_Override_Reason__c,
                   Applied_Distance_KM__c, Eligible_Amount__c, Claimed_Amount__c,
                   Approved_Amount__c, Receipt_URL__c, Receipt_Required__c,
                   Has_Receipt__c, Notes__c, Rate_Type__c, Rate_Amount__c, Is_Eligible__c
            FROM Expense_Item__c
            WHERE Expense__c = :expenseId AND Expense_Date__c = :expenseDate
            ORDER BY Expense_Type__c ASC
        ];
    }

    public static List<Expense_Item__c> saveExpenseItems(Id expenseId, List<Expense_Item__c> items) {
        // Validate expense is editable
        Expense__c expense = [
            SELECT Id, Status__c FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];
        if (expense.Status__c != 'Draft' && expense.Status__c != 'Rejected') {
            throw new AuraHandledException('Expense must be in Draft or Rejected status to edit items.');
        }

        // Validate distance override
        Integer maxOverridePercent = getConfigInteger(CFG_MAX_OVERRIDE_PERCENT, 150);

        for (Expense_Item__c item : items) {
            item.Expense__c = expenseId;

            // Validate distance override
            if (item.Manual_Distance_KM__c != null && item.GPS_Distance_KM__c != null
                && item.GPS_Distance_KM__c > 0) {
                Decimal maxAllowed = item.GPS_Distance_KM__c * maxOverridePercent / 100;
                if (item.Manual_Distance_KM__c > maxAllowed) {
                    throw new AuraHandledException(
                        'Manual distance cannot exceed ' + maxOverridePercent + '% of GPS distance.'
                    );
                }
                if (item.Manual_Distance_KM__c != item.GPS_Distance_KM__c
                    && String.isBlank(item.Distance_Override_Reason__c)) {
                    throw new AuraHandledException(
                        'Override reason is required when manual distance differs from GPS.'
                    );
                }
            }

            // Validate claimed amount
            if (item.Claimed_Amount__c != null && item.Eligible_Amount__c != null
                && item.Claimed_Amount__c > item.Eligible_Amount__c
                && item.Rate_Type__c != 'Actual') {
                throw new AuraHandledException(
                    'Claimed amount cannot exceed eligible amount for ' + item.Expense_Type__c + '.'
                );
            }
        }

        upsert items;

        Date itemDate = items[0].Expense_Date__c;
        return getExpenseItemsForDate(expenseId, itemDate);
    }

    public static void deleteExpenseItems(List<Id> itemIds) {
        List<Expense_Item__c> items = [
            SELECT Id, Expense__r.Status__c
            FROM Expense_Item__c
            WHERE Id IN :itemIds
        ];
        if (!items.isEmpty() && items[0].Expense__r.Status__c != 'Draft'
            && items[0].Expense__r.Status__c != 'Rejected') {
            throw new AuraHandledException('Cannot delete items from a non-Draft expense.');
        }
        delete items;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // APPROVAL WORKFLOW
    // ═══════════════════════════════════════════════════════════════════════

    public static Expense__c submitReport(Id expenseId) {
        Expense__c expense = [
            SELECT Id, Status__c, Employee__c
            FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];

        if (expense.Status__c != 'Draft' && expense.Status__c != 'Rejected') {
            throw new AuraHandledException('Only Draft or Rejected expenses can be submitted.');
        }

        // Validate receipt requirements
        List<Expense_Item__c> items = [
            SELECT Id, Expense_Type__c, Receipt_Required__c, Receipt_URL__c, Claimed_Amount__c
            FROM Expense_Item__c
            WHERE Expense__c = :expenseId AND Receipt_Required__c = true
        ];

        // Check receipt threshold from eligibility rules
        Employee__c emp = [SELECT User__c FROM Employee__c WHERE Id = :expense.Employee__c LIMIT 1];
        String band = getEmployeeBand(emp.User__c);
        Map<String, Expense_Eligibility__c> ruleMap = new Map<String, Expense_Eligibility__c>();
        if (String.isNotBlank(band)) {
            for (Expense_Eligibility__c rule : getEligibilityRules(band)) {
                ruleMap.put(rule.Expense_Type__c, rule);
            }
        }

        for (Expense_Item__c item : items) {
            if (String.isBlank(item.Receipt_URL__c)) {
                Expense_Eligibility__c rule = ruleMap.get(item.Expense_Type__c);
                Decimal threshold = (rule != null && rule.Receipt_Threshold__c != null)
                    ? rule.Receipt_Threshold__c : 0;
                if (threshold == 0 || (item.Claimed_Amount__c != null && item.Claimed_Amount__c > threshold)) {
                    throw new AuraHandledException(
                        'Receipt is required for ' + item.Expense_Type__c + '.'
                    );
                }
            }
        }

        expense.Status__c = 'Submitted';
        expense.Submitted_Date__c = Datetime.now();
        expense.Rejection_Reason__c = null;
        update expense;

        return [
            SELECT Id, Name, Status__c, Month__c, Year__c, Total_Claimed__c,
                   Total_Approved__c, Total_Eligible__c, Submitted_Date__c
            FROM Expense__c WHERE Id = :expenseId
        ];
    }

    public static Expense__c approveReport(Id expenseId, String remarks, String level) {
        Expense__c expense = [
            SELECT Id, Status__c FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];

        if (level == 'manager') {
            if (expense.Status__c != 'Submitted') {
                throw new AuraHandledException('Only Submitted expenses can be manager-approved.');
            }
            expense.Status__c = 'Manager Approved';
            expense.Manager_Approved_Date__c = Datetime.now();
            expense.Manager_Approver__c = UserInfo.getUserId();
            expense.Manager_Remarks__c = remarks;

            // Auto-set approved amounts = claimed amounts
            List<Expense_Item__c> items = [
                SELECT Id, Claimed_Amount__c, Approved_Amount__c
                FROM Expense_Item__c WHERE Expense__c = :expenseId
            ];
            for (Expense_Item__c item : items) {
                item.Approved_Amount__c = item.Claimed_Amount__c;
            }
            if (!items.isEmpty()) update items;

        } else if (level == 'finance') {
            if (expense.Status__c != 'Manager Approved') {
                throw new AuraHandledException('Only Manager Approved expenses can be finance-approved.');
            }
            expense.Status__c = 'Finance Approved';
            expense.Finance_Approved_Date__c = Datetime.now();
            expense.Finance_Approver__c = UserInfo.getUserId();
            expense.Finance_Remarks__c = remarks;
        }

        update expense;
        return [
            SELECT Id, Name, Status__c, Total_Claimed__c, Total_Approved__c, Total_Eligible__c
            FROM Expense__c WHERE Id = :expenseId
        ];
    }

    public static Expense__c rejectReport(Id expenseId, String reason, String level) {
        Expense__c expense = [
            SELECT Id, Status__c FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];

        if (expense.Status__c != 'Submitted' && expense.Status__c != 'Manager Approved') {
            throw new AuraHandledException('Only Submitted or Manager Approved expenses can be rejected.');
        }

        expense.Status__c = 'Rejected';
        expense.Rejection_Reason__c = reason;
        if (level == 'manager') {
            expense.Manager_Remarks__c = reason;
        } else if (level == 'finance') {
            expense.Finance_Remarks__c = reason;
        }
        update expense;

        return [
            SELECT Id, Name, Status__c, Rejection_Reason__c
            FROM Expense__c WHERE Id = :expenseId
        ];
    }

    public static Expense__c markAsPaid(Id expenseId) {
        Expense__c expense = [
            SELECT Id, Status__c FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];
        if (expense.Status__c != 'Finance Approved') {
            throw new AuraHandledException('Only Finance Approved expenses can be marked as Paid.');
        }
        expense.Status__c = 'Paid';
        update expense;
        return [
            SELECT Id, Name, Status__c FROM Expense__c WHERE Id = :expenseId
        ];
    }

    // ═══════════════════════════════════════════════════════════════════════
    // REPORTING
    // ═══════════════════════════════════════════════════════════════════════

    public static Map<String, Object> getReportSummary(Id expenseId) {
        Expense__c expense = [
            SELECT Id, Name, Month__c, Year__c, Status__c, Employee__c,
                   Employee__r.First_Name__c, Employee__r.Last_Name__c,
                   Employee__r.Band__c, Working_Days__c, Total_Distance_KM__c,
                   Total_Claimed__c, Total_Approved__c, Total_Eligible__c,
                   Submitted_Date__c, Manager_Approved_Date__c, Manager_Remarks__c,
                   Finance_Approved_Date__c, Finance_Remarks__c, Rejection_Reason__c
            FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];

        Map<String, Object> summary = new Map<String, Object>();
        summary.put('expense', expense);

        // Type-wise totals
        List<AggregateResult> typeTotals = [
            SELECT Expense_Type__c typ,
                   SUM(Eligible_Amount__c) eligible,
                   SUM(Claimed_Amount__c) claimed,
                   SUM(Approved_Amount__c) approved,
                   COUNT(Id) cnt
            FROM Expense_Item__c
            WHERE Expense__c = :expenseId
            GROUP BY Expense_Type__c
            ORDER BY Expense_Type__c
        ];

        List<Map<String, Object>> typeBreakdown = new List<Map<String, Object>>();
        for (AggregateResult ar : typeTotals) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('type', ar.get('typ'));
            row.put('eligible', ar.get('eligible'));
            row.put('claimed', ar.get('claimed'));
            row.put('approved', ar.get('approved'));
            row.put('count', ar.get('cnt'));
            typeBreakdown.add(row);
        }
        summary.put('typeBreakdown', typeBreakdown);

        // Day-wise totals
        List<AggregateResult> dayTotals = [
            SELECT Expense_Date__c dt,
                   SUM(Eligible_Amount__c) eligible,
                   SUM(Claimed_Amount__c) claimed,
                   COUNT(Id) cnt
            FROM Expense_Item__c
            WHERE Expense__c = :expenseId
            GROUP BY Expense_Date__c
            ORDER BY Expense_Date__c
        ];

        List<Map<String, Object>> dayBreakdown = new List<Map<String, Object>>();
        for (AggregateResult ar : dayTotals) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('date', ar.get('dt'));
            row.put('eligible', ar.get('eligible'));
            row.put('claimed', ar.get('claimed'));
            row.put('count', ar.get('cnt'));
            dayBreakdown.add(row);
        }
        summary.put('dayBreakdown', dayBreakdown);

        return summary;
    }

    public static List<Map<String, Object>> getMonthlyOverview(Id userId, Integer year) {
        Employee__c emp = getEmployeeForUser(userId);

        Map<String, Expense__c> reportsByMonth = new Map<String, Expense__c>();
        for (Expense__c r : [
            SELECT Id, Name, Month__c, Year__c, Status__c,
                   Total_Claimed__c, Total_Approved__c, Total_Eligible__c,
                   Working_Days__c, Total_Distance_KM__c
            FROM Expense__c
            WHERE Employee__c = :emp.Id AND Year__c = :year
            ORDER BY Period_Start__c ASC
        ]) {
            reportsByMonth.put(r.Month__c, r);
        }

        List<Map<String, Object>> overview = new List<Map<String, Object>>();
        for (Integer i = 1; i <= 12; i++) {
            String monthName = MONTH_NAMES[i];
            Map<String, Object> row = new Map<String, Object>();
            row.put('month', monthName);
            row.put('monthNumber', i);

            if (reportsByMonth.containsKey(monthName)) {
                Expense__c r = reportsByMonth.get(monthName);
                row.put('expenseId', r.Id);
                row.put('expenseName', r.Name);
                row.put('status', r.Status__c);
                row.put('totalClaimed', r.Total_Claimed__c);
                row.put('totalApproved', r.Total_Approved__c);
                row.put('totalEligible', r.Total_Eligible__c);
                row.put('workingDays', r.Working_Days__c);
                row.put('hasReport', true);
            } else {
                row.put('hasReport', false);
                row.put('status', null);
                row.put('totalClaimed', 0);
                row.put('totalApproved', 0);
                row.put('totalEligible', 0);
            }
            overview.add(row);
        }
        return overview;
    }

    public static List<Expense__c> getTeamExpenseReports(Id managerId, String month, Integer year) {
        Employee__c mgr = getEmployeeForUser(managerId);
        List<Id> directReportIds = new List<Id>();
        for (Employee__c emp : [
            SELECT Id FROM Employee__c WHERE Reporting_Manager__c = :mgr.Id AND Is_Active__c = true
        ]) {
            directReportIds.add(emp.Id);
        }

        if (directReportIds.isEmpty()) return new List<Expense__c>();

        return [
            SELECT Id, Name, Month__c, Year__c, Status__c, Employee__c,
                   Employee__r.First_Name__c, Employee__r.Last_Name__c,
                   Employee__r.Band__c, Total_Claimed__c, Total_Approved__c,
                   Total_Eligible__c, Working_Days__c, Submitted_Date__c
            FROM Expense__c
            WHERE Employee__c IN :directReportIds
              AND Month__c = :month AND Year__c = :year
            ORDER BY Employee__r.First_Name__c ASC
        ];
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STATUS VALIDATION
    // ═══════════════════════════════════════════════════════════════════════

    public static Boolean isValidTransition(String fromStatus, String toStatus) {
        if (VALID_TRANSITIONS.containsKey(fromStatus)) {
            return VALID_TRANSITIONS.get(fromStatus).contains(toStatus);
        }
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // CONFIG HELPERS
    // ═══════════════════════════════════════════════════════════════════════

    public static String getAppConfig(String configKey, String defaultValue) {
        if (configCache == null) {
            configCache = new Map<String, String>();
            for (App_Config__mdt cfg : [
                SELECT Config_Key__c, Config_Value__c FROM App_Config__mdt
                WHERE Module__c = 'EXP'
            ]) {
                configCache.put(cfg.Config_Key__c, cfg.Config_Value__c);
            }
        }
        return configCache.containsKey(configKey) ? configCache.get(configKey) : defaultValue;
    }

    public static Boolean getConfigBoolean(String configKey, Boolean defaultValue) {
        String val = getAppConfig(configKey, String.valueOf(defaultValue));
        return val != null && val.equalsIgnoreCase('true');
    }

    public static Integer getConfigInteger(String configKey, Integer defaultValue) {
        String val = getAppConfig(configKey, String.valueOf(defaultValue));
        try {
            return Integer.valueOf(val);
        } catch (Exception e) {
            return defaultValue;
        }
    }

    @TestVisible
    private static void clearCache() {
        eligibilityCache.clear();
        configCache = null;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // PRIVATE HELPERS
    // ═══════════════════════════════════════════════════════════════════════

    private static Employee__c getEmployeeForUser(Id userId) {
        List<Employee__c> emps = [
            SELECT Id, Band__c, User__c, Reporting_Manager__c
            FROM Employee__c
            WHERE User__c = :userId AND Is_Active__c = true
            LIMIT 1
        ];
        if (emps.isEmpty()) {
            throw new AuraHandledException('No active employee record found for the current user.');
        }
        return emps[0];
    }
}
