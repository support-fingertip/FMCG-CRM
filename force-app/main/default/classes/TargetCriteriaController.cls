public with sharing class TargetCriteriaController {

    // ======================
    // 1. GET ALL OBJECT NAMES
    // ======================
   @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAllObjects() {

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        List<Map<String, String>> result = new List<Map<String, String>>();

        for (String apiName : gd.keySet()) {

            // Skip irrelevant/system objects
           if (isSystemObject(apiName)) continue;

            Schema.DescribeSObjectResult d = gd.get(apiName).getDescribe();

            if (!d.isQueryable() || !d.isAccessible()) {
                continue;
            }

            if (!d.isCreateable() && !d.isUpdateable() && !d.isDeletable()) continue;

            result.add(new Map<String, String>{
                'api' => apiName, 
                'label' => d.getLabel()
            });
        }

        // SORTING SECTION (must be BEFORE the return)
        List<String> labels = new List<String>();
        Map<String, Map<String,String>> index = new Map<String, Map<String,String>>();

        for (Map<String,String> rec : result) {
            String key = rec.get('label') + '___' + rec.get('api');
            labels.add(key);
            index.put(key, rec);
        }

        labels.sort();

        List<Map<String,String>> sorted = new List<Map<String,String>>();
        for (String k : labels) {
            sorted.add(index.get(k));
        }

        // NOTHING after this line
        return sorted;
    }



    // ====================================
    // 2. GET FIELDS FOR GIVEN OBJECT
    //    - Numeric + Currency + Percent
    //    - Numeric Formula Fields
    // ====================================
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getFieldCategories(String objectName) {

        Map<String, List<String>> response = new Map<String, List<String>>();
        response.put('numberFields', new List<String>());
        response.put('dateFields', new List<String>());
        response.put('userFields', new List<String>());
        response.put('allFields', new List<String>());

        Schema.SObjectType typeObj = Schema.getGlobalDescribe().get(objectName);
        Map<String, Schema.SObjectField> fields = typeObj.getDescribe().fields.getMap();

        for (String fname : fields.keySet()) {

            Schema.DescribeFieldResult d = fields.get(fname).getDescribe();
            response.get('allFields').add(fname);

            // NUMBER / CURRENCY / PERCENT
            if (d.getType() == Schema.DisplayType.Double ||
                d.getType() == Schema.DisplayType.Currency ||
                d.getType() == Schema.DisplayType.Percent) {

                response.get('numberFields').add(fname);
            }

            // FORMULA (NUMBER) SUPPORT
            if (d.isCalculated() && d.getType() == Schema.DisplayType.Double) {
                response.get('numberFields').add(fname);
            }

            // DATE FIELDS
            if (d.getType() == Schema.DisplayType.Date || 
                d.getType() == Schema.DisplayType.DateTime) {
                response.get('dateFields').add(fname);
            }

            // USER LOOKUP FIELDS
            if (d.getType() == Schema.DisplayType.Reference &&
                d.getReferenceTo().size() > 0 &&
                d.getReferenceTo()[0] == Schema.User.getSObjectType()) {
                response.get('userFields').add(fname);
            }
        }

        return response;
    }

    // =====================
    // 3. GET EXISTING CRITERIA
    // =====================
    @AuraEnabled(cacheable=true)
    public static Target_Criteria__c getCriteria(Id criteriaId) {
        return [
            SELECT Id, Name, Object__c, Operator__c, Field__c,
                   Date_Field__c, User_Field__c,
                   Filters__c, Filter_Logic__c,
                   Enable_Customer_Targets__c
            FROM Target_Criteria__c
            WHERE Id = :criteriaId
        ];
    }

    // =====================
    // 4. SAVE CRITERIA
    // =====================
    @AuraEnabled
    public static Target_Criteria__c saveCriteria(Target_Criteria__c criteria) {

     /*   if (String.isNotBlank(filtersJson)) {
            tc.Filters__c = filtersJson;
        }*/
        upsert criteria;
        return getCriteria(criteria.Id);
    }

   static Boolean isSystemObject(String apiName) {
        return apiName.endsWith('History') ||
            apiName.endsWith('Feed') ||
            apiName.endsWith('FieldHistory') ||
            apiName.endsWith('Share') ||
            apiName.endsWith('Tag') ||
            apiName.endsWith('Vote') ||
            apiName.contains('ChangeEvent') ||
            apiName.endsWith('Event') ||
            apiName.contains('CleanInfo') ||
            apiName.contains('Duplicate') ||
            apiName.contains('Suggestion') || 
            apiName.toLowerCase().endsWith('history') ||
            apiName.toLowerCase().endsWith('feed') ||
            apiName.toLowerCase().endsWith('fieldhistory') ||
            apiName.toLowerCase().endsWith('share') ||
            apiName.toLowerCase().endsWith('tag') ||
            apiName.toLowerCase().endsWith('vote') ||
            apiName.toLowerCase().contains('changeevent') ||
            apiName.toLowerCase().endsWith('event') ||
            apiName.toLowerCase().contains('cleaninfo') ||
            apiName.toLowerCase().contains('duplicate') ||
            apiName.toLowerCase().contains('suggestion');
    }
}