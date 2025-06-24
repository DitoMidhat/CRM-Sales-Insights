USE CRM_sales_data;
-- TASK 1 – PERFORMANCE REPORT (SALES AGENTS + PRODUCTS)

-- Sales & Product Performance Report
-- Purpose:
-- This report consolidates sales performance metrics for agents and product-level revenue insights.

-- Highlights:
-- 1. Gathers fields such as sales_agent, product, close_date, close_value.
-- 2. Joins with product table to retrieve product details like series and price.
-- 3. Joins with sales_teams to identify manager and regional_office.

-- 4. Aggregates agent-level metrics:
--    - total deals closed
--    - total revenue generated
--    - average deal size
--    - deal win rate (closed deals / total opportunities)
--    - months active (first-close to last-close)
-- 5. Aggregates product-level metrics:
--    - total units sold
--    - total customers
--    - total revenue
--    - average order value (AOV)
--    - revenue tier (High, Mid, Low)
-- 6. Adds KPIs:
--    - recency (months since last sale)
--    - agent performance tier (Top, Mid, Low based on revenue)


ALTER VIEW vw_sales_performance_report AS
WITH sales_base AS (
    SELECT 
        s.sales_agent,
        t.manager,
        t.regional_office,
        s.product,
        p.series,
        p.sales_price,
        s.account,
        s.close_date,
        s.deal_stage,
        s.close_value
    FROM sales s
    LEFT JOIN teams t ON s.sales_agent = t.sales_agent
    LEFT JOIN products p ON s.product = p.product
),
agent_agg AS (
    SELECT 
        sales_agent,
        COUNT(CASE WHEN deal_stage IN ('Won', 'Lost') THEN 1 END) AS won_lost_deals,
        COUNT(CASE WHEN deal_stage = 'Won' THEN 1 END) AS total_deals,
        SUM(CASE WHEN deal_stage = 'Won' THEN close_value ELSE 0 END) AS total_revenue,
        AVG(CASE WHEN deal_stage = 'Won' THEN close_value ELSE NULL END) AS avg_deal_value,
        ROUND(
            100.0 * COUNT(CASE WHEN deal_stage = 'Won' THEN 1 END)
            / NULLIF(COUNT(CASE WHEN deal_stage IN ('Won', 'Lost') THEN 1 END), 0), 
            2
        ) AS win_rate,
        COUNT(DISTINCT FORMAT(CASE WHEN deal_stage = 'Won' THEN close_date END, 'yyyy-MM')) AS months_active,
        COUNT(DISTINCT CASE WHEN deal_stage = 'Won' THEN account END) AS distinct_customers
    FROM sales_base
    GROUP BY sales_agent
),
agent_tier AS (
    SELECT 
        sales_agent,
        NTILE(3) OVER (ORDER BY total_revenue DESC) AS performance_tier -- Top/Mid/Low
    FROM agent_agg
)
SELECT 
    sb.sales_agent,
    sb.manager,
    sb.regional_office,
    sb.product,
    sb.series,
    ag.total_deals,
    ag.total_revenue,
    ag.avg_deal_value,
    ag.win_rate,
    ag.months_active,
    ag.distinct_customers,
    CASE at.performance_tier 
        WHEN 1 THEN 'Top'
        WHEN 2 THEN 'Mid'
        ELSE 'Low'
    END AS agent_performance_tier
FROM sales_base sb
JOIN agent_agg ag ON sb.sales_agent = ag.sales_agent
JOIN agent_tier at ON sb.sales_agent = at.sales_agent;


SELECT TOP 1 *
FROM vw_sales_performance_report;

