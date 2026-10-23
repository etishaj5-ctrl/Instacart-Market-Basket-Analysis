-- =====================================================================
-- INSTACART MARKET BASKET ANALYSIS  (MySQL 8.0+)
-- ---------------------------------------------------------------------
-- Data source : "Instacart Market Basket Analysis" dataset (Kaggle)
-- Sample used : 5,000 users with ALL of their 'prior' orders
--               = 77,862 orders and 778,814 order lines
-- Notes       : * order_dow: the dataset does not say which weekday is 0
--                 (day 0 is commonly assumed to be Sunday)
--               * days_since_prior_order is capped at 30 (30 means "30+")
--               * every user has at least 3 prior orders
-- 
-- =====================================================================


-- =====================================================================
-- SECTION 1: DATABASE AND TABLES
-- =====================================================================
CREATE DATABASE IF NOT EXISTS instacart;
USE instacart;

CREATE TABLE IF NOT EXISTS departments (
    department_id INT PRIMARY KEY,
    department    VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS aisles (
    aisle_id INT PRIMARY KEY,
    aisle    VARCHAR(200)
);

CREATE TABLE IF NOT EXISTS products (
    product_id    INT PRIMARY KEY,
    product_name  VARCHAR(300),
    aisle_id      INT,
    department_id INT
);

CREATE TABLE IF NOT EXISTS orders_sample (
    order_id               INT PRIMARY KEY,
    user_id                INT,
    eval_set               VARCHAR(10),
    order_number           INT,
    order_dow              TINYINT,
    order_hour_of_day      TINYINT,
    days_since_prior_order DECIMAL(4,1)
);

CREATE TABLE IF NOT EXISTS order_products_sample (
    order_id          INT,
    product_id        INT,
    add_to_cart_order INT,
    reordered         TINYINT,
    PRIMARY KEY (order_id, product_id)
);


-- =====================================================================
-- SECTION 2: LOAD THE CSV FILES
-- Change /path/to/data/ to the folder that holds your CSV files.
-- =====================================================================
SET GLOBAL local_infile = 1;
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE departments;
LOAD DATA LOCAL INFILE '/path/to/data/departments.csv'
INTO TABLE departments
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- aisles.csv has Windows line endings (\r\n), so it needs '\r\n' here
TRUNCATE TABLE aisles;
LOAD DATA LOCAL INFILE '/path/to/data/aisles.csv'
INTO TABLE aisles
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

TRUNCATE TABLE products;
LOAD DATA LOCAL INFILE '/path/to/data/products_clean_v2.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- days_since_prior_order is blank for each user's first order.
-- NULLIF turns blank into NULL (otherwise MySQL stores 0).
TRUNCATE TABLE orders_sample;
LOAD DATA LOCAL INFILE '/path/to/data/orders_sample.csv'
INTO TABLE orders_sample
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, user_id, eval_set, order_number, order_dow, order_hour_of_day, @days)
SET days_since_prior_order = NULLIF(@days, '');

TRUNCATE TABLE order_products_sample;
LOAD DATA LOCAL INFILE '/path/to/data/order_products_sample.csv'
INTO TABLE order_products_sample
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SET FOREIGN_KEY_CHECKS = 1;


-- =====================================================================
-- SECTION 3: INDEXES AND FOREIGN KEYS  (run ONCE only)
-- If you get "Duplicate key name" or "Duplicate foreign key", it was
-- already added: skip it.
-- =====================================================================
CREATE INDEX idx_op_product ON order_products_sample (product_id);

ALTER TABLE products
    ADD CONSTRAINT fk_products_aisle FOREIGN KEY (aisle_id)      REFERENCES aisles (aisle_id),
    ADD CONSTRAINT fk_products_dept  FOREIGN KEY (department_id) REFERENCES departments (department_id);

ALTER TABLE order_products_sample
    ADD CONSTRAINT fk_op_order   FOREIGN KEY (order_id)   REFERENCES orders_sample (order_id),
    ADD CONSTRAINT fk_op_product FOREIGN KEY (product_id) REFERENCES products (product_id);


-- =====================================================================
-- SECTION 4: DATA QUALITY CHECKS
-- =====================================================================

-- 4.1 Row counts  (expected: 77862 / 778814 / 49688 / 134 / 21)
SELECT 'orders_sample' AS table_name, COUNT(*) AS row_count FROM orders_sample
UNION ALL SELECT 'order_products_sample', COUNT(*) FROM order_products_sample
UNION ALL SELECT 'products',              COUNT(*) FROM products
UNION ALL SELECT 'aisles',                COUNT(*) FROM aisles
UNION ALL SELECT 'departments',           COUNT(*) FROM departments;

-- 4.2 Order lines with no matching order  (expected: 0)
SELECT COUNT(*) AS orphan_order_lines
FROM order_products_sample op
LEFT JOIN orders_sample o ON op.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 4.3 Orders with no items  (expected: 0)
SELECT COUNT(*) AS orders_without_items
FROM orders_sample o
LEFT JOIN order_products_sample op ON o.order_id = op.order_id
WHERE op.order_id IS NULL;

-- 4.4 Order lines with an unknown product  (expected: 0)
SELECT COUNT(*) AS orphan_products
FROM order_products_sample op
LEFT JOIN products p ON op.product_id = p.product_id
WHERE p.product_id IS NULL;

-- 4.5 NULL gaps = first orders  (expected: 5000 and 5000)
SELECT SUM(days_since_prior_order IS NULL) AS null_gap_orders,
       SUM(order_number = 1)               AS first_orders
FROM orders_sample;

-- 4.6 Hidden carriage-return characters in aisle names  (expected: 0)
SELECT COUNT(*) AS aisles_with_hidden_cr
FROM aisles
WHERE RIGHT(aisle, 1) = CHAR(13);


-- =====================================================================
-- SECTION 5: ANALYSIS QUERIES
-- =====================================================================

-- Q1. Which departments drive the most order volume?
SELECT
    d.department,
    COUNT(*) AS total_order_lines,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM order_products_sample), 2) AS pct_of_order_lines
FROM order_products_sample op
JOIN products p    ON op.product_id = p.product_id
JOIN departments d ON p.department_id = d.department_id
GROUP BY d.department
ORDER BY total_order_lines DESC;

-- Q2. Which products have the highest reorder rate?
-- Only products ordered at least 200 times, so a few lucky orders
-- cannot give a fake 100% rate.
SELECT
    p.product_id,
    p.product_name,
    COUNT(*)           AS times_ordered,
    SUM(op.reordered)  AS times_reordered,
    ROUND(SUM(op.reordered) * 100.0 / COUNT(*), 2) AS reorder_rate_pct
FROM order_products_sample op
JOIN products p ON op.product_id = p.product_id
GROUP BY p.product_id, p.product_name
HAVING COUNT(*) >= 200
ORDER BY reorder_rate_pct DESC
LIMIT 10;

-- Q3. Overall reorder rate and average basket size
SELECT
    ROUND(SUM(reordered) * 100.0 / COUNT(*), 2)       AS overall_reorder_rate_pct,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT order_id), 2) AS avg_basket_size
FROM order_products_sample;

-- Q4a. Orders by day of week and hour (day 0 = assumed Sunday)
SELECT
    order_dow,
    order_hour_of_day,
    COUNT(*) AS total_orders
FROM orders_sample
GROUP BY order_dow, order_hour_of_day
ORDER BY order_dow, order_hour_of_day;

-- Q4b. Busiest hours
SELECT order_hour_of_day, COUNT(*) AS total_orders
FROM orders_sample
GROUP BY order_hour_of_day
ORDER BY total_orders DESC;

-- Q4c. Busiest days (day 0 = assumed Sunday)
SELECT order_dow, COUNT(*) AS total_orders
FROM orders_sample
GROUP BY order_dow
ORDER BY total_orders DESC;

-- Q5. How often do customers come back?
-- days_since_prior_order is capped at 30, so 30 means "30 or more days".
SELECT
    ROUND(AVG(days_since_prior_order), 2) AS avg_days_between_orders,
    SUM(days_since_prior_order = 30)      AS orders_30_plus_days,
    ROUND(SUM(days_since_prior_order = 30) * 100.0 / COUNT(*), 1) AS pct_30_plus_days
FROM orders_sample
WHERE days_since_prior_order IS NOT NULL;

-- Q6. Customer segments by number of orders placed
WITH user_orders AS (
    SELECT user_id, MAX(order_number) AS total_orders
    FROM orders_sample
    GROUP BY user_id
)
SELECT
    CASE WHEN total_orders <= 5  THEN '1. Light (3-5 orders)'
         WHEN total_orders <= 15 THEN '2. Regular (6-15 orders)'
         ELSE                         '3. Loyal (16+ orders)'
    END AS segment,
    COUNT(*) AS users,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)          AS pct_of_users,
    SUM(total_orders) AS orders_placed,
    ROUND(SUM(total_orders) * 100.0 / SUM(SUM(total_orders)) OVER (), 1) AS pct_of_orders
FROM user_orders
GROUP BY segment
ORDER BY segment;

-- Q7. Basket size distribution
SELECT basket_size, COUNT(*) AS num_orders
FROM (
    SELECT order_id, COUNT(*) AS basket_size
    FROM order_products_sample
    GROUP BY order_id
) AS order_totals
GROUP BY basket_size
ORDER BY basket_size;

-- Q8. Top 10 aisles by share of all order lines
SELECT
    a.aisle,
    COUNT(*) AS order_lines,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM order_products_sample), 2) AS pct_of_order_lines
FROM order_products_sample op
JOIN products p ON op.product_id = p.product_id
JOIN aisles a   ON p.aisle_id = a.aisle_id
GROUP BY a.aisle
ORDER BY order_lines DESC
LIMIT 10;

-- Q9. Reorder rate by department
SELECT
    d.department,
    COUNT(*) AS order_lines,
    ROUND(SUM(op.reordered) * 100.0 / COUNT(*), 2) AS reorder_rate_pct
FROM order_products_sample op
JOIN products p    ON op.product_id = p.product_id
JOIN departments d ON p.department_id = d.department_id
GROUP BY d.department
ORDER BY reorder_rate_pct DESC;

-- Q10. Top 5 products in each department (window function)
WITH product_sales AS (
    SELECT d.department, p.product_id, p.product_name, COUNT(*) AS order_lines
    FROM order_products_sample op
    JOIN products p    ON op.product_id = p.product_id
    JOIN departments d ON p.department_id = d.department_id
    GROUP BY d.department, p.product_id, p.product_name
),
ranked AS (
    SELECT department, product_name, order_lines,
           RANK() OVER (PARTITION BY department ORDER BY order_lines DESC) AS rank_in_dept
    FROM product_sales
)
SELECT department, rank_in_dept, product_name, order_lines
FROM ranked
WHERE rank_in_dept <= 5
ORDER BY department, rank_in_dept;

-- Q11. Pareto: how many products make up 80% of all order lines?
WITH product_lines AS (
    SELECT product_id, COUNT(*) AS order_lines
    FROM order_products_sample
    GROUP BY product_id
),
cumulative AS (
    SELECT product_id, order_lines,
           SUM(order_lines) OVER (ORDER BY order_lines DESC, product_id) AS running_lines,
           SUM(order_lines) OVER ()                                      AS total_lines
    FROM product_lines
)
SELECT
    COUNT(*) AS products_making_up_80pct,
    (SELECT COUNT(*) FROM product_lines) AS products_ordered,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM product_lines), 1) AS pct_of_products
FROM cumulative
WHERE running_lines <= 0.8 * total_lines;
