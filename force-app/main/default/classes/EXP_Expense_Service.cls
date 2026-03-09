/**
 * @description Service class for the Expense Management (EXP) module.
 *              Full-fledged dynamic expense management with:
 *              - Configuration-driven expense types per band/travel type
 *              - Auto-calculation of DA (working hours) and TA (distance × rate)
 *              - Per-line-item approval status tracking
 *              - Travel-mode-specific TA rates (Bike/Car/Auto/Flight/etc.)
 *              - City-based lodging limits (Metro/Non-Metro)
 *              - Configurable receipt & remarks requirements
 *              - File attachment validation before submit
 *              - Comments history with timestamps
 *              - Multi-level approval workflow (L1/L2/Finance)
 *              - Back-dated entry control
 *              Designed as a reusable base for any FMCG project.
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
    private static final String CFG_BACK_DATE_LIMIT_DAYS  = 'BACK_DATE_LIMIT_DAYS';

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

    // ── DA Working Hour Thresholds ────────────────────────────────────────
    private static final Decimal DA_MIN_HOURS      = 4;   // Below = no DA
    private static final Decimal DA_HALF_DAY_HOURS = 8;   // 4-8 = half DA, >8 = full DA

    // ═══════════════════════════════════════════════════════════════════════
    // SINGLE BULK API — Returns all data needed by the LWC in one call
    // ═══════════════════════════════════════════════════════════════════════

    public static Map<String, Object> getExpenseData(Id userId, String month, Integer year) {
        Map<String, Object> result = new Map<String, Object>();

        Employee__c emp = getEmployeeForUser(userId);
        result.put('employee', emp);
        result.put('band', emp.Band__c);

        // Get or create report
        Expense__c report = getOrCreateReport(userId, month, year);
        result.put('expense', report);

        // Eligibility rules for this band
        List<Expense_Eligibility__c> rules = new List<Expense_Eligibility__c>();
        if (String.isNotBlank(emp.Band__c)) {
            rules = getEligibilityRules(emp.Band__c);
        }
        result.put('eligibilityRules', rules);

        // Eligible dates (attendance records minus leaves)
        List<Map<String, Object>> eligibleDates = getEligibleDates(userId, month, year);
        result.put('eligibleDates', eligibleDates);

        // All existing expense items for this report
        List<Expense_Item__c> items = new List<Expense_Item__c>();
        if (report.Id != null) {
            items = getAllExpenseItemsForReport(report.Id);
        }
        result.put('expenseItems', items);

        // File attachments for all items
        List<Id> itemIds = new List<Id>();
        for (Expense_Item__c item : items) {
            itemIds.add(item.Id);
        }
        List<Map<String, Object>> files = getExpenseItemFiles(itemIds);
        result.put('files', files);

        // Config
        Map<String, Object> config = new Map<String, Object>();
        config.put('maxOverridePercent', getConfigInteger(CFG_MAX_OVERRIDE_PERCENT, 150));
        config.put('reportLockDay', getConfigInteger(CFG_REPORT_LOCK_DAY, 5));
        config.put('allowFutureDates', getConfigBoolean(CFG_ALLOW_FUTURE_DATES, false));
        config.put('backDateLimitDays', getConfigInteger(CFG_BACK_DATE_LIMIT_DAYS, 60));
        result.put('config', config);

        return result;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // REPORT LIFECYCLE
    // ═══════════════════════════════════════════════════════════════════════

    public static Expense__c getOrCreateReport(Id userId, String month, Integer year) {
        Employee__c emp = getEmployeeForUser(userId);

        List<Expense__c> existing = [
            SELECT Id, Name, Month__c, Year__c, Status__c, Employee__c, User__c,
                   Period_Start__c, Period_End__c, Working_Days__c, Total_Distance_KM__c,
                   Total_Claimed__c, Total_Approved__c, Total_Eligible__c,
                   Submitted_Date__c, Rejection_Reason__c, Comments_History__c
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
            WHERE User__c = :emp.User__c
              AND Attendance_Date__c >= :periodStart
              AND Attendance_Date__c <= :periodEnd
        ];

        // Sum GPS distance
        AggregateResult[] distResult = [
            SELECT SUM(Distance_Traveled_Km__c) totalDist
            FROM Day_Attendance__c
            WHERE User__c = :emp.User__c
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
                   Submitted_Date__c, Rejection_Reason__c, Comments_History__c
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

        // Get attendance records with hours worked
        List<Day_Attendance__c> attendances = [
            SELECT Id, Attendance_Date__c, Start_Time__c, End_Time__c,
                   Distance_Traveled_Km__c, Hours_Worked__c, Beat__r.Name,
                   Status__c
            FROM Day_Attendance__c
            WHERE User__c = :emp.User__c
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
            dateInfo.put('checkIn', att.Start_Time__c);
            dateInfo.put('checkOut', att.End_Time__c);
            dateInfo.put('gpsDistance', att.Distance_Traveled_Km__c != null ? att.Distance_Traveled_Km__c : 0);
            dateInfo.put('hoursWorked', att.Hours_Worked__c != null ? att.Hours_Worked__c : 0);
            dateInfo.put('beatName', att.Beat__r != null ? att.Beat__r.Name : '');
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
                   Is_Active__c, Sort_Order__c, Description__c,
                   Auto_Create__c, Travel_Type__c, Mandatory_Remarks__c,
                   Daily_KM_Limit__c,
                   Lodging_Metro_Limit__c, Lodging_Non_Metro_Limit__c,
                   Travel_Mode__c
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
        Decimal appliedDistance = getAppliedDistance(item);

        if (rule.Min_Distance_KM__c != null && rule.Min_Distance_KM__c > 0
            && appliedDistance < rule.Min_Distance_KM__c) {
            return 0;
        }

        Decimal eligible = 0;
        String rateType = rule.Rate_Type__c;

        if (rateType == 'Per Day') {
            // DA calculation with working hours logic
            eligible = calculateDAAmount(item, rule);
        } else if (rateType == 'Per KM') {
            // TA calculation with vehicle-type-specific rates
            eligible = calculateTAAmount(item, rule);
        } else if (rateType == 'Flat Monthly') {
            if (workingDays > 0 && rule.Rate_Amount__c != null) {
                eligible = (rule.Rate_Amount__c / workingDays).setScale(2, RoundingMode.HALF_UP);
            }
        } else if (rateType == 'Actual') {
            eligible = item.Claimed_Amount__c != null ? item.Claimed_Amount__c : 0;
            // For lodging with city-based limits
            if (rule.Lodging_Metro_Limit__c != null || rule.Lodging_Non_Metro_Limit__c != null) {
                Decimal limit_val = getLodgingLimit(item, rule);
                if (limit_val > 0 && eligible > limit_val) {
                    eligible = limit_val;
                }
            }
        }

        // Apply daily cap
        if (rule.Max_Per_Day__c != null && rule.Max_Per_Day__c > 0 && eligible > rule.Max_Per_Day__c) {
            eligible = rule.Max_Per_Day__c;
        }

        return eligible;
    }

    private static Decimal calculateDAAmount(Expense_Item__c item, Expense_Eligibility__c rule) {
        Decimal fullRate = rule.Rate_Amount__c != null ? rule.Rate_Amount__c : 0;
        Decimal halfRate = fullRate / 2;

        // If working hours available, apply DA logic
        Decimal hours = item.Working_Hours__c != null ? item.Working_Hours__c : 0;
        if (hours > 0) {
            if (hours < DA_MIN_HOURS) {
                return 0; // Less than 4 hours = no DA
            } else if (hours <= DA_HALF_DAY_HOURS) {
                return halfRate; // 4-8 hours = half DA
            }
        }
        // > 8 hours or no hours data = full DA
        return fullRate;
    }

    private static Decimal calculateTAAmount(Expense_Item__c item, Expense_Eligibility__c rule) {
        Decimal appliedDistance = getAppliedDistance(item);

        // Apply daily KM limit
        if (rule.Daily_KM_Limit__c != null && rule.Daily_KM_Limit__c > 0
            && appliedDistance > rule.Daily_KM_Limit__c) {
            appliedDistance = rule.Daily_KM_Limit__c;
        }

        // Rate comes from the matched travel-mode-specific rule
        Decimal rate = rule.Rate_Amount__c != null ? rule.Rate_Amount__c : 0;

        return appliedDistance * rate;
    }

    private static Decimal getLodgingLimit(Expense_Item__c item, Expense_Eligibility__c rule) {
        if (item.Is_Metro__c == true && rule.Lodging_Metro_Limit__c != null) {
            return rule.Lodging_Metro_Limit__c;
        }
        if (rule.Lodging_Non_Metro_Limit__c != null) {
            return rule.Lodging_Non_Metro_Limit__c;
        }
        return 0;
    }

    private static Decimal getAppliedDistance(Expense_Item__c item) {
        return item.Manual_Distance_KM__c != null
            ? item.Manual_Distance_KM__c
            : (item.GPS_Distance_KM__c != null ? item.GPS_Distance_KM__c : 0);
    }

    private static Expense_Eligibility__c findRule(
        Map<String, Expense_Eligibility__c> ruleMap,
        String expType, String travelMode) {
        String tm = String.isNotBlank(travelMode) ? travelMode : 'All';
        Expense_Eligibility__c rule = ruleMap.get(expType + '|' + tm);
        if (rule != null) return rule;
        return ruleMap.get(expType + '|All');
    }

    public static void populateEligibilityFields(List<Expense_Item__c> items, Id expenseId) {
        Expense__c expense = [
            SELECT Id, Employee__c, Employee__r.Band__c, Working_Days__c, User__c
            FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];

        String band = expense.Employee__r.Band__c;
        if (String.isBlank(band)) return;

        Integer workingDays = expense.Working_Days__c != null
            ? (Integer) expense.Working_Days__c : 0;

        List<Expense_Eligibility__c> rules = getEligibilityRules(band);
        Map<String, Expense_Eligibility__c> ruleMap = new Map<String, Expense_Eligibility__c>();
        for (Expense_Eligibility__c rule : rules) {
            String tm = rule.Travel_Mode__c != null ? rule.Travel_Mode__c : 'All';
            ruleMap.put(rule.Expense_Type__c + '|' + tm, rule);
        }

        // Get attendance records for GPS distance and working hours
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
                SELECT Id, Attendance_Date__c, Distance_Traveled_Km__c, Hours_Worked__c
                FROM Day_Attendance__c
                WHERE (Id IN :attendanceIds OR Attendance_Date__c IN :expenseDates)
                  AND User__c = :expense.User__c
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
            Expense_Eligibility__c rule = findRule(ruleMap, item.Expense_Type__c, item.Travel_Mode__c);

            // Auto-populate GPS distance and working hours from attendance
            Day_Attendance__c att = item.Day_Attendance__c != null
                ? attMap.get(item.Day_Attendance__c)
                : attByDate.get(item.Expense_Date__c);

            if (item.GPS_Distance_KM__c == null && att != null && att.Distance_Traveled_Km__c != null) {
                item.GPS_Distance_KM__c = att.Distance_Traveled_Km__c;
            }
            if (item.Working_Hours__c == null && att != null && att.Hours_Worked__c != null) {
                item.Working_Hours__c = att.Hours_Worked__c;
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
                item.System_Calculated_Amount__c = eligible;

                // Check min distance eligibility
                Decimal appliedDist = getAppliedDistance(item);
                if (rule.Min_Distance_KM__c != null && rule.Min_Distance_KM__c > 0
                    && appliedDist < rule.Min_Distance_KM__c) {
                    item.Is_Eligible__c = false;
                    item.Eligible_Amount__c = 0;
                }
            } else {
                item.Is_Eligible__c = false;
                item.Eligible_Amount__c = 0;
                item.System_Calculated_Amount__c = 0;
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

    private static final String ITEM_FIELDS_QUERY =
        'Id, Expense__c, Day_Attendance__c, Expense_Date__c, ' +
        'Expense_Type__c, Expense_Category__c, GPS_Distance_KM__c, ' +
        'Manual_Distance_KM__c, Distance_Override_Reason__c, ' +
        'Applied_Distance_KM__c, Eligible_Amount__c, Claimed_Amount__c, ' +
        'Approved_Amount__c, Receipt_URL__c, Receipt_Required__c, ' +
        'Has_Receipt__c, Notes__c, Rate_Type__c, Rate_Amount__c, Is_Eligible__c, ' +
        'From_Location__c, To_Location__c, Approval_Status__c, ' +
        'Approver_Comments__c, Vehicle_Type__c, Working_Hours__c, ' +
        'City__c, Is_Metro__c, Travel_Mode__c, System_Calculated_Amount__c';

    public static List<Expense_Item__c> getExpenseItemsForDate(Id expenseId, Date expenseDate) {
        return [
            SELECT Id, Expense__c, Day_Attendance__c, Expense_Date__c,
                   Expense_Type__c, Expense_Category__c, GPS_Distance_KM__c,
                   Manual_Distance_KM__c, Distance_Override_Reason__c,
                   Applied_Distance_KM__c, Eligible_Amount__c, Claimed_Amount__c,
                   Approved_Amount__c, Receipt_URL__c, Receipt_Required__c,
                   Has_Receipt__c, Notes__c, Rate_Type__c, Rate_Amount__c, Is_Eligible__c,
                   From_Location__c, To_Location__c, Approval_Status__c,
                   Approver_Comments__c, Vehicle_Type__c, Working_Hours__c,
                   City__c, Is_Metro__c, Travel_Mode__c, System_Calculated_Amount__c
            FROM Expense_Item__c
            WHERE Expense__c = :expenseId AND Expense_Date__c = :expenseDate
            ORDER BY Expense_Type__c ASC
        ];
    }

    @AuraEnabled
    public static List<Expense_Item__c> getAllExpenseItemsForReport(Id expenseId) {
        return [
            SELECT Id, Expense__c, Day_Attendance__c, Expense_Date__c,
                   Expense_Type__c, Expense_Category__c, GPS_Distance_KM__c,
                   Manual_Distance_KM__c, Distance_Override_Reason__c,
                   Applied_Distance_KM__c, Eligible_Amount__c, Claimed_Amount__c,
                   Approved_Amount__c, Receipt_URL__c, Receipt_Required__c,
                   Has_Receipt__c, Notes__c, Rate_Type__c, Rate_Amount__c, Is_Eligible__c,
                   From_Location__c, To_Location__c, Approval_Status__c,
                   Approver_Comments__c, Vehicle_Type__c, Working_Hours__c,
                   City__c, Is_Metro__c, Travel_Mode__c, System_Calculated_Amount__c
            FROM Expense_Item__c
            WHERE Expense__c = :expenseId
            ORDER BY Expense_Date__c ASC, Expense_Type__c ASC
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
            // Only set parent on new items (not writable on update for master-detail)
            if (item.Id == null) {
                item.Expense__c = expenseId;
                // Set default approval status for new items
                if (String.isBlank(item.Approval_Status__c)) {
                    item.Approval_Status__c = 'Not Submitted';
                }
            }

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

            // Validate claimed amount exceeding eligible requires notes
            if (item.Claimed_Amount__c != null && item.Eligible_Amount__c != null
                && item.Claimed_Amount__c > item.Eligible_Amount__c
                && item.Rate_Type__c != 'Actual') {
                if (String.isBlank(item.Notes__c)) {
                    throw new AuraHandledException(
                        'Notes are required when claimed amount exceeds eligible amount for ' + item.Expense_Type__c + '.'
                    );
                }
            }
        }

        upsert items;

        // Return all saved items (may span multiple dates)
        Set<Date> dates = new Set<Date>();
        for (Expense_Item__c item : items) {
            dates.add(item.Expense_Date__c);
        }
        return [
            SELECT Id, Expense__c, Day_Attendance__c, Expense_Date__c,
                   Expense_Type__c, Expense_Category__c, GPS_Distance_KM__c,
                   Manual_Distance_KM__c, Distance_Override_Reason__c,
                   Applied_Distance_KM__c, Eligible_Amount__c, Claimed_Amount__c,
                   Approved_Amount__c, Receipt_URL__c, Receipt_Required__c,
                   Has_Receipt__c, Notes__c, Rate_Type__c, Rate_Amount__c, Is_Eligible__c,
                   From_Location__c, To_Location__c, Approval_Status__c,
                   Approver_Comments__c, Vehicle_Type__c, Working_Hours__c,
                   City__c, Is_Metro__c, Travel_Mode__c, System_Calculated_Amount__c
            FROM Expense_Item__c
            WHERE Expense__c = :expenseId AND Expense_Date__c IN :dates
            ORDER BY Expense_Date__c ASC, Expense_Type__c ASC
        ];
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
    // APPROVAL WORKFLOW — Per-Item Granular Approval
    // ═══════════════════════════════════════════════════════════════════════

    public static Expense__c submitReport(Id expenseId) {
        Expense__c expense = [
            SELECT Id, Status__c, Employee__c, Comments_History__c
            FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];

        if (expense.Status__c != 'Draft' && expense.Status__c != 'Rejected') {
            throw new AuraHandledException('Only Draft or Rejected expenses can be submitted.');
        }

        // Validate receipt and remarks requirements
        validateReceiptsAndRemarks(expenseId, expense.Employee__c);

        // Update all item statuses to Pending
        List<Expense_Item__c> items = [
            SELECT Id, Approval_Status__c
            FROM Expense_Item__c
            WHERE Expense__c = :expenseId
        ];
        for (Expense_Item__c item : items) {
            item.Approval_Status__c = 'Pending';
        }
        if (!items.isEmpty()) update items;

        expense.Status__c = 'Submitted';
        expense.Submitted_Date__c = Datetime.now();
        expense.Rejection_Reason__c = null;
        expense.Comments_History__c = appendComment(
            expense.Comments_History__c, 'Submitted for approval', UserInfo.getUserId()
        );
        update expense;

        return [
            SELECT Id, Name, Status__c, Month__c, Year__c, Total_Claimed__c,
                   Total_Approved__c, Total_Eligible__c, Submitted_Date__c,
                   Comments_History__c
            FROM Expense__c WHERE Id = :expenseId
        ];
    }

    private static void validateReceiptsAndRemarks(Id expenseId, Id employeeId) {
        Employee__c emp = [SELECT User__c FROM Employee__c WHERE Id = :employeeId LIMIT 1];
        String band = getEmployeeBand(emp.User__c);
        Map<String, Expense_Eligibility__c> ruleMap = new Map<String, Expense_Eligibility__c>();
        if (String.isNotBlank(band)) {
            for (Expense_Eligibility__c rule : getEligibilityRules(band)) {
                ruleMap.put(rule.Expense_Type__c, rule);
            }
        }

        List<Expense_Item__c> items = [
            SELECT Id, Expense_Type__c, Receipt_Required__c, Receipt_URL__c,
                   Claimed_Amount__c, Notes__c
            FROM Expense_Item__c
            WHERE Expense__c = :expenseId
        ];

        // Check which items have files attached
        Set<Id> allItemIds = new Set<Id>();
        for (Expense_Item__c item : items) {
            allItemIds.add(item.Id);
        }
        Set<Id> itemsWithFiles = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :allItemIds
        ]) {
            itemsWithFiles.add(cdl.LinkedEntityId);
        }

        for (Expense_Item__c item : items) {
            Expense_Eligibility__c rule = ruleMap.get(item.Expense_Type__c);

            // Receipt validation
            if (item.Receipt_Required__c == true) {
                Boolean hasReceipt = itemsWithFiles.contains(item.Id) || String.isNotBlank(item.Receipt_URL__c);
                if (!hasReceipt) {
                    Decimal threshold = (rule != null && rule.Receipt_Threshold__c != null)
                        ? rule.Receipt_Threshold__c : 0;
                    if (threshold == 0 || (item.Claimed_Amount__c != null && item.Claimed_Amount__c > threshold)) {
                        throw new AuraHandledException(
                            'Receipt is required for ' + item.Expense_Type__c + '.'
                        );
                    }
                }
            }

            // Mandatory remarks validation
            if (rule != null && rule.Mandatory_Remarks__c == true) {
                if (String.isBlank(item.Notes__c)) {
                    throw new AuraHandledException(
                        'Remarks are required for ' + item.Expense_Type__c + '.'
                    );
                }
            }
        }
    }

    public static Expense__c approveReport(Id expenseId, String remarks, String level) {
        Expense__c expense = [
            SELECT Id, Status__c, Comments_History__c
            FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];

        if (level == 'manager') {
            if (expense.Status__c != 'Submitted') {
                throw new AuraHandledException('Only Submitted expenses can be manager-approved.');
            }
            expense.Status__c = 'Manager Approved';
            expense.Manager_Approved_Date__c = Datetime.now();
            expense.Manager_Approver__c = UserInfo.getUserId();
            expense.Manager_Remarks__c = remarks;

            // Update item approval statuses and set approved amounts
            List<Expense_Item__c> items = [
                SELECT Id, Claimed_Amount__c, Approved_Amount__c, Approval_Status__c
                FROM Expense_Item__c WHERE Expense__c = :expenseId
            ];
            for (Expense_Item__c item : items) {
                if (item.Approved_Amount__c == null) {
                    item.Approved_Amount__c = item.Claimed_Amount__c;
                }
                item.Approval_Status__c = 'L1 Approved';
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

            // Update item approval statuses
            List<Expense_Item__c> items = [
                SELECT Id, Approval_Status__c
                FROM Expense_Item__c WHERE Expense__c = :expenseId
            ];
            for (Expense_Item__c item : items) {
                item.Approval_Status__c = 'Finance Approved';
            }
            if (!items.isEmpty()) update items;
        }

        expense.Comments_History__c = appendComment(
            expense.Comments_History__c,
            (level == 'manager' ? 'Manager' : 'Finance') + ' approved' +
            (String.isNotBlank(remarks) ? ': ' + remarks : ''),
            UserInfo.getUserId()
        );
        update expense;

        return [
            SELECT Id, Name, Status__c, Total_Claimed__c, Total_Approved__c,
                   Total_Eligible__c, Comments_History__c
            FROM Expense__c WHERE Id = :expenseId
        ];
    }

    public static Expense__c rejectReport(Id expenseId, String reason, String level) {
        Expense__c expense = [
            SELECT Id, Status__c, Comments_History__c
            FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];

        if (expense.Status__c != 'Submitted' && expense.Status__c != 'Manager Approved') {
            throw new AuraHandledException('Only Submitted or Manager Approved expenses can be rejected.');
        }

        // Update item approval statuses
        List<Expense_Item__c> items = [
            SELECT Id, Approval_Status__c
            FROM Expense_Item__c WHERE Expense__c = :expenseId
        ];
        for (Expense_Item__c item : items) {
            item.Approval_Status__c = 'Rejected';
        }
        if (!items.isEmpty()) update items;

        expense.Status__c = 'Rejected';
        expense.Rejection_Reason__c = reason;
        if (level == 'manager') {
            expense.Manager_Remarks__c = reason;
        } else if (level == 'finance') {
            expense.Finance_Remarks__c = reason;
        }
        expense.Comments_History__c = appendComment(
            expense.Comments_History__c,
            (level == 'manager' ? 'Manager' : 'Finance') + ' rejected: ' + reason,
            UserInfo.getUserId()
        );
        update expense;

        return [
            SELECT Id, Name, Status__c, Rejection_Reason__c, Comments_History__c
            FROM Expense__c WHERE Id = :expenseId
        ];
    }

    public static Map<String, Object> approveExpenseItems(List<Id> itemIds, String remarks, String level) {
        List<Expense_Item__c> items = [
            SELECT Id, Expense__c, Claimed_Amount__c, Approved_Amount__c,
                   Approval_Status__c, Approver_Comments__c
            FROM Expense_Item__c
            WHERE Id IN :itemIds
        ];

        String newStatus = level == 'manager' ? 'L1 Approved' : 'Finance Approved';
        for (Expense_Item__c item : items) {
            item.Approval_Status__c = newStatus;
            if (item.Approved_Amount__c == null) {
                item.Approved_Amount__c = item.Claimed_Amount__c;
            }
            item.Approver_Comments__c = appendComment(
                item.Approver_Comments__c, 'Approved: ' + (remarks != null ? remarks : ''),
                UserInfo.getUserId()
            );
        }
        update items;

        Map<String, Object> result = new Map<String, Object>();
        result.put('items', items);
        result.put('count', items.size());
        return result;
    }

    public static Map<String, Object> rejectExpenseItems(List<Id> itemIds, String reason, String level) {
        List<Expense_Item__c> items = [
            SELECT Id, Expense__c, Approval_Status__c, Approver_Comments__c
            FROM Expense_Item__c
            WHERE Id IN :itemIds
        ];

        for (Expense_Item__c item : items) {
            item.Approval_Status__c = 'Rejected';
            item.Approver_Comments__c = appendComment(
                item.Approver_Comments__c, 'Rejected: ' + reason,
                UserInfo.getUserId()
            );
        }
        update items;

        Map<String, Object> result = new Map<String, Object>();
        result.put('items', items);
        result.put('count', items.size());
        return result;
    }

    public static Map<String, Object> updateApprovedAmounts(Map<Id, Decimal> itemAmounts) {
        List<Expense_Item__c> items = [
            SELECT Id, Approved_Amount__c, Approver_Comments__c
            FROM Expense_Item__c
            WHERE Id IN :itemAmounts.keySet()
        ];
        for (Expense_Item__c item : items) {
            Decimal newAmount = itemAmounts.get(item.Id);
            if (newAmount != null) {
                item.Approved_Amount__c = newAmount;
                item.Approver_Comments__c = appendComment(
                    item.Approver_Comments__c,
                    'Approved amount updated to ' + newAmount,
                    UserInfo.getUserId()
                );
            }
        }
        update items;

        Map<String, Object> result = new Map<String, Object>();
        result.put('items', items);
        return result;
    }

    public static Expense__c markAsPaid(Id expenseId) {
        Expense__c expense = [
            SELECT Id, Status__c, Comments_History__c
            FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];
        if (expense.Status__c != 'Finance Approved') {
            throw new AuraHandledException('Only Finance Approved expenses can be marked as Paid.');
        }
        expense.Status__c = 'Paid';
        expense.Comments_History__c = appendComment(
            expense.Comments_History__c, 'Marked as Paid', UserInfo.getUserId()
        );
        update expense;
        return [
            SELECT Id, Name, Status__c, Comments_History__c
            FROM Expense__c WHERE Id = :expenseId
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
                   Finance_Approved_Date__c, Finance_Remarks__c, Rejection_Reason__c,
                   Comments_History__c
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
    // APPROVAL DATA — For approver component
    // ═══════════════════════════════════════════════════════════════════════

    public static Map<String, Object> getExpenseForApproval(Id expenseId) {
        Expense__c expense = [
            SELECT Id, Name, Month__c, Year__c, Status__c, Employee__c,
                   Employee__r.First_Name__c, Employee__r.Last_Name__c,
                   Employee__r.Band__c, Working_Days__c, Total_Distance_KM__c,
                   Total_Claimed__c, Total_Approved__c, Total_Eligible__c,
                   Submitted_Date__c, Manager_Approved_Date__c, Manager_Remarks__c,
                   Finance_Approved_Date__c, Finance_Remarks__c, Rejection_Reason__c,
                   Comments_History__c
            FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];

        List<Expense_Item__c> items = getAllExpenseItemsForReport(expenseId);

        // Get files for all items
        List<Id> itemIds = new List<Id>();
        for (Expense_Item__c item : items) {
            itemIds.add(item.Id);
        }
        List<Map<String, Object>> files = getExpenseItemFiles(itemIds);

        Map<String, Object> result = new Map<String, Object>();
        result.put('expense', expense);
        result.put('items', items);
        result.put('files', files);
        return result;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FILE / RECEIPT MANAGEMENT
    // ═══════════════════════════════════════════════════════════════════════

    public static List<Map<String, Object>> getExpenseItemFiles(List<Id> itemIds) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (itemIds == null || itemIds.isEmpty()) return result;

        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, ContentDocument.Title,
                   ContentDocument.FileExtension, ContentDocument.ContentSize,
                   ContentDocument.LatestPublishedVersionId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :itemIds
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            Map<String, Object> fileInfo = new Map<String, Object>();
            fileInfo.put('contentDocumentId', cdl.ContentDocumentId);
            fileInfo.put('title', cdl.ContentDocument.Title);
            fileInfo.put('fileExtension', cdl.ContentDocument.FileExtension);
            fileInfo.put('contentSize', cdl.ContentDocument.ContentSize);
            fileInfo.put('versionId', cdl.ContentDocument.LatestPublishedVersionId);
            fileInfo.put('expenseItemId', cdl.LinkedEntityId);
            result.add(fileInfo);
        }
        return result;
    }

    public static void deleteExpenseItemFile(Id contentDocumentId) {
        List<ContentDocument> docs = [
            SELECT Id FROM ContentDocument WHERE Id = :contentDocumentId LIMIT 1
        ];
        if (!docs.isEmpty()) {
            delete docs;
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SUBMIT SUMMARY — Returns confirmation data before final submit
    // ═══════════════════════════════════════════════════════════════════════

    public static Map<String, Object> getSubmitSummary(Id expenseId) {
        Expense__c expense = [
            SELECT Id, Name, Month__c, Year__c, Status__c, Employee__c,
                   Employee__r.First_Name__c, Employee__r.Last_Name__c,
                   Employee__r.Band__c, Working_Days__c, Total_Distance_KM__c,
                   Total_Claimed__c, Total_Eligible__c
            FROM Expense__c WHERE Id = :expenseId LIMIT 1
        ];

        List<Expense_Item__c> items = getAllExpenseItemsForReport(expenseId);

        // Count items, missing receipts, type totals
        Integer totalItems = items.size();
        Integer dayCount = 0;
        Integer missingReceipts = 0;
        Decimal totalClaimed = 0;
        Decimal totalEligible = 0;

        // Check files
        Set<Id> allItemIds = new Set<Id>();
        for (Expense_Item__c item : items) {
            allItemIds.add(item.Id);
        }
        Set<Id> itemsWithFiles = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :allItemIds
        ]) {
            itemsWithFiles.add(cdl.LinkedEntityId);
        }

        Set<Date> uniqueDates = new Set<Date>();
        List<Map<String, Object>> typeBreakdown = new List<Map<String, Object>>();
        Map<String, Decimal> claimedByType = new Map<String, Decimal>();
        Map<String, Decimal> eligibleByType = new Map<String, Decimal>();
        Map<String, Integer> countByType = new Map<String, Integer>();

        for (Expense_Item__c item : items) {
            uniqueDates.add(item.Expense_Date__c);
            Decimal claimed = item.Claimed_Amount__c != null ? item.Claimed_Amount__c : 0;
            Decimal eligible = item.Eligible_Amount__c != null ? item.Eligible_Amount__c : 0;
            totalClaimed += claimed;
            totalEligible += eligible;

            String typ = item.Expense_Type__c;
            claimedByType.put(typ, (claimedByType.containsKey(typ) ? claimedByType.get(typ) : 0) + claimed);
            eligibleByType.put(typ, (eligibleByType.containsKey(typ) ? eligibleByType.get(typ) : 0) + eligible);
            countByType.put(typ, (countByType.containsKey(typ) ? countByType.get(typ) : 0) + 1);

            // Check missing receipts
            if (item.Receipt_Required__c == true && !itemsWithFiles.contains(item.Id)
                && String.isBlank(item.Receipt_URL__c)) {
                missingReceipts++;
            }
        }
        dayCount = uniqueDates.size();

        for (String typ : claimedByType.keySet()) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('type', typ);
            row.put('claimed', claimedByType.get(typ));
            row.put('eligible', eligibleByType.get(typ));
            row.put('count', countByType.get(typ));
            typeBreakdown.add(row);
        }

        Map<String, Object> summary = new Map<String, Object>();
        summary.put('expense', expense);
        summary.put('totalItems', totalItems);
        summary.put('dayCount', dayCount);
        summary.put('totalClaimed', totalClaimed);
        summary.put('totalEligible', totalEligible);
        summary.put('missingReceipts', missingReceipts);
        summary.put('typeBreakdown', typeBreakdown);
        summary.put('canSubmit', missingReceipts == 0);

        return summary;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // COMMENTS HELPER
    // ═══════════════════════════════════════════════════════════════════════

    public static String appendComment(String existing, String comment, Id userId) {
        String userName = UserInfo.getName();
        String timestamp = Datetime.now().format('yyyy-MM-dd HH:mm');
        String entry = '[' + timestamp + '] ' + userName + ': ' + comment;
        if (String.isBlank(existing)) {
            return entry;
        }
        return existing + '\n' + entry;
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
            SELECT Id, Band__c, User__c, Reporting_Manager__c,
                   First_Name__c, Last_Name__c
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
