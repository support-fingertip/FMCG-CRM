public class TAM_FilterEngine_Service {

    public class FilterRow {
        public Integer id;
        public String field;
        public String operator;
        public Object value;
        public String type;
    }

    public class FilterDefinition {
        public List<FilterRow> filters;
    }

    // Main entry
    public static String buildWhereClause(String jsonFilters, String logicString) {

        FilterDefinition def = parseFilters(jsonFilters);
        if (def.filters == null || def.filters.isEmpty()) return '';

        Map<Integer, String> idToCondition = new Map<Integer, String>();

        for (FilterRow row : def.filters) {
            idToCondition.put(row.id, buildCondition(row));
        }

        // If no logic, join using AND
        if (String.isBlank(logicString)) {
            return ' AND (' + String.join(idToCondition.values(), ' AND ') + ')';
        }

        // Replace IDs in logic string
        String resolvedLogic = logicString;
        for (Integer id : idToCondition.keySet()) {
            resolvedLogic = resolvedLogic.replace(String.valueOf(id), idToCondition.get(id));
        }

        return ' AND (' + resolvedLogic + ')';
    }

    // UNTYPED JSON PARSER (supports any data types)
    public static FilterDefinition parseFilters(String jsonFilters) {
        FilterDefinition def = new FilterDefinition();
        def.filters = new List<FilterRow>();

        if (String.isBlank(jsonFilters)) return def;

        Map<String, Object> root =
            (Map<String, Object>) JSON.deserializeUntyped(jsonFilters);

        List<Object> rows = (List<Object>) root.get('filters');
        if (rows == null) return def;

        for (Object r : rows) {
            Map<String, Object> row = (Map<String, Object>) r;

            FilterRow f = new FilterRow();
            f.id = Integer.valueOf(row.get('id'));
            f.field = (String) row.get('field');
            f.operator = (String) row.get('operator');
            f.type = (String) row.get('type');
            f.value = row.get('value'); // keep dynamic

            def.filters.add(f);
        }

        return def;
    }

    // MASTER CONDITION BUILDER
    private static String buildCondition(FilterRow f) {

        // Handle NULL conditions
        if (f.type == 'Null') {
            if (f.operator == 'IS NULL') {
                return '(' + f.field + ' = NULL)';
            }
            if (f.operator == 'IS NOT NULL') {
                return '(' + f.field + ' != NULL)';
            }
        }

        // Dispatch by type
        if (f.type == 'String') {
            return '(' + f.field + ' ' + f.operator + ' \'' +
                String.escapeSingleQuotes((String) f.value) + '\')';
        }

        if (f.type == 'LikeString') {
            return '(' + f.field + ' ' + f.operator + ' \'%' +
                String.escapeSingleQuotes((String) f.value) + '%\')';
        }

        if (f.type == 'Number' || f.type == 'Currency') {
            return '(' + f.field + ' ' + f.operator + ' ' +
                String.valueOf(f.value) + ')';
        }

        if (f.type == 'Boolean') {
            return '(' + f.field + ' ' + f.operator + ' ' +
                ((Boolean) f.value ? 'TRUE' : 'FALSE') + ')';
        }

        if (f.type == 'Date') {
            Date d = Date.valueOf((String) f.value);
            return '(' + f.field + ' ' + f.operator + ' ' + d.format() + ')';
        }

        if (f.type == 'DateTime') {
            Datetime dt = Datetime.valueOf((String) f.value);
            return '(' + f.field + ' ' + f.operator + ' ' + dt.format() + ')';
        }

        if (f.type == 'Picklist' && f.operator != 'IN' && f.operator != 'NOT IN') {
            return '(' + f.field + ' ' + f.operator + ' \'' +
                String.escapeSingleQuotes((String) f.value) + '\')';
        }

        if (f.type == 'Picklist' && (f.operator == 'IN' || f.operator == 'NOT IN')) {
            List<Object> vals = (List<Object>) f.value;
            List<String> quoted = new List<String>();

            for (Object v : vals) {
                quoted.add('\'' + String.escapeSingleQuotes((String) v) + '\'');
            }

            return '(' + f.field + ' ' + f.operator + ' (' +
                String.join(quoted, ',') + '))';
        }

        if (f.type == 'PicklistMulti') {
            List<Object> vals = (List<Object>) f.value;
            List<String> quoted = new List<String>();

            for (Object v : vals) {
                quoted.add('\'' + String.escapeSingleQuotes((String) v) + '\'');
            }

            return '(' + f.field + ' ' + f.operator + ' (' +
                String.join(quoted, ',') + '))';
        }

        throw new AuraHandledException('Unsupported filter type: ' + f.type);
    }
}
