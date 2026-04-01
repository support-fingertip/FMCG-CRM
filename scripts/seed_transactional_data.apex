// ============================================================
// Seed Script: Transactional Data for Test/Demo
// Run AFTER all master/config scripts (01-16)
// Run: sf apex run --file scripts/seed_transactional_data.apex
//
// Creates: Day Attendance, Visits, Sales Orders, Order Line Items, Collections
// Uses existing accounts, products, territories, beats from seed data
// ============================================================

// ── Clean up existing transactional data (children first) ──
delete [SELECT Id FROM Order_Line_Item__c];
delete [SELECT Id FROM Collection__c];
delete [SELECT Id FROM Sales_Order__c];
delete [SELECT Id FROM Visit__c];
delete [SELECT Id FROM Day_Attendance__c];
System.debug('Cleaned up transactional data');

// ── Load prerequisite data ──
Map<String, Id> terMap = new Map<String, Id>();
for (Territory_Master__c t : [SELECT Id, Territory_Code__c FROM Territory_Master__c WHERE Is_Active__c = true]) {
    terMap.put(t.Territory_Code__c, t.Id);
}

Map<String, Account> acctMap = new Map<String, Account>();
for (Account a : [SELECT Id, Name, Territory__c, Channel__c, Outlet_Type__c, Type FROM Account WHERE Is_Active__c = true]) {
    acctMap.put(a.Name, a);
}

Map<String, Id> beatMap = new Map<String, Id>();
for (Beat__c b : [SELECT Id, Beat_Code__c, Territory__c FROM Beat__c WHERE Is_Active__c = true]) {
    beatMap.put(b.Beat_Code__c, b.Id);
}

Map<String, Product_Extension__c> prodMap = new Map<String, Product_Extension__c>();
for (Product_Extension__c p : [SELECT Id, SKU_Code__c, Name, Unit_Price__c, MRP__c, GST_Rate__c, HSN_SAC_Code__c, Case_Size__c, Min_Order_Qty__c
                                FROM Product_Extension__c WHERE Is_Active__c = true]) {
    prodMap.put(p.SKU_Code__c, p);
}

Map<String, Id> uomMap = new Map<String, Id>();
for (UOM__c u : [SELECT Id, UOM_Code__c FROM UOM__c WHERE Is_Active__c = true]) {
    uomMap.put(u.UOM_Code__c, u.Id);
}

Map<String, Id> warehouseMap = new Map<String, Id>();
for (Warehouse__c w : [SELECT Id, Warehouse_Code__c FROM Warehouse__c WHERE Is_Active__c = true]) {
    warehouseMap.put(w.Warehouse_Code__c, w.Id);
}

Id currentUser = UserInfo.getUserId();

// ── Accounts to use (pick 6 retailers from seed data) ──
List<String> retailerNames = new List<String>{
    'Lakshmi General Store', 'Ganesh Provision Store', 'Kumar Kirana',
    'Deepak Grocery', 'Gupta Mart', 'Sri Balaji Store'
};

// ════════════════════════════════════════════════════════════
// 1. DAY ATTENDANCE — 5 days of attendance
// ════════════════════════════════════════════════════════════

List<Day_Attendance__c> attendances = new List<Day_Attendance__c>();
Id delhiBeat = beatMap.get('BT-DEL-001');

for (Integer i = 0; i < 5; i++) {
    Date attDate = Date.today().addDays(-i);
    Boolean isToday = (i == 0);
    String dayName = DateTime.newInstance(attDate, Time.newInstance(0,0,0,0)).format('EEEE');

    attendances.add(new Day_Attendance__c(
        Salesperson__c = currentUser,
        User__c = currentUser,
        Attendance_Date__c = attDate,
        Beat__c = delhiBeat,
        Day_Start_Time__c = DateTime.newInstance(attDate, Time.newInstance(9, 0, 0, 0)),
        Start_Time__c = DateTime.newInstance(attDate, Time.newInstance(9, 0, 0, 0)),
        Start_Location_Lat__c = 28.6139,
        Start_Location_Long__c = 77.2090,
        Start_Accuracy__c = 10,
        Day_End_Time__c = isToday ? null : DateTime.newInstance(attDate, Time.newInstance(18, 30, 0, 0)),
        End_Time__c = isToday ? null : DateTime.newInstance(attDate, Time.newInstance(18, 30, 0, 0)),
        End_Location_Lat__c = isToday ? null : 28.6200,
        End_Location_Long__c = isToday ? null : 77.2150,
        End_Accuracy__c = isToday ? null : 15,
        Status__c = isToday ? 'Started' : 'Ended',
        Duty_Type__c = 'HQ',
        Week_Day__c = dayName,
        Hours_Worked__c = isToday ? null : 9.5,
        Is_Finalized__c = !isToday,
        Network_Status__c = 'Online',
        Total_Visits__c = isToday ? 0 : 4,
        Productive_Calls__c = isToday ? 0 : 3,
        Non_Productive_Visits__c = isToday ? 0 : 1,
        Total_Orders__c = isToday ? 0 : 2,
        Total_Order_Value__c = isToday ? 0 : 15000,
        Total_Collection__c = isToday ? 0 : 8000,
        Distance_Traveled_Km__c = isToday ? null : 25,
        Remarks__c = isToday ? 'Day in progress' : 'Completed all planned visits'
    ));
}
insert attendances;
System.debug('Created ' + attendances.size() + ' Day Attendance records');


// ════════════════════════════════════════════════════════════
// 2. VISITS — 4 visits per completed day + 1 for today
// ════════════════════════════════════════════════════════════

List<Visit__c> visits = new List<Visit__c>();
Integer visitIdx = 0;

for (Day_Attendance__c da : attendances) {
    Boolean isToday = (da.Status__c == 'Started');
    Integer visitsPerDay = isToday ? 1 : 4;

    for (Integer v = 0; v < visitsPerDay; v++) {
        String acctName = retailerNames[Math.mod(visitIdx, retailerNames.size())];
        Account acct = acctMap.get(acctName);
        if (acct == null) continue;

        Integer startHour = 10 + v;
        Integer durationMins = 30 + (v * 5);
        Boolean isProductive = (v < 3); // first 3 productive, last non-productive
        String visitStatus = isToday && v == 0 ? 'In Progress' : 'Completed';

        Visit__c vis = new Visit__c(
            Account__c = acct.Id,
            Outlet__c = acct.Id,
            Salesperson__c = currentUser,
            User__c = currentUser,
            Day_Attendance__c = da.Id,
            Beat__c = delhiBeat,
            Visit_Date__c = da.Attendance_Date__c,
            Visit_Sequence__c = v + 1,
            Check_In_Time__c = DateTime.newInstance(da.Attendance_Date__c, Time.newInstance(startHour, 0, 0, 0)),
            Check_In_Lat__c = 28.6139 + (v * 0.005),
            Check_In_Long__c = 77.2090 + (v * 0.003),
            Check_In_Latitude__c = 28.6139 + (v * 0.005),
            Check_In_Longitude__c = 77.2090 + (v * 0.003),
            Check_In_Accuracy__c = 10,
            Check_In_Network__c = 'Online',
            Check_Out_Time__c = visitStatus == 'Completed' ?
                DateTime.newInstance(da.Attendance_Date__c, Time.newInstance(startHour, durationMins, 0, 0)) : null,
            Check_Out_Lat__c = visitStatus == 'Completed' ? 28.6139 + (v * 0.005) : null,
            Check_Out_Long__c = visitStatus == 'Completed' ? 77.2090 + (v * 0.003) : null,
            Check_Out_Accuracy__c = visitStatus == 'Completed' ? 12 : null,
            Duration_Minutes__c = visitStatus == 'Completed' ? durationMins : null,
            Visit_Status__c = visitStatus,
            Is_Planned__c = true,
            Is_Productive__c = isProductive,
            Is_Geo_Fenced__c = true,
            Is_Ad_Hoc__c = false,
            Distance_To_Outlet__c = 50 + (v * 20),
            Non_Productive_Reason__c = isProductive ? null : 'Closed',
            Notes__c = isProductive ? 'Order taken, new products introduced' : 'Shop was closed, will revisit'
        );
        visits.add(vis);
        visitIdx++;
    }
}
insert visits;
System.debug('Created ' + visits.size() + ' Visit records');


// ════════════════════════════════════════════════════════════
// 3. SALES ORDERS — 1 per productive completed visit
// ════════════════════════════════════════════════════════════

Id delWarehouse = warehouseMap.get('WHDEL01');
List<Sales_Order__c> orders = new List<Sales_Order__c>();

for (Visit__c v : visits) {
    if (v.Visit_Status__c != 'Completed' || v.Is_Productive__c != true) continue;

    Account acct = null;
    for (Account a : acctMap.values()) {
        if (a.Id == v.Account__c) { acct = a; break; }
    }

    orders.add(new Sales_Order__c(
        Account__c = v.Account__c,
        Salesperson__c = currentUser,
        Sales_Rep__c = currentUser,
        Visit__c = v.Id,
        Beat__c = delhiBeat,
        Territory__c = terMap.get('TER-DEL-001'),
        Warehouse__c = delWarehouse,
        Order_Date__c = v.Visit_Date__c,
        Order_Type__c = 'Regular',
        Channel__c = 'Field App',
        Status__c = 'Delivered',
        Payment_Terms__c = 'Net 30',
        Notes__c = 'Order placed during field visit',
        Must_Sell_Compliance__c = 80,
        Total_Items__c = 0,
        Total_Gross_Amount__c = 0,
        Total_Discount__c = 0,
        Total_Tax__c = 0,
        Total_Net_Amount__c = 0
    ));
}
// Bypass all order triggers/validations for seed data insert
TriggerHandler.bypass('OMS_SalesOrder_TriggerHandler');
insert orders;
TriggerHandler.clearBypass('OMS_SalesOrder_TriggerHandler');
System.debug('Created ' + orders.size() + ' Sales Order records');


// ════════════════════════════════════════════════════════════
// 4. ORDER LINE ITEMS — 3-4 products per order
// ════════════════════════════════════════════════════════════

// Products to use in orders (mix from all categories)
List<String> orderSkus = new List<String>{
    'FF-SNK-001', 'FF-BIS-001', 'FF-NDL-001', 'FF-JUC-001',
    'FF-DET-001', 'FF-HAR-002', 'FF-ORL-001', 'FF-TEA-001',
    'FF-SOD-001', 'FF-CLN-001', 'FF-SKN-001', 'FF-CNF-001'
};

List<Order_Line_Item__c> lineItems = new List<Order_Line_Item__c>();
Integer orderIdx = 0;

for (Sales_Order__c order : orders) {
    Decimal orderGross = 0;
    Decimal orderTax = 0;
    Integer itemCount = 0;

    // 3-4 different products per order
    Integer productsInOrder = 3 + Math.mod(orderIdx, 2);
    for (Integer p = 0; p < productsInOrder; p++) {
        String sku = orderSkus[Math.mod(orderIdx * 4 + p, orderSkus.size())];
        Product_Extension__c prod = prodMap.get(sku);
        if (prod == null) continue;

        Decimal minQty = (prod.Min_Order_Qty__c != null && prod.Min_Order_Qty__c > 0) ? prod.Min_Order_Qty__c : 12;
        Decimal qty = minQty + (Math.mod(orderIdx + p, 4) * minQty); // 1x, 2x, 3x, 4x of min qty
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
            Order_UOM__c = uomMap.get('PCS'),
            Base_UOM__c = uomMap.get('PCS'),
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

    // Update order totals
    order.Total_Items__c = itemCount;
    order.Total_Gross_Amount__c = orderGross;
    order.Total_Tax__c = orderTax;
    order.Total_Net_Amount__c = orderGross + orderTax;
    order.Total_Discount__c = 0;
    order.Line_Amount__c = orderGross;
    order.Net_Amount__c = orderGross + orderTax;
    order.Total_Amount__c = orderGross + orderTax;
    orderIdx++;
}

insert lineItems;

// Update order totals only (don't touch Status — triggers may have advanced it)
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
TriggerHandler.bypass('OMS_SalesOrder_TriggerHandler');
update totalUpdates;
TriggerHandler.clearBypass('OMS_SalesOrder_TriggerHandler');

System.debug('Created ' + lineItems.size() + ' Order Line Items (orders inserted as Delivered)');


// ════════════════════════════════════════════════════════════
// 5. COLLECTIONS — payment against some orders
// ════════════════════════════════════════════════════════════

List<Collection__c> collections = new List<Collection__c>();
Integer collIdx = 0;

// Collect payment for first 6 orders (mix of payment modes)
String[] paymentModes = new String[]{'Cash', 'Cheque', 'UPI', 'NEFT', 'Cash', 'UPI'};

for (Integer i = 0; i < Math.min(6, orders.size()); i++) {
    Sales_Order__c order = orders[i];
    Decimal collectionAmt = order.Total_Net_Amount__c != null ?
        (order.Total_Net_Amount__c * (0.5 + Math.mod(i, 3) * 0.25)).setScale(2, RoundingMode.HALF_UP) : 5000;

    Visit__c matchingVisit = null;
    for (Visit__c v : visits) {
        if (v.Id == order.Visit__c) { matchingVisit = v; break; }
    }

    Collection__c coll = new Collection__c(
        Account__c = order.Account__c,
        Amount__c = collectionAmt,
        Collected_By__c = currentUser,
        Salesperson__c = currentUser,
        Collection_Date__c = order.Order_Date__c,
        Payment_Mode__c = paymentModes[i],
        Status__c = 'Collected',
        Visit__c = matchingVisit != null ? matchingVisit.Id : null,
        Receipt_Number__c = 'RCP-2026-' + String.valueOf(i + 1).leftPad(4, '0'),
        Notes__c = 'Payment against order'
    );

    // Add payment-mode-specific fields
    if (paymentModes[i] == 'Cheque') {
        coll.Cheque_Number__c = '100' + String.valueOf(i + 1).leftPad(4, '0');
        coll.Cheque_Date__c = order.Order_Date__c.addDays(7);
        coll.Bank_Name__c = 'State Bank of India';
    } else if (paymentModes[i] == 'UPI') {
        coll.UPI_Reference__c = 'UPI' + String.valueOf(System.now().getTime()).right(10);
    } else if (paymentModes[i] == 'NEFT') {
        coll.Transaction_Reference__c = 'NEFT' + String.valueOf(System.now().getTime()).right(12);
        coll.Bank_Name__c = 'HDFC Bank';
    }

    collections.add(coll);
}

// Add one on-account payment (not tied to a specific order)
collections.add(new Collection__c(
    Account__c = acctMap.values().iterator().next().Id,
    Amount__c = 10000,
    Collected_By__c = currentUser,
    Salesperson__c = currentUser,
    Collection_Date__c = Date.today().addDays(-2),
    Payment_Mode__c = 'Cash',
    Status__c = 'Collected',
    Is_On_Account__c = true,
    Receipt_Number__c = 'RCP-2026-ADV-001',
    Notes__c = 'Advance payment on account'
));

// NOTE: Collection insert uses try-catch because the 'OMS - Collection Ledger Entry' Flow
// may fail if Ledger_Entry__c.Entry_Type__c picklist doesn't include 'Credit'/'Debit'.
// TriggerHandler.bypass only skips Apex triggers, not Flows.
TriggerHandler.bypass('OVE_Collection_TriggerHandler');
try {
    insert collections;
    System.debug('Created ' + collections.size() + ' Collection records');
} catch (Exception e) {
    System.debug('WARNING: Collection insert failed (likely Flow issue): ' + e.getMessage());
    System.debug('Collections skipped — fix the OMS Collection Ledger Entry Flow or Ledger_Entry__c.Entry_Type__c picklist, then re-run.');
}
TriggerHandler.clearBypass('OVE_Collection_TriggerHandler');


// ════════════════════════════════════════════════════════════
// SUMMARY
// ════════════════════════════════════════════════════════════

Decimal totalOrderValue = 0;
Decimal totalCollected = 0;
for (Sales_Order__c o : orders) totalOrderValue += (o.Total_Net_Amount__c != null ? o.Total_Net_Amount__c : 0);
for (Collection__c c : collections) totalCollected += (c.Amount__c != null ? c.Amount__c : 0);

System.debug('');
System.debug('═══════════════════════════════════════════');
System.debug('Transactional Seed Data Complete:');
System.debug('  Day Attendance:    ' + attendances.size());
System.debug('  Visits:            ' + visits.size() + ' (' + [SELECT COUNT() FROM Visit__c WHERE Is_Productive__c = true] + ' productive)');
System.debug('  Sales Orders:      ' + orders.size() + ' (Total: ₹' + totalOrderValue.setScale(0) + ')');
System.debug('  Order Line Items:  ' + lineItems.size());
System.debug('  Collections:       ' + collections.size() + ' (Total: ₹' + totalCollected.setScale(0) + ')');
System.debug('');
System.debug('Payment Modes: Cash, Cheque, UPI, NEFT, On-Account');
System.debug('═══════════════════════════════════════════');
