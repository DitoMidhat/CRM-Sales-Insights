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
-- PHASE 4: PART-TO-WHOLE ANALYSIS
-- ====================================================

-- 1. How much revenue does each product series contribute to total revenue?
SELECT
    series,
    SUM(close_value) AS revenue,
    ROUND(100.0 * SUM(close_value) / SUM(SUM(close_value)) OVER (), 2) AS percent_of_total
FROM #full_sales_data
WHERE deal_stage = 'Won'
GROUP BY series;

-- 2. What is the revenue share and performance tier of each agent?

SELECT
    sales_agent,
    SUM(close_value) AS total_revenue,
    ROUND(100.0 * SUM(close_value) / SUM(SUM(close_value)) OVER (), 2) AS percent_of_total,
    NTILE(4) OVER (ORDER BY SUM(close_value) DESC) AS performance_tier
FROM #full_sales_data
WHERE deal_stage = 'Won'
GROUP BY sales_agent;


-- 3. What is the revenue contribution split between the USA and other countries?
SELECT
    CASE WHEN office_location = 'United States' THEN 'United States' ELSE 'Other' END AS region,
    SUM(close_value) AS revenue,
    ROUND(100.0 * SUM(close_value) / SUM(SUM(close_value)) OVER (), 2) AS percent_of_total
FROM #full_sales_data
WHERE deal_stage = 'Won'
GROUP BY CASE WHEN office_location = 'United States' THEN 'United States' ELSE 'Other' END;


-- 4. Which products perform best in non-USA locations (deals count, revenue, avg price)?
SELECT
    product,
    COUNT(*) AS won_deals_count,
    SUM(close_value) AS total_revenue,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS deals_pct,
    ROUND(SUM(close_value) * 1.0 / COUNT(*), 2) AS avg_deal_price
FROM #full_sales_data
WHERE office_location != 'United States' AND deal_stage = 'Won'
GROUP BY product
ORDER BY won_deals_count DESC;
