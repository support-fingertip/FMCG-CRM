@IsTest
private class HolidayController_Test {

    @TestSetup
    static void setupData() {
        // Create territory for holiday association
        Territory_Master__c territory = TestDataFactory.createAndInsertTerritory('Mumbai', 'TER-MUM-001');

        // Create holidays for current year
        Integer currentYear = Date.today().year();

        List<Holiday__c> holidays = new List<Holiday__c>();

        holidays.add(new Holiday__c(
            Name = 'Republic Day',
            Holiday_Date__c = Date.newInstance(currentYear, 1, 26),
            Type__c = 'National Holiday',
            Description__c = 'Republic Day of India',
            Is_Active__c = true,
            Year__c = currentYear,
            Territory__c = territory.Id
        ));

        holidays.add(new Holiday__c(
            Name = 'Independence Day',
            Holiday_Date__c = Date.newInstance(currentYear, 8, 15),
            Type__c = 'National Holiday',
            Description__c = 'Independence Day of India',
            Is_Active__c = true,
            Year__c = currentYear,
            Territory__c = territory.Id
        ));

        holidays.add(new Holiday__c(
            Name = 'Ganesh Chaturthi',
            Holiday_Date__c = Date.newInstance(currentYear, 9, 7),
            Type__c = 'Regional Holiday',
            Description__c = 'Ganesh Chaturthi',
            Is_Active__c = true,
            Year__c = currentYear,
            Territory__c = territory.Id
        ));

        holidays.add(new Holiday__c(
            Name = 'Inactive Holiday',
            Holiday_Date__c = Date.newInstance(currentYear, 12, 25),
            Type__c = 'National Holiday',
            Description__c = 'Christmas - Inactive',
            Is_Active__c = false,
            Year__c = currentYear
        ));

        insert holidays;
    }

    // ── getHolidays ─────────────────────────────────────────────────

    @IsTest
    static void testGetHolidays_ByYear() {
        Integer currentYear = Date.today().year();

        Test.startTest();
        List<Holiday__c> results = HolidayController.getHolidays(currentYear, null, null);
        Test.stopTest();

        // Should return 3 active holidays (Inactive excluded)
        System.assertEquals(3, results.size(), 'Should return 3 active holidays');
    }

    @IsTest
    static void testGetHolidays_ByYearAndType() {
        Integer currentYear = Date.today().year();

        Test.startTest();
        List<Holiday__c> results = HolidayController.getHolidays(currentYear, 'National Holiday', null);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return 2 national holidays');
    }

    @IsTest
    static void testGetHolidays_ByYearAndTerritory() {
        Integer currentYear = Date.today().year();
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];

        Test.startTest();
        List<Holiday__c> results = HolidayController.getHolidays(currentYear, null, territory.Id);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Should return 3 territory holidays');
    }

    @IsTest
    static void testGetHolidays_NullYear() {
        Test.startTest();
        try {
            HolidayController.getHolidays(null, null, null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('Year') || e.getMessage().contains('Script-thrown exception'),
                'Should mention year requirement'
            );
        }
        Test.stopTest();
    }

    // ── getAllHolidaysForYear ────────────────────────────────────────

    @IsTest
    static void testGetAllHolidaysForYear() {
        Integer currentYear = Date.today().year();

        Test.startTest();
        List<Holiday__c> results = HolidayController.getAllHolidaysForYear(currentYear, null);
        Test.stopTest();

        // Should return all 4 including inactive
        System.assertEquals(4, results.size(), 'Should return all 4 holidays including inactive');
    }

    @IsTest
    static void testGetAllHolidaysForYear_WithTerritory() {
        Integer currentYear = Date.today().year();
        Territory_Master__c territory = [SELECT Id FROM Territory_Master__c LIMIT 1];

        Test.startTest();
        List<Holiday__c> results = HolidayController.getAllHolidaysForYear(currentYear, territory.Id);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'Should return 3 territory holidays');
    }

    @IsTest
    static void testGetAllHolidaysForYear_NullYear() {
        Test.startTest();
        try {
            HolidayController.getAllHolidaysForYear(null, null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('Year') || e.getMessage().contains('Script-thrown exception'),
                'Should mention year requirement'
            );
        }
        Test.stopTest();
    }

    // ── saveHoliday ─────────────────────────────────────────────────

    @IsTest
    static void testSaveHoliday_New() {
        Integer currentYear = Date.today().year();

        Holiday__c newHoliday = new Holiday__c(
            Name = 'Diwali',
            Holiday_Date__c = Date.newInstance(currentYear, 11, 1),
            Type__c = 'National Holiday',
            Description__c = 'Festival of Lights',
            Is_Active__c = true
        );

        Test.startTest();
        Holiday__c result = HolidayController.saveHoliday(newHoliday);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Should have an Id after save');
        System.assertEquals(currentYear, result.Year__c, 'Year should be auto-populated');
        System.assertEquals('Diwali', result.Name, 'Name should match');
    }

    @IsTest
    static void testSaveHoliday_Update() {
        Holiday__c holiday = [SELECT Id, Name, Holiday_Date__c FROM Holiday__c WHERE Name = 'Republic Day' LIMIT 1];
        holiday.Description__c = 'Updated description';

        Test.startTest();
        Holiday__c result = HolidayController.saveHoliday(holiday);
        Test.stopTest();

        System.assertEquals('Updated description', result.Description__c, 'Description should be updated');
    }

    @IsTest
    static void testSaveHoliday_NullDate() {
        Holiday__c newHoliday = new Holiday__c(
            Name = 'No Date Holiday',
            Holiday_Date__c = null
        );

        Test.startTest();
        try {
            HolidayController.saveHoliday(newHoliday);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('Holiday Date') || e.getMessage().contains('Script-thrown exception'),
                'Should mention date requirement'
            );
        }
        Test.stopTest();
    }

    // ── deleteHoliday ───────────────────────────────────────────────

    @IsTest
    static void testDeleteHoliday() {
        Holiday__c holiday = [SELECT Id FROM Holiday__c WHERE Name = 'Inactive Holiday' LIMIT 1];

        Test.startTest();
        HolidayController.deleteHoliday(holiday.Id);
        Test.stopTest();

        List<Holiday__c> remaining = [SELECT Id FROM Holiday__c WHERE Id = :holiday.Id];
        System.assertEquals(0, remaining.size(), 'Holiday should be deleted');
    }

    @IsTest
    static void testDeleteHoliday_NullId() {
        Test.startTest();
        try {
            HolidayController.deleteHoliday(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('Holiday Id') || e.getMessage().contains('Script-thrown exception'),
                'Should mention Id requirement'
            );
        }
        Test.stopTest();
    }

    // ── getUpcomingHolidays ─────────────────────────────────────────

    @IsTest
    static void testGetUpcomingHolidays() {
        Test.startTest();
        List<Holiday__c> results = HolidayController.getUpcomingHolidays(5);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return a list');
        // Results depend on today's date relative to test holidays
    }

    @IsTest
    static void testGetUpcomingHolidays_DefaultLimit() {
        Test.startTest();
        List<Holiday__c> results = HolidayController.getUpcomingHolidays(null);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return a list with default limit');
    }

    @IsTest
    static void testGetUpcomingHolidays_ZeroLimit() {
        Test.startTest();
        List<Holiday__c> results = HolidayController.getUpcomingHolidays(0);
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return a list with default limit for zero');
    }

    // ── getHolidaysBetweenDates ─────────────────────────────────────

    @IsTest
    static void testGetHolidaysBetweenDates() {
        Integer currentYear = Date.today().year();

        Test.startTest();
        List<Holiday__c> results = HolidayController.getHolidaysBetweenDates(
            Date.newInstance(currentYear, 1, 1),
            Date.newInstance(currentYear, 12, 31)
        );
        Test.stopTest();

        System.assert(results.size() >= 3, 'Should return at least 3 active holidays in the year');
    }

    @IsTest
    static void testGetHolidaysBetweenDates_NullDates() {
        Test.startTest();
        try {
            HolidayController.getHolidaysBetweenDates(null, null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('start date') || e.getMessage().contains('Script-thrown exception'),
                'Should mention date requirement'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetHolidaysBetweenDates_StartAfterEnd() {
        Test.startTest();
        try {
            HolidayController.getHolidaysBetweenDates(
                Date.newInstance(2026, 12, 31),
                Date.newInstance(2026, 1, 1)
            );
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('Start date') || e.getMessage().contains('Script-thrown exception'),
                'Should mention date order error'
            );
        }
        Test.stopTest();
    }

    // ── bulkCreateHolidays ──────────────────────────────────────────

    @IsTest
    static void testBulkCreateHolidays() {
        Integer currentYear = Date.today().year();

        List<Holiday__c> newHolidays = new List<Holiday__c>();
        newHolidays.add(new Holiday__c(
            Name = 'New Year',
            Holiday_Date__c = Date.newInstance(currentYear + 1, 1, 1),
            Type__c = 'National Holiday',
            Is_Active__c = true
        ));
        newHolidays.add(new Holiday__c(
            Name = 'Holi',
            Holiday_Date__c = Date.newInstance(currentYear + 1, 3, 14),
            Type__c = 'National Holiday',
            Is_Active__c = true
        ));

        Test.startTest();
        List<Holiday__c> results = HolidayController.bulkCreateHolidays(newHolidays);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Should return 2 created holidays');
        for (Holiday__c h : results) {
            System.assertEquals(currentYear + 1, Integer.valueOf(h.Year__c), 'Year should be auto-populated');
        }
    }

    @IsTest
    static void testBulkCreateHolidays_EmptyList() {
        Test.startTest();
        try {
            HolidayController.bulkCreateHolidays(new List<Holiday__c>());
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('No holiday') || e.getMessage().contains('Script-thrown exception'),
                'Should mention empty list'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testBulkCreateHolidays_NullList() {
        Test.startTest();
        try {
            HolidayController.bulkCreateHolidays(null);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Should have error message');
        }
        Test.stopTest();
    }

    @IsTest
    static void testBulkCreateHolidays_MissingDate() {
        List<Holiday__c> newHolidays = new List<Holiday__c>();
        newHolidays.add(new Holiday__c(
            Name = 'No Date Holiday',
            Holiday_Date__c = null,
            Type__c = 'National Holiday',
            Is_Active__c = true
        ));

        Test.startTest();
        try {
            HolidayController.bulkCreateHolidays(newHolidays);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('Holiday Date') || e.getMessage().contains('Script-thrown exception'),
                'Should mention missing date'
            );
        }
        Test.stopTest();
    }

    // ── getHolidayTypeOptions ───────────────────────────────────────

    @IsTest
    static void testGetHolidayTypeOptions() {
        Test.startTest();
        List<Map<String, String>> options = HolidayController.getHolidayTypeOptions();
        Test.stopTest();

        System.assertNotEquals(null, options, 'Should return a list');
        System.assert(!options.isEmpty(), 'Should have at least one holiday type option');
        for (Map<String, String> opt : options) {
            System.assert(opt.containsKey('label'), 'Each option should have a label');
            System.assert(opt.containsKey('value'), 'Each option should have a value');
        }
    }

    // ── getTerritoryOptions ─────────────────────────────────────────

    @IsTest
    static void testGetTerritoryOptions() {
        Test.startTest();
        List<Territory_Master__c> territories = HolidayController.getTerritoryOptions();
        Test.stopTest();

        System.assert(!territories.isEmpty(), 'Should return at least 1 territory');
        System.assertEquals('Mumbai', territories[0].Name, 'Should return the test territory');
    }
}
