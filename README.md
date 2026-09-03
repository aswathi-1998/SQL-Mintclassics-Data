# Mint Classics — Inventory Optimization Analysis (SQL)

Analysis of inventory, warehouse capacity and product profitability for Mint Classics, a retailer of classic model vehicles, to support a decision on closing one of four storage facilities.

**Tools:** MySQL Workbench · SQL (CTEs, window functions, conditional aggregation)

---

## Problem

Mint Classics is considering closing one of its four storage facilities. Management wants a data-based recommendation on how to reorganize or reduce inventory without compromising service — specifically, the ability to ship an order within 24 hours of it being placed.

The task was to explore the operational database, identify the parts of it relevant to an inventory-reduction decision, and turn that into concrete recommendations.

## Data

MySQL sample database, eight tables:

| Table | Contents |
|---|---|
| `warehouses` | Four facilities (North, East, West, South) with current percentage capacity used |
| `products` | 110 model vehicles — product line, scale, vendor, stock on hand, buy price, MSRP, assigned warehouse |
| `orders` | Order header — dates placed, required and shipped, plus status |
| `orderdetails` | Order line items — quantity and actual price per unit |
| `customers` | Client details, location, assigned sales rep, credit limit |
| `payments` | Payments received per customer |
| `employees` | Staff and reporting structure |
| `offices` | Office locations and sales territories |

All queries are in [`mint_classics_analysis.sql`](mint_classics_analysis.sql).

## Approach

The analysis runs in three workstreams.

**1. Warehouse capacity.** Stock on hand was aggregated per warehouse and joined to `warehousePctCap`. Since the schema records utilization but not absolute capacity, total capacity was back-derived from stock held and percentage filled, then used to calculate remaining headroom at both 100% and a more realistic 85% working ceiling. Stock was also broken down by product line per warehouse to see whether any facility specializes.

**2. Inventory excess and deficit.** Each product's stock on hand was compared against its cumulative units ordered to produce a surplus figure, isolating both over- and under-stocked items. This was then generalized into a stocking rule: products were ranked by demand with `DENSE_RANK()`, split into quartiles, and assigned a target surplus buffer that scales with how fast the product moves — 200% of demand for the fastest-moving quartile down to 50% for the slowest. Comparing each product's actual surplus against its target yields a per-product *Reduce Stock* / *Increase Stock* action.

**3. Profitability.** Gross profit per product and per product line was calculated from actual selling price against buy price, excluding cancelled orders. Profit share per line was then set against inventory share per line to find where capital tied up in stock is out of proportion to the return it generates.

## Key findings

1. **Total headroom across the four warehouses is substantial.** Combined stock stands at 605131 units against a derived capacity of 735793, leaving 130662 units of unused space even at an 85% working ceiling.

2. **The South facility is the smallest holding and the most easily absorbed.** It carries 79380 units, and the remaining three warehouses have 93246 units of spare capacity between them at 85% fill — enough to absorb the entire South inventory.

3. **Inventory allocation is not aligned with profitability.** Planes accounts for 11.2% of units held but only 9.27% of gross profit, while Trucks and buses returns 10.73% of profit on 6.46% of stock.

4. **Overstocking is widespread and unrelated to demand.** 86 of 110 products hold surplus above their demand-adjusted target, while 24 products are stocked below cumulative demand and are candidates for replenishment rather than reduction.

## Recommendations

**Vacate the South warehouse and redistribute its stock.**
Supported on capacity grounds: the other three facilities can absorb South's inventory while staying under an 85% fill ceiling. Note that the cost saving cannot be quantified from this database — it holds no lease, labour, or handling cost — so this is a feasibility finding, and a full business case needs those figures.

**Apply a tiered excess-stock policy rather than a flat reduction.**
Stock ceilings should scale with demand rank: fast movers keep a deep buffer, slow movers a thin one. The query outputs a per-product suggested stock level and a reduce/increase action, giving a repeatable rule rather than a one-off cut list.

**Reduce holdings in over-weighted product lines first.**
Reduction should be targeted at lines where inventory share materially exceeds profit share, which frees the most warehouse space per unit of profit risked.

**Review the 1985 Toyota Supra.**
The product is stocked but has no recorded sales in any order. Before discounting, the more likely explanation should be checked — that it was never listed for sale, or the record is incomplete.

## Limitations

- **No cost data.** The schema has no storage, lease, labour, or freight cost, so warehouse closure can be assessed for feasibility but not for savings.
- **No warehouse capacity field.** Capacity is derived from stock held and percentage utilization, so it inherits any error in `warehousePctCap`.
- **Snapshot vs cumulative.** `quantityInStock` is a current snapshot while `quantityOrdered` is cumulative across the full order history. Surplus here is a coverage heuristic, not a true inventory turnover ratio — the data holds no stock history to compute turnover properly.
- **Historic sales valued at current cost.** `buyPrice` is a single current value applied to sales spanning the whole period, so profit figures ignore any change in acquisition cost.
- **Service target not yet measured.** The 24-hour shipping requirement is not tested in this analysis. `shippedDate` − `orderDate` by warehouse is available in the data and is the natural next step.
- **Sample database.** Small and synthetic, covering a limited window, so findings are illustrative rather than externally validated.

## Next steps

- Measure fulfillment lag by warehouse and product line against the 24-hour target, and check whether consolidation would widen or narrow it.
- Recompute demand per year rather than cumulatively, to separate genuinely dead stock from recently slowed products.
- Compare `MSRP` against actual `priceEach` to establish how much discounting already occurs and what it does to realized margin.
- Group surplus by `productVendor` — surplus clustered under one supplier is a purchasing problem, not a warehouse one.
- Request lease, labour and handling cost per facility to convert the closure recommendation into a costed case.

## Repository

```
├── mint_classics_analysis.sql   # all queries, commented by section
├── report.pdf                   # written report with result tables
└── README.md
```
### Source and attribution

The data comes from the **Mint Classics** database used in the Coursera
guided project *Analyze Data in a Model Car Database with MySQL Workbench*.
That database is an adapted version of
[`classicmodels`](https://www.mysqltutorial.org/getting-started-with-mysql/mysql-sample-database/),
a MySQL sample database published by MySQL Tutorial, extended with a
`warehouses` table recording each facility's current capacity utilization.

All records are fictional — the company, customers, employees and
transactions do not represent any real business.

The database dump is not redistributed here. To reproduce the analysis,
obtain the Mint Classics schema through the Coursera project, or use the
base `classicmodels` database from the link above (note that it does not
include the `warehouses` table, so the capacity queries will not run
against it unmodified).
