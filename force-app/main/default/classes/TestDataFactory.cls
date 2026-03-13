@isTest
public class TestDataFactory {

    public static Account createAccount(String name, String type) {
        Account acc = new Account(
            Name = name,
            Type = type,
            BillingStreet = '123 Test Street',
            BillingCity = 'Mumbai',
            BillingState = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingCountry = 'India'
        );
        return acc;
    }

    public static Account createAndInsertAccount(String name, String type) {
        Account acc = createAccount(name, type);
        insert acc;
        return acc;
    }

    public static Product_Extension__c createProduct(String name, String code) {
        Product_Extension__c prod = new Product_Extension__c(
            Name = name,
            SKU_Code__c = code,
            Is_Active__c = true
        );
        return prod;
    }

    public static List<Product_Extension__c> createAndInsertProducts(Integer count) {
        List<Product_Extension__c> products = new List<Product_Extension__c>();
        for (Integer i = 0; i < count; i++) {
            products.add(createProduct('Test Product ' + i, 'TP-' + String.valueOf(i).leftPad(4, '0')));
        }
        insert products;
        return products;
    }

    public static Territory_Master__c createTerritory(String name, String code) {
        Territory_Master__c territory = new Territory_Master__c(
            Name = name,
            Territory_Code__c = code,
            State__c = 'Maharashtra',
            City__c = 'Mumbai',
            Is_Active__c = true
        );
        return territory;
    }

    public static Territory_Master__c createAndInsertTerritory(String name, String code) {
        Territory_Master__c t = createTerritory(name, code);
        insert t;
        return t;
    }

    public static Beat__c createBeat(String name, String code, Id territoryId) {
        Beat__c beat = new Beat__c(
            Name = name,
            Beat_Code__c = code,
            Territory__c = territoryId,
            Is_Active__c = true,
            Frequency__c = 'Weekly'
        );
        return beat;
    }

    public static Beat__c createAndInsertBeat(String name, String code, Id territoryId) {
        Beat__c b = createBeat(name, code, territoryId);
        insert b;
        return b;
    }

    public static Day_Attendance__c createDayAttendance(Id userId, Date attendanceDate) {
        Day_Attendance__c da = new Day_Attendance__c(
            Salesperson__c = userId,
            Attendance_Date__c = attendanceDate,
            Day_Start_Time__c = DateTime.newInstance(attendanceDate, Time.newInstance(9, 0, 0, 0)),
            Start_Location_Lat__c = 19.0760,
            Start_Location_Long__c = 72.8777,
            Status__c = 'Started',
            Total_Visits__c = 0,
            Productive_Calls__c = 0,
            Total_Orders__c = 0,
            Total_Order_Value__c = 0,
            Total_Collection__c = 0
        );
        return da;
    }

    public static Visit__c createVisit(Id accountId, Id userId, Id dayAttendanceId, Id beatId) {
        Visit__c visit = new Visit__c(
            Account__c = accountId,
            Salesperson__c = userId,
            Day_Attendance__c = dayAttendanceId,
            Beat__c = beatId,
            Visit_Date__c = Date.today(),
            Check_In_Time__c = DateTime.now(),
            Check_In_Lat__c = 19.0760,
            Check_In_Long__c = 72.8777,
            Visit_Status__c = 'Checked In',
            Is_Planned__c = true
        );
        return visit;
    }

    public static Sales_Order__c createSalesOrder(Id accountId, Id userId, Id visitId) {
        Sales_Order__c order = new Sales_Order__c(
            Account__c = accountId,
            Salesperson__c = userId,
            Visit__c = visitId,
            Order_Date__c = Date.today(),
            Status__c = 'Draft',
            Order_Type__c = 'Regular',
            Channel__c = 'Field App',
            Total_Gross_Amount__c = 0,
            Total_Discount__c = 0,
            Total_Tax__c = 0,
            Total_Net_Amount__c = 0,
            Total_Items__c = 0
        );
        return order;
    }

    public static Order_Line_Item__c createOrderLineItem(Id orderId, Id productId, Decimal qty, Decimal price) {
        Order_Line_Item__c li = new Order_Line_Item__c(
            Sales_Order__c = orderId,
            Product_Ext__c = productId,
            Quantity__c = qty,
            Unit_Price__c = price,
            Line_Total__c = qty * price,
            UOM__c = 'Pieces'
        );
        return li;
    }

    public static Invoice__c createInvoice(Id orderId, Id accountId) {
        Invoice__c inv = new Invoice__c(
            Sales_Order__c = orderId,
            Account__c = accountId,
            Invoice_Date__c = Date.today(),
            Due_Date__c = Date.today().addDays(30),
            Status__c = 'Confirmed',
            Total_Amount__c = 10000,
            Tax_Amount__c = 1800,
            Net_Amount__c = 11800,
            Balance_Due__c = 11800
        );
        return inv;
    }

    public static Collection__c createCollection(Id accountId, Id invoiceId, Decimal amount) {
        Collection__c col = new Collection__c(
            Account__c = accountId,
            Invoice__c = invoiceId,
            Collection_Date__c = Date.today(),
            Amount__c = amount,
            Payment_Mode__c = 'Cash',
            Status__c = 'Collected'
        );
        return col;
    }

    public static Scheme__c createScheme(String name, String code, String schemeType) {
        return createScheme(name, code, 'Free Products', schemeType);
    }

    public static Scheme__c createScheme(String name, String code, String category, String schemeType) {
        Scheme__c scheme = new Scheme__c(
            Name = name,
            Scheme_Code__c = code,
            Scheme_Category__c = category,
            Scheme_Type__c = schemeType,
            Start_Date__c = Date.today().addDays(-10),
            End_Date__c = Date.today().addDays(30),
            Status__c = 'Active',
            Priority__c = 1,
            Is_Stackable__c = false
        );
        return scheme;
    }

    public static Target__c createTarget(Id userId, Id territoryId, String month, String year, String type, Decimal value) {
        Target__c target = new Target__c(
            Salesperson__c = userId,
            Territory__c = territoryId,
            Period_Month__c = month,
            Period_Year__c = year,
            Target_Type__c = type,
            Target_Value__c = value,
            Achievement_Value__c = 0,
            Status__c = 'Active'
        );
        return target;
    }

    public static Return_Order__c createReturnOrder(Id accountId, Id invoiceId, Id userId) {
        Return_Order__c ro = new Return_Order__c(
            Account__c = accountId,
            Original_Invoice__c = invoiceId,
            Salesperson__c = userId,
            Return_Date__c = Date.today(),
            Status__c = 'Draft',
            Return_Reason__c = 'Damaged'
        );
        return ro;
    }

    public static Channel_Partner__c createChannelPartner(Id accountId, Id territoryId) {
        Channel_Partner__c cp = new Channel_Partner__c(
            Name = 'Test Partner',
            Account__c = accountId,
            Partner_Type__c = 'Distributor',
            Partner_Code__c = 'DIST-' + String.valueOf(Math.random()).substring(2, 8),
            Territory__c = territoryId,
            Credit_Limit__c = 500000,
            Credit_Used__c = 0,
            Is_Active__c = true,
            Onboarding_Status__c = 'Active',
            GSTIN__c = '27AAAAA0000A1Z5'
        );
        return cp;
    }

    public static Journey_Plan__c createJourneyPlan(Id userId, String month, String year) {
        Journey_Plan__c jp = new Journey_Plan__c(
            Salesperson__c = userId,
            Month__c = month,
            Year__c = year,
            Status__c = 'Draft',
            Total_Planned_Visits__c = 0,
            Effective_From__c = Date.today(),
            Effective_To__c = Date.today().addDays(30)
        );
        return jp;
    }

    public static Beat_Outlet__c createBeatOutlet(Id beatId, Id accountId) {
        Beat_Outlet__c bo = new Beat_Outlet__c(
            Beat__c = beatId,
            Account__c = accountId,
            Is_Active__c = true,
            Visit_Sequence__c = 1
        );
        return bo;
    }

    public static Beat_Outlet__c createAndInsertBeatOutlet(Id beatId, Id accountId) {
        Beat_Outlet__c bo = createBeatOutlet(beatId, accountId);
        insert bo;
        return bo;
    }

    public static Journey_Plan_Day__c createJourneyPlanDay(Id journeyPlanId, Id beatId, String dayOfWeek, Integer weekNumber) {
        Journey_Plan_Day__c jpd = new Journey_Plan_Day__c(
            Journey_Plan__c = journeyPlanId,
            Beat__c = beatId,
            Day_of_Week__c = dayOfWeek,
            Week_Number__c = 'Week ' + String.valueOf(weekNumber),
            Planned_Outlets__c = 4,
            Sequence_Order__c = weekNumber,
            Status__c = 'Planned'
        );
        return jpd;
    }

    public static Journey_Plan_Day__c createAndInsertJourneyPlanDay(Id journeyPlanId, Id beatId, String dayOfWeek, Integer weekNumber) {
        Journey_Plan_Day__c jpd = createJourneyPlanDay(journeyPlanId, beatId, dayOfWeek, weekNumber);
        insert jpd;
        return jpd;
    }

    // ── New Helper Methods for DFO / OVE Service Tests ───────────────────────

    /**
     * @description Creates a Day_Attendance__c with all new service-layer fields populated.
     * @param userId The salesperson User Id.
     * @return An unsaved Day_Attendance__c record with extended defaults.
     */
    public static Day_Attendance__c createDayAttendanceWithDefaults(Id userId) {
        Day_Attendance__c da = new Day_Attendance__c(
            User__c = userId,
            Salesperson__c = userId,
            Attendance_Date__c = Date.today(),
            Day_Start_Time__c = DateTime.now(),
            Start_Time__c = DateTime.now(),
            Start_Location_Lat__c = 19.0760,
            Start_Location_Long__c = 72.8777,
            Start_Accuracy__c = 10.0,
            Status__c = 'Started',
            Battery_Level__c = 85,
            Network_Status__c = '4G',
            Device_Info__c = 'Android 13 / Samsung Galaxy S23',
            Week_Day__c = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).format('EEEE'),
            Total_Visits__c = 0,
            Productive_Calls__c = 0,
            Non_Productive_Visits__c = 0,
            Total_Orders__c = 0,
            Total_Order_Value__c = 0,
            Total_Collection__c = 0,
            Total_Distance__c = 0,
            Distance_Traveled_Km__c = 0,
            Productivity_Percent__c = 0,
            Odometer_Start__c = 12500.0,
            With_Companion__c = false
        );
        return da;
    }

    /**
     * @description Creates a Visit__c with the new service-layer accuracy/battery/network fields.
     * @param accountId  The outlet Account Id.
     * @param userId     The salesperson User Id.
     * @param dayAttendanceId The Day_Attendance__c Id.
     * @param beatId     The Beat__c Id.
     * @return An unsaved Visit__c record with extended defaults.
     */
    public static Visit__c createVisitWithDefaults(Id accountId, Id userId, Id dayAttendanceId, Id beatId) {
        Visit__c visit = new Visit__c(
            Account__c = accountId,
            Outlet__c = accountId,
            Salesperson__c = userId,
            User__c = userId,
            Day_Attendance__c = dayAttendanceId,
            Beat__c = beatId,
            Visit_Date__c = Date.today(),
            Check_In_Time__c = DateTime.now(),
            Check_In_Lat__c = 19.0760,
            Check_In_Long__c = 72.8777,
            Check_In_Accuracy__c = 10.0,
            Check_In_Battery__c = '80%',
            Check_In_Network__c = '4G',
            Visit_Status__c = 'Checked In',
            Is_Planned__c = true,
            Order_Value__c = 0,
            Collection_Amount__c = 0,
            Total_Orders_Count__c = 0
        );
        return visit;
    }

    /**
     * @description Creates a GPS_Log__c record with all fields populated.
     * @param userId          The salesperson User Id.
     * @param dayAttendanceId The Day_Attendance__c Id.
     * @param lat             Latitude value.
     * @param lng             Longitude value.
     * @return An unsaved GPS_Log__c record.
     */
    public static GPS_Log__c createGPSLog(Id userId, Id dayAttendanceId, Decimal lat, Decimal lng) {
        GPS_Log__c gps = new GPS_Log__c(
            Salesperson__c = userId,
            Day_Attendance__c = dayAttendanceId,
            Latitude__c = lat,
            Longitude__c = lng,
            Accuracy__c = 10.0,
            Captured_At__c = DateTime.now(),
            Battery_Level__c = 75,
            Network_Status__c = '4G',
            Log_Type__c = 'Breadcrumb'
        );
        return gps;
    }

    /**
     * @description Creates an Account with geo-location data suitable for geo-fence testing.
     * @param name  Account name.
     * @param type  Account type (e.g. 'Retailer').
     * @param lat   Outlet latitude.
     * @param lng   Outlet longitude.
     * @return An unsaved Account with geo fields populated.
     */
    public static Account createAccountWithGeoData(String name, String type, Decimal lat, Decimal lng) {
        Account acc = new Account(
            Name = name,
            Type = type,
            BillingStreet = '123 Test Street',
            BillingCity = 'Mumbai',
            BillingState = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingCountry = 'India',
            BillingLatitude = lat,
            BillingLongitude = lng,
            Outlet_Latitude__c = lat,
            Outlet_Longitude__c = lng,
            Geofence_Radius__c = 200
        );
        return acc;
    }
}
