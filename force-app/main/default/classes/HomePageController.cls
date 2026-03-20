/**
 * Controller for the Home Page component.
 * Provides summary counts and quick-access data for the dashboard tiles.
 */
public with sharing class HomePageController {

    @AuraEnabled(cacheable=true)
    public static HomePageData getHomePageData() {
        HomePageData data = new HomePageData();
        Id userId = UserInfo.getUserId();
        Date today = Date.today();

        // ── Today's Visits ──
        data.todayVisitCount = [
            SELECT COUNT()
            FROM Visit__c
            WHERE OwnerId = :userId
              AND Visit_Date__c = :today
        ];
        data.completedVisitCount = [
            SELECT COUNT()
            FROM Visit__c
            WHERE OwnerId = :userId
              AND Visit_Date__c = :today
              AND Status__c = 'Completed'
        ];

        // ── Pending Orders ──
        data.pendingOrderCount = [
            SELECT COUNT()
            FROM Sales_Order__c
            WHERE OwnerId = :userId
              AND Status__c IN ('Draft', 'Pending')
        ];

        // ── Pending Collections ──
        data.pendingCollectionCount = [
            SELECT COUNT()
            FROM Collection__c
            WHERE OwnerId = :userId
              AND Status__c = 'Pending'
        ];

        // ── Open Tickets ──
        data.openTicketCount = [
            SELECT COUNT()
            FROM Ticket__c
            WHERE OwnerId = :userId
              AND Status__c NOT IN ('Closed', 'Resolved')
        ];

        // ── Today's Attendance ──
        List<Day_Attendance__c> att = [
            SELECT Id, Status__c, Day_Start_Time__c
            FROM Day_Attendance__c
            WHERE Employee__r.User__c = :userId
              AND Attendance_Date__c = :today
            LIMIT 1
        ];
        data.isDayStarted = !att.isEmpty();
        data.attendanceStatus = att.isEmpty() ? 'Not Started' : att[0].Status__c;

        // ── Pending Leaves ──
        data.pendingLeaveCount = [
            SELECT COUNT()
            FROM Leave_Request__c
            WHERE OwnerId = :userId
              AND Status__c = 'Pending'
        ];

        // ── Pending Expenses ──
        data.pendingExpenseCount = [
            SELECT COUNT()
            FROM Expense__c
            WHERE OwnerId = :userId
              AND Status__c IN ('Draft', 'Pending')
        ];

        // ── Low Stock Alerts ──
        data.lowStockAlertCount = [
            SELECT COUNT()
            FROM Distributor_Stock__c
            WHERE Quantity__c <= 10
              AND Quantity__c > 0
        ];

        // ── Active Schemes ──
        data.activeSchemeCount = [
            SELECT COUNT()
            FROM Scheme__c
            WHERE Status__c = 'Active'
              AND Start_Date__c <= :today
              AND End_Date__c >= :today
        ];

        return data;
    }

    public class HomePageData {
        @AuraEnabled public Integer todayVisitCount = 0;
        @AuraEnabled public Integer completedVisitCount = 0;
        @AuraEnabled public Integer pendingOrderCount = 0;
        @AuraEnabled public Integer pendingCollectionCount = 0;
        @AuraEnabled public Integer openTicketCount = 0;
        @AuraEnabled public Boolean isDayStarted = false;
        @AuraEnabled public String attendanceStatus = 'Not Started';
        @AuraEnabled public Integer pendingLeaveCount = 0;
        @AuraEnabled public Integer pendingExpenseCount = 0;
        @AuraEnabled public Integer lowStockAlertCount = 0;
        @AuraEnabled public Integer activeSchemeCount = 0;
    }
}
