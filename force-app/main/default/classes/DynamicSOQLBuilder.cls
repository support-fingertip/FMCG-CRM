public class DynamicSOQLBuilder {

    public static String buildSOQL(Target_Criteria__c crit, Date startDate, Date endDate) {

        // SELECT
        String selectField = crit.User_Field__c;
        String aggregate;

        if (crit.Operator__c == 'COUNT') {
            aggregate = 'COUNT(Id)';
        } else {
            aggregate = 'SUM(' + crit.Field__c + ')';
        }

        String soql = 'SELECT ' + selectField + ', ' + aggregate;

        // FROM
        soql += ' FROM ' + crit.Object__c;

        // WHERE
        soql += ' WHERE ' + crit.Date_Field__c + ' >= :startDate';
        soql += ' AND ' + crit.Date_Field__c + ' <= :endDate';

        // Apply filter JSON + logic
        String jsonWhere = FilterJSONEngine.buildWhereClause(crit.Filters__c, crit.Filter_Logic__c);
        if (!String.isBlank(jsonWhere)) {
            soql += jsonWhere;
        }

        // GROUP BY
        soql += ' GROUP BY ' + crit.User_Field__c;

        return soql;
    }
}