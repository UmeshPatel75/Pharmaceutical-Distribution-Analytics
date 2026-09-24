# Pharma Distribution Analytics — report build guide

Model: `Pharma_Distribution_Analysis.pbix`
Data: Atul Medico FY 2020-21, anonymised, values scaled 0.8317

All figures below are **scaled**. Say so once on Page 1 and never
repeat it.

---

## Before you start

**Turn off auto date/time.** File → Options → Current File → Data
Load → untick *Auto date/time*. Power BI created eleven hidden
`LocalDateTable_*` tables when you loaded the CSVs. They bloat the
model and clutter the field list. `Dim_Date` replaces them all.

**Hide these columns** (Model view → right-click → Hide in report
view): every `cust_id`, `prd_code`, `mfg_code`, `batch_key`,
`supp_id` on fact tables; `Dim_Customer[group_name]`, `[grade]`,
`[is_institute]`, `[credit_limit]`, `[bill_due_days]`;
`Dim_Product[generic_name]`; `Dim_Date[Month Year Sort]`,
`[FY Month No]`.

**Set sort columns:** `Dim_Date[Month]` → sort by `[FY Month No]`,
`Dim_Date[Month Year]` → sort by `[Month Year Sort]`. Without this
your months run April, August, December.

**Theme:** View → Themes → Customise. Navy `#1F3864` primary, red
`#C00000` for risk and warnings. Matches the yarn project, so the
two read as one portfolio.

---

## Page 1 — Sales & Margin

*What the business sold, to whom, and what it earned.*

**Cards, top row**
`Net Sales` · `Gross Margin %` · `Return Rate %` ·
`Active Customers` · `Average Invoice Value`

**Line chart** — monthly trend
- X: `Dim_Date[Month Year]`
- Y: `Net Sales`
- Secondary line: `Gross Margin %`

The COVID shape should be visible: April-May 2020 suppressed by
lockdown, recovery through the second half.

**Stacked column** — sales by GST class
- X: `Dim_Date[Month Year]`, Legend: `Fact_Sales[gst_class]`,
  Values: `Net Sales`

**Bar chart** — top 15 manufacturers
- Y: `Dim_Product[manufacturer]`, X: `Net Sales`
- Filter: Top 15 by `Net Sales`
- Add `Gross Margin %` to tooltips

**Matrix** — where the margin actually is
- Rows: `Dim_Product[category]`
- Values: `Net Sales`, `Gross Margin`, `Gross Margin %`,
  `Return Rate %`
- Conditional formatting on `Gross Margin %`: red below 0

**Slicers:** `Dim_Date[Month Year]`, `Dim_Customer[area_name]`,
`Fact_Sales[bill_type]`

**Titles**
- "Sales recovered through the second half of FY 2020-21"
- "Where the margin actually sits: 2.5% overall, but not evenly"

---

## Page 2 — ABC Classification

*Which products carry the business.*

**Cards**
`Active Products` · `Net Sales` · and two you create as needed:
count of A-class and their share of revenue.

**Scatter** — the Pareto curve
- X: product rank (or `Net Sales`, log scale)
- Y: `Cumulative Sales %`
- Legend: `ABC Class`
- Details: `Dim_Product[product_name]`

**Table** — top 25 products
- `product_name`, `manufacturer`, `Net Sales`, `Gross Margin %`,
  `ABC Class`, `Cumulative Sales %`
- Sort by `Net Sales` descending

**Matrix** — the classification summary
- Rows: `ABC Class`
- Values: `Active Products`, `Net Sales`, `Gross Margin %`,
  `Stock Value at Cost`, `Stock Cover Days`

This is the money table. If C-class products hold a
disproportionate share of stock value, that is working capital
tied up in items nobody buys — and it is a recommendation, not
just an observation.

**Titles**
- "A handful of products carry the revenue"
- "C-class products tie up stock out of proportion to their sales"

---

## Page 3 — Inventory & Expiry Risk

*What is sitting on the shelf and how much of it is at risk.*

**Cards**
`Stock Value at Cost` · `Expired Stock Value` ·
`At-Risk Stock Value` · `At-Risk Stock %`

At-Risk is 34.6% of stock. Put that card in red.

**Column chart** — the expiry profile
- X: `Fact_Stock[expiry_bucket]`
- Y: `Stock Value at Cost`
- Colour the first two buckets red, the rest navy

**Table** — worst offenders
- `product_name`, `manufacturer`, `Stock Value at Cost`,
  `Stock Cover Days`, `ABC Class`
- Filter: `expiry_bucket` = already expired or 0-3 months
- Sort by `Stock Value at Cost` descending, top 30

**Scatter** — cover days against months to expiry
- X: `Fact_Stock[months_to_expiry]`
- Y: `Stock Cover Days`
- Size: `Stock Value at Cost`

Anything with more cover days than months to expiry will expire
before it sells. That quadrant is the buying error, and it is
visible at a glance.

**Slicers:** `Dim_Product[manufacturer]`, `[category]`

**Titles**
- "A third of stock value is expired or expiring within 90 days"
- "Stock that will expire before it sells"

---

## Page 4 — Expiry Returns

*The strongest page. Nobody else's portfolio has this.*

**Cards**
`Returns to Suppliers` · `Prompt Return %` ·
`Avg Return Lag (months)`

**Column chart** — the lag distribution
- X: `Fact_Expiry_Return[lag_bucket]`
- Y: `Returns to Suppliers`
- Green for the two pre-expiry buckets, amber then red after

**Line chart** — monthly returns, the lockdown signature
- X: `Dim_Date[Month Year]`
- Y: `Returns to Suppliers`

April 2020 is the lowest month in the series; June 2020 is nearly
three times any other. Lockdown ran 25 March to 31 May. Goods
could not move, then the backlog cleared in one month. Annotate
both points with a text box.

**Bar chart** — returns by supplier
- Y: `Fact_Expiry_Return[supp_id]`, X: `Returns to Suppliers`
- Top 20

Only 39 suppliers receive returns against 204 manufacturers in
the product master. That concentration is worth a sentence.

**Table** — most-returned products
- `product_name`, `manufacturer`, `Returns to Suppliers`,
  `Avg Return Lag (months)`, `Net Sales`

**Titles**
- "84.6% of expired stock goes back within two months or earlier"
- "Lockdown froze returns in April; June cleared the backlog"

---

## Page 5 — Receivables

*Who owes what, and for how long.*

**Cards**
`Total Outstanding` · `DSO Days` · `Active Customers`

**Note:** every bill in `Fact_Ageing` is overdue — minimum 230
days, maximum 1,087. The table appears to retain only unsettled
bills. So `Overdue Amount` equals `Total Outstanding` and is not
worth showing. Say this in a text box rather than leaving a
reader to wonder.

**Column chart** — ageing buckets
Create a calculated column on `Fact_Ageing`:

```dax
Ageing Bucket =
SWITCH(
    TRUE(),
    Fact_Ageing[days_overdue] <= 90,  "1. 0-90 days",
    Fact_Ageing[days_overdue] <= 180, "2. 91-180 days",
    Fact_Ageing[days_overdue] <= 365, "3. 181-365 days",
                                      "4. over 1 year"
)
```

- X: `Ageing Bucket`, Y: `Total Outstanding`

**Table** — largest exposures
- `cust_id`, `area_name`, `Total Outstanding`, `Net Sales`,
  `DSO Days`
- Top 25 by `Total Outstanding`

A customer with high outstanding and low sales is the one to
chase. That contrast is the whole point of putting both columns
side by side.

**Titles**
- "53 days sales outstanding across a 1.4 crore book"
- "Every bill on the ledger is past due"

---

## What to say about what is missing

Put a text box on Page 1. Stating limitations reads as rigour;
leaving them unstated reads as carelessness.

- Single financial year (2020-21), so no trend or seasonality
  claims beyond within-year movement
- Values scaled by a constant factor for confidentiality;
  all ratios and rankings unaffected
- Stock adjustment data records gross book-to-physical variance
  and could not be reconciled to the accounting write-off, so it
  is excluded from loss analysis
- Margin derived from batch purchase rate; the software's own
  profit fields were not configured
- FY 2020-21 was materially affected by COVID lockdowns

---

## Then

Export to PDF, publish to Power BI Service if you want a live
link, push the SQL scripts to GitHub with a README, and write
600-800 words on what you found.

The write-up matters more than a sixth page. Lead with the expiry
return lag and the lockdown disruption — those are findings a
generalist analyst could not have reached, because they required
knowing that `PurRetSendDetail` was where the answer lived.
