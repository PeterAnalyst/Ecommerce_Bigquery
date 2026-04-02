-- ============================================================
-- REVENUE PER SESSION (RPS) ANALYSIS
-- ============================================================

-- RPS by device category (desktop vs mobile vs tablet)
SELECT
  deviceCategory,
  SUM(sessions) AS total_sessions,
  ROUND(SUM(revenue),2) AS total_revenue,
  ROUND(SUM(revenue)/SUM(sessions), 2) AS rev_per_section
FROM `analytics_portfolio.customer_channel_metrics`
GROUP BY deviceCategory
ORDER BY rev_per_section DESC;

-- RPS by device × channel (identifies best-performing device + source combos)
SELECT
  deviceCategory,
  source,
  SUM(sessions) AS total_sessions,
  ROUND(SUM(revenue),2) AS total_revenue,
  ROUND(SUM(revenue)/SUM(sessions), 2) AS rev_per_section
FROM `analytics_portfolio.customer_channel_metrics`
GROUP BY deviceCategory,source
ORDER BY total_revenue DESC, rev_per_section DESC;

-- RPS by device × user type
SELECT
  deviceCategory,
  users_seg,
  SUM(sessions) AS total_sessions,
  ROUND(SUM(revenue),2) AS total_revenue,
  ROUND(SUM(revenue)/SUM(sessions), 2) AS rev_per_section
FROM `analytics_portfolio.customer_channel_metrics`
GROUP BY deviceCategory,users_seg
ORDER BY rev_per_section DESC;

-- RPS by channel only
-- Includes session and revenue share (%) for each source as a sanity check
SELECT
  source,
  SUM(sessions) AS total_sessions,
  CONCAT(ROUND(SUM(sessions)*100/(SELECT SUM(sessions) 
                                  FROM `analytics_portfolio.customer_channel_metrics`), 2), "%")
                                  AS checking_sessions,
  ROUND(SUM(revenue),2) AS total_revenue,
  CONCAT(ROUND(SUM(revenue)*100/(SELECT SUM(revenue) 
                                  FROM `analytics_portfolio.customer_channel_metrics`), 2), "%")
                                  AS checking_revenue,
  ROUND(SUM(revenue)/SUM(sessions), 2) AS rev_per_section
FROM `analytics_portfolio.customer_channel_metrics`
GROUP BY source
HAVING rev_per_section IS NOT NULL
ORDER BY total_sessions DESC;


-- ============================================================
-- ARPU (AVERAGE REVENUE PER USER) ANALYSIS
-- ============================================================

-- ARPU by device category: how much revenue does each user generate on average per device?
WITH user_device_revenue AS(
  SELECT 
    fullVisitorid AS users,
    device.deviceCategory,
    SUM(totals.totaltransactionRevenue)/1e6 AS revenue  -- Convert from micros to dollars
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_*`
  GROUP BY users,
    device.deviceCategory
)
SELECT 
  deviceCategory,
  COUNT(users) AS num_of_users,
  ROUND(SUM(revenue), 2) AS total_revenue,
  ROUND(SUM(revenue)/COUNT(users), 2) AS ARPU
FROM user_device_revenue
GROUP BY deviceCategory;