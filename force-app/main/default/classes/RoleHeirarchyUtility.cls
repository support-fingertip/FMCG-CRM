public with sharing class RoleHeirarchyUtility {
    
    public static Set<ID> getRoleSubordinateUsers(Id userId) {
        
        Set<Id> allSubRoleIds = getAllSubRoleIds(New Set<ID>{userId});
        allSubRoleIds.add(userId);
        Map<Id, User> users = new Map<Id, User>([SELECT Id, Name From  User Where Id IN  :allSubRoleIds]);
        
        return users.keySet();
    }
    
    //Recursive function
    private static Set<ID> getAllSubRoleIds(Set<ID> userId) {
        
        Set<ID> currentRoleIds = new Set<ID>();
        
        for(User userRole :[SELECT Id, Name,ManagerId From  User Where ManagerId IN :userId AND ManagerId != null]){
            currentRoleIds.add(userRole.Id);
        }
        if(currentRoleIds.size() > 0){
            currentRoleIds.addAll(getAllSubRoleIds(currentRoleIds));
        }        
        return currentRoleIds;   
    }
}