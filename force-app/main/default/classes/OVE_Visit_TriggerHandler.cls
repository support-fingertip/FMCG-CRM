/**
 * @description Trigger handler for Visit__c. Manages geo-fence validation at
 *              check-in, Day_Attendance__c total updates, and productive call
 *              tracking upon visit completion.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public virtual with sharing class OVE_Visit_TriggerHandler extends TriggerHandler {

    /** Default geo-fence radius in meters (configurable via SFA_Settings__c). */
    private static final Double DEFAULT_GEOFENCE_RADIUS = 500.0;

    // ── Before Insert ─────────────────────────────────────────────────────────

    /**
     * @description Validates that the check-in location is within the
     *              configurable radius of the outlet's registered location.
     */
    protected override void beforeInsert() {
        List<Visit__c> newRecords = (List<Visit__c>) Trigger.new;
        validateGeoFence(newRecords);
    }

    // ── After Insert ──────────────────────────────────────────────────────────

    /**
     * @description Increments Total_Visits__c on the associated Day_Attendance__c
     *              record for each new visit.
     */
    protected override void afterInsert() {
        List<Visit__c> newRecords = (List<Visit__c>) Trigger.new;
        updateDayAttendanceTotals(newRecords, null);
    }

    // ── After Update ──────────────────────────────────────────────────────────

    /**
     * @description When Visit_Status__c changes to 'Completed', updates
     *              productive call counts and order values on Day_Attendance__c.
     */
    protected override void afterUpdate() {
        List<Visit__c> newRecords = (List<Visit__c>) Trigger.new;
        Map<Id, Visit__c> oldMap = (Map<Id, Visit__c>) Trigger.oldMap;

        List<Visit__c> completedVisits = new List<Visit__c>();
        for (Visit__c rec : newRecords) {
            Visit__c oldRec = oldMap.get(rec.Id);
            if (rec.Visit_Status__c == 'Completed' &&
                oldRec.Visit_Status__c != 'Completed') {
                completedVisits.add(rec);
            }
        }

        if (!completedVisits.isEmpty()) {
            updateProductiveCallCounts(completedVisits);
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * @description Validates check-in geo-coordinates against the outlet's
     *              registered location using the Haversine formula.
     * @param records The Visit__c records to validate.
     */
    private void validateGeoFence(List<Visit__c> records) {
        Map<String, Schema.SObjectField> visitFields = Schema.sObjectType.Visit__c.fields.getMap();
        if (!visitFields.containsKey('Outlet__c') ||
            !visitFields.containsKey('Check_In_Latitude__c') ||
            !visitFields.containsKey('Check_In_Longitude__c')) {
            for (Visit__c visit : records) {
                visit.addError('Visit__c is missing one or more required geo fields.');
            }
            return;
        }

        Map<String, Schema.SObjectField> accountFields = Schema.sObjectType.Account.fields.getMap();
        if (!accountFields.containsKey('Outlet_Latitude__c') ||
            !accountFields.containsKey('Outlet_Longitude__c') ||
            !accountFields.containsKey('Geofence_Radius__c')) {
            for (Visit__c visit : records) {
                visit.addError('Account is missing one or more required geo fields.');
            }
            return;
        }

        // Collect outlet (Account) IDs for location lookup
        Set<Id> outletIds = new Set<Id>();
        for (Visit__c visit : records) {
            if (visit.Outlet__c != null) {
                outletIds.add(visit.Outlet__c);
            } else {
                visit.addError('Outlet is required for check-in validation.');
            }
        }

        if (outletIds.isEmpty()) {
            return;
        }

        // Fetch outlet locations
        Map<Id, Account> outletMap = new Map<Id, Account>([
            SELECT Id, Outlet_Latitude__c, Outlet_Longitude__c,
                   Geofence_Radius__c
            FROM Account
            WHERE Id IN :outletIds
        ]);

        // Get configurable default radius
        Double defaultRadius = getConfiguredRadius();

        for (Visit__c visit : records) {
            // Skip validation if no GPS coordinates provided
            if (visit.Check_In_Latitude__c == null ||
                visit.Check_In_Longitude__c == null) {
                continue;
            }

            Account outlet = outletMap.get(visit.Outlet__c);
            if (outlet == null) {
                visit.addError('Outlet record is missing for check-in validation.');
                continue;
            }
            if (outlet.Outlet_Latitude__c == null ||
                outlet.Outlet_Longitude__c == null) {
                visit.addError('Outlet latitude/longitude is required for check-in validation.');
                continue;
            }

            // Use outlet-specific radius or default
            Double radiusMeters = outlet.Geofence_Radius__c != null
                ? outlet.Geofence_Radius__c
                : defaultRadius;

            Boolean withinRadius = OVE_GeoValidation_Service.validateCheckInProximity(
                visit.Check_In_Latitude__c,
                visit.Check_In_Longitude__c,
                outlet.Outlet_Latitude__c,
                outlet.Outlet_Longitude__c,
                radiusMeters
            );

            if (!withinRadius) {
                Double distance = OVE_GeoValidation_Service.calculateDistance(
                    visit.Check_In_Latitude__c,
                    visit.Check_In_Longitude__c,
                    outlet.Outlet_Latitude__c,
                    outlet.Outlet_Longitude__c
                );

                visit.addError(
                    'Check-in location is ' + Decimal.valueOf(distance).setScale(0) +
                    'm from the outlet, which exceeds the allowed radius of ' +
                    Decimal.valueOf(radiusMeters).setScale(0) + 'm. ' +
                    'Please check in from the outlet\'s registered location.'
                );
            }
        }
    }

    /**
     * @description Updates Total_Visits__c on Day_Attendance__c records.
     *              Aggregates visit counts per attendance record for bulk safety.
     * @param newVisits The new Visit__c records.
     * @param oldMap    Map of old Visit__c values (null for insert context).
     */
    private void updateDayAttendanceTotals(
        List<Visit__c> newVisits,
        Map<Id, Visit__c> oldMap
    ) {
        // Collect Day_Attendance__c IDs
        Set<Id> attendanceIds = new Set<Id>();
        for (Visit__c visit : newVisits) {
            if (visit.Day_Attendance__c != null) {
                attendanceIds.add(visit.Day_Attendance__c);
            }
        }

        if (attendanceIds.isEmpty()) {
            return;
        }

        // Aggregate total visits per attendance record
        Map<Id, Integer> visitCountByAttendance = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Day_Attendance__c attendanceId, COUNT(Id) visitCount
            FROM Visit__c
            WHERE Day_Attendance__c IN :attendanceIds
            GROUP BY Day_Attendance__c
        ]) {
            Id attId = (Id) ar.get('attendanceId');
            Integer count = (Integer) ar.get('visitCount');
            visitCountByAttendance.put(attId, count);
        }

        // Update Day_Attendance__c records
        List<Day_Attendance__c> attendancesToUpdate = new List<Day_Attendance__c>();
        for (Id attId : attendanceIds) {
            attendancesToUpdate.add(new Day_Attendance__c(
                Id = attId,
                Total_Visits__c = visitCountByAttendance.containsKey(attId)
                    ? visitCountByAttendance.get(attId) : 0
            ));
        }

        if (!attendancesToUpdate.isEmpty()) {
            update attendancesToUpdate;
        }
    }

    /**
     * @description Updates productive call counts and order values on
     *              Day_Attendance__c when visits are completed.
     * @param completedVisits The visits that just transitioned to 'Completed'.
     */
    private void updateProductiveCallCounts(List<Visit__c> completedVisits) {
        // Collect Day_Attendance__c IDs from completed visits
        Set<Id> attendanceIds = new Set<Id>();
        for (Visit__c visit : completedVisits) {
            if (visit.Day_Attendance__c != null) {
                attendanceIds.add(visit.Day_Attendance__c);
            }
        }

        if (attendanceIds.isEmpty()) {
            return;
        }

        // Aggregate productive visits and order values per attendance record
        Map<Id, Integer> productiveCountByAttendance = new Map<Id, Integer>();
        Map<Id, Decimal> orderValueByAttendance = new Map<Id, Decimal>();

        for (AggregateResult ar : [
            SELECT Day_Attendance__c attendanceId,
                   COUNT(Id) productiveCount,
                   SUM(Order_Value__c) totalOrderValue
            FROM Visit__c
            WHERE Day_Attendance__c IN :attendanceIds
              AND Visit_Status__c = 'Completed'
              AND Is_Productive__c = true
            GROUP BY Day_Attendance__c
        ]) {
            Id attId = (Id) ar.get('attendanceId');
            productiveCountByAttendance.put(attId, (Integer) ar.get('productiveCount'));
            Decimal orderVal = (Decimal) ar.get('totalOrderValue');
            orderValueByAttendance.put(attId, orderVal != null ? orderVal : 0);
        }

        // Update Day_Attendance__c records
        List<Day_Attendance__c> attendancesToUpdate = new List<Day_Attendance__c>();
        for (Id attId : attendanceIds) {
            attendancesToUpdate.add(new Day_Attendance__c(
                Id = attId,
                Productive_Calls__c = productiveCountByAttendance.containsKey(attId)
                    ? productiveCountByAttendance.get(attId) : 0,
                Total_Order_Value__c = orderValueByAttendance.containsKey(attId)
                    ? orderValueByAttendance.get(attId) : 0
            ));
        }

        if (!attendancesToUpdate.isEmpty()) {
            update attendancesToUpdate;
        }
    }

    /**
     * @description Retrieves the configured default geo-fence radius from
     *              Geo_Config__mdt custom metadata.
     * @return The configured radius in meters, or the default value.
     */
    private Double getConfiguredRadius() {
        try {
            // Get geo-fence radius from custom metadata
            Double configuredRadius = DEFAULT_GEOFENCE_RADIUS;
            String geoConfigRadiusType = 'Geofence_Radius_Meters';
            
            List<Geo_Config__mdt> geoConfigs = [
                SELECT Value__c
                FROM Geo_Config__mdt
                WHERE Config_Type__c = :geoConfigRadiusType
                LIMIT 1
            ];
            if (!geoConfigs.isEmpty() && geoConfigs[0].Value__c != null) {
                try {
                    configuredRadius = Double.valueOf(geoConfigs[0].Value__c);
                } catch (Exception ex) {
                    // Fall back to default radius
                    configuredRadius = DEFAULT_GEOFENCE_RADIUS;
                }
            }
            return configuredRadius;
        } catch (Exception e) {
            // Custom metadata may not exist; fall back to default
            return DEFAULT_GEOFENCE_RADIUS;
        }
    }
}