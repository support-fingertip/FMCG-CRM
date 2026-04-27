@IsTest
private class FileAttachment_Util_Test {

    @TestSetup
    static void setupData() {
        Account acc = TestDataFactory.createAndInsertAccount('File Test Account', 'Retailer');
    }

    private static String getTestBase64() {
        // Small valid base64 string simulating a tiny image
        return EncodingUtil.base64Encode(Blob.valueOf('test file content'));
    }

    // ── saveFileToParent ─────────────────────────────────────────────

    @IsTest
    static void testSaveFileToParent_Success() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Id cvId = FileAttachment_Util.saveFileToParent(getTestBase64(), 'TestPhoto', acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, cvId, 'ContentVersion Id should be returned');

        ContentVersion cv = [SELECT Id, Title, PathOnClient, FirstPublishLocationId
                             FROM ContentVersion WHERE Id = :cvId];
        System.assertEquals('TestPhoto', cv.Title, 'Title should match');
        System.assertEquals('TestPhoto.jpg', cv.PathOnClient, 'PathOnClient should have .jpg extension');
        System.assertEquals(acc.Id, cv.FirstPublishLocationId, 'Should be linked to parent');
    }

    @IsTest
    static void testSaveFileToParent_BlankData() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Id cvId = FileAttachment_Util.saveFileToParent('', 'TestPhoto', acc.Id);
        Test.stopTest();

        System.assertEquals(null, cvId, 'Blank data should return null');
    }

    @IsTest
    static void testSaveFileToParent_NullData() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Id cvId = FileAttachment_Util.saveFileToParent(null, 'TestPhoto', acc.Id);
        Test.stopTest();

        System.assertEquals(null, cvId, 'Null data should return null');
    }

    // ── saveFileStandalone ───────────────────────────────────────────

    @IsTest
    static void testSaveFileStandalone_Success() {
        Test.startTest();
        Id cvId = FileAttachment_Util.saveFileStandalone(getTestBase64(), 'StandaloneFile');
        Test.stopTest();

        System.assertNotEquals(null, cvId, 'ContentVersion Id should be returned');

        ContentVersion cv = [SELECT Id, Title, PathOnClient FROM ContentVersion WHERE Id = :cvId];
        System.assertEquals('StandaloneFile', cv.Title, 'Title should match');
        System.assertEquals('StandaloneFile.jpg', cv.PathOnClient, 'PathOnClient should have .jpg extension');
    }

    @IsTest
    static void testSaveFileStandalone_BlankData() {
        Test.startTest();
        Id cvId = FileAttachment_Util.saveFileStandalone('', 'StandaloneFile');
        Test.stopTest();

        System.assertEquals(null, cvId, 'Blank data should return null');
    }

    // ── linkFileToParent ─────────────────────────────────────────────

    @IsTest
    static void testLinkFileToParent_Success() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // Create a standalone file first
        Id cvId = FileAttachment_Util.saveFileStandalone(getTestBase64(), 'LinkTestFile');

        // Create a second account to link to
        Account acc2 = TestDataFactory.createAndInsertAccount('Second Account', 'Distributor');

        Test.startTest();
        FileAttachment_Util.linkFileToParent(cvId, acc2.Id);
        Test.stopTest();

        // Verify the link was created
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cvId];
        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId FROM ContentDocumentLink
            WHERE ContentDocumentId = :cv.ContentDocumentId AND LinkedEntityId = :acc2.Id
        ];
        System.assertEquals(1, links.size(), 'Should have a ContentDocumentLink to the second account');
    }

    @IsTest
    static void testLinkFileToParent_NullParams() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        // Should not throw - just returns
        FileAttachment_Util.linkFileToParent(null, acc.Id);
        FileAttachment_Util.linkFileToParent(null, null);
        Test.stopTest();
    }

    // ── getFirstAttachmentUrl ────────────────────────────────────────

    @IsTest
    static void testGetFirstAttachmentUrl_WithFile() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        FileAttachment_Util.saveFileToParent(getTestBase64(), 'UrlTestFile', acc.Id);

        Test.startTest();
        String url = FileAttachment_Util.getFirstAttachmentUrl(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, url, 'URL should be returned');
        System.assert(url.startsWith('/sfc/servlet.shepherd/document/download/'),
                       'URL should start with the download prefix');
    }

    @IsTest
    static void testGetFirstAttachmentUrl_NoFile() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        String url = FileAttachment_Util.getFirstAttachmentUrl(acc.Id);
        Test.stopTest();

        System.assertEquals(null, url, 'Should return null when no files attached');
    }

    @IsTest
    static void testGetFirstAttachmentUrl_NullId() {
        Test.startTest();
        String url = FileAttachment_Util.getFirstAttachmentUrl(null);
        Test.stopTest();

        System.assertEquals(null, url, 'Should return null for null Id');
    }

    // ── getAttachmentUrls ────────────────────────────────────────────

    @IsTest
    static void testGetAttachmentUrls_MultipleRecords() {
        Account acc1 = [SELECT Id FROM Account LIMIT 1];
        Account acc2 = TestDataFactory.createAndInsertAccount('Another Account', 'Distributor');

        FileAttachment_Util.saveFileToParent(getTestBase64(), 'File1', acc1.Id);
        FileAttachment_Util.saveFileToParent(getTestBase64(), 'File2', acc2.Id);

        Test.startTest();
        Map<Id, String> urls = FileAttachment_Util.getAttachmentUrls(new Set<Id>{ acc1.Id, acc2.Id });
        Test.stopTest();

        System.assertEquals(2, urls.size(), 'Should have URLs for both accounts');
        System.assert(urls.containsKey(acc1.Id), 'Should contain URL for account 1');
        System.assert(urls.containsKey(acc2.Id), 'Should contain URL for account 2');
    }

    @IsTest
    static void testGetAttachmentUrls_EmptySet() {
        Test.startTest();
        Map<Id, String> urls = FileAttachment_Util.getAttachmentUrls(new Set<Id>());
        Test.stopTest();

        System.assertEquals(0, urls.size(), 'Empty input should return empty map');
    }

    @IsTest
    static void testGetAttachmentUrls_NullSet() {
        Test.startTest();
        Map<Id, String> urls = FileAttachment_Util.getAttachmentUrls(null);
        Test.stopTest();

        System.assertEquals(0, urls.size(), 'Null input should return empty map');
    }

    @IsTest
    static void testGetAttachmentUrls_NoFilesAttached() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Map<Id, String> urls = FileAttachment_Util.getAttachmentUrls(new Set<Id>{ acc.Id });
        Test.stopTest();

        System.assertEquals(0, urls.size(), 'Should return empty map when no files attached');
    }
}
