@IsTest
private class ReturnOrderController_Test {

    @TestSetup
    static void setup() {
        Account acc = TestDataFactory.createAndInsertAccount('Return Outlet', 'Retailer');

        // Products
        List<Product_Extension__c> products = TestDataFactory.createAndInsertProducts(3);

        // Sales Order
        Sales_Order__c so = TestDataFactory.createSalesOrder(acc.Id, UserInfo.getUserId(), null);
        insert so;

        // Invoice - delivered status eligible for returns
        Invoice__c inv = TestDataFactory.createInvoice(so.Id, acc.Id);
        inv.Status__c = 'Delivered';
        inv.Total_Amount__c = 15000;
        inv.Net_Amount__c = 15000;
        inv.Balance_Due__c = 15000;
        insert inv;

        // Invoice Lines
        List<Invoice_Line__c> lines = new List<Invoice_Line__c>();
        for (Integer i = 0; i < products.size(); i++) {
            Invoice_Line__c line = new Invoice_Line__c(
                Invoice__c = inv.Id,
                Product_Ext__c = products[i].Id,
                Quantity__c = 10,
                Unit_Price__c = 500,
                Line_Total__c = 5000
            );
            lines.add(line);
        }
        insert lines;
    }

    static Account getTestAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Return Outlet' LIMIT 1];
    }

    static Invoice__c getTestInvoice() {
        return [SELECT Id, Name FROM Invoice__c LIMIT 1];
    }

    static List<Invoice_Line__c> getTestInvoiceLines() {
        return [SELECT Id, Product_Ext__c, Quantity__c, Unit_Price__c FROM Invoice_Line__c ORDER BY CreatedDate];
    }

    static List<Product_Extension__c> getTestProducts() {
        return [SELECT Id FROM Product_Extension__c ORDER BY Name];
    }

    // ── getAccountInvoices ───────────────────────────────────────────────────

    @IsTest
    static void testGetAccountInvoices() {
        Account acc = getTestAccount();

        Test.startTest();
        List<Invoice__c> invoices = ReturnOrderController.getAccountInvoices(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, invoices, 'Invoices list should not be null');
        System.assert(invoices.size() >= 1, 'Should return at least one delivered invoice');
        System.assertEquals('Delivered', invoices[0].Status__c, 'Invoice should be Delivered status');
    }

    @IsTest
    static void testGetAccountInvoicesNoResults() {
        Account newAcc = TestDataFactory.createAndInsertAccount('Empty Outlet', 'Retailer');

        Test.startTest();
        List<Invoice__c> invoices = ReturnOrderController.getAccountInvoices(newAcc.Id);
        Test.stopTest();

        System.assertEquals(0, invoices.size(), 'Should return no invoices for new account');
    }

    // ── getInvoiceLines ──────────────────────────────────────────────────────

    @IsTest
    static void testGetInvoiceLines() {
        Invoice__c inv = getTestInvoice();

        Test.startTest();
        List<Map<String, Object>> lines = ReturnOrderController.getInvoiceLines(inv.Id);
        Test.stopTest();

        System.assertEquals(3, lines.size(), 'Should return 3 invoice lines');

        Map<String, Object> firstLine = lines[0];
        System.assert(firstLine.containsKey('invoiceLineId'), 'Should have invoiceLineId');
        System.assert(firstLine.containsKey('productId'), 'Should have productId');
        System.assert(firstLine.containsKey('productName'), 'Should have productName');
        System.assert(firstLine.containsKey('invoicedQty'), 'Should have invoicedQty');
        System.assert(firstLine.containsKey('availableForReturn'), 'Should have availableForReturn');
        System.assert(firstLine.containsKey('alreadyReturned'), 'Should have alreadyReturned');

        System.assertEquals(10, (Decimal) firstLine.get('invoicedQty'), 'Invoiced qty should be 10');
        System.assertEquals(0, (Decimal) firstLine.get('alreadyReturned'), 'No prior returns');
        System.assertEquals(10, (Decimal) firstLine.get('availableForReturn'), 'Full qty available');
    }

    @IsTest
    static void testGetInvoiceLinesEmpty() {
        // Use a fake invoice Id (or an invoice with no lines)
        Account acc = TestDataFactory.createAndInsertAccount('No Lines Outlet', 'Retailer');
        Sales_Order__c so = TestDataFactory.createSalesOrder(acc.Id, UserInfo.getUserId(), null);
        insert so;
        Invoice__c inv = TestDataFactory.createInvoice(so.Id, acc.Id);
        inv.Status__c = 'Delivered';
        insert inv;

        Test.startTest();
        List<Map<String, Object>> lines = ReturnOrderController.getInvoiceLines(inv.Id);
        Test.stopTest();

        System.assertEquals(0, lines.size(), 'Should return empty list for invoice with no lines');
    }

    @IsTest
    static void testGetInvoiceLinesWithPriorReturns() {
        Invoice__c inv = getTestInvoice();
        List<Invoice_Line__c> invLines = getTestInvoiceLines();
        Account acc = getTestAccount();

        // Create a prior return order that consumed some quantity
        Return_Order__c priorReturn = new Return_Order__c(
            Account__c = acc.Id,
            Invoice__c = inv.Id,
            Return_Date__c = Date.today(),
            Status__c = 'Approved'
        );
        insert priorReturn;

        Return_Line__c priorLine = new Return_Line__c(
            Return_Order__c = priorReturn.Id,
            Invoice_Line__c = invLines[0].Id,
            Product_Ext__c = invLines[0].Product_Ext__c,
            Return_Quantity__c = 3,
            Return_Reason__c = 'Damaged',
            Unit_Price__c = 500
        );
        insert priorLine;

        Test.startTest();
        List<Map<String, Object>> lines = ReturnOrderController.getInvoiceLines(inv.Id);
        Test.stopTest();

        // Find the line that had a prior return
        for (Map<String, Object> line : lines) {
            if (line.get('invoiceLineId') == invLines[0].Id) {
                System.assertEquals(3, (Decimal) line.get('alreadyReturned'),
                    'Should show 3 already returned');
                System.assertEquals(7, (Decimal) line.get('availableForReturn'),
                    'Should show 7 available for return');
                break;
            }
        }
    }

    // ── createReturnOrder: valid JSON ────────────────────────────────────────

    @IsTest
    static void testCreateReturnOrderJson() {
        Account acc = getTestAccount();
        Invoice__c inv = getTestInvoice();
        List<Invoice_Line__c> invLines = getTestInvoiceLines();

        Map<String, Object> payload = new Map<String, Object>{
            'accountId' => acc.Id,
            'invoiceId' => inv.Id,
            'remarks' => 'Damaged goods return',
            'returnLines' => new List<Object>{
                new Map<String, Object>{
                    'invoiceLineId' => invLines[0].Id,
                    'productId' => invLines[0].Product_Ext__c,
                    'returnQty' => 2,
                    'returnAmount' => 1000,
                    'reason' => 'Damaged'
                },
                new Map<String, Object>{
                    'invoiceLineId' => invLines[1].Id,
                    'productId' => invLines[1].Product_Ext__c,
                    'returnQty' => 1,
                    'returnAmount' => 500,
                    'reason' => 'Expired'
                }
            }
        };

        Test.startTest();
        Return_Order__c result = ReturnOrderController.createReturnOrder(JSON.serialize(payload));
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Return order should be created');
        System.assertEquals('Draft', result.Status__c, 'Status should default to Draft');
        System.assertEquals(2, result.Total_Items__c, 'Should have 2 line items');

        // Verify return lines were created
        List<Return_Line__c> returnLines = [
            SELECT Id, Return_Quantity__c, Return_Reason__c
            FROM Return_Line__c
            WHERE Return_Order__c = :result.Id
        ];
        System.assertEquals(2, returnLines.size(), 'Should have 2 return lines');
    }

    // ── createReturnOrder: single line ───────────────────────────────────────

    @IsTest
    static void testCreateReturnOrderSingleLine() {
        Account acc = getTestAccount();
        Invoice__c inv = getTestInvoice();
        List<Invoice_Line__c> invLines = getTestInvoiceLines();

        Map<String, Object> payload = new Map<String, Object>{
            'accountId' => acc.Id,
            'invoiceId' => inv.Id,
            'remarks' => 'Single line return',
            'returnLines' => new List<Object>{
                new Map<String, Object>{
                    'invoiceLineId' => invLines[0].Id,
                    'productId' => invLines[0].Product_Ext__c,
                    'returnQty' => 5,
                    'returnAmount' => 2500,
                    'reason' => 'Wrong product'
                }
            }
        };

        Test.startTest();
        Return_Order__c result = ReturnOrderController.createReturnOrder(JSON.serialize(payload));
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Return order should be created');
        System.assertEquals(1, result.Total_Items__c, 'Should have 1 line item');
    }

    // ── createReturnOrder: with visit ────────────────────────────────────────

    @IsTest
    static void testCreateReturnOrderWithVisit() {
        Account acc = getTestAccount();
        Invoice__c inv = getTestInvoice();
        List<Invoice_Line__c> invLines = getTestInvoiceLines();

        // Create a visit
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Ret Territory', 'RT-001');
        Beat__c beat = TestDataFactory.createAndInsertBeat('Ret Beat', 'RB-001', territory.Id);
        Day_Attendance__c da = TestDataFactory.createDayAttendanceWithDefaults(UserInfo.getUserId());
        da.Beat__c = beat.Id;
        insert da;
        Visit__c visit = TestDataFactory.createVisitWithDefaults(acc.Id, UserInfo.getUserId(), da.Id, beat.Id);
        insert visit;

        Map<String, Object> payload = new Map<String, Object>{
            'accountId' => acc.Id,
            'invoiceId' => inv.Id,
            'visitId' => visit.Id,
            'remarks' => 'Return during visit',
            'returnLines' => new List<Object>{
                new Map<String, Object>{
                    'invoiceLineId' => invLines[0].Id,
                    'productId' => invLines[0].Product_Ext__c,
                    'returnQty' => 1,
                    'returnAmount' => 500,
                    'reason' => 'Damaged'
                }
            }
        };

        Test.startTest();
        Return_Order__c result = ReturnOrderController.createReturnOrder(JSON.serialize(payload));
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Return order with visit should be created');
    }

    // ── createReturnOrder: validation - no return lines ──────────────────────

    @IsTest
    static void testCreateReturnOrderNoLines() {
        Account acc = getTestAccount();

        Map<String, Object> payload = new Map<String, Object>{
            'accountId' => acc.Id,
            'returnLines' => new List<Object>()
        };

        Test.startTest();
        try {
            ReturnOrderController.createReturnOrder(JSON.serialize(payload));
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('At least one return line'),
                'Error should mention at least one line item required');
        }
        Test.stopTest();
    }

    // ── createReturnOrder: validation - zero quantity ─────────────────────────

    @IsTest
    static void testCreateReturnOrderZeroQuantity() {
        Account acc = getTestAccount();
        List<Invoice_Line__c> invLines = getTestInvoiceLines();

        Map<String, Object> payload = new Map<String, Object>{
            'accountId' => acc.Id,
            'returnLines' => new List<Object>{
                new Map<String, Object>{
                    'invoiceLineId' => invLines[0].Id,
                    'productId' => invLines[0].Product_Ext__c,
                    'returnQty' => 0,
                    'returnAmount' => 0,
                    'reason' => 'Damaged'
                }
            }
        };

        Test.startTest();
        try {
            ReturnOrderController.createReturnOrder(JSON.serialize(payload));
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('greater than zero'),
                'Error should mention return quantity must be greater than zero');
        }
        Test.stopTest();
    }

    // ── createReturnOrder: validation - exceeds available quantity ────────────

    @IsTest
    static void testCreateReturnOrderExceedsAvailableQty() {
        Account acc = getTestAccount();
        Invoice__c inv = getTestInvoice();
        List<Invoice_Line__c> invLines = getTestInvoiceLines();

        Map<String, Object> payload = new Map<String, Object>{
            'accountId' => acc.Id,
            'invoiceId' => inv.Id,
            'returnLines' => new List<Object>{
                new Map<String, Object>{
                    'invoiceLineId' => invLines[0].Id,
                    'productId' => invLines[0].Product_Ext__c,
                    'returnQty' => 15,
                    'returnAmount' => 7500,
                    'reason' => 'Damaged'
                }
            }
        };

        Test.startTest();
        try {
            ReturnOrderController.createReturnOrder(JSON.serialize(payload));
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('exceeds available quantity'),
                'Error should mention exceeding available quantity');
        }
        Test.stopTest();
    }

    // ── createReturnOrder: validation - missing reason ───────────────────────

    @IsTest
    static void testCreateReturnOrderMissingReason() {
        Account acc = getTestAccount();
        List<Invoice_Line__c> invLines = getTestInvoiceLines();

        Map<String, Object> payload = new Map<String, Object>{
            'accountId' => acc.Id,
            'returnLines' => new List<Object>{
                new Map<String, Object>{
                    'invoiceLineId' => invLines[0].Id,
                    'productId' => invLines[0].Product_Ext__c,
                    'returnQty' => 2,
                    'returnAmount' => 1000,
                    'reason' => ''
                }
            }
        };

        Test.startTest();
        try {
            ReturnOrderController.createReturnOrder(JSON.serialize(payload));
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Return reason is required'),
                'Error should mention return reason required');
        }
        Test.stopTest();
    }

    // ── createReturnOrder: validation - null return lines ────────────────────

    @IsTest
    static void testCreateReturnOrderNullLines() {
        Account acc = getTestAccount();

        Map<String, Object> payload = new Map<String, Object>{
            'accountId' => acc.Id
        };

        Test.startTest();
        try {
            ReturnOrderController.createReturnOrder(JSON.serialize(payload));
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('At least one return line'),
                'Error should mention at least one line item');
        }
        Test.stopTest();
    }

    // ── createReturnOrderFromRecords: typed method ───────────────────────────

    @IsTest
    static void testCreateReturnOrderFromRecords() {
        Account acc = getTestAccount();
        Invoice__c inv = getTestInvoice();
        List<Invoice_Line__c> invLines = getTestInvoiceLines();
        List<Product_Extension__c> products = getTestProducts();

        Return_Order__c ro = new Return_Order__c(
            Account__c = acc.Id,
            Invoice__c = inv.Id,
            Return_Date__c = Date.today(),
            Status__c = 'Draft'
        );

        List<Return_Line__c> returnLines = new List<Return_Line__c>{
            new Return_Line__c(
                Invoice_Line__c = invLines[0].Id,
                Product_Ext__c = products[0].Id,
                Return_Quantity__c = 3,
                Return_Reason__c = 'Damaged',
                Unit_Price__c = 500
            ),
            new Return_Line__c(
                Invoice_Line__c = invLines[1].Id,
                Product_Ext__c = products[1].Id,
                Return_Quantity__c = 2,
                Return_Reason__c = 'Expired',
                Unit_Price__c = 500
            )
        };

        Test.startTest();
        Return_Order__c result = ReturnOrderController.createReturnOrderFromRecords(ro, returnLines);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Return order should be created');
        System.assertEquals(2, result.Total_Items__c, 'Should have 2 items');
        System.assertEquals(2500, result.Total_Return_Value__c,
            'Total return value should be (3*500) + (2*500) = 2500');
    }

    // ── createReturnOrderFromRecords: defaults applied ───────────────────────

    @IsTest
    static void testCreateReturnOrderDefaultsApplied() {
        Account acc = getTestAccount();
        List<Invoice_Line__c> invLines = getTestInvoiceLines();
        List<Product_Extension__c> products = getTestProducts();

        Return_Order__c ro = new Return_Order__c(
            Account__c = acc.Id
            // Deliberately not setting Return_Date__c and Status__c
        );

        List<Return_Line__c> returnLines = new List<Return_Line__c>{
            new Return_Line__c(
                Invoice_Line__c = invLines[0].Id,
                Product_Ext__c = products[0].Id,
                Return_Quantity__c = 1,
                Return_Reason__c = 'Quality Issue',
                Unit_Price__c = 500
            )
        };

        Test.startTest();
        Return_Order__c result = ReturnOrderController.createReturnOrderFromRecords(ro, returnLines);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Return order should be created');
        // Defaults should be applied
        Return_Order__c freshRo = [SELECT Return_Date__c, Status__c FROM Return_Order__c WHERE Id = :result.Id];
        System.assertEquals(Date.today(), freshRo.Return_Date__c, 'Return date should default to today');
        System.assertEquals('Draft', freshRo.Status__c, 'Status should default to Draft');
    }

    // ── createReturnOrder: line without invoice line (ad-hoc product) ────────

    @IsTest
    static void testCreateReturnOrderWithoutInvoiceLine() {
        Account acc = getTestAccount();
        List<Product_Extension__c> products = getTestProducts();

        Return_Order__c ro = new Return_Order__c(
            Account__c = acc.Id,
            Return_Date__c = Date.today(),
            Status__c = 'Draft'
        );

        // Return line without invoice line reference (ad-hoc)
        List<Return_Line__c> returnLines = new List<Return_Line__c>{
            new Return_Line__c(
                Product_Ext__c = products[0].Id,
                Return_Quantity__c = 5,
                Return_Reason__c = 'Recall',
                Unit_Price__c = 300
            )
        };

        Test.startTest();
        Return_Order__c result = ReturnOrderController.createReturnOrderFromRecords(ro, returnLines);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Return order should be created for ad-hoc return');
    }
}
