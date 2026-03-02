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

    // Default annual entitlements (must match field defaultValue on Employee__c)
    private static final Map<String, Decimal> DEFAULT_BALANCE = new Map<String, Decimal>{
        'CL' => 12,
        'SL' => 7,
        'EL' => 15,
        'CO' => 0
    };

    private static final Map<String, Decimal> DEFAULT_BALANCE_BY_FIELD = new Map<String, Decimal>{
        'CL_Balance__c' => 12,
        'SL_Balance__c' => 7,
        'EL_Balance__c' => 15,
        'CO_Balance__c' => 0
    };

    // ── Check if User is a Manager ──────────────────────────────────────────

    /**
     * @description Checks whether the given user is a manager by looking for
     *              active employees who have this user's Employee record as
     *              their Reporting_Manager__c.
     * @param userId The User Id to check.
     * @return True if the user has at least one direct report.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean checkIsManager(Id userId) {
        List<Employee__c> managerEmployees = [
            SELECT Id
            FROM Employee__c
            WHERE User__c = :userId
            LIMIT 1
        ];

        if (managerEmployees.isEmpty()) {
            return false;
        }

        Id managerEmployeeId = managerEmployees[0].Id;

        Integer directReportCount = [
            SELECT COUNT()
            FROM Employee__c
            WHERE Reporting_Manager__c = :managerEmployeeId
            AND Is_Active__c = true
        ];

        return directReportCount > 0;
    }

    // ── Get Reporting Manager User Id ───────────────────────────────────────

    /**
     * @description Retrieves the User Id of the reporting manager for a given
     *              employee (User Id). Traverses Employee__c -> Reporting_Manager__c -> User__c.
     * @param userId The User Id of the employee.
     * @return The User Id of the reporting manager, or null if not found.
     */
    @AuraEnabled
    public static Id getReportingManagerUserId(Id userId) {
        List<Employee__c> employees = [
            SELECT Reporting_Manager__c, Reporting_Manager__r.User__c
            FROM Employee__c
            WHERE User__c = :userId
            LIMIT 1
        ];

        if (employees.isEmpty() || employees[0].Reporting_Manager__c == null) {
            return null;
        }

        return employees[0].Reporting_Manager__r.User__c;
    }

    // ── Get Pending Approvals for Manager ───────────────────────────────────

    /**
     * @description Retrieves all pending leave requests that are assigned to the
     *              given manager for approval (where Approved_By__c = managerId
     *              and Status is Pending or Submitted).
     * @param managerId The User Id of the manager/approver.
     * @return List of Leave_Request__c records pending this manager's approval.
     */
    @AuraEnabled
    public static List<Leave_Request__c> getPendingApprovalsForManager(Id managerId) {
        return [
            SELECT Id, Name, Employee__c, Employee__r.Name, Leave_Type__c,
                   Start_Date__c, Start_Session__c, End_Date__c, End_Session__c,
                   Number_of_Days__c, Reason__c, Status__c,
                   Approved_By__c, Approved_By__r.Name, Approval_Date__c, Comments__c,
                   CreatedDate
            FROM Leave_Request__c
            WHERE Approved_By__c = :managerId
            AND Status__c IN ('Pending', 'Submitted')
            ORDER BY CreatedDate DESC
        ];
    }

    // ── Get Approval History for Manager ────────────────────────────────────

    /**
     * @description Retrieves recently decided leave requests (Approved/Rejected)
     *              where the given manager was the approver.
     * @param managerId The User Id of the manager/approver.
     * @return List of recently decided Leave_Request__c records.
     */
    @AuraEnabled
    public static List<Leave_Request__c> getApprovalHistoryForManager(Id managerId) {
        return [
            SELECT Id, Name, Employee__c, Employee__r.Name, Leave_Type__c,
                   Start_Date__c, Start_Session__c, End_Date__c, End_Session__c,
                   Number_of_Days__c, Reason__c, Status__c,
                   Approved_By__c, Approved_By__r.Name, Approval_Date__c, Comments__c
            FROM Leave_Request__c
            WHERE Approved_By__c = :managerId
            AND Status__c IN ('Approved', 'Rejected')
            ORDER BY Approval_Date__c DESC
            LIMIT 50
        ];
    }

    // ── Get Leave Requests ────────────────────────────────────────────────────

    /**
     * @description Retrieves leave requests for a specific user, optionally filtered
     *              by status and year. Includes the Employee relationship name.
     * @param userId The User Id whose leave requests to retrieve.
     * @param status Optional status filter (e.g. 'Pending', 'Approved'). Pass null to skip.
     * @param year   Optional year filter. Pass null or 0 to skip.
     * @return List of Leave_Request__c records ordered by Start_Date__c DESC.
     */
    @AuraEnabled
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
    @AuraEnabled
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
     *              before saving. New records automatically populate Approved_By__c
     *              with the reporting manager and set Status to 'Submitted'.
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

            Boolean isNew = leaveRequest.Id == null;
            if (isNew) {
                // Auto-populate Approved_By__c with reporting manager
                Id reportingManagerUserId = getReportingManagerUserId(leaveRequest.Employee__c);
                if (reportingManagerUserId != null) {
                    leaveRequest.Approved_By__c = reportingManagerUserId;
                }

                // Set status to Submitted (sent for approval)
                leaveRequest.Status__c = 'Submitted';
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
                       Approved_By__c, Comments__c
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
                SELECT Id, Status__c, Approved_By__c
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
    @AuraEnabled
    public static Map<String, Decimal> getLeaveBalance(Id userId) {
        List<Employee__c> employees = [
            SELECT CL_Balance__c, SL_Balance__c, EL_Balance__c, CO_Balance__c
            FROM Employee__c
            WHERE User__c = :userId
            LIMIT 1
        ];

        if (!employees.isEmpty()) {
            Employee__c emp = employees[0];
            return new Map<String, Decimal>{
                'CL' => emp.CL_Balance__c != null ? emp.CL_Balance__c : DEFAULT_BALANCE.get('CL'),
                'SL' => emp.SL_Balance__c != null ? emp.SL_Balance__c : DEFAULT_BALANCE.get('SL'),
                'EL' => emp.EL_Balance__c != null ? emp.EL_Balance__c : DEFAULT_BALANCE.get('EL'),
                'CO' => emp.CO_Balance__c != null ? emp.CO_Balance__c : DEFAULT_BALANCE.get('CO')
            };
        }

        // No Employee record linked to this user — return default entitlements
        return new Map<String, Decimal>(DEFAULT_BALANCE);
    }

    // ── Get Leaves Summary ────────────────────────────────────────────────────

    /**
     * @description Returns aggregated leave counts grouped by leave type and status
     *              for a specific user and year. Useful for dashboard widgets.
     * @param userId The User Id whose leave summary to retrieve.
     * @param year   The calendar year to summarise.
     * @return Map with composite keys (e.g. 'Casual Leave_Approved') and count values.
     */
    @AuraEnabled
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
    @AuraEnabled
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
            AND Status__c IN ('Approved', 'Pending', 'Submitted')
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
    @AuraEnabled
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

    private static Decimal calculateBusinessDays(Date startDate, Date endDate) {
        Integer businessDays = 0;
        Date current = startDate;

        while (current <= endDate) {
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

    private static void validateLeaveBalance(Id userId, String leaveType, Decimal days) {
        String balanceField = LEAVE_TYPE_BALANCE_FIELD.get(leaveType);
        if (balanceField == null) {
            return;
        }

        Decimal defaultForField = DEFAULT_BALANCE_BY_FIELD.get(balanceField);

        List<Employee__c> employees = [
            SELECT CL_Balance__c, SL_Balance__c, EL_Balance__c, CO_Balance__c
            FROM Employee__c
            WHERE User__c = :userId
            LIMIT 1
        ];

        Decimal currentBalance;

        if (employees.isEmpty()) {
            currentBalance = defaultForField != null ? defaultForField : 0;
        } else {
            Employee__c emp = employees[0];

            if (balanceField == 'CL_Balance__c') {
                currentBalance = emp.CL_Balance__c != null ? emp.CL_Balance__c : defaultForField;
            } else if (balanceField == 'SL_Balance__c') {
                currentBalance = emp.SL_Balance__c != null ? emp.SL_Balance__c : defaultForField;
            } else if (balanceField == 'EL_Balance__c') {
                currentBalance = emp.EL_Balance__c != null ? emp.EL_Balance__c : defaultForField;
            } else if (balanceField == 'CO_Balance__c') {
                currentBalance = emp.CO_Balance__c != null ? emp.CO_Balance__c : defaultForField;
            } else {
                currentBalance = 0;
            }
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
