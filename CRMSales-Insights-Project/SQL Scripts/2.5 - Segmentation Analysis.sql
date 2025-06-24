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
-- PHASE 5: SEGMENTATION ANALYSIS
-- ====================================================

-- 1. Sales-Agents Segmentation [Quartiles-Based]
--    - Segment agents into 4 performance tiers based on their total revenue.
--    - Exclude Darcel Schlecht from quartile calc (he's an outlier)

SELECT 
    sales_agent,
    total_revenue,
    CASE 
        WHEN sales_agent = 'Darcel Schlecht' THEN 'Top Performer'
        WHEN NTILE(4) OVER (ORDER BY total_revenue DESC) = 1 THEN 'Top Performer'
        WHEN NTILE(4) OVER (ORDER BY total_revenue DESC) = 2 THEN 'Strong Performer'
        WHEN NTILE(4) OVER (ORDER BY total_revenue DESC) = 3 THEN 'Developing Performer'
        ELSE 'Needs Improvement'
    END AS agent_segment
FROM (
    SELECT 
        sales_agent, 
        SUM(close_value) AS total_revenue
    FROM #full_sales_data
    WHERE deal_stage = 'Won'
    GROUP BY sales_agent
) AS agg;



-- 2. Customers Segmentation 
------ Based on Location & Closed Deals Count "Using statistical thresholds (AVG, STDEV)"
------ 6 SEGMENTS -> [US-VIP, US-Regular, US-Emerging, Non-US-VIP, Non-US-Regular, Non-US-Emerging]

-- Count of closed deals for each account with their location
WITH account_deal_counts AS (
  SELECT 
    f.account,
    a.office_location,
    COUNT(*) AS won_deals
  FROM #full_sales_data f
  LEFT JOIN accounts a ON f.account = a.account
  WHERE f.deal_stage = 'Won'
  GROUP BY f.account, a.office_location
),

-- Calculate average & standard deviation of won deals per region (US vs. Non-US)
stats AS (
  SELECT
    CASE WHEN office_location = 'United States' THEN 'US' ELSE 'Non-US' END AS region,
    AVG(won_deals * 1.0) AS avg_deals,
    STDEV(won_deals * 1.0) AS std_deals
  FROM account_deal_counts
  GROUP BY CASE WHEN office_location = 'United States' THEN 'US' ELSE 'Non-US' END
),

-- Segment accounts based on statistical thresholds within their region
-- VIP       → deals >= avg + std
-- Emerging  → deals <= avg - std
-- Regular   → in between
segmented AS (
  SELECT 
    adc.account,
    adc.office_location,
    adc.won_deals,
    CASE 
      WHEN adc.office_location = 'United States' THEN 'US'
      ELSE 'Non-US'
    END AS region,
    s.avg_deals,
    s.std_deals,
    CASE 
      WHEN adc.won_deals >= s.avg_deals + s.std_deals THEN region + ' VIP'
      WHEN adc.won_deals <= s.avg_deals - s.std_deals THEN region + ' Emerging'
      ELSE region + ' Regular'
    END AS customer_segment
  FROM account_deal_counts adc
  JOIN stats s 
    ON (CASE WHEN adc.office_location = 'United States' THEN 'US' ELSE 'Non-US' END) = s.region
)

-- Final Output
SELECT 
  account,
  office_location,
  won_deals,
  customer_segment
FROM segmented
ORDER BY customer_segment, won_deals;





