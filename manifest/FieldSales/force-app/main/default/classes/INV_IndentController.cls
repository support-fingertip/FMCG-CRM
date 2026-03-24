/**
 * @description LWC Controller for Indent (Purchase Requisition) operations.
 *              Provides create, list, detail, status management, and product search
 *              functionality for distributor/warehouse purchase indents.
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class INV_IndentController {

    // Valid status transitions: Draft→Submitted→Approved→Processing→Dispatched→Received
    // Cancellation allowed from Draft, Submitted, or Approved.
    private static final Map<String, Set<String>> VALID_TRANSITIONS = new Map<String, Set<String>>{
        'Draft'      => new Set<String>{ 'Submitted', 'Cancelled' },
        'Submitted'  => new Set<String>{ 'Approved', 'Cancelled' },
        'Approved'   => new Set<String>{ 'Processing', 'Cancelled' },
        'Processing' => new Set<String>{ 'Dispatched' },
        'Dispatched' => new Set<String>{ 'Received' }
    };

    /**
     * @description Lists indents with optional status and date range filters.
     * @param status  Optional status filter ('all' or blank returns all).
     * @param dateRange Optional date range: 'today', 'thisWeek', 'thisMonth', 'last30', 'last90'.
     * @return List of Indent__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Indent__c> getIndents(String status, String dateRange) {
        String query = 'SELECT Id, Name, Account__c, Account__r.Name, ' +
                       'Territory__c, Territory__r.Name, ' +
                       'Indent_Date__c, Requested_Delivery_Date__c, Status__c, ' +
                       'Approved_By__c, Approved_By__r.Name, ' +
                       'Total_Amount__c, Notes__c, CreatedDate ' +
                       'FROM Indent__c';

        List<String> conditions = new List<String>();

        if (String.isNotBlank(status) && status != 'all') {
            conditions.add('Status__c = :status');
        }

        if (String.isNotBlank(dateRange)) {
            Date filterDate = getFilterDate(dateRange);
            if (filterDate != null) {
                conditions.add('Indent_Date__c >= :filterDate');
            }
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        query += ' ORDER BY CreatedDate DESC LIMIT 100';
        return Database.query(query);
    }

    /**
     * @description Gets a single indent with its line items.
     * @param indentId The Indent__c record ID.
     * @return IndentDetail wrapper with header and line items.
     */
    @AuraEnabled
    public static IndentDetail getIndentById(Id indentId) {
        if (indentId == null) {
            throw new AuraHandledException('Indent ID is required.');
        }

        IndentDetail detail = new IndentDetail();

        List<Indent__c> indents = [
            SELECT Id, Name, Account__c, Account__r.Name,
                   Territory__c, Territory__r.Name,
                   Indent_Date__c, Requested_Delivery_Date__c, Status__c,
                   Approved_By__c, Approved_By__r.Name,
                   Total_Amount__c, Notes__c, CreatedDate,
                   CreatedById, CreatedBy.Name
            FROM Indent__c
            WHERE Id = :indentId
            LIMIT 1
        ];

        if (indents.isEmpty()) {
            throw new AuraHandledException('Indent not found.');
        }

        detail.indent = indents[0];

        detail.lineItems = [
            SELECT Id, Name, Product_Ext__c, Product_Ext__r.Name, Product_Ext__r.SKU_Code__c,
                   Requested_Qty__c, Approved_Qty__c, Unit_Price__c, Line_Total__c,
                   Current_Stock__c, Reorder_Level__c
            FROM Indent_Line__c
            WHERE Indent__c = :indentId
            ORDER BY Name ASC
        ];

        return detail;
    }

    /**
     * @description Creates a new indent with line items from JSON input.
     * @param indentJson JSON string containing indent header and lineItems array.
     * @return The created Indent__c ID.
     */
    @AuraEnabled
    public static Id createIndent(String indentJson) {
        Savepoint sp = Database.setSavepoint();
        try {
            IndentInput input = (IndentInput) JSON.deserialize(indentJson, IndentInput.class);

            if (input.lineItems == null || input.lineItems.isEmpty()) {
                throw new AuraHandledException('At least one line item is required.');
            }

            Indent__c indent = new Indent__c(
                Account__c = input.accountId,
                Territory__c = input.territoryId,
                Indent_Date__c = input.indentDate != null ? input.indentDate : Date.today(),
                Requested_Delivery_Date__c = input.requestedDeliveryDate,
                Status__c = 'Draft',
                Notes__c = input.notes
            );
            insert indent;

            List<Indent_Line__c> lines = new List<Indent_Line__c>();
            Decimal totalAmount = 0;

            for (IndentLineInput lineInput : input.lineItems) {
                if (lineInput.productId == null || lineInput.requestedQty == null || lineInput.requestedQty <= 0) {
                    continue;
                }

                Decimal unitPrice = lineInput.unitPrice != null ? lineInput.unitPrice : 0;
                Decimal lineTotal = lineInput.requestedQty * unitPrice;
                totalAmount += lineTotal;

                lines.add(new Indent_Line__c(
                    Indent__c = indent.Id,
                    Product_Ext__c = lineInput.productId,
                    Requested_Qty__c = lineInput.requestedQty,
                    Unit_Price__c = unitPrice,
                    Line_Total__c = lineTotal,
                    Current_Stock__c = lineInput.currentStock,
                    Reorder_Level__c = lineInput.reorderLevel
                ));
            }

            if (lines.isEmpty()) {
                Database.rollback(sp);
                throw new AuraHandledException('No valid line items provided.');
            }

            insert lines;

            indent.Total_Amount__c = totalAmount;
            update indent;

            return indent.Id;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Error creating indent: ' + e.getMessage());
        }
    }

    /**
     * @description Updates the status of an indent following valid transitions.
     * @param indentId  The Indent__c record ID.
     * @param newStatus The target status value.
     */
    @AuraEnabled
    public static void updateIndentStatus(Id indentId, String newStatus) {
        if (indentId == null || String.isBlank(newStatus)) {
            throw new AuraHandledException('Indent ID and new status are required.');
        }

        Indent__c indent = [
            SELECT Id, Status__c FROM Indent__c WHERE Id = :indentId LIMIT 1
        ];

        String currentStatus = indent.Status__c;

        if (!VALID_TRANSITIONS.containsKey(currentStatus) ||
            !VALID_TRANSITIONS.get(currentStatus).contains(newStatus)) {
            throw new AuraHandledException(
                'Invalid status transition from ' + currentStatus + ' to ' + newStatus + '.'
            );
        }

        indent.Status__c = newStatus;

        if (newStatus == 'Approved') {
            indent.Approved_By__c = UserInfo.getUserId();
        }

        update indent;
    }

    /**
     * @description Gets line items for a given indent.
     * @param indentId The Indent__c record ID.
     * @return List of Indent_Line__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Indent_Line__c> getIndentLineItems(Id indentId) {
        if (indentId == null) {
            throw new AuraHandledException('Indent ID is required.');
        }

        return [
            SELECT Id, Name, Product_Ext__c, Product_Ext__r.Name, Product_Ext__r.SKU_Code__c,
                   Requested_Qty__c, Approved_Qty__c, Unit_Price__c, Line_Total__c,
                   Current_Stock__c, Reorder_Level__c
            FROM Indent_Line__c
            WHERE Indent__c = :indentId
            ORDER BY Name ASC
        ];
    }

    /**
     * @description Searches active products by name or SKU code for indent line selection.
     * @param searchTerm The search keyword.
     * @return List of matching Product_Extension__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Product_Extension__c> searchProducts(String searchTerm) {
        String query = 'SELECT Id, Name, SKU_Code__c ' +
                       'FROM Product_Extension__c ' +
                       'WHERE Is_Active__c = true';

        if (String.isNotBlank(searchTerm)) {
            String searchWild = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            query += ' AND (Name LIKE :searchWild OR SKU_Code__c LIKE :searchWild)';
        }

        query += ' ORDER BY Name ASC LIMIT 50';
        return Database.query(query);
    }

    // ── Private Helpers ──────────────────────────────────────────────────────

    private static Date getFilterDate(String dateRange) {
        switch on dateRange {
            when 'today' {
                return Date.today();
            }
            when 'thisWeek' {
                return Date.today().toStartOfWeek();
            }
            when 'thisMonth' {
                return Date.today().toStartOfMonth();
            }
            when 'last30' {
                return Date.today().addDays(-30);
            }
            when 'last90' {
                return Date.today().addDays(-90);
            }
            when else {
                return null;
            }
        }
    }

    // ── Inner Classes ────────────────────────────────────────────────────────

    public class IndentInput {
        public Id accountId;
        public Id territoryId;
        public Date indentDate;
        public Date requestedDeliveryDate;
        public String notes;
        public List<IndentLineInput> lineItems;
    }

    public class IndentLineInput {
        public Id productId;
        public Decimal requestedQty;
        public Decimal unitPrice;
        public Decimal currentStock;
        public Decimal reorderLevel;
    }

    public class IndentDetail {
        @AuraEnabled public Indent__c indent;
        @AuraEnabled public List<Indent_Line__c> lineItems;
    }
}