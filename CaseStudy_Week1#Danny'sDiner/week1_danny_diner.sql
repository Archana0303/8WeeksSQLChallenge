--Q1
select s.customer_id, sum(m.price) as Total_Amount
from dannys_diner.sales s
inner join dannys_diner.menu m
on s.product_id = m.product_id
group by s.customer_id
order by Total_Amount desc;

-- Q2
select customer_id, count(distinct(order_date)) as visits
from dannys_diner.sales
group by customer_id
order by visits desc;

--Q3
With First_Item as (
Select *, row_number() over (partition by customer_id order by order_date) as Number from dannys_diner.sales )
Select f.customer_id, m.product_name as First_Product
from First_item f
inner join dannys_diner.menu m
on f.product_id = m.product_id
where Number = 1;

-- Q4
With Purchased_Item as (
  Select m.product_id
  from dannys_diner.sales s
  inner join dannys_diner.menu m
  on s.product_id = m.product_id
  group by m.product_id order by count(*) desc limit 1 ),

Purchased_Product as (
  select s.customer_id, s.product_id,count(*) as purchase_count
  from dannys_diner.sales s
  where s.product_id in (select product_id from Purchased_Item)
  group by s.customer_id, s.product_id)
  
select pp.customer_id, m.product_name, pp.purchase_count
from Purchased_Product pp
inner join dannys_diner.menu m
on pp.product_id = m.product_id
order by purchase_count desc;

--Q5
Select ab.customer_id, ab.product_name, ab.order_count
from (select s.customer_id, m.product_name,
      count(m.product_id) as Order_Count,
      RANK() over (partition by s.customer_id order by count(m.product_name) desc) as rn
      from dannys_diner.sales s inner join dannys_diner.menu m
      on s.product_id = m.product_id
      group by s.customer_id, m.product_name) ab
 where ab.rn = 1;
 
--Q6
With First_Order AS
( select s.customer_id, mm.join_date,
        s.order_date, m1.product_name,
 ROW_NUMBER() over (partition by s.customer_id order by s.order_date) as rn
from dannys_diner.menu m1 
 inner join dannys_diner.sales s
on s.product_id =m1.product_id
inner join dannys_diner.members mm
on s.customer_id = mm.customer_id 
AND s.order_date >= mm.join_date
)
select customer_id, join_date, order_date, product_name 
from First_Order
where rn = 1;

--Q7
With Just_Order AS
( select s.customer_id, mm.join_date,
        s.order_date, m1.product_name,
 DENSE_RANK() over (partition by s.customer_id order by s.order_date desc) as rn
from dannys_diner.menu m1 
 inner join dannys_diner.sales s
on s.product_id =m1.product_id
inner join dannys_diner.members mm
on s.customer_id = mm.customer_id 
AND s.order_date < mm.join_date
)
select customer_id, join_date, order_date, product_name 
from Just_Order
where rn = 1;

--Q8
With Total_Order AS
( select s.customer_id, 
        count(s.product_id) as Total_Item,
        sum(m1.price) as Total_Amount
from dannys_diner.menu m1 
 inner join dannys_diner.sales s
on s.product_id =m1.product_id
inner join dannys_diner.members mm
on s.customer_id = mm.customer_id 
AND s.order_date < mm.join_date
Group by s.customer_id
Order by s.customer_id
)
select customer_id,Total_Item, Total_Amount 
from Total_Order;


--Q9
Select customer_id, sum(Points) as Total_Points
from( select s.customer_id,
case 
when m1.product_name='sushi' then m1.price*20 
     else m1.price*10
end as Points
from dannys_diner.sales s
inner join dannys_diner.menu m1
on s.product_id = m1.product_id)A
group by customer_id
order by customer_id;

--Q10
With member_date AS
( select *, join_date + INTERVAL '6' day as next_week
  from dannys_diner.members ),
  
 Total_Rewards AS (
   select s.customer_id,
   CASE 
     WHEN m1.product_name ='sushi' or s.order_date BETWEEN md.join_date AND md.next_week
     THEN m1.price*20
     ELSE m1.price*10 END AS reward_point
   from dannys_diner.sales s 
   inner join member_date md on s.customer_id = md.customer_id
   inner join dannys_diner.menu m1
   on m1.product_id = s.product_id
   where s.order_date < '2021-02-01' )
   
 SELECT customer_id, sum(reward_point) as Reward_Points
 from Total_Rewards
 Group by customer_id;
 
 --Q11
 select s.customer_id, s.order_date,
   m1.product_name, m1.price,
   CASE WHEN s.order_date >= m2.join_date THEN 'Y'
   ELSE 'N' END AS membership 
 FROM dannys_diner.sales s
 inner join dannys_diner.menu m1
 on s.product_id = m1.product_id
 LEFT join dannys_diner.members m2
 on s.customer_id = m2.customer_id
 order by s.customer_id,s.order_date;
 
--Q12
With New_Table AS
(  select s.customer_id, s.order_date,
   m1.product_name, m1.price,
   CASE WHEN s.order_date >= m2.join_date THEN 'Y'
   ELSE 'N' END AS membership 
 FROM dannys_diner.sales s
 inner join dannys_diner.menu m1
 on s.product_id = m1.product_id
 LEFT join dannys_diner.members m2
 on s.customer_id = m2.customer_id
 order by s.customer_id,s.order_date
 )
 
 Select *, CASE
 WHEN membership = 'Y' THEN DENSE_RANK() over (Partition BY customer_id,membership ORDER BY order_date) ELSE NULL
 END AS Ranking
 FROM New_Table;