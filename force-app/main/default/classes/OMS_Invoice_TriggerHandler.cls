/**
 * @description Trigger handler for Invoice__c. Manages invoice lifecycle events
 *              including status updates, payment tracking, and account credit
 *              utilisation adjustments.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public class OMS_Invoice_TriggerHandler extends TriggerHandler {

    // ── Before Insert ─────────────────────────────────────────────────────────

    /**
     * @description Sets default values on new invoices.
     */
    protected override void beforeInsert() {
        List<Invoice__c> newRecords = (List<Invoice__c>) Trigger.new;
        for (Invoice__c inv : newRecords) {
            if (String.isBlank(inv.Status__c)) {
                inv.Status__c = 'Draft';
            }
            if (inv.Invoice_Date__c == null) {
                inv.Invoice_Date__c = Date.today();
            }
            if (inv.Balance_Due__c == null) {
                inv.Balance_Due__c = inv.Total_Amount__c;
            }
        }
    }

    // ── After Update ──────────────────────────────────────────────────────────

    /**
     * @description Handles invoice status changes. When confirmed, updates
     *              account credit utilisation.
     */
    protected override void afterUpdate() {
        List<Invoice__c> newRecords = (List<Invoice__c>) Trigger.new;
        Map<Id, Invoice__c> oldMap = (Map<Id, Invoice__c>) Trigger.oldMap;

        Map<Id, Decimal> creditByAccount = new Map<Id, Decimal>();

        for (Invoice__c inv : newRecords) {
            Invoice__c oldInv = oldMap.get(inv.Id);

            // When invoice is confirmed/finalized, add to credit utilization
            if (inv.Status__c == 'Confirmed' && oldInv.Status__c != 'Confirmed' &&
                inv.Account__c != null && inv.Total_Amount__c != null) {
                Decimal current = creditByAccount.containsKey(inv.Account__c)
                    ? creditByAccount.get(inv.Account__c) : 0;
                creditByAccount.put(inv.Account__c, current + inv.Total_Amount__c);
            }

            // When invoice is cancelled, release credit
            if (inv.Status__c == 'Cancelled' && oldInv.Status__c != 'Cancelled' &&
                inv.Account__c != null && inv.Total_Amount__c != null) {
                Decimal current = creditByAccount.containsKey(inv.Account__c)
                    ? creditByAccount.get(inv.Account__c) : 0;
                creditByAccount.put(inv.Account__c, current - inv.Total_Amount__c);
            }
        }

        if (!creditByAccount.isEmpty()) {
            updateAccountCredit(creditByAccount);
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * @description Updates account credit utilisation based on invoice changes.
     * @param creditByAccount Map of Account ID to credit adjustment amount.
     */
    private void updateAccountCredit(Map<Id, Decimal> creditByAccount) {
        List<Account> accounts = [
            SELECT Id, Credit_Utilized__c
            FROM Account
            WHERE Id IN :creditByAccount.keySet()
        ];

        for (Account acct : accounts) {
            Decimal adjustment = creditByAccount.get(acct.Id);
            Decimal currentUtilised = acct.Credit_Utilized__c != null
                ? acct.Credit_Utilized__c : 0;
            acct.Credit_Utilized__c = Math.max(0, currentUtilised + adjustment);
        }

        if (!accounts.isEmpty()) {
            update accounts;
        }
    }
}
