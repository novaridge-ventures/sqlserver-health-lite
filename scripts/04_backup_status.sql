/* =====================================================================
   04 Backup status and RPO gaps  (read-only)
   Flags databases without a recent FULL backup, FULL-recovery databases
   without LOG backups, and shows the last backup of every type.
   Adjust thresholds below to your RPO.
   ===================================================================== */
SET NOCOUNT ON;
DECLARE @FullMaxAgeHours int = 26 * 7,   -- weekly full + slack
        @DiffOrFullMaxAgeHours int = 26, -- daily diff/full
        @LogMaxAgeMinutes int = 60;

WITH last_bk AS (
    SELECT database_name,
           MAX(CASE WHEN type = 'D' THEN backup_finish_date END) AS last_full,
           MAX(CASE WHEN type = 'I' THEN backup_finish_date END) AS last_diff,
           MAX(CASE WHEN type = 'L' THEN backup_finish_date END) AS last_log
    FROM msdb.dbo.backupset
    WHERE is_copy_only = 0
    GROUP BY database_name
)
SELECT  d.name AS database_name, d.recovery_model_desc,
        b.last_full, b.last_diff, b.last_log,
        CASE
          WHEN d.name = 'tempdb' THEN 'n/a'
          WHEN b.last_full IS NULL THEN 'CRITICAL: never had a full backup'
          WHEN b.last_full < DATEADD(HOUR, -@FullMaxAgeHours, GETDATE()) THEN 'WARN: last full backup too old'
          WHEN COALESCE(b.last_diff, b.last_full) < DATEADD(HOUR, -@DiffOrFullMaxAgeHours, GETDATE())
               AND COALESCE(b.last_full, '19000101') < DATEADD(HOUR, -@DiffOrFullMaxAgeHours, GETDATE())
               THEN 'WARN: no full/diff backup in the last day'
          WHEN d.recovery_model_desc <> 'SIMPLE' AND (b.last_log IS NULL OR b.last_log < DATEADD(MINUTE, -@LogMaxAgeMinutes, GETDATE()))
               THEN 'WARN: FULL/BULK_LOGGED recovery but no recent LOG backup (log will grow, RPO at risk)'
          ELSE 'OK' END AS finding
FROM sys.databases AS d
LEFT JOIN last_bk AS b ON b.database_name = d.name
WHERE d.state_desc = 'ONLINE'
ORDER BY CASE WHEN b.last_full IS NULL THEN 0 ELSE 1 END, d.name;

/* Last 20 backups with size and destination */
SELECT TOP (20) bs.database_name, bs.type AS backup_type, bs.backup_start_date, bs.backup_finish_date,
       CAST(bs.backup_size / 1048576.0 AS decimal(18,1)) AS size_mb,
       CAST(bs.compressed_backup_size / 1048576.0 AS decimal(18,1)) AS compressed_mb,
       bs.has_backup_checksums, bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
ORDER BY bs.backup_finish_date DESC;
