USE CRM_sales_data;

CREATE VIEW vw_advanced_sales_insights AS
WITH sales_base AS (
  SELECT
    s.sales_agent,
    t.manager,
    t.regional_office,
    s.product,
    p.series,
    s.account,
    a.sector,
    s.deal_stage,
    s.engage_date,
    s.close_date,
    s.close_value
  FROM sales s
  LEFT JOIN teams t ON s.sales_agent = t.sales_agent
  LEFT JOIN products p ON s.product = p.product
  LEFT JOIN accounts a ON s.account = a.account
),
monthly_metrics AS (
  SELECT
    FORMAT(close_date, 'yyyy-MM') AS month,
    sales_agent,
    regional_office,
    product,
    series,
    COUNT(*) AS deals_closed,
    SUM(CASE WHEN deal_stage = 'Won' THEN close_value ELSE 0 END) AS revenue
  FROM sales_base
  WHERE deal_stage = 'Won'
  GROUP BY FORMAT(close_date, 'yyyy-MM'), sales_agent, regional_office, product, series
),
monthly_growth AS (
  SELECT
    month,
    sales_agent,
    revenue,
    LAG(revenue) OVER (PARTITION BY sales_agent ORDER BY month) AS prev_month_revenue,
    CASE 
      WHEN LAG(revenue) OVER (PARTITION BY sales_agent ORDER BY month) = 0 THEN NULL
      ELSE (revenue - LAG(revenue) OVER (PARTITION BY sales_agent ORDER BY month)) * 100.0 
            / LAG(revenue) OVER (PARTITION BY sales_agent ORDER BY month)
    END AS revenue_growth_pct
  FROM monthly_metrics
),
cumulative_sales AS (
  SELECT
    sales_agent,
    product,
    SUM(revenue) OVER (PARTITION BY sales_agent ORDER BY month ROWS UNBOUNDED PRECEDING) AS cum_revenue,
    SUM(deals_closed) OVER (PARTITION BY sales_agent ORDER BY month ROWS UNBOUNDED PRECEDING) AS cum_deals
  FROM monthly_metrics
)
SELECT
  mg.month,
  mg.sales_agent,
  mb.regional_office,
  mg.revenue,
  mg.prev_month_revenue,
  mg.revenue_growth_pct,
  cs.cum_revenue,
  cs.cum_deals
FROM monthly_growth mg
JOIN monthly_metrics mb ON mg.month = mb.month AND mg.sales_agent = mb.sales_agent
JOIN cumulative_sales cs ON cs.sales_agent = mg.sales_agent AND cs.product = mb.product;

SELECT *
FROM vw_advanced_sales_insights;
