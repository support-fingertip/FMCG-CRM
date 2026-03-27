public class TAM_TargetAllocation_Controller {

    public class DataBox {
        @AuraEnabled
        public List<User> userList;
        @AuraEnabled
        public List<Target_Period__c> periodsList;
        @AuraEnabled
        public List<Target_Period__c> currentPeriods;
        @AuraEnabled
        public String period;
        @AuraEnabled
        public String userProfileName;
        @AuraEnabled
        public List<Target_Criteria__c> targetCriterias;
        @AuraEnabled
        public String currentUserId;
        @AuraEnabled
        public List<Target_Actual__c> targetActuals;
        @AuraEnabled
        public String initialTargetAssignmentProfile;
        @AuraEnabled
        public Map<Id, Decimal> parentToTotalTargetValueMap;
    }

    @AuraEnabled
    public static DataBox getAllData() {
        DataBox dx = new DataBox();

        Set<ID> userIds = TAM_RoleHierarchy_Service.getRoleSubordinateUsers(UserInfo.getUserId());

        dx.userList = [
            SELECT Id, Name, ManagerId, Manager.ManagerId, Profile.Name
            FROM User
            WHERE Id IN :userIds
            AND IsActive = true
            ORDER BY Name
        ];

        Boolean isCurrentUserPresent = false;
        for (User u : dx.userList) {
            if (u.Id == UserInfo.getUserId()) {
                isCurrentUserPresent = true;
                break;
            }
        }
        dx.currentUserId = isCurrentUserPresent ? UserInfo.getUserId() : '';

        dx.periodsList = [SELECT Id, Name, Start_Date__c, End_Date__c FROM Target_Period__c ORDER BY CreatedDate DESC LIMIT 12];

        List<Target_Period__c> currentPeriodList = [SELECT Id FROM Target_Period__c WHERE Start_Date__c <= TODAY AND End_Date__c >= TODAY LIMIT 1];
        dx.period = currentPeriodList.isEmpty() ? '' : currentPeriodList[0].Id;

        if (String.isNotBlank(dx.period)) {
            dx.targetActuals = [
                SELECT Id, Target_Period__c, Target_Value__c, Achievement_Value__c, Target_Criteria__c,
                       Target_Criteria__r.Name, User__c, User__r.Name, Parent_Target__c,
                       Teams_Target__c, Teams_Achievement__c, Pending_Target__c
                FROM Target_Actual__c
                WHERE Target_Criteria__r.Active__c = true
                AND (Target_Period__c = :dx.period OR Parent_Target__r.Target_Period__c = :dx.period)
                AND User__c IN :userIds
                ORDER BY Target_Criteria__r.Name
            ];
        } else {
            dx.targetActuals = new List<Target_Actual__c>();
        }

        Datetime currentDatetime = System.now();
        Integer currentYear = currentDatetime.year();
        Integer currentMonth = System.today().month();
        Date startYear = Date.newInstance(currentYear, currentMonth, 1);
        if (currentMonth < 4) {
            currentYear = currentYear - 1;
        }
        Date endYear = Date.newInstance(currentYear + 1, 3, 31);

        dx.currentPeriods = [SELECT Id, Name FROM Target_Period__c WHERE Start_Date__c >= :startYear AND End_Date__c <= :endYear ORDER BY CreatedDate];
        return dx;
    }

    @AuraEnabled
    public static List<Target_Actual__c> getTargetActuals(String period, String userId) {
        if (String.isBlank(period)) {
            List<Target_Period__c> currentPeriodList = [SELECT Id FROM Target_Period__c WHERE Start_Date__c <= TODAY AND End_Date__c >= TODAY LIMIT 1];
            period = currentPeriodList.isEmpty() ? '' : currentPeriodList[0].Id;
        }
        if (String.isBlank(period)) return new List<Target_Actual__c>();

        String currentUserId = String.isNotBlank(userId) ? userId : UserInfo.getUserId();
        Set<ID> userIds = TAM_RoleHierarchy_Service.getRoleSubordinateUsers(currentUserId);

        List<Target_Actual__c> items = [
            SELECT Id, Target_Period__c, Target_Value__c, Achievement_Value__c, Target_Criteria__c,
                   Target_Criteria__r.Name, User__c, User__r.Name, Parent_Target__c,
                   Teams_Target__c, Teams_Achievement__c, Pending_Target__c
            FROM Target_Actual__c
            WHERE Target_Criteria__r.Active__c = true
            AND (Target_Period__c = :period OR Parent_Target__r.Target_Period__c = :period)
            AND User__c IN :userIds
            ORDER BY Target_Criteria__r.Name
        ];

        return items;
    }

    @AuraEnabled
    public static DataBox getUserTargets(String period, String userId) {
        DataBox dx = new DataBox();
        if (String.isBlank(period)) {
            List<Target_Period__c> currentPeriodList = [SELECT Id FROM Target_Period__c WHERE Start_Date__c <= TODAY AND End_Date__c >= TODAY LIMIT 1];
            period = currentPeriodList.isEmpty() ? '' : currentPeriodList[0].Id;
        }
        if (String.isBlank(period)) return dx;

        List<Target_Criteria__c> targetCriteriasList = [
            SELECT Id, Name, Object__c, Field__c, Operator__c, Date_Field__c, User_Field__c
            FROM Target_Criteria__c
            WHERE Active__c = true
            ORDER BY Name
        ];

        dx.targetCriterias = targetCriteriasList;
        dx.targetActuals = [
            SELECT Id, Target_Period__c, Target_Value__c, Achievement_Value__c, Target_Criteria__c,
                   Target_Criteria__r.Name, User__c, User__r.Name, Parent_Target__c,
                   Teams_Target__c, Teams_Achievement__c, Pending_Target__c
            FROM Target_Actual__c
            WHERE Target_Criteria__r.Active__c = true
            AND (Target_Period__c = :period OR Parent_Target__r.Target_Period__c = :period)
            AND User__c = :userId
            ORDER BY Target_Criteria__r.Name
        ];

        if (!dx.targetActuals.isEmpty()) {
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
        }

        return dx;
    }

    @AuraEnabled
    public static List<Target_Actual__c> saveTargets(String targetList, String selectedPeriod) {
        List<Target_Actual__c> targetActualList = (List<Target_Actual__c>) JSON.deserialize(targetList, List<Target_Actual__c>.class);

        String currentUserId = UserInfo.getUserId();
        Set<ID> userIds = TAM_RoleHierarchy_Service.getRoleSubordinateUsers(currentUserId);

        List<Target_Actual__c> itemsToUpdate = new List<Target_Actual__c>();

        for (Target_Actual__c itm : targetActualList) {
            if (itm.Target_Value__c != null && itm.Target_Value__c != 0) {
                Target_Actual__c item1 = new Target_Actual__c();
                item1.Target_Criteria__c = itm.Target_Criteria__c;
                item1.Target_Value__c = itm.Target_Value__c;
                item1.Parent_Target__c = itm.Parent_Target__c;
                item1.Target_Period__c = selectedPeriod;
                item1.User__c = itm.User__c;

                if (itm.Id != null) {
                    item1.Id = itm.Id;
                }

                itemsToUpdate.add(item1);
            }
        }

        if (!itemsToUpdate.isEmpty()) {
            upsert itemsToUpdate;
        }

        List<Target_Actual__c> items = [
            SELECT Id, Target_Period__c, Target_Value__c, Achievement_Value__c, Target_Criteria__c,
                   Target_Criteria__r.Name, User__c, User__r.Name, Parent_Target__c,
                   Teams_Target__c, Teams_Achievement__c, Pending_Target__c
            FROM Target_Actual__c
            WHERE (Target_Period__c = :selectedPeriod OR Parent_Target__r.Target_Period__c = :selectedPeriod)
            AND User__c IN :userIds
            ORDER BY Target_Criteria__r.Name
        ];

        return items;
    }

    @AuraEnabled
    public static List<Target_Actual__c> saveAdminTargets(List<Target_Actual__c> targetActuals, String selectedAdminPeriod, String selectedPeriod, String userId) {

        if (!targetActuals.isEmpty()) {
            for (Target_Actual__c ta : targetActuals) {
                ta.Target_Period__c = selectedAdminPeriod;
                ta.User__c = userId;
                if (ta.Achievement_Value__c == null) {
                    ta.Achievement_Value__c = 0;
                }
            }
            upsert targetActuals;
        }

        Set<ID> userIds = TAM_RoleHierarchy_Service.getRoleSubordinateUsers(UserInfo.getUserId());

        List<Target_Actual__c> items = [
            SELECT Id, Target_Period__c, Target_Value__c, Achievement_Value__c, Target_Criteria__c,
                   Target_Criteria__r.Name, User__c, User__r.Name, Parent_Target__c,
                   Teams_Target__c, Teams_Achievement__c, Pending_Target__c
            FROM Target_Actual__c
            WHERE Target_Criteria__r.Active__c = true
            AND (Target_Period__c = :selectedPeriod OR Parent_Target__r.Target_Period__c = :selectedPeriod)
            AND User__c IN :userIds
            ORDER BY Target_Criteria__r.Name
        ];

        return items;
    }
}
