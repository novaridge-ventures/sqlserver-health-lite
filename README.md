# SQL Server Health Check Lite

Four **read-only** T-SQL scripts that answer the first questions to ask about any SQL Server you've inherited:

| Script | Answers |
|---|---|
| `scripts/01_server_health_overview.sql` | What version and edition is this, and how long has it been up? Are memory, MAXDOP, cost threshold and backup checksum still on bad defaults? Which recovery model is each database in? |
| `scripts/02_wait_stats.sql` | Where does the server spend its time waiting? Benign waits are filtered out, and each common wait gets a one-line hint. |
| `scripts/03_index_fragmentation.sql` | Which indexes worth caring about (1,000+ pages) are fragmented, and should each be reorganized or rebuilt? |
| `scripts/04_backup_status.sql` | Which databases have **never** had a full backup, have an old one, or run in FULL recovery with no log backups? |

Every finding is labelled `OK`, `WARN` or `CRITICAL` with a plain-English reason, so you don't need to be a DBA to read the output.

- Nothing is created, changed or installed. The scripts only read DMVs and `msdb` history.
- Works on SQL Server 2016 SP2 to 2022, on Windows, Linux or Docker, plus Azure SQL Managed Instance. Azure SQL Database lacks `msdb` backup history, so script 04 doesn't apply there.
- Tested end to end on SQL Server 2022.

## Run it

**SSMS or Azure Data Studio:** open a script, choose the database (script 03 runs in the current database), then press Execute.

**All scripts at once, saving the output to `./output`:**

```bash
# Linux / macOS (sqlcmd required)
SQLSERVER=localhost SQLUSER=sa SQLPASSWORD='your-password' DATABASE=YourDb bash run-all.sh
```

```powershell
# Windows, using Windows authentication
.\run-all.ps1 -Server SQL01 -Database YourDb
```

Then search the output for `CRITICAL` and `WARN`.

## Example output

```
cost threshold for parallelism | 5          | WARN: default 5 is too low for modern hardware. Start at 50 and tune.
max server memory (MB)         | 2147483647 | WARN: max server memory is unlimited. Cap it to leave RAM for the OS (e.g. total - 10-20%).
SalesDB | FULL | 2026-11-23 01:00 | NULL | NULL | WARN: FULL/BULK_LOGGED recovery but no recent LOG backup (log will grow, RPO at risk)
```

## Read the output before you act on it

- Fragmentation thresholds (10% reorganize, 30% rebuild) are common rules of thumb, not laws. On SSDs, stale statistics usually matter more than fragmentation.
- Wait stats are cumulative since the last restart. Take a snapshot before and after a busy period for a sharper picture.
- A recent backup only proves a backup *ran*. It doesn't prove you can restore it. Test restores regularly.

## Want the full toolkit?

This repo is a free sample. The paid **[SQL Server DBA Toolkit](https://payhip.com/b/iTWh0?utm_source=github&utm_medium=readme&utm_campaign=sql-lite)** ($19) adds:

- 10 more read-only reports: top queries with plans, missing, unused and duplicate indexes with ready-made `CREATE`/`DROP` statements, statistics health, blocking, file space and autogrowth, log and VLFs, Agent job failures, a security audit and tempdb.
- Four maintenance procedures that **default to dry-run** and log every action:
  - index maintenance (online where the edition supports it, with a time limit)
  - statistics updates
  - FULL/DIFF/LOG backups with `CHECKSUM` and `RESTORE VERIFYONLY`
  - `DBCC CHECKDB`
- One script that creates six SQL Agent jobs, a PowerShell **HTML health report** and backup clean-up tools.

The free scripts stay free under the MIT licence, whether or not you buy anything.

## Licence

MIT © 2026 Novaridge Ventures. Provided as-is. Read a script before you run it on production.
