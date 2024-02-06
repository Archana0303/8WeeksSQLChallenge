--A 1. Data Cleansing Steps
-- In a single query, perform the following operations and generate a new table in the data_mart schema named clean_weekly_sales:
DROP TABLE IF EXISTS data_mart.clean_weekly_sales;
 CREATE TABLE data_mart.clean_weekly_sales AS
 SELECT 
   TO_DATE(week_date, 'dd/mm/yy') AS week_date,
   EXTRACT(week FROM TO_DATE(week_date, 'dd/mm/yy')) AS week_number,
   EXTRACT(MONTH FROM TO_DATE(week_date, 'dd/mm/yy')) AS month_number,
   EXTRACT(YEAR FROM TO_DATE(week_date, 'dd/mm/yy')) AS calendar_year,
   region,
   platform,
   segment,
   customer_type,
   (
     CASE
       WHEN RIGHT(segment, 1) = '1' THEN 'Young Adults'
       WHEN RIGHT(segment, 1) = '2' THEN 'Middle Aged'
       WHEN RIGHT(segment, 1) in ('3', '4') THEN 'Retirees'
       ELSE 'unknown'
     END
   ) AS age_band,
   (
     CASE
       WHEN LEFT(segment, 1) = 'C' THEN 'Couples'
       WHEN LEFT(segment, 1) = 'F' THEN 'Families'
       ELSE 'unknown'
     END
   ) AS demographic,
   transactions,
   sales,
   ROUND(sales::NUMERIC/transactions, 2) AS avg_transaction
 FROM data_mart.weekly_sales;
 
 select * from data_mart.clean_weekly_sales
 limit 10;
 
 -- 2. Data Exploration

--Q1. What day of the week is used for each week_date value?
 SELECT DISTINCT TO_CHAR(week_date,'DAY') AS day_of_week
 from data_mart.clean_weekly_sales;
 
 --Q2. What range of week numbers are missing from the dataset?
SELECT * FROM GENERATE_SERIES(1,53) AS missing_week_numbers
WHERE missing_week_numbers NOT IN (
  SELECT DISTINCT cws.week_number FROM data_mart.clean_weekly_sales cws
) 
ORDER BY missing_week_numbers;

--Q3. How many total transactions were there for each year in the dataset?
SELECT calendar_year,
       SUM(transactions) AS Total_Transaction
FROM data_mart.clean_weekly_sales
GROUP BY calendar_year
ORDER BY calendar_year;

--Q4. What is the total sales for each region for each month?
SELECT region, 
       TO_CHAR(week_date,'Month') AS Months,
       SUM(sales) AS Total_Sales
FROM data_mart.clean_weekly_sales
GROUP BY region, Months
ORDER BY region, Months;

--Q5. What is the total count of transactions for each platform
SELECT platform,
       COUNT(transactions) AS Total_NO_Transaction
FROM data_mart.clean_weekly_sales
GROUP BY platform
ORDER BY platform;

--Q6. What is the percentage of sales for Retail vs Shopify for each month?
SELECT calendar_year,
TO_CHAR(week_date,'MONTH') AS Months,
ROUND(100*SUM(CASE WHEN platform = 'Retail' THEN sales::NUMERIC END)/
      SUM(sales),2) AS Retail_Sales,
ROUND(100*SUM(CASE WHEN platform = 'Shopify' THEN sales::NUMERIC END)/
      SUM(sales),2) AS Shopify_Sales
FROM data_mart.clean_weekly_sales
GROUP BY calendar_year, Months
ORDER BY calendar_year, Months;

-- Q7. What is the percentage of sales by demographic for each year in the dataset?
SELECT calendar_year,
ROUND(100*SUM(CASE WHEN demographic = 'Couples' THEN sales::NUMERIC END)/
      SUM(sales),2) AS couple_Sales,
ROUND(100*SUM(CASE WHEN demographic = 'Families' THEN sales::NUMERIC END)/
      SUM(sales),2) AS family_Sales,
ROUND(100*SUM(CASE WHEN demographic = 'unknown' THEN sales::NUMERIC END)/
      SUM(sales),2) AS unknown_Sales
FROM data_mart.clean_weekly_sales
GROUP BY calendar_year
ORDER BY calendar_year;

--Q8. Which age_band and demographic values contribute the most to Retail sales?
WITH retail_total as (
  SELECT * 
  FROM data_mart.clean_weekly_sales
  WHERE platform = 'Retail'
)
SELECT age_band, demographic, sum(sales) AS subtotal,
  ROUND(100 * sum(sales)::NUMERIC / 
  (SELECT sum(sales) FROM retail_total), 2) AS percentage_contribution
FROM retail_total
GROUP BY age_band, demographic
ORDER BY subtotal DESC;

--Q9. Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?
-- Doing an average of averages will not result in the correct answer.
SELECT calendar_year, platform,
ROUND(AVG(avg_transaction), 2) AS avg_avg_transactions,
ROUND(SUM(sales)::NUMERIC/SUM(transactions), 2) AS proper_avg_transactions
FROM data_mart.clean_weekly_sales
GROUP BY calendar_year,platform
ORDER BY calendar_year, platform;

-- 3. Before & After Analysis

-- Taking the week_date value of 2020-06-15 as the baseline week where the Data Mart sustainable packaging changes came into effect.

--Q1. What is the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?

WITH week_num_cte AS (
  SELECT DISTINCT week_number AS weekNum
  FROM data_mart.clean_weekly_sales
  WHERE week_date = '2020-06-15'
),
salesChanges AS (
  SELECT
    SUM(CASE WHEN week_number BETWEEN weekNum-4 AND weekNum-1 THEN sales END) AS before_changes,
    SUM(CASE WHEN week_number BETWEEN weekNum AND weekNum+3 THEN sales END) AS after_changes
  FROM data_mart.clean_weekly_sales
  JOIN week_num_cte ON 1=1
  WHERE calendar_year = 2020
)

SELECT *,
  CAST(100.0 * (after_changes-before_changes)/before_changes AS decimal(5,2)) AS pct_change
FROM salesChanges;

--Q2. What about the entire 12 weeks before and after?

WITH week_num_cte AS (
  SELECT DISTINCT week_number AS weekNum
  FROM data_mart.clean_weekly_sales
  WHERE week_date = '2020-06-15'
),
salesChanges AS (
  SELECT
    SUM(CASE WHEN week_number BETWEEN weekNum-12 AND weekNum-1 THEN sales END) AS before_changes,
    SUM(CASE WHEN week_number BETWEEN weekNum AND weekNum+11 THEN sales END) AS after_changes
  FROM data_mart.clean_weekly_sales
  JOIN week_num_cte ON 1=1
  WHERE calendar_year = 2020
)

SELECT *,
  CAST(100.0 * (after_changes-before_changes)/before_changes AS decimal(5,2)) AS pct_change
FROM salesChanges;

--Q3. How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
-- PART 1 : 4 WEEKS
WITH week_num_cte AS (
  SELECT DISTINCT week_number AS weekNum
  FROM data_mart.clean_weekly_sales
  WHERE week_date = '2020-06-15'
),
salesChanges AS (
  SELECT calendar_year,
    SUM(CASE WHEN week_number BETWEEN weekNum-4 AND weekNum-1 THEN sales END) AS before_changes,
    SUM(CASE WHEN week_number BETWEEN weekNum AND weekNum+3 THEN sales END) AS after_changes
  FROM data_mart.clean_weekly_sales
  JOIN week_num_cte ON 1=1
  GROUP BY calendar_year
)

SELECT *,
  CAST(100.0 * (after_changes-before_changes)/before_changes AS decimal(5,2)) AS pct_change
FROM salesChanges;

-- PART 2 : 12 WEEKS
--Q3. How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?

WITH week_num_cte AS (
  SELECT DISTINCT week_number AS weekNum
  FROM data_mart.clean_weekly_sales
  WHERE week_date = '2020-06-15'
),
salesChanges AS (
  SELECT calendar_year,
    SUM(CASE WHEN week_number BETWEEN weekNum-12 AND weekNum-1 THEN sales END) AS before_changes,
    SUM(CASE WHEN week_number BETWEEN weekNum AND weekNum+11 THEN sales END) AS after_changes
  FROM data_mart.clean_weekly_sales
  JOIN week_num_cte ON 1=1
  GROUP BY calendar_year
)

SELECT *,
  CAST(100.0 * (after_changes-before_changes)/before_changes AS decimal(5,2)) AS pct_change
FROM salesChanges;


-- D. BONUS QUESTION
-- Q. Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?

-- A. REGION
WITH week_num_cte AS (
  SELECT DISTINCT week_number AS weekNum
  FROM data_mart.clean_weekly_sales
  WHERE week_date = '2020-06-15'
),
region_changes AS (
  SELECT region,
    SUM(CASE WHEN week_number BETWEEN weekNum-12 AND weekNum-1 THEN sales END) AS before_changes,
    SUM(CASE WHEN week_number BETWEEN weekNum AND weekNum+11 THEN sales END) AS after_changes
  FROM data_mart.clean_weekly_sales
  JOIN week_num_cte ON 1=1
  GROUP BY region
)

SELECT *,
  CAST(100.0 * (after_changes-before_changes)/before_changes AS decimal(5,2)) AS pct_change
FROM region_changes;

--B. PLATFORM
WITH week_num_cte AS (
  SELECT DISTINCT week_number AS weekNum
  FROM data_mart.clean_weekly_sales
  WHERE week_date = '2020-06-15'
),
platform_changes AS (
  SELECT platform,
    SUM(CASE WHEN week_number BETWEEN weekNum-12 AND weekNum-1 THEN sales END) AS before_changes,
    SUM(CASE WHEN week_number BETWEEN weekNum AND weekNum+11 THEN sales END) AS after_changes
  FROM data_mart.clean_weekly_sales
  JOIN week_num_cte ON 1=1
  GROUP BY platform
)

SELECT *,
  CAST(100.0 * (after_changes-before_changes)/before_changes AS decimal(5,2)) AS pct_change
FROM platform_changes;

--C. AGE_BAND
WITH week_num_cte AS (
  SELECT DISTINCT week_number AS weekNum
  FROM data_mart.clean_weekly_sales
  WHERE week_date = '2020-06-15'
),
age_band_changes AS (
  SELECT age_band,
    SUM(CASE WHEN week_number BETWEEN weekNum-12 AND weekNum-1 THEN sales END) AS before_changes,
    SUM(CASE WHEN week_number BETWEEN weekNum AND weekNum+11 THEN sales END) AS after_changes
  FROM data_mart.clean_weekly_sales
  JOIN week_num_cte ON 1=1
  GROUP BY age_band
)

SELECT *,
  CAST(100.0 * (after_changes-before_changes)/before_changes AS decimal(5,2)) AS pct_change
FROM age_band_changes;

--D. DEMOGRAPHIC
WITH week_num_cte AS (
  SELECT DISTINCT week_number AS weekNum
  FROM data_mart.clean_weekly_sales
  WHERE week_date = '2020-06-15'
),
demographic_changes AS (
  SELECT demographic,
    SUM(CASE WHEN week_number BETWEEN weekNum-12 AND weekNum-1 THEN sales END) AS before_changes,
    SUM(CASE WHEN week_number BETWEEN weekNum AND weekNum+11 THEN sales END) AS after_changes
  FROM data_mart.clean_weekly_sales
  JOIN week_num_cte ON 1=1
  GROUP BY demographic
)

SELECT *,
  CAST(100.0 * (after_changes-before_changes)/before_changes AS decimal(5,2)) AS pct_change
FROM demographic_changes;

--E. CUSTOMER_TYPE
WITH week_num_cte AS (
  SELECT DISTINCT week_number AS weekNum
  FROM data_mart.clean_weekly_sales
  WHERE week_date = '2020-06-15'
),
customer_type_changes AS (
  SELECT customer_type,
    SUM(CASE WHEN week_number BETWEEN weekNum-12 AND weekNum-1 THEN sales END) AS before_changes,
    SUM(CASE WHEN week_number BETWEEN weekNum AND weekNum+11 THEN sales END) AS after_changes
  FROM data_mart.clean_weekly_sales
  JOIN week_num_cte ON 1=1
  GROUP BY customer_type
)

SELECT *,
  CAST(100.0 * (after_changes-before_changes)/before_changes AS decimal(5,2)) AS pct_change
FROM customer_type_changes;