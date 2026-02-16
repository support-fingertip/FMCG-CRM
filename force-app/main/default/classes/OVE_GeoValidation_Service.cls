public with sharing class OVE_GeoValidation_Service {

    private static final Double EARTH_RADIUS_METERS = 6371000; // Earth radius in meters

    /**
     * Calculates distance between two geo coordinates using Haversine formula.
     * Returns distance in meters.
     */
    public static Decimal calculateDistance(
        Decimal lat1,
        Decimal lon1,
        Decimal lat2,
        Decimal lon2
    ) {
        // Convert degrees to radians
        Double dLat = (lat2 - lat1) * Math.PI / 180;
        Double dLon = (lon2 - lon1) * Math.PI / 180;

        Double rLat1 = lat1 * Math.PI / 180;
        Double rLat2 = lat2 * Math.PI / 180;

        // Haversine formula
        Double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                   Math.cos(rLat1) * Math.cos(rLat2) *
                   Math.sin(dLon / 2) * Math.sin(dLon / 2);

        Double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        Double distance = EARTH_RADIUS_METERS * c;

        return Decimal.valueOf(distance);
    }

    /**
     * Validates that check-in location is within the specified radius of outlet.
     * @param lat1 Check-in latitude
     * @param lon1 Check-in longitude
     * @param lat2 Outlet latitude
     * @param lon2 Outlet longitude
     * @param radiusMeters Maximum allowed distance in meters
     * @return True if check-in is within radius, false otherwise
     */
    public static Boolean validateCheckInProximity(
        Decimal lat1,
        Decimal lon1,
        Decimal lat2,
        Decimal lon2,
        Double radiusMeters
    ) {
        // Handle null coordinates gracefully
        if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
            return false;
        }
        
        Decimal distance = calculateDistance(lat1, lon1, lat2, lon2);
        return distance <= radiusMeters;
    }
}