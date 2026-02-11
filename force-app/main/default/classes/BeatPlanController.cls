/**
 * @description Controller for the Beat Plan / Journey Plan LWC component.
 *              Manages monthly journey plans, beat assignments, approval workflows,
 *              and plan compliance tracking for FMCG field sales territory management.
 *
 * @author  SFA Development Team
 * @date    2024
 */
public with sharing class BeatPlanController {

    // ── Get Journey Plan ────────────────────────────────────────────────────────

    /**
     * @description Retrieves a Journey Plan for a specific user, month and year,
     *              including all day-level entries with beat details.
     * @param userId The Salesperson (User) Id.
     * @param month  The month name or number (e.g. 'January' or '01').
     * @param year   The four-digit year string.
     * @return The Journey_Plan__c record with child Journey_Plan_Day__c entries,
     *         or null if no plan exists.
     */
    @AuraEnabled(cacheable=true)
    public static Journey_Plan__c getJourneyPlan(Id userId, String month, String year) {
        List<Journey_Plan__c> plans = [
            SELECT Id, Name, Month__c, Year__c, Status__c, Salesperson__c,
                   Total_Planned_Visits__c, Effective_From__c, Effective_To__c,
                   Approval_Date__c, Approved_By__c, Approved_By__r.Name,
                   (SELECT Id, Day_of_Week__c, Week_Number__c, Beat__c,
                           Beat__r.Name, Beat__r.Beat_Code__c, Beat__r.Total_Outlets__c,
                           Planned_Outlets__c, Sequence_Order__c, Notes__c
                    FROM Journey_Plan_Days__r
                    ORDER BY Week_Number__c, Sequence_Order__c)
            FROM Journey_Plan__c
            WHERE Salesperson__c = :userId
            AND Month__c = :month
            AND Year__c = :year
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return plans.isEmpty() ? null : plans[0];
    }

    // ── Get Beats for Territory ─────────────────────────────────────────────────

    /**
     * @description Retrieves all active beats within a territory, with outlet counts.
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

    // ── Submit for Approval ─────────────────────────────────────────────────────

    /**
     * @description Submits a Journey Plan for managerial approval using the
     *              standard Salesforce Approval Process.
     * @param journeyPlanId The Id of the Journey Plan to submit.
     * @return The updated Journey_Plan__c record.
     */
    @AuraEnabled
    public static Journey_Plan__c submitForApproval(Id journeyPlanId) {
        try {
            // Validate current status
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

            // Update status to Submitted
            plan.Status__c = 'Submitted';
            update plan;

            // Submit via standard approval process
            Approval.ProcessSubmitRequest approvalReq = new Approval.ProcessSubmitRequest();
            approvalReq.setObjectId(journeyPlanId);
            approvalReq.setSubmitterId(UserInfo.getUserId());
            approvalReq.setComments('Journey Plan submitted for approval.');
            approvalReq.setSkipEntryCriteria(false);

            Approval.ProcessResult approvalResult = Approval.process(approvalReq);

            if (!approvalResult.isSuccess()) {
                // Revert status if approval submission fails
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

    // ── Save Journey Plan Days ──────────────────────────────────────────────────

    /**
     * @description Upserts a list of Journey Plan Day entries. Handles both new and
     *              existing records in a bulk-safe manner.
     * @param days List of Journey_Plan_Day__c records to save.
     * @return The upserted list of Journey_Plan_Day__c records.
     */
    @AuraEnabled
    public static List<Journey_Plan_Day__c> saveJourneyPlanDays(List<Journey_Plan_Day__c> days) {
        try {
            if (days == null || days.isEmpty()) {
                throw new AuraHandledException('No journey plan day entries provided.');
            }

            // Validate parent plan is editable
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

            // Recalculate total planned visits on parent plans
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

    // ── Get Plan Compliance ─────────────────────────────────────────────────────

    /**
     * @description Calculates the compliance percentage of a Journey Plan by comparing
     *              planned beats/days against actual visits completed.
     * @param journeyPlanId The Journey Plan Id.
     * @return The compliance percentage (0-100).
     */
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

        // Gather planned beat Ids
        Set<Id> plannedBeatIds = new Set<Id>();
        for (Journey_Plan_Day__c day : plan.Journey_Plan_Days__r) {
            if (day.Beat__c != null) {
                plannedBeatIds.add(day.Beat__c);
            }
        }

        // Count actual visits completed within the plan period for planned beats
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

    // ── Private Helper: Recalculate Planned Visits ──────────────────────────────

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
}
