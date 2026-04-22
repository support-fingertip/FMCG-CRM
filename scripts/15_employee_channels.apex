// Seed: Assign default channels to employees
// All sales employees get all 3 channels by default; narrow per business needs post-seed.

List<Employee__c> employees = [SELECT Id, Employee_Code__c, Channels__c FROM Employee__c WHERE Is_Active__c = true];
List<Employee__c> toUpdate = new List<Employee__c>();

for (Employee__c emp : employees) {
    if (String.isBlank(emp.Channels__c)) {
        emp.Channels__c = 'GT;MT;E-Commerce';
        toUpdate.add(emp);
    }
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Updated ' + toUpdate.size() + ' employees with default channels (GT;MT;E-Commerce)');
} else {
    System.debug('All employees already have channels assigned');
}
