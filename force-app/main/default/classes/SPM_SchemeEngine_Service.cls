/**
 * @description Service class implementing the promotional scheme evaluation engine.
 *              Evaluates scheme eligibility based on date range, product match,
 *              channel match, outlet type, and slab criteria. Supports scheme
 *              priority and stacking rules.
 *
 * Scheme Types:
 *   - Discount: Percentage or flat amount discount
 *   - Free Goods: Buy X get Y free
 *   - Slab: Tiered pricing based on quantity or value
 *   - Combo: Cross-product promotions
 *
 * @author  SFA Development Team
 * @date    2024
 */
public without sharing class SPM_SchemeEngine_Service {

    // ── Inner class: SchemeResult ─────────────────────────────────────────────

    /**
     * @description Encapsulates the result of evaluating a single scheme.
     */
    public class SchemeResult {
        /** The Scheme__c record ID. */
        public Id schemeId { get; set; }
        /** The scheme name for display. */
        public String schemeName { get; set; }
        /** The type of scheme (Discount, Free Goods, Slab, Combo). */
        public String schemeType { get; set; }
        /** The calculated discount amount (for discount-type schemes). */
        public Decimal discountAmount { get; set; }
        /** The free product ID (for free-goods-type schemes). */
        public Id freeProductId { get; set; }
        /** The free quantity (for free-goods-type schemes). */
        public Decimal freeQty { get; set; }

        public SchemeResult() {
            this.discountAmount = 0;
            this.freeQty = 0;
        }
    }

    // ── Public API ────────────────────────────────────────────────────────────

    /**
     * @description Evaluates all applicable schemes for a given account and set
     *              of line items on a specific order date.
     *
     * @param accountId  The Account (outlet) ID for channel/type matching.
     * @param lineItems  The list of order line items to evaluate against schemes.
     * @param orderDate  The order date for date-range validation.
     * @return A list of SchemeResult objects representing all applicable scheme benefits.
     */
    public static List<SchemeResult> getApplicableSchemes(
        Id accountId,
        List<Order_Line_Item__c> lineItems,
        Date orderDate
    ) {
        List<SchemeResult> results = new List<SchemeResult>();

        if (accountId == null || lineItems == null || lineItems.isEmpty()) {
            return results;
        }

        if (orderDate == null) {
            orderDate = Date.today();
        }

        // Fetch account details for channel and outlet type matching
        Account outlet = getAccountDetails(accountId);
        if (outlet == null) {
            return results;
        }

        // Collect product IDs from line items
        Set<Id> productIds = new Set<Id>();
        for (Order_Line_Item__c item : lineItems) {
            if (item.Product__c != null) {
                productIds.add(item.Product__c);
            }
        }

        // Fetch all potentially applicable schemes
        List<Scheme__c> candidateSchemes = fetchCandidateSchemes(
            productIds, orderDate, outlet.Channel__c, outlet.Outlet_Type__c
        );

        if (candidateSchemes.isEmpty()) {
            return results;
        }

        // Sort schemes by priority (lower number = higher priority)
        candidateSchemes.sort();

        // Track stacking rules
        Set<String> appliedSchemeTypes = new Set<String>();
        Boolean hasNonStackableScheme = false;

        // Evaluate each scheme
        for (Scheme__c scheme : candidateSchemes) {
            // Check stacking rules
            if (hasNonStackableScheme && scheme.Is_Stackable__c != true) {
                continue;
            }

            SchemeResult result = evaluateScheme(scheme, lineItems, outlet);

            if (result != null &&
                (result.discountAmount > 0 || result.freeQty > 0)) {
                results.add(result);

                if (scheme.Is_Stackable__c != true) {
                    hasNonStackableScheme = true;
                }

                appliedSchemeTypes.add(scheme.Scheme_Type__c);
            }
        }

        return results;
    }

    /**
     * @description Evaluates a specific slab within a scheme against the provided
     *              quantity and value to determine the applicable benefit.
     *
     * @param scheme  The Scheme__c record containing slab definitions.
     * @param quantity The total quantity for slab evaluation.
     * @param value    The total value for slab evaluation.
     * @return A SchemeResult if a slab matches, null otherwise.
     */
    public static SchemeResult evaluateSlab(
        Scheme__c scheme,
        Decimal quantity,
        Decimal value
    ) {
        if (scheme == null) {
            return null;
        }

        SchemeResult result = new SchemeResult();
        result.schemeId = scheme.Id;
        result.schemeName = scheme.Name;
        result.schemeType = scheme.Scheme_Type__c;

        // Get slab definitions for this scheme
        List<Scheme_Slab__c> slabs;
        if (scheme.Scheme_Slabs__r != null) {
            slabs = scheme.Scheme_Slabs__r;
        } else {
            slabs = [
                SELECT Id, Min_Quantity__c, Max_Quantity__c,
                       Min_Value__c, Max_Value__c,
                       Discount_Percent__c, Discount_Amount__c,
                       Free_Product__c, Free_Quantity__c
                FROM Scheme_Slab__c
                WHERE Scheme__c = :scheme.Id
                  AND Is_Active__c = true
                ORDER BY Min_Quantity__c ASC, Min_Value__c ASC
            ];
        }

        if (slabs == null || slabs.isEmpty()) {
            return null;
        }

        // Find the matching slab
        for (Scheme_Slab__c slab : slabs) {
            Boolean quantityMatch = isInRange(
                quantity,
                slab.Min_Quantity__c,
                slab.Max_Quantity__c
            );
            Boolean valueMatch = isInRange(
                value,
                slab.Min_Value__c,
                slab.Max_Value__c
            );

            // Match based on what criteria the slab defines
            Boolean slabMatches = false;
            if (slab.Min_Quantity__c != null && slab.Min_Value__c != null) {
                slabMatches = quantityMatch && valueMatch;
            } else if (slab.Min_Quantity__c != null) {
                slabMatches = quantityMatch;
            } else if (slab.Min_Value__c != null) {
                slabMatches = valueMatch;
            }

            if (slabMatches) {
                if (slab.Discount_Percent__c != null && slab.Discount_Percent__c > 0) {
                    result.discountAmount = (value * slab.Discount_Percent__c / 100)
                        .setScale(2, RoundingMode.HALF_UP);
                } else if (slab.Discount_Amount__c != null && slab.Discount_Amount__c > 0) {
                    result.discountAmount = slab.Discount_Amount__c;
                }

                if (slab.Free_Product__c != null) {
                    result.freeProductId = slab.Free_Product__c;
                    result.freeQty = slab.Free_Quantity__c != null
                        ? slab.Free_Quantity__c : 0;
                }

                return result;
            }
        }

        return null;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * @description Fetches the account details needed for scheme matching.
     */
    private static Account getAccountDetails(Id accountId) {
        List<Account> accounts = [
            SELECT Id, Name, Channel__c, Outlet_Type__c, Region__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        return accounts.isEmpty() ? null : accounts[0];
    }

    /**
     * @description Fetches all potentially applicable schemes based on date range,
     *              product match, channel, and outlet type.
     */
    private static List<Scheme__c> fetchCandidateSchemes(
        Set<Id> productIds,
        Date orderDate,
        String channel,
        String outletType
    ) {
        return [
            SELECT Id, Name, Scheme_Type__c, Priority__c,
                   Is_Stackable__c, Discount_Percent__c, Discount_Amount__c,
                   Free_Product__c, Free_Quantity__c,
                   Min_Quantity__c, Max_Quantity__c,
                   Min_Value__c, Max_Value__c,
                   Channel__c, Outlet_Type__c,
                   Product__c, Product_Category__c,
                   Start_Date__c, End_Date__c,
                   (SELECT Id, Min_Quantity__c, Max_Quantity__c,
                           Min_Value__c, Max_Value__c,
                           Discount_Percent__c, Discount_Amount__c,
                           Free_Product__c, Free_Quantity__c
                    FROM Scheme_Slabs__r
                    WHERE Is_Active__c = true
                    ORDER BY Min_Quantity__c ASC, Min_Value__c ASC)
            FROM Scheme__c
            WHERE Is_Active__c = true
              AND Start_Date__c <= :orderDate
              AND (End_Date__c >= :orderDate OR End_Date__c = null)
              AND (Product__c IN :productIds OR Product__c = null)
              AND (Channel__c = :channel OR Channel__c = null)
              AND (Outlet_Type__c = :outletType OR Outlet_Type__c = null)
            ORDER BY Priority__c ASC NULLS LAST
        ];
    }

    /**
     * @description Evaluates a single scheme against the provided line items.
     */
    private static SchemeResult evaluateScheme(
        Scheme__c scheme,
        List<Order_Line_Item__c> lineItems,
        Account outlet
    ) {
        // Calculate aggregates for matching products
        Decimal totalQty = 0;
        Decimal totalValue = 0;

        for (Order_Line_Item__c item : lineItems) {
            // Check product match
            if (scheme.Product__c != null && item.Product__c != scheme.Product__c) {
                continue;
            }

            Decimal qty = item.Quantity__c != null ? item.Quantity__c : 0;
            Decimal val = item.Net_Amount__c != null ? item.Net_Amount__c
                : (item.Line_Amount__c != null ? item.Line_Amount__c : 0);

            totalQty += qty;
            totalValue += val;
        }

        if (totalQty == 0 && totalValue == 0) {
            return null;
        }

        // Handle different scheme types
        SchemeResult result;

        if (scheme.Scheme_Type__c == 'Slab') {
            result = evaluateSlab(scheme, totalQty, totalValue);
        } else {
            result = new SchemeResult();
            result.schemeId = scheme.Id;
            result.schemeName = scheme.Name;
            result.schemeType = scheme.Scheme_Type__c;

            if (scheme.Scheme_Type__c == 'Discount') {
                if (scheme.Discount_Percent__c != null && scheme.Discount_Percent__c > 0) {
                    result.discountAmount = (totalValue * scheme.Discount_Percent__c / 100)
                        .setScale(2, RoundingMode.HALF_UP);
                } else if (scheme.Discount_Amount__c != null && scheme.Discount_Amount__c > 0) {
                    result.discountAmount = scheme.Discount_Amount__c;
                }
            } else if (scheme.Scheme_Type__c == 'Free Goods') {
                // Check minimum quantity/value thresholds
                Boolean meetsMinQty = scheme.Min_Quantity__c == null ||
                    totalQty >= scheme.Min_Quantity__c;
                Boolean meetsMinVal = scheme.Min_Value__c == null ||
                    totalValue >= scheme.Min_Value__c;

                if (meetsMinQty && meetsMinVal) {
                    result.freeProductId = scheme.Free_Product__c;
                    result.freeQty = scheme.Free_Quantity__c != null
                        ? scheme.Free_Quantity__c : 0;
                }
            }
        }

        return result;
    }

    /**
     * @description Checks whether a value falls within a specified range.
     *              Handles null bounds (null = unbounded).
     */
    private static Boolean isInRange(Decimal value, Decimal minVal, Decimal maxVal) {
        if (value == null) {
            return false;
        }
        Boolean aboveMin = (minVal == null) || (value >= minVal);
        Boolean belowMax = (maxVal == null) || (value <= maxVal);
        return aboveMin && belowMax;
    }
}
