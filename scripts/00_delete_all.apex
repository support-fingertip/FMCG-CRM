// ============================================================
// Master Cleanup Script — Deletes ALL seed data
// Run BEFORE re-running seed scripts to avoid duplicates
// Run via: sf apex run --file scripts/00_delete_all.apex
//
// NOTE: Does NOT delete Users (cannot delete in Salesforce)
// WARNING: This deletes ALL records from custom objects!
// ============================================================

System.debug('═══════════════════════════════════════════');
System.debug('STARTING CLEANUP...');
System.debug('═══════════════════════════════════════════');

Integer c;

// ── Incentives & Targets (delete children first) ─────────
c = [SELECT COUNT() FROM Incentive__c];
if (c > 0) { delete [SELECT Id FROM Incentive__c]; System.debug('Deleted ' + c + ' Incentive__c'); }

c = [SELECT COUNT() FROM Incentive_Slab__c];
if (c > 0) { delete [SELECT Id FROM Incentive_Slab__c]; System.debug('Deleted ' + c + ' Incentive_Slab__c'); }

c = [SELECT COUNT() FROM Target_Actual__c];
if (c > 0) { delete [SELECT Id FROM Target_Actual__c]; System.debug('Deleted ' + c + ' Target_Actual__c'); }

c = [SELECT COUNT() FROM Target_Criteria__c];
if (c > 0) { delete [SELECT Id FROM Target_Criteria__c]; System.debug('Deleted ' + c + ' Target_Criteria__c'); }

c = [SELECT COUNT() FROM Target_Period__c];
if (c > 0) { delete [SELECT Id FROM Target_Period__c]; System.debug('Deleted ' + c + ' Target_Period__c'); }

// ── Leave Management ─────────────────────────────────────
c = [SELECT COUNT() FROM Leave_Request__c];
if (c > 0) { delete [SELECT Id FROM Leave_Request__c]; System.debug('Deleted ' + c + ' Leave_Request__c'); }

c = [SELECT COUNT() FROM Leave_Balance__c];
if (c > 0) { delete [SELECT Id FROM Leave_Balance__c]; System.debug('Deleted ' + c + ' Leave_Balance__c'); }

c = [SELECT COUNT() FROM Leave_Policy__c];
if (c > 0) { delete [SELECT Id FROM Leave_Policy__c]; System.debug('Deleted ' + c + ' Leave_Policy__c'); }

// ── Invoices & Orders (delete children first) ────────────
c = [SELECT COUNT() FROM Invoice_Line__c];
if (c > 0) { delete [SELECT Id FROM Invoice_Line__c]; System.debug('Deleted ' + c + ' Invoice_Line__c'); }

c = [SELECT COUNT() FROM Invoice__c];
if (c > 0) { delete [SELECT Id FROM Invoice__c]; System.debug('Deleted ' + c + ' Invoice__c'); }

// Delete orders first — line items auto-cascade via Master-Detail
// (Deleting line items first triggers order update validation errors)
c = [SELECT COUNT() FROM Sales_Order__c];
if (c > 0) { delete [SELECT Id FROM Sales_Order__c]; System.debug('Deleted ' + c + ' Sales_Order__c (+ line items cascaded)'); }

c = [SELECT COUNT() FROM Collection__c];
if (c > 0) { delete [SELECT Id FROM Collection__c]; System.debug('Deleted ' + c + ' Collection__c'); }

c = [SELECT COUNT() FROM Return_Order__c];
if (c > 0) { delete [SELECT Id FROM Return_Order__c]; System.debug('Deleted ' + c + ' Return_Order__c'); }

// ── Visits & Day Operations ──────────────────────────────
c = [SELECT COUNT() FROM Visit__c];
if (c > 0) { delete [SELECT Id FROM Visit__c]; System.debug('Deleted ' + c + ' Visit__c'); }

c = [SELECT COUNT() FROM Day_Attendance__c];
if (c > 0) { delete [SELECT Id FROM Day_Attendance__c]; System.debug('Deleted ' + c + ' Day_Attendance__c'); }

// ── Journey Plans & Beats ────────────────────────────────
c = [SELECT COUNT() FROM Journey_Plan__c];
if (c > 0) { delete [SELECT Id FROM Journey_Plan__c]; System.debug('Deleted ' + c + ' Journey_Plan__c'); }

c = [SELECT COUNT() FROM Beat_Outlet__c];
if (c > 0) { delete [SELECT Id FROM Beat_Outlet__c]; System.debug('Deleted ' + c + ' Beat_Outlet__c'); }

c = [SELECT COUNT() FROM Beat__c];
if (c > 0) { delete [SELECT Id FROM Beat__c]; System.debug('Deleted ' + c + ' Beat__c'); }

// ── Schemes ──────────────────────────────────────────────
c = [SELECT COUNT() FROM Scheme_Mapping__c];
if (c > 0) { delete [SELECT Id FROM Scheme_Mapping__c]; System.debug('Deleted ' + c + ' Scheme_Mapping__c'); }

c = [SELECT COUNT() FROM Scheme_Product__c];
if (c > 0) { delete [SELECT Id FROM Scheme_Product__c]; System.debug('Deleted ' + c + ' Scheme_Product__c'); }

c = [SELECT COUNT() FROM Scheme_Slab__c];
if (c > 0) { delete [SELECT Id FROM Scheme_Slab__c]; System.debug('Deleted ' + c + ' Scheme_Slab__c'); }

c = [SELECT COUNT() FROM Scheme__c];
if (c > 0) { delete [SELECT Id FROM Scheme__c]; System.debug('Deleted ' + c + ' Scheme__c'); }

// ── Products & Pricing ───────────────────────────────────
c = [SELECT COUNT() FROM UOM_Conversion__c];
if (c > 0) { delete [SELECT Id FROM UOM_Conversion__c]; System.debug('Deleted ' + c + ' UOM_Conversion__c'); }

c = [SELECT COUNT() FROM Price_Change_Log__c];
if (c > 0) { delete [SELECT Id FROM Price_Change_Log__c]; System.debug('Deleted ' + c + ' Price_Change_Log__c'); }

c = [SELECT COUNT() FROM Price_List__c];
if (c > 0) { delete [SELECT Id FROM Price_List__c]; System.debug('Deleted ' + c + ' Price_List__c'); }

c = [SELECT COUNT() FROM Must_Sell_Config__c];
if (c > 0) { delete [SELECT Id FROM Must_Sell_Config__c]; System.debug('Deleted ' + c + ' Must_Sell_Config__c'); }

c = [SELECT COUNT() FROM Batch_Master__c];
if (c > 0) { delete [SELECT Id FROM Batch_Master__c]; System.debug('Deleted ' + c + ' Batch_Master__c'); }

c = [SELECT COUNT() FROM Product_Extension__c];
if (c > 0) { delete [SELECT Id FROM Product_Extension__c]; System.debug('Deleted ' + c + ' Product_Extension__c'); }

// Delete child categories first, then parents
c = [SELECT COUNT() FROM Product_Category__c WHERE Parent_Category__c != null];
if (c > 0) { delete [SELECT Id FROM Product_Category__c WHERE Parent_Category__c != null]; System.debug('Deleted ' + c + ' child Product_Category__c'); }

c = [SELECT COUNT() FROM Product_Category__c];
if (c > 0) { delete [SELECT Id FROM Product_Category__c]; System.debug('Deleted ' + c + ' parent Product_Category__c'); }

c = [SELECT COUNT() FROM UOM__c];
if (c > 0) { delete [SELECT Id FROM UOM__c]; System.debug('Deleted ' + c + ' UOM__c'); }

// ── Stock & Warehouses ───────────────────────────────────
c = [SELECT COUNT() FROM Distributor_Stock__c];
if (c > 0) { delete [SELECT Id FROM Distributor_Stock__c]; System.debug('Deleted ' + c + ' Distributor_Stock__c'); }

c = [SELECT COUNT() FROM Warehouse_Stock__c];
if (c > 0) { delete [SELECT Id FROM Warehouse_Stock__c]; System.debug('Deleted ' + c + ' Warehouse_Stock__c'); }

c = [SELECT COUNT() FROM Stock_Transfer__c];
if (c > 0) { delete [SELECT Id FROM Stock_Transfer__c]; System.debug('Deleted ' + c + ' Stock_Transfer__c'); }

c = [SELECT COUNT() FROM Warehouse__c];
if (c > 0) { delete [SELECT Id FROM Warehouse__c]; System.debug('Deleted ' + c + ' Warehouse__c'); }

// ── Accounts ─────────────────────────────────────────────
c = [SELECT COUNT() FROM Account];
if (c > 0) { delete [SELECT Id FROM Account]; System.debug('Deleted ' + c + ' Account'); }

// ── Expenses, Holidays, Leaves ───────────────────────────
c = [SELECT COUNT() FROM Expense__c];
if (c > 0) { delete [SELECT Id FROM Expense__c]; System.debug('Deleted ' + c + ' Expense__c'); }

c = [SELECT COUNT() FROM Holiday__c];
if (c > 0) { delete [SELECT Id FROM Holiday__c]; System.debug('Deleted ' + c + ' Holiday__c'); }

// ── Employees ────────────────────────────────────────────
c = [SELECT COUNT() FROM Employee__c];
if (c > 0) { delete [SELECT Id FROM Employee__c]; System.debug('Deleted ' + c + ' Employee__c'); }

// ── Territories ──────────────────────────────────────────
c = [SELECT COUNT() FROM Territory_Master__c];
if (c > 0) { delete [SELECT Id FROM Territory_Master__c]; System.debug('Deleted ' + c + ' Territory_Master__c'); }

System.debug('');
System.debug('═══════════════════════════════════════════');
System.debug('CLEANUP COMPLETE');
System.debug('═══════════════════════════════════════════');
System.debug('');
System.debug('Run seed scripts in order:');
System.debug('  sf apex run --file scripts/01_company_hierarchy.apex');
System.debug('  sf apex run --file scripts/02_territory_master.apex');
System.debug('  sf apex run --file scripts/03_product_category.apex');
System.debug('  sf apex run --file scripts/04_products.apex');
System.debug('  sf apex run --file scripts/05_batch_master.apex');
System.debug('  sf apex run --file scripts/06_tax_configuration.apex');
System.debug('  sf apex run --file scripts/07_price_list.apex');
System.debug('  sf apex run --file scripts/08_warehouse.apex');
System.debug('  sf apex run --file scripts/09_accounts.apex');
System.debug('  sf apex run --file scripts/10_beats_and_outlets.apex');
System.debug('  sf apex run --file scripts/11_schemes.apex');
System.debug('  sf apex run --file scripts/13_employees.apex');
System.debug('  sf apex run --file scripts/13_target_periods.apex');
System.debug('  sf apex run --file scripts/14_target_criteria_and_actuals.apex');
System.debug('  sf apex run --file scripts/13_incentive_slabs.apex');
System.debug('  sf apex run --file scripts/15_test_team.apex');
System.debug('  sf apex run --file scripts/16_leave_policies.apex');
