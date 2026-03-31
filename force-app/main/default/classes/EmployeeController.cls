/**
 * @description Controller for the Employee Management LWC component.
 *              Handles employee search, CRUD operations, picklist retrieval,
 *              and org-hierarchy queries for FMCG field sales workforce management.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class EmployeeController {

    // ── Get Employees (Search / Filter) ──────────────────────────────────────────

    /**
     * @description Searches and filters Employee__c records with support for
     *              text search, department/designation filtering, and active-only toggle.
     * @param searchTerm  Optional keyword to match against First_Name__c, Last_Name__c,
     *                    Employee_Code__c, or Email__c.
     * @param department  Optional Department__c picklist value to filter by.
     * @param designation Optional Designation__c picklist value to filter by.
     * @param activeOnly  When true (default), returns only active employees.
     * @return List of Employee__c records with related Territory and Reporting Manager fields.
     */
    @AuraEnabled
    public static List<Employee__c> getEmployees(
        String searchTerm, String department, String designation, Boolean activeOnly
    ) {
        if (activeOnly == null) {
            activeOnly = true;
        }

        String query = 'SELECT Id, Name, Employee_Code__c, First_Name__c, Last_Name__c, ' +
                        'Email__c, Phone__c, Department__c, Designation__c, ' +
                        'Date_of_Joining__c, Is_Active__c, Zone__c, Region__c, ' +
                        'Profile_Photo_URL__c, User__c, User__r.Name, Week_Off_Days__c, Gross_Salary__c, ' +
                        'Territory__c, Territory__r.Name, ' +
                        'Reporting_Manager__c, Reporting_Manager__r.First_Name__c, ' +
                        'Reporting_Manager__r.Last_Name__c, Reporting_Manager__r.Employee_Code__c ' +
                        'FROM Employee__c WHERE Id != null';

        if (activeOnly) {
            query += ' AND Is_Active__c = true';
        }

        if (String.isNotBlank(searchTerm)) {
            String searchKey = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            query += ' AND (First_Name__c LIKE :searchKey OR Last_Name__c LIKE :searchKey ' +
                     'OR Employee_Code__c LIKE :searchKey OR Email__c LIKE :searchKey)';
        }

        if (String.isNotBlank(department)) {
            query += ' AND Department__c = :department';
        }

        if (String.isNotBlank(designation)) {
            query += ' AND Designation__c = :designation';
        }

        query += ' ORDER BY First_Name__c LIMIT 200';
        return Database.query(query);
    }

    // ── Get Single Employee ──────────────────────────────────────────────────────

    /**
     * @description Retrieves a single Employee__c record with all fields and
     *              related lookup data.
     * @param employeeId The Employee__c record Id.
     * @return The Employee__c record, or null if not found.
     */
    @AuraEnabled
    public static Employee__c getEmployee(Id employeeId) {
        List<Employee__c> employees = [
            SELECT Id, Name, Employee_Code__c, First_Name__c, Last_Name__c,
                   Email__c, Phone__c, Department__c, Designation__c,
                   Date_of_Joining__c, Is_Active__c, Zone__c, Region__c,
                   Profile_Photo_URL__c, Address__c, User__c, User__r.Name, Week_Off_Days__c, Gross_Salary__c,
                   CL_Balance__c, SL_Balance__c, EL_Balance__c, CO_Balance__c,
                   Territory__c, Territory__r.Name,
                   Reporting_Manager__c, Reporting_Manager__r.First_Name__c,
                   Reporting_Manager__r.Last_Name__c, Reporting_Manager__r.Employee_Code__c
            FROM Employee__c
            WHERE Id = :employeeId
            LIMIT 1
        ];
        return employees.isEmpty() ? null : employees[0];
    }

    // ── Save Employee (Upsert) ───────────────────────────────────────────────────

    /**
     * @description Upserts an Employee__c record. Handles both creation of new
     *              employees and updates to existing records.
     * @param employee The Employee__c record to upsert.
     * @return The upserted Employee__c record with refreshed field values.
     */
    @AuraEnabled
    public static Employee__c saveEmployee(Employee__c employee) {
        try {
            upsert employee;

            return [
                SELECT Id, Name, Employee_Code__c, First_Name__c, Last_Name__c,
                       Email__c, Phone__c, Department__c, Designation__c,
                       Date_of_Joining__c, Is_Active__c, Zone__c, Region__c,
                       Profile_Photo_URL__c, Address__c, User__c, User__r.Name, Week_Off_Days__c, Gross_Salary__c,
                       CL_Balance__c, SL_Balance__c, EL_Balance__c, CO_Balance__c,
                       Territory__c, Territory__r.Name,
                       Reporting_Manager__c, Reporting_Manager__r.First_Name__c,
                       Reporting_Manager__r.Last_Name__c, Reporting_Manager__r.Employee_Code__c
                FROM Employee__c
                WHERE Id = :employee.Id
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Deactivate Employee ──────────────────────────────────────────────────────

    /**
     * @description Deactivates an employee by setting Is_Active__c to false.
     * @param employeeId The Employee__c record Id to deactivate.
     */
    @AuraEnabled
    public static void deactivateEmployee(Id employeeId) {
        try {
            Employee__c employee = [
                SELECT Id, Is_Active__c
                FROM Employee__c
                WHERE Id = :employeeId
                LIMIT 1
            ];

            if (!employee.Is_Active__c) {
                throw new AuraHandledException('This employee is already inactive.');
            }

            employee.Is_Active__c = false;
            update employee;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Get Employee by User Id ──────────────────────────────────────────────────

    /**
     * @description Finds an Employee__c record linked to a specific User record
     *              via the User__c lookup field.
     * @param userId The User Id to look up.
     * @return The matching Employee__c record, or null if no link exists.
     */
    @AuraEnabled
    public static Employee__c getEmployeeByUserId(Id userId) {
        List<Employee__c> employees = [
            SELECT Id, Name, Employee_Code__c, First_Name__c, Last_Name__c,
                   Email__c, Phone__c, Department__c, Designation__c,
                   Date_of_Joining__c, Is_Active__c, Zone__c, Region__c,
                   Profile_Photo_URL__c, Address__c, User__c, User__r.Name, Week_Off_Days__c, Gross_Salary__c,
                   CL_Balance__c, SL_Balance__c, EL_Balance__c, CO_Balance__c,
                   Territory__c, Territory__r.Name,
                   Reporting_Manager__c, Reporting_Manager__r.First_Name__c,
                   Reporting_Manager__r.Last_Name__c, Reporting_Manager__r.Employee_Code__c
            FROM Employee__c
            WHERE User__c = :userId
            AND Is_Active__c = true
            LIMIT 1
        ];
        return employees.isEmpty() ? null : employees[0];
    }

    // ── Get Department Options ───────────────────────────────────────────────────

    /**
     * @description Retrieves all available picklist values for the Department__c
     *              field on Employee__c.
     * @return List of picklist value strings.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getDepartmentOptions() {
        List<String> options = new List<String>();
        Schema.DescribeFieldResult fieldResult =
            Employee__c.Department__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(entry.getValue());
            }
        }
        return options;
    }

    // ── Get Designation Options ──────────────────────────────────────────────────

    /**
     * @description Retrieves all available picklist values for the Designation__c
     *              field on Employee__c.
     * @return List of picklist value strings.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getDesignationOptions() {
        List<String> options = new List<String>();
        Schema.DescribeFieldResult fieldResult =
            Employee__c.Designation__c.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(entry.getValue());
            }
        }
        return options;
    }

    // ── Get Direct Reports ───────────────────────────────────────────────────────

    /**
     * @description Retrieves all active employees who report to the specified
     *              manager via the Reporting_Manager__c self-referencing lookup.
     * @param employeeId The manager's Employee__c record Id.
     * @return List of Employee__c records reporting to this manager.
     */
    @AuraEnabled
    public static List<Employee__c> getDirectReports(Id employeeId) {
        return [
            SELECT Id, Name, Employee_Code__c, First_Name__c, Last_Name__c,
                   Email__c, Phone__c, Department__c, Designation__c,
                   Date_of_Joining__c, Is_Active__c, Zone__c, Region__c,
                   Profile_Photo_URL__c, User__c, User__r.Name, Week_Off_Days__c, Gross_Salary__c,
                   Territory__c, Territory__r.Name,
                   Reporting_Manager__c
            FROM Employee__c
            WHERE Reporting_Manager__c = :employeeId
            AND Is_Active__c = true
            ORDER BY First_Name__c
        ];
    }
}
