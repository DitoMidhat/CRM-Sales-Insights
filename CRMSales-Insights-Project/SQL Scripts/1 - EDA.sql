USE CRM_sales_data;
-- TEMP TABLE SETUP
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
---------------------------------------------------------------------------------------
-- 1) DB Exploration

SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME != 'sysdiagrams';

---------------------------------------------------------------------------------------

-- 2) Dimensions Exploration

-- Column Types
SELECT TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME != 'sysdiagrams' AND DATA_TYPE = 'nvarchar';

-- Series / Products
SELECT series, product, 
       ROW_NUMBER() OVER (PARTITION BY series ORDER BY series) AS prodNO_by_series
FROM products;

-- Office / Manager / Agent (Hierarchy)
SELECT regional_office, manager, COUNT(DISTINCT sales_agent) AS team_size
FROM teams
GROUP BY regional_office, manager
ORDER BY regional_office, team_size DESC;

SELECT COUNT(DISTINCT account)
FROM accounts;

-- Accounts Count By Sector
SELECT sector, COUNT(*) AS accountsCount
FROM accounts
GROUP BY sector
ORDER BY accountsCount DESC;

-- Accounts Count By OfficeLocation
SELECT office_location, COUNT(*) AS accountsCount
FROM accounts
GROUP BY office_location
ORDER BY accountsCount DESC;

-- Accounts Count By Holding Companies
SELECT subsidiary_of, COUNT(*) AS accountsCount
FROM accounts
WHERE subsidiary_of IS NOT NULL
GROUP BY subsidiary_of
ORDER BY accountsCount DESC;

-- Deals Count By Stage
SELECT deal_stage, COUNT(*) AS deals_count
FROM sales
GROUP BY deal_stage
ORDER BY deals_count DESC;

---------------------------------------------------------------------------------------

-- 3) Date Exploration

-- First & Last Dates
SELECT 
    MIN(engage_date) AS first_engagement, 
    MAX(engage_date) AS last_engagement,
    MIN(close_date) AS first_close, 
    MAX(close_date) AS last_close
FROM sales;

-- Month | Qty | Sales
SELECT DATEPART(MONTH, close_date) AS month_, 
       COUNT(*) AS qty_sold, 
       SUM(close_value) AS total_sales
FROM sales
WHERE deal_stage = 'Won'
GROUP BY DATEPART(MONTH, close_date)
ORDER BY month_;

---------------------------------------------------------------------------------------

-- 4) Measures Exploration

SELECT 'total sales' AS measure_Name, SUM(close_value) AS measure_value 
FROM sales

UNION ALL

SELECT 'qty sold', COUNT(*) 
FROM sales 
WHERE deal_stage = 'Won'

UNION ALL

SELECT 'avg price', AVG(close_value) 
FROM sales

UNION ALL

SELECT 'avg nego days', AVG(DATEDIFF(DAY, engage_date, close_date)) 
FROM sales

UNION ALL

SELECT 'deal win %',
       ROUND(100.0 * 
             SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END) / COUNT(*), 2)
FROM sales
WHERE deal_stage IN ('Won', 'Lost');

---------------------------------------------------------------------------------------

-- 5) Magnitude

ALTER PROCEDURE magnitudeExploration
  @x NVARCHAR(100)
AS
BEGIN
  DECLARE @sql NVARCHAR(MAX);

  SET @sql = '
    SELECT ' + QUOTENAME(@x) + ' AS group_by_value,
           SUM(close_value) AS total_sales,
           COUNT(*) AS qty_sold
    FROM #full_sales_data
    WHERE deal_stage = ''Won''
    GROUP BY ' + QUOTENAME(@x) + '
    ORDER BY total_sales DESC;
  ';

  EXEC sp_executesql @sql;
END;

EXEC magnitudeExploration @x = 'series';
EXEC magnitudeExploration @x = 'product';
EXEC magnitudeExploration @x = 'regional_office';
EXEC magnitudeExploration @x = 'manager';
EXEC magnitudeExploration @x = 'sales_agent';
EXEC magnitudeExploration @x = 'sector';
EXEC magnitudeExploration @x = 'account';
EXEC magnitudeExploration @x = 'office_location';

---------------------------------------------------------------------------------------

-- 6) Ranking

-- SERIES % OF OVERALL SALES
SELECT 
  series,
  SUM(close_value) AS total_sales,
  ROUND(100.0 * SUM(close_value) / 
        (SELECT SUM(close_value) FROM #full_sales_data WHERE deal_stage = 'Won'), 2) AS percent_of_total
FROM #full_sales_data
WHERE deal_stage = 'Won'
GROUP BY series
ORDER BY percent_of_total DESC;

-- TOP 10 AGENTS BY ($)
SELECT TOP 10
  regional_office,
  manager,
  sales_agent,
  SUM(close_value) AS total_sales
FROM #full_sales_data
WHERE deal_stage = 'Won'
GROUP BY regional_office, manager, sales_agent
ORDER BY total_sales DESC;

-- TOP 10 AGENTS BY (close%)
SELECT TOP 10
  regional_office,
  manager,
  sales_agent,
  COUNT(*) AS total_deals,
  SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END) AS won_deals,
  ROUND(100.0 * SUM(CASE WHEN deal_stage = 'Won' THEN 1 ELSE 0 END) / COUNT(*), 2) AS win_rate
FROM #full_sales_data
GROUP BY regional_office, manager, sales_agent
ORDER BY win_rate DESC;

-- LOCATION SALES %
SELECT 
  office_location,
  SUM(close_value) AS total_sales,
  ROUND(100.0 * SUM(close_value) / 
        (SELECT SUM(close_value) FROM #full_sales_data WHERE deal_stage = 'Won'), 2) AS percent_of_total
FROM #full_sales_data
WHERE deal_stage = 'Won'
GROUP BY office_location
ORDER BY percent_of_total DESC;

-- SECTOR SALES %
WITH sector_totals AS (
  SELECT 
    sector,
    SUM(close_value) AS total_sales,
    ROUND(100.0 * SUM(close_value) / 
          (SELECT SUM(close_value) FROM #full_sales_data WHERE deal_stage = 'Won'), 2) AS percent_of_total
  FROM #full_sales_data
  WHERE deal_stage = 'Won'
  GROUP BY sector
)

SELECT
  sector,
  total_sales,
  percent_of_total,
  ROUND(
    100.0 * SUM(total_sales) OVER (ORDER BY percent_of_total DESC ROWS UNBOUNDED PRECEDING) /
    (SELECT SUM(close_value) FROM #full_sales_data WHERE deal_stage = 'Won'),
    2
  ) AS running_percent
FROM sector_totals
ORDER BY percent_of_total DESC;

---------------------------------------------------------------------------------------

-- Checking Nulls
SELECT 
  SUM(CASE WHEN opportunity_id IS NULL THEN 1 ELSE 0 END) AS null_opportunity_id,
  SUM(CASE WHEN sales_agent IS NULL THEN 1 ELSE 0 END) AS null_sales_agent,
  SUM(CASE WHEN manager IS NULL THEN 1 ELSE 0 END) AS null_manager,
  SUM(CASE WHEN regional_office IS NULL THEN 1 ELSE 0 END) AS null_regional_office,
  SUM(CASE WHEN product IS NULL THEN 1 ELSE 0 END) AS null_product,
  SUM(CASE WHEN series IS NULL THEN 1 ELSE 0 END) AS null_series,
  SUM(CASE WHEN sales_price IS NULL THEN 1 ELSE 0 END) AS null_sales_price,
  SUM(CASE WHEN account IS NULL THEN 1 ELSE 0 END) AS null_account,
  SUM(CASE WHEN sector IS NULL THEN 1 ELSE 0 END) AS null_sector,
  SUM(CASE WHEN year_established IS NULL THEN 1 ELSE 0 END) AS null_year_established,
  SUM(CASE WHEN revenue IS NULL THEN 1 ELSE 0 END) AS null_revenue,
  SUM(CASE WHEN employees IS NULL THEN 1 ELSE 0 END) AS null_employees,
  SUM(CASE WHEN office_location IS NULL THEN 1 ELSE 0 END) AS null_office_location,
  SUM(CASE WHEN subsidiary_of IS NULL THEN 1 ELSE 0 END) AS null_subsidiary_of,
  SUM(CASE WHEN deal_stage IS NULL THEN 1 ELSE 0 END) AS null_deal_stage,
  SUM(CASE WHEN engage_date IS NULL THEN 1 ELSE 0 END) AS null_engage_date,
  SUM(CASE WHEN close_date IS NULL THEN 1 ELSE 0 END) AS null_close_date,
  SUM(CASE WHEN close_value IS NULL THEN 1 ELSE 0 END) AS null_close_value
FROM #full_sales_data;