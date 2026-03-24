/**
 * @description Trigger handler for Collection__c. Manages invoice balance updates
 *              and ledger entry creation when payments are collected. Handles status
 *              changes including bounced payment reversals.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public class OVE_Collection_TriggerHandler extends TriggerHandler {

    // ── After Insert ──────────────────────────────────────────────────────────

    /**
     * @description When a collection is created, updates the related Invoice's
     *              Balance_Due__c and creates a corresponding Ledger_Entry__c.
     */
    protected override void afterInsert() {
        List<Collection__c> newRecords = (List<Collection__c>) Trigger.new;
        processNewCollections(newRecords);
    }

    // ── After Update ──────────────────────────────────────────────────────────

    /**
     * @description Handles collection status changes. When a collection bounces,
     *              reverses the original ledger entry and restores the invoice
     *              balance.
     */
    protected override void afterUpdate() {
        List<Collection__c> newRecords = (List<Collection__c>) Trigger.new;
        Map<Id, Collection__c> oldMap = (Map<Id, Collection__c>) Trigger.oldMap;

        List<Collection__c> bounced = new List<Collection__c>();
        List<Collection__c> confirmed = new List<Collection__c>();

        for (Collection__c rec : newRecords) {
            Collection__c oldRec = oldMap.get(rec.Id);

            if (rec.Status__c != oldRec.Status__c) {
                if (rec.Status__c == 'Bounced') {
                    bounced.add(rec);
                } else if (rec.Status__c == 'Confirmed' && oldRec.Status__c == 'Pending') {
                    confirmed.add(rec);
                }
            }
        }

        if (!bounced.isEmpty()) {
            reverseBouncedCollections(bounced);
        }

        if (!confirmed.isEmpty()) {
            confirmCollections(confirmed);
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * @description Processes newly inserted collections: creates ledger entries
     *              and updates invoice balances.
     * @param collections The new Collection__c records.
     */
    private void processNewCollections(List<Collection__c> collections) {
        List<Ledger_Entry__c> ledgerEntries = new List<Ledger_Entry__c>();
        Map<Id, Decimal> paymentByInvoice = new Map<Id, Decimal>();

        for (Collection__c coll : collections) {
            Decimal amount = coll.Amount__c != null ? coll.Amount__c : 0;

            if (amount <= 0) {
                continue;
            }

            // Create ledger entry for the collection
            ledgerEntries.add(new Ledger_Entry__c(
                Account__c        = coll.Account__c,
                Entry_Type__c     = 'Payment',
                Amount__c         = amount,
                Reference_Type__c = 'Collection',
                Reference_Id__c   = coll.Id,
                Invoice__c        = coll.Invoice__c,
                Entry_Date__c     = coll.Collection_Date__c != null
                    ? coll.Collection_Date__c : Date.today(),
                Description__c    = 'Payment collected via ' +
                    (String.isNotBlank(coll.Payment_Mode__c) ? coll.Payment_Mode__c : 'Cash'),
                Status__c         = coll.Status__c == 'Confirmed' ? 'Posted' : 'Pending'
            ));

            // Aggregate payments by invoice
            if (coll.Invoice__c != null) {
                Decimal current = paymentByInvoice.containsKey(coll.Invoice__c)
                    ? paymentByInvoice.get(coll.Invoice__c) : 0;
                paymentByInvoice.put(coll.Invoice__c, current + amount);
            }
        }

        if (!ledgerEntries.isEmpty()) {
            insert ledgerEntries;
        }

        // Update invoice balances
        updateInvoiceBalances(paymentByInvoice, false);
    }

    /**
     * @description Reverses bounced collections by creating reversal ledger entries
     *              and restoring the invoice balance.
     * @param bouncedCollections The collections that have bounced.
     */
    private void reverseBouncedCollections(List<Collection__c> bouncedCollections) {
        List<Ledger_Entry__c> reversalEntries = new List<Ledger_Entry__c>();
        Map<Id, Decimal> restoreByInvoice = new Map<Id, Decimal>();

        for (Collection__c coll : bouncedCollections) {
            Decimal amount = coll.Amount__c != null ? coll.Amount__c : 0;

            if (amount <= 0) {
                continue;
            }

            // Create reversal ledger entry
            reversalEntries.add(new Ledger_Entry__c(
                Account__c        = coll.Account__c,
                Entry_Type__c     = 'Payment Reversal',
                Amount__c         = amount,
                Reference_Type__c = 'Collection',
                Reference_Id__c   = coll.Id,
                Invoice__c        = coll.Invoice__c,
                Entry_Date__c     = Date.today(),
                Description__c    = 'Payment reversal - bounced ' +
                    (String.isNotBlank(coll.Payment_Mode__c) ? coll.Payment_Mode__c : 'payment'),
                Status__c         = 'Posted'
            ));

            // Track amounts to restore on invoices
            if (coll.Invoice__c != null) {
                Decimal current = restoreByInvoice.containsKey(coll.Invoice__c)
                    ? restoreByInvoice.get(coll.Invoice__c) : 0;
                restoreByInvoice.put(coll.Invoice__c, current + amount);
            }
        }

        if (!reversalEntries.isEmpty()) {
            insert reversalEntries;
        }

        // Restore invoice balances (add back bounced amounts)
        updateInvoiceBalances(restoreByInvoice, true);
    }

    /**
     * @description Confirms pending collections by updating their ledger entries
     *              to Posted status.
     * @param confirmedCollections The collections that have been confirmed.
     */
    private void confirmCollections(List<Collection__c> confirmedCollections) {
        Set<Id> collectionIds = new Set<Id>();
        for (Collection__c coll : confirmedCollections) {
            collectionIds.add(coll.Id);
        }

        // Update associated pending ledger entries to Posted
        List<Ledger_Entry__c> ledgerEntries = [
            SELECT Id, Status__c
            FROM Ledger_Entry__c
            WHERE Reference_Id__c IN :collectionIds
              AND Reference_Type__c = 'Collection'
              AND Status__c = 'Pending'
        ];

        for (Ledger_Entry__c entry : ledgerEntries) {
            entry.Status__c = 'Posted';
        }

        if (!ledgerEntries.isEmpty()) {
            update ledgerEntries;
        }
    }

    /**
     * @description Updates Invoice__c.Balance_Due__c by either reducing (payment)
     *              or restoring (reversal) the balance amount.
     * @param amountByInvoice Map of Invoice ID to amount to apply.
     * @param isReversal      True if restoring balance (bounced); false if reducing (payment).
     */
    private void updateInvoiceBalances(Map<Id, Decimal> amountByInvoice, Boolean isReversal) {
        if (amountByInvoice == null || amountByInvoice.isEmpty()) {
            return;
        }

        List<Invoice__c> invoices = [
            SELECT Id, Balance_Due__c, Total_Amount__c
            FROM Invoice__c
            WHERE Id IN :amountByInvoice.keySet()
        ];

        for (Invoice__c inv : invoices) {
            Decimal currentBalance = inv.Balance_Due__c != null ? inv.Balance_Due__c : 0;
            Decimal amount = amountByInvoice.get(inv.Id);
            Decimal totalAmount = inv.Total_Amount__c != null ? inv.Total_Amount__c : 0;

            if (isReversal) {
                // Restore balance (bounced payment)
                inv.Balance_Due__c = Math.min(totalAmount, currentBalance + amount);
            } else {
                // Reduce balance (payment received)
                inv.Balance_Due__c = Math.max(0, currentBalance - amount);
            }
        }

        if (!invoices.isEmpty()) {
            update invoices;
        }
    }
}