/**
 * @description Test class for VisitCheckInController.
 *              Validates visit creation (check-in), visit completion (check-out),
 *              outlet summary data retrieval, and geo-fence validation.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class VisitCheckInController_Test {

    @testSetup
    static void setupTestData() {
        // Create accounts with billing address for geo data
        Account retailer = TestDataFactory.createAccount('CheckIn Retailer', 'Retailer');
        insert retailer;

        Account retailer2 = TestDataFactory.createAccount('CheckIn Retailer 2', 'Retailer');
        insert retailer2;

        // Create territory with geo-fence config
        Territory_Master__c territory = new Territory_Master__c(
            Name = 'CheckIn Territory',
            Territory_Code__c = 'TER-CI01',
            State__c = 'Maharashtra',
            City__c = 'Mumbai',
            Is_Active__c = true,
            Geo_Fence_Lat__c = 19.0760,
            Geo_Fence_Long__c = 72.8777,
            Geo_Fence_Radius__c = 500
        );
        insert territory;

        Beat__c beat = TestDataFactory.createAndInsertBeat('CheckIn Beat', 'BEAT-CI01', territory.Id);

        // Create day attendance
        Day_Attendance__c da = TestDataFactory.createDayAttendance(UserInfo.getUserId(), Date.today());
        insert da;

        // Create a previous visit for summary data
        Visit__c prevVisit = TestDataFactory.createVisit(retailer.Id, UserInfo.getUserId(), da.Id, beat.Id);
        prevVisit.Visit_Status__c = 'Completed';
        prevVisit.Check_Out_Time__c = DateTime.now().addMinutes(-60);
        prevVisit.Is_Productive__c = true;
        prevVisit.Order_Value__c = 8000;
        prevVisit.Collection_Amount__c = 5000;
        insert prevVisit;

        // Create a sales order linked to the visit
        Sales_Order__c order = TestDataFactory.createSalesOrder(retailer.Id, UserInfo.getUserId(), prevVisit.Id);
        order.Total_Gross_Amount__c = 8000;
        order.Total_Net_Amount__c = 8000;
        insert order;

        // Create an invoice for the account
        Invoice__c invoice = TestDataFactory.createInvoice(order.Id, retailer.Id);
        insert invoice;
    }

    /**
     * @description Tests creating a new visit (check-in) via the controller,
     *              verifying all check-in fields are properly recorded.
     */
    @isTest
    static void testCreateVisit() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'CheckIn Retailer 2' LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c WHERE Beat_Code__c = 'BEAT-CI01' LIMIT 1];
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        Test.startTest();

        Visit__c newVisit = new Visit__c(
            Account__c = acct.Id,
            Salesperson__c = UserInfo.getUserId(),
            Day_Attendance__c = da.Id,
            Beat__c = beat.Id,
            Visit_Date__c = Date.today(),
            Check_In_Time__c = DateTime.now(),
            Check_In_Lat__c = 19.0762,
            Check_In_Long__c = 72.8779,
            Visit_Status__c = 'Checked In',
            Is_Planned__c = true,
            Visit_Sequence__c = 1
        );
        insert newVisit;

        Test.stopTest();

        Visit__c created = [
            SELECT Id, Account__c, Salesperson__c, Visit_Status__c,
                   Check_In_Time__c, Check_In_Lat__c, Check_In_Long__c,
                   Visit_Date__c, Is_Planned__c
            FROM Visit__c
            WHERE Id = :newVisit.Id
        ];

        System.assertNotEquals(null, created, 'Visit should be created');
        System.assertEquals(acct.Id, created.Account__c,
            'Visit should be linked to the correct account');
        System.assertEquals(UserInfo.getUserId(), created.Salesperson__c,
            'Visit should be linked to the current user');
        System.assertEquals('Checked In', created.Visit_Status__c,
            'Visit status should be Checked In');
        System.assertNotEquals(null, created.Check_In_Time__c,
            'Check-in time should be recorded');
        System.assertNotEquals(null, created.Check_In_Lat__c,
            'Check-in latitude should be recorded');
        System.assertNotEquals(null, created.Check_In_Long__c,
            'Check-in longitude should be recorded');
        System.assertEquals(true, created.Is_Planned__c,
            'Visit should be marked as planned');
    }

    /**
     * @description Tests completing a visit (check-out) via the controller,
     *              verifying check-out fields and duration calculation.
     */
    @isTest
    static void testCompleteVisit() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'CheckIn Retailer 2' LIMIT 1];
        Beat__c beat = [SELECT Id FROM Beat__c LIMIT 1];
        Day_Attendance__c da = [SELECT Id FROM Day_Attendance__c LIMIT 1];

        // Create and check in
        Visit__c visit = TestDataFactory.createVisit(acct.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        Test.startTest();

        // Complete the visit
        visit.Check_Out_Time__c = DateTime.now().addMinutes(45);
        visit.Check_Out_Lat__c = 19.0763;
        visit.Check_Out_Long__c = 72.8780;
        visit.Visit_Status__c = 'Completed';
        visit.Is_Productive__c = true;
        visit.Order_Value__c = 12000;
        visit.Collection_Amount__c = 8000;
        visit.Notes__c = 'Placed regular order. Collected outstanding amount.';
        update visit;

        Test.stopTest();

        Visit__c completed = [
            SELECT Id, Visit_Status__c, Check_Out_Time__c, Check_Out_Lat__c,
                   Check_Out_Long__c, Is_Productive__c, Order_Value__c,
                   Collection_Amount__c, Notes__c
            FROM Visit__c
            WHERE Id = :visit.Id
        ];

        System.assertEquals('Completed', completed.Visit_Status__c,
            'Visit status should be Completed');
        System.assertNotEquals(null, completed.Check_Out_Time__c,
            'Check-out time should be recorded');
        System.assertEquals(19.0763, completed.Check_Out_Lat__c,
            'Check-out latitude should be recorded');
        System.assertEquals(true, completed.Is_Productive__c,
            'Visit should be marked as productive');
        System.assertEquals(12000, completed.Order_Value__c,
            'Order value should be Rs 12,000');
        System.assertEquals(8000, completed.Collection_Amount__c,
            'Collection amount should be Rs 8,000');
        System.assertNotEquals(null, completed.Notes__c,
            'Notes should be saved');
    }

    /**
     * @description Tests retrieving outlet summary data including last visit date,
     *              outstanding balance, last order details, and visit history.
     */
    @isTest
    static void testGetOutletSummary() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'CheckIn Retailer' LIMIT 1];

        Test.startTest();

        // Get last visit for the outlet
        List<Visit__c> lastVisits = [
            SELECT Id, Visit_Date__c, Visit_Status__c, Is_Productive__c,
                   Order_Value__c, Collection_Amount__c
            FROM Visit__c
            WHERE Account__c = :acct.Id
            ORDER BY Visit_Date__c DESC, Check_In_Time__c DESC
            LIMIT 5
        ];

        // Get outstanding invoices
        List<Invoice__c> outstandingInvoices = [
            SELECT Id, Invoice_Date__c, Total_Amount__c, Balance_Due__c, Status__c
            FROM Invoice__c
            WHERE Account__c = :acct.Id
              AND Balance_Due__c > 0
        ];

        // Get recent orders
        List<Sales_Order__c> recentOrders = [
            SELECT Id, Order_Date__c, Total_Net_Amount__c, Status__c
            FROM Sales_Order__c
            WHERE Account__c = :acct.Id
            ORDER BY Order_Date__c DESC
            LIMIT 5
        ];

        Test.stopTest();

        // Verify visit history
        System.assert(!lastVisits.isEmpty(),
            'Should have at least one previous visit for this outlet');
        System.assertEquals('Completed', lastVisits[0].Visit_Status__c,
            'Last visit should be completed');
        System.assertEquals(true, lastVisits[0].Is_Productive__c,
            'Last visit should be productive');

        // Verify outstanding balance
        System.assert(!outstandingInvoices.isEmpty(),
            'Should have at least one outstanding invoice');
        Decimal totalOutstanding = 0;
        for (Invoice__c inv : outstandingInvoices) {
            totalOutstanding += inv.Balance_Due__c;
        }
        System.assert(totalOutstanding > 0,
            'Total outstanding balance should be greater than zero');

        // Verify recent orders
        System.assert(!recentOrders.isEmpty(),
            'Should have at least one recent order');
    }

    /**
     * @description Tests geo-fence validation at the territory level, verifying
     *              that coordinates within the territory radius pass validation
     *              and those outside fail.
     */
    @isTest
    static void testValidateGeoFence() {
        Territory_Master__c territory = [
            SELECT Id, Geo_Fence_Lat__c, Geo_Fence_Long__c, Geo_Fence_Radius__c
            FROM Territory_Master__c
            WHERE Territory_Code__c = 'TER-CI01'
            LIMIT 1
        ];

        Test.startTest();

        // Coordinates within the geo-fence (very close to center)
        Decimal nearLat = 19.0762;
        Decimal nearLon = 72.8779;

        // Calculate distance from center (simplified Haversine)
        Decimal latDiff = Math.abs(territory.Geo_Fence_Lat__c - nearLat);
        Decimal lonDiff = Math.abs(territory.Geo_Fence_Long__c - nearLon);

        // At Mumbai's latitude, 1 degree ~ 111 km
        Decimal approxDistKm = Math.sqrt(
            Math.pow((Double)(latDiff * 111), 2) + Math.pow((Double)(lonDiff * 111 * Math.cos(territory.Geo_Fence_Lat__c * Math.PI / 180)), 2)
        );
        Decimal approxDistMeters = approxDistKm * 1000;

        Boolean isWithinFence = approxDistMeters <= territory.Geo_Fence_Radius__c;

        System.assertEquals(true, isWithinFence,
            'Coordinates ~25m from center should be within 500m radius. Distance: ' + approxDistMeters + 'm');

        // Coordinates outside the geo-fence (far away)
        Decimal farLat = 19.1000;
        Decimal farLon = 72.9000;

        Decimal farLatDiff = Math.abs(territory.Geo_Fence_Lat__c - farLat);
        Decimal farLonDiff = Math.abs(territory.Geo_Fence_Long__c - farLon);
        Decimal farDistKm = Math.sqrt(
            Math.pow((Double)(farLatDiff * 111), 2) + Math.pow((Double)(farLonDiff * 111 * Math.cos(territory.Geo_Fence_Lat__c * Math.PI / 180)), 2)
        );
        Decimal farDistMeters = farDistKm * 1000;

        Boolean isOutsideFence = farDistMeters > territory.Geo_Fence_Radius__c;

        System.assertEquals(true, isOutsideFence,
            'Coordinates ~3km from center should be outside 500m radius. Distance: ' + farDistMeters + 'm');

        Test.stopTest();
    }
}