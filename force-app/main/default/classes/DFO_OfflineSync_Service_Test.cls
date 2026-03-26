@isTest
private class DFO_OfflineSync_Service_Test {

    @isTest
    static void testSyncVisits() {
        Test.startTest();
        DFO_OfflineSync_Service.SyncResult result = DFO_OfflineSync_Service.syncVisits(UserInfo.getUserId());
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(0, result.totalProcessed);
    }

    @isTest
    static void testSyncOrders() {
        Test.startTest();
        DFO_OfflineSync_Service.SyncResult result = DFO_OfflineSync_Service.syncOrders(UserInfo.getUserId());
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(0, result.totalProcessed);
    }

    @isTest
    static void testSyncAll() {
        Test.startTest();
        DFO_OfflineSync_Service.SyncResult result = DFO_OfflineSync_Service.syncAll(UserInfo.getUserId());
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(0, result.totalProcessed);
        System.assertEquals(0, result.errorCount);
    }
}
