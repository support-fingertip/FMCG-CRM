/**
 * @description Service class for Journey Plan (Beat Plan) management. Generates
 *              default journey plans based on beat assignments and calculates
 *              plan compliance metrics.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public without sharing class BPM_JourneyPlan_Service {

    /** Days of the week mapped to their index (1 = Monday). */
    private static final Map<String, Integer> DAY_INDEX_MAP = new Map<String, Integer>{
        'Monday'    => 1,
        'Tuesday'   => 2,
        'Wednesday' => 3,
        'Thursday'  => 4,
        'Friday'    => 5,
        'Saturday'  => 6,
        'Sunday'    => 7
    };

    /**
     * @description Generates a default journey plan for a user in a given territory
     *              for a specified month and year. Creates a Journey_Plan__c header
     *              and Journey_Plan_Day__c records based on the user's Beat__c
     *              assignments.
     *
     * @param userId      The user (sales rep) for whom to generate the plan.
     * @param territoryId The territory under which beats are assigned.
     * @param month       The month (1-12 or name) for the plan.
     * @param year        The four-digit year string.
     * @return The Id of the created Journey_Plan__c record.
     */
    public static Id generateDefaultPlan(
        Id userId,
        Id territoryId,
        String month,
        String year
    ) {
        return generateDefaultPlan(userId, territoryId, month, year, null, null);
    }

    /**
     * @description Overloaded version that accepts an optional date range.
     *              Filters beats by Assigned_User__c and only generates plan days
     *              for dates within the specified range. Sets Effective_From__c
     *              and Effective_To__c on the plan when provided.
     *
     * @param userId         The user (sales rep) for whom to generate the plan.
     * @param territoryId    The territory under which beats are assigned.
     * @param month          The month (1-12 or name) for the plan.
     * @param year           The four-digit year string.
     * @param rangeStartDate Optional start date to limit plan day generation.
     * @param rangeEndDate   Optional end date to limit plan day generation.
     * @return The Id of the created Journey_Plan__c record.
     */
    public static Id generateDefaultPlan(
        Id userId,
        Id territoryId,
        String month,
        String year,
        Date rangeStartDate,
        Date rangeEndDate
    ) {
        if (userId == null || territoryId == null ||
            String.isBlank(month) || String.isBlank(year)) {
            throw new BPM_JourneyPlanServiceException(
                'All parameters (userId, territoryId, month, year) are required.'
            );
        }

        Integer monthInt = parseMonth(month);
        Integer yearInt = Integer.valueOf(year);
        String monthName = normalizeMonthName(monthInt);

        // Validate no existing plan for this user/territory/month/year
        List<Journey_Plan__c> existingPlans = [
            SELECT Id
            FROM Journey_Plan__c
            WHERE Salesperson__c = :userId
              AND Territory__c = :territoryId
              AND Month__c = :monthName
              AND Year__c = :year
              AND Status__c != 'Cancelled'
            LIMIT 1
        ];

        if (!existingPlans.isEmpty()) {
            throw new BPM_JourneyPlanServiceException(
                'A journey plan already exists for this user, territory, month, and year.'
            );
        }

        // Fetch user and territory names for the plan name
        String userName = [SELECT Name FROM User WHERE Id = :userId LIMIT 1].Name;
        String territoryName = [SELECT Name FROM Territory_Master__c WHERE Id = :territoryId LIMIT 1].Name;
        String planName = monthName + ' ' + year + ' - ' + userName + ' - ' + territoryName;

        // Fetch beat assignments for the user in this territory
        List<Beat__c> beats = [
            SELECT Id, Name, Day_of_Week__c, Frequency__c,
                   Territory__c, Sequence__c,
                   (SELECT Id, Account__c, Account__r.Name, Visit_Sequence__c
                    FROM Beat_Outlets__r
                    WHERE Is_Active__c = true
                    ORDER BY Visit_Sequence__c ASC)
            FROM Beat__c
            WHERE Assigned_User__c = :userId
              AND Territory__c = :territoryId
              AND Is_Active__c = true
            ORDER BY Sequence__c NULLS LAST, Name
        ];

        if (beats.isEmpty()) {
            throw new BPM_JourneyPlanServiceException(
                'No active beat assignments found for this user in the specified territory.'
            );
        }

        // Create the journey plan header
        Journey_Plan__c plan = new Journey_Plan__c(
            Name          = planName,
            Salesperson__c       = userId,
            Territory__c  = territoryId,
            Month__c      = monthName,
            Year__c       = year,
            Status__c     = 'Draft',
            Plan_Date__c  = Date.today()
        );
        if (rangeStartDate != null) {
            plan.Effective_From__c = rangeStartDate;
        }
        if (rangeEndDate != null) {
            plan.Effective_To__c = rangeEndDate;
        }
        insert plan;

        // Generate journey plan days
        List<Journey_Plan_Day__c> planDays = new List<Journey_Plan_Day__c>();
        Date firstOfMonth = Date.newInstance(yearInt, monthInt, 1);
        Integer daysInMonth = Date.daysInMonth(yearInt, monthInt);

        // Build a map of day-of-week -> beats
        Map<String, List<Beat__c>> beatsByDay = new Map<String, List<Beat__c>>();
        for (Beat__c beat : beats) {
            if (String.isNotBlank(beat.Day_of_Week__c)) {
                // Handle multi-day assignments (semicolon-separated multi-select picklist)
                List<String> days = beat.Day_of_Week__c.split(';');
                for (String day : days) {
                    String trimmedDay = day.trim();
                    if (!beatsByDay.containsKey(trimmedDay)) {
                        beatsByDay.put(trimmedDay, new List<Beat__c>());
                    }
                    beatsByDay.get(trimmedDay).add(beat);
                }
            }
        }

        // Iterate through each day of the month
        Integer sequenceOrder = 0;
        for (Integer dayNum = 1; dayNum <= daysInMonth; dayNum++) {
            Date currentDate = Date.newInstance(yearInt, monthInt, dayNum);

            // Skip dates outside the specified range
            if (rangeStartDate != null && currentDate < rangeStartDate) {
                continue;
            }
            if (rangeEndDate != null && currentDate > rangeEndDate) {
                continue;
            }

            String dayOfWeek = getDayOfWeek(currentDate);

            // Skip Sundays (or configurable weekly off)
            if (dayOfWeek == 'Sunday') {
                continue;
            }

            List<Beat__c> daysBeats = beatsByDay.get(dayOfWeek);
            if (daysBeats == null || daysBeats.isEmpty()) {
                continue;
            }

            String weekNumber = getWeekNumber(dayNum);

            for (Beat__c beat : daysBeats) {
                // Check frequency (daily, weekly, bi-weekly, monthly)
                if (!shouldIncludeForFrequency(beat.Frequency__c, dayNum, daysInMonth)) {
                    continue;
                }

                sequenceOrder++;
                Journey_Plan_Day__c planDay = new Journey_Plan_Day__c(
                    Journey_Plan__c     = plan.Id,
                    Plan_Date__c        = currentDate,
                    Day_Of_Week__c      = dayOfWeek,
                    Beat__c             = beat.Id,
                    Beat_Name__c        = beat.Name,
                    Planned_Outlets__c  = beat.Beat_Outlets__r != null
                        ? beat.Beat_Outlets__r.size() : 0,
                    Status__c           = 'Planned',
                    Sequence__c         = beat.Sequence__c,
                    Week_Number__c      = weekNumber,
                    Sequence_Order__c   = sequenceOrder
                );
                planDays.add(planDay);
            }
        }

        if (!planDays.isEmpty()) {
            insert planDays;
        }

        // Update plan with total planned days
        plan.Total_Planned_Days__c = planDays.size();
        update plan;

        return plan.Id;
    }

    /**
     * @description Generates a single journey plan spanning a date range.
     *              Creates ONE Journey_Plan__c and iterates through every day
     *              from fromDate to toDate, creating Journey_Plan_Day__c records.
     *              Validates no overlapping plan exists for this user/territory.
     *
     * @param userId      The user (sales rep) for whom to generate the plan.
     * @param territoryId The territory under which beats are assigned.
     * @param fromDate    Start date of the plan range.
     * @param toDate      End date of the plan range.
     * @return The Id of the created Journey_Plan__c record.
     */
    public static Id generatePlanForDateRange(
        Id userId,
        Id territoryId,
        Date fromDate,
        Date toDate
    ) {
        if (userId == null || territoryId == null || fromDate == null || toDate == null) {
            throw new BPM_JourneyPlanServiceException(
                'All parameters (userId, territoryId, fromDate, toDate) are required.'
            );
        }
        if (fromDate > toDate) {
            throw new BPM_JourneyPlanServiceException('From Date must be before or equal to To Date.');
        }

        // Validate no overlapping plan exists (by date range, not month/year)
        List<Journey_Plan__c> overlapping = [
            SELECT Id, Name, Effective_From__c, Effective_To__c
            FROM Journey_Plan__c
            WHERE Salesperson__c = :userId
              AND Territory__c = :territoryId
              AND Status__c != 'Cancelled'
              AND Effective_From__c != null
              AND Effective_To__c != null
              AND Effective_From__c <= :toDate
              AND Effective_To__c >= :fromDate
            LIMIT 1
        ];

        if (!overlapping.isEmpty()) {
            Journey_Plan__c existing = overlapping[0];
            throw new BPM_JourneyPlanServiceException(
                'An overlapping journey plan already exists: ' + existing.Name
                + ' (' + String.valueOf(existing.Effective_From__c)
                + ' to ' + String.valueOf(existing.Effective_To__c) + ').'
            );
        }

        // Fetch user and territory names
        String userName = [SELECT Name FROM User WHERE Id = :userId LIMIT 1].Name;
        String territoryName = [SELECT Name FROM Territory_Master__c WHERE Id = :territoryId LIMIT 1].Name;

        String startMonthName = normalizeMonthName(fromDate.month());
        String startYearStr = String.valueOf(fromDate.year());
        String planName;
        if (fromDate.month() == toDate.month() && fromDate.year() == toDate.year()) {
            planName = startMonthName + ' ' + startYearStr + ' - ' + userName + ' - ' + territoryName;
        } else {
            String endMonthName = normalizeMonthName(toDate.month());
            planName = startMonthName + ' ' + startYearStr + ' to '
                + endMonthName + ' ' + String.valueOf(toDate.year())
                + ' - ' + userName + ' - ' + territoryName;
        }

        // Fetch beats assigned to this user in the territory
        List<Beat__c> beats = [
            SELECT Id, Name, Day_of_Week__c, Frequency__c,
                   Territory__c, Sequence__c,
                   (SELECT Id, Account__c, Account__r.Name, Visit_Sequence__c
                    FROM Beat_Outlets__r
                    WHERE Is_Active__c = true
                    ORDER BY Visit_Sequence__c ASC)
            FROM Beat__c
            WHERE Assigned_User__c = :userId
              AND Territory__c = :territoryId
              AND Is_Active__c = true
            ORDER BY Sequence__c NULLS LAST, Name
        ];

        if (beats.isEmpty()) {
            throw new BPM_JourneyPlanServiceException(
                'No active beat assignments found for this user in the specified territory.'
            );
        }

        // Create single journey plan header
        Journey_Plan__c plan = new Journey_Plan__c(
            Name             = planName,
            Salesperson__c   = userId,
            Territory__c     = territoryId,
            Month__c         = startMonthName,
            Year__c          = startYearStr,
            Status__c        = 'Draft',
            Plan_Date__c     = Date.today(),
            Effective_From__c = fromDate,
            Effective_To__c   = toDate
        );
        insert plan;

        // Build day-of-week -> beats map
        Map<String, List<Beat__c>> beatsByDay = new Map<String, List<Beat__c>>();
        for (Beat__c beat : beats) {
            if (String.isNotBlank(beat.Day_of_Week__c)) {
                List<String> days = beat.Day_of_Week__c.split(';');
                for (String day : days) {
                    String trimmedDay = day.trim();
                    if (!beatsByDay.containsKey(trimmedDay)) {
                        beatsByDay.put(trimmedDay, new List<Beat__c>());
                    }
                    beatsByDay.get(trimmedDay).add(beat);
                }
            }
        }

        // Iterate through every day in the date range
        List<Journey_Plan_Day__c> planDays = new List<Journey_Plan_Day__c>();
        Integer sequenceOrder = 0;
        Date currentDate = fromDate;

        while (currentDate <= toDate) {
            String dayOfWeek = getDayOfWeek(currentDate);

            if (dayOfWeek != 'Sunday') {
                List<Beat__c> daysBeats = beatsByDay.get(dayOfWeek);
                if (daysBeats != null && !daysBeats.isEmpty()) {
                    Integer dayOfMonth = currentDate.day();
                    Integer daysInMonth = Date.daysInMonth(currentDate.year(), currentDate.month());
                    String weekNumber = getWeekNumber(dayOfMonth);

                    for (Beat__c beat : daysBeats) {
                        if (shouldIncludeForFrequency(beat.Frequency__c, dayOfMonth, daysInMonth)) {
                            sequenceOrder++;
                            planDays.add(new Journey_Plan_Day__c(
                                Journey_Plan__c     = plan.Id,
                                Plan_Date__c        = currentDate,
                                Day_Of_Week__c      = dayOfWeek,
                                Beat__c             = beat.Id,
                                Beat_Name__c        = beat.Name,
                                Planned_Outlets__c  = beat.Beat_Outlets__r != null
                                    ? beat.Beat_Outlets__r.size() : 0,
                                Status__c           = 'Planned',
                                Sequence__c         = beat.Sequence__c,
                                Week_Number__c      = weekNumber,
                                Sequence_Order__c   = sequenceOrder
                            ));
                        }
                    }
                }
            }

            currentDate = currentDate.addDays(1);
        }

        if (!planDays.isEmpty()) {
            insert planDays;
        }

        plan.Total_Planned_Days__c = planDays.size();
        update plan;

        return plan.Id;
    }

    /**
     * @description Regenerates a journey plan by deleting all future plan days
     *              (from today onwards) and recreating them using the user's
     *              current beat assignments. Preserves past plan days.
     *
     * @param journeyPlanId The Journey_Plan__c record to regenerate.
     * @param toDate        The new end date for the plan.
     */
    public static void regeneratePlan(Id journeyPlanId, Date toDate) {
        Journey_Plan__c plan = [
            SELECT Id, Salesperson__c, Territory__c, Status__c,
                   Effective_From__c, Effective_To__c
            FROM Journey_Plan__c
            WHERE Id = :journeyPlanId
            LIMIT 1
        ];

        if (plan.Status__c != 'Draft' && plan.Status__c != 'Rejected') {
            throw new BPM_JourneyPlanServiceException('Only Draft or Rejected plans can be regenerated.');
        }

        Date fromDate = Date.today();
        if (toDate == null) {
            toDate = plan.Effective_To__c != null ? plan.Effective_To__c : fromDate.addMonths(1).addDays(-1);
        }

        // Delete all plan days from today onwards
        List<Journey_Plan_Day__c> futureDays = [
            SELECT Id FROM Journey_Plan_Day__c
            WHERE Journey_Plan__c = :journeyPlanId AND Plan_Date__c >= :fromDate
        ];
        if (!futureDays.isEmpty()) {
            delete futureDays;
        }

        // Fetch current beat assignments for the user
        Id userId = plan.Salesperson__c;
        Id territoryId = plan.Territory__c;

        List<Beat__c> beats = [
            SELECT Id, Name, Day_of_Week__c, Frequency__c,
                   Territory__c, Sequence__c,
                   (SELECT Id, Account__c, Account__r.Name, Visit_Sequence__c
                    FROM Beat_Outlets__r
                    WHERE Is_Active__c = true
                    ORDER BY Visit_Sequence__c ASC)
            FROM Beat__c
            WHERE Assigned_User__c = :userId
              AND Territory__c = :territoryId
              AND Is_Active__c = true
            ORDER BY Sequence__c NULLS LAST, Name
        ];

        if (beats.isEmpty()) {
            throw new BPM_JourneyPlanServiceException(
                'No active beat assignments found for this user in the specified territory.'
            );
        }

        // Build day-of-week -> beats map
        Map<String, List<Beat__c>> beatsByDay = new Map<String, List<Beat__c>>();
        for (Beat__c beat : beats) {
            if (String.isNotBlank(beat.Day_of_Week__c)) {
                List<String> days = beat.Day_of_Week__c.split(';');
                for (String day : days) {
                    String trimmedDay = day.trim();
                    if (!beatsByDay.containsKey(trimmedDay)) {
                        beatsByDay.put(trimmedDay, new List<Beat__c>());
                    }
                    beatsByDay.get(trimmedDay).add(beat);
                }
            }
        }

        // Get max sequence from remaining (past) plan days
        List<AggregateResult> maxSeq = [
            SELECT MAX(Sequence_Order__c) maxVal
            FROM Journey_Plan_Day__c
            WHERE Journey_Plan__c = :journeyPlanId
        ];
        Integer sequenceOrder = 0;
        if (maxSeq[0].get('maxVal') != null) {
            sequenceOrder = ((Decimal) maxSeq[0].get('maxVal')).intValue();
        }

        // Create new plan days from today to toDate
        List<Journey_Plan_Day__c> planDays = new List<Journey_Plan_Day__c>();
        Date currentDate = fromDate;

        while (currentDate <= toDate) {
            String dayOfWeek = getDayOfWeek(currentDate);

            if (dayOfWeek != 'Sunday') {
                List<Beat__c> daysBeats = beatsByDay.get(dayOfWeek);
                if (daysBeats != null && !daysBeats.isEmpty()) {
                    Integer dayOfMonth = currentDate.day();
                    Integer daysInMonth = Date.daysInMonth(currentDate.year(), currentDate.month());
                    String weekNumber = getWeekNumber(dayOfMonth);

                    for (Beat__c beat : daysBeats) {
                        if (shouldIncludeForFrequency(beat.Frequency__c, dayOfMonth, daysInMonth)) {
                            sequenceOrder++;
                            planDays.add(new Journey_Plan_Day__c(
                                Journey_Plan__c     = plan.Id,
                                Plan_Date__c        = currentDate,
                                Day_Of_Week__c      = dayOfWeek,
                                Beat__c             = beat.Id,
                                Beat_Name__c        = beat.Name,
                                Planned_Outlets__c  = beat.Beat_Outlets__r != null
                                    ? beat.Beat_Outlets__r.size() : 0,
                                Status__c           = 'Planned',
                                Sequence__c         = beat.Sequence__c,
                                Week_Number__c      = weekNumber,
                                Sequence_Order__c   = sequenceOrder
                            ));
                        }
                    }
                }
            }

            currentDate = currentDate.addDays(1);
        }

        if (!planDays.isEmpty()) {
            insert planDays;
        }

        // Update plan dates and total
        plan.Effective_To__c = toDate;
        plan.Total_Planned_Days__c = [
            SELECT COUNT() FROM Journey_Plan_Day__c WHERE Journey_Plan__c = :journeyPlanId
        ];
        update plan;
    }

    /**
     * @description Calculates the compliance percentage for a journey plan by
     *              comparing executed visits against planned visits.
     *
     * @param journeyPlanId The Journey_Plan__c record ID.
     * @return The compliance percentage (0-100).
     */
    public static Decimal getPlanCompliance(Id journeyPlanId) {
        if (journeyPlanId == null) {
            return 0;
        }

        // Get plan days with execution status
        List<Journey_Plan_Day__c> planDays = [
            SELECT Id, Status__c, Planned_Outlets__c, Visited_Outlets__c
            FROM Journey_Plan_Day__c
            WHERE Journey_Plan__c = :journeyPlanId
        ];

        if (planDays.isEmpty()) {
            return 0;
        }

        Decimal totalPlanned = 0;
        Decimal totalExecuted = 0;

        for (Journey_Plan_Day__c day : planDays) {
            Decimal planned = day.Planned_Outlets__c != null ? day.Planned_Outlets__c : 0;
            Decimal visited = day.Visited_Outlets__c != null ? day.Visited_Outlets__c : 0;

            totalPlanned += planned;
            totalExecuted += visited;
        }

        if (totalPlanned == 0) {
            return 0;
        }

        Decimal compliance = (totalExecuted / totalPlanned * 100)
            .setScale(2, RoundingMode.HALF_UP);

        // Cap at 100%
        return Math.min(compliance, 100);
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * @description Parses the month parameter which can be a number (1-12) or
     *              a month name.
     */
    private static Integer parseMonth(String month) {
        Map<String, Integer> monthNames = new Map<String, Integer>{
            'january' => 1, 'february' => 2, 'march' => 3,
            'april' => 4, 'may' => 5, 'june' => 6,
            'july' => 7, 'august' => 8, 'september' => 9,
            'october' => 10, 'november' => 11, 'december' => 12
        };

        // Try as number first
        try {
            Integer monthInt = Integer.valueOf(month);
            if (monthInt >= 1 && monthInt <= 12) {
                return monthInt;
            }
        } catch (Exception e) {
            // Not a number, try as name
        }

        String lowerMonth = month.toLowerCase().trim();
        if (monthNames.containsKey(lowerMonth)) {
            return monthNames.get(lowerMonth);
        }

        throw new BPM_JourneyPlanServiceException('Invalid month value: ' + month);
    }

    /**
     * @description Returns the day-of-week name for a given date.
     */
    private static String getDayOfWeek(Date d) {
        // Calculate day of week (Salesforce doesn't have a direct method)
        DateTime dt = DateTime.newInstance(d, Time.newInstance(12, 0, 0, 0));
        return dt.format('EEEE');
    }

    /**
     * @description Determines whether a beat should be included based on its
     *              frequency and the day of the month.
     */
    private static Boolean shouldIncludeForFrequency(
        String frequency,
        Integer dayOfMonth,
        Integer daysInMonth
    ) {
        if (String.isBlank(frequency) || frequency == 'Daily' || frequency == 'Weekly') {
            return true; // Daily/Weekly: include every occurrence
        }

        if (frequency == 'Bi-Weekly') {
            // Include in the 1st and 3rd weeks only
            return dayOfMonth <= 14;
        }

        if (frequency == 'Monthly') {
            // Include only on the first occurrence in the month
            return dayOfMonth <= 7;
        }

        return true;
    }

    /**
     * @description Returns the week number label ("Week 1" through "Week 4")
     *              for a given day of the month.
     */
    private static String getWeekNumber(Integer dayOfMonth) {
        if (dayOfMonth <= 7) return 'Week 1';
        if (dayOfMonth <= 14) return 'Week 2';
        if (dayOfMonth <= 21) return 'Week 3';
        return 'Week 4';
    }

    /**
     * @description Converts a month integer (1-12) to the standard picklist
     *              name (e.g. "January").
     */
    private static String normalizeMonthName(Integer monthInt) {
        List<String> names = new List<String>{
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };
        return names[monthInt - 1];
    }
}
