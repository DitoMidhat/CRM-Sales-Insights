-- Building Relationships

USE CRM_sales_data;
GO

-- Fixing The Typo
SELECT DISTINCT s.product
FROM sales s
LEFT JOIN products p ON s.product = p.product
WHERE p.product IS NULL;

UPDATE sales
SET product = 'GTX Pro'
WHERE product = 'GTXPro';
GO

-- Relationship: sales.sales_agent → teams.sales_agent
ALTER TABLE sales
ADD CONSTRAINT FK_sales_teams
FOREIGN KEY (sales_agent)
REFERENCES teams(sales_agent);
GO

-- Relationship: sales.product → products.product
ALTER TABLE sales
ADD CONSTRAINT FK_sales_products
FOREIGN KEY (product)
REFERENCES products(product);
GO

-- Relationship: sales.account → accounts.account
ALTER TABLE sales
ADD CONSTRAINT FK_sales_accounts
FOREIGN KEY (account)
REFERENCES accounts(account);
GO