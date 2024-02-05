use pizza_runner;

-- Cleaning the Dataset

select * from customer_orders;
update customer_orders
set exclusions = Case when exclusions = 'null' THEN '' else exclusions END,
    extras = case when extras = 'null' or extras is null then '' else extras end;

select * from customer_orders;

-- runner's order

update runner_orders
set pickup_time = CASE WHEN pickup_time = 'null' THEN NULL ELSE CAST(pickup_time AS TIMESTAMP) END,
update runner_orders
set distance =  CASE WHEN distance LIKE 'null' THEN ''
	        WHEN distance LIKE '%km' THEN TRIM('km' from distance)
	        ELSE distance END;
update runner_orders
set duration =
       CASE  WHEN duration LIKE 'null' THEN ' '
	  WHEN duration LIKE '%mins' THEN TRIM('mins' from duration)
	  WHEN duration LIKE '%minute' THEN TRIM('minute' from duration)
	  WHEN duration LIKE '%minutes' THEN TRIM('minutes' from duration)
	  ELSE duration END,
update runner_orders
set cancellation =
      CASE WHEN cancellation IN ('null', '') THEN '' ELSE cancellation END ;

select * from runner_orders;

-- UPDATING THE DATA TYPES
ALTER TABLE runner_orders
alter column duration int;
ALTER TABLE runner_orders
alter column distance FLOAT;

-- A Pizza metrics
--Q1
select count(*) as pizza_orders_count
from customer_orders;
--Q2
SELECT COUNT(DISTINCT order_id) as unique_order
from customer_orders;
--Q3
select runner_id,count(order_id) as success_orders
from runner_orders where distance!=0
group by runner_id;
--Q4
ALTER TABLE pizza_names
ALTER COLUMN pizza_name varchar(15);

select p.pizza_name, count(c.pizza_id) AS Total_pizza_order
from customer_orders c
join runner_orders r
on c.order_id = r.order_id
join pizza_names p
on c.pizza_id = p.pizza_id
where r.distance!=0
group by p.pizza_name;

--Q5
select c.customer_id,
count(CASE WHEN pizza_name = 'Vegetarian' THEN 1 END) AS Vegetrarian_count,
count(CASE WHEN pizza_name = 'MEATLOVERS' THEN 1 END) AS Meatlovers_count
FROM customer_orders c
JOIN pizza_names p
ON c.pizza_id = p.pizza_id
GROUP BY c.customer_id;

--Q6 What was the maximum number of pizzas delivered in a single order?
 WITH pizza_cnt AS
 ( SELECT order_id, count(pizza_id) as Total_pizza
   FROM customer_orders
   GROUP BY order_id)

SELECT order_id, Total_pizza
FROM (
SELECT order_id,Total_pizza,
RANK() OVER (order by Total_pizza Desc) AS rnk
FROM pizza_cnt ) A
where A.rnk = 1;

--Q7 For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
select customer_id,
COUNT (CASE WHEN exclusions<>'' OR extras <>'' THEN 1 END) AS changes,
COUNT (CASE WHEN exclusions= '' AND extras = '' THEN 1 END) AS no_changes
from customer_orders
GROUP BY customer_id
ORDER BY customer_id;

--Q8 How many pizzas were delivered that had both exclusions and extras?
SELECT COUNT(*) AS New_Pizza
from customer_orders c
JOIN runner_orders r
on c.order_id = r.order_id
where c.exclusions<> '' AND c.extras <>''
AND r.cancellation is NULL ;

--Q9 What was the total volume of pizzas ordered for each hour of the day?
ALTER TABLE customer_orders
alter column order_time timestamp;

 SELECT DATEPART(HOUR, order_time) AS Hour_of_Day,
 COUNT(order_id) FROM customer_orders
 GROUP BY DATEPART(HOUR, order_time)
 ORDER BY Hour_of_Day;

 SELECT 
  DATEPART(HOUR, [order_time]) AS hour_of_day, 
  COUNT(order_id) AS pizza_count
FROM customer_orders
GROUP BY DATEPART(HOUR, [order_time]);

SELECT HOUR(order_time) AS Hour_of_Day
FROM customer_orders;

SELECT DATEPART(HOUR, order_time) from customer_orders;


--Q10 What was the volume of orders for each day of the week?
SELECT 
  FORMAT(DATEADD(DAY, 2, order_time),'dddd') AS day_of_week, -- add 2 to adjust 1st day of the week as Monday
  COUNT(order_id) AS total_pizzas_ordered
FROM customer_orders
GROUP BY FORMAT(DATEADD(DAY, 2, order_time),'dddd');

--B Runner and Customer Experience
--Q1 How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT DATEPART(WEEK, registration_date) AS registration_week,
count(runner_id) AS No_of_runners
FROM runners
GROUP BY DATEPART(WEEK, registration_date);

--Q2 What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
With pizza_pick_time AS
( SELECT c. order_time, r.pickup_time, c.order_id,
  DATEDIFF(MINUTE, c.order_id, r.pickup_time) AS time_taken
  FROM customer_orders c 
  join  runner_orders r
  on c.order_id = r.runner_id
  WHERE R.distance!= 0
  GROUP BY c.order_id, c.order_time, r.pickup_time
  )
SELECT AVG(time_taken) as Avg_Time 
FROM pizza_pick_time 
WHERE time_taken > 1;

--Q3 Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH pizza_time AS
(
  SELECT c.order_time, r.pickup_time,
  COUNT(c.order_time) AS Pizzas_Ordered,
  DATEDIFF(MINUTE, c.order_time, r.pickup_time) AS time_taken
  FROM customer_orders c
  join  runner_orders r
  on c.order_id = r.runner_id
  WHERE R.distance!= 0
  GROUP BY c.order_id, c.order_time, r.pickup_time
  )
SELECT Pizzas_Ordered, AVG(time_taken)
FROM pizza_time WHERE time_taken >1
GROUP BY Pizzas_Ordered;

--Q4 What was the average distance travelled for each customer?
SELECT c.customer_id, AVG(r.distance) AS Distance
FROM customer_orders c
join runner_orders r
ON c.order_id = r.order_id
WHERE r.distance!=0
GROUP BY C.customer_id;

--Q5 What was the difference between the longest and shortest delivery times for all orders?
SELECT MAX(duration)-MIN(duration) AS Time_Diff
FROM runner_orders
WHERE duration >0;

-- Q6 What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT runner_id, order_id, 
CONCAT(ROUND(AVG((distance*60)/duration),2),'km/hr') AS avg_speed
FROM runner_orders
WHERE distance != 0
Group BY runner_id, order_id;

--Q7 What is the successful delivery percentage for each runner?
SELECT runner_id, 
ROUND(100 * SUM( CASE WHEN distance = 0 THEN 0 ELSE 1 END)/COUNT(*),0) AS success_percent
FROM runner_orders
GROUP BY runner_id;

--C Ingredient Optimisation
--Q1 What are the standard ingredients for each pizza?
ALTER TABLE pizza_names
ALTER COLUMN pizza_name varchar(15);

ALTER TABLE pizza_toppings
ALTER COLUMN topping_name varchar(15);


WITH cte_toppings AS (
	SELECT
		pt.topping_name,
		tpr.pizza_id,
        pn.pizza_name
	FROM pizza_recipes tpr
    JOIN pizza_toppings pt ON pt.topping_id = tpr.toppings
    JOIN pizza_names pn ON pn.pizza_id = tpr.pizza_id
    )
SELECT
	ct.pizza_name,
    ct.topping_name
FROM cte_toppings ct;

--Q2 What was the most commonly added extra?

-- D. Pricing and Ratings
--Q1 If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - 
--how much money has Pizza Runner made so far if there are no delivery fees?
SELECT 
 SUM(CASE WHEN c.pizza_id = 1 THEN 12 ELSE 10 END ) AS Amount
 FROM customer_orders c
 JOIN runner_orders r
 ON c.order_id = r.order_id
 WHERE r.distance != 0;


 --Q2 What if there was an additional $1 charge for any pizza extras?
 With Total_amt AS
 (
 SELECT 
 SUM(CASE WHEN c.pizza_id = 1 THEN 12 ELSE 10 END ) AS Amount ,
 SUM( CASE WHEN c.extras!= '' THEN 1 ELSE 0 END) AS extra_amt
 FROM customer_orders c
 JOIN runner_orders r
 ON c.order_id = r.order_id
 WHERE r.distance != 0)

 SELECT CONCAT('$', Amount+extra_amt) AS Total
 from Total_amt;

 --Q3 enerate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5
 DROP TABLE IF EXISTS ratings;
 CREATE TABLE ratings (
 runner_id INTEGER,
 order_id INTEGER,
 customer_id INTEGER,
 rating INTEGER);

 INSERT INTO ratings
 (runner_id, order_id, customer_id, rating)
 VALUES 
 (1,1,101,4),
 (1,2,102,3),
 (2,3,102,4),
 (2,4,103,5),
 (1,5,101,3),
 (2,6,104,4),
 (1,7,103,5),
 (2,8,105,4);

 SELECT * FROM ratings;

 --Q4 
 SELECT
	co.customer_id, co.order_id, ro.runner_id,
    rt.rating,
    co.order_time, ro.pickup_time,
    DATEDIFF(MINUTE, co.order_time, ro.pickup_time) AS time_order_pickup,
    ro.duration,
    ROUND(avg(60 * ro.distance / ro.duration), 1) AS avg_speed,
    COUNT(co.pizza_id) AS num_pizza
FROM customer_orders co
JOIN runner_orders ro ON co.order_id = ro.order_id
JOIN ratings rt ON co.order_id = rt.order_id
GROUP BY co.customer_id, co.order_id, ro.runner_id, rt.rating, co.order_time, ro.pickup_time, ro.duration
ORDER BY co.customer_id;

--Q5 If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - 
--how much money does Pizza Runner have left over after these deliveries?
 With Total_amt AS
 (
 SELECT 
 SUM(CASE WHEN c.pizza_id = 1 THEN 12 ELSE 10 END ) AS Amount ,
 SUM(r.distance)*0.30 AS dist_price
 FROM customer_orders c
 JOIN runner_orders r
 ON c.order_id = r.order_id
 WHERE r.distance != 0)

 SELECT CONCAT('$', Amount-dist_price) AS Total_Price
 from Total_amt;