/* ============================================================
   Atul Medico - schema discovery, PART 2
   The FA* tables are the real ones. My first script's LIKE
   patterns missed them because they are named FAINV / FAPUR /
   FAPRD / FAPAR rather than anything containing 'sale',
   'purchase' or 'product'.

   Structure only. No customer names, no values.
   ============================================================ */

USE ATUL202021;
GO

-- STEP 6 --------------------------------------------------------
-- Columns for the ten tables the analysis actually needs.
SELECT  c.TABLE_NAME,
        c.ORDINAL_POSITION          AS pos,
        c.COLUMN_NAME,
        c.DATA_TYPE,
        c.CHARACTER_MAXIMUM_LENGTH  AS max_len
FROM    INFORMATION_SCHEMA.COLUMNS c
WHERE   c.TABLE_NAME IN (
            'FAINV',      -- sales invoice lines
            'FAINVCOD',   -- sales invoice headers
            'FAPUR',      -- purchase lines
            'FAPURCOD',   -- purchase headers
            'FAPRD',      -- batch-level product stock
            'FAPAR',      -- party master
            'MFG_COMP',   -- manufacturer master
            'AREAMST',    -- area / route master
            'SHORTAGE',   -- unfulfilled demand
            'FAAGBL'      -- ageing / bill settlement
        )
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;
GO


-- STEP 7 --------------------------------------------------------
-- What period does this database actually cover?
-- Adjust the date column name if STEP 6 shows something different
-- (likely INV_DATE or BILL_DATE).
SELECT  MIN(INV_DATE)   AS first_invoice,
        MAX(INV_DATE)   AS last_invoice,
        COUNT(*)        AS invoice_lines,
        COUNT(DISTINCT PARTY_CODE) AS distinct_customers,
        COUNT(DISTINCT PRD_CODE)   AS distinct_products
FROM    dbo.FAINV;
GO


-- STEP 8 --------------------------------------------------------
-- How are parties classified? FAPAR holds customers, suppliers,
-- banks and ledger heads together, so I need to know which
-- column separates them before writing any extract.
-- Run after STEP 6 shows FAPAR's columns; substitute the likely
-- classifier (LDG_CODE, PARTY_TYPE, or similar).
--
-- SELECT LDG_CODE, COUNT(*) AS parties
-- FROM   dbo.FAPAR
-- GROUP BY LDG_CODE
-- ORDER BY parties DESC;
