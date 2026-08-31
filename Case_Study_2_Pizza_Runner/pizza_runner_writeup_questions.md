# Pizza Runner — write-up prompts

Questions to answer in the header block, section by section.

**Target length: 600–900 words total.** A README nobody finishes is worth less than a short one that lands. Section 2 is the one that earns the read — give it the most room and keep the rest tight.

Write in past tense, first person, plain sentences. Don't explain what SQL is. Assume the reader can read the queries; tell them what they can't see from the code.

---

## 1 · What this is

*Two or three sentences. Orientation only.*

- What dataset is this and where did it come from?
- What dialect, and does that matter? (`regexp_split_to_table`, `FILTER`, `GROUPING()`, `generate_series` are all Postgres-specific — someone porting this needs to know.)
- Can the file be run top to bottom on a clean database, and does it need the cleaning step first?

---

## 2 · The data problem

*This is the section that makes the repo worth reading. Everything else is table stakes.*

- **What is actually wrong with the raw data?** Name the three failure modes you hit: text columns holding numbers with inconsistent units (`20km`, `13.4`, `23.4 km`), three different representations of missing (`NULL`, `''`, the literal string `'null'`), and the big one below.
- **`customer_orders` has no row identity.** No primary key, and `(order_id, pizza_id)` isn't unique — order 4 carries two identical Meat Lovers rows, order 10 carries two rows for the same pizza with different modifications. Explain what that does to a query: joins to that table either multiply rows or silently collapse them.
- **How did you find it?** Be honest — you hit it in B2, solved it with `DISTINCT`, hit it again in C5, solved it properly with `row_number()`, and only then went back and found it in B4, C4 and D2. That sequence is more interesting than a clean narrative, and it's what the work actually looks like.
- **Which answers were wrong before you caught it, and by how much?** D2 was $12 short. B4's customer averages were pulled toward multi-pizza orders.

---

## 3 · Cleaning decisions

*Why you cleaned it the way you did, not what the functions do.*

- Why `lower(trim(x)) in ('', 'null', 'nan')` rather than casting and catching the error?
- **Blacklist versus whitelist.** You're naming the junk values you found rather than validating the shape of what you keep. Say that's a deliberate choice for a dataset you've profiled completely, and name when it breaks — the day a row shows up holding `'N/A'` or `'pending'`.
- Why did you restructure `pizza_recipes` into `pizza_recipes_tags` up front instead of splitting the string inline in each of C1, C5 and C6?
- What did you decide *not* to clean, and why?

---

## 4 · Schema design (D3)

*The question asked how you'd design the table. The DDL is only half an answer.*

- **Grain:** one row per order, enforced by `UNIQUE(order_id)` rather than by convention.
- **Why a surrogate `rating_id`** when `order_id` would have worked as the key.
- **Why `runner_id` is stored** rather than derived through `runner_orders` — the rating is about the runner, and the cost is possible drift if an order were ever reassigned.
- **Why the `CHECK` constraint.** The prompt says ratings run 1 to 5; putting that in the schema means nobody can insert a 7 next year.
- **Why there's no foreign key.** `order_id` repeats in `customer_orders` so it can't be a FK target, and `runner_orders` has no declared primary key. Say which of the two available answers you took and why.
- **Why two orders are unrated.** Not every customer rates. It's also what forces D4 to `LEFT JOIN`, which is the part of that question most people get wrong.
- **How `rated_at` was derived** — pickup time plus delivery duration plus twenty minutes, because a rating can't precede the food arriving. And why it's a fixed offset rather than randomised: a portfolio script has to produce the same numbers when someone else runs it.

---

## 5 · Assumptions and departures from the prompt

*Where you answered something other than exactly what was asked, and why. Declaring these is the point — a reader who spots an undeclared departure stops trusting the rest.*

- **D5 and extras.** The canonical prompt says fixed prices with no cost for extras. You report both figures because excluding them makes D5 inconsistent with D2, and because the business question is what the company nets. State both numbers.
- **B1's week boundary.** The prompt fixes week 1 at 2021-01-01, a Friday. `date_trunc('week', ...)` only knows Monday. Explain the shift-truncate-shift trick in one sentence.
- **B6 reports km per minute, not km per hour.** Say so, since "speed" usually implies the latter.
- **A10 counts orders, not pizzas.** The wording says orders; the distinction is real and worth one clause.
- **B3's caveat.** You already wrote this in the file — pickup time is a proxy for prep time and only holds if runners collect immediately. Pull it up here or point at it.

---

## 6 · How I verified the answers

*Nobody graded this. Say how you knew.*

- **The D2 versus D5 cross-check.** Both compute gross revenue by different routes. They disagreed by exactly $12, which located the phantom `GROUP BY` in D2. That's the single best thing in this section — two independent calculations of one number is a technique, not an accident.
- What else did you check by hand? Row counts after each join, the eight successful orders against the cancellation column, the `rated_at` arithmetic against pickup plus duration.
- What would you add if this were production rather than a case study?

---

## 7 · Limitations

*Short. Two or three bullets. Confidence, not hedging.*

- Fourteen order rows and ten orders is not a dataset. Nothing here says anything about performance, and several answers would need re-examining at scale.
- The cleaning is blacklist-shaped and assumes the junk values are fully enumerated.
- **The derived-table drift point from E1.** `pizza_recipes_tags` is built from `pizza_recipes`, so anything inserted into the tags table alone disappears the next time the cleaning step runs. That's why E1 writes to all three source tables. It's the same class of problem as the row-identity finding, and it's worth naming as a general rule: a derived table gets rebuilt or written alongside its source, never instead of it.

---

## One thing to resist

Don't write a section explaining window functions or CTEs. The reader either knows or can look it up, and a tutorial in a portfolio README reads as padding. Every paragraph should tell them something they could not get by reading the SQL themselves.
