/**
 * @description Trigger handler for Return_Order__c. Validates return quantities
 *              against original invoiced quantities and generates credit notes
 *              (Ledger_Entry__c) upon approval.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public class OMS_ReturnOrder_TriggerHandler extends TriggerHandler {

    // ── Before Insert ─────────────────────────────────────────────────────────

    /**
     * @description Validates that the return quantity does not exceed the
     *              original invoiced quantity for each referenced invoice line.
     */
    protected override void beforeInsert() {
        List<Return_Order__c> newRecords = (List<Return_Order__c>) Trigger.new;
        validateReturnQuantity(newRecords);
    }

    // ── Before Update ─────────────────────────────────────────────────────────

    /**
     * @description Re-validates return quantity when quantities or invoice
     *              references change.
     */
    protected override void beforeUpdate() {
        List<Return_Order__c> newRecords = (List<Return_Order__c>) Trigger.new;
        Map<Id, Return_Order__c> oldMap = (Map<Id, Return_Order__c>) Trigger.oldMap;

        List<Return_Order__c> changed = new List<Return_Order__c>();
        for (Return_Order__c rec : newRecords) {
            Return_Order__c oldRec = oldMap.get(rec.Id);
            if (rec.Return_Quantity__c != oldRec.Return_Quantity__c ||
                rec.Invoice__c != oldRec.Invoice__c ||
                rec.Invoice_Line__c != oldRec.Invoice_Line__c) {
                changed.add(rec);
            }
        }

        if (!changed.isEmpty()) {
            validateReturnQuantity(changed);
        }
    }

    // ── After Update ──────────────────────────────────────────────────────────

    /**
     * @description When a return order is approved, generates a credit note
     *              ledger entry and updates the related invoice balance.
     */
    protected override void afterUpdate() {
        List<Return_Order__c> newRecords = (List<Return_Order__c>) Trigger.new;
        Map<Id, Return_Order__c> oldMap = (Map<Id, Return_Order__c>) Trigger.oldMap;

        List<Return_Order__c> approved = new List<Return_Order__c>();
        for (Return_Order__c rec : newRecords) {
            Return_Order__c oldRec = oldMap.get(rec.Id);
            if (rec.Status__c == 'Approved' && oldRec.Status__c != 'Approved') {
                approved.add(rec);
            }
        }

        if (!approved.isEmpty()) {
            generateCreditNotes(approved);
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * @description Validates that the return quantity does not exceed the
     *              available (invoiced minus already-returned) quantity.
     * @param records The Return_Order__c records to validate.
     */
    private void validateReturnQuantity(List<Return_Order__c> records) {
        // Collect invoice line IDs
        Set<Id> invoiceLineIds = new Set<Id>();
        Set<Id> invoiceIds = new Set<Id>();
        for (Return_Order__c rec : records) {
            if (rec.Invoice_Line__c != null) {
                invoiceLineIds.add(rec.Invoice_Line__c);
            }
            if (rec.Invoice__c != null) {
                invoiceIds.add(rec.Invoice__c);
            }
        }

        // Get invoiced quantities from invoice lines
        Map<Id, Invoice_Line__c> invoiceLineMap = new Map<Id, Invoice_Line__c>();
        if (!invoiceLineIds.isEmpty()) {
            invoiceLineMap = new Map<Id, Invoice_Line__c>([
                SELECT Id, Quantity__c, Product__c
                FROM Invoice_Line__c
                WHERE Id IN :invoiceLineIds
            ]);
        }

        // Get already-returned quantities (excluding current records on update)
        Map<Id, Decimal> alreadyReturnedByLine = new Map<Id, Decimal>();
        Set<Id> currentRecordIds = new Set<Id>();
        for (Return_Order__c rec : records) {
            if (rec.Id != null) {
                currentRecordIds.add(rec.Id);
            }
        }

        if (!invoiceLineIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Invoice_Line__c lineId, SUM(Return_Quantity__c) totalReturned
                FROM Return_Order__c
                WHERE Invoice_Line__c IN :invoiceLineIds
                  AND Status__c NOT IN ('Rejected', 'Cancelled')
                  AND Id NOT IN :currentRecordIds
                GROUP BY Invoice_Line__c
            ]) {
                Id lineId = (Id) ar.get('lineId');
                Decimal totalReturned = (Decimal) ar.get('totalReturned');
                alreadyReturnedByLine.put(lineId, totalReturned != null ? totalReturned : 0);
            }
        }

        // Validate each return order
        for (Return_Order__c rec : records) {
            if (rec.Return_Quantity__c == null || rec.Return_Quantity__c <= 0) {
                rec.Return_Quantity__c.addError('Return quantity must be greater than zero.');
                continue;
            }

            if (rec.Invoice_Line__c == null) {
                continue;
            }

            Invoice_Line__c invoiceLine = invoiceLineMap.get(rec.Invoice_Line__c);
            if (invoiceLine == null) {
                rec.Invoice_Line__c.addError('Referenced invoice line not found.');
                continue;
            }

            Decimal invoicedQty = invoiceLine.Quantity__c != null ? invoiceLine.Quantity__c : 0;
            Decimal alreadyReturned = alreadyReturnedByLine.containsKey(rec.Invoice_Line__c)
                ? alreadyReturnedByLine.get(rec.Invoice_Line__c) : 0;
            Decimal availableForReturn = invoicedQty - alreadyReturned;

            if (rec.Return_Quantity__c > availableForReturn) {
                rec.Return_Quantity__c.addError(
                    'Return quantity (' + rec.Return_Quantity__c +
                    ') exceeds available returnable quantity (' +
                    availableForReturn + '). Invoiced: ' + invoicedQty +
                    ', Already returned: ' + alreadyReturned + '.'
                );
            }
        }
    }

    /**
     * @description Generates credit note ledger entries for approved return orders
     *              and updates the related invoice balance.
     * @param approvedReturns The approved Return_Order__c records.
     */
    private void generateCreditNotes(List<Return_Order__c> approvedReturns) {
        List<Ledger_Entry__c> ledgerEntries = new List<Ledger_Entry__c>();
        Map<Id, Decimal> creditByInvoice = new Map<Id, Decimal>();

        for (Return_Order__c ret : approvedReturns) {
            Decimal creditAmount = ret.Return_Amount__c != null ? ret.Return_Amount__c : 0;

            // Create credit note ledger entry
            ledgerEntries.add(new Ledger_Entry__c(
                Account__c          = ret.Account__c,
                Entry_Type__c       = 'Credit Note',
                Amount__c           = creditAmount,
                Reference_Type__c   = 'Return Order',
                Reference_Id__c     = ret.Id,
                Invoice__c          = ret.Invoice__c,
                Entry_Date__c       = Date.today(),
                Description__c      = 'Credit note for return order: ' + ret.Name,
                Status__c           = 'Posted'
            ));

            // Track credit amounts by invoice for balance update
            if (ret.Invoice__c != null) {
                Decimal current = creditByInvoice.containsKey(ret.Invoice__c)
                    ? creditByInvoice.get(ret.Invoice__c) : 0;
                creditByInvoice.put(ret.Invoice__c, current + creditAmount);
            }
        }

        if (!ledgerEntries.isEmpty()) {
            insert ledgerEntries;
        }

        // Update invoice balances
        if (!creditByInvoice.isEmpty()) {
            List<Invoice__c> invoicesToUpdate = [
                SELECT Id, Balance_Due__c
                FROM Invoice__c
                WHERE Id IN :creditByInvoice.keySet()
            ];

            for (Invoice__c inv : invoicesToUpdate) {
                Decimal credit = creditByInvoice.get(inv.Id);
                Decimal currentBalance = inv.Balance_Due__c != null ? inv.Balance_Due__c : 0;
                inv.Balance_Due__c = Math.max(0, currentBalance - credit);
            }

            if (!invoicesToUpdate.isEmpty()) {
                update invoicesToUpdate;
            }
        }
    }
}