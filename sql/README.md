# SQL scripts — run order

The source database is a pharmaceutical distribution package
(`FAINV`, `FAPRD`, `FAPAR`, `PRODHEAD` table prefixes) running on
SQL Server at compatibility level 100. Scripts avoid `TRY_CONVERT`
and other post-2008 functions accordingly.

| # | Script | Purpose |
|---|---|---|
| 1 | `schema_discovery.sql` | Lists tables, row counts, columns, foreign keys |
| 2 | `schema_discovery_part2.sql` | Columns for the core `FA*` transaction tables |
| 3 | `profile_codes.sql` | Decodes voucher types, party ledger codes, expiry date format |
| 4 | `extract_anonymised.sql` | Creates the `anon` schema: 7 views, anonymised and scaled |
| 5 | `extract_expiry_returns.sql` | Adds the expiry-returns view with lag calculation |
| 6 | `export_views.ps1` | Exports all 8 views to CSV via PowerShell |

## Anonymisation

`extract_anonymised.sql` builds two mapping tables — `anon.CustomerMap`
and `anon.SupplierMap` — that stay inside the database and are never
exported. Customer and supplier names become `CUST_0001` / `SUPP_001`.
Addresses, phone numbers, GSTINs, PAN and drug licence numbers are
dropped entirely.

All monetary values are multiplied by a single constant factor held in
`anon.Config`. Every ratio, margin, trend and ranking is unaffected;
no real turnover figure is exposed.

Product and manufacturer brand names are retained — they are public,
and the analysis is meaningless without them.

## A note on discovery

Steps 1 to 3 exist because the database schema was undocumented. The
vendor's own profit fields turned out to be unpopulated (NULL on
501,716 of 502,489 sales lines), so margin is derived from batch
purchase rate instead. Expiry write-off fields were likewise empty,
which led to `PurRetSendMstr` / `PurRetSendDetail` — the table that
produced the strongest finding in the analysis.
