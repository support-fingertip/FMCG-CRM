// Script 15: Leave Requests - sample leave data for testing
// Run: sf apex run -f scripts/15_leave_requests.apex
// Prerequisite: 13_employees.apex
// Note: Leave_Request__c.Employee__c is a Lookup to User, not Employee__c
//       The controller links leaves via the record Owner (running user)

// Clean up existing leave requests
delete [SELECT Id FROM Leave_Request__c];
System.debug('Cleaned up Leave_Request__c');

Id runningUserId = UserInfo.getUserId();

List<Leave_Request__c> leaves = new List<Leave_Request__c>();

// 1. Past approved - Casual Leave, full days
leaves.add(new Leave_Request__c(
    Employee__c = runningUserId,
    Leave_Type__c = 'Casual Leave',
    Start_Date__c = Date.newInstance(2026, 1, 5),
    End_Date__c = Date.newInstance(2026, 1, 6),
    Start_Session__c = 'Full Day',
    End_Session__c = 'Full Day',
    Number_of_Days__c = 2,
    Reason__c = 'Personal work - bank visit and house maintenance',
    Status__c = 'Approved',
    Approval_Date__c = DateTime.newInstance(2026, 1, 3, 10, 0, 0),
    Comments__c = 'Approved. Enjoy your time off.'
));

// 2. Past approved - Sick Leave, full days
leaves.add(new Leave_Request__c(
    Employee__c = runningUserId,
    Leave_Type__c = 'Sick Leave',
    Start_Date__c = Date.newInstance(2026, 1, 19),
    End_Date__c = Date.newInstance(2026, 1, 20),
    Start_Session__c = 'Full Day',
    End_Session__c = 'Full Day',
    Number_of_Days__c = 2,
    Reason__c = 'Fever and cold - doctor advised rest',
    Status__c = 'Approved',
    Approval_Date__c = DateTime.newInstance(2026, 1, 19, 9, 0, 0),
    Comments__c = 'Get well soon. Please submit medical certificate.'
));

// 3. Past approved - Earned Leave, multiple days
leaves.add(new Leave_Request__c(
    Employee__c = runningUserId,
    Leave_Type__c = 'Earned Leave',
    Start_Date__c = Date.newInstance(2026, 2, 9),
    End_Date__c = Date.newInstance(2026, 2, 13),
    Start_Session__c = 'Full Day',
    End_Session__c = 'Full Day',
    Number_of_Days__c = 5,
    Reason__c = 'Family vacation - visiting hometown',
    Status__c = 'Approved',
    Approval_Date__c = DateTime.newInstance(2026, 2, 2, 14, 0, 0),
    Comments__c = 'Approved. Please ensure handover is done before you leave.'
));

// 4. Past approved - Compensatory Off, single day
leaves.add(new Leave_Request__c(
    Employee__c = runningUserId,
    Leave_Type__c = 'Compensatory Off',
    Start_Date__c = Date.newInstance(2026, 3, 2),
    End_Date__c = Date.newInstance(2026, 3, 2),
    Start_Session__c = 'Full Day',
    End_Session__c = 'Full Day',
    Number_of_Days__c = 1,
    Reason__c = 'Compensatory off for working on Sunday during distributor meet',
    Status__c = 'Approved',
    Approval_Date__c = DateTime.newInstance(2026, 2, 28, 10, 30, 0),
    Comments__c = 'Approved as per comp-off policy.'
));

// 5. Upcoming pending - Casual Leave, full days
leaves.add(new Leave_Request__c(
    Employee__c = runningUserId,
    Leave_Type__c = 'Casual Leave',
    Start_Date__c = Date.today().addDays(5),
    End_Date__c = Date.today().addDays(6),
    Start_Session__c = 'Full Day',
    End_Session__c = 'Full Day',
    Number_of_Days__c = 2,
    Reason__c = 'Family function - cousin wedding ceremony',
    Status__c = 'Pending'
));

// 6. Upcoming pending - Earned Leave, multi-day
leaves.add(new Leave_Request__c(
    Employee__c = runningUserId,
    Leave_Type__c = 'Earned Leave',
    Start_Date__c = Date.today().addDays(14),
    End_Date__c = Date.today().addDays(18),
    Start_Session__c = 'Full Day',
    End_Session__c = 'Full Day',
    Number_of_Days__c = 5,
    Reason__c = 'Annual vacation - planned travel with family',
    Status__c = 'Pending'
));

// 7. Upcoming pending - Sick Leave, second half only (0.5 day)
leaves.add(new Leave_Request__c(
    Employee__c = runningUserId,
    Leave_Type__c = 'Sick Leave',
    Start_Date__c = Date.today().addDays(3),
    End_Date__c = Date.today().addDays(3),
    Start_Session__c = 'Second Half',
    End_Session__c = 'Second Half',
    Number_of_Days__c = 0.5,
    Reason__c = 'Medical appointment with specialist in the afternoon',
    Status__c = 'Pending'
));

// 8. Upcoming pending - Casual Leave, first half only (0.5 day)
leaves.add(new Leave_Request__c(
    Employee__c = runningUserId,
    Leave_Type__c = 'Casual Leave',
    Start_Date__c = Date.today().addDays(10),
    End_Date__c = Date.today().addDays(10),
    Start_Session__c = 'First Half',
    End_Session__c = 'First Half',
    Number_of_Days__c = 0.5,
    Reason__c = 'Bank work - urgent document submission in the morning',
    Status__c = 'Pending'
));

// 9. Rejected leave
leaves.add(new Leave_Request__c(
    Employee__c = runningUserId,
    Leave_Type__c = 'Casual Leave',
    Start_Date__c = Date.newInstance(2026, 2, 23),
    End_Date__c = Date.newInstance(2026, 2, 27),
    Start_Session__c = 'Full Day',
    End_Session__c = 'Full Day',
    Number_of_Days__c = 5,
    Reason__c = 'Extended weekend trip - personal travel',
    Status__c = 'Rejected',
    Approval_Date__c = DateTime.newInstance(2026, 2, 20, 11, 0, 0),
    Comments__c = 'Cannot approve during quarter-end closing. Please reschedule to a less critical period.'
));

// 10. Cancelled leave
leaves.add(new Leave_Request__c(
    Employee__c = runningUserId,
    Leave_Type__c = 'Compensatory Off',
    Start_Date__c = Date.newInstance(2026, 2, 16),
    End_Date__c = Date.newInstance(2026, 2, 16),
    Start_Session__c = 'Full Day',
    End_Session__c = 'Full Day',
    Number_of_Days__c = 1,
    Reason__c = 'Worked on Saturday for annual stock-taking exercise',
    Status__c = 'Cancelled'
));

insert leaves;
System.debug('Leave Request setup complete. Total: ' + leaves.size());
