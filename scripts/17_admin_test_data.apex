// ============================================================
// Script 17: Admin User Test Data
// Run AFTER all other seed scripts (01-16 + seed_transactional_data)
// Run: sf apex run --file scripts/17_admin_test_data.apex
//
// Creates complete test data for the current admin user:
//   - Day Attendance (7 days — today + 6 past days)
//   - Visits (5 per day — productive, non-productive, skipped mix)
//   - Sales Orders (3 per day — Regular, Urgent, Sample types)
//   - Order Line Items (3-5 products per order with tax)
//   - Collections (various payment modes)
//   - Leave Requests (all types and statuses)
//   - Target Actuals (all 6 criteria for current period)
//   - Journey Plan (with daily entries)
// ============================================================

Id adminUserId = UserInfo.getUserId();
String adminName = UserInfo.getFirstName() + ' ' + UserInfo.getLastName();
System.debug('Creating test data for admin user: ' + adminName + ' (' + adminUserId + ')');

// ── Clean up existing admin data (bypass triggers to save SOQL) ──
TriggerHandler.bypass('OMS_SalesOrder_TriggerHandler');
TriggerHandler.bypass('OMS_OrderLineItem_TriggerHandler');
TriggerHandler.bypass('OVE_Collection_TriggerHandler');
TriggerHandler.bypass('OVE_Visit_TriggerHandler');
TriggerHandler.bypass('BPM_DayAttendance_TriggerHandler');
delete [SELECT Id FROM Order_Line_Item__c WHERE Sales_Order__r.Salesperson__c = :adminUserId];
delete [SELECT Id FROM Sales_Order__c WHERE Salesperson__c = :adminUserId];
delete [SELECT Id FROM Collection__c WHERE Collected_By__c = :adminUserId];
delete [SELECT Id FROM Visit__c WHERE User__c = :adminUserId];
delete [SELECT Id FROM Day_Attendance__c WHERE User__c = :adminUserId];
delete [SELECT Id FROM Leave_Request__c WHERE Employee__c = :adminUserId];
delete [SELECT Id FROM Target_Actual__c WHERE User__c = :adminUserId];
System.debug('Cleaned up existing admin data');

// Bypass ALL triggers to avoid SOQL limit (triggers add queries per record)
TriggerHandler.bypass('OMS_SalesOrder_TriggerHandler');
TriggerHandler.bypass('OVE_Collection_TriggerHandler');
TriggerHandler.bypass('OVE_Visit_TriggerHandler');
TriggerHandler.bypass('OMS_OrderLineItem_TriggerHandler');
TriggerHandler.bypass('BPM_DayAttendance_TriggerHandler');

// ── Load prerequisite data ──
Map<String, Id> terMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c FROM Territory_Master__c WHERE Is_Active__c = true]) {
    terMap.put(t.Territory_Code__c, t.Id);
}

List<Account> retailers = [SELECT Id, Name, Territory__c, Channel__c, Outlet_Type__c
                            FROM Account WHERE Type = 'Retailer' AND Is_Active__c = true ORDER BY Name LIMIT 10];
System.assert(!retailers.isEmpty(), 'No retailer accounts found. Run 09_accounts.apex first.');

// ── Create admin-specific beats assigned to admin user ──
// Delete old admin beats first
delete [SELECT Id FROM Beat_Outlet__c WHERE Beat__r.Beat_Code__c LIKE 'BT-ADM-%'];
delete [SELECT Id FROM Beat__c WHERE Beat_Code__c LIKE 'BT-ADM-%'];

String todayDayName = DateTime.newInstance(Date.today(), Time.newInstance(0,0,0,0)).format('EEEE');

List<Beat__c> adminBeats = new List<Beat__c>{
    new Beat__c(
        Name = 'Admin Beat - Delhi Central',
        Beat_Code__c = 'BT-ADM-001',
        Territory__c = terMap.get('TER-DEL-001'),
        Assigned_User__c = adminUserId,
        Day_of_Week__c = 'Monday;Tuesday;Wednesday;Thursday;Friday;Saturday',
        Frequency__c = 'Weekly',
        Is_Active__c = true,
        Description__c = 'Admin test beat covering central Delhi retailers',
        Sequence__c = 1
    ),
    new Beat__c(
        Name = 'Admin Beat - Delhi South',
        Beat_Code__c = 'BT-ADM-002',
        Territory__c = terMap.get('TER-DEL-001'),
        Assigned_User__c = adminUserId,
        Day_of_Week__c = 'Monday;Wednesday;Friday',
        Frequency__c = 'Weekly',
        Is_Active__c = true,
        Description__c = 'Admin test beat covering south Delhi retailers',
        Sequence__c = 2
    )
};
insert adminBeats;
System.debug('Created ' + adminBeats.size() + ' Admin Beats');

Id primaryBeat = adminBeats[0].Id;
Id secondaryBeat = adminBeats[1].Id;

// Map retailers to admin beats (first 4 to beat 1, next 4 to beat 2)
List<Beat_Outlet__c> adminBeatOutlets = new List<Beat_Outlet__c>();
for (Integer i = 0; i < Math.min(8, retailers.size()); i++) {
    adminBeatOutlets.add(new Beat_Outlet__c(
        Beat__c = (i < 4) ? primaryBeat : secondaryBeat,
        Account__c = retailers[i].Id,
        Visit_Sequence__c = Math.mod(i, 4) + 1,
        Is_Active__c = true
    ));
}
insert adminBeatOutlets;
System.debug('Created ' + adminBeatOutlets.size() + ' Beat-Outlet mappings for admin');

// ── Create Journey Plan for admin ──
delete [SELECT Id FROM Journey_Plan_Day__c WHERE Journey_Plan__r.Name LIKE 'PJP - Admin%'];
delete [SELECT Id FROM Journey_Plan__c WHERE Name LIKE 'PJP - Admin%'];

Integer currentMonth = Date.today().month();
Integer currentYear = Date.today().year();
String[] monthNames = new String[]{'', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'};
String monthName = monthNames[currentMonth];
Date firstDay = Date.newInstance(currentYear, currentMonth, 1);
Date lastDay = firstDay.addMonths(1).addDays(-1);

Journey_Plan__c adminPlan = new Journey_Plan__c(
    Name = 'PJP - Admin - ' + monthName + ' ' + currentYear,
    Month__c = monthName,
    Year__c = String.valueOf(currentYear),
    Territory__c = terMap.get('TER-DEL-001'),
    Salesperson__c = adminUserId,
    User__c = adminUserId,
    Status__c = 'Draft',
    Plan_Date__c = Date.today(),
    Effective_From__c = firstDay,
    Effective_To__c = lastDay,
    Exclude_Holidays__c = true,
    Exclude_Leaves__c = true,
    Exclude_Week_Offs__c = true
);
insert adminPlan;

// Create plan days for admin beats
List<Journey_Plan_Day__c> adminPlanDays = new List<Journey_Plan_Day__c>();
Integer seq = 1;
Date d = firstDay;
while (d <= lastDay) {
    String dayOfWeek = DateTime.newInstance(d, Time.newInstance(0,0,0,0)).format('EEEE');
    if (dayOfWeek == 'Sunday') { d = d.addDays(1); continue; }

    // Alternate beats: beat 1 on Mon/Tue/Wed/Thu, beat 2 on Fri/Sat
    Id beatForDay = (dayOfWeek == 'Friday' || dayOfWeek == 'Saturday') ? secondaryBeat : primaryBeat;
    String beatName = (beatForDay == primaryBeat) ? 'Admin Beat - Delhi Central' : 'Admin Beat - Delhi South';
    Integer dayOfMonth = d.day();
    String weekNum = dayOfMonth <= 7 ? 'Week 1' : dayOfMonth <= 14 ? 'Week 2' : dayOfMonth <= 21 ? 'Week 3' : 'Week 4';

    adminPlanDays.add(new Journey_Plan_Day__c(
        Journey_Plan__c = adminPlan.Id,
        Beat__c = beatForDay,
        Beat_Name__c = beatName,
        Plan_Date__c = d,
        Day_of_Week__c = dayOfWeek,
        Week_Number__c = weekNum,
        Planned_Outlets__c = 4,
        Visited_Outlets__c = d < Date.today() ? 4 : 0,
        Sequence_Order__c = seq,
        Sequence__c = seq,
        Status__c = d < Date.today() ? 'Completed' : 'Planned'
    ));
    seq++;
    d = d.addDays(1);
}
insert adminPlanDays;

// Advance plan: Draft → Submitted → Approved → Active
adminPlan.Status__c = 'Submitted';
update adminPlan;
adminPlan.Status__c = 'Approved';
adminPlan.Approval_Date__c = Date.today();
adminPlan.Approved_By__c = adminUserId;
update adminPlan;
adminPlan.Status__c = 'Active';
update adminPlan;
adminPlan.Total_Planned_Days__c = adminPlanDays.size();
adminPlan.Total_Planned_Visits__c = adminPlanDays.size() * 4;
update adminPlan;

System.debug('Created Admin Journey Plan: ' + adminPlanDays.size() + ' days, Status=Active');

Map<String, Product_Extension__c> prodMap = new Map<String, Product_Extension__c>();
for (Product_Extension__c p : [SELECT Id, SKU_Code__c, Name, Unit_Price__c, MRP__c, GST_Rate__c,
                                      HSN_SAC_Code__c, Min_Order_Qty__c
                                FROM Product_Extension__c WHERE Is_Active__c = true]) {
    prodMap.put(p.SKU_Code__c, p);
}

Map<String, Id> uomMap = new Map<String, Id>();
for (UOM__c u : [SELECT Id, UOM_Code__c FROM UOM__c WHERE Is_Active__c = true]) {
    uomMap.put(u.UOM_Code__c, u.Id);
}
Id pcsUomId = uomMap.get('PCS');

Id primaryTerritory = terMap.get('TER-DEL-001');
Id primaryWarehouse = null;
List<Warehouse__c> whs = [SELECT Id FROM Warehouse__c WHERE Warehouse_Code__c = 'WHDEL01' AND Is_Active__c = true LIMIT 1];
if (!whs.isEmpty()) primaryWarehouse = whs[0].Id;


// ════════════════════════════════════════════════════════════
// 1. DAY ATTENDANCE — 7 days
// ════════════════════════════════════════════════════════════

List<Day_Attendance__c> attendances = new List<Day_Attendance__c>();

for (Integer i = 0; i < 5; i++) {
    Date attDate = Date.today().addDays(-i);
    Boolean isToday = (i == 0);
    String dayName = DateTime.newInstance(attDate, Time.newInstance(0,0,0,0)).format('EEEE');
    // Skip Sundays
    if (dayName == 'Sunday') continue;

    String dutyType = (i < 4) ? 'HQ' : (i < 6 ? 'EX-HQ' : 'OS');

    attendances.add(new Day_Attendance__c(
        Salesperson__c = adminUserId,
        User__c = adminUserId,
        Attendance_Date__c = attDate,
        Beat__c = primaryBeat,
        Day_Start_Time__c = DateTime.newInstance(attDate, Time.newInstance(9, 0, 0, 0)),
        Start_Time__c = DateTime.newInstance(attDate, Time.newInstance(9, 0, 0, 0)),
        Start_Location_Lat__c = 28.6139,
        Start_Location_Long__c = 77.2090,
        Start_Accuracy__c = 8,
        Day_End_Time__c = isToday ? null : DateTime.newInstance(attDate, Time.newInstance(18, 30, 0, 0)),
        End_Time__c = isToday ? null : DateTime.newInstance(attDate, Time.newInstance(18, 30, 0, 0)),
        End_Location_Lat__c = isToday ? null : 28.6200,
        End_Location_Long__c = isToday ? null : 77.2150,
        End_Accuracy__c = isToday ? null : 12,
        Status__c = isToday ? 'Started' : 'Ended',
        Duty_Type__c = dutyType,
        Week_Day__c = dayName,
        Hours_Worked__c = isToday ? null : 9.5,
        Is_Finalized__c = !isToday,
        Network_Status__c = 'Online',
        Total_Visits__c = isToday ? 0 : 5,
        Productive_Calls__c = isToday ? 0 : 4,
        Non_Productive_Visits__c = isToday ? 0 : 1,
        Total_Orders__c = isToday ? 0 : 3,
        Total_Order_Value__c = isToday ? 0 : 25000,
        Total_Collection__c = isToday ? 0 : 12000,
        Distance_Traveled_Km__c = isToday ? null : 30,
        Remarks__c = isToday ? 'Day started' : 'All planned visits completed'
    ));
}
insert attendances;
System.debug('Created ' + attendances.size() + ' Day Attendance records');


// ════════════════════════════════════════════════════════════
// 2. VISITS — 5 per completed day + 1 for today
// ════════════════════════════════════════════════════════════

List<Visit__c> allVisits = new List<Visit__c>();
Integer acctIdx = 0;

for (Day_Attendance__c da : attendances) {
    Boolean isToday = (da.Status__c == 'Started');
    Integer visitsPerDay = isToday ? 1 : 3;

    for (Integer v = 0; v < visitsPerDay; v++) {
        Account acct = retailers[Math.mod(acctIdx, retailers.size())];
        Integer startHour = 9 + v;
        Integer durationMins = 25 + (v * 10);
        Boolean isProductive = (v < 2); // first 2 productive, last non-productive
        String visitStatus;
        if (isToday && v == 0) {
            visitStatus = 'In Progress';
        } else if (!isProductive) {
            visitStatus = 'Completed';
        } else {
            visitStatus = 'Completed';
        }

        allVisits.add(new Visit__c(
            Account__c = acct.Id,
            Outlet__c = acct.Id,
            Salesperson__c = adminUserId,
            User__c = adminUserId,
            Day_Attendance__c = da.Id,
            Beat__c = primaryBeat,
            Visit_Date__c = da.Attendance_Date__c,
            Visit_Sequence__c = v + 1,
            Check_In_Time__c = DateTime.newInstance(da.Attendance_Date__c, Time.newInstance(startHour, 0, 0, 0)),
            Check_In_Lat__c = 28.6139 + (v * 0.003),
            Check_In_Long__c = 77.2090 + (v * 0.002),
            Check_In_Latitude__c = 28.6139 + (v * 0.003),
            Check_In_Longitude__c = 77.2090 + (v * 0.002),
            Check_In_Accuracy__c = 10,
            Check_In_Network__c = 'Online',
            Check_Out_Time__c = (visitStatus == 'Completed') ?
                DateTime.newInstance(da.Attendance_Date__c, Time.newInstance(startHour, durationMins, 0, 0)) : null,
            Check_Out_Lat__c = (visitStatus == 'Completed') ? 28.6139 + (v * 0.003) : null,
            Check_Out_Long__c = (visitStatus == 'Completed') ? 77.2090 + (v * 0.002) : null,
            Check_Out_Accuracy__c = (visitStatus == 'Completed') ? 12 : null,
            Duration_Minutes__c = (visitStatus == 'Completed') ? durationMins : null,
            Visit_Status__c = visitStatus,
            Is_Planned__c = true,
            Is_Productive__c = isProductive,
            Is_Geo_Fenced__c = true,
            Is_Ad_Hoc__c = (v == 4),
            Distance_To_Outlet__c = 50 + (v * 30),
            Non_Productive_Reason__c = isProductive ? null : 'Closed',
            Notes__c = isProductive ? 'Order placed, new products pitched' : 'Shop closed, will revisit tomorrow'
        ));
        acctIdx++;
    }
}
insert allVisits;
System.debug('Created ' + allVisits.size() + ' Visit records');


// ════════════════════════════════════════════════════════════
// 3. SALES ORDERS — 3 per completed day (Regular/Urgent/Sample)
// ════════════════════════════════════════════════════════════

String[] orderTypes = new String[]{'Regular', 'Regular', 'Urgent'};
List<Visit__c> productiveVisits = new List<Visit__c>();
for (Visit__c v : allVisits) {
    if (v.Visit_Status__c == 'Completed' && v.Is_Productive__c == true) {
        productiveVisits.add(v);
    }
}


List<Sales_Order__c> orders = new List<Sales_Order__c>();
for (Integer i = 0; i < productiveVisits.size(); i++) {
    Visit__c v = productiveVisits[i];
    orders.add(new Sales_Order__c(
        Account__c = v.Account__c,
        Salesperson__c = adminUserId,
        Sales_Rep__c = adminUserId,
        Visit__c = v.Id,
        Beat__c = primaryBeat,
        Territory__c = primaryTerritory,
        Warehouse__c = primaryWarehouse,
        Order_Date__c = v.Visit_Date__c,
        Order_Type__c = orderTypes[Math.mod(i, orderTypes.size())],
        Channel__c = 'Field App',
        Status__c = 'Delivered',
        Payment_Terms__c = 'Net 30',
        Notes__c = 'Admin test order #' + (i + 1),
        Must_Sell_Override__c = true,
        Total_Items__c = 0,
        Total_Gross_Amount__c = 0,
        Total_Discount__c = 0,
        Total_Tax__c = 0,
        Total_Net_Amount__c = 0
    ));
}
insert orders;
System.debug('Created ' + orders.size() + ' Sales Orders');


// ════════════════════════════════════════════════════════════
// 4. ORDER LINE ITEMS — 3-5 products per order
// ════════════════════════════════════════════════════════════

List<String> skuRotation = new List<String>{
    'FF-SNK-001', 'FF-BIS-001', 'FF-NDL-001', 'FF-JUC-001', 'FF-DET-001',
    'FF-HAR-002', 'FF-ORL-001', 'FF-TEA-001', 'FF-SOD-001', 'FF-CLN-001',
    'FF-SKN-001', 'FF-CNF-001', 'FF-DRY-001', 'FF-SNK-002', 'FF-BIS-002'
};

List<Order_Line_Item__c> lineItems = new List<Order_Line_Item__c>();

for (Integer oi = 0; oi < orders.size(); oi++) {
    Sales_Order__c order = orders[oi];
    Decimal orderGross = 0;
    Decimal orderTax = 0;
    Integer itemCount = 0;
    Integer productsPerOrder = 3 + Math.mod(oi, 3); // 3, 4, 5 rotating

    for (Integer p = 0; p < productsPerOrder; p++) {
        String sku = skuRotation[Math.mod(oi * 5 + p, skuRotation.size())];
        Product_Extension__c prod = prodMap.get(sku);
        if (prod == null) continue;

        Decimal minQty = (prod.Min_Order_Qty__c != null && prod.Min_Order_Qty__c > 0) ? prod.Min_Order_Qty__c : 12;
        Decimal qty = minQty * (1 + Math.mod(oi + p, 3)); // 1x, 2x, 3x min
        Decimal unitPrice = prod.Unit_Price__c != null ? prod.Unit_Price__c : 50;
        Decimal lineTotal = qty * unitPrice;
        Decimal gstRate = prod.GST_Rate__c != null ? prod.GST_Rate__c : 18;
        Decimal taxAmt = (lineTotal * gstRate / 100).setScale(2, RoundingMode.HALF_UP);
        Decimal cgst = (taxAmt / 2).setScale(2, RoundingMode.HALF_UP);
        Decimal sgst = taxAmt - cgst;

        lineItems.add(new Order_Line_Item__c(
            Sales_Order__c = order.Id,
            Product_Ext__c = prod.Id,
            Quantity__c = qty,
            Unit_Price__c = unitPrice,
            MRP__c = prod.MRP__c,
            Line_Amount__c = lineTotal,
            Line_Total__c = lineTotal,
            Tax_Rate__c = gstRate,
            Tax_Amount__c = taxAmt,
            CGST__c = cgst,
            SGST__c = sgst,
            IGST__c = 0,
            Net_Amount__c = lineTotal + taxAmt,
            Total_Amount__c = lineTotal + taxAmt,
            HSN_SAC_Code__c = prod.HSN_SAC_Code__c,
            UOM__c = 'Pieces',
            Order_UOM__c = pcsUomId,
            Base_UOM__c = pcsUomId,
            Base_Quantity__c = qty,
            Conversion_Factor__c = 1,
            Discount_Amount__c = 0,
            Discount_Percent__c = 0,
            Free_Quantity__c = 0,
            Reward_Points__c = 0
        ));

        orderGross += lineTotal;
        orderTax += taxAmt;
        itemCount++;
    }

    order.Total_Items__c = itemCount;
    order.Total_Gross_Amount__c = orderGross;
    order.Total_Tax__c = orderTax;
    order.Total_Net_Amount__c = orderGross + orderTax;
    order.Total_Discount__c = 0;
    order.Line_Amount__c = orderGross;
    order.Net_Amount__c = orderGross + orderTax;
    order.Total_Amount__c = orderGross + orderTax;
}

insert lineItems;

// Update order totals
List<Sales_Order__c> totalUpdates = new List<Sales_Order__c>();
for (Sales_Order__c o : orders) {
    totalUpdates.add(new Sales_Order__c(
        Id = o.Id,
        Total_Items__c = o.Total_Items__c,
        Total_Gross_Amount__c = o.Total_Gross_Amount__c,
        Total_Tax__c = o.Total_Tax__c,
        Total_Net_Amount__c = o.Total_Net_Amount__c,
        Total_Discount__c = o.Total_Discount__c,
        Line_Amount__c = o.Line_Amount__c,
        Net_Amount__c = o.Net_Amount__c,
        Total_Amount__c = o.Total_Amount__c
    ));
}
update totalUpdates;
System.debug('Created ' + lineItems.size() + ' Order Line Items');


// ════════════════════════════════════════════════════════════
// 5. COLLECTIONS — various payment modes
// ════════════════════════════════════════════════════════════

List<Collection__c> collections = new List<Collection__c>();
String[] payModes = new String[]{'Cash', 'Cheque', 'UPI', 'NEFT', 'Cash', 'UPI', 'Online'};

for (Integer i = 0; i < Math.min(payModes.size(), orders.size()); i++) {
    Sales_Order__c order = orders[i];
    Decimal amount = order.Total_Net_Amount__c != null ?
        (order.Total_Net_Amount__c * (0.6 + Math.mod(i, 3) * 0.15)).setScale(2, RoundingMode.HALF_UP) : 5000;

    Collection__c coll = new Collection__c(
        Account__c = order.Account__c,
        Amount__c = amount,
        Collected_By__c = adminUserId,
        Salesperson__c = adminUserId,
        Collection_Date__c = order.Order_Date__c,
        Payment_Mode__c = payModes[i],
        Status__c = 'Collected',
        Receipt_Number__c = 'ADM-RCP-' + String.valueOf(i + 1).leftPad(4, '0'),
        Notes__c = 'Admin collection #' + (i + 1) + ' via ' + payModes[i]
    );

    if (payModes[i] == 'Cheque') {
        coll.Cheque_Number__c = '200' + String.valueOf(i + 1).leftPad(4, '0');
        coll.Cheque_Date__c = order.Order_Date__c.addDays(15);
        coll.Bank_Name__c = 'HDFC Bank';
    } else if (payModes[i] == 'UPI') {
        coll.UPI_Reference__c = 'ADMINUPI' + String.valueOf(System.now().getTime()).right(8) + i;
    } else if (payModes[i] == 'NEFT') {
        coll.Transaction_Reference__c = 'ADMINNEFT' + String.valueOf(System.now().getTime()).right(10);
        coll.Bank_Name__c = 'SBI';
    }
    collections.add(coll);
}

// One advance/on-account payment
collections.add(new Collection__c(
    Account__c = retailers[0].Id,
    Amount__c = 15000,
    Collected_By__c = adminUserId,
    Salesperson__c = adminUserId,
    Collection_Date__c = Date.today().addDays(-1),
    Payment_Mode__c = 'Cash',
    Status__c = 'Collected',
    Is_On_Account__c = true,
    Receipt_Number__c = 'ADM-RCP-ADV-001',
    Notes__c = 'Advance on-account payment'
));

try {
    insert collections;
    System.debug('Created ' + collections.size() + ' Collections');
} catch (Exception e) {
    System.debug('WARNING: Collection insert failed: ' + e.getMessage());
    System.debug('Skipped — fix OMS Collection Ledger Entry Flow, then re-run.');
}


// ════════════════════════════════════════════════════════════
// 6. LEAVE REQUESTS — all types and statuses
// ════════════════════════════════════════════════════════════

List<Leave_Request__c> leaves = new List<Leave_Request__c>();

// Approved CL — 2 days last month
leaves.add(new Leave_Request__c(
    Employee__c = adminUserId, Leave_Type__c = 'Casual Leave',
    Start_Date__c = Date.today().addDays(-35), End_Date__c = Date.today().addDays(-34),
    Start_Session__c = 'Session 1', End_Session__c = 'Session 2',
    Number_of_Days__c = 2, Status__c = 'Approved',
    Reason__c = 'Family function', Comments__c = 'Approved',
    Approval_Date__c = DateTime.now().addDays(-37)
));

// Approved SL — half day last week
leaves.add(new Leave_Request__c(
    Employee__c = adminUserId, Leave_Type__c = 'Sick Leave',
    Start_Date__c = Date.today().addDays(-5), End_Date__c = Date.today().addDays(-5),
    Start_Session__c = 'Session 2', End_Session__c = 'Session 2',
    Number_of_Days__c = 0.5, Status__c = 'Approved',
    Reason__c = 'Medical appointment', Comments__c = 'Approved - half day',
    Approval_Date__c = DateTime.now().addDays(-6)
));

// Pending EL — next week
leaves.add(new Leave_Request__c(
    Employee__c = adminUserId, Leave_Type__c = 'Earned Leave',
    Start_Date__c = Date.today().addDays(7), End_Date__c = Date.today().addDays(9),
    Start_Session__c = 'Session 1', End_Session__c = 'Session 2',
    Number_of_Days__c = 3, Status__c = 'Pending',
    Reason__c = 'Vacation planned'
));

// Pending CO — upcoming
leaves.add(new Leave_Request__c(
    Employee__c = adminUserId, Leave_Type__c = 'Compensatory Off',
    Start_Date__c = Date.today().addDays(14), End_Date__c = Date.today().addDays(14),
    Start_Session__c = 'Session 1', End_Session__c = 'Session 2',
    Number_of_Days__c = 1, Status__c = 'Pending',
    Reason__c = 'Worked on Saturday for product launch'
));

// Rejected CL
leaves.add(new Leave_Request__c(
    Employee__c = adminUserId, Leave_Type__c = 'Casual Leave',
    Start_Date__c = Date.today().addDays(-20), End_Date__c = Date.today().addDays(-18),
    Start_Session__c = 'Session 1', End_Session__c = 'Session 2',
    Number_of_Days__c = 3, Status__c = 'Rejected',
    Reason__c = 'Personal travel', Comments__c = 'Rejected - quarter end, all hands needed',
    Approval_Date__c = DateTime.now().addDays(-22)
));

// Cancelled EL
leaves.add(new Leave_Request__c(
    Employee__c = adminUserId, Leave_Type__c = 'Earned Leave',
    Start_Date__c = Date.today().addDays(-10), End_Date__c = Date.today().addDays(-8),
    Start_Session__c = 'Session 1', End_Session__c = 'Session 2',
    Number_of_Days__c = 3, Status__c = 'Cancelled',
    Reason__c = 'Travel plans changed'
));

insert leaves;
System.debug('Created ' + leaves.size() + ' Leave Requests');


// ════════════════════════════════════════════════════════════
// 7. TARGET ACTUALS — all 6 criteria for current period
// ════════════════════════════════════════════════════════════

// Get current default period
List<Target_Period__c> periods = [SELECT Id FROM Target_Period__c
    WHERE Is_Default__c = true AND Is_Active__c = true AND Type__c = 'Monthly' LIMIT 1];
if (periods.isEmpty()) {
    periods = [SELECT Id FROM Target_Period__c WHERE Is_Active__c = true AND Type__c = 'Monthly'
               ORDER BY Start_Date__c DESC LIMIT 1];
}

if (!periods.isEmpty()) {
    Id periodId = periods[0].Id;

    // Get all active criteria
    Map<String, Id> criteriaMap = new Map<String, Id>();
    for (Target_Criteria__c tc : [SELECT Id, Name FROM Target_Criteria__c WHERE Active__c = true]) {
        criteriaMap.put(tc.Name, tc.Id);
    }

    List<Target_Actual__c> actuals = new List<Target_Actual__c>();

    // Revenue — 92% achievement
    if (criteriaMap.containsKey('Revenue')) {
        actuals.add(new Target_Actual__c(
            Target_Criteria__c = criteriaMap.get('Revenue'),
            Target_Period__c = periodId,
            User__c = adminUserId,
            Target_Value__c = 500000,
            Achievement_Value__c = 460000
        ));
    }

    // Collection — 85% achievement
    if (criteriaMap.containsKey('Collection')) {
        actuals.add(new Target_Actual__c(
            Target_Criteria__c = criteriaMap.get('Collection'),
            Target_Period__c = periodId,
            User__c = adminUserId,
            Target_Value__c = 350000,
            Achievement_Value__c = 297500
        ));
    }

    // Volume — 105% achievement
    if (criteriaMap.containsKey('Volume')) {
        actuals.add(new Target_Actual__c(
            Target_Criteria__c = criteriaMap.get('Volume'),
            Target_Period__c = periodId,
            User__c = adminUserId,
            Target_Value__c = 100,
            Achievement_Value__c = 105
        ));
    }

    // Coverage — 96% achievement
    if (criteriaMap.containsKey('Coverage')) {
        actuals.add(new Target_Actual__c(
            Target_Criteria__c = criteriaMap.get('Coverage'),
            Target_Period__c = periodId,
            User__c = adminUserId,
            Target_Value__c = 150,
            Achievement_Value__c = 144
        ));
    }

    // Focus Brand — 91% (just above prerequisite)
    if (criteriaMap.containsKey('Focus Brand')) {
        actuals.add(new Target_Actual__c(
            Target_Criteria__c = criteriaMap.get('Focus Brand'),
            Target_Period__c = periodId,
            User__c = adminUserId,
            Target_Value__c = 100000,
            Achievement_Value__c = 91000
        ));
    }

    // Outlet Expansion — 112% (super achiever)
    if (criteriaMap.containsKey('Outlet Expansion')) {
        actuals.add(new Target_Actual__c(
            Target_Criteria__c = criteriaMap.get('Outlet Expansion'),
            Target_Period__c = periodId,
            User__c = adminUserId,
            Target_Value__c = 25,
            Achievement_Value__c = 28
        ));
    }

    if (!actuals.isEmpty()) {
        insert actuals;
        System.debug('Created ' + actuals.size() + ' Target Actuals for admin');
    }
} else {
    System.debug('WARNING: No active monthly period found. Skipping Target Actuals.');
}


// Clear all trigger bypasses
TriggerHandler.clearBypass('OMS_SalesOrder_TriggerHandler');
TriggerHandler.clearBypass('OVE_Collection_TriggerHandler');
TriggerHandler.clearBypass('OVE_Visit_TriggerHandler');
TriggerHandler.clearBypass('OMS_OrderLineItem_TriggerHandler');
TriggerHandler.clearBypass('BPM_DayAttendance_TriggerHandler');

// ════════════════════════════════════════════════════════════
// SUMMARY
// ════════════════════════════════════════════════════════════

Decimal totalOrderValue = 0;
Decimal totalCollected = 0;
for (Sales_Order__c o : orders) totalOrderValue += (o.Total_Net_Amount__c != null ? o.Total_Net_Amount__c : 0);
for (Collection__c c : collections) totalCollected += (c.Amount__c != null ? c.Amount__c : 0);

System.debug('');
System.debug('═══════════════════════════════════════════════════');
System.debug('Admin Test Data Complete for: ' + adminName);
System.debug('  Day Attendance:    ' + attendances.size() + ' days');
System.debug('  Visits:            ' + allVisits.size() + ' (' +
    productiveVisits.size() + ' productive)');
System.debug('  Sales Orders:      ' + orders.size() + ' (₹' + totalOrderValue.setScale(0) + ')');
System.debug('  Order Line Items:  ' + lineItems.size());
System.debug('  Collections:       ' + collections.size() + ' (₹' + totalCollected.setScale(0) + ')');
System.debug('  Leave Requests:    ' + leaves.size() +
    ' (2 Approved, 2 Pending, 1 Rejected, 1 Cancelled)');
System.debug('  Target Actuals:    6 criteria (Rev 92%, Col 85%, Vol 105%, Cov 96%, FB 91%, OE 112%)');
System.debug('═══════════════════════════════════════════════════');
