USE CRM_sales_data;

-- ====================================================
-- TEMP TABLE SETUP
-- ====================================================
SELECT
    s.opportunity_id,
    s.sales_agent,
    t.manager,
    t.regional_office,
    s.product,
    p.series,
    p.sales_price,
    s.account,
    a.sector,
    a.year_established,
    a.revenue,
    a.employees,
    a.office_location,
    a.subsidiary_of,
    s.deal_stage,
    s.engage_date,
    s.close_date,
    s.close_value
INTO #full_sales_data
FROM sales s
LEFT JOIN teams t ON s.sales_agent = t.sales_agent
LEFT JOIN products p ON s.product = p.product
LEFT JOIN accounts a ON s.account = a.account;

-- ====================================================
-- PHASE 1: CHANGE OVER TIME ANALYSIS
-- ====================================================

-- 1. How did revenue and deal volume change month-over-month, and what is the monthly growth rate?
SELECT
    FORMAT(close_date, 'yy-MM') AS 'month',
    COUNT(*) AS deals_closed,
    SUM(close_value) AS revenue,
    LAG(SUM(close_value)) OVER (ORDER BY FORMAT(close_date, 'yy-MM')) AS prev_month_revenue,
    SUM(close_value) - LAG(SUM(close_value)) OVER (ORDER BY FORMAT(close_date, 'yy-MM')) AS change,
    ROUND(100.0 * (SUM(close_value) - LAG(SUM(close_value)) OVER (ORDER BY FORMAT(close_date, 'yy-MM')))
    / NULLIF(LAG(SUM(close_value)) OVER (ORDER BY FORMAT(close_date, 'yy-MM')), 0), 2) AS percent_growth
FROM #full_sales_data
WHERE deal_stage = 'Won'
GROUP BY FORMAT(close_date, 'yy-MM');


-- 2. What is the monthly sales performance of each product series, and how much does each contribute to that month’s total?
SELECT
  FORMAT(close_date, 'yy-MM') AS month,
  series,
  SUM(close_value) AS revenue,
  FORMAT(100.0 * SUM(close_value) / SUM(SUM(close_value)) 
	OVER (PARTITION BY FORMAT(close_date, 'yy-MM')), 'N2') + '%' AS monthly_series_pct
FROM #full_sales_data
WHERE deal_stage = 'Won'
GROUP BY FORMAT(close_date, 'yy-MM'), series;
-- Examine customer sector preferences — who buys GTK, and why?

-- 3. Monthly Office Sales (Ranked)
SELECT
  FORMAT(close_date, 'yy-MM') AS month,	
  regional_office,
  SUM(close_value) AS revenue,
  FORMAT(100.0 * SUM(close_value) / SUM(SUM(close_value)) OVER (PARTITION BY FORMAT(close_date, 'yy-MM')), 'N2') + '%' AS monthly_contribution_pct,
  RANK() OVER (PARTITION BY FORMAT(close_date, 'yy-MM') ORDER BY SUM(close_value) DESC) AS monthly_rank
FROM #full_sales_data
WHERE deal_stage = 'Won'
GROUP BY regional_office, FORMAT(close_date, 'yy-MM');

-- 4. Won Deals % By Quarter
SELECT 
  DATEPART(QUARTER, close_date) AS Quar,
  COUNT(CASE WHEN deal_stage = 'Won' THEN 1 END) * 100.0 / 
  COUNT(CASE WHEN deal_stage IN ('Won', 'Lost') THEN 1 END) AS Close_Percentage
FROM #full_sales_data
WHERE deal_stage IN ('Won', 'Lost') AND close_date IS NOT NULL
GROUP BY DATEPART(QUARTER, close_date)
ORDER BY Quar;
