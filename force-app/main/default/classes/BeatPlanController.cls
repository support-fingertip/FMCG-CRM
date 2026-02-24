/**
 * @description Controller for the Beat Plan / Journey Plan LWC component.
 *              Manages monthly journey plans, beat assignments, approval workflows,
 *              and plan compliance tracking for FMCG field sales territory management.
 */
public with sharing class BeatPlanController {

    /**
     * Wrapper class so the LWC receives a structured response with both the
     * plan header and the flattened list of day entries.
     */
    public class JourneyPlanResult {
        @AuraEnabled public Journey_Plan__c journeyPlan;
        @AuraEnabled public List<Journey_Plan_Day__c> planDays;
    }

    // ── Get Journey Plan by Record Id (for record-page context) ───────────────

    /**
     * @description Loads a Journey Plan directly by its record Id and returns
     *              a structured wrapper with the plan + day entries.
     * @param journeyPlanId The Journey_Plan__c record Id from the record page.
     * @return JourneyPlanResult wrapper.
     */
    @AuraEnabled
    public static JourneyPlanResult getJourneyPlanById(Id journeyPlanId) {
        List<Journey_Plan__c> plans = [
            SELECT Id, Name, Month__c, Year__c, Status__c, Salesperson__c,
                   Salesperson__r.Name, Total_Planned_Visits__c,
                   Territory__c, Territory__r.Name,
                   Effective_From__c, Effective_To__c,
                   Approval_Date__c, Approved_By__c, Approved_By__r.Name
            FROM Journey_Plan__c
            WHERE Id = :journeyPlanId
            LIMIT 1
        ];

        JourneyPlanResult result = new JourneyPlanResult();
        if (plans.isEmpty()) {
            result.journeyPlan = null;
            result.planDays = new List<Journey_Plan_Day__c>();
            return result;
        }

        result.journeyPlan = plans[0];
        result.planDays = [
            SELECT Id, Day_of_Week__c, Week_Number__c, Beat__c,
                   Beat__r.Name, Beat__r.Beat_Code__c, Beat__r.Total_Outlets__c,
                   Planned_Outlets__c, Sequence_Order__c, Notes__c,
                   Plan_Date__c, Journey_Plan__c
            FROM Journey_Plan_Day__c
            WHERE Journey_Plan__c = :journeyPlanId
            ORDER BY Plan_Date__c, Sequence_Order__c
        ];
        return result;
    }

    // ── Get Journey Plan by User / Month / Year ───────────────────────────────

    /**
     * @description Retrieves a Journey Plan for a specific user, month and year.
     * @param userId The Salesperson (User) Id.
     * @param month  The month name (e.g. 'January', 'March').
     * @param year   The four-digit year string (e.g. '2026').
     * @return JourneyPlanResult wrapper, or empty wrapper if no plan exists.
     */
    @AuraEnabled
    public static JourneyPlanResult getJourneyPlan(Id userId, String month, String year) {
        List<Journey_Plan__c> plans = [
            SELECT Id, Name, Month__c, Year__c, Status__c, Salesperson__c,
                   Salesperson__r.Name, Total_Planned_Visits__c,
                   Territory__c, Territory__r.Name,
                   Effective_From__c, Effective_To__c,
                   Approval_Date__c, Approved_By__c, Approved_By__r.Name
            FROM Journey_Plan__c
            WHERE Salesperson__c = :userId
            AND Month__c = :month
            AND Year__c = :year
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        JourneyPlanResult result = new JourneyPlanResult();
        if (plans.isEmpty()) {
            result.journeyPlan = null;
            result.planDays = new List<Journey_Plan_Day__c>();
            return result;
        }

        result.journeyPlan = plans[0];
        result.planDays = [
            SELECT Id, Day_of_Week__c, Week_Number__c, Beat__c,
                   Beat__r.Name, Beat__r.Beat_Code__c, Beat__r.Total_Outlets__c,
                   Planned_Outlets__c, Sequence_Order__c, Notes__c,
                   Plan_Date__c, Journey_Plan__c
            FROM Journey_Plan_Day__c
            WHERE Journey_Plan__c = :plans[0].Id
            ORDER BY Plan_Date__c, Sequence_Order__c
        ];
        return result;
    }

    // ── Get Beats for Territory ───────────────────────────────────────────────

    /**
     * @description Retrieves all active beats within a territory.
     * @param territoryId The Territory_Master__c Id.
     * @return List of Beat__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Beat__c> getBeatsForTerritory(Id territoryId) {
        return [
            SELECT Id, Name, Beat_Code__c, Day_of_Week__c, Frequency__c,
                   Total_Outlets__c, Pincode_Cluster__c, Description__c,
                   Territory__c, Territory__r.Name
            FROM Beat__c
            WHERE Territory__c = :territoryId
            AND Is_Active__c = true
            ORDER BY Beat_Code__c
        ];
    }

    /**
     * @description Retrieves all active beats for a salesperson by looking up
     *              their assigned territory from Journey Plans or Territory assignments.
     * @param userId The User (Salesperson) Id.
     * @return List of Beat__c records from the user's territory.
     */
    @AuraEnabled(cacheable=true)
    public static List<Beat__c> getBeatsForUser(Id userId) {
        // First try to find territory from user's most recent Journey Plan
        List<Journey_Plan__c> plans = [
            SELECT Id, Salesperson__c
            FROM Journey_Plan__c
            WHERE Salesperson__c = :userId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        // Collect territory Ids from beats already linked to this user's plans
        Set<Id> territoryIds = new Set<Id>();

        // Look for beats assigned in any Journey Plan Day for this user
        List<Journey_Plan_Day__c> planDays = [
            SELECT Beat__r.Territory__c
            FROM Journey_Plan_Day__c
            WHERE Journey_Plan__r.Salesperson__c = :userId
            AND Beat__r.Territory__c != null
        ];
        for (Journey_Plan_Day__c pd : planDays) {
            territoryIds.add(pd.Beat__r.Territory__c);
        }

        // Also check if there are any Accounts assigned to this user with a territory
        if (territoryIds.isEmpty()) {
            List<Account> accts = [
                SELECT Territory__c
                FROM Account
                WHERE OwnerId = :userId
                AND Territory__c != null
                LIMIT 100
            ];
            for (Account a : accts) {
                territoryIds.add(a.Territory__c);
            }
        }

        if (territoryIds.isEmpty()) {
            // Return all active beats as fallback (admin/manager view)
            return [
                SELECT Id, Name, Beat_Code__c, Day_of_Week__c, Frequency__c,
                       Total_Outlets__c, Pincode_Cluster__c, Description__c,
                       Territory__c, Territory__r.Name
                FROM Beat__c
                WHERE Is_Active__c = true
                ORDER BY Territory__r.Name, Beat_Code__c
                LIMIT 200
            ];
        }

        return [
            SELECT Id, Name, Beat_Code__c, Day_of_Week__c, Frequency__c,
                   Total_Outlets__c, Pincode_Cluster__c, Description__c,
                   Territory__c, Territory__r.Name
            FROM Beat__c
            WHERE Territory__c IN :territoryIds
            AND Is_Active__c = true
            ORDER BY Beat_Code__c
        ];
    }

    // ── Submit for Approval ───────────────────────────────────────────────────

    @AuraEnabled
    public static Journey_Plan__c submitForApproval(Id journeyPlanId) {
        try {
            Journey_Plan__c plan = [
                SELECT Id, Status__c, Salesperson__c
                FROM Journey_Plan__c
                WHERE Id = :journeyPlanId
                LIMIT 1
            ];

            if (plan.Status__c == 'Approved') {
                throw new AuraHandledException('This journey plan has already been approved.');
            }
            if (plan.Status__c == 'Submitted') {
                throw new AuraHandledException('This journey plan has already been submitted for approval.');
            }

            plan.Status__c = 'Submitted';
            update plan;

            Approval.ProcessSubmitRequest approvalReq = new Approval.ProcessSubmitRequest();
            approvalReq.setObjectId(journeyPlanId);
            approvalReq.setSubmitterId(UserInfo.getUserId());
            approvalReq.setComments('Journey Plan submitted for approval.');
            approvalReq.setSkipEntryCriteria(false);

            Approval.ProcessResult approvalResult = Approval.process(approvalReq);

            if (!approvalResult.isSuccess()) {
                plan.Status__c = 'Draft';
                update plan;
                String errorMsg = 'Approval submission failed.';
                if (approvalResult.getErrors() != null && !approvalResult.getErrors().isEmpty()) {
                    errorMsg = approvalResult.getErrors()[0].getMessage();
                }
                throw new AuraHandledException(errorMsg);
            }

            return [
                SELECT Id, Name, Status__c, Month__c, Year__c
                FROM Journey_Plan__c
                WHERE Id = :journeyPlanId
                LIMIT 1
            ];
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Save Journey Plan Days ────────────────────────────────────────────────

    @AuraEnabled
    public static List<Journey_Plan_Day__c> saveJourneyPlanDays(List<Journey_Plan_Day__c> days) {
        try {
            if (days == null || days.isEmpty()) {
                throw new AuraHandledException('No journey plan day entries provided.');
            }

            Set<Id> planIds = new Set<Id>();
            for (Journey_Plan_Day__c day : days) {
                if (day.Journey_Plan__c != null) {
                    planIds.add(day.Journey_Plan__c);
                }
            }

            if (!planIds.isEmpty()) {
                List<Journey_Plan__c> plans = [
                    SELECT Id, Status__c
                    FROM Journey_Plan__c
                    WHERE Id IN :planIds
                    AND Status__c IN ('Approved', 'Submitted')
                ];
                if (!plans.isEmpty()) {
                    throw new AuraHandledException(
                        'Cannot modify days for a journey plan that is already submitted or approved.'
                    );
                }
            }

            upsert days;

            if (!planIds.isEmpty()) {
                recalculatePlannedVisits(planIds);
            }

            return days;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Get Plan Compliance ───────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Decimal getPlanCompliance(Id journeyPlanId) {
        Journey_Plan__c plan = [
            SELECT Id, Salesperson__c, Effective_From__c, Effective_To__c,
                   Total_Planned_Visits__c,
                   (SELECT Id, Beat__c, Day_of_Week__c, Week_Number__c, Planned_Outlets__c
                    FROM Journey_Plan_Days__r)
            FROM Journey_Plan__c
            WHERE Id = :journeyPlanId
            LIMIT 1
        ];

        if (plan.Journey_Plan_Days__r == null || plan.Journey_Plan_Days__r.isEmpty()) {
            return 0;
        }

        Integer totalPlanned = plan.Journey_Plan_Days__r.size();

        Set<Id> plannedBeatIds = new Set<Id>();
        for (Journey_Plan_Day__c day : plan.Journey_Plan_Days__r) {
            if (day.Beat__c != null) {
                plannedBeatIds.add(day.Beat__c);
            }
        }

        Date startDate = plan.Effective_From__c != null ? plan.Effective_From__c : Date.today().toStartOfMonth();
        Date endDate = plan.Effective_To__c != null ? plan.Effective_To__c : startDate.addMonths(1).addDays(-1);

        Integer actualVisits = [
            SELECT COUNT()
            FROM Visit__c
            WHERE Salesperson__c = :plan.Salesperson__c
            AND Visit_Date__c >= :startDate
            AND Visit_Date__c <= :endDate
            AND Beat__c IN :plannedBeatIds
            AND Visit_Status__c = 'Completed'
        ];

        if (totalPlanned == 0) {
            return 0;
        }

        Decimal compliance = (Decimal.valueOf(actualVisits) / Decimal.valueOf(totalPlanned)) * 100;
        return compliance.setScale(2, RoundingMode.HALF_UP);
    }

    // ── Private Helpers ───────────────────────────────────────────────────────

    private static void recalculatePlannedVisits(Set<Id> planIds) {
        List<AggregateResult> aggResults = [
            SELECT Journey_Plan__c planId, SUM(Planned_Outlets__c) totalOutlets
            FROM Journey_Plan_Day__c
            WHERE Journey_Plan__c IN :planIds
            GROUP BY Journey_Plan__c
        ];

        List<Journey_Plan__c> plansToUpdate = new List<Journey_Plan__c>();
        for (AggregateResult ar : aggResults) {
            plansToUpdate.add(new Journey_Plan__c(
                Id = (Id)ar.get('planId'),
                Total_Planned_Visits__c = (Decimal)ar.get('totalOutlets')
            ));
        }
        if (!plansToUpdate.isEmpty()) {
            update plansToUpdate;
        }
    }

    // ── Beat CRUD ───────────────────────────────────────────────────────────

    @AuraEnabled
    public static Beat__c saveBeat(Beat__c beat) {
        try {
            upsert beat;
            return [
                SELECT Id, Name, Beat_Code__c, Day_of_Week__c, Frequency__c,
                       Total_Outlets__c, Pincode_Cluster__c, Description__c,
                       Territory__c, Territory__r.Name, Assigned_User__c,
                       Is_Active__c, Sequence__c
                FROM Beat__c
                WHERE Id = :beat.Id
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteBeat(Id beatId) {
        try {
            delete [SELECT Id FROM Beat__c WHERE Id = :beatId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Beat Outlet Management ──────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Beat_Outlet__c> getBeatOutlets(Id beatId) {
        return [
            SELECT Id, Beat__c, Account__c, Account__r.Name,
                   Is_Active__c, Visit_Sequence__c
            FROM Beat_Outlet__c
            WHERE Beat__c = :beatId
            ORDER BY Visit_Sequence__c
        ];
    }

    @AuraEnabled
    public static List<Beat_Outlet__c> addBeatOutlets(Id beatId, List<Id> accountIds) {
        try {
            Set<Id> existingAccountIds = new Set<Id>();
            for (Beat_Outlet__c bo : [SELECT Account__c FROM Beat_Outlet__c WHERE Beat__c = :beatId]) {
                existingAccountIds.add(bo.Account__c);
            }

            List<AggregateResult> maxSeqResult = [
                SELECT MAX(Visit_Sequence__c) maxVal
                FROM Beat_Outlet__c
                WHERE Beat__c = :beatId
            ];
            Integer nextSeq = 1;
            if (maxSeqResult[0].get('maxVal') != null) {
                nextSeq = ((Decimal)maxSeqResult[0].get('maxVal')).intValue() + 1;
            }

            List<Beat_Outlet__c> newOutlets = new List<Beat_Outlet__c>();
            for (Id accId : accountIds) {
                if (!existingAccountIds.contains(accId)) {
                    newOutlets.add(new Beat_Outlet__c(
                        Beat__c = beatId,
                        Account__c = accId,
                        Is_Active__c = true,
                        Visit_Sequence__c = nextSeq++
                    ));
                }
            }

            if (!newOutlets.isEmpty()) {
                insert newOutlets;
            }

            return [
                SELECT Id, Beat__c, Account__c, Account__r.Name,
                       Is_Active__c, Visit_Sequence__c
                FROM Beat_Outlet__c
                WHERE Beat__c = :beatId
                ORDER BY Visit_Sequence__c
            ];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void removeBeatOutlet(Id beatOutletId) {
        try {
            delete [SELECT Id FROM Beat_Outlet__c WHERE Id = :beatOutletId];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Account> searchAccounts(String searchTerm) {
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return new List<Account>();
        }
        String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        return [
            SELECT Id, Name, Type, BillingCity, BillingState
            FROM Account
            WHERE Name LIKE :searchPattern
            ORDER BY Name
            LIMIT 50
        ];
    }

    // ── Calendar Day Persistence ────────────────────────────────────────────

    @AuraEnabled
    public static Journey_Plan_Day__c addBeatToCalendarDay(
        Id journeyPlanId, Id beatId, String dayOfWeek, String weekNumber, Date planDate
    ) {
        try {
            Journey_Plan__c plan = [
                SELECT Id, Status__c FROM Journey_Plan__c WHERE Id = :journeyPlanId LIMIT 1
            ];
            if (plan.Status__c == 'Approved' || plan.Status__c == 'Submitted') {
                throw new AuraHandledException('Cannot modify a plan that is submitted or approved.');
            }

            Integer outletCount = [
                SELECT COUNT() FROM Beat_Outlet__c
                WHERE Beat__c = :beatId AND Is_Active__c = true
            ];

            List<AggregateResult> maxSeq = [
                SELECT MAX(Sequence_Order__c) maxVal
                FROM Journey_Plan_Day__c
                WHERE Journey_Plan__c = :journeyPlanId
            ];
            Integer nextSeq = 1;
            if (maxSeq[0].get('maxVal') != null) {
                nextSeq = ((Decimal)maxSeq[0].get('maxVal')).intValue() + 1;
            }

            Journey_Plan_Day__c planDay = new Journey_Plan_Day__c(
                Journey_Plan__c = journeyPlanId,
                Beat__c = beatId,
                Day_of_Week__c = dayOfWeek,
                Week_Number__c = weekNumber,
                Plan_Date__c = planDate,
                Planned_Outlets__c = outletCount,
                Status__c = 'Planned',
                Sequence_Order__c = nextSeq
            );
            insert planDay;

            return [
                SELECT Id, Day_of_Week__c, Week_Number__c, Beat__c,
                       Beat__r.Name, Beat__r.Beat_Code__c, Beat__r.Total_Outlets__c,
                       Planned_Outlets__c, Sequence_Order__c, Plan_Date__c, Notes__c,
                       Journey_Plan__c
                FROM Journey_Plan_Day__c
                WHERE Id = :planDay.Id
            ];
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void removePlanDay(Id planDayId) {
        try {
            Journey_Plan_Day__c day = [
                SELECT Id, Journey_Plan__r.Status__c
                FROM Journey_Plan_Day__c WHERE Id = :planDayId LIMIT 1
            ];
            if (day.Journey_Plan__r.Status__c == 'Approved' || day.Journey_Plan__r.Status__c == 'Submitted') {
                throw new AuraHandledException('Cannot modify a plan that is submitted or approved.');
            }
            delete day;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Generate Default Plan ───────────────────────────────────────────────

    @AuraEnabled
    public static Id generateDefaultPlan(Id userId, Id territoryId, String month, String year) {
        try {
            return BPM_JourneyPlan_Service.generateDefaultPlan(userId, territoryId, month, year);
        } catch (BPM_JourneyPlanServiceException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
