-- ============================================================
-- CREATING TABLES TO BE USED IN POWERBI
-- ============================================================


-- ============================================================
-- FACT TABLE
-- ============================================================

-- 1. fact_session
-- Core transactional table. Each row = one session.
-- Holds foreign keys linking to all dimension tables, plus session-level metrics.
CREATE OR REPLACE TABLE `analytics_portfolio.fact_session` AS
SELECT 
  PARSE_DATE("%Y%m%d", date) AS date_key,

  CONCAT(fullVisitorID, '-', CAST(visitId AS STRING)) AS session_key, -- Unique session ID: visitor + visit combination

  fullVisitorID AS user_id,
  device.deviceCategory AS device_key,
  
  -- Surrogate key built from country + region + city to avoid collisions
  -- when the same city name appears in multiple regions or countries
  FARM_FINGERPRINT(
    CONCAT(
      COALESCE(geoNetwork.country, '(not set)'), '|',
      COALESCE(geoNetwork.region,   '(not set)'), '|',
      COALESCE(geoNetwork.city,     '(not set)')
    )
  ) AS city_surrogate_key,

  CONCAT(trafficSource.source, '-', trafficSource.medium) AS channel_key,

  1 AS sessions,                                                         -- Each row counts as 1 session
  IFNULL(totals.transactions, 0) AS transactions,                        -- Null-safe: defaults to 0 if no transaction
  IFNULL(totals.totalTransactionRevenue, 0) / 1000000 AS revenue        -- Convert from micros to dollars (GA stores revenue × 1,000,000)

FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE geoNetwork.city IS NOT NULL 
  AND geoNetwork.city != "(not set)";                                    -- Exclude sessions with unknown city


-- ============================================================
-- DIMENSION TABLES
-- ============================================================

-- 2. dim_city
-- Geographic dimension at city level.
-- Uses a surrogate key instead of city name to guarantee uniqueness
-- (e.g. two cities named "Springfield" in different states/countries).
CREATE OR REPLACE TABLE `analytics_portfolio.dim_city` AS
SELECT
  FARM_FINGERPRINT(
    CONCAT(
      COALESCE(geoNetwork.country, '(not set)'), '|',
      COALESCE(geoNetwork.region,   '(not set)'), '|',
      COALESCE(geoNetwork.city,     '(not set)')
    )
  ) AS city_surrogate_key,   -- Hashed PK: must match the surrogate key logic in fact_session

  geoNetwork.city     AS city_name,
  geoNetwork.region   AS region_name,
  geoNetwork.country  AS country_name,
  geoNetwork.latitude AS latitude,
  geoNetwork.longitude AS longitude

FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE geoNetwork.city IS NOT NULL 
  AND geoNetwork.city != "(not set)"
GROUP BY 
  -- Deduplicate: one row per unique city/region/country/coordinates combination
  geoNetwork.city,
  geoNetwork.region,
  geoNetwork.country,
  geoNetwork.latitude,
  geoNetwork.longitude;


-- ------------------------------------------------------------

-- 3. dim_users
-- User dimension capturing lifetime session history and user type classification.
-- A user is "new" if they have exactly 1 session across the entire dataset.
CREATE OR REPLACE TABLE `analytics_portfolio.dim_users` AS
SELECT 
  fullVisitorID AS user_key,
  
  CASE 
    WHEN COUNT(DISTINCT CONCAT(fullVisitorID, '-', CAST(visitId AS STRING))) = 1 
      THEN 'new_user'       -- Only one session recorded across the full dataset
    ELSE 'returning_user'   -- More than one session
  END AS user_type,

  MIN(PARSE_DATE("%Y%m%d", date)) AS first_session_date,  -- Earliest recorded session
  MAX(PARSE_DATE("%Y%m%d", date)) AS last_session_date    -- Most recent recorded session

FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
GROUP BY fullVisitorID;     -- One row per unique visitor


-- ------------------------------------------------------------

-- 4. dim_device
-- Simple device type dimension (e.g. desktop, mobile, tablet).
CREATE OR REPLACE TABLE `analytics_portfolio.dim_device` AS
SELECT DISTINCT 
  device.deviceCategory AS device_key,   -- PK, also used as FK in fact_session
  device.deviceCategory AS device_name   -- Kept separate for readability in reports
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE device.deviceCategory IS NOT NULL;


-- ------------------------------------------------------------

-- 5. dim_country
-- Country-level dimension. Can be enriched later with ISO codes, continents, etc.
CREATE OR REPLACE TABLE `analytics_portfolio.dim_country` AS
SELECT 
  geoNetwork.country AS country_key,
  geoNetwork.country AS country_name,  -- same value, but explicit
  -- You can enrich later with ISO codes, continent etc. from external source
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
WHERE geoNetwork.country IS NOT NULL 
  AND geoNetwork.country != "(not set)"
GROUP BY geoNetwork.country;           -- One row per unique country


-- ------------------------------------------------------------

-- 6. dim_channel
-- Traffic source dimension with brand-level grouping.
-- Maps raw source/medium pairs to recognizable platform names.
CREATE OR REPLACE TABLE `analytics_portfolio.dim_channel` AS
SELECT 
  *,
  -- Classify raw traffic sources into higher-level platform/brand buckets
  CASE 
    WHEN LOWER(source) LIKE '%google%'       THEN 'Google'
    WHEN LOWER(source) LIKE '%yahoo%'        THEN 'Yahoo'
    WHEN LOWER(source) LIKE '%pinterest%'    THEN 'Pinterest'
    WHEN LOWER(source) LIKE '%linkedin%'     THEN 'LinkedIn'
    WHEN LOWER(source) LIKE '%yandex%'       THEN 'Yandex'
    WHEN LOWER(source) LIKE '%doubleclick%'  THEN 'DoubleClick'
    WHEN LOWER(source) LIKE '%bing%'         THEN 'Bing'
    WHEN LOWER(source) LIKE '%reddit%'       THEN 'Reddit'
    WHEN LOWER(source) LIKE '%facebook%'     THEN 'Facebook'
    WHEN LOWER(source) LIKE '%youtube%'      THEN 'Youtube'
    ELSE 'Other'
  END AS main_source
FROM (
  -- Subquery: deduplicate to one row per unique source-medium combination
  SELECT DISTINCT
    CONCAT(trafficSource.source, '-', trafficSource.medium) AS channel_key,
    trafficSource.source AS source,
    trafficSource.medium AS medium
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
) AS dim_channel;


-- ============================================================
-- DATE DIMENSION
-- ============================================================

-- (First version — superseded by the CTE version below)
CREATE OR REPLACE TABLE `analytics_portfolio.dim_date` AS
SELECT 
  PARSE_DATE("%Y%m%d",date) AS date_key,
  FORMAT_DATE("%Y", PARSE_DATE("%Y%m%d",date)) AS year,
  FORMAT_DATE("%B", PARSE_DATE("%Y%m%d",date)) AS month_name,
  FORMAT_DATE("%A", PARSE_DATE("%Y%m%d",date)) AS day_name
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`;

-- Improved version: deduplicates dates first via CTE before formatting,
-- and adds an ISO day number (Monday = 1) for correct week-based sorting in reports.
CREATE OR REPLACE TABLE `analytics_portfolio.dim_date` AS
WITH parsed_dates AS (
  SELECT DISTINCT 
    PARSE_DATE('%Y%m%d', date) AS date_key
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
  WHERE date IS NOT NULL
)
SELECT
  date_key,
  EXTRACT(YEAR FROM date_key)              AS year,
  FORMAT_DATE('%B', date_key)             AS month_name,          -- e.g. "January"
  FORMAT_DATE('%A', date_key)             AS day_name,            -- e.g. "Monday"
  -- BigQuery's DAYOFWEEK returns 1=Sunday; this shifts it to 1=Monday (ISO standard)
  MOD((EXTRACT(DAYOFWEEK FROM date_key) + 5), 7) + 1 AS day_number_mon1
FROM parsed_dates
WHERE date_key >= DATE '2016-01-01';    -- Filter to relevant date range only