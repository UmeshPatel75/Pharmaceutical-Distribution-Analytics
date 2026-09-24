# Pharmaceutical Distribution Analytics — FY 2020-21

**Analysis of a Surat-based pharmaceutical stockist and distributor**
Net sales ₹11.5 crore · 4,000 customers · 4,667 products · 204 principals · 108,364 invoices

*All monetary figures in this report are scaled by a constant factor
for confidentiality. Ratios, rankings, trends and percentages are
unaffected. Customer and supplier names are replaced with codes.*

---

## Why this analysis

I spent nine years running this business as a partner. The billing
system captured every invoice line, batch and expiry date for that
period, but the reporting never went beyond monthly sales totals and
outstanding statements — which is true of most distribution SMEs in
India.

This project asks what the transactional data can answer that the
standard reports cannot: where margin actually comes from, how much
inventory will expire before it sells, whether the expiry return
process works, and which customers carry real credit risk.

**Stack:** SQL Server (extraction, anonymisation), Power BI (star
schema, DAX), 502,482 invoice lines across six fact tables.

---

## What the year looked like

Revenue held roughly flat through FY 2020-21 at ₹8-10 lakh a month.
Gross margin did not.

**Margin ran about 3.2% in April 2020 and about 1.3% by March 2021 —
it more than halved while sales were steady.** Full-year gross margin
was 2.49%.

Two causes, both visible from inside the business: COVID discounting
to keep retailers ordering through a collapsed footfall period, and
scheme pressure from principals pushing volume on declining demand.
Neither shows up in a sales report; both show up immediately once
line-level margin is computed against batch purchase cost.

Margin also varies sharply by segment:

| Segment | Net sales | Gross margin % |
|---|---|---|
| Allopathic | ₹9.03 cr | **2.19%** |
| Ayurvedic | ₹41.2 lakh | **8.61%** |
| Vaccine | ₹14.2 lakh | 3.23% |

Ayurvedic earns nearly four times the margin of allopathic on 4.5% of
the revenue. Allopathic volume is price-bound by scheduled pricing and
scheme structures; ayurvedic is not.

---

## Concentration: 25% of products carry 80% of revenue

| Class | Products | Sales share | Margin | Stock value | Cover days |
|---|---|---|---|---|---|
| A | 1,064 | 80.2% | 2.08% | ₹1.06 cr | **45** |
| B | 1,173 | 15.0% | 4.16% | ₹35.1 lakh | **78** |
| C | 1,940 | 5.0% | 4.07% | ₹29.5 lakh | **182** |
| No sales | 5,704 | — | — | ₹10.4 lakh | — |

Two things worth drawing out.

**A-class earns the thinnest margin.** The fast movers are the
price-competitive ones; the slow movers carry margin but tie up cash.
That tension is the central working-capital problem of the business.

**Slow movers consume 22% of inventory for 5% of revenue.** C-class
plus dead stock is ₹39.9 lakh, turning at 182 days against A-class's
45.

---

## Expiry risk: ₹76 lakh, with an important caveat

Comparing each product's stock cover against its own remaining shelf
life, **₹76 lakh — 42% of inventory — would expire before it sold at
FY 2020-21 selling rates.** At 31 March 2021, ₹56 lakh had already
passed expiry and a further ₹40 lakh was within 90 days.

**This figure should not be read as a pure inventory-control failure,
and the data itself says why.**

The business migrated from DOS-based software to a Windows system,
with stock transferred partly automatically and partly by manual
entry. The database shows the signature of that migration:
`OPEN_STOCK` equals `CURR_STOCK` *exactly* on all 15,726 in-stock
batches. A genuine year-opening balance would diverge from closing
stock as goods moved. This field was written by a bulk load, so
opening balances cannot be independently verified, and some portion of
the expired stock is likely to be migration residue rather than real
goods on a shelf.

Three further factors apply, in declining order of confidence:

- **Dormancy.** 9,304 batches — ₹51.5 lakh, 28% of stock value —
  recorded no sale and no purchase across the entire year. ₹27.3 lakh
  of that had already expired. Genuinely dead records, live goods, or
  a mix; the data cannot separate them.
- **COVID.** Movement was slow across the board and seasonal lines
  barely moved at all, so cover-day calculations based on FY 2020-21
  offtake overstate expiry risk for products that sell normally in an
  ordinary year.
- **New launches.** Recently introduced products had not yet
  established velocity and appear as slow movers by construction.

**The defensible statement is narrower than the headline number:**
₹27.3 lakh of expired stock sits in batches that saw no movement
whatsoever during the year, and the recorded opening balances cannot
be verified. A physical stock verification would be needed to size the
real loss.

---

## The return process works, and it is the operational strength

Expired and near-expiry stock goes back to suppliers for credit.
₹89.4 lakh moved back across 27 months, ₹69.6 lakh during FY 2020-21.

**84.6% of return value goes back within two months of expiry or
earlier.** The value-weighted average lag is **−1.27 months**, meaning
the typical return leaves *before* the batch expires. 31.8% of value
is returned pre-expiry — proactive near-expiry management, not damage
control.

Set against the expiry findings, this matters: the process for
recovering value is sound. The problem is upstream, in how much slow-
moving stock enters the building.

**Returns concentrate on 39 suppliers against 204 principals.** Worth
knowing which 39, and whether concentration reflects who accepts
returns readily rather than who supplies the most.

---

## Lockdown is visible in the returns ledger

April 2020 was the lowest month in the entire 27-month series —
₹0.61 lakh across 8 documents. June 2020 was the highest at ₹15.44
lakh across 5,906 lines, nearly three times any other month.

India's first lockdown ran 25 March to 31 May 2020. Goods physically
could not move. April collapsed, May partially recovered, and June
cleared the accumulated backlog in a single month.

This does not appear in any sales report. It is only visible in a
table that records supplier returns — which is the argument for
analysing operational data and not only revenue.

---

## Receivables: size is not the risk, ratio is

₹1.40 crore outstanding, DSO 53 days, value-weighted average age 392
days. Every bill on the ledger is past due — the ageing table retains
only unsettled items, so the split between current and overdue is not
available.

The useful measure is outstanding as a proportion of what a customer
actually buys:

| Customer | Outstanding | Annual purchases | % of sales |
|---|---|---|---|
| CUST_2910 | ₹1.99 lakh | ₹1.55 lakh | **128%** |
| CUST_0646 | ₹4.24 lakh | ₹5.72 lakh | **74%** |
| CUST_6499 | ₹1.34 lakh | ₹1.87 lakh | **72%** |
| CUST_7782 | ₹3.00 lakh | ₹24.24 lakh | **12%** |

CUST_7782 is the largest balance-holder on the book and among the
safest — it owes six weeks of its own purchasing. CUST_2910 owes more
than it buys in a year. **A collections list sorted by balance would
chase the wrong customers.**

---

## Recommendations

**1. Cap purchase quantities on C-class lines.**
₹29.5 lakh sits in products turning at 182 days for 5% of revenue.
Moving C-class to smaller, more frequent orders — or to order-on-
demand for the slowest — releases working capital without touching
service on the lines that matter.

**2. Run a physical stock verification before writing anything off.**
The ₹76 lakh expiry exposure cannot be relied on while opening
balances carry the migration signature. A count separates real goods
from ledger residue, and until that is done the number is an upper
bound, not a loss.

**3. Bring the near-expiry return trigger forward on slow movers.**
The return process already performs well at −1.27 months average lag.
Applying a longer lead — six months rather than two — specifically to
C-class and newly launched products would catch more value before the
supplier window closes.

**4. Review scheme-driven purchasing against margin.**
Several A-class products carry negative gross margin once free scheme
goods are costed in. Some are deliberate loss-leaders; others are
volume bought for a scheme that did not pay back. The line-level
margin calculation now makes the difference visible.

**5. Reset collections priority to outstanding-as-%-of-purchases.**
Chasing the largest balances misdirects effort toward good customers.
Customers above roughly 50% of annual purchases are the exposure.

**6. Retire dead product masters.**
5,704 products recorded no sales; 1,367 sit under placeholder
manufacturer records. Cleaning the master reduces picking errors and
makes every subsequent report more reliable.

---

## Limitations

- **Single financial year** (April 2020 – March 2021). No trend or
  seasonality claims beyond within-year movement.
- **FY 2020-21 was materially distorted by COVID.** Selling rates
  underpinning cover-day and expiry calculations are not typical.
- **Opening stock balances cannot be verified** — see the migration
  evidence above.
- **Stock adjustment data excluded from loss analysis.** The shortage
  table records gross book-to-physical variance from year-end counts
  (₹1.19 crore for the FY 2020-21 cycle) and could not be reconciled
  to the accounting write-off, so no shrinkage figure is claimed.
- **Margin derived from batch purchase rate.** The software's own
  profit fields were never configured (NULL on 501,716 of 502,489
  lines), so margin is computed as net sale value less quantity times
  the purchase rate of the batch billed from.
- **Ten batch rows reference deleted product masters**, holding
  ₹1.50 lakh of stock.
- **Figures scaled** by a constant factor; ratios unaffected.

---

## Method

Source data extracted from SQL Server via views that anonymise
customers and suppliers, drop all addresses, tax registrations and
licence numbers, and scale monetary values. Eight tables exported to
CSV and modelled in Power BI as a star schema: six fact tables
(sales, stock, purchases, expiry returns, receivables, stock
adjustments) sharing conformed product, customer and date dimensions.

Analytical logic — ABC classification, stock cover, expiry bucketing,
return lag, receivables ageing — implemented in DAX. SQL extraction
scripts and the full measure list are in the repository.
