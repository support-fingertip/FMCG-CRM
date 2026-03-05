/**
 * @description Controller for the Expense Manager LWC components.
 *              Thin @AuraEnabled wrapper that delegates all business logic
 *              to EXP_Expense_Service.
 *
 * @author  SFA Development Team
 * @date    2026
 */
public with sharing class ExpenseController {

    @AuraEnabled
    public static Expense__c getOrCreateReport(String month, Integer year) {
        try {
            return EXP_Expense_Service.getOrCreateReport(UserInfo.getUserId(), month, year);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getEligibleDates(String month, Integer year) {
        try {
            return EXP_Expense_Service.getEligibleDates(UserInfo.getUserId(), month, year);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense_Eligibility__c> getEligibilityRules() {
        try {
            String band = EXP_Expense_Service.getEmployeeBand(UserInfo.getUserId());
            if (String.isBlank(band)) {
                throw new AuraHandledException('No band configured for current employee.');
            }
            return EXP_Expense_Service.getEligibilityRules(band);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Expense_Item__c> getExpenseItemsForDate(Id expenseId, Date expenseDate) {
        try {
            return EXP_Expense_Service.getExpenseItemsForDate(expenseId, expenseDate);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Expense_Item__c> saveExpenseItems(Id expenseId, String itemsJson) {
        try {
            List<Expense_Item__c> items = (List<Expense_Item__c>)
                JSON.deserialize(itemsJson, List<Expense_Item__c>.class);
            return EXP_Expense_Service.saveExpenseItems(expenseId, items);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteExpenseItems(List<Id> itemIds) {
        try {
            EXP_Expense_Service.deleteExpenseItems(itemIds);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Expense__c submitReport(Id expenseId) {
        try {
            return EXP_Expense_Service.submitReport(expenseId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Expense__c approveReport(Id expenseId, String remarks, String level) {
        try {
            return EXP_Expense_Service.approveReport(expenseId, remarks, level);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Expense__c rejectReport(Id expenseId, String reason, String level) {
        try {
            return EXP_Expense_Service.rejectReport(expenseId, reason, level);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getReportSummary(Id expenseId) {
        try {
            return EXP_Expense_Service.getReportSummary(expenseId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMonthlyOverview(Integer year) {
        try {
            return EXP_Expense_Service.getMonthlyOverview(UserInfo.getUserId(), year);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getExpenseConfig() {
        try {
            Map<String, Object> config = new Map<String, Object>();
            config.put('expenseEnabled', BPM_FeatureToggle_Util.isEnabled(EXP_Expense_Service.FEATURE_EXPENSE));
            config.put('autoCalcEnabled', BPM_FeatureToggle_Util.isEnabled(EXP_Expense_Service.FEATURE_AUTO_CALC));
            config.put('financeApprovalEnabled', BPM_FeatureToggle_Util.isEnabled(EXP_Expense_Service.FEATURE_FINANCE_APPROVAL));
            config.put('maxOverridePercent', EXP_Expense_Service.getConfigInteger('MAX_OVERRIDE_PERCENT', 150));
            config.put('reportLockDay', EXP_Expense_Service.getConfigInteger('REPORT_LOCK_DAY', 5));
            config.put('allowFutureDates', EXP_Expense_Service.getConfigBoolean('ALLOW_FUTURE_DATES', false));
            return config;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Expense__c> getTeamExpenseReports(String month, Integer year) {
        try {
            return EXP_Expense_Service.getTeamExpenseReports(UserInfo.getUserId(), month, year);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Expense__c markAsPaid(Id expenseId) {
        try {
            return EXP_Expense_Service.markAsPaid(expenseId);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
