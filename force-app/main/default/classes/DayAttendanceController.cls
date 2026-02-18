/**
 * @description Controller for the Day Attendance LWC component.
 *              Manages daily attendance lifecycle: day-start with selfie and GPS,
 *              day-end with summary calculation, intra-day stats, and GPS breadcrumb logging.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class DayAttendanceController {

    // ── Start Day ───────────────────────────────────────────────────────────────

    /**
     * @description Creates a Day Attendance record to mark the start of a working day.
     *              Validates that no duplicate attendance exists for the same date.
     * @param attendance The Day_Attendance__c record pre-populated with start fields.
     * @return The inserted Day_Attendance__c record.
     */
    @AuraEnabled
    public static Day_Attendance__c startDay(Day_Attendance__c attendance) {
        try {
            // Check for existing attendance on the same date for this user
            Date attendanceDate = attendance.Attendance_Date__c != null
                ? attendance.Attendance_Date__c
                : Date.today();

            List<Day_Attendance__c> existing = [
                SELECT Id, Status__c
                FROM Day_Attendance__c
                WHERE Salesperson__c = :attendance.Salesperson__c
                AND Attendance_Date__c = :attendanceDate
                LIMIT 1
            ];

            if (!existing.isEmpty()) {
                throw new AuraHandledException(
                    'Day attendance has already been recorded for this date. Status: ' +
                    existing[0].Status__c
                );
            }

            attendance.Attendance_Date__c = attendanceDate;
            if (attendance.Day_Start_Time__c == null) {
                attendance.Day_Start_Time__c = Datetime.now();
            }
            attendance.Status__c = 'Started';
            attendance.Total_Visits__c = 0;
            attendance.Productive_Calls__c = 0;
            attendance.Total_Orders__c = 0;
            attendance.Total_Order_Value__c = 0;
            attendance.Total_Collection__c = 0;

            insert attendance;

            return [
                SELECT Id, Name, Attendance_Date__c, Day_Start_Time__c, Status__c,
                       Start_Location_Lat__c, Start_Location_Long__c,
                       Start_Selfie_URL__c, Salesperson__c, Salesperson__r.Name
                FROM Day_Attendance__c
                WHERE Id = :attendance.Id
                LIMIT 1
            ];
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── End Day ─────────────────────────────────────────────────────────────────

    /**
     * @description Marks day-end on an existing attendance record, calculating
     *              summary metrics from the day's visits and orders.
     * @param attendanceId The Id of the Day_Attendance__c record.
     * @return The updated Day_Attendance__c record.
     */
    @AuraEnabled
    public static Day_Attendance__c endDay(Id attendanceId) {
        try {
            Day_Attendance__c attendance = [
                SELECT Id, Salesperson__c, Attendance_Date__c, Day_Start_Time__c, Status__c
                FROM Day_Attendance__c
                WHERE Id = :attendanceId
                LIMIT 1
            ];

            if (attendance.Status__c == 'Completed') {
                throw new AuraHandledException('This day has already been ended.');
            }

            attendance.Day_End_Time__c = Datetime.now();
            attendance.Status__c = 'Completed';

            // Calculate summary from today's visits
            Date attendanceDate = attendance.Attendance_Date__c;
            Id salespersonId = attendance.Salesperson__c;

            AggregateResult[] visitStats = [
                SELECT COUNT(Id) totalVisits,
                       SUM(Order_Value__c) totalOrderValue,
                       SUM(Collection_Amount__c) totalCollection
                FROM Visit__c
                WHERE Salesperson__c = :salespersonId
                AND Visit_Date__c = :attendanceDate
                AND Visit_Status__c = 'Completed'
            ];

            if (!visitStats.isEmpty()) {
                attendance.Total_Visits__c = (Integer)visitStats[0].get('totalVisits');
                Decimal orderVal = (Decimal)visitStats[0].get('totalOrderValue');
                attendance.Total_Order_Value__c = orderVal != null ? orderVal : 0;
                Decimal collVal = (Decimal)visitStats[0].get('totalCollection');
                attendance.Total_Collection__c = collVal != null ? collVal : 0;
            }

            // Count productive visits
            Integer productiveCalls = [
                SELECT COUNT()
                FROM Visit__c
                WHERE Salesperson__c = :salespersonId
                AND Visit_Date__c = :attendanceDate
                AND Visit_Status__c = 'Completed'
                AND Is_Productive__c = true
            ];
            attendance.Productive_Calls__c = productiveCalls;

            // Count orders placed today
            Integer totalOrders = [
                SELECT COUNT()
                FROM Sales_Order__c
                WHERE Salesperson__c = :salespersonId
                AND Order_Date__c = :attendanceDate
            ];
            attendance.Total_Orders__c = totalOrders;

            // Calculate distance traveled from GPS logs
            List<GPS_Log__c> gpsLogs = [
                SELECT Latitude__c, Longitude__c, Captured_At__c
                FROM GPS_Log__c
                WHERE Day_Attendance__c = :attendanceId
                ORDER BY Captured_At__c ASC
            ];
            if (gpsLogs.size() > 1) {
                Double totalDistance = 0;
                for (Integer i = 1; i < gpsLogs.size(); i++) {
                    totalDistance += calculateDistance(
                        gpsLogs[i - 1].Latitude__c, gpsLogs[i - 1].Longitude__c,
                        gpsLogs[i].Latitude__c, gpsLogs[i].Longitude__c
                    );
                }
                // Convert metres to kilometres
                attendance.Distance_Traveled_Km__c = Decimal.valueOf(totalDistance / 1000).setScale(2, RoundingMode.HALF_UP);
            }

            // Set end location from last GPS log
            if (!gpsLogs.isEmpty()) {
                GPS_Log__c lastLog = gpsLogs[gpsLogs.size() - 1];
                attendance.End_Location_Lat__c = lastLog.Latitude__c;
                attendance.End_Location_Long__c = lastLog.Longitude__c;
            }

            update attendance;

            return [
                SELECT Id, Name, Attendance_Date__c, Day_Start_Time__c, Day_End_Time__c,
                       Status__c, Total_Visits__c, Productive_Calls__c, Total_Orders__c,
                       Total_Order_Value__c, Total_Collection__c, Distance_Traveled_Km__c,
                       End_Location_Lat__c, End_Location_Long__c
                FROM Day_Attendance__c
                WHERE Id = :attendanceId
                LIMIT 1
            ];
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Get Day Stats ───────────────────────────────────────────────────────────

    /**
     * @description Retrieves real-time day statistics for a given user and date.
     * @param userId The Salesperson (User) Id.
     * @param attendanceDate The date to query stats for.
     * @return Map with totalVisits, productiveCalls, totalOrders, totalOrderValue,
     *         totalCollection, distanceTraveled.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDayStats(Id userId, Date attendanceDate) {
        Map<String, Object> stats = new Map<String, Object>();

        // Visit statistics
        AggregateResult[] visitAgg = [
            SELECT COUNT(Id) totalVisits,
                   SUM(Order_Value__c) totalOrderValue,
                   SUM(Collection_Amount__c) totalCollection
            FROM Visit__c
            WHERE Salesperson__c = :userId
            AND Visit_Date__c = :attendanceDate
            AND Visit_Status__c = 'Completed'
        ];

        Integer totalVisits = 0;
        Decimal totalOrderValue = 0;
        Decimal totalCollection = 0;
        if (!visitAgg.isEmpty()) {
            totalVisits = (Integer)visitAgg[0].get('totalVisits');
            Decimal ov = (Decimal)visitAgg[0].get('totalOrderValue');
            totalOrderValue = ov != null ? ov : 0;
            Decimal cv = (Decimal)visitAgg[0].get('totalCollection');
            totalCollection = cv != null ? cv : 0;
        }

        Integer productiveCalls = [
            SELECT COUNT()
            FROM Visit__c
            WHERE Salesperson__c = :userId
            AND Visit_Date__c = :attendanceDate
            AND Visit_Status__c = 'Completed'
            AND Is_Productive__c = true
        ];

        Integer totalOrders = [
            SELECT COUNT()
            FROM Sales_Order__c
            WHERE Salesperson__c = :userId
            AND Order_Date__c = :attendanceDate
        ];

        stats.put('totalVisits', totalVisits);
        stats.put('productiveCalls', productiveCalls);
        stats.put('totalOrders', totalOrders);
        stats.put('totalOrderValue', totalOrderValue);
        stats.put('totalCollection', totalCollection);

        // Distance from attendance record
        List<Day_Attendance__c> att = [
            SELECT Distance_Traveled_Km__c
            FROM Day_Attendance__c
            WHERE Salesperson__c = :userId
            AND Attendance_Date__c = :attendanceDate
            LIMIT 1
        ];
        stats.put('distanceTraveled', att.isEmpty() ? 0 : att[0].Distance_Traveled_Km__c);

        return stats;
    }

    // ── Get Current Day Attendance ──────────────────────────────────────────────

    /**
     * @description Retrieves today's Day_Attendance__c record for the given user,
     *              if one exists.
     * @param userId The Salesperson (User) Id.
     * @return The Day_Attendance__c record or null.
     */
    @AuraEnabled(cacheable=true)
    public static Day_Attendance__c getCurrentDayAttendance(Id userId) {
        Date today = Date.today();
        List<Day_Attendance__c> records = [
            SELECT Id, Name, Attendance_Date__c, Day_Start_Time__c, Day_End_Time__c,
                   Status__c, Start_Location_Lat__c, Start_Location_Long__c,
                   End_Location_Lat__c, End_Location_Long__c,
                   Start_Selfie_URL__c, Total_Visits__c, Productive_Calls__c,
                   Total_Orders__c, Total_Order_Value__c, Total_Collection__c,
                   Distance_Traveled_Km__c, Battery_Level__c, Device_Info__c
            FROM Day_Attendance__c
            WHERE Salesperson__c = :userId
            AND Attendance_Date__c = :today
            LIMIT 1
        ];
        return records.isEmpty() ? null : records[0];
    }

    // ── Log GPS Breadcrumb ──────────────────────────────────────────────────────

    /**
     * @description Creates a GPS breadcrumb log entry for tracking field movement.
     * @param gpsLog The GPS_Log__c record with latitude, longitude, and timestamp.
     * @return The inserted GPS_Log__c record.
     */
    @AuraEnabled
    public static GPS_Log__c logGPS(GPS_Log__c gpsLog) {
        try {
            if (gpsLog.Captured_At__c == null) {
                gpsLog.Captured_At__c = Datetime.now();
            }
            if (gpsLog.Is_Offline_Captured__c == null) {
                gpsLog.Is_Offline_Captured__c = false;
            }
            insert gpsLog;
            return gpsLog;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Private Helper: Haversine Distance ──────────────────────────────────────

    private static Double calculateDistance(Decimal lat1, Decimal lon1, Decimal lat2, Decimal lon2) {
        if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
            return 0;
        }
        Double earthRadius = 6371000; // metres
        Double dLat = toRadians(lat2.doubleValue() - lat1.doubleValue());
        Double dLon = toRadians(lon2.doubleValue() - lon1.doubleValue());
        Double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                   Math.cos(toRadians(lat1.doubleValue())) * Math.cos(toRadians(lat2.doubleValue())) *
                   Math.sin(dLon / 2) * Math.sin(dLon / 2);
        Double c = 2 * Math.asin(Math.sqrt(a));
        return earthRadius * c;
    }

    private static Double toRadians(Double degrees) {
        return degrees * Math.PI / 180;
    }
}
