#!/bin/bash
# Master Data Loading Script - FMCG CRM
# Runs all data scripts in dependency order
# Usage: bash scripts/run_all.sh [start_from]
# Example: bash scripts/run_all.sh          # Run all from beginning
#          bash scripts/run_all.sh 09        # Start from script 09 onwards
#
# Dependency Order:
#   01 Company Hierarchy (standalone)
#   02 Territory Master (standalone)
#   03 Product Category (standalone)
#   04 Products → 03
#   05 Batch Master → 04
#   06 Tax Configuration → 04
#   07 Price List → 04
#   08 Warehouses → 01
#   09 Accounts → 02
#   10 Beats & Outlets → 02, 09
#   11 Schemes → 04
#   12 Targets → 02, 03
#   13 Employees → 02
#   14 Holidays (standalone)
#   15 Leave Requests → 13
#   16 Journey Plans → 02, 10

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

START_FROM=${1:-01}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SCRIPTS=(
    "01_company_hierarchy.apex"
    "02_territory_master.apex"
    "03_product_category.apex"
    "04_products.apex"
    "05_batch_master.apex"
    "06_tax_configuration.apex"
    "07_price_list.apex"
    "08_warehouse.apex"
    "09_accounts.apex"
    "10_beats_and_outlets.apex"
    "11_schemes.apex"
    "12_targets.apex"
    "13_employees.apex"
    "14_holidays.apex"
    "15_leave_requests.apex"
    "16_journey_plans.apex"
)

echo -e "${YELLOW}╔══════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║   FMCG CRM - Master Data Loader         ║${NC}"
echo -e "${YELLOW}║   Starting from script: ${START_FROM}               ║${NC}"
echo -e "${YELLOW}╚══════════════════════════════════════════╝${NC}"
echo ""

TOTAL=0
PASSED=0
FAILED=0

for script in "${SCRIPTS[@]}"; do
    SCRIPT_NUM="${script:0:2}"

    # Skip scripts before START_FROM
    if [[ "$SCRIPT_NUM" < "$START_FROM" ]]; then
        continue
    fi

    TOTAL=$((TOTAL + 1))
    SCRIPT_NAME="${script%.apex}"
    SCRIPT_NAME="${SCRIPT_NAME:3}"  # Remove number prefix
    SCRIPT_NAME="${SCRIPT_NAME//_/ }"  # Replace underscores with spaces

    echo -e "${YELLOW}[${SCRIPT_NUM}/16]${NC} Running: ${SCRIPT_NAME}..."

    if sf apex run -f "${SCRIPT_DIR}/${script}" 2>&1 | tee /tmp/apex_output_$$.txt | grep -q "SUCCESS\|Compiled successfully"; then
        # Check for actual success in debug logs
        if grep -q "setup complete\|Inserted\|Updated" /tmp/apex_output_$$.txt 2>/dev/null; then
            echo -e "  ${GREEN}✓ Success${NC}"
            PASSED=$((PASSED + 1))
        else
            echo -e "  ${YELLOW}⚠ Completed (check output above)${NC}"
            PASSED=$((PASSED + 1))
        fi
    else
        echo -e "  ${RED}✗ Failed${NC}"
        FAILED=$((FAILED + 1))
        echo ""
        echo -e "${RED}Error output:${NC}"
        cat /tmp/apex_output_$$.txt
        echo ""
        read -p "Continue with remaining scripts? (y/n): " choice
        if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
            echo -e "${RED}Aborted.${NC}"
            rm -f /tmp/apex_output_$$.txt
            exit 1
        fi
    fi

    rm -f /tmp/apex_output_$$.txt
    echo ""
done

echo -e "${YELLOW}══════════════════════════════════════════${NC}"
echo -e "  Total: ${TOTAL} | ${GREEN}Passed: ${PASSED}${NC} | ${RED}Failed: ${FAILED}${NC}"
echo -e "${YELLOW}══════════════════════════════════════════${NC}"
