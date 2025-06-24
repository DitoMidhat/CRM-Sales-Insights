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
-- PHASE 3: PERFORMANCE ANALYSIS
-- ====================================================

-- 1. Who are the top-performing sales agents by total revenue?
SELECT
    sales_agent,
    SUM(close_value) AS total_revenue,
    RANK() OVER (ORDER BY SUM(close_value) DESC) AS revenue_rank
FROM #full_sales_data
WHERE deal_stage = 'Won'
GROUP BY sales_agent;


-- 2. What is the deal win rate for each manager and regional office?
SELECT
    regional_office,
    manager,
    COUNT(*) AS total_deals,
    SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END) AS won_deals,
    ROUND(100.0 * SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END) / COUNT(*), 2) AS win_rate
FROM #full_sales_data
WHERE deal_stage IN ('Won', 'Lost')
GROUP BY regional_office, manager
ORDER BY win_rate DESC;


-- 3. Which sectors generate the most revenue and have the highest average deal value?
SELECT
    sector,
    AVG(close_value) AS avg_deal_value,
    SUM(close_value) AS total_revenue,
    FORMAT(100.0 * SUM(close_value) / SUM(SUM(close_value)) OVER (),'N2') + '%' AS percent_of_total,
    RANK() OVER (ORDER BY SUM(close_value) DESC) AS sector_revenue_rank
FROM #full_sales_data
WHERE deal_stage = 'Won'
GROUP BY sector;


-- 4. What is the average negotiation duration per agent (engage-to-close days)?
SELECT
    sales_agent,
    AVG(DATEDIFF(DAY, engage_date, close_date)) AS avg_negotiation_days
FROM #full_sales_data
WHERE deal_stage = 'Won'
GROUP BY sales_agent
ORDER BY avg_negotiation_days;


-- 5. What is the win conversion rate per client account?
SELECT
    account,
    sector,
    COUNT(*) AS total_deals,
    SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END) AS won_deals,
    ROUND(100.0 * SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END) / COUNT(*), 2) AS win_rate
FROM #full_sales_data
WHERE deal_stage IN ('Won', 'Lost')
GROUP BY account, sector
ORDER BY win_rate DESC;


-- 6. How much do sectors spend on average, and how frequently do they place deals?
SELECT
    sector,
    COUNT(DISTINCT account) AS customers,
    COUNT(*) AS total_deals,
    SUM(close_value) AS revenue,
    AVG(close_value) AS avg_spend,
    CAST(COUNT(*) * 1.0 / COUNT(DISTINCT account) AS DECIMAL(5,2)) AS deal_frequency
FROM #full_sales_data
WHERE deal_stage = 'Won'
GROUP BY sector
ORDER BY total_deals DESC;