// Script 15: Leave Requests - sample leave data for testing
// Run: sf apex run -f scripts/15_leave_requests.apex
// Prerequisite: 13_employees.apex
// Note: Leave_Request__c.Employee__c is a Lookup to User, not Employee__c
//       The controller links leaves via the record Owner (running user)

// Clean up existing leave requests
delete [SELECT Id FROM Leave_Request__c];
System.debug('Cleaned up Leave_Request__c');

List<Leave_Request__c> leaves = new List<Leave_Request__c>();

// Past approved leaves (already taken)
leaves.add(new Leave_Request__c(
    Leave_Type__c = 'Casual Leave', Start_Date__c = Date.newInstance(2026, 1, 5),
    End_Date__c = Date.newInstance(2026, 1, 6), Number_of_Days__c = 2,
    Reason__c = 'Personal work - bank visit and house maintenance',
    Status__c = 'Approved', Approval_Date__c = DateTime.newInstance(2026, 1, 3, 10, 0, 0),
    Comments__c = 'Approved. Enjoy your time off.'
));
leaves.add(new Leave_Request__c(
    Leave_Type__c = 'Sick Leave', Start_Date__c = Date.newInstance(2026, 1, 19),
    End_Date__c = Date.newInstance(2026, 1, 20), Number_of_Days__c = 2,
    Reason__c = 'Fever and cold - doctor advised rest',
    Status__c = 'Approved', Approval_Date__c = DateTime.newInstance(2026, 1, 19, 9, 0, 0),
    Comments__c = 'Get well soon.'
));
leaves.add(new Leave_Request__c(
    Leave_Type__c = 'Earned Leave', Start_Date__c = Date.newInstance(2026, 2, 9),
    End_Date__c = Date.newInstance(2026, 2, 13), Number_of_Days__c = 5,
    Reason__c = 'Family vacation - visiting hometown',
    Status__c = 'Approved', Approval_Date__c = DateTime.newInstance(2026, 2, 2, 14, 0, 0),
    Comments__c = 'Approved. Please ensure handover is done.'
));

// Current/upcoming pending leaves
leaves.add(new Leave_Request__c(
    Leave_Type__c = 'Casual Leave', Start_Date__c = Date.today().addDays(5),
    End_Date__c = Date.today().addDays(6), Number_of_Days__c = 2,
    Reason__c = 'Family function - cousin wedding ceremony',
    Status__c = 'Pending'
));
leaves.add(new Leave_Request__c(
    Leave_Type__c = 'Earned Leave', Start_Date__c = Date.today().addDays(14),
    End_Date__c = Date.today().addDays(18), Number_of_Days__c = 5,
    Reason__c = 'Annual vacation - travel plans',
    Status__c = 'Pending'
));
leaves.add(new Leave_Request__c(
    Leave_Type__c = 'Casual Leave', Start_Date__c = Date.today().addDays(3),
    Start_Session__c = 'Session 2', End_Date__c = Date.today().addDays(3),
    End_Session__c = 'Session 2', Number_of_Days__c = 0.5,
    Reason__c = 'Doctor appointment in the afternoon',
    Status__c = 'Pending'
));

// Rejected leave
leaves.add(new Leave_Request__c(
    Leave_Type__c = 'Casual Leave', Start_Date__c = Date.newInstance(2026, 2, 23),
    End_Date__c = Date.newInstance(2026, 2, 27), Number_of_Days__c = 5,
    Reason__c = 'Extended weekend trip',
    Status__c = 'Rejected', Approval_Date__c = DateTime.newInstance(2026, 2, 20, 11, 0, 0),
    Comments__c = 'Cannot approve during quarter-end closing. Please reschedule.'
));

// Cancelled leave
leaves.add(new Leave_Request__c(
    Leave_Type__c = 'Compensatory Off', Start_Date__c = Date.newInstance(2026, 2, 16),
    End_Date__c = Date.newInstance(2026, 2, 16), Number_of_Days__c = 1,
    Reason__c = 'Worked on Saturday for stock-taking',
    Status__c = 'Cancelled'
));

insert leaves;
System.debug('Leave Request setup complete. Total: ' + leaves.size());
