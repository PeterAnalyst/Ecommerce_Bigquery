-- ============================================================
-- USER SEGMENTATION: NEW VS RETURNING
-- ============================================================

-- How do new vs returning users differ in behavior and value?
SELECT 
  users_seg,
  SUM(sessions) AS total_sessions,
  SUM(transactions) AS total_transactions,
  ROUND((SUM(transactions)/SUM(sessions))*100,2) AS conv_rate,
  ROUND(SUM(revenue), 2) AS total_revenue
FROM `analytics_portfolio.customer_channel_metrics`
GROUP BY users_seg;


-- ============================================================
-- DEVICE ANALYSIS
-- ============================================================

-- ------------------------------------------------------------
-- Q3.1 — How does user behavior differ on mobile vs desktop vs tablet?
-- Where is monetization weaker? Where might UX or performance issues exist?
-- ------------------------------------------------------------

-- User segment × device breakdown
SELECT
  users_seg,
  deviceCategory,
  SUM(sessions) AS total_sessions,
  SUM(transactions) AS total_transactions,
  CONCAT(ROUND((SUM(transactions)/SUM(sessions))*100, 2),"%") AS conv_rate,
  ROUND(SUM(revenue), 2) AS total_revenue
  FROM `analytics_portfolio.customer_channel_metrics`
GROUP BY users_seg,
         deviceCategory;

-- Device only (aggregated across all user segments)
SELECT
  deviceCategory,
  SUM(sessions) AS total_sessions,
  SUM(transactions) AS total_transactions,
  CONCAT(ROUND((SUM(transactions)/SUM(sessions))*100, 2),"%") AS conv_rate,
  ROUND(SUM(revenue), 2) AS total_revenue
  FROM `analytics_portfolio.customer_channel_metrics`
GROUP BY deviceCategory;

-- Device × user segment (ordered by device for side-by-side comparison)
SELECT
  deviceCategory,
  users_seg,
  SUM(sessions) AS total_sessions,
  SUM(transactions) AS total_transactions,
  CONCAT(ROUND((SUM(transactions)/SUM(sessions))*100, 2),"%") AS conv_rate,
  ROUND(SUM(revenue), 2) AS total_revenue
  FROM `analytics_portfolio.customer_channel_metrics`
GROUP BY deviceCategory, users_seg
ORDER BY deviceCategory;


-- ------------------------------------------------------------
-- Q3.2 — Business question: Is mobile underperforming across all channels,
-- or are specific acquisition channels causing the problem?
-- ------------------------------------------------------------

-- Version 1
SELECT
  deviceCategory,
  source,
  medium,
  SUM(sessions) AS total_sessions,
  SUM(transactions) AS total_transactions,
  CONCAT(ROUND((SUM(transactions)/SUM(sessions))*100, 2),"%") AS conv_rate,
  ROUND(SUM(revenue), 2) AS total_revenue
  FROM `analytics_portfolio.customer_channel_metrics`
GROUP BY deviceCategory, source, medium
HAVING deviceCategory = "mobile"
ORDER BY total_revenue DESC
LIMIT 15;

-- Version 2 (cleaner formatting, same logic)
SELECT
  deviceCategory,
  source,
  medium,
  SUM(sessions) AS total_sessions,
  SUM(transactions) AS total_transactions,
  CONCAT(ROUND((SUM(transactions)/SUM(sessions))*100, 2),"%") AS conv_rate,
  ROUND(SUM(revenue), 2) AS total_revenue
FROM `analytics_portfolio.customer_channel_metrics`
GROUP BY deviceCategory, source, medium
HAVING deviceCategory = "mobile"
ORDER BY total_revenue DESC
LIMIT 15;