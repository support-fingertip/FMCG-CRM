public class TargetAllocationNewUICtrl 
{
    public class DataBox{
        @AuraEnabled
        public list<user> userList;
        @AuraEnabled
        public List<Target_Period__c> periodsList;
        @AuraEnabled
        public List<Target_Period__c> currentPeriods;
        @AuraEnabled
        public string period;
        @AuraEnabled
        public string userProfileName;
        @AuraEnabled
        public List<Target_Criteria__c> targetCriterias; 
        @AuraEnabled
        public string currentUserId;
        @AuraEnabled
        public List<Target_Actual__c> targetActuals; 
        @AuraEnabled
        public String initialTargetAssignmentProfile; 
        @AuraEnabled
        public Map<Id, Decimal> parentToTotalTargetValueMap;
    }
    
    @AuraEnabled
    public static DataBox getAllData(){
        DataBox dx = new DataBox();
     
        Set<ID> UserIds = RoleHeirarchyUtility.getRoleSubordinateUsers(UserInfo.getUserId()); 
       
        User userRecord = [select id,Heirarchial_Number__c from user where Profile.Name = 'System Administrator' limit 1];
        decimal heirarchialNumber = userRecord.Heirarchial_Number__c;
        
        dx.userList = [select Id,Name,ManagerId,Manager.ManagerId,Profile.Name from User where id in:UserIds
                       and Heirarchial_Number__c <=: heirarchialNumber and isactive = true order by Heirarchial_Number__c DESC];
        
        Boolean isCurrentUserPresent = false;
        for (User u : dx.userList) {
            if (u.Id == UserInfo.getUserId()) {
                isCurrentUserPresent = true;
                break;
            }
        }
        dx.currentUserId = isCurrentUserPresent ? UserInfo.getUserId() : '';
        
        dx.periodsList = [select id, name,Start_Date__c,End_Date__c from Target_Period__c order by Createddate desc limit 12];
        dx.period = [select id from Target_Period__c where Start_Date__c <= TODAY and End_Date__c>= TODAY limit 1].Id;
       
        dx.targetActuals = [select Id,Target_Period__c,Target_Value__c,Achievement_Value__c,Target_Criteria__c,
                                      Target_Criteria__r.Name,User__c,User__r.Name,Parent_Target__c,
                                      Teams_Target__c,Teams_Achievement__c,Pending_Target__c
                                      from Target_Actual__c where Target_Criteria__r.Active__c = true and 
                                      (Target_Period__c =:dx.period or Parent_Target__r.Target_Period__c =:dx.period)
                                      and (User__c IN:UserIds) order by Target_Criteria__r.Name];
        
        Datetime currentDatetime = System.now();
        Integer currentYear = currentDatetime.year();  
        integer cuMonth=System.today().month();
        Date startYear = Date.newInstance(currentYear, cuMonth, 1);        
        if(cuMonth<4){
            currentYear=currentYear-1;
        }
        Date endYear = Date.newInstance(currentYear + 1, 3, 31);
        
        dx.currentPeriods = [select id, name from Target_Period__c where Start_Date__c >= :startYear AND end_Date__c <= :endYear order by Createddate ];
        return dx;
    } 
    
    @AuraEnabled
    public static List<Target_Actual__c> getTargetActuals(String period,String userId){
        if(period == null || period == ''){
            period = [select id from Target_Period__c where Start_Date__c <= TODAY and End_Date__c>= TODAY].Id;
        }
        string currentUserId = userId != null && userId !='' ? userId: UserInfo.getUserId();
        Set<ID> UserIds = RoleHeirarchyUtility.getRoleSubordinateUsers(currentUserId);  
        List<Target_Actual__c> items = [select Id,Target_Period__c,Target_Value__c,Achievement_Value__c,Target_Criteria__c,
                                      Target_Criteria__r.Name,User__c,User__r.Name,Parent_Target__c,
                                      Teams_Target__c,Teams_Achievement__c,Pending_Target__c
                                      from Target_Actual__c where Target_Criteria__r.Active__c = true and 
                                      (Target_Period__c =:period or Parent_Target__r.Target_Period__c =:period)
                                      and (User__c IN:UserIds) order by Target_Criteria__r.Name];
        
        return items;
    }
    
    @AuraEnabled
    public static DataBox getUserTargets(String period,String userId){
        system.debug('period---------->' + period);
        system.debug('userId--------->' + userId);
        DataBox dx = new DataBox();
        if(period == null || period == ''){
            period = [select id from Target_Period__c where Start_Date__c <= TODAY and End_Date__c>= TODAY].Id;
        }
        
        list<Target_Criteria__c> targetCriteriasList = new list<Target_Criteria__c>();
        targetCriteriasList = [SELECT Id, Name, Object__c, Field__c, Operator__c, Date_Field__c, User_Field__c
                                FROM Target_Criteria__c where Active__c = true order by Name];
     
        dx.targetCriterias = targetCriteriasList;
        dx.targetActuals = [select Id,Target_Period__c,Target_Value__c,Achievement_Value__c,Target_Criteria__c,
                          Target_Criteria__r.Name,User__c,User__r.Name,Parent_Target__c,
                          Teams_Target__c,Teams_Achievement__c,Pending_Target__c
                          from Target_Actual__c where Target_Criteria__r.Active__c = true and 
                          (Target_Period__c =:period or Parent_Target__r.Target_Period__c =:period)
                          and (User__c =: userId) order by Target_Criteria__r.Name];
        
        if(!dx.targetActuals.isEmpty())
        {
            List<Id> parentIds = new List<Id>();
            for (Target_Actual__c ta : dx.targetActuals) {
                parentIds.add(ta.Id);
            }
            
            Map<Id, Decimal> parentToTotalTargetValueMap = new Map<Id, Decimal>();
            
            if (!parentIds.isEmpty()) {
                AggregateResult[] groupedResults = [
                    SELECT Parent_Target__c, SUM(Target_Value__c) totalTargetValue 
                    FROM Target_Actual__c 
                    WHERE Parent_Target__c IN :parentIds 
                    GROUP BY Parent_Target__c
                ];
                
                for (AggregateResult ar : groupedResults) {
                    Id parentId = (Id) ar.get('Parent_Target__c');
                    Decimal totalValue = (Decimal) ar.get('totalTargetValue');
                    parentToTotalTargetValueMap.put(parentId, totalValue);
                }
            }
            dx.parentToTotalTargetValueMap = parentToTotalTargetValueMap;
            
            system.debug('Parent to Total Target Value Map: ' + parentToTotalTargetValueMap);
        }
        
        return dx;
    }
    
    @AuraEnabled
    public static List<Target_Actual__c> saveTargets(String targetList, string selctdperiod){ 
        List<Target_Actual__c> targetActualList = (List<Target_Actual__c>)JSON.deserialize(targetList, List<Target_Actual__c>.class);
        system.debug('Selected Period' + selctdperiod);
        system.debug('targetActualList' + targetActualList);
        
        string currentUserId = UserInfo.getUserId();
        Set<ID> UserIds = RoleHeirarchyUtility.getRoleSubordinateUsers(currentUserId); 
        
        List<Target_Actual__c> itemsToUpdate = new List<Target_Actual__c>();
        
        for(Target_Actual__c itm : targetActualList){
            if(itm.Target_Value__c != null && itm.Target_Value__c != 0){
                Target_Actual__c item1 = new Target_Actual__c();
                item1.Target_Criteria__c = itm.Target_Criteria__c;
                item1.Target_Value__c = itm.Target_Value__c;
                item1.Parent_Target__c = itm.Parent_Target__c;
                item1.Target_Period__c = selctdperiod;
                item1.User__c = itm.User__c;
                
                if(itm.Id != null){
                    item1.Id = itm.Id;
                }
                
                itemsToUpdate.add(item1);
            }
        }  
        
        if(itemsToUpdate.size() > 0)
        {
            upsert itemsToUpdate;
        }
        
        List<Target_Actual__c> items = [select Id,Target_Period__c,Target_Value__c,Achievement_Value__c,Target_Criteria__c,
                                      Target_Criteria__r.Name,User__c,User__r.Name,Parent_Target__c,
                                      Teams_Target__c,Teams_Achievement__c,Pending_Target__c
                                      from Target_Actual__c where 
                                      (Target_Period__c =:selctdperiod or Parent_Target__r.Target_Period__c =:selctdperiod)
                                      and (User__c IN:UserIds) order by Target_Criteria__r.Name];
        
        return items;
    }
    
    @AuraEnabled
    public static List<Target_Actual__c> saveAdminTargets(List<Target_Actual__c> targetActuals, string selectedAdminPeriod, string selectedPeriod, string userId) {
        system.debug('targetActuals ' + targetActuals);
        system.debug('selectedAdminPeriod ' + selectedAdminPeriod);
        
        if(targetActuals.size() > 0){
            for(Target_Actual__c ta : targetActuals){
                ta.Target_Period__c = selectedAdminPeriod;
                ta.User__c = userId;
                if(ta.Achievement_Value__c == null){
                    ta.Achievement_Value__c = 0;
                }
            }
            system.debug('targetActuals after update ' + targetActuals);
            upsert targetActuals;
        }
      
        Set<ID> UserIds = RoleHeirarchyUtility.getRoleSubordinateUsers(UserInfo.getUserId()); 
        
        List<Target_Actual__c> items = [select Id,Target_Period__c,Target_Value__c,Achievement_Value__c,Target_Criteria__c,
                                      Target_Criteria__r.Name,User__c,User__r.Name,Parent_Target__c,
                                      Teams_Target__c,Teams_Achievement__c,Pending_Target__c
                                      from Target_Actual__c where Target_Criteria__r.Active__c = true and 
                                      (Target_Period__c =:selectedPeriod or Parent_Target__r.Target_Period__c =:selectedPeriod)
                                      and (User__c IN: UserIds) order by Target_Criteria__r.Name];
        
        return items;
    }
}