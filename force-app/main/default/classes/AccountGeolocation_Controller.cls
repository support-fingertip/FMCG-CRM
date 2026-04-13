/**
 * @description Controller for capturing and managing geolocation on Account
 *              (outlet) records. Used by:
 *                - accountGeolocationButton: single-record capture from the
 *                  customer's physical location (via browser geolocation)
 *                - bulkGeolocateAccounts: bulk-copy from BillingLatitude/
 *                  BillingLongitude fields where present
 *
 *              Geo-fencing during visit check-in compares the Salesperson's
 *              current location against Outlet_Latitude__c / Outlet_Longitude__c
 *              within Geofence_Radius__c metres.
 *
 * @author  SFA Development Team
 * @date    2026
 */
public with sharing class AccountGeolocation_Controller {

    private static final Decimal DEFAULT_RADIUS_METERS = 100;

    /**
     * @description Saves a captured GPS location to a single account.
     */
    @AuraEnabled
    public static Account saveAccountLocation(
        Id accountId,
        Decimal latitude,
        Decimal longitude,
        Decimal accuracy,
        Decimal radiusMeters
    ) {
        if (accountId == null) {
            throw new AuraHandledException('Account Id is required.');
        }
        if (latitude == null || longitude == null) {
            throw new AuraHandledException('Latitude and longitude are required.');
        }
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            throw new AuraHandledException('Latitude or longitude out of range.');
        }
        try {
            Account acc = new Account(
                Id = accountId,
                Outlet_Latitude__c = latitude,
                Outlet_Longitude__c = longitude,
                Geo_Location__Latitude__s = latitude,
                Geo_Location__Longitude__s = longitude
            );
            if (radiusMeters != null && radiusMeters > 0) {
                acc.Geofence_Radius__c = radiusMeters;
            } else {
                acc.Geofence_Radius__c = DEFAULT_RADIUS_METERS;
            }
            update acc;
            return [
                SELECT Id, Name, Outlet_Latitude__c, Outlet_Longitude__c,
                       Geofence_Radius__c, BillingStreet, BillingCity, BillingState
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Failed to save location: ' + e.getMessage());
        }
    }

    /**
     * @description Returns the current geolocation status of an account.
     */
    @AuraEnabled(cacheable=true)
    public static Account getAccountLocation(Id accountId) {
        if (accountId == null) return null;
        List<Account> accts = [
            SELECT Id, Name, Outlet_Latitude__c, Outlet_Longitude__c,
                   Geofence_Radius__c, BillingStreet, BillingCity,
                   BillingState, BillingPostalCode, BillingCountry,
                   BillingLatitude, BillingLongitude
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        return accts.isEmpty() ? null : accts[0];
    }

    /**
     * @description Returns counts of accounts with/without geolocation, scoped
     *              by territory if provided.
     */
    @AuraEnabled
    public static Map<String, Integer> getGeolocationStats(Id territoryId) {
        Integer total;
        Integer withLocation;
        Integer withBilling;

        if (territoryId == null) {
            total = [SELECT COUNT() FROM Account WHERE Is_Active__c = true];
            withLocation = [
                SELECT COUNT() FROM Account
                WHERE Is_Active__c = true
                  AND Outlet_Latitude__c != null
                  AND Outlet_Longitude__c != null
            ];
            withBilling = [
                SELECT COUNT() FROM Account
                WHERE Is_Active__c = true
                  AND BillingLatitude != null
                  AND BillingLongitude != null
                  AND (Outlet_Latitude__c = null OR Outlet_Longitude__c = null)
            ];
        } else {
            total = [SELECT COUNT() FROM Account WHERE Is_Active__c = true AND Territory__c = :territoryId];
            withLocation = [
                SELECT COUNT() FROM Account
                WHERE Is_Active__c = true
                  AND Territory__c = :territoryId
                  AND Outlet_Latitude__c != null
                  AND Outlet_Longitude__c != null
            ];
            withBilling = [
                SELECT COUNT() FROM Account
                WHERE Is_Active__c = true
                  AND Territory__c = :territoryId
                  AND BillingLatitude != null
                  AND BillingLongitude != null
                  AND (Outlet_Latitude__c = null OR Outlet_Longitude__c = null)
            ];
        }

        Map<String, Integer> stats = new Map<String, Integer>();
        stats.put('total', total);
        stats.put('withLocation', withLocation);
        stats.put('withBilling', withBilling);
        stats.put('missing', total - withLocation);
        return stats;
    }

    /**
     * @description Bulk-copies BillingLatitude/BillingLongitude into
     *              Outlet_Latitude__c/Outlet_Longitude__c for all accounts
     *              in scope that have billing geocodes but no outlet geocodes.
     *              Useful when Salesforce Address Geocoder has populated the
     *              standard billing geocodes via standard data.com or batch.
     *
     * @param territoryId Optional territory filter.
     * @return Number of accounts updated.
     */
    @AuraEnabled
    public static Integer bulkCopyFromBillingAddress(Id territoryId, Decimal radiusMeters) {
        Decimal radius = (radiusMeters != null && radiusMeters > 0) ? radiusMeters : DEFAULT_RADIUS_METERS;

        List<Account> toUpdate;
        if (territoryId == null) {
            toUpdate = [
                SELECT Id, BillingLatitude, BillingLongitude, Geofence_Radius__c
                FROM Account
                WHERE Is_Active__c = true
                  AND BillingLatitude != null
                  AND BillingLongitude != null
                  AND (Outlet_Latitude__c = null OR Outlet_Longitude__c = null)
                LIMIT 200
            ];
        } else {
            toUpdate = [
                SELECT Id, BillingLatitude, BillingLongitude, Geofence_Radius__c
                FROM Account
                WHERE Is_Active__c = true
                  AND Territory__c = :territoryId
                  AND BillingLatitude != null
                  AND BillingLongitude != null
                  AND (Outlet_Latitude__c = null OR Outlet_Longitude__c = null)
                LIMIT 200
            ];
        }

        if (toUpdate.isEmpty()) return 0;

        for (Account a : toUpdate) {
            a.Outlet_Latitude__c = a.BillingLatitude;
            a.Outlet_Longitude__c = a.BillingLongitude;
            a.Geo_Location__Latitude__s = a.BillingLatitude;
            a.Geo_Location__Longitude__s = a.BillingLongitude;
            if (a.Geofence_Radius__c == null || a.Geofence_Radius__c == 0) {
                a.Geofence_Radius__c = radius;
            }
        }

        try {
            update toUpdate;
            return toUpdate.size();
        } catch (Exception e) {
            throw new AuraHandledException('Bulk copy failed: ' + e.getMessage());
        }
    }

    /**
     * @description Clears geolocation on a single account.
     */
    @AuraEnabled
    public static void clearAccountLocation(Id accountId) {
        if (accountId == null) return;
        try {
            Account acc = new Account(
                Id = accountId,
                Outlet_Latitude__c = null,
                Outlet_Longitude__c = null,
                Geo_Location__Latitude__s = null,
                Geo_Location__Longitude__s = null
            );
            update acc;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to clear location: ' + e.getMessage());
        }
    }
}
