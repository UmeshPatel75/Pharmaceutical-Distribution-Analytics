/* ============================================================
   Atul Medico - PART 3: decode the code columns
   Small result sets. Codes and counts only, no names, no
   customer-identifying data.
   ============================================================ */

USE ATUL202021;
GO

-- 1. Date range and scale -------------------------------------
SELECT  MIN(INV_DATE)               AS first_invoice,
        MAX(INV_DATE)               AS last_invoice,
        COUNT(*)                    AS invoice_lines,
        COUNT(DISTINCT PARTY_CODE)  AS customers,
        COUNT(DISTINCT PRD_CODE)    AS products,
        COUNT(DISTINCT INVOICE_NO)  AS invoices;
GO
-- (run against dbo.FAINV -- added below so it executes)
SELECT  MIN(INV_DATE) AS first_invoice, MAX(INV_DATE) AS last_invoice,
        COUNT(*) AS invoice_lines,
        COUNT(DISTINCT PARTY_CODE) AS customers,
        COUNT(DISTINCT PRD_CODE) AS products
FROM    dbo.FAINV;
GO


-- 2. What do the transaction-type codes mean? -----------------
-- Critical: I must not add sales returns to sales.
SELECT  VOUCH_TYPE, BILL_TYPE, INV_CODE,
        COUNT(*)        AS lines,
        SUM(NETT_SALE)  AS total_nett,
        MIN(INV_DATE)   AS first_date,
        MAX(INV_DATE)   AS last_date
FROM    dbo.FAINV
GROUP BY VOUCH_TYPE, BILL_TYPE, INV_CODE
ORDER BY lines DESC;
GO


-- 3. How are parties classified? ------------------------------
-- FAPAR holds customers, suppliers, banks and ledger heads in
-- one table. LDG_CODE and PARTY_TYPE should separate them.
SELECT  LDG_CODE, PARTY_TYPE, IsInstitute,
        COUNT(*)            AS parties,
        SUM(CASE WHEN CURR_BAL <> 0 THEN 1 ELSE 0 END) AS with_balance
FROM    dbo.FAPAR
GROUP BY LDG_CODE, PARTY_TYPE, IsInstitute
ORDER BY parties DESC;
GO


-- 4. Which parties actually appear as customers in sales? -----
SELECT  p.LDG_CODE,
        COUNT(DISTINCT i.PARTY_CODE) AS distinct_parties_in_sales,
        COUNT(*)                     AS sales_lines
FROM    dbo.FAINV i
JOIN    dbo.FAPAR p ON p.PARTY_CODE = i.PARTY_CODE
                   AND p.COMP_NO    = i.COMP_NO
GROUP BY p.LDG_CODE
ORDER BY sales_lines DESC;
GO


-- 5. EXP_DATE is nvarchar(7) -- what format? ------------------
-- Need this to compute months-to-expiry. No product identity
-- revealed; just the string shape.
SELECT TOP 10 EXP_DATE, COUNT(*) AS occurrences
FROM    dbo.FAPRD
WHERE   EXP_DATE IS NOT NULL AND LTRIM(RTRIM(EXP_DATE)) <> ''
GROUP BY EXP_DATE
ORDER BY occurrences DESC;
GO


-- 6. Stock position sanity check ------------------------------
SELECT  COUNT(*)                                    AS batch_rows,
        COUNT(DISTINCT PRD_CODE)                    AS products,
        SUM(CASE WHEN CURR_STOCK > 0 THEN 1 ELSE 0 END) AS batches_in_stock,
        SUM(CASE WHEN ExpStock  > 0 THEN 1 ELSE 0 END)  AS batches_expired,
        SUM(CASE WHEN TOTAL_EXP > 0 THEN 1 ELSE 0 END)  AS batches_with_expiry_writeoff
FROM    dbo.FAPRD;
GO


-- 7. Is the pre-computed profit column populated? -------------
-- If ItemProfitAmt is mostly zero or null the software was not
-- configured to track it, and margin must be derived instead.
SELECT  COUNT(*)                                          AS lines,
        SUM(CASE WHEN ItemProfitAmt IS NULL THEN 1 ELSE 0 END) AS null_profit,
        SUM(CASE WHEN ItemProfitAmt = 0 THEN 1 ELSE 0 END)     AS zero_profit,
        SUM(CASE WHEN LandingCost  > 0 THEN 1 ELSE 0 END)      AS has_landing_cost
FROM    dbo.FAINV;
GO


-- 8. SALE_TYPE / tax-class spread -----------------------------
SELECT TOP 10 SALE_TYPE, COUNT(*) AS lines
FROM    dbo.FAINV
GROUP BY SALE_TYPE
ORDER BY lines DESC;
GO
