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
        if (userId == null || territoryId == null ||
            String.isBlank(month) || String.isBlank(year)) {
            throw new BPM_JourneyPlanServiceException(
                'All parameters (userId, territoryId, month, year) are required.'
            );
        }

        Integer monthInt = parseMonth(month);
        Integer yearInt = Integer.valueOf(year);

        // Validate no existing plan for this user/territory/month/year
        List<Journey_Plan__c> existingPlans = [
            SELECT Id
            FROM Journey_Plan__c
            WHERE User__c = :userId
              AND Territory__c = :territoryId
              AND Month__c = :month
              AND Year__c = :year
              AND Status__c != 'Cancelled'
            LIMIT 1
        ];

        if (!existingPlans.isEmpty()) {
            throw new BPM_JourneyPlanServiceException(
                'A journey plan already exists for this user, territory, month, and year.'
            );
        }

        // Fetch beat assignments for the user in this territory
        List<Beat__c> beats = [
            SELECT Id, Name, Beat_Day__c, Beat_Frequency__c,
                   Territory__c, Sequence__c,
                   (SELECT Id, Account__c, Account__r.Name, Visit_Sequence__c
                    FROM Beat_Outlets__r
                    WHERE Is_Active__c = true
                    ORDER BY Visit_Sequence__c ASC)
            FROM Beat__c
            WHERE Territory__c = :territoryId
              AND Assigned_User__c = :userId
              AND Is_Active__c = true
            ORDER BY Beat_Day__c, Sequence__c
        ];

        if (beats.isEmpty()) {
            throw new BPM_JourneyPlanServiceException(
                'No active beat assignments found for this user in the specified territory.'
            );
        }

        // Create the journey plan header
        Journey_Plan__c plan = new Journey_Plan__c(
            User__c       = userId,
            Territory__c  = territoryId,
            Month__c      = month,
            Year__c       = year,
            Status__c     = 'Draft',
            Plan_Date__c  = Date.today()
        );
        insert plan;

        // Generate journey plan days
        List<Journey_Plan_Day__c> planDays = new List<Journey_Plan_Day__c>();
        Date firstOfMonth = Date.newInstance(yearInt, monthInt, 1);
        Integer daysInMonth = Date.daysInMonth(yearInt, monthInt);

        // Build a map of day-of-week -> beats
        Map<String, List<Beat__c>> beatsByDay = new Map<String, List<Beat__c>>();
        for (Beat__c beat : beats) {
            if (String.isNotBlank(beat.Beat_Day__c)) {
                // Handle multi-day assignments (comma-separated)
                List<String> days = beat.Beat_Day__c.split(',');
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
        for (Integer dayNum = 1; dayNum <= daysInMonth; dayNum++) {
            Date currentDate = Date.newInstance(yearInt, monthInt, dayNum);
            String dayOfWeek = getDayOfWeek(currentDate);

            // Skip Sundays (or configurable weekly off)
            if (dayOfWeek == 'Sunday') {
                continue;
            }

            List<Beat__c> daysBeats = beatsByDay.get(dayOfWeek);
            if (daysBeats == null || daysBeats.isEmpty()) {
                continue;
            }

            for (Beat__c beat : daysBeats) {
                // Check frequency (weekly, fortnightly, monthly)
                if (!shouldIncludeForFrequency(beat.Beat_Frequency__c, dayNum, daysInMonth)) {
                    continue;
                }

                Journey_Plan_Day__c planDay = new Journey_Plan_Day__c(
                    Journey_Plan__c     = plan.Id,
                    Plan_Date__c        = currentDate,
                    Day_Of_Week__c      = dayOfWeek,
                    Beat__c             = beat.Id,
                    Beat_Name__c        = beat.Name,
                    Planned_Outlets__c  = beat.Beat_Outlets__r != null
                        ? beat.Beat_Outlets__r.size() : 0,
                    Status__c           = 'Planned',
                    Sequence__c         = beat.Sequence__c
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
        if (String.isBlank(frequency) || frequency == 'Weekly') {
            return true; // Weekly: include every occurrence
        }

        if (frequency == 'Fortnightly') {
            // Include on 1st and 3rd occurrence of the day in the month
            return dayOfMonth <= 14;
        }

        if (frequency == 'Monthly') {
            // Include only on the first occurrence in the month
            return dayOfMonth <= 7;
        }

        return true;
    }
}