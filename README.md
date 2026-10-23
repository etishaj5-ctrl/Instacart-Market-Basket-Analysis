# Instacart Market Basket Analysis

**End-to-end retail analytics project using MySQL and Power BI.** I analysed 778K grocery order lines to understand what customers buy, when they order and how often they come back, and turned the results into business recommendations.

![Dashboard preview](images/dashboard_1_executive.png)

---

## Business Problem

An online grocery retailer needs to know:

1. Which departments, aisles and products drive demand?
2. When do customers order, so staffing and stock can match demand?
3. How strong is repeat purchasing, and which customers matter most?

## Dataset

- **Source:** [Instacart Market Basket Analysis](https://www.kaggle.com/c/instacart-market-basket-analysis) (Kaggle). The raw data is **not** included in this repository. Please download it from the source and follow its terms of use.
- **Sample used:** 5,000 customers with **all** of their prior orders.

| Table | Rows |
|---|---|
| orders_sample | 77,862 |
| order_products_sample | 778,814 |
| products | 49,688 (28,966 appear in the sample orders) |
| aisles | 134 |
| departments | 21 |

## Tools

- **MySQL**: database design, data loading, validation, analysis (CTEs, window functions)
- **Power BI**: 4-page dashboard with DAX measures
- **Excel**: initial review of the CSV files

## Workflow

1. **Data model:** created 5 tables in MySQL, loaded the CSV files, and added indexes and foreign keys.
2. **Data quality checks:** verified row counts, orphan records, NULLs and hidden characters.
3. **Analysis:** wrote 11 analytical queries (departments, reorders, timing, customer segments, Pareto).
4. **Dashboard:** built a 4-page Power BI report connected to the MySQL database.

## Data Model

![ER diagram](images/er_diagram.png)

## Data Quality Checks and Issues Found

| Check | Result |
|---|---|
| Order lines without a matching order | 0 |
| Orders without items | 0 |
| Order lines with an unknown product | 0 |
| Blank `days_since_prior_order` | 5,000, which are each customer's first order. Stored as NULL, not 0. |
| Hidden carriage-return character in `aisle` names | Found in all 134 rows because of Windows line endings. Fixed with `TRIM(TRAILING '\r' ...)`. |
| `days_since_prior_order` capped at 30 | The value 30 means "30 or more days", so it is labelled "30+" in the dashboard. |

![Row counts](images/sql_4_1_row_counts.png)

## Key Insights

| # | Insight | Evidence |
|---|---|---|
| 1 | **Demand is concentrated.** | Produce (29.7%) and Dairy & Eggs (16.4%) make up **46.0%** of order lines. With Snacks, the top 3 departments reach 54.8%. Fresh fruits (11.4%) and fresh vegetables (10.7%) are the biggest aisles. |
| 2 | **Orders peak during the day and at the start of the week.** | 64.7% of orders are placed between 9 AM and 5 PM, and 11 AM is the busiest hour. Day 0 and day 1 together are 34.7% of orders. |
| 3 | **Most items are reorders.** | 58.6% of order lines are reorders. Dairy & Eggs has the highest department reorder rate (66.3%). |
| 4 | **Items added first are the ones bought again.** | The reorder rate falls from about 68% for the first item added to about 48% by the 20th item. |
| 5 | **Customers shop on weekly cycles.** | Orders spike at 7, 14, 21 and 28 days. The average gap is 10.7 days, and 10.2% of orders come after 30+ days. |
| 6 | **A small group of loyal customers drives most orders.** | Customers with 16+ orders are 31.4% of users but place **68.8%** of all orders. |
| 7 | **A small share of products drives volume.** | 4,150 products (14.3% of products ordered) make up 80% of order lines. |

![Customer segments](images/q6_segments.png)

## Recommendations

These are suggestions based on the patterns above. They would need testing before acting on them.

- **Staffing and stock:** schedule picking staff and restock fresh produce and dairy ahead of the 9 AM to 5 PM window and the start of the week.
- **Retention:** run reminders or "buy again" lists around the weekly 7-day cycle, since repeat customers generate most orders.
- **Loyalty:** move Regular customers (6 to 15 orders) towards Loyal with targeted offers, because Loyal customers place about 69% of orders.
- **Assortment:** protect availability of the roughly 14% of products that drive 80% of order volume.

## SQL Skills Demonstrated

- Multi-table `JOIN`s (5 tables), subqueries and `CASE` expressions
- CTEs (`WITH`), window functions (`RANK() OVER`, `SUM() OVER`)
- Data validation queries, NULL handling (`NULLIF`), `LOAD DATA`
- Indexes and foreign keys

Full code: [`sql/instacart_analysis.sql`](sql/instacart_analysis.sql)

![Top aisles](images/q8_aisles.png)

## Power BI Dashboard

| Page | What it shows |
|---|---|
| Executive Overview | Orders, users, basket size, reorder rate, order volume by department |
| Demand Timing | Order volume by day and hour (heatmap), peak hours |
| Product and Category Insights | Top departments, aisles and products, reorder rate by department |
| Customer Insights | Order frequency, reorder rate by cart position, reordered vs new items |

![Demand timing](images/dashboard_2_demand_timing.png)
![Product and category insights](images/dashboard_3_products.png)
![Customer insights](images/dashboard_4_customers.png)

A PDF of the dashboard is in [`docs/`](docs/). The `.pbix` file is available on request.

## Limitations

- This is a **5,000-customer sample**, so results may differ from the full dataset.
- The dataset has no prices, so the analysis uses **order volume, not revenue**.
- The dataset does not define which weekday is day 0 (commonly assumed to be Sunday), so days are shown as numbers.
- Every customer has at least 3 prior orders, so "new customer" analysis is not possible.
- These results show patterns, not causes.

## How to Run

1. Download the dataset from Kaggle and create the sample files.
2. In `sql/instacart_analysis.sql`, change `/path/to/data/` to your folder.
3. Run Section 1 (tables), Section 2 (load), Section 3 (keys) once, then Section 4 (checks) and Section 5 (analysis) query by query. MySQL 8.0 or later is needed.
4. Open the Power BI report and point it at your MySQL database.

## Repository Structure

```
├── README.md
├── sql/instacart_analysis.sql
├── images/                  (dashboard pages, ER diagram, query results)
└── docs/instacart_dashboard.pdf
```

## About Me

**[Your Name]**, aspiring data analyst
[LinkedIn URL] | [email]
