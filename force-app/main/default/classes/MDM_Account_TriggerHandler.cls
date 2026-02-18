/**
 * @description Trigger handler for Account object automations in FMCG SFA context.
 *              Manages default field population, beat outlet count rollups,
 *              visit frequency auto-assignment based on outlet class, and
 *              credit utilization recalculation.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class MDM_Account_TriggerHandler {

    /**
     * @description Before Insert: Set defaults for new Accounts.
     *              - Is_Active__c defaults to true
     *              - Visit_Frequency__c auto-set based on Outlet_Class__c
     */
    public void beforeInsert(List<Account> newList) {
        for (Account acc : newList) {
            if (acc.Is_Active__c == null) {
                acc.Is_Active__c = true;
            }
            if (acc.Visit_Frequency__c == null && acc.Outlet_Class__c != null) {
                acc.Visit_Frequency__c = getDefaultVisitFrequency(acc.Outlet_Class__c);
            }
            if (acc.Credit_Utilized__c == null) {
                acc.Credit_Utilized__c = 0;
            }
        }
    }

    /**
     * @description Before Update: Re-derive visit frequency if outlet class changed
     *              and frequency was not manually overridden.
     */
    public void beforeUpdate(List<Account> newList, Map<Id, Account> oldMap) {
        for (Account acc : newList) {
            Account oldAcc = oldMap.get(acc.Id);

            // Auto-update visit frequency when outlet class changes
            // (only if frequency was previously the default for old class)
            if (acc.Outlet_Class__c != oldAcc.Outlet_Class__c
                && acc.Outlet_Class__c != null
                && acc.Visit_Frequency__c == getDefaultVisitFrequency(oldAcc.Outlet_Class__c)) {
                acc.Visit_Frequency__c = getDefaultVisitFrequency(acc.Outlet_Class__c);
            }
        }
    }

    /**
     * @description After Insert: Increment Total_Outlets__c on assigned Beat records.
     */
    public void afterInsert(List<Account> newList) {
        updateBeatOutletCounts(newList, null);
    }

    /**
     * @description After Update: Update Beat outlet counts when Beat__c assignment changes.
     *              Also update Last_Order_Date__c and Last_Visit_Date__c tracking.
     */
    public void afterUpdate(List<Account> newList, Map<Id, Account> oldMap) {
        List<Account> beatChangedAccounts = new List<Account>();
        for (Account acc : newList) {
            Account oldAcc = oldMap.get(acc.Id);
            if (acc.Beat__c != oldAcc.Beat__c) {
                beatChangedAccounts.add(acc);
            }
        }
        if (!beatChangedAccounts.isEmpty()) {
            updateBeatOutletCounts(beatChangedAccounts, oldMap);
        }
    }

    /**
     * @description After Delete: Decrement Total_Outlets__c on assigned Beat records.
     */
    public void afterDelete(List<Account> oldList) {
        Set<Id> beatIds = new Set<Id>();
        for (Account acc : oldList) {
            if (acc.Beat__c != null) {
                beatIds.add(acc.Beat__c);
            }
        }
        if (!beatIds.isEmpty()) {
            recalculateBeatOutletCounts(beatIds);
        }
    }

    // ── Beat Outlet Count Management ──────────────────────────────────────────

    /**
     * @description Updates Total_Outlets__c on Beat records when accounts are
     *              inserted or their Beat assignment changes.
     * @param accounts  The account records being processed.
     * @param oldMap    The old account values (null on insert).
     */
    private void updateBeatOutletCounts(List<Account> accounts, Map<Id, Account> oldMap) {
        Set<Id> affectedBeatIds = new Set<Id>();

        for (Account acc : accounts) {
            if (acc.Beat__c != null) {
                affectedBeatIds.add(acc.Beat__c);
            }
            if (oldMap != null) {
                Account oldAcc = oldMap.get(acc.Id);
                if (oldAcc != null && oldAcc.Beat__c != null) {
                    affectedBeatIds.add(oldAcc.Beat__c);
                }
            }
        }

        if (!affectedBeatIds.isEmpty()) {
            recalculateBeatOutletCounts(affectedBeatIds);
        }
    }

    /**
     * @description Recalculates Total_Outlets__c for the given Beat records
     *              by counting active Accounts assigned to each beat.
     * @param beatIds The Beat Ids to recalculate.
     */
    private void recalculateBeatOutletCounts(Set<Id> beatIds) {
        Map<Id, Integer> beatCounts = new Map<Id, Integer>();
        for (Id beatId : beatIds) {
            beatCounts.put(beatId, 0);
        }

        for (AggregateResult ar : [
            SELECT Beat__c, COUNT(Id) cnt
            FROM Account
            WHERE Beat__c IN :beatIds
            AND Is_Active__c = true
            GROUP BY Beat__c
        ]) {
            Id beatId = (Id)ar.get('Beat__c');
            Integer count = (Integer)ar.get('cnt');
            beatCounts.put(beatId, count);
        }

        List<Beat__c> beatsToUpdate = new List<Beat__c>();
        for (Id beatId : beatCounts.keySet()) {
            beatsToUpdate.add(new Beat__c(
                Id = beatId,
                Total_Outlets__c = beatCounts.get(beatId)
            ));
        }

        if (!beatsToUpdate.isEmpty()) {
            update beatsToUpdate;
        }
    }

    // ── Credit Utilization ────────────────────────────────────────────────────

    /**
     * @description Recalculates Credit_Utilized__c for given accounts based on
     *              sum of Balance_Due__c from unpaid invoices.
     *              Called from Invoice trigger handler when invoice balances change.
     * @param accountIds The Account Ids to recalculate credit for.
     */
    public static void recalculateCreditUtilization(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> accountBalances = new Map<Id, Decimal>();
        for (Id accId : accountIds) {
            accountBalances.put(accId, 0);
        }

        for (AggregateResult ar : [
            SELECT Account__c, SUM(Balance_Due__c) totalDue
            FROM Invoice__c
            WHERE Account__c IN :accountIds
            AND Balance_Due__c > 0
            AND Status__c NOT IN ('Cancelled', 'Fully Paid')
            GROUP BY Account__c
        ]) {
            Id accId = (Id)ar.get('Account__c');
            Decimal totalDue = (Decimal)ar.get('totalDue');
            accountBalances.put(accId, totalDue != null ? totalDue : 0);
        }

        List<Account> accountsToUpdate = new List<Account>();
        for (Id accId : accountBalances.keySet()) {
            accountsToUpdate.add(new Account(
                Id = accId,
                Credit_Utilized__c = accountBalances.get(accId),
                Outstanding_Balance__c = accountBalances.get(accId)
            ));
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }

    /**
     * @description Updates Last_Order_Date__c and Last_Order_Value__c on Account
     *              when a new Sales Order is created/updated.
     *              Called from Sales Order trigger handler.
     * @param accountIds The Account Ids to update.
     */
    public static void updateLastOrderInfo(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        List<Account> accountsToUpdate = new List<Account>();
        for (Id accId : accountIds) {
            List<Sales_Order__c> latestOrders = [
                SELECT Order_Date__c, Total_Net_Amount__c
                FROM Sales_Order__c
                WHERE Account__c = :accId
                AND Status__c NOT IN ('Cancelled', 'Rejected')
                ORDER BY Order_Date__c DESC
                LIMIT 1
            ];
            if (!latestOrders.isEmpty()) {
                accountsToUpdate.add(new Account(
                    Id = accId,
                    Last_Order_Date__c = latestOrders[0].Order_Date__c,
                    Last_Order_Value__c = latestOrders[0].Total_Net_Amount__c
                ));
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }

    /**
     * @description Updates Last_Visit_Date__c on Account when a visit is completed.
     *              Called from Visit trigger handler.
     * @param accountIds The Account Ids to update.
     */
    public static void updateLastVisitDate(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        List<Account> accountsToUpdate = new List<Account>();
        for (Id accId : accountIds) {
            List<Visit__c> latestVisits = [
                SELECT Visit_Date__c
                FROM Visit__c
                WHERE Account__c = :accId
                AND Visit_Status__c = 'Completed'
                ORDER BY Visit_Date__c DESC
                LIMIT 1
            ];
            if (!latestVisits.isEmpty()) {
                accountsToUpdate.add(new Account(
                    Id = accId,
                    Last_Visit_Date__c = latestVisits[0].Visit_Date__c
                ));
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            update accountsToUpdate;
        }
    }

    // ── Utility Methods ───────────────────────────────────────────────────────

    /**
     * @description Returns the default visit frequency based on outlet class.
     *              Class A (premium) = Weekly, B = Bi-Weekly, C/D = Monthly.
     * @param outletClass The Outlet_Class__c value (A/B/C/D).
     * @return The default Visit_Frequency__c value.
     */
    @TestVisible
    private static String getDefaultVisitFrequency(String outletClass) {
        if (outletClass == null) {
            return 'Monthly';
        }
        switch on outletClass {
            when 'A' { return 'Weekly'; }
            when 'B' { return 'Bi-Weekly'; }
            when 'C', 'D' { return 'Monthly'; }
            when else { return 'Monthly'; }
        }
    }
}
