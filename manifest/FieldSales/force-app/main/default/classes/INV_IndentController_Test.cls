/**
 * @description Test class for INV_IndentController.
 *              Tests indent CRUD, status transitions, line items, and product search.
 * @author  SFA Development Team
 * @date    2024
 */
@isTest
private class INV_IndentController_Test {

    @TestSetup
    static void setupTestData() {
        Account acc = TestDataFactory.createAndInsertAccount('Test Distributor', 'Distributor');

        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('West Territory', 'WEST01');

        List<Product_Extension__c> products = TestDataFactory.createAndInsertProducts(3);

        // Create a Draft indent with line items for reuse
        Indent__c indent = new Indent__c(
            Account__c = acc.Id,
            Territory__c = territory.Id,
            Indent_Date__c = Date.today(),
            Requested_Delivery_Date__c = Date.today().addDays(7),
            Status__c = 'Draft',
            Notes__c = 'Test indent'
        );
        insert indent;

        List<Indent_Line__c> lines = new List<Indent_Line__c>();
        for (Integer i = 0; i < products.size(); i++) {
            lines.add(new Indent_Line__c(
                Indent__c = indent.Id,
                Product_Ext__c = products[i].Id,
                Requested_Qty__c = (i + 1) * 10,
                Unit_Price__c = 100.00,
                Line_Total__c = (i + 1) * 10 * 100.00,
                Current_Stock__c = 5,
                Reorder_Level__c = 20
            ));
        }
        insert lines;

        indent.Total_Amount__c = 6000.00; // (10+20+30)*100
        update indent;
    }

    // ── getIndents Tests ─────────────────────────────────────────────────────

    @isTest
    static void testGetIndentsNoFilters() {
        Test.startTest();
        List<Indent__c> indents = INV_IndentController.getIndents(null, null);
        Test.stopTest();

        System.assertEquals(1, indents.size(), 'Should return 1 indent');
    }

    @isTest
    static void testGetIndentsWithStatusFilter() {
        Test.startTest();
        List<Indent__c> drafts = INV_IndentController.getIndents('Draft', null);
        List<Indent__c> approved = INV_IndentController.getIndents('Approved', null);
        Test.stopTest();

        System.assertEquals(1, drafts.size(), 'Should return 1 draft indent');
        System.assertEquals(0, approved.size(), 'Should return 0 approved indents');
    }

    @isTest
    static void testGetIndentsWithAllStatus() {
        Test.startTest();
        List<Indent__c> indents = INV_IndentController.getIndents('all', null);
        Test.stopTest();

        System.assertEquals(1, indents.size(), 'Should return all indents when status is all');
    }

    @isTest
    static void testGetIndentsWithDateRange() {
        Test.startTest();
        List<Indent__c> indents = INV_IndentController.getIndents(null, 'thisMonth');
        Test.stopTest();

        System.assert(indents.size() >= 1, 'Should return indents for this month');
    }

    @isTest
    static void testGetIndentsWithDateRangeToday() {
        Test.startTest();
        List<Indent__c> indents = INV_IndentController.getIndents(null, 'today');
        Test.stopTest();

        System.assertEquals(1, indents.size(), 'Should return 1 indent for today');
    }

    @isTest
    static void testGetIndentsWithDateRangeLast30() {
        Test.startTest();
        List<Indent__c> indents = INV_IndentController.getIndents(null, 'last30');
        Test.stopTest();

        System.assert(indents.size() >= 1, 'Should return indents for last 30 days');
    }

    // ── getIndentById Tests ──────────────────────────────────────────────────

    @isTest
    static void testGetIndentById() {
        Indent__c indent = [SELECT Id FROM Indent__c LIMIT 1];

        Test.startTest();
        INV_IndentController.IndentDetail detail = INV_IndentController.getIndentById(indent.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail.indent, 'Indent should not be null');
        System.assertEquals(3, detail.lineItems.size(), 'Should have 3 line items');
        System.assertEquals('Draft', detail.indent.Status__c, 'Status should be Draft');
    }

    @isTest
    static void testGetIndentByIdNullId() {
        Test.startTest();
        try {
            INV_IndentController.getIndentById(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Error should mention required');
        }
        Test.stopTest();
    }

    // ── createIndent Tests ───────────────────────────────────────────────────

    @isTest
    static void testCreateIndent() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];
        List<Product_Extension__c> products = [SELECT Id FROM Product_Extension__c ORDER BY Name LIMIT 2];

        String indentJson = JSON.serialize(new Map<String, Object>{
            'accountId' => acc.Id,
            'territoryId' => territory.Id,
            'indentDate' => Date.today(),
            'requestedDeliveryDate' => Date.today().addDays(5),
            'notes' => 'New test indent',
            'lineItems' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'productId' => products[0].Id,
                    'requestedQty' => 25,
                    'unitPrice' => 50.00,
                    'currentStock' => 10,
                    'reorderLevel' => 30
                },
                new Map<String, Object>{
                    'productId' => products[1].Id,
                    'requestedQty' => 15,
                    'unitPrice' => 75.00,
                    'currentStock' => 5,
                    'reorderLevel' => 20
                }
            }
        });

        Test.startTest();
        Id indentId = INV_IndentController.createIndent(indentJson);
        Test.stopTest();

        System.assertNotEquals(null, indentId, 'Indent ID should not be null');

        Indent__c indent = [SELECT Status__c, Total_Amount__c FROM Indent__c WHERE Id = :indentId];
        System.assertEquals('Draft', indent.Status__c, 'New indent should be in Draft');
        System.assertEquals(2375.00, indent.Total_Amount__c, 'Total should be (25*50)+(15*75)=2375');

        List<Indent_Line__c> lines = [
            SELECT Requested_Qty__c FROM Indent_Line__c WHERE Indent__c = :indentId
        ];
        System.assertEquals(2, lines.size(), 'Should have 2 line items');
    }

    @isTest
    static void testCreateIndentNoLineItems() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        String indentJson = JSON.serialize(new Map<String, Object>{
            'accountId' => acc.Id,
            'lineItems' => new List<Map<String, Object>>()
        });

        Test.startTest();
        try {
            INV_IndentController.createIndent(indentJson);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('line item'), 'Error should mention line items');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateIndentInvalidLineItems() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // Line items with null productId and zero qty should be skipped
        String indentJson = JSON.serialize(new Map<String, Object>{
            'accountId' => acc.Id,
            'lineItems' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'productId' => null,
                    'requestedQty' => 10,
                    'unitPrice' => 50.00
                }
            }
        });

        Test.startTest();
        try {
            INV_IndentController.createIndent(indentJson);
            System.assert(false, 'Should have thrown exception for no valid line items');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('valid line item') || e.getMessage().contains('Error'),
                'Should throw an error');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateIndentDefaultDate() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Product_Extension__c product = [SELECT Id FROM Product_Extension__c LIMIT 1];

        String indentJson = JSON.serialize(new Map<String, Object>{
            'accountId' => acc.Id,
            'indentDate' => null,
            'lineItems' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'productId' => product.Id,
                    'requestedQty' => 10,
                    'unitPrice' => 100.00
                }
            }
        });

        Test.startTest();
        Id indentId = INV_IndentController.createIndent(indentJson);
        Test.stopTest();

        Indent__c indent = [SELECT Indent_Date__c FROM Indent__c WHERE Id = :indentId];
        System.assertEquals(Date.today(), indent.Indent_Date__c, 'Should default to today');
    }

    // ── updateIndentStatus Tests ─────────────────────────────────────────────

    @isTest
    static void testUpdateIndentStatusDraftToSubmitted() {
        Indent__c indent = [SELECT Id FROM Indent__c LIMIT 1];

        Test.startTest();
        INV_IndentController.updateIndentStatus(indent.Id, 'Submitted');
        Test.stopTest();

        indent = [SELECT Status__c FROM Indent__c WHERE Id = :indent.Id];
        System.assertEquals('Submitted', indent.Status__c, 'Should be Submitted');
    }

    @isTest
    static void testUpdateIndentStatusSubmittedToApproved() {
        Indent__c indent = [SELECT Id FROM Indent__c LIMIT 1];
        indent.Status__c = 'Submitted';
        update indent;

        Test.startTest();
        INV_IndentController.updateIndentStatus(indent.Id, 'Approved');
        Test.stopTest();

        indent = [SELECT Status__c, Approved_By__c FROM Indent__c WHERE Id = :indent.Id];
        System.assertEquals('Approved', indent.Status__c, 'Should be Approved');
        System.assertEquals(UserInfo.getUserId(), indent.Approved_By__c, 'Approved_By should be set');
    }

    @isTest
    static void testUpdateIndentStatusApprovedToProcessing() {
        Indent__c indent = [SELECT Id FROM Indent__c LIMIT 1];
        indent.Status__c = 'Approved';
        update indent;

        Test.startTest();
        INV_IndentController.updateIndentStatus(indent.Id, 'Processing');
        Test.stopTest();

        indent = [SELECT Status__c FROM Indent__c WHERE Id = :indent.Id];
        System.assertEquals('Processing', indent.Status__c, 'Should be Processing');
    }

    @isTest
    static void testUpdateIndentStatusDraftToCancelled() {
        Indent__c indent = [SELECT Id FROM Indent__c LIMIT 1];

        Test.startTest();
        INV_IndentController.updateIndentStatus(indent.Id, 'Cancelled');
        Test.stopTest();

        indent = [SELECT Status__c FROM Indent__c WHERE Id = :indent.Id];
        System.assertEquals('Cancelled', indent.Status__c, 'Should be Cancelled');
    }

    @isTest
    static void testUpdateIndentStatusInvalidTransition() {
        Indent__c indent = [SELECT Id FROM Indent__c LIMIT 1];

        Test.startTest();
        try {
            INV_IndentController.updateIndentStatus(indent.Id, 'Received');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Invalid status transition'),
                'Error should mention invalid transition');
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateIndentStatusNullParams() {
        Test.startTest();
        try {
            INV_IndentController.updateIndentStatus(null, 'Submitted');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Error should mention required');
        }
        Test.stopTest();
    }

    // ── getIndentLineItems Tests ─────────────────────────────────────────────

    @isTest
    static void testGetIndentLineItems() {
        Indent__c indent = [SELECT Id FROM Indent__c LIMIT 1];

        Test.startTest();
        List<Indent_Line__c> lines = INV_IndentController.getIndentLineItems(indent.Id);
        Test.stopTest();

        System.assertEquals(3, lines.size(), 'Should return 3 line items');
    }

    @isTest
    static void testGetIndentLineItemsNullId() {
        Test.startTest();
        try {
            INV_IndentController.getIndentLineItems(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Error should mention required');
        }
        Test.stopTest();
    }

    // ── searchProducts Tests ─────────────────────────────────────────────────

    @isTest
    static void testSearchProductsNoTerm() {
        Test.startTest();
        List<Product_Extension__c> products = INV_IndentController.searchProducts(null);
        Test.stopTest();

        System.assertEquals(3, products.size(), 'Should return all 3 active products');
    }

    @isTest
    static void testSearchProductsByName() {
        Test.startTest();
        List<Product_Extension__c> products = INV_IndentController.searchProducts('Test Product');
        Test.stopTest();

        System.assertEquals(3, products.size(), 'Should find products matching name');
    }

    @isTest
    static void testSearchProductsBySKU() {
        Test.startTest();
        List<Product_Extension__c> products = INV_IndentController.searchProducts('TP-0001');
        Test.stopTest();

        System.assertEquals(1, products.size(), 'Should find 1 product matching SKU');
    }

    @isTest
    static void testSearchProductsNoMatch() {
        Test.startTest();
        List<Product_Extension__c> products = INV_IndentController.searchProducts('NonExistent');
        Test.stopTest();

        System.assertEquals(0, products.size(), 'Should return no products');
    }

    // ── Full Lifecycle Test ──────────────────────────────────────────────────

    @isTest
    static void testFullIndentLifecycle() {
        Indent__c indent = [SELECT Id FROM Indent__c LIMIT 1];

        Test.startTest();
        // Draft → Submitted
        INV_IndentController.updateIndentStatus(indent.Id, 'Submitted');
        indent = [SELECT Status__c FROM Indent__c WHERE Id = :indent.Id];
        System.assertEquals('Submitted', indent.Status__c, 'Should be Submitted');

        // Submitted → Approved
        INV_IndentController.updateIndentStatus(indent.Id, 'Approved');
        indent = [SELECT Status__c FROM Indent__c WHERE Id = :indent.Id];
        System.assertEquals('Approved', indent.Status__c, 'Should be Approved');

        // Approved → Processing
        INV_IndentController.updateIndentStatus(indent.Id, 'Processing');
        indent = [SELECT Status__c FROM Indent__c WHERE Id = :indent.Id];
        System.assertEquals('Processing', indent.Status__c, 'Should be Processing');

        // Processing → Dispatched
        INV_IndentController.updateIndentStatus(indent.Id, 'Dispatched');
        indent = [SELECT Status__c FROM Indent__c WHERE Id = :indent.Id];
        System.assertEquals('Dispatched', indent.Status__c, 'Should be Dispatched');

        // Dispatched → Received
        INV_IndentController.updateIndentStatus(indent.Id, 'Received');
        indent = [SELECT Status__c FROM Indent__c WHERE Id = :indent.Id];
        System.assertEquals('Received', indent.Status__c, 'Should be Received');
        Test.stopTest();
    }
}