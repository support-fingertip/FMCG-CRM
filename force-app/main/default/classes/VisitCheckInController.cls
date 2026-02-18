/**
 * @description Controller for the Visit Check-In / Check-Out LWC component.
 *              Manages field visit lifecycle including geo-fenced check-in,
 *              outlet summary retrieval, and daily visit tracking for FMCG sales reps.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class VisitCheckInController {

    // ── Constants ────────────────────────────────────────────────────────────────

    private static final String GEO_CONFIG_RADIUS = 'Geofence_Radius_Meters';
    private static final Double DEFAULT_RADIUS_METERS = 200.0;
    private static final Double EARTH_RADIUS_METERS = 6371000.0;

    // ── Create Visit (Check-In) ─────────────────────────────────────────────────

    /**
     * @description Creates a new Visit record with check-in data (timestamp, GPS coords).
     * @param visit The Visit__c record pre-populated with check-in fields by the LWC.
     * @return The inserted Visit__c record with Id and Name.
     */
    @AuraEnabled
    public static Visit__c createVisit(Visit__c visit) {
        try {
            if (visit.Check_In_Time__c == null) {
                visit.Check_In_Time__c = Datetime.now();
            }
            if (visit.Visit_Date__c == null) {
                visit.Visit_Date__c = Date.today();
            }
            visit.Visit_Status__c = 'In Progress';
            insert visit;
            return [
                SELECT Id, Name, Account__c, Account__r.Name, Check_In_Time__c,
                       Check_In_Lat__c, Check_In_Long__c, Visit_Status__c, Visit_Date__c
                FROM Visit__c
                WHERE Id = :visit.Id
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Complete Visit (Check-Out) ──────────────────────────────────────────────

    /**
     * @description Updates a Visit record with check-out data and calculates duration.
     * @param visitId The Id of the Visit to complete.
     * @param updates A Visit__c instance carrying check-out field values.
     * @return The updated Visit__c record.
     */
    @AuraEnabled
    public static Visit__c completeVisit(Id visitId, Visit__c updates) {
        try {
            Visit__c visit = [
                SELECT Id, Check_In_Time__c, Visit_Status__c
                FROM Visit__c
                WHERE Id = :visitId
                LIMIT 1
            ];

            if (visit.Visit_Status__c == 'Completed') {
                throw new AuraHandledException('This visit has already been completed.');
            }

            visit.Check_Out_Time__c = updates.Check_Out_Time__c != null
                ? updates.Check_Out_Time__c
                : Datetime.now();
            visit.Check_Out_Lat__c = updates.Check_Out_Lat__c;
            visit.Check_Out_Long__c = updates.Check_Out_Long__c;
            visit.Notes__c = updates.Notes__c;
            visit.Is_Productive__c = updates.Is_Productive__c;
            visit.Non_Productive_Reason__c = updates.Non_Productive_Reason__c;
            visit.Order_Value__c = updates.Order_Value__c;
            visit.Collection_Amount__c = updates.Collection_Amount__c;
            visit.Visit_Status__c = 'Completed';

            // Calculate duration in minutes
            if (visit.Check_In_Time__c != null && visit.Check_Out_Time__c != null) {
                Long milliseconds = visit.Check_Out_Time__c.getTime() - visit.Check_In_Time__c.getTime();
                visit.Duration_Minutes__c = Decimal.valueOf(milliseconds) / 60000;
            }

            update visit;

            return [
                SELECT Id, Name, Account__c, Account__r.Name, Check_In_Time__c,
                       Check_Out_Time__c, Duration_Minutes__c, Visit_Status__c,
                       Is_Productive__c, Order_Value__c, Collection_Amount__c
                FROM Visit__c
                WHERE Id = :visitId
                LIMIT 1
            ];
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Outlet Summary ──────────────────────────────────────────────────────────

    /**
     * @description Retrieves a summary of key metrics for a given outlet (Account).
     * @param accountId The Account Id.
     * @return Map with lastVisitDate, pendingOrders, outstandingBalance, applicableSchemes.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getOutletSummary(Id accountId) {
        Map<String, Object> summary = new Map<String, Object>();

        // Last visit date
        List<Visit__c> lastVisits = [
            SELECT Id, Visit_Date__c
            FROM Visit__c
            WHERE Account__c = :accountId AND Visit_Status__c = 'Completed'
            ORDER BY Visit_Date__c DESC
            LIMIT 1
        ];
        summary.put('lastVisitDate', lastVisits.isEmpty() ? null : lastVisits[0].Visit_Date__c);

        // Pending orders count
        Integer pendingOrders = [
            SELECT COUNT()
            FROM Sales_Order__c
            WHERE Account__c = :accountId
            AND Status__c IN ('Draft', 'Submitted', 'Approved')
        ];
        summary.put('pendingOrders', pendingOrders);

        // Outstanding balance from invoices
        AggregateResult[] balanceResult = [
            SELECT SUM(Balance_Due__c) totalBalance
            FROM Invoice__c
            WHERE Account__c = :accountId
            AND Status__c != 'Cancelled'
            AND Balance_Due__c > 0
        ];
        Decimal outstandingBalance = balanceResult.isEmpty()
            ? 0
            : (Decimal)balanceResult[0].get('totalBalance');
        summary.put('outstandingBalance', outstandingBalance != null ? outstandingBalance : 0);

        // Count of active schemes applicable today
        Date today = Date.today();
        Integer applicableSchemes = [
            SELECT COUNT()
            FROM Scheme__c
            WHERE Status__c = 'Active'
            AND Start_Date__c <= :today
            AND End_Date__c >= :today
        ];
        summary.put('applicableSchemes', applicableSchemes);

        return summary;
    }

    // ── Today's Visits ──────────────────────────────────────────────────────────

    /**
     * @description Retrieves all visits created today for a given user.
     * @param userId The Salesperson (User) Id.
     * @return List of today's Visit__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Visit__c> getTodaysVisits(Id userId) {
        Date today = Date.today();
        return [
            SELECT Id, Name, Account__c, Account__r.Name, Visit_Date__c,
                   Check_In_Time__c, Check_Out_Time__c, Visit_Status__c,
                   Duration_Minutes__c, Is_Productive__c, Is_Planned__c,
                   Order_Value__c, Collection_Amount__c, Visit_Sequence__c
            FROM Visit__c
            WHERE Salesperson__c = :userId
            AND Visit_Date__c = :today
            ORDER BY Check_In_Time__c ASC
        ];
    }

    // ── Geo-Fence Validation ────────────────────────────────────────────────────

    /**
     * @description Validates whether the salesperson's current position is within the
     *              configured geo-fence radius of the outlet using the Haversine formula.
     *              The radius is read from Geo_Config__mdt custom metadata.
     * @param lat  Latitude of the salesperson's current position.
     * @param lng  Longitude of the salesperson's current position.
     * @param accountId The outlet Account Id whose location is the geo-fence centre.
     * @return Map with 'isWithinFence' (Boolean), 'distance' (Decimal metres),
     *         and 'allowedRadius' (Decimal metres).
     */
    @AuraEnabled
    public static Map<String, Object> validateGeoFence(Decimal lat, Decimal lng, Id accountId) {
        try {
            Map<String, Object> result = new Map<String, Object>();

            // Get geo-fence radius from custom metadata
            Double allowedRadius = DEFAULT_RADIUS_METERS;
            List<Geo_Config__mdt> geoConfigs = [
                SELECT Value__c
                FROM Geo_Config__mdt
                WHERE Config_Type__c = :GEO_CONFIG_RADIUS
                LIMIT 1
            ];
            if (!geoConfigs.isEmpty() && geoConfigs[0].Value__c != null) {
                try {
                    allowedRadius = Double.valueOf(geoConfigs[0].Value__c);
                } catch (Exception ex) {
                    // Fall back to default radius
                    allowedRadius = DEFAULT_RADIUS_METERS;
                }
            }

            // Get outlet coordinates from Account (ShippingLatitude / ShippingLongitude)
            Account outlet = [
                SELECT Id, ShippingLatitude, ShippingLongitude
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            if (outlet.ShippingLatitude == null || outlet.ShippingLongitude == null) {
                // No outlet coordinates configured, allow check-in
                result.put('isWithinFence', true);
                result.put('distance', 0);
                result.put('allowedRadius', allowedRadius);
                result.put('message', 'Outlet location not configured. Geo-fence check skipped.');
                return result;
            }

            // Haversine formula to calculate distance in metres
            Double distance = calculateHaversineDistance(
                lat.doubleValue(), lng.doubleValue(),
                (Double) outlet.ShippingLatitude, (Double) outlet.ShippingLongitude
            );

            Boolean isWithinFence = distance <= allowedRadius;

            result.put('isWithinFence', isWithinFence);
            result.put('distance', Math.round(distance * 100) / 100.0);
            result.put('allowedRadius', allowedRadius);
            if (!isWithinFence) {
                result.put('message', 'You are ' + String.valueOf(Math.round(distance)) +
                    'm from the outlet. Allowed radius is ' + String.valueOf(Math.round(allowedRadius)) + 'm.');
            }

            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Haversine Distance Helper ───────────────────────────────────────────────

    /**
     * @description Calculates the great-circle distance between two GPS points
     *              using the Haversine formula.
     * @return Distance in metres.
     */
    private static Double calculateHaversineDistance(
        Double lat1, Double lon1, Double lat2, Double lon2
    ) {
        Double dLat = toRadians(lat2 - lat1);
        Double dLon = toRadians(lon2 - lon1);

        Double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                   Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
                   Math.sin(dLon / 2) * Math.sin(dLon / 2);
        Double c = 2 * Math.asin(Math.sqrt(a));

        return EARTH_RADIUS_METERS * c;
    }

    // ── Visit Activities ────────────────────────────────────────────────────────

    /**
     * @description Returns the list of standard visit activity types available
     *              during a field visit check-in.
     * @return List of activity definition maps with id, label, and icon.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getVisitActivities() {
        List<Map<String, String>> activities = new List<Map<String, String>>();
        activities.add(new Map<String, String>{ 'id' => 'order', 'label' => 'Order', 'icon' => 'standard:orders' });
        activities.add(new Map<String, String>{ 'id' => 'collection', 'label' => 'Collection', 'icon' => 'standard:currency' });
        activities.add(new Map<String, String>{ 'id' => 'merchandising', 'label' => 'Merchandising', 'icon' => 'standard:product_item' });
        activities.add(new Map<String, String>{ 'id' => 'survey', 'label' => 'Survey', 'icon' => 'standard:survey' });
        return activities;
    }

    private static Double toRadians(Double degrees) {
        return degrees * Math.PI / 180;
    }
}
