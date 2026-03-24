/**
 * @description Controller for the Day Attendance LWC components.
 *              Thin @AuraEnabled wrapper that delegates all business logic
 *              to DFO_DayAttendance_Service.
 *
 * @author  SFA Development Team
 * @date    2026
 */
public with sharing class DayAttendanceController {

    /**
     * @description Starts a new day for the current user.
     * @param dayJson JSON string with DayStartRequest fields.
     * @return The created Day_Attendance__c record.
     */
    @AuraEnabled
    public static Day_Attendance__c startDay(String dayJson) {
        try {
            DFO_DayAttendance_Service.DayStartRequest request =
                (DFO_DayAttendance_Service.DayStartRequest)
                JSON.deserialize(dayJson, DFO_DayAttendance_Service.DayStartRequest.class);
            return DFO_DayAttendance_Service.startDay(request);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Ends the current day for the user.
     * @param dayJson JSON string with DayEndRequest fields.
     * @return The updated Day_Attendance__c record.
     */
    @AuraEnabled
    public static Day_Attendance__c endDay(String dayJson) {
        try {
            DFO_DayAttendance_Service.DayEndRequest request =
                (DFO_DayAttendance_Service.DayEndRequest)
                JSON.deserialize(dayJson, DFO_DayAttendance_Service.DayEndRequest.class);
            return DFO_DayAttendance_Service.endDay(request);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets real-time day stats for the attendance dashboard.
     * @param dayId The Day_Attendance__c record Id.
     * @return Map of stat key-value pairs.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDayStats(Id dayId) {
        try {
            return DFO_DayAttendance_Service.getDayStats(dayId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets the current day's attendance for a user.
     * @param userId Optional User Id (defaults to current user).
     * @return The Day_Attendance__c record or null.
     */
    @AuraEnabled(cacheable=true)
    public static Day_Attendance__c getCurrentDayAttendance(Id userId) {
        try {
            return DFO_DayAttendance_Service.getCurrentAttendance(userId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Logs a single GPS breadcrumb.
     * @param gpsLog The GPS_Log__c record to insert.
     * @return The inserted GPS_Log__c record.
     */
    @AuraEnabled
    public static GPS_Log__c logGPS(GPS_Log__c gpsLog) {
        try {
            return DFO_DayAttendance_Service.logGPS(gpsLog);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Syncs offline GPS logs in bulk.
     * @param gpsLogsJson JSON array of GPS_Log__c records.
     * @return List of inserted GPS_Log__c records.
     */
    @AuraEnabled
    public static List<GPS_Log__c> syncOfflineGPSLogs(String gpsLogsJson) {
        try {
            List<GPS_Log__c> gpsLogs = (List<GPS_Log__c>) JSON.deserialize(gpsLogsJson, List<GPS_Log__c>.class);
            return DFO_DayAttendance_Service.logGPSBatch(gpsLogs);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets team attendance for the current manager on a given date.
     * @param attendanceDate The date to query.
     * @return List of Day_Attendance__c records for direct reports.
     */
    @AuraEnabled(cacheable=true)
    public static List<Day_Attendance__c> getTeamAttendance(Date attendanceDate) {
        try {
            return DFO_DayAttendance_Service.getTeamAttendance(UserInfo.getUserId(), attendanceDate);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets team attendance summary for a date range.
     * @param fromDate Start of range.
     * @param toDate End of range.
     * @return List of aggregate summary maps per user.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getTeamAttendanceSummary(Date fromDate, Date toDate) {
        try {
            return DFO_DayAttendance_Service.getTeamAttendanceSummary(UserInfo.getUserId(), fromDate, toDate);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Gets app configuration values for the LWC.
     * @return Map of config key-value pairs relevant to DFO module.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getAttendanceConfig() {
        try {
            Map<String, Object> config = new Map<String, Object>();
            config.put('selfieRequired', DFO_DayAttendance_Service.getConfigBoolean('SELFIE_REQUIRED', false));
            config.put('gpsTrackingInterval', DFO_DayAttendance_Service.getConfigInteger('GPS_TRACKING_INTERVAL_SEC', 300));
            config.put('statsRefreshInterval', DFO_DayAttendance_Service.getConfigInteger('STATS_REFRESH_INTERVAL_SEC', 60));
            config.put('gpsTrackingEnabled', BPM_FeatureToggle_Util.isEnabled(DFO_DayAttendance_Service.FEATURE_GPS_TRACKING));
            config.put('managerDashboardEnabled', BPM_FeatureToggle_Util.isEnabled(DFO_DayAttendance_Service.FEATURE_MANAGER_DASH));
            return config;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Searches employees by name for the companion lookup.
     * @param searchTerm The search string to match against employee names.
     * @return List of matching Employee__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Employee__c> searchEmployees(String searchTerm) {
        try {
            if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
                return new List<Employee__c>();
            }
            String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            return [
                SELECT Id, Name, First_Name__c, Last_Name__c, Employee_Code__c, Designation__c
                FROM Employee__c
                WHERE (First_Name__c LIKE :searchPattern
                       OR Last_Name__c LIKE :searchPattern
                       OR Employee_Code__c LIKE :searchPattern)
                  AND Is_Active__c = true
                ORDER BY First_Name__c ASC
                LIMIT 20
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}