-- ============================================================
-- SCHEMA SETUP
-- ============================================================

-- Create the analytics schema if it doesn't already exist
CREATE SCHEMA IF NOT EXISTS analytics_portfolio;


-- ============================================================
-- VIEWS
-- ============================================================

-- ------------------------------------------------------------
-- daily_channel_metrics
-- Aggregates session-level data by date and traffic source/medium.
-- Used for channel performance and trend analysis.
-- Date range: 2016–2017 (GA sample dataset)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW `analytics_portfolio.daily_channel_metrics` AS
SELECT 
  PARSE_DATE("%Y%m%d",date) AS session_date,
  COUNT(DISTINCT fullVisitorid) AS users,              -- Unique visitors per day per channel
  trafficSource.source,
  trafficSource.medium,
  COUNT(*) AS sessions,                                -- Total sessions (including multiple per user)
  SUM(totals.transactions) AS transactions,
  SUM(totals.totaltransactionRevenue)/1e6 AS revenue   -- Convert from micros to dollars
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE _TABLE_SUFFIX BETWEEN '20160101' AND '20171231'  -- Filter to 2016–2017 date range
GROUP BY 
  session_date,
  trafficSource.source,
  trafficSource.medium
ORDER BY
  PARSE_DATE("%Y%m%d",date);


-- ------------------------------------------------------------
-- customer_channel_metrics
-- Extends daily_channel_metrics with device category and user type segmentation.
-- Used for device analysis, new vs returning user comparisons, and RPS/ARPU queries.
-- Date range: 2016–2017 (GA sample dataset)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW `analytics_portfolio.customer_channel_metrics` AS
SELECT 
  PARSE_DATE("%Y%m%d",date) AS session_date,
  COUNT(DISTINCT fullVisitorid) AS users,              -- Unique visitors per segment
  trafficSource.source,
  trafficSource.medium,
  device.deviceCategory,
  CASE
    WHEN totals.newVisits = 1 THEN 'new_user'          -- First-time visitor in this session
    ELSE 'returning_user'                              -- Has visited before
  END AS users_seg,
  COUNT(*) AS sessions,                                -- Total sessions per segment
  SUM(totals.transactions) AS transactions,
  SUM(totals.totaltransactionRevenue)/1e6 AS revenue   -- Convert from micros to dollars
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE _TABLE_SUFFIX BETWEEN '20160101' AND '20171231'  -- Filter to 2016–2017 date range
GROUP BY 
  session_date,
  trafficSource.source,
  trafficSource.medium,
  users_seg,
  device.deviceCategory
ORDER BY
  PARSE_DATE("%Y%m%d",date);