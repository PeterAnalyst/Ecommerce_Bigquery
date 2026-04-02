
# [Ecommerce_dashboard.pbix](https://app.powerbi.com/groups/me/reports/e9620d7a-0bfb-43e0-a895-2085ab21c69f/c194e3542183c297a483?experience=power-bi&bookmarkGuid=ea12eb5f7f471214b45d)

## ecommerce_dashboard.pbix
Tool: Power BI Desktop

Connection: DirectQuery → Google BigQuery

Data: analytics_portfolio schema (7 tables)

Pages: 2 | Views: 6 | DAX Measures: 20+

## Connection Setup
This report connects to BigQuery via DirectQuery, meaning no data is imported locally — every visual fires a live query against the warehouse.

To reconnect:

1. Open Power BI Desktop
2. Get Data → Google BigQuery
3. Select all tables from analytics_portfolio:
    * `fact_session`
    * `dim_date, dim_city, dim_device, dim_users, dim_channel, dim_country`

4. In Model View, verify relationships (or auto-detect)

## Data Model
All relationships are Many-to-One from fact_session to each dimension:

| From (fact_session) | To (dim table) | Key  |
| ------------------- | -------------- | --- |
| date_key | dim_date.date_key | Date 
|city_surrogate_key	| dim_city.city_surrogate_key | FARM_FINGERPRINT hash
|device_key	| dim_device.device_key	| Device category string
|user_id | dim_users.user_key | Visitor ID
|channel_key | dim_channel.channel_key	| source-medium concat

## DAX Measures
### Core Metrics

`Total Revenue = SUM(fact_session[revenue])`

`Total Sessions = SUM(fact_session[sessions])`

`Total Transactions = SUM(fact_session[transactions])`

`Total Users = DISTINCTCOUNT(fact_session[user_id])`

### Month-over-Month
```
Previous Month Rev =
CALCULATE([Total Revenue], DATEADD(dim_date[date_key], -1, MONTH))
```

```
MoM Revenue Change =
DIVIDE([Total Revenue] - [Previous Month Rev], [Previous Month Rev])
```

### Efficiency KPIs

```
Conversion Rate =
DIVIDE([Total Transactions], [Total Sessions])
```
```
Revenue per Session =
VAR SessionsValue = [Total Sessions]
VAR Threshold = SELECTEDVALUE('What if'[Value], 100)
RETURN
    IF(SessionsValue >= Threshold,
       DIVIDE([Total Revenue], [Total Sessions]),
       BLANK())
```
```
ARPU =
DIVIDE([Total Revenue], [Total Users])
```

### Revenue Opportunity
```
-- STEP 1: Get current device's metrics
VAR CurrentDeviceCR  = [Conversion Rate]   
VAR CurrentDeviceRev = [Total Revenue]     

-- STEP 2: Find BEST device's conversion rate (benchmark across ALL devices)
VAR BestDeviceCR = 
    MAXX(
        ALL(dim_device[device_name]),             
        [Conversion Rate]               
    )

-- STEP 3: Calculate POTENTIAL revenue if this device converted like best device
VAR PotentialRevenue = 
    IF(
        CurrentDeviceCR > 0,                 
        CurrentDeviceRev * (BestDeviceCR / CurrentDeviceCR),
        BLANK()
    )

-- STEP 4: Opportunity = Potential - Actual (but never negative)
VAR RevenueGap = PotentialRevenue - CurrentDeviceRev
RETURN IF(RevenueGap <= 0, BLANK(), RevenueGap)     
```

### Funnel (Log-Scaled)
```
Funnel Value (Log) =
VAR RawValue =
    SWITCH(
        SELECTEDVALUE(FunnelSteps[StepName]),
        "Sessions",     [Total Sessions],
        "Users",        [Total Users],
        "Transactions", [Total Transactions],
        "Revenue",      [Total Revenue]
    )
RETURN IF(RawValue > 0, LOG(RawValue, 10), BLANK())
```

**Why LOG10?** Sessions (~869K) and Revenue (~$2M) cannot share the same bar axis as Transactions (~12K). LOG10 compresses them into a 4–7 range, making all four funnel steps readable side by side without distorting their meaning.

## Dashboard Pages
### Page 1 — Executive Summary
Three toggle-states controlled by bookmarks:

|View | What it shows
|--- | --- |
|Default | KPI cards (Revenue, Sessions, Transactions, Users) + MoM indicators
|Filtered |	Same cards with slicer active — MoM delta becomes visible
|Geographic |	World map (Revenue by Country) + City tooltip + RPS matrix

Slicers: Year · Month · Device toggle · Session threshold (What-if, 100–10,000)

### Page 2 — Device Comparison
Side-by-side panel for any two devices selected via dropdown.

|Toggle	| What it shows
|---|---|
|Rev / Opp | Revenue vs Revenue Opportunity trend line over time
|Funnel	| LOG10-scaled funnel bars — % contribution per device across Sessions → Users → Transactions → Revenue

**Below the panels:**  RPS by Country per device · Channel breakdown (Revenue, Conv Rate, RPS) switchable between Source / User Type / Medium views

**Slicers:** Year · Quarter · Month · Session threshold

## What-If Parameter
Created as a disconnected table:

```
What if = GENERATESERIES(100, 10000, 100)
```
Used in the Revenue per Session measure to suppress RPS values for low-traffic segments below a user-defined session threshold. Adjust the slider on either page to filter out noise.

## Known Limitations
* August 2017 revenue shows a sharp drop (~94.5% from July). This is a data cut-off in the source dataset, not a real business event. Do not draw trend conclusions from it.

* DirectQuery latency: complex cross-filter combinations (device × channel × geography) may be slow. If needed, switch dim_country to Import mode.

* Mobile sessions with zero transactions: several countries show mobile sessions with no revenue. This is expected based on the source data, not a modeling error.