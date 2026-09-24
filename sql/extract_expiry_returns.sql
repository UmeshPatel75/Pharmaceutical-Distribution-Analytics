/* ============================================================
   Atul Medico - PART 5: expiry returns to suppliers

   PurRetSendMstr / PurRetSendDetail is where expiry and damage
   returns actually live. The FAPRD expiry fields were never
   populated, so this table is the only record of the return
   process -- and it carries the three findings worth building
   the project around:

     - return lag: how long between expiry and credit
     - recovery rate: how much expired stock got returned
     - lockdown disruption: April 2020 vs June 2020

   Run AFTER extract_anonymised.sql (needs anon.Config and
   anon.SupplierMap).

   No TRY_CONVERT -- compatibility level 100 safe.
   ============================================================ */

USE ATUL202021;
GO

IF OBJECT_ID('anon.fact_expiry_returns') IS NOT NULL
    DROP VIEW anon.fact_expiry_returns;
GO

CREATE VIEW anon.fact_expiry_returns AS
SELECT
    CAST(m.INV_DATE AS date)                     AS return_date,
    ISNULL(s.supp_id, 'SUPP_UNMAPPED')           AS supp_id,
    m.INVOICE_NO                                 AS return_doc_no,
    d.PRD_CODE                                   AS prd_code,
    d.QTY_CODE                                   AS batch_key,
    d.BATCH_NO                                   AS batch_no,
    d.EXP_DATE                                   AS exp_date_raw,
    e.exp_date,
    -- Negative = returned BEFORE expiry (near-expiry return,
    -- good practice). Positive = returned after it expired.
    CASE WHEN e.exp_date IS NULL THEN NULL
         ELSE DATEDIFF(month, e.exp_date, m.INV_DATE)
    END                                          AS months_after_expiry,
    CASE WHEN e.exp_date IS NULL                              THEN 'unknown'
         WHEN DATEDIFF(month, e.exp_date, m.INV_DATE) <  -6   THEN '1. over 6 mth before expiry'
         WHEN DATEDIFF(month, e.exp_date, m.INV_DATE) <   0   THEN '2. near-expiry return'
         WHEN DATEDIFF(month, e.exp_date, m.INV_DATE) <=  2   THEN '3. within 2 mth after'
         WHEN DATEDIFF(month, e.exp_date, m.INV_DATE) <=  5   THEN '4. 3-5 mth after'
         ELSE                                                      '5. over 5 mth after'
    END                                          AS lag_bucket,
    d.QUANTITY                                   AS qty_returned,
    d.FREE_QNTY                                  AS free_qty,
    CAST(d.RATE   * c.ScaleFactor AS decimal(18,4)) AS rate,
    CAST(d.MRP    * c.ScaleFactor AS decimal(18,4)) AS mrp,
    CAST(d.AMOUNT * c.ScaleFactor AS decimal(18,4)) AS value_returned
FROM        dbo.PurRetSendMstr m
JOIN        dbo.PurRetSendDetail d
           ON  d.COMP_NO    = m.COMP_NO
           AND d.BOOK_CODE  = m.BOOK_CODE
           AND d.INVOICE_NO = m.INVOICE_NO
CROSS JOIN  anon.Config c
LEFT JOIN   anon.SupplierMap s ON s.PARTY_CODE = m.PARTY_CODE
CROSS APPLY (
    SELECT CASE WHEN LEN(LTRIM(RTRIM(d.EXP_DATE))) = 7
                 AND ISDATE(RIGHT(RTRIM(d.EXP_DATE), 4)
                          + LEFT(LTRIM(d.EXP_DATE), 2) + '01') = 1
                THEN CAST(RIGHT(RTRIM(d.EXP_DATE), 4)
                        + LEFT(LTRIM(d.EXP_DATE), 2) + '01' AS date)
                ELSE NULL
           END AS exp_date
) e;
GO


/* ------------------------------------------------------------
   Checks - confirm before exporting
   ------------------------------------------------------------ */

-- 1. Row count and how many suppliers failed to map.
--    Return parties may not all appear in FAPUR.
SELECT  COUNT(*)                                              AS lines,
        COUNT(DISTINCT supp_id)                               AS suppliers,
        SUM(CASE WHEN supp_id = 'SUPP_UNMAPPED' THEN 1 ELSE 0 END) AS unmapped_lines,
        SUM(CASE WHEN exp_date IS NULL THEN 1 ELSE 0 END)     AS unparseable_expiry,
        SUM(value_returned)                                   AS total_scaled
FROM    anon.fact_expiry_returns;
GO

-- 2. Lag profile. Should show the mode just after expiry.
SELECT  lag_bucket,
        COUNT(*)            AS lines,
        SUM(value_returned) AS value_scaled
FROM    anon.fact_expiry_returns
GROUP BY lag_bucket
ORDER BY lag_bucket;
GO

-- 3. FY 2020-21 only, by month. April vs June is the
--    lockdown signature.
SELECT  YEAR(return_date)  AS yr,
        MONTH(return_date) AS mth,
        COUNT(*)           AS lines,
        SUM(value_returned) AS value_scaled
FROM    anon.fact_expiry_returns
WHERE   return_date BETWEEN '2020-04-01' AND '2021-03-31'
GROUP BY YEAR(return_date), MONTH(return_date)
ORDER BY yr, mth;
GO
