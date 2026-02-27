/**
 * @description Controller for the Leave Request LWC component.
 *              Manages leave request lifecycle: creation, approval, rejection,
 *              cancellation, balance tracking, and team leave visibility
 *              for FMCG field sales workforce management.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class LeaveRequestController {

    // ── Leave Type to Balance Field Mapping ───────────────────────────────────

    private static final Map<String, String> LEAVE_TYPE_BALANCE_FIELD = new Map<String, String>{
        'Casual Leave'     => 'CL_Balance__c',
        'Sick Leave'       => 'SL_Balance__c',
        'Earned Leave'     => 'EL_Balance__c',
        'Compensatory Off' => 'CO_Balance__c'
    };

    // ── Get Leave Requests ────────────────────────────────────────────────────

    /**
     * @description Retrieves leave requests for a specific user, optionally filtered
     *              by status and year. Includes the Employee relationship name.
     * @param userId The User Id whose leave requests to retrieve.
     * @param status Optional status filter (e.g. 'Pending', 'Approved'). Pass null to skip.
     * @param year   Optional year filter. Pass null or 0 to skip.
     * @return List of Leave_Request__c records ordered by Start_Date__c DESC.
     */
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getLeaveRequests(Id userId, String status, Integer year) {
        String query = 'SELECT Id, Name, Employee__c, Employee__r.Name, Leave_Type__c, ' +
            'Start_Date__c, Start_Session__c, End_Date__c, End_Session__c, Number_of_Days__c, Reason__c, Status__c, ' +
            'Approved_By__c, Approved_By__r.Name, Approval_Date__c, Comments__c ' +
            'FROM Leave_Request__c WHERE Employee__c = :userId';

        if (String.isNotBlank(status)) {
            query += ' AND Status__c = :status';
        }
        if (year != null && year > 0) {
            query += ' AND CALENDAR_YEAR(Start_Date__c) = :year';
        }

        query += ' ORDER BY Start_Date__c DESC';

        return Database.query(query);
    }

    // ── Get Team Leave Requests ───────────────────────────────────────────────

    /**
     * @description Retrieves leave requests for all direct reports of a manager.
     *              Looks up the manager's Employee__c record, finds direct reports
     *              via Reporting_Manager__c, then queries their leave requests.
     * @param managerId The User Id of the manager.
     * @param status    Optional status filter. Pass null to skip.
     * @return List of Leave_Request__c records for the manager's team.
     */
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getTeamLeaveRequests(Id managerId, String status) {
        // Find the manager's Employee__c record
        List<Employee__c> managerEmployees = [
            SELECT Id
            FROM Employee__c
            WHERE User__c = :managerId
            LIMIT 1
        ];

        if (managerEmployees.isEmpty()) {
            return new List<Leave_Request__c>();
        }

        Id managerEmployeeId = managerEmployees[0].Id;

        // Find direct reports via the self-referencing Reporting_Manager__c lookup
        List<Employee__c> directReports = [
            SELECT User__c
            FROM Employee__c
            WHERE Reporting_Manager__c = :managerEmployeeId
            AND Is_Active__c = true
        ];

        if (directReports.isEmpty()) {
            return new List<Leave_Request__c>();
        }

        Set<Id> reportUserIds = new Set<Id>();
        for (Employee__c emp : directReports) {
            reportUserIds.add(emp.User__c);
        }

        String query = 'SELECT Id, Name, Employee__c, Employee__r.Name, Leave_Type__c, ' +
            'Start_Date__c, Start_Session__c, End_Date__c, End_Session__c, Number_of_Days__c, Reason__c, Status__c, ' +
            'Approved_By__c, Approved_By__r.Name, Approval_Date__c, Comments__c ' +
            'FROM Leave_Request__c WHERE Employee__c IN :reportUserIds';

        if (String.isNotBlank(status)) {
            query += ' AND Status__c = :status';
        }

        query += ' ORDER BY Start_Date__c DESC';

        return Database.query(query);
    }

    // ── Save Leave Request ────────────────────────────────────────────────────

    /**
     * @description Inserts or updates a Leave_Request__c record. Auto-calculates
     *              Number_of_Days__c from Start_Date__c/End_Date__c counting only
     *              business days (Mon-Fri), adjusted by Start_Session__c and
     *              End_Session__c for half-day precision. Validates leave balance
     *              before saving. New records are automatically set to 'Pending' status.
     * @param leaveRequest The Leave_Request__c record to save.
     * @return The saved Leave_Request__c record.
     */
    @AuraEnabled
    public static Leave_Request__c saveLeaveRequest(Leave_Request__c leaveRequest) {
        Savepoint sp = Database.setSavepoint();
        try {
            // Validate required dates
            if (leaveRequest.Start_Date__c == null || leaveRequest.End_Date__c == null) {
                throw new AuraHandledException('Start Date and End Date are required.');
            }
            if (leaveRequest.End_Date__c < leaveRequest.Start_Date__c) {
                throw new AuraHandledException('End Date cannot be before Start Date.');
            }

            // Validate session combination for same date
            String startSession = leaveRequest.Start_Session__c != null ? leaveRequest.Start_Session__c : 'Session 1';
            String endSession = leaveRequest.End_Session__c != null ? leaveRequest.End_Session__c : 'Session 2';

            if (leaveRequest.Start_Date__c == leaveRequest.End_Date__c &&
                startSession == 'Session 2' && endSession == 'Session 1') {
                throw new AuraHandledException(
                    'Invalid session selection. To Session cannot be Session 1 when From Session is Session 2 on the same date.'
                );
            }

            // Calculate business days with session adjustments
            Decimal numberOfDays = calculateBusinessDays(leaveRequest.Start_Date__c, leaveRequest.End_Date__c);

            // Adjust for sessions: Session 2 start = subtract 0.5, Session 1 end = subtract 0.5
            if (startSession == 'Session 2') {
                numberOfDays -= 0.5;
            }
            if (endSession == 'Session 1') {
                numberOfDays -= 0.5;
            }

            leaveRequest.Number_of_Days__c = numberOfDays;

            if (numberOfDays <= 0) {
                throw new AuraHandledException(
                    'The selected date range does not contain any business days.'
                );
            }

            // Set status to Pending for new records
            Boolean isNew = leaveRequest.Id == null;
            if (isNew) {
                leaveRequest.Status__c = 'Pending';
            }

            // Validate leave balance
            validateLeaveBalance(leaveRequest.Employee__c, leaveRequest.Leave_Type__c, numberOfDays);

            upsert leaveRequest;

            return [
                SELECT Id, Name, Employee__c, Employee__r.Name, Leave_Type__c,
                       Start_Date__c, Start_Session__c, End_Date__c, End_Session__c,
                       Number_of_Days__c, Reason__c,
                       Status__c, Approved_By__c, Approved_By__r.Name,
                       Approval_Date__c, Comments__c
                FROM Leave_Request__c
                WHERE Id = :leaveRequest.Id
                LIMIT 1
            ];
        } catch (AuraHandledException ahe) {
            Database.rollback(sp);
            throw ahe;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Approve Leave Request ─────────────────────────────────────────────────

    /**
     * @description Approves a leave request by setting Status to 'Approved',
     *              recording the approver and approval timestamp, and deducting
     *              the corresponding leave balance from the employee's record.
     * @param leaveRequestId The Id of the Leave_Request__c to approve.
     * @param comments       Optional approval comments.
     * @return The updated Leave_Request__c record.
     */
    @AuraEnabled
    public static Leave_Request__c approveLeaveRequest(Id leaveRequestId, String comments) {
        Savepoint sp = Database.setSavepoint();
        try {
            Leave_Request__c request = [
                SELECT Id, Employee__c, Leave_Type__c, Number_of_Days__c, Status__c,
                       Comments__c
                FROM Leave_Request__c
                WHERE Id = :leaveRequestId
                LIMIT 1
            ];

            if (request.Status__c == 'Approved') {
                throw new AuraHandledException('This leave request has already been approved.');
            }
            if (request.Status__c == 'Cancelled') {
                throw new AuraHandledException('Cannot approve a cancelled leave request.');
            }

            request.Status__c = 'Approved';
            request.Approved_By__c = UserInfo.getUserId();
            request.Approval_Date__c = Datetime.now();
            if (String.isNotBlank(comments)) {
                request.Comments__c = comments;
            }
            update request;

            // Deduct leave balance
            deductLeaveBalance(request.Employee__c, request.Leave_Type__c, request.Number_of_Days__c);

            return [
                SELECT Id, Name, Employee__c, Employee__r.Name, Leave_Type__c,
                       Start_Date__c, Start_Session__c, End_Date__c, End_Session__c,
                       Number_of_Days__c, Reason__c,
                       Status__c, Approved_By__c, Approved_By__r.Name,
                       Approval_Date__c, Comments__c
                FROM Leave_Request__c
                WHERE Id = :leaveRequestId
                LIMIT 1
            ];
        } catch (AuraHandledException ahe) {
            Database.rollback(sp);
            throw ahe;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Reject Leave Request ──────────────────────────────────────────────────

    /**
     * @description Rejects a leave request by setting Status to 'Rejected'
     *              and recording the rejection comments.
     * @param leaveRequestId The Id of the Leave_Request__c to reject.
     * @param comments       Rejection reason/comments.
     * @return The updated Leave_Request__c record.
     */
    @AuraEnabled
    public static Leave_Request__c rejectLeaveRequest(Id leaveRequestId, String comments) {
        try {
            Leave_Request__c request = [
                SELECT Id, Status__c
                FROM Leave_Request__c
                WHERE Id = :leaveRequestId
                LIMIT 1
            ];

            if (request.Status__c == 'Rejected') {
                throw new AuraHandledException('This leave request has already been rejected.');
            }
            if (request.Status__c == 'Cancelled') {
                throw new AuraHandledException('Cannot reject a cancelled leave request.');
            }

            request.Status__c = 'Rejected';
            request.Approved_By__c = UserInfo.getUserId();
            request.Approval_Date__c = Datetime.now();
            if (String.isNotBlank(comments)) {
                request.Comments__c = comments;
            }
            update request;

            return [
                SELECT Id, Name, Employee__c, Employee__r.Name, Leave_Type__c,
                       Start_Date__c, Start_Session__c, End_Date__c, End_Session__c,
                       Number_of_Days__c, Reason__c,
                       Status__c, Approved_By__c, Approved_By__r.Name,
                       Approval_Date__c, Comments__c
                FROM Leave_Request__c
                WHERE Id = :leaveRequestId
                LIMIT 1
            ];
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Cancel Leave Request ──────────────────────────────────────────────────

    /**
     * @description Cancels a leave request. If the request was previously Approved,
     *              restores the deducted leave balance back to the employee's record.
     * @param leaveRequestId The Id of the Leave_Request__c to cancel.
     * @return The updated Leave_Request__c record.
     */
    @AuraEnabled
    public static Leave_Request__c cancelLeaveRequest(Id leaveRequestId) {
        Savepoint sp = Database.setSavepoint();
        try {
            Leave_Request__c request = [
                SELECT Id, Employee__c, Leave_Type__c, Number_of_Days__c, Status__c
                FROM Leave_Request__c
                WHERE Id = :leaveRequestId
                LIMIT 1
            ];

            if (request.Status__c == 'Cancelled') {
                throw new AuraHandledException('This leave request has already been cancelled.');
            }

            Boolean wasApproved = request.Status__c == 'Approved';

            request.Status__c = 'Cancelled';
            update request;

            // Restore leave balance if the request was previously approved
            if (wasApproved) {
                restoreLeaveBalance(request.Employee__c, request.Leave_Type__c, request.Number_of_Days__c);
            }

            return [
                SELECT Id, Name, Employee__c, Employee__r.Name, Leave_Type__c,
                       Start_Date__c, Start_Session__c, End_Date__c, End_Session__c,
                       Number_of_Days__c, Reason__c,
                       Status__c, Approved_By__c, Approved_By__r.Name,
                       Approval_Date__c, Comments__c
                FROM Leave_Request__c
                WHERE Id = :leaveRequestId
                LIMIT 1
            ];
        } catch (AuraHandledException ahe) {
            Database.rollback(sp);
            throw ahe;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Get Leave Balance ─────────────────────────────────────────────────────

    /**
     * @description Retrieves the leave balance for a user from the Employee__c record.
     *              Returns a map with keys CL, SL, EL, CO and their respective balances.
     * @param userId The User Id to look up leave balances for.
     * @return Map with leave type abbreviation keys and Decimal balance values.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getLeaveBalance(Id userId) {
        Map<String, Decimal> balances = new Map<String, Decimal>{
            'CL' => 0,
            'SL' => 0,
            'EL' => 0,
            'CO' => 0
        };

        List<Employee__c> employees = [
            SELECT CL_Balance__c, SL_Balance__c, EL_Balance__c, CO_Balance__c
            FROM Employee__c
            WHERE User__c = :userId
            LIMIT 1
        ];

        if (!employees.isEmpty()) {
            Employee__c emp = employees[0];
            balances.put('CL', emp.CL_Balance__c != null ? emp.CL_Balance__c : 0);
            balances.put('SL', emp.SL_Balance__c != null ? emp.SL_Balance__c : 0);
            balances.put('EL', emp.EL_Balance__c != null ? emp.EL_Balance__c : 0);
            balances.put('CO', emp.CO_Balance__c != null ? emp.CO_Balance__c : 0);
        }

        return balances;
    }

    // ── Get Leaves Summary ────────────────────────────────────────────────────

    /**
     * @description Returns aggregated leave counts grouped by leave type and status
     *              for a specific user and year. Useful for dashboard widgets.
     * @param userId The User Id whose leave summary to retrieve.
     * @param year   The calendar year to summarise.
     * @return Map with composite keys (e.g. 'Casual Leave_Approved') and count values.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getLeavesSummary(Id userId, Integer year) {
        Map<String, Integer> summary = new Map<String, Integer>();

        List<AggregateResult> results = [
            SELECT Leave_Type__c leaveType, Status__c status, COUNT(Id) cnt
            FROM Leave_Request__c
            WHERE Employee__c = :userId
            AND CALENDAR_YEAR(Start_Date__c) = :year
            GROUP BY Leave_Type__c, Status__c
        ];

        for (AggregateResult ar : results) {
            String leaveType = (String) ar.get('leaveType');
            String status = (String) ar.get('status');
            Integer cnt = (Integer) ar.get('cnt');
            summary.put(leaveType + '_' + status, cnt);
        }

        return summary;
    }

    // ── Get Upcoming Leaves ───────────────────────────────────────────────────

    /**
     * @description Retrieves future approved or pending leave requests for a user,
     *              ordered by start date ascending.
     * @param userId     The User Id whose upcoming leaves to retrieve.
     * @param limitCount Maximum number of records to return.
     * @return List of upcoming Leave_Request__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getUpcomingLeaves(Id userId, Integer limitCount) {
        if (limitCount == null || limitCount <= 0) {
            limitCount = 10;
        }

        return [
            SELECT Id, Name, Employee__c, Employee__r.Name, Leave_Type__c,
                   Start_Date__c, Start_Session__c, End_Date__c, End_Session__c,
                   Number_of_Days__c, Reason__c,
                   Status__c, Comments__c
            FROM Leave_Request__c
            WHERE Employee__c = :userId
            AND Start_Date__c >= :Date.today()
            AND Status__c IN ('Approved', 'Pending')
            ORDER BY Start_Date__c ASC
            LIMIT :limitCount
        ];
    }

    // ── Get Team Leaves on Date ───────────────────────────────────────────────

    /**
     * @description Retrieves all team members who are on approved leave for a specific
     *              date. Useful for journey plan integration to show team availability.
     * @param targetDate The date to check for leaves.
     * @param managerId  The User Id of the manager.
     * @return List of Leave_Request__c records for team members on leave that date.
     */
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getTeamLeavesOnDate(Date targetDate, Id managerId) {
        // Find the manager's Employee__c record
        List<Employee__c> managerEmployees = [
            SELECT Id
            FROM Employee__c
            WHERE User__c = :managerId
            LIMIT 1
        ];

        if (managerEmployees.isEmpty()) {
            return new List<Leave_Request__c>();
        }

        Id managerEmployeeId = managerEmployees[0].Id;

        // Find direct reports
        List<Employee__c> directReports = [
            SELECT User__c
            FROM Employee__c
            WHERE Reporting_Manager__c = :managerEmployeeId
            AND Is_Active__c = true
        ];

        if (directReports.isEmpty()) {
            return new List<Leave_Request__c>();
        }

        Set<Id> reportUserIds = new Set<Id>();
        for (Employee__c emp : directReports) {
            reportUserIds.add(emp.User__c);
        }

        return [
            SELECT Id, Name, Employee__c, Employee__r.Name, Leave_Type__c,
                   Start_Date__c, Start_Session__c, End_Date__c, End_Session__c,
                   Number_of_Days__c, Status__c
            FROM Leave_Request__c
            WHERE Employee__c IN :reportUserIds
            AND Start_Date__c <= :targetDate
            AND End_Date__c >= :targetDate
            AND Status__c = 'Approved'
            ORDER BY Employee__r.Name ASC
        ];
    }

    // ── Private Helper: Calculate Business Days ───────────────────────────────

    /**
     * @description Calculates the number of business days (Monday through Friday)
     *              between two dates, inclusive of both start and end dates.
     * @param startDate The start date.
     * @param endDate   The end date.
     * @return The count of business days as a Decimal.
     */
    private static Decimal calculateBusinessDays(Date startDate, Date endDate) {
        Integer businessDays = 0;
        Date current = startDate;

        while (current <= endDate) {
            // DateTime.format('u') returns day-of-week where Monday=1, Sunday=7
            // We use the daysBetween approach to determine the weekday
            DateTime dt = DateTime.newInstance(current, Time.newInstance(0, 0, 0, 0));
            String dayOfWeek = dt.format('EEEE');
            if (dayOfWeek != 'Saturday' && dayOfWeek != 'Sunday') {
                businessDays++;
            }
            current = current.addDays(1);
        }

        return Decimal.valueOf(businessDays);
    }

    // ── Private Helper: Validate Leave Balance ────────────────────────────────

    /**
     * @description Validates that the employee has sufficient leave balance for
     *              the requested leave type and number of days.
     * @param userId    The User Id of the employee.
     * @param leaveType The leave type picklist value.
     * @param days      The number of days requested.
     */
    private static void validateLeaveBalance(Id userId, String leaveType, Decimal days) {
        String balanceField = LEAVE_TYPE_BALANCE_FIELD.get(leaveType);
        if (balanceField == null) {
            // Leave type does not require balance validation (e.g. Half Day)
            return;
        }

        List<Employee__c> employees = [
            SELECT CL_Balance__c, SL_Balance__c, EL_Balance__c, CO_Balance__c
            FROM Employee__c
            WHERE User__c = :userId
            LIMIT 1
        ];

        if (employees.isEmpty()) {
            throw new AuraHandledException(
                'Employee record not found for this user. Please contact your administrator.'
            );
        }

        Employee__c emp = employees[0];
        Decimal currentBalance = 0;

        if (balanceField == 'CL_Balance__c') {
            currentBalance = emp.CL_Balance__c != null ? emp.CL_Balance__c : 0;
        } else if (balanceField == 'SL_Balance__c') {
            currentBalance = emp.SL_Balance__c != null ? emp.SL_Balance__c : 0;
        } else if (balanceField == 'EL_Balance__c') {
            currentBalance = emp.EL_Balance__c != null ? emp.EL_Balance__c : 0;
        } else if (balanceField == 'CO_Balance__c') {
            currentBalance = emp.CO_Balance__c != null ? emp.CO_Balance__c : 0;
        }

        if (days > currentBalance) {
            throw new AuraHandledException(
                'Insufficient ' + leaveType + ' balance. Available: ' +
                String.valueOf(currentBalance) + ' days, Requested: ' +
                String.valueOf(days) + ' days.'
            );
        }
    }

    // ── Private Helper: Deduct Leave Balance ──────────────────────────────────

    /**
     * @description Deducts the specified number of days from the employee's leave
     *              balance for the given leave type.
     * @param userId    The User Id of the employee.
     * @param leaveType The leave type picklist value.
     * @param days      The number of days to deduct.
     */
    private static void deductLeaveBalance(Id userId, String leaveType, Decimal days) {
        String balanceField = LEAVE_TYPE_BALANCE_FIELD.get(leaveType);
        if (balanceField == null) {
            return;
        }

        List<Employee__c> employees = [
            SELECT Id, CL_Balance__c, SL_Balance__c, EL_Balance__c, CO_Balance__c
            FROM Employee__c
            WHERE User__c = :userId
            LIMIT 1
        ];

        if (employees.isEmpty()) {
            return;
        }

        Employee__c emp = employees[0];

        if (balanceField == 'CL_Balance__c') {
            emp.CL_Balance__c = (emp.CL_Balance__c != null ? emp.CL_Balance__c : 0) - days;
        } else if (balanceField == 'SL_Balance__c') {
            emp.SL_Balance__c = (emp.SL_Balance__c != null ? emp.SL_Balance__c : 0) - days;
        } else if (balanceField == 'EL_Balance__c') {
            emp.EL_Balance__c = (emp.EL_Balance__c != null ? emp.EL_Balance__c : 0) - days;
        } else if (balanceField == 'CO_Balance__c') {
            emp.CO_Balance__c = (emp.CO_Balance__c != null ? emp.CO_Balance__c : 0) - days;
        }

        update emp;
    }

    // ── Private Helper: Restore Leave Balance ─────────────────────────────────

    /**
     * @description Restores the specified number of days to the employee's leave
     *              balance for the given leave type. Used when cancelling a previously
     *              approved leave request.
     * @param userId    The User Id of the employee.
     * @param leaveType The leave type picklist value.
     * @param days      The number of days to restore.
     */
    private static void restoreLeaveBalance(Id userId, String leaveType, Decimal days) {
        String balanceField = LEAVE_TYPE_BALANCE_FIELD.get(leaveType);
        if (balanceField == null) {
            return;
        }

        List<Employee__c> employees = [
            SELECT Id, CL_Balance__c, SL_Balance__c, EL_Balance__c, CO_Balance__c
            FROM Employee__c
            WHERE User__c = :userId
            LIMIT 1
        ];

        if (employees.isEmpty()) {
            return;
        }

        Employee__c emp = employees[0];

        if (balanceField == 'CL_Balance__c') {
            emp.CL_Balance__c = (emp.CL_Balance__c != null ? emp.CL_Balance__c : 0) + days;
        } else if (balanceField == 'SL_Balance__c') {
            emp.SL_Balance__c = (emp.SL_Balance__c != null ? emp.SL_Balance__c : 0) + days;
        } else if (balanceField == 'EL_Balance__c') {
            emp.EL_Balance__c = (emp.EL_Balance__c != null ? emp.EL_Balance__c : 0) + days;
        } else if (balanceField == 'CO_Balance__c') {
            emp.CO_Balance__c = (emp.CO_Balance__c != null ? emp.CO_Balance__c : 0) + days;
        }

        update emp;
    }
}
