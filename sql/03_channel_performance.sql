-- ============================================================
-- ACQUISITION & CHANNEL PERFORMANCE
-- ============================================================

-- Q2.0 — Full channel metrics snapshot
SELECT
  *
FROM `analytics_portfolio.daily_channel_metrics`;


-- ------------------------------------------------------------
-- Q2.1 — Volume: which channels attract the most traffic?
-- ------------------------------------------------------------

-- Which channels generate the most sessions?
SELECT
  source,
  medium,
  SUM(sessions) AS total_session,
FROM `analytics_portfolio.daily_channel_metrics`
GROUP BY source, medium
ORDER BY total_session DESC
LIMIT 10;

-- Which channels bring the most users?
SELECT
  source,
  medium,
  SUM(users) AS total_users,
FROM `analytics_portfolio.daily_channel_metrics`
GROUP BY source, medium
ORDER BY total_users DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Q2.2 — Value: which channels generate the most revenue and transactions?
-- ------------------------------------------------------------

-- Which channels generate the most revenue?
SELECT
  source,
  medium,
  SUM(transactions) AS total_transaction,
  ROUND(SUM(revenue), 2) AS total_revenue
FROM `analytics_portfolio.daily_channel_metrics`
GROUP BY source, medium
ORDER BY total_revenue DESC
LIMIT 10;

-- Which channels drive the most transactions?
SELECT
  source,
  medium,
  SUM(transactions) AS total_transaction
FROM `analytics_portfolio.daily_channel_metrics`
GROUP BY source, medium
ORDER BY total_transaction DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Q2.3 — Efficiency: which channels convert best and deliver most value per session?
-- ------------------------------------------------------------

-- Which channels convert best? (highest session-to-transaction rate)
SELECT
  source,
  medium,
  SUM(sessions) AS total_session,
  SUM(transactions) AS total_transaction,
  ROUND((SUM(transactions)/SUM(sessions))* 100, 2) AS conv_rate
FROM `analytics_portfolio.daily_channel_metrics`
GROUP BY source, medium
ORDER BY conv_rate DESC, total_session DESC, total_transaction DESC
LIMIT 20;

-- Which channels deliver higher value per interaction? (revenue per session)
SELECT
  source,
  medium,
  SUM(sessions) AS total_session,
  ROUND(SUM(revenue), 2) AS total_revenue,
  ROUND(SUM(revenue)/SUM(sessions), 2) AS value_per_interaction
FROM `analytics_portfolio.daily_channel_metrics`
GROUP BY source, medium
ORDER BY alue_per_interaction DESC
LIMIT 20;