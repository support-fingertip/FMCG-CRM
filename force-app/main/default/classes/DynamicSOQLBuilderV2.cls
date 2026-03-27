public class DynamicSOQLBuilderV2 {

    public class Context {
        public String objectName;
        public String userField;
        public String aggField;
        public String aggFunction; // SUM or COUNT
        public String dateField;

        public Date startDate;
        public Date endDate;

        public String filtersJson;
        public String logic;

        public Set<Id> userIds;
    }

    public static String buildSOQL(Context ctx) {

        // 1) WHERE from JSON
       

        List<String> whereSegments = new List<String>();

        whereSegments.add(ctx.dateField + ' >= :startDate');
        whereSegments.add(ctx.dateField + ' <= :endDate');
        
        String whereClause = String.join(whereSegments, ' AND ');
        
         String whereFilters =
            FilterJSONEngine.buildWhereClause(ctx.filtersJson, ctx.logic);
         if (!String.isBlank(whereFilters))
            whereSegments.add(whereFilters);

        whereClause +=whereFilters;


        // 2) Aggregation
        String agg =
            (ctx.aggFunction == 'COUNT')
            ? 'COUNT(Id)'
            : ctx.aggFunction + '(' + ctx.aggField + ')';


        // 3) Build full SOQL
        String soql =
            'SELECT ' + ctx.userField + ', ' + agg +
            ' FROM ' + ctx.objectName +
            ' WHERE ' + whereClause +
            ' GROUP BY ' + ctx.userField +
            ' HAVING ' + ctx.userField + ' IN :userIds';

        return soql;
    }
}