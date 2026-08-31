/* ==========================================================================
   DANNY'S DINER — Danny Ma 8 Week SQL Challenge, Case Study #1
   Aaron Barnett · PostgreSQL · 2026-08-28
   github.com/aaron-f-barnett
   ==========================================================================

   1 · WHAT THIS IS
   This is case study #1 from Danny Ma's 8 Week SQL Challenge. Three tables: sales, menu, and members.
   Written and run on Postgres, though only the interval arithmetic in question 10 is dialect-specific.

   There is no cleaning step. The data arrives clean, which is the main difference between this case
   study and #2, and it means the interesting decisions here are about how to read the questions rather
   than how to repair the source.

   2 · INTERPRETATION DECISIONS
	No timestamps (questions 3 and 7). The sales table records order_date with no time component, and
	several customers ordered more than one item on the same date. Picking a single "first" or "last"
	item out of those would be an arbitrary choice rather than a data supported finding, so I used
	rank() and returned every item tied at the boundary. Customer A ordered both sushi and curry on
	2021-01-01, so A returns two rows in both of those answers. Time may live behind the scenes in the
	POS, but that would record what was typed first rather than what the customer decided first.

	Non-members included (questions 6 and 7). The questions only ask about members. I left customers
	who have ordered but never joined in the result labelled "Not a member", so the output doubles as a
	list of who to contact about membership. Question 8 drops the callout because it already appears above.

	Sushi during the bonus week (question 10). In a member's first week everything earns 2x, and sushi
	already earns 2x on its own. I read that as 2x rather than stacking to 4x, so the CASE checks the
	bonus window first and stops there. The question does not settle this, and the other reading would
	change customer B's total.

   3 · HOW I VERIFIED THE ANSWERS
	Fifteen sales rows is small enough to check by hand, so I calculated the totals on paper before
	writing each query and compared. The points in questions 9 and 10 were worked out that way first,
	since those are the two where a wrong CASE branch produces a plausible looking number rather than
	an obvious error.

   4 · LIMITATIONS
	Fifteen sales rows across three customers. That is enough to demonstrate the technique and nothing
	like enough to say anything about the business. Nothing here is written with performance in mind.

   ========================================================================== */


-- 1. What is the total amount each customer spent at the restaurant?
select
s.customer_id,
sum(m.price) as total_spent
from sales s
join menu m on s.product_id = m.product_id
group by s.customer_id
order by total_spent desc;

-- 2. How many days has each customer visited the restaurant?
select
customer_id,
count(distinct order_date) as number_of_visits
from sales
group by customer_id
order by number_of_visits desc;

-- 3. What was the first item from the menu purchased by each customer?
-- Ties on the same order_date are all returned. See section 2 of the header.
with ranked as(
	select
	customer_id,
	order_date,
	product_id,
	rank() over (partition by customer_id order by order_date asc) as rn
	from sales)
select distinct
r.customer_id,
m.product_name as first_purchase
from ranked r
join menu m on m.product_id = r.product_id
where rn = 1
order by r.customer_id asc, first_purchase asc;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
with ranked as (
	select
	product_id,
	count(*) as number_of_orders,
	rank() over (order by count(*) desc) as rn
	from sales
	group by product_id)
select
m.product_name,
r.number_of_orders
from menu m
join ranked r on r.product_id = m.product_id
where r.rn = 1
order by r.number_of_orders desc, m.product_name asc;

-- 5. Which item was the most popular for each customer?
-- Customer B ordered all three items twice, so B returns three rows.
with ranked as (
	select
	customer_id,
	product_id,
	count(*) as number_of_orders,
	rank() over (partition by customer_id order by count(*) desc) as rn
	from sales
	group by customer_id, product_id)
select
r.customer_id,
m.product_name,
r.number_of_orders
from ranked r
join menu m on r.product_id = m.product_id
where r.rn = 1
order by r.customer_id asc, m.product_name asc;

-- 6. Which item was purchased first by the customer after they became a member?
-- Non-members are kept and labelled. See section 2 of the header.
with ranked as (
	select
	s.customer_id,
	s.product_id,
	mm.join_date,
	rank() over (partition by s.customer_id order by s.order_date asc) as rn
	from sales s
	left join members mm on s.customer_id = mm.customer_id
	where s.order_date >= mm.join_date
	or mm.join_date is null)
select distinct
r.customer_id,
case
	when r.join_date is null then 'Not a member'
	else m.product_name
end as first_purchase_after_member
from ranked r
left join menu m on r.product_id = m.product_id
where r.rn = 1
order by r.customer_id asc, first_purchase_after_member asc;

-- 7. Which item was purchased just before the customer became a member?
-- Same date-tie handling as question 3. Customer A returns two rows.
with ranked as (
	select
	s.customer_id,
	s.product_id,
	mm.join_date,
	rank() over (partition by s.customer_id order by s.order_date desc) as rn
	from sales s
	left join members mm on s.customer_id = mm.customer_id
	where s.order_date < mm.join_date
	or mm.join_date is null)
select distinct
r.customer_id,
case
	when r.join_date is null then 'Not a member'
	else m.product_name
end as last_purchase_before_member
from ranked r
left join menu m on r.product_id = m.product_id
where r.rn = 1
order by r.customer_id asc, last_purchase_before_member asc;

-- 8. What is the total items and amount spent for each member before they became a member?
-- Inner join to members, so non-members drop out here on purpose.
select
s.customer_id,
count(s.product_id) as number_of_items_ordered,
sum(m.price) as total_spent
from sales s
join menu m on s.product_id = m.product_id
join members mm on s.customer_id = mm.customer_id
where s.order_date < mm.join_date
group by s.customer_id
order by s.customer_id asc;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier, how many points would each customer have?
select
s.customer_id,
sum(case
	when m.product_name = 'sushi' then m.price * 20
	else m.price * 10
end) as points_earned
from sales s
join menu m on s.product_id = m.product_id
group by s.customer_id
order by s.customer_id asc;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items,
--     not just sushi. How many points do customer A and B have at the end of January?
-- The bonus window is checked first, so sushi bought in that week earns 2x rather than 4x. See section 2 of the header.
with purchases as (
	select
	s.customer_id,
	case
		when s.order_date >= mm.join_date and
		s.order_date <= (mm.join_date + interval '6 day')::date
		then m.price * 2 * 10
		when m.product_name = 'sushi'
		then m.price * 2 * 10
		else m.price * 10
	end as points
	from sales s
	join menu m on m.product_id = s.product_id
	join members mm on mm.customer_id = s.customer_id
	where s.order_date <= '2021-01-31')
select
customer_id,
sum(points) as total_points
from purchases
group by customer_id
order by customer_id asc;
