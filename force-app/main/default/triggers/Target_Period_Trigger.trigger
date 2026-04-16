trigger Target_Period_Trigger on Target_Period__c (before insert, before update) {
    // Block duplicate active Target Periods that share the same Start_Date__c + End_Date__c.
    List<Target_Period__c> toCheck = new List<Target_Period__c>();
    Set<Date> startDates = new Set<Date>();
    Set<Date> endDates = new Set<Date>();

    for (Target_Period__c tp : Trigger.new) {
        if (tp.Is_Active__c == true && tp.Start_Date__c != null && tp.End_Date__c != null) {
            toCheck.add(tp);
            startDates.add(tp.Start_Date__c);
            endDates.add(tp.End_Date__c);
        }
    }

    if (toCheck.isEmpty()) {
        return;
    }

    // Pull existing active periods whose start or end date intersects any candidate.
    Map<String, Target_Period__c> existingByKey = new Map<String, Target_Period__c>();
    for (Target_Period__c existing : [
        SELECT Id, Name, Start_Date__c, End_Date__c
        FROM Target_Period__c
        WHERE Is_Active__c = true
          AND Start_Date__c IN :startDates
          AND End_Date__c IN :endDates
    ]) {
        String key = String.valueOf(existing.Start_Date__c) + '|' + String.valueOf(existing.End_Date__c);
        existingByKey.put(key + '|' + existing.Id, existing);
    }

    for (Target_Period__c tp : toCheck) {
        String prefix = String.valueOf(tp.Start_Date__c) + '|' + String.valueOf(tp.End_Date__c) + '|';
        for (String k : existingByKey.keySet()) {
            if (!k.startsWith(prefix)) continue;
            Target_Period__c existing = existingByKey.get(k);
            if (existing.Id == tp.Id) continue;
            tp.addError(
                'An active period "' + existing.Name + '" already exists with the same Start Date (' +
                tp.Start_Date__c.format() + ') and End Date (' + tp.End_Date__c.format() +
                '). Deactivate the existing period or choose different dates before saving.'
            );
            break;
        }
    }
}
