-- A CUSTOMER NODES EXPLORATION
--Q1. How many unique nodes are there on the Data Bank system?
SELECT COUNT(DISTINCT node_id) AS nodes
FROM data_bank.customer_nodes;

--Q2. What is the number of nodes per region?
SELECT r.region_name, COUNT(DISTINCT c.node_id) AS no_of_nodes
from data_bank.customer_nodes c
join data_bank.regions r
on r.region_id = c.region_id
group by r.region_name;

--Q3.How many customers are allocated to each region?
SELECT r.region_name, COUNT(DISTINCT c.customer_id) AS no_of_customers
from data_bank.customer_nodes c
join data_bank.regions r
on r.region_id = c.region_id
group by r.region_name;

--Q4.How many days on average are customers reallocated to a different node?
SELECT ROUND(AVG(end_date-start_date)) AS reallocation_avg_time
FROM data_bank.customer_nodes
where end_date <> '9999-12-31';   

--Q5.What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
WITH reallocation_cte AS (
  SELECT region_name,
         ROUND(end_date - start_date) AS reallocation_days
  FROM data_bank.regions r 
  INNER JOIN data_bank.customer_nodes cn ON r.region_id = cn.region_id
  WHERE end_date <> '9999-12-31'
)

SELECT region_name, 
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY reallocation_days) AS median,
       PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY reallocation_days) AS percentile_80th,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY reallocation_days) AS percentile_95th
FROM reallocation_cte
GROUP BY region_name;

--B Customer Transactions
--Q1 What is the unique count and total amount for each transaction type?
SELECT DISTINCT txn_type,
COUNT(txn_type) as Txn_Type_count,
to_char(SUM(txn_amount), 'FM$ 999,999,999') as Total_Amount
FROM data_bank.customer_transactions
GROUP BY txn_type
ORDER BY Txn_Type_count DESC;

--Q2 What is the average total historical deposit counts and amounts for all --customers?
WITH avg_calculations AS
(
  SELECT customer_id, count(txn_type) AS deposit_count,
  AVG(txn_amount) AS deposit_amt
  FROM data_bank.customer_transactions
  WHERE txn_type = 'deposit'
  GROUP BY customer_id
 )
 SELECT ROUND(AVG(deposit_count)) as deposit_count,
 CONCAT('$', ROUND(AVG(deposit_amt),2)) AS deposit_amt
 FROM avg_calculations;
 
 --Q3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
 WITH transaction_details AS
 (
   SELECT customer_id,
   EXTRACT(MONTH from txn_date) as months,
   UPPER(TO_CHAR(txn_date, 'month')) AS month_name,
   COUNT(CASE WHEN txn_type = 'deposit' THEN 1 END) AS deposit_count,
   COUNT(CASE WHEN txn_type = 'withdrawal' THEN 1 END) AS withdrawal_count,
   COUNT(CASE WHEN txn_type = 'purchase' THEN 1 END) AS purchase_count
   FROM data_bank.customer_transactions
   GROUP BY customer_id, months, month_name
  )
  
   SELECT month_name, COUNT(customer_id)
   FROM transaction_details
   WHERE (deposit_count>1 AND (withdrawal_count=1 OR purchase_count=1))
   GROUP BY month_name,months
   ORDER BY months;
   
--Q4. What is the closing balance for each customer at the end of the month?
WITH AmountCte AS(
   SELECT 
   	customer_id,
   	EXTRACT(MONTH FROM txn_date) AS month,
   	SUM(CASE 
   	WHEN txn_type = 'deposit' THEN txn_amount ELSE -txn_amount END) AS amount
   FROM data_bank.customer_transactions
   GROUP BY customer_id, month
   ORDER BY customer_id
)
SELECT 
   customer_id, 
   month,
   SUM(amount)OVER(PARTITION BY customer_id ORDER BY MONTH) AS closing_balance
FROM AmountCte
GROUP BY customer_id, month, amount
ORDER BY customer_id;
   
--Q5. What is the percentage of customers who increase their closing balance by more than 5%?
WITH AmountCte AS(
   SELECT 
   	customer_id,
   	EXTRACT(MONTH FROM txn_date) AS month,
   	SUM(CASE 
   	WHEN txn_type = 'deposit' THEN txn_amount ELSE -txn_amount END) AS amount
   FROM data_bank.customer_transactions
   GROUP BY customer_id, month
   ORDER BY customer_id
),
ClosingBalance AS(
   SELECT 
   	customer_id, 
   	month,
   	SUM(amount)OVER(PARTITION BY customer_id, month ORDER BY MONTH) AS closing_balance
   FROM AmountCte
   GROUP BY customer_id, month, amount
   ORDER BY customer_id
),
PercentageIncrease AS (
   SELECT 
   	customer_id,
   	month,
   	closing_balance,
   	100 *(closing_balance - LAG(closing_balance) OVER(PARTITION BY customer_id ORDER BY	month))
   		 / LAG(closing_balance) OVER(PARTITION BY customer_id ORDER BY	month) AS percentage_increase
   FROM ClosingBalance
)
SELECT 100 * COUNT(DISTINCT customer_id)/ (SELECT COUNT(DISTINCT customer_id) FROM data_bank.customer_transactions)::float AS percentage_cutomer
FROM PercentageIncrease
WHERE percentage_increase > 5;