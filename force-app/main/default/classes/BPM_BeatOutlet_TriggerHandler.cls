/**
 * @description Trigger handler for Beat_Outlet__c. Manages automatic rollup
 *              of Total_Outlets__c on the parent Beat__c record by counting
 *              active child Beat_Outlet__c records.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public class BPM_BeatOutlet_TriggerHandler extends TriggerHandler {

    // ── After Insert ────────────────────────────────────────────────────────

    protected override void afterInsert() {
        recalculateBeatOutletCounts(getAffectedBeatIds(Trigger.new, null));
    }

    // ── After Update ────────────────────────────────────────────────────────

    protected override void afterUpdate() {
        Map<Id, Beat_Outlet__c> oldMap = (Map<Id, Beat_Outlet__c>) Trigger.oldMap;
        Set<Id> affectedBeatIds = getAffectedBeatIds(Trigger.new, oldMap);
        if (!affectedBeatIds.isEmpty()) {
            recalculateBeatOutletCounts(affectedBeatIds);
        }
    }

    // ── After Delete ────────────────────────────────────────────────────────

    protected override void afterDelete() {
        recalculateBeatOutletCounts(getAffectedBeatIds(Trigger.old, null));
    }

    // ── Private helper methods ──────────────────────────────────────────────

    private Set<Id> getAffectedBeatIds(List<SObject> records, Map<Id, Beat_Outlet__c> oldMap) {
        Set<Id> beatIds = new Set<Id>();
        for (SObject sobj : records) {
            Beat_Outlet__c rec = (Beat_Outlet__c) sobj;
            if (rec.Beat__c != null) {
                beatIds.add(rec.Beat__c);
            }
            // If beat was changed, also include the old beat
            if (oldMap != null) {
                Beat_Outlet__c oldRec = oldMap.get(rec.Id);
                if (oldRec != null && oldRec.Beat__c != null && oldRec.Beat__c != rec.Beat__c) {
                    beatIds.add(oldRec.Beat__c);
                }
            }
        }
        return beatIds;
    }

    private void recalculateBeatOutletCounts(Set<Id> beatIds) {
        if (beatIds.isEmpty()) {
            return;
        }

        // Count active outlets per beat
        Map<Id, Integer> countByBeat = new Map<Id, Integer>();
        for (Id beatId : beatIds) {
            countByBeat.put(beatId, 0);
        }

        for (AggregateResult ar : [
            SELECT Beat__c, COUNT(Id) cnt
            FROM Beat_Outlet__c
            WHERE Beat__c IN :beatIds
              AND Is_Active__c = true
            GROUP BY Beat__c
        ]) {
            Id beatId = (Id) ar.get('Beat__c');
            countByBeat.put(beatId, (Integer) ar.get('cnt'));
        }

        // Update parent beats
        List<Beat__c> beatsToUpdate = new List<Beat__c>();
        for (Id beatId : countByBeat.keySet()) {
            beatsToUpdate.add(new Beat__c(
                Id = beatId,
                Total_Outlets__c = countByBeat.get(beatId)
            ));
        }

        if (!beatsToUpdate.isEmpty()) {
            update beatsToUpdate;
        }
    }
}
