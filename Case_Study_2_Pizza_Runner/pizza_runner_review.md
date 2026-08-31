# Pizza Runner — Code Review

Reviewed 2026-08-28 against `pizza_runner questions worksheet.sql` (759 lines, A1 through D5).

**19 findings.** Six produce a wrong answer. Four leave a question incompletely answered. Two are right by coincidence. Seven are consistency or robustness. E1 is not attempted.

Line numbers refer to the version reviewed.

---

## Severity 1 — Wrong answer or won't run

### [ ] 1. `pizza_recipes_tags` column name doesn't match what queries it
**Line 10 creates `individual_tags`. Lines 292, 452, 455, 540, 543 reference `toppings_id`.**

Your live table must have `toppings_id`, because C1, C5 and C6 ran. So the documented DDL at the top of the file is stale. Anyone who clones the repo and runs it top to bottom fails at C1 with `column "toppings_id" does not exist`.

Also confirm the source column on line 10. You wrote `regexp_split_to_table(recipe_id, ...)`; the stock Pizza Runner schema calls that column `toppings`.

**Fix:** make the documented CREATE match reality, and run the whole file from a clean database once to prove it executes end to end.

---

### [ ] 2. D2 silently drops a pizza — revenue is $12 short
**Lines 619–628.** `order_rev` has a `GROUP BY` and no aggregate function. That isn't grouping, it's deduplicating.

Order 4 contains two identical rows: `(order_id=4, pizza_id=1, extras='')`. They collapse into one. Order 4 bills $22 instead of $34.

**Cross-check that proves it:** D5 computes the same revenue without that `GROUP BY` and gets $142. D2 gets $130. Two questions, one number, $12 apart — and $12 is exactly the Meat Lovers being dropped. Worth writing up; catching an error by making two independent calculations disagree is more interesting than the error itself.

**Fix:** delete the `GROUP BY` on line 628. It was never doing anything else.

---

### [ ] 3. B2 weights the average by pizza count
**Line 158.** `join customer_orders co on r.order_id = co.order_id` — `customer_orders` has one row per *pizza*.

Orders 3, 4 and 10 have 2, 3 and 2 pizzas, so their pickup delays get counted that many times. Runner 1's average is pulled toward orders 3 and 10.

**Fix:** `select distinct` in the CTE, exactly as you did in B3 on line 174.

---

### [ ] 4. B4 has the identical bug
**Line 211.** Same join, same multiplication.

Customer 102 has two orders — 13.4 km and 23.4 km — and the true average is 18.4. Order 3 has two pizzas, so it counts twice and the answer comes out 16.73.

**Fix:** `select distinct`, or aggregate `clean_data` to one row per order before joining.

---

### [ ] 5. C4 merges two pizzas into one row
**Lines 390 and 392.** The join key is `(order_id, pizza_id)`, and that pair is not unique in `customer_orders`.

Order 10 has two rows both with `pizza_id = 1` — one plain, one with exclusions `2, 6` and extras `1, 4`. The join attaches both modification sets to both rows, then `GROUP BY co.order_id, co.pizza_id` collapses them. You get one description where the question asks for one per record.

**Fix:** the `row_number() as unique_id` pattern from C5. This is the same problem, solved correctly 60 lines later.

---

### [ ] 6. D5 charges for extras, and the question says not to
**Lines 738–742.** The canonical D5 reads: *"$12 Meat Lovers and $10 Vegetarian fixed prices **with no cost for extras**, and each runner is paid $0.30 per kilometre."*

Your abbreviated comment on line 709 drops that clause, and your `pizza_rev` CTE adds `extras_cost`.

| | Revenue | Runner cost | Net |
|---|---|---|---|
| Canonical (no extras) | $138.00 | $43.56 | **$94.44** |
| Yours (extras at $1) | $142.00 | $43.56 | $98.44 |

**Fix:** drop `extras_cost` from the D5 total, or keep it and state explicitly in a comment that you're answering a variant. Either is defensible; silently answering a different question is not.

---

## Severity 2 — Incomplete answer

### [ ] 7. D4 is missing three of the requested fields
**Lines 693–707.** The question asks for `customer_id`, `order_id`, `runner_id`, `rating`, `order_time`, `pickup_time`, **time between order and pickup**, **delivery duration**, average speed, and total pizzas.

Missing:
- **`customer_id`** — not selected at all, though `customer_orders` is already in the FROM
- **Time between order and pickup** — you have both timestamps but never compute the delta
- **`duration`** — used in the speed calculation and named in the `GROUP BY`, never output

The `LEFT JOIN` to `order_ratings` on line 705 is right, and it's the thing most people get wrong here. Orders 2 and 8 correctly come through with a null rating.

**Fix:** add the three columns. The delta is `extract(epoch from (cr.pickup_timestamp - co.order_time))/60`.

---

### [ ] 8. D1 returns two rows where the question wants one number
**Lines 591–600.** "How much money has Pizza Runner made so far" is a single figure. You return revenue split by pizza name, which is useful — add the total alongside it rather than instead of it.

---

### [ ] 9. A10 answers a different question
**Line 134.** "What was the volume of **orders** for each day of the week" — you're counting pizzas with `count(pizza_id)`.

Your alias is honest about what you computed, but `count(distinct order_id)` is what was asked.

Minor second point: `to_char(order_time, 'Day')` pads to nine characters with trailing spaces. Wrap it in `trim()`.

---

### [ ] 10. E1 not attempted
**Line 758.** Write an INSERT demonstrating that the design supports a new Supreme pizza carrying all toppings.

Worth doing — it's the one question that tests whether your `pizza_recipes_tags` restructure actually holds up, and it should be short.

---

## Severity 3 — Right by coincidence

### [ ] 11. B5 tests the wrong column
**Line 220.** `when duration is null or distance in ('', 'null', 'NaN')` — the second test should read `duration`.

It produces the correct answer only because `distance` and `duration` happen to be junk on the same rows. Change the data and it breaks.

---

### [ ] 12. B1 ignores the week start the question specifies
**Line 142.** The question fixes week 1 at **2021-01-01**, a Friday. `date_trunc('week', ...)` uses Monday.

Your counts come out right by luck. The bucket labels don't match what was asked.

**Fix:** `date_trunc('week', registration_date + interval '3 days') - interval '3 days'`

---

## Severity 4 — Consistency and robustness

### [ ] 13. Two different standards for testing junk values
Case-sensitive `not in ('', 'null', 'NaN')` in **A7, A8, C2, C3**. Case-insensitive `lower(...) in ('null', '', 'nan')` in **C4, C5, C6, D3, D4, D5**.

Both work on this data. A reader sees two standards and can't tell which you meant. Standardise on the `lower(trim(...))` form throughout — it's the one that survives `'NULL'` and `' null '`.

---

### [ ] 14. `clean_data` temp table name collides between C2 and C3
**Lines 295–302 and 323–330.** Each drops and recreates the other's table. Run them out of order and you get a wrong answer with no error at all.

**Fix:** distinct names, or convert both to CTEs.

---

### [ ] 15. A3's `NOT EXISTS` is a wrapper around nothing
**Lines 32–35.** The subquery selects from `runner_orders` matched to itself on `order_id`. Since that table has one row per order, the whole thing reduces to `where cancellation is null or cancellation not ilike '%cancel%'`.

Also `and ro2.cancellation is not null` on line 35 is redundant — `ILIKE` against NULL yields NULL, never true.

Not wrong. Just harder to read than the thing it does. Same construction repeats in A4, A6, A7, A8.

---

### [ ] 16. C1 returns one row per pizza-topping pair
**Lines 287–292.** "What are the standard ingredients for each pizza" normally wants one row per pizza with a `string_agg` list. Yours is the long form.

---

### [ ] 17. `row_number()` has no tiebreaker
**Lines 413 and 501.** `row_number() over (order by order_id)` with many rows sharing an `order_id` gives an arbitrary assignment.

Safe as written: Postgres materialises a CTE referenced more than once, so `base_table` is computed once and every downstream reference sees the same `unique_id`. But the query is depending on that behaviour rather than stating what it wants.

**Fix:** `over (order by order_id, pizza_id, exclusions, extras)`.

---

### [ ] 18. D4 formats numbers into strings inside the result set
**Lines 700–701.** `concat(cr.distance, 'km')` and `concat(round(...), 'km/min')` return text. Anything reading this output can no longer sort, filter or aggregate on distance or speed.

Formatting belongs in the presentation layer. Return the numbers and name the columns `distance_km` and `speed_km_per_min`.

---

### [ ] 19. Stray `ORDER BY` inside an aggregated CTE
**Line 752.** `order by rc.order_id` in `total_cost`, whose output is then summed to a single row. Does nothing.

---

## Fix order

1. **#1** first — until the script runs top to bottom on a clean database, nothing else can be verified.
2. **#2, #3, #4, #5, #6** — the wrong answers.
3. **#7** — D4's missing columns.
4. Everything else.

After #1 through #6, re-run and check that **D2 and D5 agree on gross revenue**. They currently differ by $12, and that reconciliation is your proof the fix landed.

---

## The one thing to write up

Four of the six wrong answers (#2, #3, #4, #5) are the same root cause:

> **`customer_orders` has no row identity.** There is no primary key, and `(order_id, pizza_id)` is not unique — order 4 has two identical Meat Lovers rows and order 10 has two rows for the same pizza with different modifications. Every query that joins to this table either multiplies rows or, worse, collapses them.

You solved it twice — `select distinct` in B3, `row_number() as unique_id` in C5 — and never went back to apply it to B2, B4, C4 and D2.

That paragraph is the most interesting thing in the case study and it belongs at the top of the README, above the answers. It's a data-quality finding about the source, not a SQL trick, and it's the part of this work that maps directly onto reconciling systems that disagree.
