// Script 13: Employee Hierarchy - NSM > RSM > ASM > Sales Reps
// Run: sf apex run -f scripts/13_employees.apex
// Prerequisite: 02_territory_master.apex

// Clean up (children with Restrict constraint first, then nullify self-refs)
delete [SELECT Id FROM Leave_Balance__c];
delete [SELECT Id FROM Expense__c WHERE Employee__c != null];
List<Employee__c> empOld = [SELECT Id FROM Employee__c WHERE Reporting_Manager__c != null];
for (Employee__c e : empOld) e.Reporting_Manager__c = null;
if (!empOld.isEmpty()) update empOld;
delete [SELECT Id FROM Employee__c];
System.debug('Cleaned up Employee__c');

// Fetch territories
Map<String, Id> terMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c FROM Territory_Master__c WHERE Is_Active__c = true]) {
    terMap.put(t.Territory_Code__c, t.Id);
}

// Pass 1: Create all employees without Reporting_Manager
List<Employee__c> employees = new List<Employee__c>();

// Admin user — linked to current running user
employees.add(new Employee__c(
    First_Name__c = UserInfo.getFirstName(),
    Last_Name__c = UserInfo.getLastName(),
    Employee_Code__c = 'EMP-ADMIN-001',
    Email__c = UserInfo.getUserEmail(),
    Phone__c = '9800000000',
    Department__c = 'Management',
    Designation__c = 'Admin',
    Band__c = 'Band 6',
    Date_of_Joining__c = Date.newInstance(2017, 1, 1),
    Is_Active__c = true,
    Zone__c = 'All India',
    Region__c = 'National',
    HQ_City__c = 'Delhi',
    Gross_Salary__c = 150000,
    User__c = UserInfo.getUserId(),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 12, SL_Balance__c = 7, EL_Balance__c = 15, CO_Balance__c = 3
));

// National Sales Manager (1)
employees.add(new Employee__c(
    First_Name__c = 'Rajesh', Last_Name__c = 'Kapoor', Employee_Code__c = 'EMP-NSM-001',
    Email__c = 'rajesh.kapoor@freshfields.com', Phone__c = '9810000001',
    Department__c = 'Sales', Designation__c = 'National Sales Manager',
    Band__c = 'Band 6',
    Date_of_Joining__c = Date.newInstance(2018, 4, 1), Is_Active__c = true,
    Zone__c = 'All India', Region__c = 'National',
    HQ_City__c = 'Delhi',
    Address__c = '12, Janpath Road, Connaught Place, New Delhi - 110001',
    Gross_Salary__c = 120000,
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 12, SL_Balance__c = 7, EL_Balance__c = 15, CO_Balance__c = 2
));

// Regional Sales Managers (2)
employees.add(new Employee__c(
    First_Name__c = 'Suresh', Last_Name__c = 'Menon', Employee_Code__c = 'EMP-RSM-001',
    Email__c = 'suresh.menon@freshfields.com', Phone__c = '9820000001',
    Department__c = 'Sales', Designation__c = 'Regional Sales Manager',
    Band__c = 'Band 5',
    Date_of_Joining__c = Date.newInstance(2019, 6, 15), Is_Active__c = true,
    Zone__c = 'West', Region__c = 'West',
    HQ_City__c = 'Mumbai',
    Address__c = '45, Nariman Point, Fort, Mumbai - 400021',
    Gross_Salary__c = 80000,
    Territory__c = terMap.get('TER-MUM-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 10, SL_Balance__c = 5, EL_Balance__c = 12, CO_Balance__c = 1
));
employees.add(new Employee__c(
    First_Name__c = 'Priya', Last_Name__c = 'Sharma', Employee_Code__c = 'EMP-RSM-002',
    Email__c = 'priya.sharma@freshfields.com', Phone__c = '9810000002',
    Department__c = 'Sales', Designation__c = 'Regional Sales Manager',
    Band__c = 'Band 5',
    Date_of_Joining__c = Date.newInstance(2019, 8, 1), Is_Active__c = true,
    Zone__c = 'North', Region__c = 'North',
    HQ_City__c = 'Delhi',
    Address__c = '8, Rajouri Garden, New Delhi - 110027',
    Gross_Salary__c = 80000,
    Territory__c = terMap.get('TER-DEL-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 11, SL_Balance__c = 6, EL_Balance__c = 14, CO_Balance__c = 0
));

// Area Sales Managers (4)
employees.add(new Employee__c(
    First_Name__c = 'Amit', Last_Name__c = 'Patel', Employee_Code__c = 'EMP-ASM-001',
    Email__c = 'amit.patel@freshfields.com', Phone__c = '9820000002',
    Department__c = 'Sales', Designation__c = 'Area Sales Manager',
    Band__c = 'Band 4',
    Date_of_Joining__c = Date.newInstance(2020, 3, 10), Is_Active__c = true,
    Zone__c = 'West', Region__c = 'West',
    HQ_City__c = 'Mumbai',
    Address__c = '22, Linking Road, Bandra West, Mumbai - 400050',
    Gross_Salary__c = 50000,
    Territory__c = terMap.get('TER-MUM-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 8, SL_Balance__c = 4, EL_Balance__c = 10, CO_Balance__c = 3
));
employees.add(new Employee__c(
    First_Name__c = 'Deepa', Last_Name__c = 'Nair', Employee_Code__c = 'EMP-ASM-002',
    Email__c = 'deepa.nair@freshfields.com', Phone__c = '9840000001',
    Department__c = 'Sales', Designation__c = 'Area Sales Manager',
    Band__c = 'Band 4',
    Date_of_Joining__c = Date.newInstance(2020, 5, 20), Is_Active__c = true,
    Zone__c = 'South', Region__c = 'South',
    HQ_City__c = 'Bangalore',
    Address__c = '5, MG Road, Shivajinagar, Bangalore - 560001',
    Gross_Salary__c = 50000,
    Territory__c = terMap.get('TER-BLR-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 9, SL_Balance__c = 7, EL_Balance__c = 11, CO_Balance__c = 1
));
employees.add(new Employee__c(
    First_Name__c = 'Vikram', Last_Name__c = 'Singh', Employee_Code__c = 'EMP-ASM-003',
    Email__c = 'vikram.singh@freshfields.com', Phone__c = '9810000003',
    Department__c = 'Sales', Designation__c = 'Area Sales Manager',
    Band__c = 'Band 4',
    Date_of_Joining__c = Date.newInstance(2020, 7, 1), Is_Active__c = true,
    Zone__c = 'North', Region__c = 'North',
    HQ_City__c = 'Delhi',
    Address__c = '17, Karol Bagh, New Delhi - 110005',
    Gross_Salary__c = 50000,
    Territory__c = terMap.get('TER-DEL-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 12, SL_Balance__c = 7, EL_Balance__c = 15, CO_Balance__c = 0
));
employees.add(new Employee__c(
    First_Name__c = 'Kavitha', Last_Name__c = 'Rajan', Employee_Code__c = 'EMP-ASM-004',
    Email__c = 'kavitha.rajan@freshfields.com', Phone__c = '9840000002',
    Department__c = 'Sales', Designation__c = 'Area Sales Manager',
    Band__c = 'Band 4',
    Date_of_Joining__c = Date.newInstance(2021, 1, 5), Is_Active__c = true,
    Zone__c = 'South', Region__c = 'South',
    HQ_City__c = 'Chennai',
    Address__c = '3, Anna Salai, T. Nagar, Chennai - 600017',
    Gross_Salary__c = 50000,
    Territory__c = terMap.get('TER-CHN-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 10, SL_Balance__c = 6, EL_Balance__c = 13, CO_Balance__c = 2
));

// Sales Representatives (8)
employees.add(new Employee__c(
    First_Name__c = 'Rahul', Last_Name__c = 'Verma', Employee_Code__c = 'EMP-SR-001',
    Email__c = 'rahul.verma@freshfields.com', Phone__c = '9810000010',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Band__c = 'Band 3',
    Date_of_Joining__c = Date.newInstance(2021, 6, 1), Is_Active__c = true,
    Zone__c = 'North', Region__c = 'North',
    HQ_City__c = 'Delhi',
    Address__c = '34, Lajpat Nagar, New Delhi - 110024',
    Gross_Salary__c = 30000,
    Territory__c = terMap.get('TER-DEL-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 6, SL_Balance__c = 3, EL_Balance__c = 8, CO_Balance__c = 1
));
employees.add(new Employee__c(
    First_Name__c = 'Sneha', Last_Name__c = 'Gupta', Employee_Code__c = 'EMP-SR-002',
    Email__c = 'sneha.gupta@freshfields.com', Phone__c = '9810000011',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Band__c = 'Band 3',
    Date_of_Joining__c = Date.newInstance(2021, 8, 15), Is_Active__c = true,
    Zone__c = 'North', Region__c = 'North',
    HQ_City__c = 'Delhi',
    Address__c = '56, Pitampura, New Delhi - 110034',
    Gross_Salary__c = 30000,
    Territory__c = terMap.get('TER-DEL-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 10, SL_Balance__c = 5, EL_Balance__c = 12, CO_Balance__c = 0
));
employees.add(new Employee__c(
    First_Name__c = 'Arjun', Last_Name__c = 'Deshmukh', Employee_Code__c = 'EMP-SR-003',
    Email__c = 'arjun.deshmukh@freshfields.com', Phone__c = '9820000010',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Band__c = 'Band 3',
    Date_of_Joining__c = Date.newInstance(2022, 1, 10), Is_Active__c = true,
    Zone__c = 'West', Region__c = 'West',
    HQ_City__c = 'Mumbai',
    Address__c = '11, Andheri East, Mumbai - 400069',
    Gross_Salary__c = 30000,
    Territory__c = terMap.get('TER-MUM-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 12, SL_Balance__c = 7, EL_Balance__c = 15, CO_Balance__c = 2
));
employees.add(new Employee__c(
    First_Name__c = 'Meera', Last_Name__c = 'Joshi', Employee_Code__c = 'EMP-SR-004',
    Email__c = 'meera.joshi@freshfields.com', Phone__c = '9820000011',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Band__c = 'Band 3',
    Date_of_Joining__c = Date.newInstance(2022, 3, 1), Is_Active__c = true,
    Zone__c = 'West', Region__c = 'West',
    HQ_City__c = 'Pune',
    Address__c = '7, Koregaon Park, Pune - 411001',
    Gross_Salary__c = 30000,
    Territory__c = terMap.get('TER-PUN-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 9, SL_Balance__c = 4, EL_Balance__c = 10, CO_Balance__c = 1
));
employees.add(new Employee__c(
    First_Name__c = 'Karthik', Last_Name__c = 'Iyer', Employee_Code__c = 'EMP-SR-005',
    Email__c = 'karthik.iyer@freshfields.com', Phone__c = '9840000010',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Band__c = 'Band 3',
    Date_of_Joining__c = Date.newInstance(2022, 5, 15), Is_Active__c = true,
    Zone__c = 'South', Region__c = 'South',
    HQ_City__c = 'Bangalore',
    Address__c = '9, Indiranagar, Bangalore - 560038',
    Gross_Salary__c = 30000,
    Territory__c = terMap.get('TER-BLR-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 11, SL_Balance__c = 6, EL_Balance__c = 14, CO_Balance__c = 0
));
employees.add(new Employee__c(
    First_Name__c = 'Lakshmi', Last_Name__c = 'Sundaram', Employee_Code__c = 'EMP-SR-006',
    Email__c = 'lakshmi.sundaram@freshfields.com', Phone__c = '9840000011',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Band__c = 'Band 3',
    Date_of_Joining__c = Date.newInstance(2022, 7, 1), Is_Active__c = true,
    Zone__c = 'South', Region__c = 'South',
    HQ_City__c = 'Chennai',
    Address__c = '20, Adyar, Chennai - 600020',
    Gross_Salary__c = 30000,
    Territory__c = terMap.get('TER-CHN-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 12, SL_Balance__c = 7, EL_Balance__c = 15, CO_Balance__c = 3
));
employees.add(new Employee__c(
    First_Name__c = 'Ankit', Last_Name__c = 'Agarwal', Employee_Code__c = 'EMP-SR-007',
    Email__c = 'ankit.agarwal@freshfields.com', Phone__c = '9830000010',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Band__c = 'Band 3',
    Date_of_Joining__c = Date.newInstance(2023, 2, 1), Is_Active__c = true,
    Zone__c = 'East', Region__c = 'East',
    HQ_City__c = 'Kolkata',
    Address__c = '14, Park Street, Kolkata - 700016',
    Gross_Salary__c = 30000,
    Territory__c = terMap.get('TER-KOL-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 8, SL_Balance__c = 5, EL_Balance__c = 9, CO_Balance__c = 0
));
employees.add(new Employee__c(
    First_Name__c = 'Divya', Last_Name__c = 'Reddy', Employee_Code__c = 'EMP-SR-008',
    Email__c = 'divya.reddy@freshfields.com', Phone__c = '9850000010',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Band__c = 'Band 3',
    Date_of_Joining__c = Date.newInstance(2023, 4, 15), Is_Active__c = true,
    Zone__c = 'South', Region__c = 'South',
    HQ_City__c = 'Hyderabad',
    Address__c = '6, Banjara Hills, Hyderabad - 500034',
    Gross_Salary__c = 30000,
    Territory__c = terMap.get('TER-HYD-001'),
    Week_Off_Days__c = 'Sunday',
    CL_Balance__c = 12, SL_Balance__c = 7, EL_Balance__c = 15, CO_Balance__c = 1
));

insert employees;
System.debug('Inserted employees: ' + employees.size());

// Pass 1b: Link employees to Users (test team from 15_test_team.apex)
// Test team emails: firstname.lastname@fmcg-test.com
// Explicit mapping: Employee Code → test team email prefix
Map<String, String> empToEmail = new Map<String, String>{
    'EMP-NSM-001' => 'rajesh.kapoor',
    'EMP-RSM-001' => 'suresh.menon',
    'EMP-RSM-002' => 'priya.nair',
    'EMP-ASM-001' => 'amit.sharma',
    'EMP-ASM-002' => 'deepa.pillai',
    'EMP-ASM-003' => 'vikram.singh',
    'EMP-ASM-004' => 'shalini.gupta',
    'EMP-SR-001'  => 'rahul.kumar',
    'EMP-SR-002'  => 'anjali.reddy',
    'EMP-SR-003'  => 'karthik.nambiar',
    'EMP-SR-004'  => 'meera.iyer',
    'EMP-SR-005'  => 'arjun.patel',
    'EMP-SR-006'  => 'divya.joshi',
    'EMP-SR-007'  => 'nikhil.rao',
    'EMP-SR-008'  => 'pooja.desai'
};

Map<String, Id> userByEmail = new Map<String, Id>();
for (User u : [SELECT Id, Email FROM User WHERE IsActive = true AND Email LIKE '%@fmcg-test.com']) {
    userByEmail.put(u.Email.substringBefore('@'), u.Id);
}
Id fallbackUserId = UserInfo.getUserId();

List<Employee__c> userLinks = new List<Employee__c>();
Integer matched = 0;
for (Employee__c e : [SELECT Id, Employee_Code__c FROM Employee__c WHERE Employee_Code__c LIKE 'EMP-%']) {
    String emailPrefix = empToEmail.get(e.Employee_Code__c);
    Id userId = (emailPrefix != null && userByEmail.containsKey(emailPrefix))
        ? userByEmail.get(emailPrefix) : fallbackUserId;
    if (userId != fallbackUserId) matched++;
    userLinks.add(new Employee__c(Id = e.Id, User__c = userId));
}
update userLinks;
System.debug('Linked employees to users: ' + matched + '/' + userLinks.size() + ' matched test team users');

// Pass 2: Link reporting hierarchy
Map<String, Employee__c> empMap = new Map<String, Employee__c>();
for (Employee__c e : [SELECT Id, Employee_Code__c FROM Employee__c WHERE Employee_Code__c LIKE 'EMP-%']) {
    empMap.put(e.Employee_Code__c, e);
}

List<Employee__c> updates = new List<Employee__c>();

// RSMs report to NSM
updates.add(new Employee__c(Id = empMap.get('EMP-RSM-001').Id, Reporting_Manager__c = empMap.get('EMP-NSM-001').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-RSM-002').Id, Reporting_Manager__c = empMap.get('EMP-NSM-001').Id));

// ASMs report to RSMs (geographic alignment)
// RSM-001 Suresh Menon (West): ASM-001 Mumbai + ASM-002 Bangalore
// RSM-002 Priya Sharma (North): ASM-003 Delhi + ASM-004 Chennai
updates.add(new Employee__c(Id = empMap.get('EMP-ASM-001').Id, Reporting_Manager__c = empMap.get('EMP-RSM-001').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-ASM-002').Id, Reporting_Manager__c = empMap.get('EMP-RSM-001').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-ASM-003').Id, Reporting_Manager__c = empMap.get('EMP-RSM-002').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-ASM-004').Id, Reporting_Manager__c = empMap.get('EMP-RSM-002').Id));

// Sales Reps report to ASMs (territory alignment)
// ASM-001 Amit (Mumbai): SR-003 Mumbai + SR-004 Pune
// ASM-002 Deepa (Bangalore): SR-005 Bangalore + SR-008 Hyderabad
// ASM-003 Vikram (Delhi): SR-001 Delhi + SR-002 Delhi
// ASM-004 Kavitha (Chennai): SR-006 Chennai + SR-007 Kolkata
updates.add(new Employee__c(Id = empMap.get('EMP-SR-001').Id, Reporting_Manager__c = empMap.get('EMP-ASM-003').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-002').Id, Reporting_Manager__c = empMap.get('EMP-ASM-003').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-003').Id, Reporting_Manager__c = empMap.get('EMP-ASM-001').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-004').Id, Reporting_Manager__c = empMap.get('EMP-ASM-001').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-005').Id, Reporting_Manager__c = empMap.get('EMP-ASM-002').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-006').Id, Reporting_Manager__c = empMap.get('EMP-ASM-004').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-007').Id, Reporting_Manager__c = empMap.get('EMP-ASM-004').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-008').Id, Reporting_Manager__c = empMap.get('EMP-ASM-002').Id));

update updates;
System.debug('Updated reporting hierarchy: ' + updates.size());

// Pass 3: Set L1 and L2 approvers (User lookups, not Employee lookups)
// L1_Approver__c / L2_Approver__c are Lookup(User), so we need User__c from the manager Employee
// Build empId → User__c map, and empId → managerId map
Map<Id, Id> empToUser = new Map<Id, Id>();       // Employee Id → User Id
Map<Id, Id> empToManager = new Map<Id, Id>();    // Employee Id → Manager Employee Id
for (Employee__c e : [SELECT Id, User__c, Reporting_Manager__c FROM Employee__c WHERE Employee_Code__c LIKE 'EMP-%']) {
    if (e.User__c != null) empToUser.put(e.Id, e.User__c);
    empToManager.put(e.Id, e.Reporting_Manager__c);
}

List<Employee__c> approverUpdates = new List<Employee__c>();
for (Employee__c e : [SELECT Id, Reporting_Manager__c FROM Employee__c WHERE Employee_Code__c LIKE 'EMP-%']) {
    Id managerId = e.Reporting_Manager__c;
    Id l1UserId = (managerId != null) ? empToUser.get(managerId) : null;
    Id grandManagerId = (managerId != null) ? empToManager.get(managerId) : null;
    Id l2UserId = (grandManagerId != null) ? empToUser.get(grandManagerId) : null;
    if (l1UserId != null || l2UserId != null) {
        approverUpdates.add(new Employee__c(Id = e.Id, L1_Approver__c = l1UserId, L2_Approver__c = l2UserId));
    }
}
if (!approverUpdates.isEmpty()) update approverUpdates;
System.debug('Updated L1/L2 approvers: ' + approverUpdates.size() + ' (requires User__c on employees)');

System.debug('Employee setup complete. Total: ' + employees.size());
