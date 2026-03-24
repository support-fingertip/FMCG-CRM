/**
 * Seed Script: Transactional Data for Test/Demo Environments
 * Creates sample Orders, Visits, Day Attendance, and Collections
 * Run via: Execute Anonymous in Developer Console
 */

// ── Prerequisites: Ensure accounts, products, territories, beats exist ──

// Get or create test account
List<Account> accounts = [SELECT Id FROM Account WHERE Type = 'Retailer' LIMIT 1];
if (accounts.isEmpty()) {
    Account acc = new Account(
        Name = 'Demo Retailer',
        Type = 'Retailer',
        BillingCity = 'Mumbai',
        BillingState = 'Maharashtra',
        BillingCountry = 'India',
        Credit_Limit__c = 500000,
        Credit_Utilized__c = 0
    );
    insert acc;
    accounts.add(acc);
}
Id accountId = accounts[0].Id;

// Get or create test product
List<Product_Extension__c> products = [SELECT Id FROM Product_Extension__c WHERE Is_Active__c = true LIMIT 5];
if (products.isEmpty()) {
    products = new List<Product_Extension__c>();
    for (Integer i = 1; i <= 5; i++) {
        products.add(new Product_Extension__c(
            Name = 'Demo Product ' + i,
            SKU_Code__c = 'DEMO-' + String.valueOf(i).leftPad(4, '0'),
            Is_Active__c = true
        ));
    }
    insert products;
}

// Get or create beat
List<Beat__c> beats = [SELECT Id FROM Beat__c WHERE Is_Active__c = true LIMIT 1];
if (beats.isEmpty()) {
    List<Territory_Master__c> territories = [SELECT Id FROM Territory_Master__c LIMIT 1];
    if (territories.isEmpty()) {
        Territory_Master__c t = new Territory_Master__c(
            Name = 'Demo Territory',
            Territory_Code__c = 'DEMO-TER-001',
            State__c = 'Maharashtra',
            City__c = 'Mumbai',
            Is_Active__c = true
        );
        insert t;
        territories.add(t);
    }
    Beat__c beat = new Beat__c(
        Name = 'Demo Beat',
        Beat_Code__c = 'DEMO-BEAT-001',
        Territory__c = territories[0].Id,
        Is_Active__c = true,
        Frequency__c = 'Weekly'
    );
    insert beat;
    beats.add(beat);
}
Id beatId = beats[0].Id;

// ── Create Day Attendance records ──
List<Day_Attendance__c> attendances = new List<Day_Attendance__c>();
for (Integer i = 0; i < 5; i++) {
    Date attDate = Date.today().addDays(-i);
    attendances.add(new Day_Attendance__c(
        Salesperson__c = UserInfo.getUserId(),
        Attendance_Date__c = attDate,
        Day_Start_Time__c = DateTime.newInstance(attDate, Time.newInstance(9, 0, 0, 0)),
        Start_Location_Lat__c = 19.0760,
        Start_Location_Long__c = 72.8777,
        Status__c = i == 0 ? 'Started' : 'Completed',
        Total_Visits__c = 0,
        Productive_Calls__c = 0,
        Total_Orders__c = 0,
        Total_Order_Value__c = 0,
        Total_Collection__c = 0
    ));
}
insert attendances;

// ── Create Visit records ──
List<Visit__c> visits = new List<Visit__c>();
for (Day_Attendance__c da : attendances) {
    visits.add(new Visit__c(
        Account__c = accountId,
        Salesperson__c = UserInfo.getUserId(),
        Day_Attendance__c = da.Id,
        Beat__c = beatId,
        Visit_Date__c = da.Attendance_Date__c,
        Check_In_Time__c = DateTime.newInstance(da.Attendance_Date__c, Time.newInstance(10, 0, 0, 0)),
        Check_In_Lat__c = 19.0760,
        Check_In_Long__c = 72.8777,
        Visit_Status__c = 'Completed',
        Is_Planned__c = true
    ));
}
insert visits;

// ── Create Sales Orders ──
List<Sales_Order__c> orders = new List<Sales_Order__c>();
for (Visit__c v : visits) {
    orders.add(new Sales_Order__c(
        Account__c = accountId,
        Salesperson__c = UserInfo.getUserId(),
        Visit__c = v.Id,
        Order_Date__c = v.Visit_Date__c,
        Order_Type__c = 'Regular',
        Channel__c = 'Field App',
        Total_Gross_Amount__c = 0,
        Total_Discount__c = 0,
        Total_Tax__c = 0,
        Total_Net_Amount__c = 0,
        Total_Items__c = 0
    ));
}
insert orders;

// ── Create Order Line Items ──
List<Order_Line_Item__c> lineItems = new List<Order_Line_Item__c>();
for (Sales_Order__c order : orders) {
    for (Integer p = 0; p < Math.min(3, products.size()); p++) {
        Decimal qty = 10 + (Math.random() * 40).intValue();
        Decimal price = 50 + (Math.random() * 200).intValue();
        lineItems.add(new Order_Line_Item__c(
            Sales_Order__c = order.Id,
            Product_Ext__c = products[p].Id,
            Quantity__c = qty,
            Unit_Price__c = price,
            Line_Total__c = qty * price,
            UOM__c = 'Pieces'
        ));
    }
}
insert lineItems;

System.debug('Seed data created: ' + attendances.size() + ' attendance, ' +
    visits.size() + ' visits, ' + orders.size() + ' orders, ' +
    lineItems.size() + ' line items');
