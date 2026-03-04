/**
 * VisitManagerController
 * Unified Apex controller for the standalone Visit Management component.
 * Orchestrates Day Attendance, Visit lifecycle, and all visit activities
 * within a single-screen experience.
 */
public without sharing class VisitManagerController {

    // ──────────────────────────────────────────────────
    // 1. INITIALIZATION — Full context load on mount
    // ──────────────────────────────────────────────────
    @AuraEnabled
    public static Map<String, Object> getInitialContext() {
        Id userId = UserInfo.getUserId();
        Map<String, Object> ctx = new Map<String, Object>();

        // Current day attendance
        Day_Attendance__c dayAtt = DFO_DayAttendance_Service.getCurrentAttendance(userId);
        ctx.put('dayAttendance', dayAtt);
        ctx.put('isDayStarted', dayAtt != null);

        // Config
        ctx.put('config', getVisitConfig());

        if (dayAtt != null) {
            // Day stats
            ctx.put('dayStats', DFO_DayAttendance_Service.getDayStats(dayAtt.Id));

            // Active visit (in-progress)
            Visit__c activeVisit = getActiveVisit(userId);
            ctx.put('activeVisit', activeVisit);
            ctx.put('hasActiveVisit', activeVisit != null);

            if (activeVisit != null) {
                ctx.put('activeVisitSummary', getVisitSummaryData(activeVisit.Id));
                ctx.put('visitActivities', OVE_Visit_Service.getVisitActivities());
            }

            // Planned + today's visits
            Date today = Date.today();
            ctx.put('todaysVisits', OVE_Visit_Service.getTodaysVisits(userId));
            ctx.put('plannedVisits', OVE_Visit_Service.getPlannedVisits(userId, today));

            // Beat info
            ctx.put('currentBeat', dayAtt.Beat__r != null ? dayAtt.Beat__r.Name : '');
            ctx.put('beatId', dayAtt.Beat__c);
        }

        return ctx;
    }

    // ──────────────────────────────────────────────────
    // 2. DAY START
    // ──────────────────────────────────────────────────
    @AuraEnabled
    public static Day_Attendance__c startDay(String dayJson) {
        return DayAttendanceController.startDay(dayJson);
    }

    // ──────────────────────────────────────────────────
    // 3. DAY END
    // ──────────────────────────────────────────────────
    @AuraEnabled
    public static Day_Attendance__c endDay(String dayJson) {
        return DayAttendanceController.endDay(dayJson);
    }

    // ──────────────────────────────────────────────────
    // 4. VISIT CHECK-IN
    // ──────────────────────────────────────────────────
    @AuraEnabled
    public static Visit__c checkInVisit(String visitJson) {
        return VisitCheckInController.createVisit(visitJson);
    }

    // ──────────────────────────────────────────────────
    // 5. VISIT CHECK-OUT
    // ──────────────────────────────────────────────────
    @AuraEnabled
    public static Visit__c checkOutVisit(String visitJson) {
        return VisitCheckInController.completeVisit(visitJson);
    }

    // ──────────────────────────────────────────────────
    // 6. SKIP VISIT
    // ──────────────────────────────────────────────────
    @AuraEnabled
    public static Visit__c skipVisit(Id visitId, String skipReason) {
        return VisitCheckInController.skipVisit(visitId, skipReason);
    }

    // ──────────────────────────────────────────────────
    // 7. REFRESH DATA — Lightweight refresh endpoints
    // ──────────────────────────────────────────────────
    @AuraEnabled
    public static Map<String, Object> refreshDayData() {
        Id userId = UserInfo.getUserId();
        Map<String, Object> data = new Map<String, Object>();

        Day_Attendance__c dayAtt = DFO_DayAttendance_Service.getCurrentAttendance(userId);
        if (dayAtt != null) {
            data.put('dayStats', DFO_DayAttendance_Service.getDayStats(dayAtt.Id));
            data.put('todaysVisits', OVE_Visit_Service.getTodaysVisits(userId));
            data.put('plannedVisits', OVE_Visit_Service.getPlannedVisits(userId, Date.today()));

            Visit__c activeVisit = getActiveVisit(userId);
            data.put('activeVisit', activeVisit);
            data.put('hasActiveVisit', activeVisit != null);

            if (activeVisit != null) {
                data.put('activeVisitSummary', getVisitSummaryData(activeVisit.Id));
            }
        }

        return data;
    }

    @AuraEnabled
    public static Map<String, Object> refreshVisitSummary(Id visitId) {
        return getVisitSummaryData(visitId);
    }

    // ──────────────────────────────────────────────────
    // 8. OUTLET SEARCH (ad-hoc)
    // ──────────────────────────────────────────────────
    @AuraEnabled
    public static List<Account> searchOutlets(String searchTerm) {
        return VisitCheckInController.searchOutlets(searchTerm);
    }

    // ──────────────────────────────────────────────────
    // 9. EMPLOYEE SEARCH (companion)
    // ──────────────────────────────────────────────────
    @AuraEnabled
    public static List<Employee__c> searchEmployees(String searchTerm) {
        return DayAttendanceController.searchEmployees(searchTerm);
    }

    // ──────────────────────────────────────────────────
    // 10. GPS LOGGING
    // ──────────────────────────────────────────────────
    @AuraEnabled
    public static GPS_Log__c logGPS(GPS_Log__c gpsLog) {
        return DayAttendanceController.logGPS(gpsLog);
    }

    // ──────────────────────────────────────────────────
    // 11. VISIT ACTIVITIES & CONFIG
    // ──────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getVisitActivities() {
        return OVE_Visit_Service.getVisitActivities();
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getVisitConfig() {
        Map<String, Object> config = new Map<String, Object>();
        try {
            // Feature toggles
            config.put('selfieRequired', DFO_DayAttendance_Service.getConfigBoolean('SELFIE_REQUIRED', false));
            config.put('gpsTrackingEnabled', BPM_FeatureToggle_Util.isEnabled('DFO-002'));
            config.put('gpsTrackingInterval', DFO_DayAttendance_Service.getConfigInteger('GPS_TRACKING_INTERVAL', 300000));
            config.put('geofenceEnabled', BPM_FeatureToggle_Util.isEnabled('OVE-002'));
            config.put('adHocVisitsEnabled', BPM_FeatureToggle_Util.isEnabled('OVE-003'));
            config.put('photoRequiredCheckIn', DFO_DayAttendance_Service.getConfigBoolean('PHOTO_REQUIRED_CHECKIN', false));
            config.put('minVisitDuration', DFO_DayAttendance_Service.getConfigInteger('MIN_VISIT_DURATION_SEC', 60));
            config.put('maxVisitsPerDay', DFO_DayAttendance_Service.getConfigInteger('MAX_VISITS_PER_DAY', 50));
            config.put('statsRefreshInterval', DFO_DayAttendance_Service.getConfigInteger('STATS_REFRESH_INTERVAL', 60000));
            config.put('allowGeofenceOverride', DFO_DayAttendance_Service.getConfigBoolean('ALLOW_GEOFENCE_OVERRIDE', true));
        } catch (Exception e) {
            // Defaults if config fails
            config.put('selfieRequired', false);
            config.put('gpsTrackingEnabled', false);
            config.put('gpsTrackingInterval', 300000);
            config.put('geofenceEnabled', false);
            config.put('adHocVisitsEnabled', true);
            config.put('photoRequiredCheckIn', false);
            config.put('minVisitDuration', 60);
            config.put('maxVisitsPerDay', 50);
            config.put('statsRefreshInterval', 60000);
            config.put('allowGeofenceOverride', true);
        }
        return config;
    }

    // ──────────────────────────────────────────────────
    // 12. OUTLET SUMMARY (for check-in screen)
    // ──────────────────────────────────────────────────
    @AuraEnabled
    public static Map<String, Object> getOutletSummary(Id accountId) {
        return OVE_Visit_Service.getOutletSummary(accountId);
    }

    // ──────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ──────────────────────────────────────────────────

    private static Visit__c getActiveVisit(Id userId) {
        List<Visit__c> activeVisits = [
            SELECT Id, Name, Account__c, Account__r.Name, Account__r.BillingStreet,
                   Account__r.BillingCity, Beat__c, Beat__r.Name,
                   Visit_Status__c, Visit_Sequence__c, Check_In_Time__c,
                   Check_In_Lat__c, Check_In_Long__c, Is_Ad_Hoc__c, Is_Planned__c,
                   Order_Value__c, Collection_Amount__c, Total_Orders_Count__c,
                   Day_Attendance__c, Notes__c, Duration_Minutes__c,
                   Salesperson__c
            FROM Visit__c
            WHERE Salesperson__c = :userId
              AND Visit_Status__c IN ('Checked In', 'In Progress')
              AND DAY_ONLY(Check_In_Time__c) = TODAY
            ORDER BY Check_In_Time__c DESC
            LIMIT 1
        ];
        return activeVisits.isEmpty() ? null : activeVisits[0];
    }

    private static Map<String, Object> getVisitSummaryData(Id visitId) {
        Map<String, Object> summary = new Map<String, Object>();

        // Orders for this visit
        List<Sales_Order__c> orders = [
            SELECT Id, Name, Total_Net_Amount__c, Status__c, Total_Items__c,
                   CreatedDate
            FROM Sales_Order__c
            WHERE Visit__c = :visitId AND Status__c != 'Cancelled'
            ORDER BY CreatedDate DESC
        ];
        summary.put('orders', orders);
        summary.put('ordersCount', orders.size());

        Decimal totalOrderValue = 0;
        for (Sales_Order__c o : orders) {
            totalOrderValue += (o.Total_Net_Amount__c != null ? o.Total_Net_Amount__c : 0);
        }
        summary.put('totalOrderValue', totalOrderValue);

        // Collections for this visit
        List<Collection__c> collections = [
            SELECT Id, Name, Amount__c, Payment_Mode__c, Status__c, CreatedDate
            FROM Collection__c
            WHERE Visit__c = :visitId AND Status__c NOT IN ('Cancelled', 'Bounced')
            ORDER BY CreatedDate DESC
        ];
        summary.put('collections', collections);
        summary.put('collectionsCount', collections.size());

        Decimal totalCollection = 0;
        for (Collection__c c : collections) {
            totalCollection += (c.Amount__c != null ? c.Amount__c : 0);
        }
        summary.put('totalCollection', totalCollection);

        // Return orders for this visit
        List<Return_Order__c> returns = [
            SELECT Id, Name, Total_Return_Amount__c, Status__c, Return_Reason__c, CreatedDate
            FROM Return_Order__c
            WHERE Visit__c = :visitId AND Status__c != 'Cancelled'
            ORDER BY CreatedDate DESC
        ];
        summary.put('returns', returns);
        summary.put('returnsCount', returns.size());

        return summary;
    }
}
