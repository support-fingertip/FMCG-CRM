public with sharing class MDM_CompanyHierarchy_Handler extends TriggerHandler {

    // Simple recursion guard for rollup updates
    private static Boolean isRunningRollup = false;

    protected override void beforeInsert() {
        List<Company_Hierarchy__c> newRecords = (List<Company_Hierarchy__c>) Trigger.new;
        validateUniqueCode(newRecords);
        validateNoCircularHierarchy(newRecords); // insert: mainly defensive
    }

    protected override void beforeUpdate() {
        List<Company_Hierarchy__c> newRecords = (List<Company_Hierarchy__c>) Trigger.new;
        Map<Id, Company_Hierarchy__c> oldMap = (Map<Id, Company_Hierarchy__c>) Trigger.oldMap;

        List<Company_Hierarchy__c> parentChanged = new List<Company_Hierarchy__c>();
        List<Company_Hierarchy__c> codeChanged = new List<Company_Hierarchy__c>();

        for (Company_Hierarchy__c rec : newRecords) {
            Company_Hierarchy__c oldRec = oldMap.get(rec.Id);
            if (rec.Parent_Hierarchy__c != oldRec.Parent_Hierarchy__c) parentChanged.add(rec);
            if (rec.Hierarchy_Code__c != oldRec.Hierarchy_Code__c) codeChanged.add(rec);
        }

        if (!codeChanged.isEmpty()) validateUniqueCode(codeChanged);
        if (!parentChanged.isEmpty()) validateNoCircularHierarchy(parentChanged);
    }

    protected override void afterInsert() {
        List<Company_Hierarchy__c> newRecords = (List<Company_Hierarchy__c>) Trigger.new;
        // Prevent infinite loop when we update parents for rollups
        if (isRunningRollup) return;
        
        updateTerritoryRollupsAfterChange(newRecords, null);
    }

    protected override void afterUpdate() {
        List<Company_Hierarchy__c> newRecords = (List<Company_Hierarchy__c>) Trigger.new;
        Map<Id, Company_Hierarchy__c> oldMap = (Map<Id, Company_Hierarchy__c>) Trigger.oldMap;
        
        // Prevent infinite loop when we update parents for rollups
        if (isRunningRollup) return;

        List<Company_Hierarchy__c> relevant = new List<Company_Hierarchy__c>();
        for (Company_Hierarchy__c rec : newRecords) {
            Company_Hierarchy__c oldRec = oldMap.get(rec.Id);
            if (rec.Parent_Hierarchy__c != oldRec.Parent_Hierarchy__c ||
                rec.Territory__c != oldRec.Territory__c ||
                rec.Is_Active__c != oldRec.Is_Active__c) {
                relevant.add(rec);
            }
        }
        if (!relevant.isEmpty()) updateTerritoryRollupsAfterChange(relevant, oldMap);
    }

    protected override void afterDelete() {
        // No specific logic needed for delete
    }

    protected override void afterUndelete() {
        // No specific logic needed for undelete
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Unique code validation
    // ─────────────────────────────────────────────────────────────────────────
    private static void validateUniqueCode(List<Company_Hierarchy__c> records) {
        Set<String> newCodes = new Set<String>();
        Set<String> duplicatesInBatch = new Set<String>();

        for (Company_Hierarchy__c rec : records) {
            if (String.isNotBlank(rec.Hierarchy_Code__c)) {
                String code = rec.Hierarchy_Code__c.trim().toUpperCase();
                if (newCodes.contains(code)) duplicatesInBatch.add(code);
                newCodes.add(code);
            }
        }
        if (newCodes.isEmpty()) return;

        Set<Id> currentIds = new Set<Id>();
        for (Company_Hierarchy__c rec : records) if (rec.Id != null) currentIds.add(rec.Id);

        Set<String> existingCodes = new Set<String>();
        for (Company_Hierarchy__c existing : [
            SELECT Hierarchy_Code__c
            FROM Company_Hierarchy__c
            WHERE Hierarchy_Code__c IN :newCodes
            AND Id NOT IN :currentIds
        ]) {
            if (String.isNotBlank(existing.Hierarchy_Code__c)) {
                existingCodes.add(existing.Hierarchy_Code__c.trim().toUpperCase());
            }
        }

        for (Company_Hierarchy__c rec : records) {
            if (String.isBlank(rec.Hierarchy_Code__c)) continue;

            String code = rec.Hierarchy_Code__c.trim().toUpperCase();
            if (existingCodes.contains(code)) {
                rec.Hierarchy_Code__c.addError(
                    'Hierarchy Code \'' + rec.Hierarchy_Code__c + '\' already exists. Please use a unique code.'
                );
            } else if (duplicatesInBatch.contains(code)) {
                rec.Hierarchy_Code__c.addError(
                    'Duplicate Hierarchy Code \'' + rec.Hierarchy_Code__c + '\' found within the same batch.'
                );
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Circular hierarchy validation (governor-safe)
    // ─────────────────────────────────────────────────────────────────────────
    private static void validateNoCircularHierarchy(List<Company_Hierarchy__c> records) {
        // Only meaningful when records have Ids (updates). On insert, lookup cycles
        // aren't representable because the parent needs an Id.
        Set<Id> startParents = new Set<Id>();
        for (Company_Hierarchy__c rec : records) {
            if (rec.Parent_Hierarchy__c != null) startParents.add(rec.Parent_Hierarchy__c);
        }
        if (startParents.isEmpty()) return;

        // Build parent map by querying all hierarchy records at once
        // and traversing the tree in memory instead of iterative SOQL
        Map<Id, Id> parentById = new Map<Id, Id>();
        for (Company_Hierarchy__c node : [
            SELECT Id, Parent_Hierarchy__c
            FROM Company_Hierarchy__c
            WHERE Parent_Hierarchy__c != null
        ]) {
            parentById.put(node.Id, node.Parent_Hierarchy__c);
        }

        Integer maxDepth = 50;

        for (Company_Hierarchy__c rec : records) {
            if (rec.Id == null || rec.Parent_Hierarchy__c == null) continue;

            Set<Id> visited = new Set<Id>();
            visited.add(rec.Id);

            Id current = rec.Parent_Hierarchy__c;
            Integer steps = 0;

            while (current != null && steps < maxDepth) {
                if (visited.contains(current)) {
                    rec.Parent_Hierarchy__c.addError(
                        'Circular hierarchy detected. The selected parent would create a circular reference.'
                    );
                    break;
                }
                visited.add(current);
                current = parentById.get(current);
                steps++;
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Rollups
    // ─────────────────────────────────────────────────────────────────────────
    private static void updateTerritoryRollupsAfterChange(
        List<Company_Hierarchy__c> changed,
        Map<Id, Company_Hierarchy__c> oldMap
    ) {
        Set<Id> parentIds = new Set<Id>();

        for (Company_Hierarchy__c rec : changed) {
            if (rec.Parent_Hierarchy__c != null) parentIds.add(rec.Parent_Hierarchy__c);

            // key fix: include OLD parent too
            if (oldMap != null && rec.Id != null) {
                Id oldParent = oldMap.get(rec.Id).Parent_Hierarchy__c;
                if (oldParent != null) parentIds.add(oldParent);
            }
        }
        if (parentIds.isEmpty()) return;

        Map<Id, Integer> totalChildCount = new Map<Id, Integer>();
        Map<Id, Integer> activeChildCount = new Map<Id, Integer>();
        for (Id pid : parentIds) {
            totalChildCount.put(pid, 0);
            activeChildCount.put(pid, 0);
        }

        for (Company_Hierarchy__c child : [
            SELECT Parent_Hierarchy__c, Is_Active__c
            FROM Company_Hierarchy__c
            WHERE Parent_Hierarchy__c IN :parentIds
        ]) {
            Id pid = child.Parent_Hierarchy__c;
            totalChildCount.put(pid, totalChildCount.get(pid) + 1);
            if (child.Is_Active__c == true) {
                activeChildCount.put(pid, activeChildCount.get(pid) + 1);
            }
        }

        List<Company_Hierarchy__c> parentsToUpdate = new List<Company_Hierarchy__c>();
        for (Id pid : parentIds) {
            parentsToUpdate.add(new Company_Hierarchy__c(
                Id = pid,
                Total_Child_Nodes__c = totalChildCount.get(pid),
                Active_Child_Nodes__c = activeChildCount.get(pid)
            ));
        }

        if (parentsToUpdate.isEmpty()) return;

        isRunningRollup = true;
        try {
            update parentsToUpdate;
        } finally {
            isRunningRollup = false;
        }
    }
}