/* =====================================================================
   01 Server health overview  (read-only)
   Version, uptime, CPU/memory, key configuration settings with
   recommendations, and database state/recovery model summary.
   ===================================================================== */
SET NOCOUNT ON;

SELECT  SERVERPROPERTY('ServerName')               AS server_name,
        SERVERPROPERTY('ProductVersion')           AS product_version,
        SERVERPROPERTY('ProductLevel')             AS product_level,
        SERVERPROPERTY('Edition')                  AS edition,
        si.sqlserver_start_time,
        DATEDIFF(HOUR, si.sqlserver_start_time, SYSDATETIME()) AS uptime_hours,
        si.cpu_count                               AS logical_cpus,
        si.physical_memory_kb / 1024               AS physical_memory_mb,
        si.committed_kb / 1024                     AS sql_committed_mb,
        si.committed_target_kb / 1024              AS sql_target_mb
FROM sys.dm_os_sys_info AS si;

/* Configuration checks with plain-English recommendations */
WITH cfg AS (
    SELECT name, CAST(value_in_use AS bigint) AS value_in_use FROM sys.configurations
)
SELECT  c.name AS setting, c.value_in_use,
        CASE
          WHEN c.name = 'max server memory (MB)' AND c.value_in_use >= 2147483647
               THEN 'WARN: max server memory is unlimited. Cap it to leave RAM for the OS (e.g. total - 10-20%).'
          WHEN c.name = 'cost threshold for parallelism' AND c.value_in_use <= 5
               THEN 'WARN: default 5 is too low for modern hardware. Start at 50 and tune.'
          WHEN c.name = 'max degree of parallelism' AND c.value_in_use = 0 AND (SELECT cpu_count FROM sys.dm_os_sys_info) > 8
               THEN 'WARN: MAXDOP 0 on >8 cores. Microsoft guidance: 8 or cores-per-NUMA-node.'
          WHEN c.name = 'optimize for ad hoc workloads' AND c.value_in_use = 0
               THEN 'INFO: consider enabling to reduce plan cache bloat from single-use plans.'
          WHEN c.name = 'backup compression default' AND c.value_in_use = 0
               THEN 'INFO: enable if your edition supports it (smaller, faster backups).'
          WHEN c.name = 'backup checksum default' AND c.value_in_use = 0
               THEN 'INFO: enable so every backup is verified with CHECKSUM.'
          WHEN c.name = 'remote admin connections' AND c.value_in_use = 0
               THEN 'INFO: enable the remote DAC so you can connect when the server is unresponsive.'
          ELSE 'OK'
        END AS recommendation
FROM cfg AS c
WHERE c.name IN ('max server memory (MB)', 'cost threshold for parallelism', 'max degree of parallelism',
                 'optimize for ad hoc workloads', 'backup compression default', 'backup checksum default',
                 'remote admin connections')
ORDER BY c.name;

/* Databases: state, recovery model, compat level, risky options */
SELECT  d.name, d.state_desc, d.recovery_model_desc, d.compatibility_level,
        d.page_verify_option_desc, d.is_auto_close_on, d.is_auto_shrink_on,
        d.log_reuse_wait_desc,
        CASE WHEN d.is_auto_close_on = 1 OR d.is_auto_shrink_on = 1 THEN 'WARN: turn off AUTO_CLOSE / AUTO_SHRINK'
             WHEN d.page_verify_option_desc <> 'CHECKSUM' THEN 'WARN: set PAGE_VERIFY CHECKSUM'
             WHEN d.state_desc <> 'ONLINE' THEN 'CHECK: database not online'
             ELSE 'OK' END AS finding
FROM sys.databases AS d
ORDER BY d.name;
