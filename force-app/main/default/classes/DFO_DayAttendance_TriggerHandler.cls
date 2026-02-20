/**
 * @description Trigger handler for Day_Attendance__c. Prevents duplicate day starts,
 *              calculates end-of-day summaries, and finalises daily field operations
 *              metrics.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public class DFO_DayAttendance_TriggerHandler extends TriggerHandler {

    // ── Before Insert ─────────────────────────────────────────────────────────

    /**
     * @description Validates that no duplicate day start exists for the same
     *              user and date combination.
     */
    protected override void beforeInsert() {
        List<Day_Attendance__c> newRecords = (List<Day_Attendance__c>) Trigger.new;
        validateNoDuplicateDayStart(newRecords);
    }

    // ── Before Update ─────────────────────────────────────────────────────────

    /**
     * @description On day end (when End_Time__c is set), calculates summary
     *              metrics: total visits, orders, collections, and distance.
     */
    protected override void beforeUpdate() {
        List<Day_Attendance__c> newRecords = (List<Day_Attendance__c>) Trigger.new;
        Map<Id, Day_Attendance__c> oldMap = (Map<Id, Day_Attendance__c>) Trigger.oldMap;

        List<Day_Attendance__c> dayEnding = new List<Day_Attendance__c>();
        for (Day_Attendance__c rec : newRecords) {
            Day_Attendance__c oldRec = oldMap.get(rec.Id);
            // Day is ending when End_Time__c is populated for the first time
            if (rec.End_Time__c != null && oldRec.End_Time__c == null) {
                dayEnding.add(rec);
            }
        }

        if (!dayEnding.isEmpty()) {
            calculateDaySummary(dayEnding);
        }
    }

    // ── After Update ──────────────────────────────────────────────────────────

    /**
     * @description When status transitions to 'Ended', finalises the daily
     *              summary and marks the attendance as complete.
     */
    protected override void afterUpdate() {
        List<Day_Attendance__c> newRecords = (List<Day_Attendance__c>) Trigger.new;
        Map<Id, Day_Attendance__c> oldMap = (Map<Id, Day_Attendance__c>) Trigger.oldMap;

        List<Day_Attendance__c> endedRecords = new List<Day_Attendance__c>();
        for (Day_Attendance__c rec : newRecords) {
            Day_Attendance__c oldRec = oldMap.get(rec.Id);
            if (rec.Status__c == 'Ended' && oldRec.Status__c != 'Ended') {
                endedRecords.add(rec);
            }
        }

        if (!endedRecords.isEmpty()) {
            finalizeDailySummary(endedRecords);
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * @description Validates uniqueness of user + date combinations. Prevents
     *              a salesperson from having multiple day starts for the same date.
     * @param records The new Day_Attendance__c records.
     */
    private void validateNoDuplicateDayStart(List<Day_Attendance__c> records) {
        Set<Id> userIds = new Set<Id>();
        Set<Date> attendanceDates = new Set<Date>();

        for (Day_Attendance__c rec : records) {
            if (rec.User__c != null) {
                userIds.add(rec.User__c);
            }
            if (rec.Attendance_Date__c != null) {
                attendanceDates.add(rec.Attendance_Date__c);
            }
        }

        if (userIds.isEmpty() || attendanceDates.isEmpty()) {
            return;
        }

        // Query existing attendance for the same user + date
        Set<String> existingKeys = new Set<String>();
        for (Day_Attendance__c existing : [
            SELECT User__c, Attendance_Date__c
            FROM Day_Attendance__c
            WHERE User__c IN :userIds
              AND Attendance_Date__c IN :attendanceDates
              AND Status__c != 'Cancelled'
        ]) {
            existingKeys.add(buildUserDateKey(existing.User__c, existing.Attendance_Date__c));
        }

        // Check incoming batch for intra-batch duplicates
        Set<String> batchKeys = new Set<String>();
        for (Day_Attendance__c rec : records) {
            if (rec.User__c == null || rec.Attendance_Date__c == null) {
                continue;
            }

            String key = buildUserDateKey(rec.User__c, rec.Attendance_Date__c);

            if (existingKeys.contains(key)) {
                rec.addError(
                    'A day attendance record already exists for this user on ' +
                    String.valueOf(rec.Attendance_Date__c) +
                    '. Only one day start is allowed per user per date.'
                );
            } else if (batchKeys.contains(key)) {
                rec.addError(
                    'Duplicate day attendance found within the same batch for user on ' +
                    String.valueOf(rec.Attendance_Date__c) + '.'
                );
            }
            batchKeys.add(key);
        }
    }

    /**
     * @description Calculates the daily summary metrics by aggregating visit,
     *              order, and collection data for the day.
     * @param records The Day_Attendance__c records being ended.
     */
    private void calculateDaySummary(List<Day_Attendance__c> records) {
        Set<Id> attendanceIds = new Set<Id>();
        for (Day_Attendance__c rec : records) {
            attendanceIds.add(rec.Id);
        }

        // Aggregate visit metrics
        Map<Id, AggregateResult> visitAggregates = new Map<Id, AggregateResult>();
        for (AggregateResult ar : [
            SELECT Day_Attendance__c attId,
                   COUNT(Id) totalVisits,
                   SUM(Order_Value__c) totalOrderValue
            FROM Visit__c
            WHERE Day_Attendance__c IN :attendanceIds
            GROUP BY Day_Attendance__c
        ]) {
            visitAggregates.put((Id) ar.get('attId'), ar);
        }

        // Aggregate productive visit counts separately (SOQL doesn't support CASE WHEN)
        Map<Id, Integer> productiveVisitCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Day_Attendance__c attId,
                   COUNT(Id) productiveVisits
            FROM Visit__c
            WHERE Day_Attendance__c IN :attendanceIds
              AND Is_Productive__c = true
            GROUP BY Day_Attendance__c
        ]) {
            productiveVisitCounts.put((Id) ar.get('attId'), (Integer) ar.get('productiveVisits'));
        }

        // Aggregate collection metrics
        Map<Id, Decimal> collectionByAttendance = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Visit__r.Day_Attendance__c attId,
                   SUM(Amount__c) totalCollected
            FROM Collection__c
            WHERE Visit__r.Day_Attendance__c IN :attendanceIds
              AND Status__c != 'Bounced'
            GROUP BY Visit__r.Day_Attendance__c
        ]) {
            Id attId = (Id) ar.get('attId');
            Decimal total = (Decimal) ar.get('totalCollected');
            collectionByAttendance.put(attId, total != null ? total : 0);
        }

        // Apply summary to records (before update context - modify in place)
        for (Day_Attendance__c rec : records) {
            AggregateResult visitAR = visitAggregates.get(rec.Id);
            if (visitAR != null) {
                rec.Total_Visits__c = (Integer) visitAR.get('totalVisits');
                rec.Productive_Calls__c = productiveVisitCounts.containsKey(rec.Id)
                    ? productiveVisitCounts.get(rec.Id) : 0;
                rec.Total_Order_Value__c = (Decimal) visitAR.get('totalOrderValue');
            } else {
                rec.Total_Visits__c = 0;
                rec.Productive_Calls__c = 0;
                rec.Total_Order_Value__c = 0;
            }

            rec.Total_Collection__c = collectionByAttendance.containsKey(rec.Id)
                ? collectionByAttendance.get(rec.Id) : 0;

            // Calculate working hours
            if (rec.Start_Time__c != null && rec.End_Time__c != null) {
                Long startMillis = rec.Start_Time__c.getTime();
                Long endMillis = rec.End_Time__c.getTime();
                Decimal hoursWorked = ((Decimal)(endMillis - startMillis)) / (1000 * 60 * 60);
                rec.Hours_Worked__c = hoursWorked.setScale(2, RoundingMode.HALF_UP);
            }
        }
    }

    /**
     * @description Finalises the daily summary after the day has ended.
     *              Creates a snapshot record and updates any derived metrics.
     * @param endedRecords The Day_Attendance__c records with status = 'Ended'.
     */
    private void finalizeDailySummary(List<Day_Attendance__c> endedRecords) {
        // Collect IDs for distance calculation
        Set<Id> attendanceIds = new Set<Id>();
        for (Day_Attendance__c rec : endedRecords) {
            attendanceIds.add(rec.Id);
        }

        // Calculate total distance travelled from visit GPS data
        Map<Id, Double> distanceByAttendance = calculateDistanceTravelled(attendanceIds);

        // Update records with final metrics
        List<Day_Attendance__c> toUpdate = new List<Day_Attendance__c>();
        for (Day_Attendance__c rec : endedRecords) {
            Day_Attendance__c updateRec = new Day_Attendance__c(
                Id = rec.Id,
                Is_Finalized__c = true,
                Total_Distance__c = distanceByAttendance.containsKey(rec.Id)
                    ? distanceByAttendance.get(rec.Id) : 0
            );
            toUpdate.add(updateRec);
        }

        if (!toUpdate.isEmpty()) {
            TriggerHandler.bypass('DFO_DayAttendance_TriggerHandler');
            update toUpdate;
            TriggerHandler.clearBypass('DFO_DayAttendance_TriggerHandler');
        }
    }

    /**
     * @description Calculates total distance travelled during the day by summing
     *              sequential distances between visit GPS coordinates.
     * @param attendanceIds The Day_Attendance__c IDs to process.
     * @return Map of Attendance ID to total distance in meters.
     */
    private Map<Id, Double> calculateDistanceTravelled(Set<Id> attendanceIds) {
        Map<Id, Double> result = new Map<Id, Double>();

        // Get all visits with GPS data ordered by check-in time
        Map<Id, List<Visit__c>> visitsByAttendance = new Map<Id, List<Visit__c>>();
        for (Visit__c visit : [
            SELECT Id, Day_Attendance__c, Check_In_Latitude__c, Check_In_Longitude__c,
                   Check_In_Time__c
            FROM Visit__c
            WHERE Day_Attendance__c IN :attendanceIds
              AND Check_In_Latitude__c != null
              AND Check_In_Longitude__c != null
            ORDER BY Check_In_Time__c ASC
        ]) {
            if (!visitsByAttendance.containsKey(visit.Day_Attendance__c)) {
                visitsByAttendance.put(visit.Day_Attendance__c, new List<Visit__c>());
            }
            visitsByAttendance.get(visit.Day_Attendance__c).add(visit);
        }

        // Calculate cumulative distance for each attendance
        for (Id attId : attendanceIds) {
            Double totalDistance = 0;
            List<Visit__c> visits = visitsByAttendance.get(attId);

            if (visits != null && visits.size() > 1) {
                for (Integer i = 1; i < visits.size(); i++) {
                    Visit__c prev = visits[i - 1];
                    Visit__c curr = visits[i];
                    totalDistance += OVE_GeoValidation_Service.calculateDistance(
                        (Double) prev.Check_In_Latitude__c, (Double) prev.Check_In_Longitude__c,
                        (Double) curr.Check_In_Latitude__c, (Double) curr.Check_In_Longitude__c
                    );
                }
            }

            result.put(attId, totalDistance);
        }

        return result;
    }

    /**
     * @description Builds a composite key from user ID and date.
     */
    private String buildUserDateKey(Id userId, Date attendanceDate) {
        return String.valueOf(userId) + '|' + String.valueOf(attendanceDate);
    }
}
