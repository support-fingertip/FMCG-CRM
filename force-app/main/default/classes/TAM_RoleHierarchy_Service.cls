public with sharing class TAM_RoleHierarchy_Service {

    public static Set<ID> getRoleSubordinateUsers(Id userId) {

        Set<Id> allSubRoleIds = getAllSubRoleIds(new Set<ID>{userId});
        allSubRoleIds.add(userId);
        Map<Id, User> users = new Map<Id, User>([SELECT Id, Name FROM User WHERE Id IN :allSubRoleIds]);

        return users.keySet();
    }

    // Recursive function
    private static Set<ID> getAllSubRoleIds(Set<ID> userId) {

        Set<ID> currentRoleIds = new Set<ID>();

        for (User userRole : [SELECT Id, Name, ManagerId FROM User WHERE ManagerId IN :userId AND ManagerId != null]) {
            currentRoleIds.add(userRole.Id);
        }
        if (currentRoleIds.size() > 0) {
            currentRoleIds.addAll(getAllSubRoleIds(currentRoleIds));
        }
        return currentRoleIds;
    }
}
