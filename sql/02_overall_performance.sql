-- ============================================================
-- OVERALL PERFORMANCE & HEALTH
-- ============================================================

-- Q1.1 — How are sessions, users, transactions, and revenue evolving over time?
SELECT 
  session_date,
  SUM(sessions) AS total_sessions,
  SUM(users) AS total_users,
  SUM(transactions) AS total_transactions,
  ROUND(SUM(revenue), 2) AS total_revenue
FROM `analytics_portfolio.daily_channel_metrics`
GROUP BY session_date
ORDER BY session_date;


-- ------------------------------------------------------------
-- Q1.2 — What are the daily / weekly / monthly trends in conversion and revenue?
-- ------------------------------------------------------------

-- Version 1: Yearly totals only (simpler aggregation)
WITH full_data AS (
  SELECT 
    FORMAT_DATE("%Y", session_date) AS year,
    FORMAT_DATE("%B", session_date) AS month_name,
    SUM(sessions) AS total_sessions,
    SUM(users) AS total_users,
    SUM(transactions) AS total_transactions,
    ROUND(SUM(revenue), 2) AS total_revenue
  FROM `analytics_portfolio.daily_channel_metrics`
  GROUP BY year,
          month_name)
SELECT 
  year,
  SUM(total_transactions) AS total_transactions,
  SUM(total_sessions) AS total_sessions,
  ROUND(SUM(total_transactions)/ SUM(total_sessions),3) AS conv_rate,
  SUM(total_revenue) AS total_revenue
FROM full_data
GROUP BY 
        year
ORDER BY 
        total_revenue DESC;


-- Version 2: Yearly totals with formatted conversion rate (adds % symbol)
WITH full_data AS (
  SELECT 
    FORMAT_DATE("%Y", session_date) AS year,
    FORMAT_DATE("%B", session_date) AS month_name,
    EXTRACT(MONTH FROM session_date) AS month_num,
    sessions,
    users,
    transactions,
    revenue
  FROM `analytics_portfolio.daily_channel_metrics`
  )
SELECT
  year,
  -- month_num,
  -- month_name,
  SUM(transactions) AS total_transactions,
  SUM(sessions) AS total_sessions,
  CONCAT(ROUND((SUM(transactions)/ SUM(sessions))*100, 2),"%") AS conv_rate,
  ROUND(SUM(revenue)) AS total_revenue
FROM full_data
GROUP BY 
        year
        -- month_num,
        -- month_name
ORDER BY 
        year;


-- Version 3 (final): Yearly + monthly breakdown using GROUPING SETS
-- Returns both yearly totals and monthly breakdowns in a single query
WITH full_data AS (
  SELECT
    FORMAT_DATE('%Y', session_date) AS year,
    FORMAT_DATE('%B', session_date) AS month_name,
    EXTRACT(MONTH FROM session_date) AS month_num,
    sessions,
    transactions,
    revenue
  FROM `analytics_portfolio.daily_channel_metrics`
)

SELECT
  year,
  month_num,
  month_name,
  SUM(transactions) AS total_transactions,
  SUM(sessions) AS total_sessions,
  CONCAT(
    ROUND(SUM(transactions) / SUM(sessions) * 100, 2),
    '%'
  ) AS conv_rate,
  ROUND(SUM(revenue), 2) AS total_revenue
FROM full_data
GROUP BY GROUPING SETS (
  (year),                      -- yearly totals
  (year, month_num, month_name) -- monthly breakdown
)
ORDER BY
  year,
  month_num;


-- Daily trends in conversion and revenue
WITH day_conv_rate AS (
  SELECT
   session_date,
   users,
    sessions,
    transactions,
    revenue
  FROM `analytics_portfolio.daily_channel_metrics`
  )
SELECT 
  session_date,
  SUM(users) AS total_users,
  SUM(sessions) AS total_session,
  SUM(transactions) AS total_transaction,
  CONCAT(
    ROUND(SUM(transactions) / SUM(sessions) * 100, 2),
    '%'
  ) AS conv_rate,
  ROUND(SUM(revenue), 2) AS total_revenue
FROM day_conv_rate
GROUP BY session_date
ORDER BY session_date;


-- Day-of-week performance: which days drive the most revenue and conversions?
WITH day_conv_rate AS (
  SELECT
    FORMAT_DATE('%A', session_date) AS day_name,
    sessions,
    transactions,
    revenue
  FROM `analytics_portfolio.daily_channel_metrics`
  )
SELECT 
  day_name,
  SUM(sessions) AS total_session,
  SUM(transactions) AS total_transaction,
  CONCAT(
    ROUND(SUM(transactions) / SUM(sessions) * 100, 2),
    '%'
  ) AS conv_rate,
  ROUND(SUM(revenue), 2) AS total_revenue
FROM day_conv_rate
GROUP BY day_name
ORDER BY total_revenue DESC;