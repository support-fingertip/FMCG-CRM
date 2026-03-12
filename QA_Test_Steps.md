# FMCG-CRM QA Test Steps Document

**Version:** 1.0
**Date:** March 2026
**Modules Covered:** Day Attendance, Holiday, Leave, Visit Management, Expense Management

---

## Prerequisites / Test Data Setup

- **Admin User:** System Administrator with full access
- **Employee User (E1):** Active employee with Beat assignments, Territory, Band, Week_Off_Days configured
- **Manager User (M1):** Reporting Manager of E1 (set as E1's L1 Approver)
- **Finance User (F1):** Finance approver (set as E1's L2 Approver)
- **Beats:** At least 2 beats assigned to E1 (e.g., Beat-A for Monday, Beat-B for Tuesday)
- **Outlets:** At least 3 outlets mapped to each beat
- **Holidays:** At least 1 holiday configured for current month
- **Expense Eligibility:** DA and TA rules configured for E1's band
- **Leave Balances:** CL, SL, EL, CO balances set on Employee record

---

## Module 1: Day Attendance

### 1.1 Day Start (Check-In)

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 1 | Login as E1. Open Day Attendance / Day Start component | Day Start form should load with today's date |  |
| 2 | Select Beat from assigned beat list for today | Only beats assigned for today's weekday should appear |  |
| 3 | Select Duty Type (HQ / EX-HQ / OS) | Default should be HQ. All 3 options available |  |
| 4 | Allow GPS location capture | Start_Location_Lat, Start_Location_Long, Start_Accuracy should be populated |  |
| 5 | Capture Start Selfie (if required) | Start_Selfie_URL should be populated |  |
| 6 | Click "Start Day" | Day_Attendance__c record created with Status = "Started", Start_Time = current time, Attendance_Date = today |  |
| 7 | Verify device info is captured | Device_Info__c, Battery_Level__c, Network_Status__c populated |  |
| 8 | Try starting another day for the same date | Should be prevented - only one attendance per day per user |  |

### 1.2 Beat Switch

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 9 | During an active day, initiate beat switch | Beat switch form should appear |  |
| 10 | Select a different beat and provide Beat_Switch_Reason | Beat__c updated, Beat_Switched__c = true, Original_Beat__c preserves first beat |  |

### 1.3 Companion Tracking

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 11 | Mark "With Companion" during day start | With_Companion__c = true |  |
| 12 | Select/enter companion details | Companion__c field populated |  |

### 1.4 Day End (Check-Out)

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 13 | Click "End Day" on an active attendance | Day End form loads |  |
| 14 | Allow GPS capture for end location | End_Location_Lat, End_Location_Long, End_Accuracy populated |  |
| 15 | Capture End Selfie (if required) | End_Selfie_URL populated |  |
| 16 | Enter Odometer End reading (if applicable) | Odometer_End__c populated |  |
| 17 | Submit Day End | Status changes to "Ended", End_Time = current time |  |
| 18 | Verify Hours_Worked__c is calculated | Should equal difference between Start_Time and End_Time in hours |  |
| 19 | Verify Distance_Traveled_Km__c | Should be calculated from GPS start/end coordinates or odometer difference |  |
| 20 | Verify day summary fields are updated | Total_Visits__c, Total_Orders__c, Total_Order_Value__c, Total_Collection__c, Productive_Calls__c should reflect actual visits |  |

### 1.5 Auto Day-End (Scheduled Flow)

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 21 | Leave a day attendance in "Started" or "In Progress" status past 9 PM cutoff | Flow DFO_AutoDayEnd should auto-close the record |  |
| 22 | Verify auto-closed record | Status = "Auto-Closed", Auto_Closed__c = true, End_Time set to flow execution time |  |

### 1.6 Employee 360 - Attendance Calendar View

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 23 | Open Employee 360 page for E1. Click "Attendance" tab | Monthly calendar view should display |  |
| 24 | Verify calendar shows correct attendance markers | Present days (green), Leave days, Holiday days, Absent days, Week-off days should be color-coded correctly |  |
| 25 | Verify present day shows hours worked | e.g., "190.7h" displayed on the calendar cell |  |
| 26 | Verify Monthly Summary Cards | Present count, Absent count, Leaves count, Holidays count, Avg Hours should match calendar |  |
| 27 | Verify Monthly Attendance Bar percentage | Should equal (Present Days / Working Days) * 100, where working days exclude employee's Week_Off_Days |  |
| 28 | Navigate to previous/next month using arrows | Calendar should update to show correct month's data |  |

### 1.7 KPI Summary (Top Bar)

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 29 | Verify Attendance KPI card shows "X/Y" | X = MTD present days (statuses: Present, Started, Completed, Ended, Auto-Closed, In Progress, Half Day), Y = working days using employee's Week_Off_Days |  |
| 30 | Verify Attendance % ring matches | Percentage = (X/Y) * 100, should match the calendar bar % |  |
| 31 | Verify MTD Orders, Collection, Visits KPIs | Should aggregate from Day_Attendance__c records for current month |  |

### 1.8 Team Attendance (Manager View)

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 32 | Login as M1. Open Employee 360 Team tab | Direct reports should be listed |  |
| 33 | Verify each team member shows attendance count | MTD attendance days and percentage should display per member |  |

---

## Module 2: Holiday Management

### 2.1 Holiday CRUD

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 34 | Login as Admin. Navigate to Holiday__c list view | Existing holidays should be listed |  |
| 35 | Create a new Holiday: Name = "Test Holiday", Holiday_Date__c = a future working day, Type__c, Territory__c, Year__c, Is_Active__c = true | Record created successfully |  |
| 36 | Edit the holiday - change the date | Record updated |  |
| 37 | Deactivate the holiday (Is_Active__c = false) | Holiday should no longer appear in active holiday lists |  |

### 2.2 Territory-Based Holidays

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 38 | Create a holiday with Territory = E1's territory | Holiday should appear in E1's calendar |  |
| 39 | Create a holiday with a different territory | Holiday should NOT appear in E1's calendar |  |
| 40 | Create a holiday with Territory = blank (national holiday) | Holiday should appear for all employees |  |

### 2.3 Holiday Impact on Calendar

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 41 | Open E1's Employee 360 Attendance tab for the month with holidays | Holiday should appear on the calendar with holiday indicator |  |
| 42 | Verify holiday is counted in the summary cards | Holiday count should include the holiday |  |
| 43 | Verify holiday doesn't count as absent | Working days calculation should not count holidays as absent |  |

---

## Module 3: Leave Management

### 3.1 Apply for Leave

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 44 | Login as E1. Navigate to Leave section | Leave form should load with leave types and balances visible |  |
| 45 | Select Leave_Type = "Casual Leave" | CL balance should display |  |
| 46 | Enter Start_Date = tomorrow, End_Date = day after tomorrow | Number_of_Days__c should auto-calculate (2 days) |  |
| 47 | Select Start_Session and End_Session (Full Day / First Half / Second Half) | If half-day selected, Number_of_Days should adjust (e.g., 0.5) |  |
| 48 | Enter Reason for leave | Reason__c field populated |  |
| 49 | Submit leave request | Status = "Pending" or "Submitted", record created |  |
| 50 | Verify leave balance is NOT deducted yet | CL_Balance__c on Employee should remain unchanged until approved |  |

### 3.2 Leave Validation

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 51 | Apply for leave with Start_Date > End_Date | Should show validation error |  |
| 52 | Apply for leave when balance is 0 for that type | Should show insufficient balance error |  |
| 53 | Apply for leave overlapping an existing approved leave | Should show overlap validation error |  |
| 54 | Apply for leave on a holiday date | Should show warning or prevent |  |
| 55 | Apply for leave on a past date | Should validate based on business rules (may be prevented) |  |

### 3.3 Leave Approval (Manager)

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 56 | Login as M1 (Reporting Manager). Navigate to pending leave requests | E1's leave request should appear |  |
| 57 | Approve the leave request | Status changes to "Approved", Approved_By__c = M1, Approval_Date__c = now |  |
| 58 | Verify leave balance is deducted | CL_Balance__c on Employee reduced by Number_of_Days |  |
| 59 | Verify leave appears on E1's attendance calendar | Leave days should show with leave indicator on calendar |  |

### 3.4 Leave Rejection

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 60 | Submit a new leave request as E1 | Status = Pending/Submitted |  |
| 61 | Login as M1. Reject the leave with a comment | Status changes to "Rejected", Comments__c updated |  |
| 62 | Verify balance is NOT deducted | Leave balance unchanged |  |

### 3.5 Leave Cancellation

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 63 | Login as E1. Cancel a previously approved leave | Status changes to "Cancelled" |  |
| 64 | Verify balance is restored | CL_Balance__c increased back by the leave days |  |

### 3.6 Leave Balance Display

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 65 | Open Employee 360 for E1 | Leave Balance KPI should show total remaining (CL + SL + EL + CO) |  |
| 66 | Click "Leaves" tab | Individual balance breakdown should show: CL, SL, EL, CO separately |  |
| 67 | Verify leave history list | All past leave requests with dates, type, status, days should display |  |

---

## Module 4: Visit Management

### 4.1 Beat & Outlet Setup (Prerequisites)

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 68 | Verify Beat_Assignment__c records exist for E1 | Beats assigned with day-wise schedule (e.g., Monday = Beat-A) |  |
| 69 | Verify Outlets mapped to beats | Each beat should have outlets listed |  |

### 4.2 Visit Check-In

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 70 | Login as E1. Start day attendance first | Day_Attendance__c created with Status = Started |  |
| 71 | Open Visit component / Outlet list for today's beat | Planned outlets for today's beat should display |  |
| 72 | Select an outlet and click "Check In" | Visit__c record created with Visit_Status = "Checked In", Check_In_Time = now |  |
| 73 | Verify GPS captured on check-in | Check_In_Lat__c, Check_In_Long__c, Check_In_Accuracy__c populated |  |
| 74 | Verify check-in photo captured (if required) | Check_In_Photo_URL__c populated |  |
| 75 | Verify Visit_Sequence__c is auto-assigned | Sequential visit number for the day |  |
| 76 | Verify Is_Planned__c flag | Should be true for planned outlets, false for ad-hoc |  |
| 77 | Verify Day_Attendance__c link | Visit linked to today's attendance record |  |

### 4.3 Geo-Fencing

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 78 | Check in at an outlet within geo-fence radius | Is_Geo_Fenced__c = true, Distance_To_Outlet__c within threshold |  |
| 79 | Check in at an outlet outside geo-fence radius | Is_Geo_Fenced__c = false, Geo_Fence_Override_Reason__c required |  |

### 4.4 Visit Activities & Completion

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 80 | During a checked-in visit, take an order | Order_Value__c, Total_Orders_Count__c updated |  |
| 81 | Record a collection | Collection_Amount__c updated |  |
| 82 | Mark merchandising completed | Merchandising_Completed__c = true |  |
| 83 | Complete a survey (if applicable) | Survey_Completed__c = true |  |
| 84 | Add visit notes | Notes__c populated |  |

### 4.5 Visit Check-Out / Completion

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 85 | Click "Check Out" / "Complete Visit" | Visit_Status changes to "Completed" |  |
| 86 | Verify Check_Out_Time captured | Should be current time |  |
| 87 | Verify Check_Out GPS | Check_Out_Lat__c, Check_Out_Long__c populated |  |
| 88 | Verify Duration_Minutes__c calculated | Difference between Check_In_Time and Check_Out_Time |  |
| 89 | Verify Is_Productive__c flag | true if orders/collections recorded, false otherwise |  |
| 90 | Verify check-out photo captured (if required) | Check_Out_Photo_URL__c populated |  |

### 4.6 Ad-Hoc Visits

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 91 | Start a visit to an outlet NOT in today's beat plan | Is_Ad_Hoc__c = true |  |
| 92 | Verify Ad_Hoc_Reason__c is required | Should prompt for reason before proceeding |  |

### 4.7 Skipped / Missed Visits

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 93 | Skip a planned visit with reason | Visit_Status = "Skipped", Missed_Reason__c populated |  |
| 94 | End the day without visiting a planned outlet | Unvisited outlets should be marked as "Missed" |  |

### 4.8 Non-Productive Visit

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 95 | Complete a visit without taking any order or collection | Is_Productive__c = false |  |
| 96 | Verify Non_Productive_Reason__c is captured | Should prompt for reason |  |

### 4.9 Visit Summary on Attendance

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 97 | After completing multiple visits, check Day_Attendance__c | Total_Visits__c = total visit count, Productive_Calls__c = productive visits, Non_Productive_Visits__c = non-productive count |  |
| 98 | Verify Productivity_Percent__c | (Productive / Total) * 100 |  |

### 4.10 Deviation Tracking

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 99 | Visit outlets out of planned sequence | Deviation_Reason__c should be captured |  |
| 100 | Reschedule a visit | Is_Rescheduled__c = true, Reschedule_Date__c populated, Original_Visit__c links to original |  |

---

## Module 5: Expense Management

### 5.1 Expense Report Creation

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 101 | Login as E1. Open Expense Manager | Expense form should load with month/year selector |  |
| 102 | Select current month and year | Expense__c report created (or existing one loaded) with Period_Start__c, Period_End__c, Working_Days__c |  |
| 103 | Verify eligible dates loaded | Days with attendance records (minus leave days) should appear as eligible dates |  |
| 104 | Verify eligibility rules loaded | DA, TA, and other configured expense types should auto-populate per day |  |
| 105 | Verify L1_Approver__c and L2_Approver__c set | Should be populated from Employee record |  |

### 5.2 Daily Allowance (DA)

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 106 | Open a day with Hours_Worked > 8 hours | DA eligible amount = Full Day rate (from eligibility rule) |  |
| 107 | Open a day with 4 <= Hours_Worked <= 8 | DA eligible amount = Half Day rate (Full Rate / 2) |  |
| 108 | Open a day with Hours_Worked < 4 hours | DA eligible amount = 0 (below DA_MIN_HOURS threshold) |  |
| 109 | Open a day with no hours data (hours = 0 or null) | DA eligible amount = Full Day rate (default when no hours) |  |
| 110 | Enter DA claimed amount > eligible amount | Warning "Exceeds eligible" should appear, Notes required |  |
| 111 | Enter DA claimed amount <= eligible amount | No warning, save normally |  |
| 112 | Verify DA Hours field shows attendance hours | Hours auto-populated from Day_Attendance__c (Hours_Worked or calculated from Start/End time) |  |

### 5.3 Travelling Allowance (TA)

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 113 | Open a day expense with GPS distance recorded | GPS_Distance_KM__c auto-populated from attendance |  |
| 114 | Select Travel Mode from allowed modes | Only modes allowed by eligibility rule should appear |  |
| 115 | Verify eligible amount calculated | Based on distance x rate, respecting slab rates if configured |  |
| 116 | Enter Manual Distance > GPS Distance | Distance_Override_Reason__c required |  |
| 117 | Enter Manual Distance > 150% of GPS Distance | Should show error (max override % exceeded) |  |
| 118 | Verify Daily KM Limit is applied | If distance > Daily_KM_Limit, eligible capped at limit |  |
| 119 | Enter From_Location and To_Location | Fields should accept values |  |

### 5.4 Duty Type Impact on Eligibility

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 120 | Day with Duty_Type = HQ | Eligibility rules with Travel_Type = 'HQ' or 'All' should apply |  |
| 121 | Day with Duty_Type = EX-HQ | Eligibility rules with Travel_Type = 'EX-HQ' or 'All' should apply |  |
| 122 | Day with Duty_Type = OS (Outstation) | Eligibility rules with Travel_Type = 'OS' or 'All' should apply |  |

### 5.5 Lodging Expenses

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 123 | Add a Lodging expense item | Rate Type should be "Actual" |  |
| 124 | Enter city name and verify city tier auto-resolved | City_Tier__c auto-populated from City_Tier master |  |
| 125 | Enter claimed amount above lodging limit for the city tier | Eligible amount capped at the tier limit (Tier 1 / Tier 2 / Tier 3) |  |
| 126 | Enter claimed amount within limit | Eligible = Claimed |  |

### 5.6 Flat Monthly Expenses

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 127 | Verify Flat Monthly expense type (e.g., Mobile) | Eligible = Rate_Amount / Working_Days per day |  |

### 5.7 Receipt Management

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 128 | For an item with Receipt_Required = true | "Receipt Required" badge should display |  |
| 129 | Upload a receipt image/file | File attached to expense item, file icon visible |  |
| 130 | Delete an uploaded receipt | File removed from item |  |
| 131 | Verify receipt threshold | If claimed > Receipt_Threshold__c, receipt becomes mandatory |  |

### 5.8 Save Expense Items

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 132 | Enter claimed amounts for DA, TA on multiple days and click Save | All items saved, status = "Not Submitted", Eligible_Amount recalculated by server |  |
| 133 | Verify saved items reload correctly | Claimed amounts, eligible amounts, notes, distances all persist |  |
| 134 | Verify total claimed, total eligible in report header | Aggregates should match sum of all items |  |

### 5.9 Add/Delete Expense Items

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 135 | Add a generic/miscellaneous expense type to a day | New item row added |  |
| 136 | Delete an unsaved expense item | Item removed from the row |  |
| 137 | Delete a previously saved item | Item deleted from database after save |  |

### 5.10 Submit Expense Report

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 138 | Click "Submit" on the expense report | Confirmation dialog should appear with summary |  |
| 139 | Verify submit summary shows totals | Total Claimed, Total Eligible, item count |  |
| 140 | Confirm submission | Expense__c.Status = "Submitted", all items Approval_Status = "Pending", Submitted_Date populated |  |
| 141 | Verify items become read-only after submission | Claimed amount, notes, distance fields should be non-editable |  |
| 142 | Verify L1 Approver receives notification | L1_Approver should get "Expense Submitted for Approval" notification |  |

### 5.11 Expense Approval - L1 (Manager)

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 143 | Login as M1. Open the Expense Approval component for E1's expense | Expense details, item list with checkboxes, amounts should load |  |
| 144 | Verify inline amount editing | Approved_Amount should be editable, defaults to Claimed_Amount |  |
| 145 | Reduce approved amount for an item | Amount updated, "Save Amounts" button becomes active |  |
| 146 | Click "Save Amounts" | Approved amounts persisted |  |
| 147 | Select specific items (not all) using checkboxes | "Approve Selected (N)" button enabled |  |
| 148 | Click "Approve Selected" → enter remarks → confirm | Selected items: Approval_Status = "L1 Approved". Non-selected items remain "Pending" |  |
| 149 | Verify expense status did NOT advance yet | Expense Status still "Submitted" (not all items approved) |  |
| 150 | Select remaining Pending items and approve | All items now "L1 Approved". Expense auto-advances to "Manager Approved" |  |
| 151 | Verify notification sent | E1 receives "Expense L1 Approved" notification. L2 Approver receives "Expense Pending L2 Approval" notification |  |

### 5.12 Expense Approval - L2

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 152 | Login as F1 (L2 Approver). Open the expense | Expense status = "Manager Approved", items = "L1 Approved" |  |
| 153 | Select L1 Approved items and click "Approve Selected" | Items change to "L2 Approved" |  |
| 154 | Verify expense auto-advances when all items L2 Approved | Expense Status = "Finance Approved" |  |
| 155 | Verify notification | E1 and L1 Approver receive "Expense L2 Approved" notification |  |

### 5.13 Item-Level L1 to L2 Progression (Mixed Approval)

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 156 | Submit a new expense with multiple items | Status = Submitted, items = Pending |  |
| 157 | As L1 Approver: approve SOME items (not all) | Approved items → "L1 Approved". Expense stays "Submitted" |  |
| 158 | As L1 Approver: select those L1 Approved items and approve AGAIN | Items should advance to "L2 Approved" (not stay at L1) |  |
| 159 | Approve remaining Pending items | Those items → "L1 Approved". Expense advances to "Manager Approved" (all items at L1+) |  |
| 160 | Approve the L1 Approved items to L2 | Those items → "L2 Approved". If all items now L2, expense → "Finance Approved" |  |

### 5.14 Approve All (Report-Level)

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 161 | Submit a new expense. Login as L1 Approver | Expense = Submitted |  |
| 162 | Click "Approve All" → enter remarks → confirm | All items → "L1 Approved", Expense → "Manager Approved" |  |
| 163 | Login as L2 Approver. Click "Approve All" | All items → "L2 Approved", Expense → "Finance Approved" |  |

### 5.15 Rejection

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 164 | Submit expense. As L1 Approver, select items and click "Reject Selected" | Rejection reason must be entered (mandatory) |  |
| 165 | Enter reason and confirm | Selected items: Approval_Status = "Rejected" |  |
| 166 | Click "Reject All" with reason | All items = "Rejected", Expense Status = "Rejected" |  |
| 167 | Verify rejection notification | E1 receives "Expense Rejected by L1" notification |  |
| 168 | Login as E1. Verify rejected expense can be edited | Status returns to "Draft", items editable again |  |

### 5.16 Re-submission After Rejection

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 169 | Edit a rejected expense - update claimed amounts | Items should be editable |  |
| 170 | Re-submit the expense | Status = "Submitted", items = "Pending" |  |

### 5.17 Comments History

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 171 | After multiple approve/reject actions, verify Comments_History__c | Should show timestamped entries: "[date time] User: action" for each action |  |
| 172 | Verify item-level Approver_Comments__c | Each approved/rejected item should have its own comment trail |  |

### 5.18 Edge Cases

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 173 | Verify expense for a month with no attendance records | No eligible dates should appear, "0 eligible day(s)" message |  |
| 174 | Verify expense for a month with all leave days | Leave dates excluded from eligible dates |  |
| 175 | Try editing a "Finance Approved" expense | Should be blocked - "cannot be edited after finance approval" |  |
| 176 | Verify Min Distance eligibility | If rule has Min_Distance_KM and GPS distance is below it, Is_Eligible = false, Eligible_Amount = 0 |  |
| 177 | Verify TA with disallowed travel mode | If travel mode not in Allowed_Travel_Modes, Is_Eligible = false |  |

---

## Cross-Module Integration Tests

| # | Test Step | Expected Result | Pass/Fail |
|---|-----------|-----------------|-----------|
| 178 | Full day flow: Start Day → Visit 3 outlets → End Day → Verify attendance summary | Total_Visits, Productive_Calls, Hours_Worked, Distance all calculated correctly |  |
| 179 | Attendance + Leave: Apply leave for a date, verify it's excluded from expense eligible dates | Leave date should not appear in expense eligible dates |  |
| 180 | Attendance + Holiday: Verify holiday appears on calendar and is excluded from expense eligible dates | Holiday shown on calendar, not counted as absent, not in expense dates |  |
| 181 | Attendance + Expense: Verify DA hours, GPS distance, and Duty Type auto-populate in expense items | Working_Hours from attendance, GPS_Distance from attendance, Duty_Type from attendance |  |
| 182 | Week-Off Days: Verify working days calculation uses employee's Week_Off_Days (not hardcoded Sat/Sun) | If employee only has Sunday week-off, Saturday should count as working day |  |
| 183 | Employee 360 KPI vs Calendar consistency | Attendance summary (X/Y %) should match calendar bar (%) - both use same Week_Off_Days logic |  |

---

## Notes for QA Team

1. **Test Users:** Always test with different users for approver flows. Salesforce custom notifications do NOT deliver to the user who triggers them (self-notification not supported).
2. **GPS:** For GPS-dependent tests, use a browser with location mocking or test on a mobile device with actual GPS.
3. **Scheduled Flows:** Auto Day-End flow runs at 9 PM UTC daily. For testing, you may need to trigger it manually or adjust the schedule.
4. **Expense Eligibility Setup:** Ensure Expense_Eligibility__c rules are configured for the test employee's Band before testing expense calculations.
5. **DA Thresholds:** DA_MIN_HOURS = 4 hours, DA_HALF_DAY_HOURS = 8 hours. These are hardcoded in both Apex and LWC.
6. **Status Transitions (Expense):** Draft → Submitted → Manager Approved → Finance Approved → Paid. Rejected goes back to Draft.
7. **Item Approval Statuses:** Not Submitted → Pending → L1 Approved → L2 Approved. Can be Rejected at any stage.
