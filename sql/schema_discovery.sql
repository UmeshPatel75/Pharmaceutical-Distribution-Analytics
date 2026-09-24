/* ============================================================
   Atul Medico database - schema discovery
   Run in SQL Server Management Studio (SSMS) or Azure Data Studio.
   Returns STRUCTURE only: no customer names, no values, no rows.
   Paste the output back into the chat.
   ============================================================ */

-- STEP 1 --------------------------------------------------------
-- Is the database attached, and what other years exist?
SELECT  name                AS database_name,
        state_desc,
        create_date
FROM    sys.databases
WHERE   name NOT IN ('master','tempdb','model','msdb')
ORDER BY name;
GO


-- STEP 2 --------------------------------------------------------
-- Switch to the database. Change the name if STEP 1 shows it
-- registered differently (e.g. ATUL202021_Data).
USE ATUL202021;
GO


-- STEP 3 --------------------------------------------------------
-- Every table with its row count, largest first.
-- The big tables are the transaction tables; the small ones are
-- masters. This alone tells me most of what I need.
SELECT  s.name                      AS schema_name,
        t.name                      AS table_name,
        SUM(p.rows)                 AS row_count
FROM    sys.tables t
JOIN    sys.schemas s   ON t.schema_id = s.schema_id
JOIN    sys.partitions p ON t.object_id = p.object_id
                        AND p.index_id IN (0,1)
GROUP BY s.name, t.name
HAVING  SUM(p.rows) > 0
ORDER BY row_count DESC;
GO


-- STEP 4 --------------------------------------------------------
-- Columns for the tables that look like sales, purchase, stock,
-- product or party masters. Adjust the LIKE patterns after you
-- see STEP 3 output -- billing packages name things differently
-- (Marg, Busy, Tally, Logic, Unisolve all differ).
SELECT  c.TABLE_NAME,
        c.ORDINAL_POSITION          AS pos,
        c.COLUMN_NAME,
        c.DATA_TYPE,
        c.CHARACTER_MAXIMUM_LENGTH  AS max_len,
        c.IS_NULLABLE
FROM    INFORMATION_SCHEMA.COLUMNS c
WHERE   c.TABLE_NAME LIKE '%sale%'
     OR c.TABLE_NAME LIKE '%bill%'
     OR c.TABLE_NAME LIKE '%invoice%'
     OR c.TABLE_NAME LIKE '%purch%'
     OR c.TABLE_NAME LIKE '%stock%'
     OR c.TABLE_NAME LIKE '%item%'
     OR c.TABLE_NAME LIKE '%prod%'
     OR c.TABLE_NAME LIKE '%master%'
     OR c.TABLE_NAME LIKE '%party%'
     OR c.TABLE_NAME LIKE '%ledger%'
     OR c.TABLE_NAME LIKE '%batch%'
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;
GO


-- STEP 5 --------------------------------------------------------
-- Declared foreign keys, if the vendor bothered to define any.
-- Many Indian billing packages do not, so an empty result here
-- is normal and not a problem -- it just means I infer the joins
-- from column names instead.
SELECT  fk.name                     AS fk_name,
        OBJECT_NAME(fk.parent_object_id)      AS from_table,
        cp.name                               AS from_column,
        OBJECT_NAME(fk.referenced_object_id)  AS to_table,
        cr.name                               AS to_column
FROM    sys.foreign_keys fk
JOIN    sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
JOIN    sys.columns cp ON fkc.parent_object_id = cp.object_id
                      AND fkc.parent_column_id = cp.column_id
JOIN    sys.columns cr ON fkc.referenced_object_id = cr.object_id
                      AND fkc.referenced_column_id = cr.column_id
ORDER BY from_table;
GO


-- STEP 6 --------------------------------------------------------
-- Date range actually present. Replace TABLE and DATECOLUMN with
-- the real sales table and its date column from STEP 3 and 4.
--
-- SELECT MIN(DATECOLUMN) AS first_txn,
--        MAX(DATECOLUMN) AS last_txn,
--        COUNT(*)        AS rows
-- FROM   dbo.TABLE;
