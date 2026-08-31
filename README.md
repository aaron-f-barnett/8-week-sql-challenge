# 8 Week SQL Challenge

Danny Ma's [8 Week SQL Challenge](https://8weeksqlchallenge.com/), worked in PostgreSQL. Two of the eight case studies are finished and I am adding the rest as I go.

Each folder holds the setup script and a worksheet with my queries. The worksheets open with a write-up covering what the data looked like, the calls I made where a question left room for interpretation, and how I checked the answers. The reasoning lives there rather than here.

## Finished

### [Case Study 1: Danny's Diner](Case_Study_1_Dannys_Diner)

Ten questions against a small sales table. The data is clean, so the work is in reading the questions rather than repairing anything. The sales table records dates with no time component, which makes "the first item purchased" ambiguous for a customer who ordered two things on the same day. I chose to return everything tied at that boundary instead of picking one arbitrarily.

### [Case Study 2: Pizza Runner](Case_Study_2_Pizza_Runner)

Five sections against a deliberately messy dataset. Distances and durations stored as text with inconsistent units, three separate ways of recording a missing value, and no primary key anywhere in it.

That last one cost me the most time and is the part worth reading. The `customer_orders` table stores one row per pizza, so `order_id` repeats, and `(order_id, pizza_id)` is not unique either because a single order can contain the same pizza twice with different modifications. Any query that joins to that table either multiplies rows or quietly collapses them, and neither failure raises an error.

I found it while hand-checking an average that would not reconcile with my query. It came back three more times in different disguises before I stopped patching the symptom and gave the table an explicit row identity to join on.

## In progress

Case Study 3 (Foodie-Fi) and Case Study 4 (Data Bank) are set up locally but not finished, so they are not in this repo yet.

## Running these

Everything is written for PostgreSQL. Load the setup script for a case study first, then work down the worksheet. Case Study 2 has a cleaning step at the top of its worksheet that several of the later queries depend on, so run that before skipping ahead.
