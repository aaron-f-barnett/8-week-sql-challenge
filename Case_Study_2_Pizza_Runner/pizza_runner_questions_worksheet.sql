/* ==========================================================================
   PIZZA RUNNER — Danny Ma 8 Week SQL Challenge, Case Study #2
   Aaron Barnett · PostgreSQL · 2026-08-28
   github.com/aaron-f-barnett
   ==========================================================================

   1 · WHAT THIS IS
   This is case study #2 from Danny Ma's 8 Week SQL Challenge. The queries use Postgres-specific functions, so they will not run on another
   dialect without changes. Run the cleaning step directly below this block first; several queries further down reference the table it builds.

   2 · THE DATA PROBLEM
	This dataset has multiple issues in regards to easily running analysis. The first is table "pizza_recipes"; it contains a listing of its ingredients in a single
	row which has each separated with a comma (ex. 1, 3, 5). This type of data recording also exists within the tables "customer_orders", and "runner_orders". This type
	of data recording forced the use of either splitting off the data to a new table with a new row per data point, or splitting them mid-query to reassemble later on.
	The next problem within the dataset was inconsistent recording within measurements and those measurements being stored as text. The table "runner_orders" had both
	distance and duration stored as text and used: numeric (23.2), numeric with text (21km), and even writing in 'null'. The last issue was the lack of any primary key
	within the dataset primarily in regards to table "customer_orders". The column order_id looks like a good candidate at first, but it introduces errors when
	aggregating data due to its repetition within the table itself.

	I discovered the primary key problem due to an issue that came about within the calculations. I ran into this issue when facing question B2: calculating the average
	time it took a runner to pickup an order after it had been placed. I could hand calculate the answers but was getting different answers with my original query. The
	fix was to pull DISTINCT order_ids from table "customer_orders" rather than a standard join which was multiplying the calculation. The same problem
	turned up again in B4, C4 and D2, each time behind a different symptom, which is why the C-section queries give "customer_orders" an explicit
	row_number() identity to join on.

	The rest of the trouble with the dataset was clear from the start and my time was spent determining the best method to address it, rather than chasing my tail in
	sorting out where a calculation was failing.

   3 · CLEANING DECISIONS
	lower(trim(x)) in ('', 'null', 'nan'): I used this structure whenever breaking out a case/when formula to catch the cases where the cell was entered in with the 
	text 'null', 'NaN', 'NULL', etc. This was a broadstroke attack, and that was on purpose. If you look at the data, you can clearly see the values which would be misinterpreted
	as text rather than qualifying as NULL. I easily could have structured each query to target the specific conditions within that column. I chose to standardize the 
	structure for ease of repeated use, and for the practice which would function outside of this dataset. I learned how to catch these inputs and that was of greater
	value than the time I could have saved in targeted attacks.
	
	regexp_replace(x) vs. regexp_split_to_table(x): I cleaned "pizza_recipes" up front with regexp_split_to_table, on the gut instinct that the data would be
	needed in at least 1 query and doing it once would save me time and text. For "customer_orders" I used both. Where I only needed the values as a list, as in
	C2 and C3, regexp_split_to_table was enough. Where I needed to tie each value back to a specific pizza row, C4 through C6, I used regexp_replace with
	string_to_array and UNNEST so I could carry unique_id through the query. Unlike "pizza_recipes", columns extras and exclusions were not similar in their
	data; mixed integers split with a comma, singular integers, 'NULL' written as text.

   4 · SCHEMA DESIGN (D3)
   The question asks how I would design the table, so the CREATE statement is only half the answer. Here is what I decided and why.

   One row per order, enforced by a UNIQUE constraint on order_id rather than by convention. The moment an order can carry two ratings, every query downstream has to decide which 
   one counts. I still gave it a surrogate rating_id so a rating has its own identity if anything ever needs to reference one.

   I stored runner_id on the table instead of pulling it through runner_orders every time. The rating is about the runner, so the column belongs here, and it keeps the D4 join simpler. 
   The cost is that it can drift if an order is ever reassigned, which I decided I could live with.

   The rating column carries a CHECK for 1 through 5. The prompt gives that range, and putting it in the schema means the database enforces it instead of whoever writes the next insert.

   There is no foreign key, and that one took some working out. order_id repeats in customer_orders because there is one row per pizza, so it cannot be a foreign key target. 
   runner_orders has one row per order but no declared primary key, so referencing it would mean altering a source table first. I left the constraint off and explained it here rather than 
   change that table quietly.

   Two of the eight successful orders have no rating. Not every customer rates their delivery, and leaving those out is what forces D4 into a LEFT JOIN instead of an INNER one.

   For rated_at I used pickup time plus delivery duration plus twenty minutes, since a customer cannot rate food that has not arrived. I considered randomizing the delay to look more realistic, 
   but then the script produces different data on every run, and I would rather the numbers in this write-up match what a reader gets when they run the file themselves.

   5 · ASSUMPTIONS AND DEPARTURES FROM THE PROMPT
	D5: Assumed the adjustments from D1 and D2 still applied and reported the revenue as such (pizza price, extras @ $1 each, runner fee).
	I also report the figure that excludes extras, since the prompt can be read either way, but I believe my version answers the more important question.

	B1: Bounds the week count as of Friday (2021-01-01), which required adjusting date_trunc through adding 3 days in order to move
	our starting day (Friday) to a Monday which is where the date_trunc defaults to. It's reversed after the date_trunc function.

	B6: Reported in km/min rather than standard km/hour that is commonly used in vehicles.

	A10: Counts orders rather than number of pizzas. Pointed out because I made the wrong calculation at first.

	B3: Provides possible bad data. Deeper explanation provided at the questions itself.

   6 · HOW I VERIFIED THE ANSWERS
	D2 vs D5: Disagreed by $12, with D2 coming up short. This led to verifying that there was a group by that was generating bad data.

	Standard counts, aggregation, and other quickly generated data was done by hand before attempting each query. As stated previously,
	this practice caught errors that would have gone unnoticed.

   7 · LIMITATIONS
	The dataset is small, ten orders across fourteen pizza rows. That makes it good practice but it will not support real business decisions
	taken off the back of this analysis. The secondary table I generated at the start, pizza_recipes_tags, is built off the table at the moment the query ran.
	Any additions or adjustments to the dataset would require the query to be run before every analysis where it is referenced, if this approach
	is still taken. 

   ========================================================================== */


-- Pizza Runner: case study questions. Clean the data first - customer_orders and runner_orders
-- carry 'null' strings, blanks, and inconsistent units on purpose.

--Cleaning Steps:
/* I broke down the pizza_recipes table into pizza_recipes_tags table which takes each pizza and their ingredients into a group by type table where each ingredient
number is it's own row against the pizza associated with it originally. Here is my code:*/
drop table if exists pizza_recipes_tags;
create table pizza_recipes_tags as(
    select
    pizza_id,
    regexp_split_to_table(recipe_id, ',\s*') as toppings_id
    from pizza_recipes
);


-- ==== A. Pizza Metrics ====
-- A1. How many pizzas were ordered?
select
count(*) as number_of_pizzas_ordered
from customer_orders co
where pizza_id is not null;

-- A2. How many unique customer orders were made?
select 
count(distinct order_id) as number_of_orders
from customer_orders co 
where co.order_id is not null;

-- A3. How many successful orders were delivered by each runner?
select
ro.runner_id,
count(distinct order_id) as number_of_deliveries_completed
from runner_orders ro 
where not exists (select 1 from runner_orders ro2 
					where ro2.order_id = ro.order_id 
					and ro2.cancellation ilike '%cancel%')
					group by ro.runner_id;

-- A4. How many of each type of pizza was delivered?
select
pn.pizza_name,
count(co.pizza_id) as number_of_pizzas_delivered
from runner_orders ro 
join customer_orders co on ro.order_id = co.order_id
join pizza_names pn on pn.pizza_id = co.pizza_id 
where not exists (select 1 from runner_orders ro2 
					where ro2.order_id = ro.order_id 
					and ro2.cancellation ilike '%cancel%'
					and ro2.cancellation is not null)
group by pn.pizza_name;

-- A5. How many Vegetarian and Meatlovers were ordered by each customer?
select 
customer_id,
sum(case 
	when pizza_id = 1 then 1
	else 0
end) as number_of_meatlovers,
sum(case 
	when pizza_id = 2 then 1
	else 0
end) as number_of_vegetarian
from customer_orders co 
group by co.customer_id
order by co.customer_id asc;

-- A6. What was the maximum number of pizzas delivered in a single order?
with pizza_count as (
	select 
	co.order_id,
	count(co.pizza_id) as number_of_pizzas_delivered
	from customer_orders co
	where not exists (select 1 from runner_orders ro 
					where ro.order_id = co.order_id
					and ro.cancellation ilike '%cancel%'
					and ro.cancellation is not null)
	group by co.order_id),
ranked as(
	select
	order_id,
	number_of_pizzas_delivered,
	dense_rank() over (order by number_of_pizzas_delivered desc) as rn
	from pizza_count)
select 
r.order_id,
r.number_of_pizzas_delivered
from ranked r 
where r.rn = 1;

-- A7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
select
customer_id,
SUM(case 
	when (exclusions is not null and lower(trim(co.exclusions)) not in ('', 'null', 'nan')) 
	or (extras is not null and lower(trim(co.extras)) not in ('', 'null', 'nan')) then 1
	else 0
end) as number_of_altered_pizzas,
sum(case 
	 when (exclusions is null or lower(trim(co.exclusions)) in ('', 'null', 'nan'))
	and (extras is null or lower(trim(co.extras)) in ('', 'null', 'nan')) then 1
	else 0
end) as number_of_nonaltered_pizzas
from customer_orders co
where not exists (select 1 from runner_orders ro 
					where ro.order_id = co.order_id 
					and ro.cancellation ilike '%cancel%'
					and ro.cancellation is not null)
group by co.customer_id
order by co.customer_id asc;

-- A8. How many pizzas were delivered that had both exclusions and extras?
select
SUM(case 
	when (exclusions is not null and lower(trim(co.exclusions)) not in ('', 'null', 'nan')) 
	and (extras is not null and lower(trim(co.extras)) not in ('', 'null', 'nan')) then 1
	else 0
end) as number_of_pizzas_with_extras_and_exclusions
from customer_orders co
where not exists (select 1 from runner_orders ro 
					where ro.order_id = co.order_id 
					and ro.cancellation ilike '%cancel%'
					and ro.cancellation is not null);

-- A9. What was the total volume of pizzas ordered for each hour of the day?
select
extract (hour from order_time) as "hour",
count(pizza_id) as number_of_pizzas_ordered
from customer_orders
group by extract(hour from order_time)
order by "hour" asc;

-- A10. What was the volume of orders for each day of the week?
select
trim(to_char(order_time, 'Day')) as "day",
count(distinct order_id) as number_of_orders
from customer_orders
group by to_char(order_time, 'Day'), extract(isodow from order_time)
order by extract(isodow from order_time) asc;

-- ==== B. Runner and Customer Experience ====
-- B1. How many runners signed up for each 1 week period (week starts 2021-01-01)?
select 
(date_trunc('week',registration_date + interval '3 days') - interval '3 days')::date as start_of_week_date,
count(runner_id) as number_of_runners
from runners
group by 1
order by 1;

-- B2. What was the average time in minutes it took for each runner to arrive at HQ to pick up the order?
with clean_date as (
	select distinct
	r.runner_id,
	co.order_id,
	co.order_time,
	case 
		when r.pickup_time is null or lower(trim(r.pickup_time)) in ('', 'null', 'nan') then null
		else (r.pickup_time)::timestamp
	end as clean_pickup
	from runner_orders r
	join customer_orders co on r.order_id = co.order_id)
select
runner_id,
round(avg(extract(epoch from (clean_pickup - order_time )) / 60),2) as average_order_pickup_minutes
from clean_date
group by runner_id
order by runner_id asc;

-- B3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
/* Yes there is a distinct relationship between the amount of pizzas within an order and how long, on average, it takes to prepare the order.
One area where this could be dragged down with bad data is in the true relationship between the pickup time by the runner and when the order was completed.
Unfortunately, our conclusion hinges on the idea that the runners are picking up and starting their delivery immedaitely upon order completion. 
A better metric would be to tap into the kitchen's tracking system and using their "clear" time as the endpoint for determining the true ratio between the 
number of pizzas and the time required.*/

with clean_date as (
	select distinct
	co.order_id,
	co.order_time,
	case 
		when r.pickup_time is null or lower(trim(r.pickup_time)) in ('', 'null', 'nan') then null
		else (r.pickup_time)::timestamp
	end as clean_pickup
	from runner_orders r
	join customer_orders co on r.order_id = co.order_id),
order_pizza as(
	select
	order_id,
	count(pizza_id) as number_of_pizzas
	from customer_orders
	group by order_id)
select
op.number_of_pizzas,
round(avg(extract(epoch from (clean_pickup - order_time )) / 60),2) as average_order_pickup_minutes
from clean_date cd
join order_pizza op on op.order_id = cd.order_id
group by op.number_of_pizzas
order by op.number_of_pizzas desc;

-- B4. What was the average distance travelled for each customer?
with order_distance as (
    select
        order_id,
        case
            when distance is null or lower(trim(distance)) in ('', 'null', 'nan') then null
            when distance ~ '[A-Za-z]' then regexp_replace(distance, '[^0-9.]', '', 'g')::numeric
            else distance::numeric
        end as distance_km
    from runner_orders
),
order_customer as (
    select distinct order_id, customer_id
    from customer_orders
)
select
    oc.customer_id,
    round(avg(od.distance_km), 2) as avg_distance_km
from order_customer oc
join order_distance od on od.order_id = oc.order_id
group by oc.customer_id
order by oc.customer_id;

-- B5. What was the difference between the longest and shortest delivery times for all orders?
with clean_data as(
	select distinct
	order_id,
	case 
		when duration is null or lower(trim(duration)) in ('', 'null', 'nan') then null
		when duration ~ '[A-Za-z]' then regexp_replace(duration, '[^0-9.]', '','g')::numeric
		else duration::numeric
	end as clean_duration
	from runner_orders)
select
round(max(clean_duration) - min(clean_duration),2) as diff_between_longest_shortest_delivery
from clean_data cd;

-- B6. What was the average speed for each runner for each delivery; do you notice any trend?
/* I expanded the data set to include data for average distance traveled and how many successful deliveries each runner has.
With this data alongside the average speed, we see that the top speed runner is also the one who is traveling the furthest on average as well.
The fastest runner doesn't have the highest number of successful deliveries, but they are in second place and roughly 30% faster and traveling 34% farther than than the runner in first. */
with clean_data as (
	select
	runner_id,
	order_id,
	case 
		when duration is null or lower(trim(duration)) in ('null', '', 'nan') then null
		when duration ~ '[A-Za-z]' then regexp_replace(duration, '[^0-9.]', '', 'g')::numeric
		else duration::numeric
	end as clean_duration,
	case 
		when distance is null or lower(trim(distance)) in ('null', '', 'nan') then null
		when distance ~ '[A-Za-z]' then regexp_replace(distance, '[^0-9.]', '', 'g')::numeric
		else distance::numeric
	end as clean_distance
	from runner_orders),
successful as (
	select
	runner_id,
	count(distinct order_id) as number_of_successful_deliveries
	from runner_orders
	where cancellation not ilike '%cancel%' or cancellation is null
	group by runner_id)
select
cd.runner_id,
round(avg(cd.clean_distance / cd.clean_duration), 2) as average_km_per_minute,
round(avg(cd.clean_distance)::numeric, 2) as avg_distance_traveled,
coalesce(s.number_of_successful_deliveries, 0) as number_of_successful_deliveries
from clean_data cd
left join successful s on s.runner_id = cd.runner_id 
group by cd.runner_id, s.number_of_successful_deliveries
order by average_km_per_minute desc;

-- B7. What is the successful delivery percentage for each runner?
with runner_count as (
	select
	runner_id,
	count(case
		when cancellation not ilike '%cancel%'
		or cancellation is null then 1
	end
	) as number_of_successful_orders,
	count(*) as total_assigned_orders
	from runner_orders ro 
	group by runner_id)
select 
runner_id,
concat(Round((number_of_successful_orders::numeric / total_assigned_orders  * 100), 2), '%') as successful_order_percentage
from runner_count 
group by runner_id, number_of_successful_orders, total_assigned_orders
order by runner_id;

-- ==== C. Ingredient Optimisation ====
-- C1. What are the standard ingredients for each pizza?
select 
pn.pizza_name,
string_agg(pt.topping_name, ', ') as topping_name
from pizza_names pn
join pizza_recipes_tags prt on pn.pizza_id = prt.pizza_id 
join pizza_toppings pt on pt.topping_id = prt.toppings_id::int
group by pn.pizza_name ;

-- C2. What was the most commonly added extra?
drop table if exists clean_data;
create temporary table clean_data as 
	select	
	order_id,
	regexp_split_to_table(extras, ',\s*')::int as extra_id
	from customer_orders
	where extras is not null
	and lower(trim(extras)) not in ('null', '', 'nan');
with count as (
	select 
	extra_id,
	count(distinct order_id) as times_added
	from clean_data
	group by extra_id),
ranked as (
	select 
	extra_id,
	times_added,
	dense_rank() over (order by times_added desc) as rn
	from count)
select
pt.topping_name,
r.times_added
from ranked r
join pizza_toppings pt on pt.topping_id = r.extra_id 
where r.rn = 1;

-- C3. What was the most common exclusion?
drop table if exists clean_data2;
create temporary table clean_data2 as 
	select	
	order_id,
	regexp_split_to_table(exclusions, ',\s*')::int as exclu_id
	from customer_orders
	where exclusions is not null
	and lower(trim(exclusions)) not in ('null', '', 'nan');
with count as (
	select 
	exclu_id,
	count(distinct order_id) as times_excluded
	from clean_data2
	group by exclu_id),
ranked as (
	select 
	exclu_id,
	times_excluded,
	dense_rank() over (order by times_excluded desc) as rn
	from count)
select
pt.topping_name,
r.times_excluded
from ranked r
join pizza_toppings pt on pt.topping_id = r.exclu_id 
where r.rn = 1;

-- C4. Generate an order item description for each record (e.g. "Meat Lovers - Exclude Beef")
WITH base_table as (
	select
		order_id,
		pizza_id,
		row_number() over (order by order_id, pizza_id, exclusions, extras) as unique_id,
		exclusions,
		extras
	from customer_orders),
clean_exclusions AS (
    SELECT 
        order_id, 
        pizza_id,
		unique_id,
        UNNEST(
            string_to_array(
				regexp_replace(
                CASE 
                    WHEN exclusions IS NULL THEN NULL
                    WHEN LOWER(trim(exclusions)) IN ('null', '', 'nan') THEN NULL
                    ELSE exclusions
                END, '\s+', '', 'g'),
                ','
            )
        )::INT AS exclu_id
    FROM base_table
),
clean_extras AS (
    SELECT 
        order_id, 
        pizza_id,
		unique_id,
        UNNEST(
            string_to_array(
				regexp_replace(
                CASE 
                    WHEN extras IS NULL THEN NULL
                    WHEN LOWER(trim(extras)) IN ('null', '', 'nan') THEN NULL
                    ELSE extras
                END, '\s+', '', 'g'),
                ','
            )
        )::INT AS extra_id
    FROM base_table
),
aggregated_toppings AS (
    SELECT
        bt.order_id,
        bt.unique_id,
        bt.pizza_id,
        STRING_AGG(DISTINCT pt_ex.topping_name,  ', ') AS removed_toppings,
        STRING_AGG(DISTINCT pt_ext.topping_name, ', ') AS added_toppings
    FROM base_table bt
    LEFT JOIN clean_exclusions ce   ON ce.unique_id  = bt.unique_id
    LEFT JOIN pizza_toppings   pt_ex  ON pt_ex.topping_id  = ce.exclu_id
    LEFT JOIN clean_extras     cx   ON cx.unique_id  = bt.unique_id
    LEFT JOIN pizza_toppings   pt_ext ON pt_ext.topping_id = cx.extra_id
    GROUP BY bt.order_id, bt.unique_id, bt.pizza_id
)
SELECT 
    a.order_id,
	a.unique_id,
    CONCAT(
        INITCAP(pn.pizza_name), 
        ' - Add ', COALESCE(a.added_toppings, 'None'), 
        ' - Remove ', COALESCE(a.removed_toppings, 'None')
    ) AS order_description
FROM aggregated_toppings a
JOIN pizza_names pn ON a.pizza_id = pn.pizza_id
order by a.order_id, a.unique_id asc;


-- C5. Generate an alphabetically ordered comma separated ingredient list for each pizza order,
--     with "2x" in front of any relevant ingredients
WITH base_table as (
	select
		order_id,
		pizza_id,
		row_number() over (order by order_id, pizza_id, exclusions, extras) as unique_id,
		exclusions,
		extras
	from customer_orders),
clean_exclusions AS (
    SELECT 
        order_id, 
        pizza_id,
        unique_id,
        UNNEST(
            string_to_array(
            regexp_replace(
                CASE 
                    WHEN exclusions IS NULL THEN NULL
                    WHEN LOWER(trim(exclusions)) IN ('null', '', 'nan') THEN NULL
                    ELSE exclusions
                END, '\s+', '', 'g'), ','))::int as exclu_id
    FROM base_table 
),
clean_extras AS (
    SELECT 
        order_id, 
        pizza_id,
        unique_id,
        UNNEST(
            string_to_array(
            regexp_replace(
                CASE 
                    WHEN extras IS NULL THEN NULL
                    WHEN LOWER(trim(extras)) IN ('null', '', 'nan') THEN NULL
                    ELSE extras
                END, '\s+', '', 'g'), ','))::int as extras_id
                from base_table 
        ),
base_recipe as (
	select
		bt.unique_id,
		bt.order_id,
		bt.pizza_id,
		(prt.toppings_id)::int as toppings_id
	from base_table bt
	join pizza_recipes_tags prt on prt.pizza_id = bt.pizza_id 	
	left join clean_exclusions ce on ce.unique_id = bt.unique_id and ce.exclu_id = (prt.toppings_id)::int 
	where ce.exclu_id is null),
base_with_extras as (
	select
		unique_id,
		order_id,
		pizza_id,
		toppings_id
	from base_recipe br
	union all
	select
		cex.unique_id,
		bt.order_id,
		bt.pizza_id,
		cex.extras_id as toppings_id
	from clean_extras cex 
	join base_table bt on bt.unique_id = cex.unique_id),
count_top as (
	select
		bwe.unique_id,
		bwe.order_id,
		pn.pizza_name,
		pt.topping_name,
		case
			when count(bwe.toppings_id) > 1 then concat('2x', pt.topping_name)
			else pt.topping_name
		end as final_topping
	from base_with_extras bwe
	join pizza_names pn on pn.pizza_id = bwe.pizza_id 
	join pizza_toppings pt on pt.topping_id = bwe.toppings_id 
	group by bwe.unique_id , bwe.order_id , pn.pizza_name , pt.topping_name)
select
	order_id,
	concat(
		pizza_name,
		': ',
		string_agg(final_topping, ', ' order by topping_name asc)) as pizza_ingredient_list
from count_top 
group by order_id, unique_id , pizza_name 
order by order_id asc;

-- C6. What is the total quantity of each ingredient used in all delivered pizzas, most frequent first?
WITH base_table as (
	select
		order_id,
		pizza_id,
		row_number() over (order by order_id, pizza_id, exclusions, extras) as unique_id,
		exclusions,
		extras
	from customer_orders),
clean_exclusions AS (
    SELECT 
        order_id, 
        pizza_id,
        unique_id,
        UNNEST(
            string_to_array(
            regexp_replace(
                CASE 
                    WHEN exclusions IS NULL THEN NULL
                    WHEN LOWER(trim(exclusions)) IN ('null', '', 'nan') THEN NULL
                    ELSE exclusions
                END, '\s+', '', 'g'), ','))::int as exclu_id
    FROM base_table 
),
clean_extras AS (
    SELECT 
        order_id, 
        pizza_id,
        unique_id,
        UNNEST(
            string_to_array(
            regexp_replace(
                CASE 
                    WHEN extras IS NULL THEN NULL
                    WHEN LOWER(trim(extras)) IN ('null', '', 'nan') THEN NULL
                    ELSE extras
                END, '\s+', '', 'g'), ','))::int as extras_id
                from base_table 
        ),
base_recipe as (
	select
		bt.unique_id,
		bt.order_id,
		bt.pizza_id,
		(prt.toppings_id)::int as toppings_id
	from base_table bt
	join pizza_recipes_tags prt on prt.pizza_id = bt.pizza_id 	
	left join clean_exclusions ce on ce.unique_id = bt.unique_id and ce.exclu_id = (prt.toppings_id)::int 
	where ce.exclu_id is null),
base_with_extras as (
	select
		unique_id,
		order_id,
		pizza_id,
		toppings_id
	from base_recipe br
	union all
	select
		cex.unique_id,
		bt.order_id,
		bt.pizza_id,
		cex.extras_id as toppings_id
	from clean_extras cex 
	join base_table bt on bt.unique_id = cex.unique_id),
count_top as (
	select
		bwe.unique_id,
		bwe.order_id,
		pt.topping_name,
		count(bwe.toppings_id) as number_ordered
	from base_with_extras bwe
	join pizza_toppings pt on pt.topping_id = bwe.toppings_id 
	join runner_orders ro on ro.order_id = bwe.order_id and (ro.cancellation not ilike '%cancel%' or ro.cancellation is null)
	group by bwe.unique_id, bwe.order_id , pt.topping_name)
select 
topping_name,
sum(number_ordered) as total_ordered
from count_top
group by topping_name
order by total_ordered desc;

-- ==== D. Pricing and Ratings ====
-- D1. Revenue at $12 Meat Lovers / $10 Vegetarian, no delivery fees?
with delivered as (
select
order_id
from runner_orders ro 
where cancellation not ilike '%cancel%' or cancellation is null),
pizza_count as (
select
co.pizza_id,
count(co.order_id) as number_ordered
from customer_orders co 
join delivered d on d.order_id = co.order_id 
group by co.pizza_id),
revenue_calc as (
select
pn.pizza_name,
case
	when pn.pizza_id = 1 then pc.number_ordered * 12
	when pn.pizza_id = 2 then pc.number_ordered * 10
end as revenue
from pizza_count pc
join pizza_names pn on pn.pizza_id = pc.pizza_id )
select
coalesce(pizza_name, 'Total') as pizza_name,
sum(revenue) as revenue
from revenue_calc
group by rollup (pizza_name)
order by grouping(pizza_name) asc, revenue desc;

-- D2. Same, plus $1 for each pizza extra (cheese is $1)?
with delivered as (
select
order_id
from runner_orders ro 
where cancellation not ilike '%cancel%' or cancellation is null),
extra_cost as (
	select
	d.order_id,
	co.pizza_id,
	case 
		when co.extras is null then 0
		when lower(trim(co.extras)) in ('null', '', 'nan') then 0
		else cardinality(string_to_array(trim(co.extras), ','))
	end as number_of_toppings
	from customer_orders co 
	join delivered d on d.order_id = co.order_id),
order_rev as (
select
order_id,
case 
	when pizza_id = 1 then 12
	else 10
end as pizza_revenue,
(number_of_toppings * 1) as toppings_revenue
from extra_cost
)
select
order_id,
(sum(pizza_revenue) + sum(toppings_revenue)) as total_rev
from order_rev
group by order_id
order by order_id;

-- D3. Design a runner ratings table (1-5) and insert data for each successful order.
DROP TABLE IF EXISTS order_ratings;

CREATE TABLE order_ratings (
    rating_id integer generated always as identity primary key,
    order_id  integer not null unique,
    runner_id integer not null,
    rating    integer not null check (rating between 1 and 5),
    comment   text,
    rated_at  timestamp default now()
);

INSERT INTO order_ratings (order_id, runner_id, rating, comment, rated_at)
SELECT v.order_id,
       v.runner_id,
       v.rating,
       v.comment,
       CASE
           WHEN lower(trim(ro.pickup_time)) IN ('null', '', 'nan') THEN NULL
           WHEN ro.pickup_time IS NULL THEN NULL
           ELSE trim(ro.pickup_time)::timestamp
                + (nullif(regexp_replace(ro.duration, '[^0-9]', '', 'g'), ''))::int * interval '1 minute'
                + interval '20 minutes'
       END
FROM (VALUES
    (1,  1, 4, 'Arrived hot, driver was friendly'),
    (3,  1, 5, NULL::text),
    (4,  2, 3, 'Took longer than I expected'),
    (5,  3, 5, 'Fast, no issues'),
    (7,  2, 4, NULL::text),
    (10, 1, 5, 'Great service')
) AS v(order_id, runner_id, rating, comment)
JOIN runner_orders ro ON ro.order_id = v.order_id;

-- D4. Join all delivery information (customer, order, runner, rating, times, distance, speed, pizza count).
with clean_runners as (
	select
		order_id,
		runner_id,
		case 
			when lower(trim(ro.pickup_time)) in ('null', '', 'nan') then null
			when ro.pickup_time is null then null
			else trim(ro.pickup_time)::timestamp
		end as pickup_timestamp,
		case
			when duration is null or lower(trim(duration)) in ('null', '', 'nan') then null
			when duration ~ '[A-Za-z]' then regexp_replace(duration, '[^0-9.]', '', 'g')::numeric
			else duration::numeric
		end as duration,
		case
			when distance is null or lower(trim(distance)) in ('null', 'nan', '') then null
			when distance ~ '[A-Za-z]' then regexp_replace(distance, '[^0-9.]', '', 'g')::numeric
			else distance::numeric
		end as distance,
		cancellation
	from runner_orders ro 
)
select 
co.customer_id,
co.order_id,
cr.runner_id,
ord.rating,
co.order_time,
cr.pickup_timestamp,
round((extract(epoch from (cr.pickup_timestamp - co.order_time)) / 60)::numeric, 2) as minutes_between_order_and_pickup,
cr.duration as delivery_time_minutes,
ord.rated_at,
cr.distance as distance_km,
round((cr.distance / cr.duration), 2) as speed_km_per_min,
count(co.pizza_id) as number_of_pizzas
from customer_orders co
join clean_runners cr on co.order_id = cr.order_id and (cr.cancellation not ilike ('%cancel%') or cr.cancellation is null)
left join order_ratings ord on ord.order_id = co.order_id
group by co.order_id, cr.runner_id, ord.rating, co.order_time, cr.pickup_timestamp , ord.rated_at, cr.distance, cr.duration , co.customer_id
order by co.order_id;

-- D5. If runners are paid $0.30/km, how much money does Pizza Runner have left over?
with clean_runners as (
	select
		order_id,
		runner_id,
		case
			when distance is null or lower(trim(distance)) in ('null', 'nan', '') then null
			when distance ~ '[A-Za-z]' then regexp_replace(distance, '[^0-9.]', '', 'g')::numeric
			else distance::numeric
		end as distance,
		cancellation
	from runner_orders ro 
),
runner_cost as (
	select
	order_id,
	runner_id,
	(distance * 0.30) as distance_cost
	from clean_runners
	where cancellation not ilike '%cancel%' or cancellation is null),
pizza_rev as (
	select
	order_id,
	pizza_id,
	case 
		when pizza_id = 1 then 12
		else 10
	end as pizza_cost,
	extras,
	case
		when extras is null then 0
		when lower(trim(extras)) in ('null', '', 'nan') then 0
		else cardinality(string_to_array(trim(extras), ','))
	end as extras_cost
	from customer_orders),
total_cost as (
	select
	rc.order_id,
	rc.distance_cost,
	sum(pr.pizza_cost)  as pizza_money,
	sum(pr.extras_cost) as extras_money
	from runner_cost rc
	join pizza_rev pr on rc.order_id = pr.order_id
	group by rc.order_id, rc.distance_cost)
select
concat('$', round(sum(pizza_money) + sum(extras_money) - sum(distance_cost), 2)) as net_with_extras,
concat('$', round(sum(pizza_money) - sum(distance_cost), 2))                     as net_excluding_extras
from total_cost;

-- ==== E. Bonus ====
-- E1. Write an INSERT demonstrating how the data design supports adding a new Supreme pizza (all toppings).
-- deletes first so this block can be run more than once
delete from pizza_recipes_tags where pizza_id = 3;
delete from pizza_recipes      where pizza_id = 3;
delete from pizza_names       where pizza_id = 3;

insert into pizza_names (pizza_id, pizza_name)
values (3, 'Supreme');

insert into pizza_recipes (pizza_id, recipe_id)
select 3, string_agg(topping_id::text, ', ' order by topping_id)
from pizza_toppings;

insert into pizza_recipes_tags (pizza_id, toppings_id)
select 3, topping_id::text
from pizza_toppings;