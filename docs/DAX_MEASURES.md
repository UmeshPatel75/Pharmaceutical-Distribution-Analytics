# DAX measures

Twenty-nine measures across six fact tables, grouped by display
folder as they appear in the Power BI field list.

## 1 Sales

```dax
Net Sales = SUM ( Fact_Sales[nett_sale] )
```
Sales returns are stored with a negative sign, so a plain SUM is
already net of returns.

```dax
Gross Sales =
CALCULATE ( SUM ( Fact_Sales[nett_sale] ), Fact_Sales[txn_type] = "Sale" )

Sales Returns =
-CALCULATE ( SUM ( Fact_Sales[nett_sale] ), Fact_Sales[txn_type] = "Sales Return" )

Return Rate % = DIVIDE ( [Sales Returns], [Gross Sales] )

Invoice Count = DISTINCTCOUNT ( Fact_Sales[invoice_no] )

Average Invoice Value = DIVIDE ( [Net Sales], [Invoice Count] )
```

## 2 Margin

The billing software's own profit fields were never configured, so
margin is derived from the purchase rate of the batch each line was
billed from.

```dax
Gross Margin = SUM ( Fact_Sales[gross_margin] )

Gross Margin % = DIVIDE ( [Gross Margin], [Net Sales] )
```

## 4 ABC classification

Implemented as calculated **columns** on `Dim_Product`, not measures,
so classification is stable across slicer selections and can be used
in Legend and Matrix Rows.

```dax
Product Sales = COALESCE ( CALCULATE ( [Net Sales] ), 0 )

Product Rank =
IF (
    Dim_Product[Product Sales] > 0,
    RANKX (
        FILTER ( ALL ( Dim_Product ), Dim_Product[Product Sales] > 0 ),
        Dim_Product[Product Sales], , DESC, Dense
    )
)

Cumulative Sales % =
VAR CurrentSales = Dim_Product[Product Sales]
VAR TotalSales =
    SUMX (
        FILTER ( ALL ( Dim_Product ), Dim_Product[Product Sales] > 0 ),
        Dim_Product[Product Sales]
    )
VAR RunningTotal =
    SUMX (
        FILTER (
            ALL ( Dim_Product ),
            Dim_Product[Product Sales] >= CurrentSales
                && Dim_Product[Product Sales] > 0
        ),
        Dim_Product[Product Sales]
    )
RETURN
    IF ( Dim_Product[Product Sales] > 0, DIVIDE ( RunningTotal, TotalSales ) )

ABC Class =
VAR Cum = Dim_Product[Cumulative Sales %]
RETURN
SWITCH (
    TRUE (),
    Dim_Product[Product Sales] <= 0, "D - no sales",
    Cum <= 0.80, "A",
    Cum <= 0.95, "B",
    "C"
)
```

## 5 Inventory

```dax
Stock Value at Cost =
SUMX ( Fact_Stock, Fact_Stock[curr_stock] * Fact_Stock[pur_rate] )

At-Risk Stock Value =
CALCULATE (
    [Stock Value at Cost],
    Fact_Stock[expiry_bucket] IN { "1. already expired", "2. 0-3 months" }
)

Stock Cover Days =
VAR DailySales =
    DIVIDE ( CALCULATE ( SUM ( Fact_Sales[qty_signed] ), REMOVEFILTERS ( Dim_Date ) ), 365 )
VAR OnHand = SUM ( Fact_Stock[curr_stock] )
RETURN
    IF ( DailySales > 0, DIVIDE ( OnHand, DailySales ) )
```

Stock-value-weighted expiry, excluding batches with no stock and
corrupt dates outside a -24 to +36 month window:

```dax
Months to Expiry (weighted) =
VAR Batches =
    FILTER (
        Fact_Stock,
        Fact_Stock[curr_stock] > 0
            && NOT ISBLANK ( Fact_Stock[months_to_expiry] )
            && Fact_Stock[months_to_expiry] >= -24
            && Fact_Stock[months_to_expiry] <= 36
    )
RETURN
DIVIDE (
    SUMX ( Batches, Fact_Stock[months_to_expiry] * Fact_Stock[curr_stock] * Fact_Stock[pur_rate] ),
    SUMX ( Batches, Fact_Stock[curr_stock] * Fact_Stock[pur_rate] )
)
```

Stock in products whose cover exceeds their remaining shelf life —
inventory that will expire before it can be sold:

```dax
Stock Expiring Before Sale =
SUMX (
    VALUES ( Dim_Product[prd_code] ),
    VAR Cover = [Stock Cover Months]
    VAR ToExpiry = [Months to Expiry (weighted)]
    RETURN
        IF (
            NOT ISBLANK ( ToExpiry ) && NOT ISBLANK ( Cover ) && Cover > ToExpiry,
            [Stock Value at Cost]
        )
)
```

## 7 Expiry returns

```dax
Returns to Suppliers = SUM ( Fact_Expiry_Return[value_returned] )
```

Value-weighted months between batch expiry and return. Negative means
the batch went back before it expired.

```dax
Avg Return Lag (months) =
VAR Valid =
    FILTER ( Fact_Expiry_Return, NOT ISBLANK ( Fact_Expiry_Return[months_after_expiry] ) )
RETURN
DIVIDE (
    SUMX ( Valid, Fact_Expiry_Return[months_after_expiry] * Fact_Expiry_Return[value_returned] ),
    SUMX ( Valid, Fact_Expiry_Return[value_returned] )
)

Prompt Return % =
VAR Prompt =
    CALCULATE (
        [Returns to Suppliers],
        Fact_Expiry_Return[lag_bucket] IN {
            "1. over 6 mth before expiry",
            "2. near-expiry return",
            "3. within 2 mth after"
        }
    )
RETURN DIVIDE ( Prompt, [Returns to Suppliers] )
```

## 8 Receivables

```dax
Total Outstanding = SUM ( Fact_Ageing[outstanding] )

Avg Days Outstanding =
DIVIDE (
    SUMX ( Fact_Ageing, Fact_Ageing[outstanding] * Fact_Ageing[days_overdue] ),
    SUM ( Fact_Ageing[outstanding] )
)

Outstanding % of Sales = DIVIDE ( [Total Outstanding], [Net Sales] )
```

`Outstanding % of Sales` is the useful collections measure. Sorting by
balance alone chases the largest customers; sorting by this ratio finds
the ones whose exposure is disproportionate to what they buy.

## Model structure

Six fact tables sharing conformed dimensions:

```
            Dim_Date
                |
  +-------+-----+-----+--------+-----------+
  |       |           |        |           |
Sales  Purchase  Shortage  Expiry_Ret   Ageing
  |       |           |        |           |
  +--- Dim_Product ---+        |           |
  |                            |           |
  +------------ Dim_Customer --+-----------+
```

`Fact_Stock` joins `Dim_Product` only — it is a position at a point in
time, not a dated transaction.
