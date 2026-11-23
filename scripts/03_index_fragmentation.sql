/* =====================================================================
   03 Index fragmentation report  (read-only, current database)
   Uses LIMITED mode (cheap). Small indexes (< @MinPages) are ignored:
   fragmentation on them does not matter.
   ===================================================================== */
SET NOCOUNT ON;
DECLARE @MinPages int = 1000;

SELECT  OBJECT_SCHEMA_NAME(ps.object_id) + '.' + OBJECT_NAME(ps.object_id) AS table_name,
        i.name AS index_name, i.type_desc, ps.partition_number,
        CAST(ps.avg_fragmentation_in_percent AS decimal(5,1)) AS frag_pct,
        ps.page_count,
        CAST(ps.page_count * 8 / 1024.0 AS decimal(18,1)) AS size_mb,
        i.fill_factor,
        CASE WHEN ps.avg_fragmentation_in_percent >= 30 THEN 'REBUILD'
             WHEN ps.avg_fragmentation_in_percent >= 10 THEN 'REORGANIZE'
             ELSE 'OK' END AS suggestion
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') AS ps
JOIN sys.indexes AS i ON i.object_id = ps.object_id AND i.index_id = ps.index_id
WHERE ps.index_id > 0 AND ps.page_count >= @MinPages AND ps.alloc_unit_type_desc = 'IN_ROW_DATA'
ORDER BY ps.avg_fragmentation_in_percent DESC;
