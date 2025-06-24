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
-- PHASE 2: CUMULATIVE ANALYSIS
-- ====================================================

-- 1. running total of deals by product.
WITH monthly_product_deals AS (
    SELECT	
        product,
        DATEFROMPARTS(YEAR(close_date), MONTH(close_date), 1) AS month,
        COUNT(*) AS monthly_deals
    FROM #full_sales_data
    WHERE deal_stage = 'Won'
    GROUP BY product, DATEFROMPARTS(YEAR(close_date), MONTH(close_date), 1)
)
SELECT
    product,
    month,
    monthly_deals,
    SUM(monthly_deals) OVER (PARTITION BY product ORDER BY month
) AS cumulative_deals,

    SUM(monthly_deals) OVER (PARTITION BY product) AS total_deals_per_product
FROM monthly_product_deals
ORDER BY total_deals_per_product DESC;


-- 2. Which agents reached $400,000 in cumulative sales the fastest?
WITH revenue_progress AS (
    SELECT
        sales_agent,
        close_date,
        SUM(close_value) OVER (PARTITION BY sales_agent ORDER BY close_date) AS cum_revenue
  FROM #full_sales_data
  WHERE deal_stage = 'Won'
)
SELECT 
	sales_agent, 
	MIN(close_date) AS hit_400k_date
FROM revenue_progress
WHERE cum_revenue >= 400000
GROUP BY sales_agent
ORDER BY hit_400k_date;

-- Darcel Schlecht sold 22% of overall GTX PRO sales
WITH product_deals AS (
  SELECT 
    product,
    CASE 
      WHEN sales_agent = 'Darcel Schlecht' THEN 'Darcel'
      ELSE 'Others'
    END AS agent_type,
    COUNT(*) AS deal_count
  FROM #full_sales_data
  WHERE deal_stage = 'Won'
  GROUP BY product, 
           CASE WHEN sales_agent = 'Darcel Schlecht' THEN 'Darcel' ELSE 'Others' END
)
SELECT
  p.product,
  MAX(CASE WHEN p.agent_type = 'Darcel' THEN p.deal_count ELSE 0 END) AS darcel_deals,
  MAX(CASE WHEN p.agent_type = 'Others' THEN p.deal_count ELSE 0 END) AS other_deals,
  ROUND(
    100.0 * MAX(CASE WHEN p.agent_type = 'Darcel' THEN p.deal_count ELSE 0 END) / 
    NULLIF(SUM(p.deal_count), 0),
    2
  ) AS darcel_pct
FROM product_deals p
GROUP BY p.product
ORDER BY darcel_pct DESC;
-----------------------------------------------------------------------------

-- 3. How many unique accounts have been acquired cumulatively over time?
WITH monthly_first_time_customers AS (
    SELECT
        account,
        DATEFROMPARTS(YEAR(MIN(close_date)), MONTH(MIN(close_date)), 1) AS first_deal_month
  FROM #full_sales_data
  WHERE deal_stage = 'Won'
  GROUP BY account
)
SELECT
    FORMAT(first_deal_month, 'yy-MM') AS month,
    COUNT(*) AS new_customers_this_month,
    SUM(COUNT(*)) OVER (ORDER BY first_deal_month) AS total_customers_to_date
FROM monthly_first_time_customers
GROUP BY first_deal_month
ORDER BY first_deal_month;