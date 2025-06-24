USE CRM_sales_data;

-- TASK 2 – CUSTOMER VALUE REPORT (ACCOUNTS)

-- Customer Value Report (Accounts)
-- Purpose:
-- This report analyzes account behavior, lifetime value, and segmentation.

-- Highlights:
-- 1. Gathers essential fields: account, sector, year_established, revenue, employees.
-- 2. Joins with sales_pipeline to analyze all opportunities by account.
-- 3. Aggregates account-level metrics:
--    - total deals
--    - total revenue
--    - number of products purchased
--    - number of unique sales agents engaged
--    - months active (first engagement to last close)
-- 4. Calculates customer KPIs:
--    - recency (months since last order)
--    - average deal value
--    - average monthly spend
--    - customer tier (VIP, Regular, New) based on revenue and frequency
-- 5. Adds enrichment fields from accounts table:
--    - sector, year_established, revenue band, office_location
--    - whether it’s a subsidiary

CREATE VIEW vw_customer_value_report AS
WITH sales_base AS (
    SELECT 
        s.account,
        s.product,
        s.sales_agent,
        s.engage_date,
        s.close_date,
        s.deal_stage,
        s.close_value
    FROM sales s
),
account_agg AS (
    SELECT 
        s.account,
        COUNT(*) AS total_deals,
        COUNT(DISTINCT s.product) AS products_bought,
        COUNT(DISTINCT s.sales_agent) AS agents_engaged,
        SUM(CASE WHEN s.deal_stage = 'Won' THEN s.close_value ELSE 0 END) AS total_revenue,
        AVG(CASE WHEN s.deal_stage = 'Won' THEN s.close_value ELSE NULL END) AS avg_deal_value,
        DATEDIFF(MONTH, MIN(s.engage_date), MAX(s.close_date)) + 1 AS months_active,
        DATEDIFF(MONTH, MAX(s.close_date), GETDATE()) AS months_since_last_order
    FROM sales_base s
    GROUP BY s.account
),
account_tiers AS (
    SELECT
        account,
        CASE 
            WHEN total_revenue >= 100000 THEN 'VIP'
            WHEN total_revenue >= 30000 THEN 'Regular'
            ELSE 'New'
        END AS customer_tier,
        ROUND(IIF(months_active > 0, total_revenue * 1.0 / months_active, NULL), 2) AS avg_monthly_spend
    FROM account_agg
)
SELECT 
    a.account,
    a.sector,
    a.year_established,
    a.revenue,
    a.employees,
    a.office_location,
    a.subsidiary_of,
    aa.total_deals,
    aa.products_bought,
    aa.agents_engaged,
    aa.total_revenue,
    aa.avg_deal_value,
    aa.months_active,
    aa.months_since_last_order,
    at.avg_monthly_spend,
    at.customer_tier
FROM accounts a
JOIN account_agg aa ON a.account = aa.account
JOIN account_tiers at ON a.account = at.account;
