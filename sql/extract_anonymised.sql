/* ============================================================
   Atul Medico - PART 4: anonymised extraction

   Creates an [anon] schema of views that expose the analysis
   data with:
     - customer and supplier names replaced by stable codes
     - all monetary values multiplied by one scaling factor
     - no addresses, phone numbers, GSTINs, DL numbers or PANs

   Product and manufacturer brand names are kept: they are
   public information and the analysis is meaningless without
   them.

   Run once. Then export each anon.* view to CSV.
   ============================================================ */

USE ATUL202021;
GO

/* ------------------------------------------------------------
   0a. What compatibility level is this database on?
   TRY_CONVERT needs 110+. Everything below avoids it, so this
   is for information only -- no need to change anything.
   ------------------------------------------------------------ */
SELECT  name, compatibility_level
FROM    sys.databases
WHERE   name = 'ATUL202021';
GO


/* ------------------------------------------------------------
   0b. DIAGNOSTIC - expiry profile of stock actually on hand.
   EXP_DATE is 'MM/YYYY'. Parsed by rebuilding it as YYYYMMDD,
   which CAST accepts unambiguously on every SQL Server version.
   ISDATE guards against malformed values.
   ------------------------------------------------------------ */
SELECT  CASE
            WHEN exp_dt IS NULL          THEN 'unparseable'
            WHEN exp_dt < '2021-04-01'   THEN '1. already expired'
            WHEN exp_dt < '2021-07-01'   THEN '2. 0-3 months'
            WHEN exp_dt < '2021-10-01'   THEN '3. 3-6 months'
            WHEN exp_dt < '2022-04-01'   THEN '4. 6-12 months'
            ELSE                              '5. over 12 months'
        END                                  AS expiry_bucket,
        COUNT(*)                             AS batches,
        SUM(CURR_STOCK)                      AS units,
        SUM(CURR_STOCK * PUR_RATE)           AS value_at_cost
FROM (
    SELECT  p.CURR_STOCK, p.PUR_RATE,
            CASE WHEN LEN(LTRIM(RTRIM(p.EXP_DATE))) = 7
                  AND ISDATE(RIGHT(RTRIM(p.EXP_DATE), 4)
                           + LEFT(LTRIM(p.EXP_DATE), 2) + '01') = 1
                 THEN CAST(RIGHT(RTRIM(p.EXP_DATE), 4)
                         + LEFT(LTRIM(p.EXP_DATE), 2) + '01' AS date)
                 ELSE NULL
            END AS exp_dt
    FROM    dbo.FAPRD p
    WHERE   p.CURR_STOCK > 0
) x
GROUP BY CASE
            WHEN exp_dt IS NULL          THEN 'unparseable'
            WHEN exp_dt < '2021-04-01'   THEN '1. already expired'
            WHEN exp_dt < '2021-07-01'   THEN '2. 0-3 months'
            WHEN exp_dt < '2021-10-01'   THEN '3. 3-6 months'
            WHEN exp_dt < '2022-04-01'   THEN '4. 6-12 months'
            ELSE                              '5. over 12 months'
         END
ORDER BY expiry_bucket;
GO


/* ------------------------------------------------------------
   1. Scaling factor and anonymisation maps
   ------------------------------------------------------------ */
IF SCHEMA_ID('anon') IS NULL EXEC('CREATE SCHEMA anon');
GO

-- Change this if you like. Any value works; keep it constant
-- so every table scales identically and ratios stay true.
IF OBJECT_ID('anon.Config') IS NOT NULL DROP TABLE anon.Config;
CREATE TABLE anon.Config (ScaleFactor decimal(10,6));
INSERT INTO anon.Config VALUES (0.8317);
GO

-- Customer map. Stays in the database. NEVER export this view.
IF OBJECT_ID('anon.CustomerMap') IS NOT NULL DROP TABLE anon.CustomerMap;
CREATE TABLE anon.CustomerMap (
    PARTY_CODE nvarchar(10) PRIMARY KEY,
    cust_id    nvarchar(12)
);
INSERT INTO anon.CustomerMap (PARTY_CODE, cust_id)
SELECT  PARTY_CODE,
        'CUST_' + RIGHT('0000' + CAST(
            ROW_NUMBER() OVER (ORDER BY PARTY_CODE) AS nvarchar(10)), 4)
FROM    dbo.FAPAR
WHERE   LDG_CODE = '07';
GO

-- Supplier map, built from who actually appears in purchases.
IF OBJECT_ID('anon.SupplierMap') IS NOT NULL DROP TABLE anon.SupplierMap;
CREATE TABLE anon.SupplierMap (
    PARTY_CODE nvarchar(10) PRIMARY KEY,
    supp_id    nvarchar(12)
);
INSERT INTO anon.SupplierMap (PARTY_CODE, supp_id)
SELECT  PARTY_CODE,
        'SUPP_' + RIGHT('000' + CAST(
            ROW_NUMBER() OVER (ORDER BY PARTY_CODE) AS nvarchar(10)), 3)
FROM   (SELECT DISTINCT PARTY_CODE FROM dbo.FAPUR) s;
GO


/* ------------------------------------------------------------
   2. fact_sales - invoice lines
   SR rows are flagged, NOT silently added to sales.
   ------------------------------------------------------------ */
IF OBJECT_ID('anon.fact_sales') IS NOT NULL DROP VIEW anon.fact_sales;
GO
CREATE VIEW anon.fact_sales AS
SELECT
    CAST(i.INV_DATE AS date)                      AS inv_date,
    i.INVOICE_NO                                  AS invoice_no,
    m.cust_id,
    i.PRD_CODE                                    AS prd_code,
    i.MFG_CODE                                    AS mfg_code,
    i.BATCH_NO                                    AS batch_no,
    i.QTY_CODE                                    AS batch_key,
    CASE i.VOUCH_TYPE WHEN 'SL' THEN 'Sale'
                      WHEN 'SR' THEN 'Sales Return'
                      ELSE i.VOUCH_TYPE END       AS txn_type,
    CASE i.BILL_TYPE  WHEN 'B' THEN 'Credit'
                      WHEN 'C' THEN 'Cash'
                      ELSE i.BILL_TYPE END        AS bill_type,
    i.SALE_TYPE                                   AS gst_class,
    i.SALESMAN_CODE                               AS salesman_code,
    i.QUANTITY                                    AS qty,
    i.FREE_QNTY                                   AS free_qty,
    i.SCHEMQNTY                                   AS scheme_qty,
    -- Signed so SR subtracts naturally when summed
    CASE WHEN i.VOUCH_TYPE = 'SR' THEN -1 ELSE 1 END
        * i.QUANTITY                              AS qty_signed,
    CAST(i.RATE      * c.ScaleFactor AS decimal(18,4)) AS rate,
    CAST(i.MRP_RATE  * c.ScaleFactor AS decimal(18,4)) AS mrp,
    CAST(i.AMOUNT    * c.ScaleFactor AS decimal(18,4)) AS amount,
    CAST(i.DISC_AMT  * c.ScaleFactor AS decimal(18,4)) AS disc_amt,
    CAST(i.STAX_AMT  * c.ScaleFactor AS decimal(18,4)) AS tax_amt,
    CAST(CASE WHEN i.VOUCH_TYPE = 'SR' THEN -1 ELSE 1 END
         * i.NETT_SALE * c.ScaleFactor AS decimal(18,4)) AS nett_sale,
    -- Cost from the batch this line was billed from
    CAST(p.PUR_RATE * c.ScaleFactor AS decimal(18,4))  AS batch_cost_rate,
    CAST(CASE WHEN i.VOUCH_TYPE = 'SR' THEN -1 ELSE 1 END
         * (i.NETT_SALE - (i.QUANTITY * ISNULL(p.PUR_RATE, 0)))
         * c.ScaleFactor AS decimal(18,4))            AS gross_margin
FROM        dbo.FAINV i
CROSS JOIN  anon.Config c
JOIN        anon.CustomerMap m ON m.PARTY_CODE = i.PARTY_CODE
LEFT JOIN   dbo.FAPRD p        ON p.COMP_NO  = i.COMP_NO
                              AND p.PRD_CODE = i.PRD_CODE
                              AND p.QTY_CODE = i.QTY_CODE;
GO


/* ------------------------------------------------------------
   3. dim_customer - no names, no addresses, no tax numbers
   ------------------------------------------------------------ */
IF OBJECT_ID('anon.dim_customer') IS NOT NULL DROP VIEW anon.dim_customer;
GO
CREATE VIEW anon.dim_customer AS
SELECT
    m.cust_id,
    f.AREA_CODE                                  AS area_code,
    f.AREA_NAME                                  AS area_name,
    f.GROUP_CODE                                 AS group_code,
    f.GROUP_NAME                                 AS group_name,
    f.SALESMAN_CODE                              AS salesman_code,
    CASE f.PARTY_TYPE WHEN 'B' THEN 'Credit'
                      WHEN 'C' THEN 'Cash'
                      ELSE f.PARTY_TYPE END      AS party_type,
    f.Grade                                      AS grade,
    ISNULL(f.IsInstitute, 0)                     AS is_institute,
    f.DUE_DAYS                                   AS due_days,
    f.BillDueDays                                AS bill_due_days,
    CAST(f.CreditLimit * c.ScaleFactor AS decimal(18,2)) AS credit_limit,
    CAST(f.CURR_BAL    * c.ScaleFactor AS decimal(18,2)) AS current_balance,
    ISNULL(f.BillStop, 0)                        AS bill_stopped
FROM        dbo.FAPAR f
CROSS JOIN  anon.Config c
JOIN        anon.CustomerMap m ON m.PARTY_CODE = f.PARTY_CODE
WHERE       f.LDG_CODE = '07';
GO


/* ------------------------------------------------------------
   4. dim_product - brand names kept, they are public
   ------------------------------------------------------------ */
IF OBJECT_ID('anon.dim_product') IS NOT NULL DROP VIEW anon.dim_product;
GO
CREATE VIEW anon.dim_product AS
SELECT
    h.PRD_CODE                                   AS prd_code,
    h.PRD_NAME                                   AS product_name,
    h.MFG_CODE                                   AS mfg_code,
    ISNULL(g.COMP_NAME, h.MFG_NAME)              AS manufacturer,
    h.PACKING                                    AS packing,
    h.PrdCategory                                AS category,
    h.HSN_CODE                                   AS hsn_code,
    gm.GenericName                               AS generic_name,
    CAST(h.MRP       * c.ScaleFactor AS decimal(18,4)) AS mrp,
    CAST(h.PRD_RATE  * c.ScaleFactor AS decimal(18,4)) AS sale_rate,
    CAST(h.PUR_RATE  * c.ScaleFactor AS decimal(18,4)) AS pur_rate,
    h.RetailMargin                               AS retail_margin_pct,
    h.StockistMargin                             AS stockist_margin_pct,
    h.MinStock                                   AS min_stock,
    h.MaxStock                                   AS max_stock,
    h.OPEN_STOCK                                 AS open_stock,
    h.CLOS_STOCK                                 AS close_stock,
    h.TOTAL_SALE                                 AS total_sale_qty,
    h.TOTAL_SRET                                 AS total_return_qty
FROM        dbo.PRODHEAD h
CROSS JOIN  anon.Config c
LEFT JOIN   dbo.MFG_COMP g      ON g.COMP_NO = h.COMP_NO
                               AND g.PRD_CODE = h.MFG_CODE
LEFT JOIN   dbo.GenericMaster gm ON gm.GenericID = h.GenericID;
GO


/* ------------------------------------------------------------
   5. fact_stock - batch level, with months to expiry computed
   ------------------------------------------------------------ */
IF OBJECT_ID('anon.fact_stock') IS NOT NULL DROP VIEW anon.fact_stock;
GO
CREATE VIEW anon.fact_stock AS
SELECT
    p.PRD_CODE                                   AS prd_code,
    p.QTY_CODE                                   AS batch_key,
    p.BATCH_NO                                   AS batch_no,
    p.EXP_DATE                                   AS exp_date_raw,
    e.exp_date,
    CASE WHEN e.exp_date IS NULL THEN NULL
         ELSE DATEDIFF(month, '2021-03-31', e.exp_date)
    END                                          AS months_to_expiry,
    CASE WHEN e.exp_date IS NULL             THEN 'unknown'
         WHEN e.exp_date < '2021-04-01'      THEN '1. already expired'
         WHEN e.exp_date < '2021-07-01'      THEN '2. 0-3 months'
         WHEN e.exp_date < '2021-10-01'      THEN '3. 3-6 months'
         WHEN e.exp_date < '2022-04-01'      THEN '4. 6-12 months'
         ELSE                                     '5. over 12 months'
    END                                          AS expiry_bucket,
    p.CURR_STOCK                                 AS curr_stock,
    p.FREE_STOCK                                 AS free_stock,
    p.OPEN_STOCK                                 AS open_stock,
    p.CLOS_STOCK                                 AS close_stock,
    p.TOTAL_SALE                                 AS total_sale_qty,
    p.TOTAL_PUR                                  AS total_pur_qty,
    p.SHORTAGE                                   AS shortage_qty,
    CAST(p.PUR_RATE  * c.ScaleFactor AS decimal(18,4)) AS pur_rate,
    CAST(p.MRP_RATE  * c.ScaleFactor AS decimal(18,4)) AS mrp,
    CAST(p.SALES_RATE* c.ScaleFactor AS decimal(18,4)) AS sales_rate,
    CAST(p.CURR_STOCK * p.PUR_RATE * c.ScaleFactor
         AS decimal(18,4))                       AS stock_value_at_cost
FROM        dbo.FAPRD p
CROSS JOIN  anon.Config c
CROSS APPLY (
    SELECT CASE WHEN LEN(LTRIM(RTRIM(p.EXP_DATE))) = 7
                 AND ISDATE(RIGHT(RTRIM(p.EXP_DATE), 4)
                          + LEFT(LTRIM(p.EXP_DATE), 2) + '01') = 1
                THEN CAST(RIGHT(RTRIM(p.EXP_DATE), 4)
                        + LEFT(LTRIM(p.EXP_DATE), 2) + '01' AS date)
                ELSE NULL
           END AS exp_date
) e;
GO


/* ------------------------------------------------------------
   6. fact_purchase
   ------------------------------------------------------------ */
IF OBJECT_ID('anon.fact_purchase') IS NOT NULL DROP VIEW anon.fact_purchase;
GO
CREATE VIEW anon.fact_purchase AS
SELECT
    CAST(u.INV_DATE AS date)                     AS inv_date,
    s.supp_id,
    u.PRD_CODE                                   AS prd_code,
    u.MFG_CODE                                   AS mfg_code,
    u.BATCH_NO                                   AS batch_no,
    u.QTY_CODE                                   AS batch_key,
    u.EXP_DATE                                   AS exp_date_raw,
    u.QUANTITY                                   AS qty,
    u.FREE_QNTY                                  AS free_qty,
    CAST(u.RATE     * c.ScaleFactor AS decimal(18,4)) AS rate,
    CAST(u.AMOUNT   * c.ScaleFactor AS decimal(18,4)) AS amount,
    CAST(u.DISC_AMT * c.ScaleFactor AS decimal(18,4)) AS disc_amt,
    CAST(u.NETT_SALE* c.ScaleFactor AS decimal(18,4)) AS nett_purchase
FROM        dbo.FAPUR u
CROSS JOIN  anon.Config c
JOIN        anon.SupplierMap s ON s.PARTY_CODE = u.PARTY_CODE;
GO


/* ------------------------------------------------------------
   7. fact_shortage - demand you could not fulfil
   ------------------------------------------------------------ */
IF OBJECT_ID('anon.fact_shortage') IS NOT NULL DROP VIEW anon.fact_shortage;
GO
CREATE VIEW anon.fact_shortage AS
SELECT
    CAST(s.INV_DATE AS date)                     AS inv_date,
    ISNULL(m.cust_id, 'UNKNOWN')                 AS cust_id,
    s.PRD_CODE                                   AS prd_code,
    s.QUANTITY                                   AS qty_short,
    CAST(s.RATE   * c.ScaleFactor AS decimal(18,4)) AS rate,
    CAST(s.AMOUNT * c.ScaleFactor AS decimal(18,4)) AS value_lost
FROM        dbo.SHORTAGE s
CROSS JOIN  anon.Config c
LEFT JOIN   anon.CustomerMap m ON m.PARTY_CODE = s.PartyCode;
GO


/* ------------------------------------------------------------
   8. fact_ageing - receivables
   ------------------------------------------------------------ */
IF OBJECT_ID('anon.fact_ageing') IS NOT NULL DROP VIEW anon.fact_ageing;
GO
CREATE VIEW anon.fact_ageing AS
SELECT
    m.cust_id,
    CAST(a.InvDate AS date)                      AS inv_date,
    CAST(a.DueDate AS date)                      AS due_date,
    DATEDIFF(day, a.DueDate, '2021-03-31')       AS days_overdue,
    CAST(a.BillAmt * c.ScaleFactor AS decimal(18,2)) AS bill_amt,
    CAST(a.PaidAmt * c.ScaleFactor AS decimal(18,2)) AS paid_amt,
    CAST(a.NetAmt  * c.ScaleFactor AS decimal(18,2)) AS outstanding
FROM        dbo.AgBillYr a
CROSS JOIN  anon.Config c
JOIN        anon.CustomerMap m ON m.PARTY_CODE = a.PartyCode;
GO


/* ------------------------------------------------------------
   9. VERIFY before exporting
   ------------------------------------------------------------ */
SELECT 'fact_sales'    AS view_name, COUNT(*) AS rows FROM anon.fact_sales
UNION ALL SELECT 'dim_customer',  COUNT(*) FROM anon.dim_customer
UNION ALL SELECT 'dim_product',   COUNT(*) FROM anon.dim_product
UNION ALL SELECT 'fact_stock',    COUNT(*) FROM anon.fact_stock
UNION ALL SELECT 'fact_purchase', COUNT(*) FROM anon.fact_purchase
UNION ALL SELECT 'fact_shortage', COUNT(*) FROM anon.fact_shortage
UNION ALL SELECT 'fact_ageing',   COUNT(*) FROM anon.fact_ageing;
GO

-- Sales reconciliation. Net should be roughly 83% of the real
-- figure, because of the scaling factor.
SELECT  txn_type,
        COUNT(*)         AS lines,
        SUM(nett_sale)   AS nett_scaled
FROM    anon.fact_sales
GROUP BY txn_type;
GO
