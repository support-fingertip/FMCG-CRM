public with sharing class TAM_RoleHierarchy_Service {

    private static final Integer MAX_DEPTH = 6; // Prevent infinite recursion / governor limits

    public static Set<ID> getRoleSubordinateUsers(Id userId) {
        Set<Id> allSubRoleIds = getAllSubRoleIds(new Set<ID>{userId}, 0);
        allSubRoleIds.add(userId);
        return allSubRoleIds;
    }

    // Recursive function with depth limit and active user filter
    private static Set<ID> getAllSubRoleIds(Set<ID> userIds, Integer depth) {
        if (depth >= MAX_DEPTH || userIds.isEmpty()) return new Set<Id>();

        Set<ID> currentRoleIds = new Set<ID>();

        for (User userRole : [
            SELECT Id FROM User
            WHERE ManagerId IN :userIds
            AND ManagerId != null
            AND IsActive = true
        ]) {
            currentRoleIds.add(userRole.Id);
        }

        if (!currentRoleIds.isEmpty()) {
            currentRoleIds.addAll(getAllSubRoleIds(currentRoleIds, depth + 1));
        }

        return currentRoleIds;
    }
}
