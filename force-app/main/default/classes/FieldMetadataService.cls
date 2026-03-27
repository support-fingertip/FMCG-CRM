public with sharing class FieldMetadataService {

    @AuraEnabled(cacheable=true)
    public static List<FieldInfo> getFields(String objectName) {

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(objectName)) return new List<FieldInfo>();

        Schema.DescribeSObjectResult objDesc = gd.get(objectName).getDescribe();
        Map<String, Schema.SObjectField> fields = objDesc.fields.getMap();

        List<FieldInfo> results = new List<FieldInfo>();

        for (String name : fields.keySet()) {
            Schema.DescribeFieldResult fd = fields.get(name).getDescribe();

            FieldInfo info = new FieldInfo();
            info.apiName = fd.getName();
            info.label = fd.getLabel();
            info.type = getFieldType(fd);

            // Picklist
            if (fd.getType() == Schema.DisplayType.Picklist || 
                fd.getType() == Schema.DisplayType.MultiPicklist) 
            {
                info.picklistValues = new List<String>();
                for (Schema.PicklistEntry p : fd.getPicklistValues()) {
                    info.picklistValues.add(p.getValue());
                }
            }

            // ONLY TRUE USER LOOKUPS
            if (fd.getType() == Schema.DisplayType.Reference) {
                List<Schema.SObjectType> refTo = fd.getReferenceTo();
                for (Schema.SObjectType r : refTo) {
                    if (r != null && r.getDescribe().getName().equalsIgnoreCase('User')) {
                        info.isUserField = true;
                    }
                }
            }

            results.add(info);
        }

        results.sort();
        return results;
    }

    private static String getFieldType(Schema.DescribeFieldResult fd) {
        Schema.DisplayType t = fd.getType();

        if (t == Schema.DisplayType.String || t == Schema.DisplayType.TextArea) return 'String';
        if (t == Schema.DisplayType.Integer || t == Schema.DisplayType.Long || 
            t == Schema.DisplayType.Double || t == Schema.DisplayType.Percent) return 'Number';
        if (t == Schema.DisplayType.Currency) return 'Currency';
        if (t == Schema.DisplayType.Date) return 'Date';
        if (t == Schema.DisplayType.DateTime) return 'DateTime';
        if (t == Schema.DisplayType.Boolean) return 'Boolean';
        if (t == Schema.DisplayType.Picklist) return 'Picklist';
        if (t == Schema.DisplayType.MultiPicklist) return 'MultiPicklist';
        if (t == Schema.DisplayType.Reference) return 'Reference';

        return 'String'; // fallback
    }

    public class FieldInfo implements Comparable {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean isUserField;
        @AuraEnabled public List<String> picklistValues;

        public Integer compareTo(Object o) {
            FieldInfo other = (FieldInfo)o;
            return String.valueOf(label).toLowerCase().compareTo(
                   String.valueOf(other.label).toLowerCase());
        }
    }
}