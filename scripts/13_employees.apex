// Script 13: Employee Hierarchy - NSM > RSM > ASM > Sales Reps
// Run: sf apex run -f scripts/13_employees.apex
// Prerequisite: 02_territory_master.apex

// Fetch territories
Map<String, Id> terMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c FROM Territory_Master__c WHERE Is_Active__c = true]) {
    terMap.put(t.Territory_Code__c, t.Id);
}

// Pass 1: Create all employees without Reporting_Manager
List<Employee__c> employees = new List<Employee__c>();

// National Sales Manager (1)
employees.add(new Employee__c(
    First_Name__c = 'Rajesh', Last_Name__c = 'Kapoor', Employee_Code__c = 'EMP-NSM-001',
    Email__c = 'rajesh.kapoor@freshfields.com', Phone__c = '9810000001',
    Department__c = 'Sales', Designation__c = 'National Sales Manager',
    Date_of_Joining__c = Date.newInstance(2018, 4, 1), Is_Active__c = true,
    Zone__c = 'All India', Region__c = 'National',
    CL_Balance__c = 12, SL_Balance__c = 7, EL_Balance__c = 15, CO_Balance__c = 2
));

// Regional Sales Managers (2)
employees.add(new Employee__c(
    First_Name__c = 'Suresh', Last_Name__c = 'Menon', Employee_Code__c = 'EMP-RSM-001',
    Email__c = 'suresh.menon@freshfields.com', Phone__c = '9820000001',
    Department__c = 'Sales', Designation__c = 'Regional Sales Manager',
    Date_of_Joining__c = Date.newInstance(2019, 6, 15), Is_Active__c = true,
    Zone__c = 'West', Region__c = 'West',
    Territory__c = terMap.get('TER-MUM-001'),
    CL_Balance__c = 10, SL_Balance__c = 5, EL_Balance__c = 12, CO_Balance__c = 1
));
employees.add(new Employee__c(
    First_Name__c = 'Priya', Last_Name__c = 'Sharma', Employee_Code__c = 'EMP-RSM-002',
    Email__c = 'priya.sharma@freshfields.com', Phone__c = '9810000002',
    Department__c = 'Sales', Designation__c = 'Regional Sales Manager',
    Date_of_Joining__c = Date.newInstance(2019, 8, 1), Is_Active__c = true,
    Zone__c = 'North', Region__c = 'North',
    Territory__c = terMap.get('TER-DEL-001'),
    CL_Balance__c = 11, SL_Balance__c = 6, EL_Balance__c = 14, CO_Balance__c = 0
));

// Area Sales Managers (4)
employees.add(new Employee__c(
    First_Name__c = 'Amit', Last_Name__c = 'Patel', Employee_Code__c = 'EMP-ASM-001',
    Email__c = 'amit.patel@freshfields.com', Phone__c = '9820000002',
    Department__c = 'Sales', Designation__c = 'Area Sales Manager',
    Date_of_Joining__c = Date.newInstance(2020, 3, 10), Is_Active__c = true,
    Zone__c = 'West', Region__c = 'West',
    Territory__c = terMap.get('TER-MUM-001'),
    CL_Balance__c = 8, SL_Balance__c = 4, EL_Balance__c = 10, CO_Balance__c = 3
));
employees.add(new Employee__c(
    First_Name__c = 'Deepa', Last_Name__c = 'Nair', Employee_Code__c = 'EMP-ASM-002',
    Email__c = 'deepa.nair@freshfields.com', Phone__c = '9840000001',
    Department__c = 'Sales', Designation__c = 'Area Sales Manager',
    Date_of_Joining__c = Date.newInstance(2020, 5, 20), Is_Active__c = true,
    Zone__c = 'South', Region__c = 'South',
    Territory__c = terMap.get('TER-BLR-001'),
    CL_Balance__c = 9, SL_Balance__c = 7, EL_Balance__c = 11, CO_Balance__c = 1
));
employees.add(new Employee__c(
    First_Name__c = 'Vikram', Last_Name__c = 'Singh', Employee_Code__c = 'EMP-ASM-003',
    Email__c = 'vikram.singh@freshfields.com', Phone__c = '9810000003',
    Department__c = 'Sales', Designation__c = 'Area Sales Manager',
    Date_of_Joining__c = Date.newInstance(2020, 7, 1), Is_Active__c = true,
    Zone__c = 'North', Region__c = 'North',
    Territory__c = terMap.get('TER-DEL-001'),
    CL_Balance__c = 12, SL_Balance__c = 7, EL_Balance__c = 15, CO_Balance__c = 0
));
employees.add(new Employee__c(
    First_Name__c = 'Kavitha', Last_Name__c = 'Rajan', Employee_Code__c = 'EMP-ASM-004',
    Email__c = 'kavitha.rajan@freshfields.com', Phone__c = '9840000002',
    Department__c = 'Sales', Designation__c = 'Area Sales Manager',
    Date_of_Joining__c = Date.newInstance(2021, 1, 5), Is_Active__c = true,
    Zone__c = 'South', Region__c = 'South',
    Territory__c = terMap.get('TER-CHN-001'),
    CL_Balance__c = 10, SL_Balance__c = 6, EL_Balance__c = 13, CO_Balance__c = 2
));

// Sales Representatives (8)
employees.add(new Employee__c(
    First_Name__c = 'Rahul', Last_Name__c = 'Verma', Employee_Code__c = 'EMP-SR-001',
    Email__c = 'rahul.verma@freshfields.com', Phone__c = '9810000010',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Date_of_Joining__c = Date.newInstance(2021, 6, 1), Is_Active__c = true,
    Zone__c = 'North', Region__c = 'North',
    Territory__c = terMap.get('TER-DEL-001'),
    CL_Balance__c = 6, SL_Balance__c = 3, EL_Balance__c = 8, CO_Balance__c = 1
));
employees.add(new Employee__c(
    First_Name__c = 'Sneha', Last_Name__c = 'Gupta', Employee_Code__c = 'EMP-SR-002',
    Email__c = 'sneha.gupta@freshfields.com', Phone__c = '9810000011',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Date_of_Joining__c = Date.newInstance(2021, 8, 15), Is_Active__c = true,
    Zone__c = 'North', Region__c = 'North',
    Territory__c = terMap.get('TER-DEL-001'),
    CL_Balance__c = 10, SL_Balance__c = 5, EL_Balance__c = 12, CO_Balance__c = 0
));
employees.add(new Employee__c(
    First_Name__c = 'Arjun', Last_Name__c = 'Deshmukh', Employee_Code__c = 'EMP-SR-003',
    Email__c = 'arjun.deshmukh@freshfields.com', Phone__c = '9820000010',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Date_of_Joining__c = Date.newInstance(2022, 1, 10), Is_Active__c = true,
    Zone__c = 'West', Region__c = 'West',
    Territory__c = terMap.get('TER-MUM-001'),
    CL_Balance__c = 12, SL_Balance__c = 7, EL_Balance__c = 15, CO_Balance__c = 2
));
employees.add(new Employee__c(
    First_Name__c = 'Meera', Last_Name__c = 'Joshi', Employee_Code__c = 'EMP-SR-004',
    Email__c = 'meera.joshi@freshfields.com', Phone__c = '9820000011',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Date_of_Joining__c = Date.newInstance(2022, 3, 1), Is_Active__c = true,
    Zone__c = 'West', Region__c = 'West',
    Territory__c = terMap.get('TER-PUN-001'),
    CL_Balance__c = 9, SL_Balance__c = 4, EL_Balance__c = 10, CO_Balance__c = 1
));
employees.add(new Employee__c(
    First_Name__c = 'Karthik', Last_Name__c = 'Iyer', Employee_Code__c = 'EMP-SR-005',
    Email__c = 'karthik.iyer@freshfields.com', Phone__c = '9840000010',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Date_of_Joining__c = Date.newInstance(2022, 5, 15), Is_Active__c = true,
    Zone__c = 'South', Region__c = 'South',
    Territory__c = terMap.get('TER-BLR-001'),
    CL_Balance__c = 11, SL_Balance__c = 6, EL_Balance__c = 14, CO_Balance__c = 0
));
employees.add(new Employee__c(
    First_Name__c = 'Lakshmi', Last_Name__c = 'Sundaram', Employee_Code__c = 'EMP-SR-006',
    Email__c = 'lakshmi.sundaram@freshfields.com', Phone__c = '9840000011',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Date_of_Joining__c = Date.newInstance(2022, 7, 1), Is_Active__c = true,
    Zone__c = 'South', Region__c = 'South',
    Territory__c = terMap.get('TER-CHN-001'),
    CL_Balance__c = 12, SL_Balance__c = 7, EL_Balance__c = 15, CO_Balance__c = 3
));
employees.add(new Employee__c(
    First_Name__c = 'Ankit', Last_Name__c = 'Agarwal', Employee_Code__c = 'EMP-SR-007',
    Email__c = 'ankit.agarwal@freshfields.com', Phone__c = '9830000010',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Date_of_Joining__c = Date.newInstance(2023, 2, 1), Is_Active__c = true,
    Zone__c = 'East', Region__c = 'East',
    Territory__c = terMap.get('TER-KOL-001'),
    CL_Balance__c = 8, SL_Balance__c = 5, EL_Balance__c = 9, CO_Balance__c = 0
));
employees.add(new Employee__c(
    First_Name__c = 'Divya', Last_Name__c = 'Reddy', Employee_Code__c = 'EMP-SR-008',
    Email__c = 'divya.reddy@freshfields.com', Phone__c = '9850000010',
    Department__c = 'Sales', Designation__c = 'Sales Representative',
    Date_of_Joining__c = Date.newInstance(2023, 4, 15), Is_Active__c = true,
    Zone__c = 'South', Region__c = 'South',
    Territory__c = terMap.get('TER-HYD-001'),
    CL_Balance__c = 12, SL_Balance__c = 7, EL_Balance__c = 15, CO_Balance__c = 1
));

insert employees;
System.debug('Inserted employees: ' + employees.size());

// Pass 2: Link reporting hierarchy
Map<String, Employee__c> empMap = new Map<String, Employee__c>();
for (Employee__c e : [SELECT Id, Employee_Code__c FROM Employee__c WHERE Employee_Code__c LIKE 'EMP-%']) {
    empMap.put(e.Employee_Code__c, e);
}

List<Employee__c> updates = new List<Employee__c>();

// RSMs report to NSM
updates.add(new Employee__c(Id = empMap.get('EMP-RSM-001').Id, Reporting_Manager__c = empMap.get('EMP-NSM-001').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-RSM-002').Id, Reporting_Manager__c = empMap.get('EMP-NSM-001').Id));

// ASMs report to RSMs
updates.add(new Employee__c(Id = empMap.get('EMP-ASM-001').Id, Reporting_Manager__c = empMap.get('EMP-RSM-001').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-ASM-002').Id, Reporting_Manager__c = empMap.get('EMP-RSM-001').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-ASM-003').Id, Reporting_Manager__c = empMap.get('EMP-RSM-002').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-ASM-004').Id, Reporting_Manager__c = empMap.get('EMP-RSM-001').Id));

// Sales Reps report to ASMs
updates.add(new Employee__c(Id = empMap.get('EMP-SR-001').Id, Reporting_Manager__c = empMap.get('EMP-ASM-003').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-002').Id, Reporting_Manager__c = empMap.get('EMP-ASM-003').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-003').Id, Reporting_Manager__c = empMap.get('EMP-ASM-001').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-004').Id, Reporting_Manager__c = empMap.get('EMP-ASM-001').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-005').Id, Reporting_Manager__c = empMap.get('EMP-ASM-002').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-006').Id, Reporting_Manager__c = empMap.get('EMP-ASM-004').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-007').Id, Reporting_Manager__c = empMap.get('EMP-ASM-003').Id));
updates.add(new Employee__c(Id = empMap.get('EMP-SR-008').Id, Reporting_Manager__c = empMap.get('EMP-ASM-002').Id));

update updates;
System.debug('Updated reporting hierarchy: ' + updates.size());
System.debug('Employee setup complete. Total: ' + employees.size());
