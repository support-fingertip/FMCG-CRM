/**
 * @description Trigger handler for Sales_Order__c. Manages the complete sales order
 *              lifecycle including default population, credit validation, duplicate
 *              detection, status transition enforcement, and downstream actions
 *              (invoice creation, credit release).
 *
 * Status Flow:
 *   Draft -> Submitted -> Approved -> Processing -> Dispatched -> Delivered
 *                      -> Rejected
 *   (Any non-terminal) -> Cancelled
 *
 * @author  SFA Development Team
 * @date    2024
 */
public class OMS_SalesOrder_TriggerHandler extends TriggerHandler {

    /** Valid status transitions. Key = current status, Value = set of allowed next statuses. */
    private static final Map<String, Set<String>> VALID_TRANSITIONS = new Map<String, Set<String>>{
        'Draft'      => new Set<String>{ 'Submitted', 'Cancelled' },
        'Submitted'  => new Set<String>{ 'Approved', 'Rejected', 'Cancelled' },
        'Approved'   => new Set<String>{ 'Processing', 'Cancelled' },
        'Processing' => new Set<String>{ 'Dispatched', 'Cancelled' },
        'Dispatched' => new Set<String>{ 'Delivered', 'Cancelled' },
        'Rejected'   => new Set<String>{ 'Draft' },
        'Delivered'  => new Set<String>(),
        'Cancelled'  => new Set<String>()
    };

    // ── Before Insert ─────────────────────────────────────────────────────────

    /**
     * @description Sets default field values, validates credit limits, and
     *              checks for duplicate orders on new sales orders.
     */
    protected override void beforeInsert() {
        List<Sales_Order__c> newRecords = (List<Sales_Order__c>) Trigger.new;
        setDefaults(newRecords);
        OMS_OrderValidation_Service.validateCreditLimit(newRecords);
        OMS_OrderValidation_Service.validateMinOrderValue(newRecords);
        OMS_OrderValidation_Service.checkDuplicateOrders(newRecords);
    }

    // ── Before Update ─────────────────────────────────────────────────────────

    /**
     * @description Validates status transitions follow the defined state machine.
     *              Re-validates credit on value increases.
     */
    protected override void beforeUpdate() {
        List<Sales_Order__c> newRecords = (List<Sales_Order__c>) Trigger.new;
        Map<Id, Sales_Order__c> oldMap = (Map<Id, Sales_Order__c>) Trigger.oldMap;
        validateStatusTransitions(newRecords, oldMap);

        // Re-validate credit limit if order value increased
        List<Sales_Order__c> valueIncreased = new List<Sales_Order__c>();
        for (Sales_Order__c rec : newRecords) {
            Sales_Order__c oldRec = oldMap.get(rec.Id);
            if (rec.Total_Amount__c != null && oldRec.Total_Amount__c != null &&
                rec.Total_Amount__c > oldRec.Total_Amount__c &&
                rec.Order_Status__c != 'Cancelled' &&
                rec.Order_Status__c != 'Rejected') {
                valueIncreased.add(rec);
            }
        }
        if (!valueIncreased.isEmpty()) {
            OMS_OrderValidation_Service.validateCreditLimit(valueIncreased);
        }
    }

    // ── After Update ──────────────────────────────────────────────────────────

    /**
     * @description Triggers downstream processes on status changes:
     *              - Approved: Generate invoices
     *              - Cancelled: Release held credit
     */
    protected override void afterUpdate() {
        List<Sales_Order__c> newRecords = (List<Sales_Order__c>) Trigger.new;
        Map<Id, Sales_Order__c> oldMap = (Map<Id, Sales_Order__c>) Trigger.oldMap;

        Set<Id> approvedOrderIds = new Set<Id>();
        Set<Id> cancelledOrderIds = new Set<Id>();

        for (Sales_Order__c rec : newRecords) {
            Sales_Order__c oldRec = oldMap.get(rec.Id);

            if (rec.Order_Status__c != oldRec.Order_Status__c) {
                if (rec.Order_Status__c == 'Approved') {
                    approvedOrderIds.add(rec.Id);
                } else if (rec.Order_Status__c == 'Cancelled') {
                    cancelledOrderIds.add(rec.Id);
                }
            }
        }

        if (!approvedOrderIds.isEmpty()) {
            OMS_InvoiceGeneration_Service.generateInvoices(approvedOrderIds);
        }

        if (!cancelledOrderIds.isEmpty()) {
            releaseCreditHold(cancelledOrderIds);
        }
    }

    // ── Private helper methods ────────────────────────────────────────────────

    /**
     * @description Populates default values on new sales order records.
     * @param records The new records to initialise.
     */
    private void setDefaults(List<Sales_Order__c> records) {
        for (Sales_Order__c rec : records) {
            // Default status
            if (String.isBlank(rec.Order_Status__c)) {
                rec.Order_Status__c = 'Draft';
            }

            // Default order date
            if (rec.Order_Date__c == null) {
                rec.Order_Date__c = Date.today();
            }

            // Default sales rep to current user
            if (rec.Sales_Rep__c == null) {
                rec.Sales_Rep__c = UserInfo.getUserId();
            }

            // Initialise amounts
            if (rec.Total_Amount__c == null) {
                rec.Total_Amount__c = 0;
            }
            if (rec.Total_Tax__c == null) {
                rec.Total_Tax__c = 0;
            }
            if (rec.Discount_Amount__c == null) {
                rec.Discount_Amount__c = 0;
            }
        }
    }

    /**
     * @description Enforces the sales order status state machine. Only transitions
     *              defined in VALID_TRANSITIONS are permitted.
     * @param newRecords The updated records.
     * @param oldMap     Map of previous record values.
     */
    private void validateStatusTransitions(
        List<Sales_Order__c> newRecords,
        Map<Id, Sales_Order__c> oldMap
    ) {
        for (Sales_Order__c rec : newRecords) {
            Sales_Order__c oldRec = oldMap.get(rec.Id);

            if (rec.Order_Status__c == oldRec.Order_Status__c) {
                continue;
            }

            String currentStatus = oldRec.Order_Status__c;
            String newStatus = rec.Order_Status__c;

            if (!VALID_TRANSITIONS.containsKey(currentStatus)) {
                rec.Order_Status__c.addError(
                    'Unknown current status: ' + currentStatus + '. Cannot determine valid transitions.'
                );
                continue;
            }

            Set<String> allowedNext = VALID_TRANSITIONS.get(currentStatus);
            if (!allowedNext.contains(newStatus)) {
                rec.Order_Status__c.addError(
                    'Invalid status transition from \'' + currentStatus +
                    '\' to \'' + newStatus + '\'. Allowed transitions: ' +
                    String.join(new List<String>(allowedNext), ', ') + '.'
                );
            }
        }
    }

    /**
     * @description Releases credit hold for cancelled orders by updating the
     *              Account's credit utilisation.
     * @param cancelledOrderIds Set of cancelled Sales_Order__c IDs.
     */
    private void releaseCreditHold(Set<Id> cancelledOrderIds) {
        List<Sales_Order__c> cancelledOrders = [
            SELECT Id, Account__c, Total_Amount__c
            FROM Sales_Order__c
            WHERE Id IN :cancelledOrderIds
              AND Account__c != null
              AND Total_Amount__c != null
        ];

        // Aggregate released amounts per account
        Map<Id, Decimal> releaseByAccount = new Map<Id, Decimal>();
        for (Sales_Order__c order : cancelledOrders) {
            Decimal current = releaseByAccount.containsKey(order.Account__c)
                ? releaseByAccount.get(order.Account__c) : 0;
            releaseByAccount.put(order.Account__c, current + order.Total_Amount__c);
        }

        if (releaseByAccount.isEmpty()) {
            return;
        }

        // Update account credit utilisation
        List<Account> accountsToUpdate = [
            SELECT Id, Credit_Utilized__c
            FROM Account
            WHERE Id IN :releaseByAccount.keySet()
        ];

        for (Account acct : accountsToUpdate) {
            Decimal releaseAmount = releaseByAccount.get(acct.Id);
            Decimal currentUtilised = acct.Credit_Utilized__c != null
                ? acct.Credit_Utilized__c : 0;
            acct.Credit_Utilized__c = Math.max(0, currentUtilised - releaseAmount);
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }
}