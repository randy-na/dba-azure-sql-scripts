-- ============================================================
-- Weekly | 06 - Wait Statistics Snapshot
-- Run on: Primary
-- Informational only. Focus on sustained dominant waits.
-- ============================================================
WITH waits AS (
    SELECT
        wait_type,
        wait_time_ms,
        signal_wait_time_ms,
        waiting_tasks_count,
        resource_wait_time_ms = wait_time_ms - signal_wait_time_ms
    FROM sys.dm_db_wait_stats
    WHERE waiting_tasks_count > 0
      AND wait_type NOT IN (
            'BROKER_EVENTHANDLER',
            'BROKER_RECEIVE_WAITFOR',
            'BROKER_TASK_STOP',
            'BROKER_TO_FLUSH',
            'BROKER_TRANSMITTER',
            'CHECKPOINT_QUEUE',
            'CHKPT',
            'CLR_AUTO_EVENT',
            'CLR_MANUAL_EVENT',
            'CLR_SEMAPHORE',
            'DBMIRROR_DBM_EVENT',
            'DBMIRROR_EVENTS_QUEUE',
            'DBMIRROR_WORKER_QUEUE',
            'DBMIRRORING_CMD',
            'DIRTY_PAGE_POLL',
            'DISPATCHER_QUEUE_SEMAPHORE',
            'EXECSYNC',
            'FSAGENT',
            'FT_IFTS_SCHEDULER_IDLE_WAIT',
            'FT_IFTSHC_MUTEX',
            'HADR_CLUSAPI_CALL',
            'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
            'HADR_LOGCAPTURE_WAIT',
            'HADR_NOTIFICATION_DEQUEUE',
            'HADR_TIMER_TASK',
            'HADR_WORK_QUEUE',
            'KSOURCE_WAKEUP',
            'LAZYWRITER_SLEEP',
            'LOGMGR_QUEUE',
            'MEMORY_ALLOCATION_EXT',
            'ONDEMAND_TASK_QUEUE',
            'PARALLEL_REDO_DRAIN_WORKER',
            'PARALLEL_REDO_LOG_CACHE',
            'PARALLEL_REDO_TRAN_LIST',
            'PARALLEL_REDO_WORKER_SYNC',
            'PARALLEL_REDO_WORKER_WAIT_WORK',
            'PREEMPTIVE_OS_FLUSHFILEBUFFERS',
            'PREEMPTIVE_XE_GETTARGETSTATE',
            'PWAIT_ALL_COMPONENTS_INITIALIZED',
            'PWAIT_DIRECTLOGCONSUMER_GETNEXT',
            'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP',
            'QDS_ASYNC_QUEUE',
            'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP',
            'QDS_SHUTDOWN_QUEUE',
            'REDO_THREAD_PENDING_WORK',
            'REQUEST_FOR_DEADLOCK_SEARCH',
            'RESOURCE_QUEUE',
            'SERVER_IDLE_CHECK',
            'SLEEP_BPOOL_FLUSH',
            'SLEEP_DBSTARTUP',
            'SLEEP_DCOMSTARTUP',
            'SLEEP_MASTERDBREADY',
            'SLEEP_MASTERMDREADY',
            'SLEEP_MASTERUPGRADED',
            'SLEEP_MSDBSTARTUP',
            'SLEEP_SYSTEMTASK',
            'SLEEP_TASK',
            'SLEEP_TEMPDBSTARTUP',
            'SNI_HTTP_ACCEPT',
            'SP_SERVER_DIAGNOSTICS_SLEEP',
            'SQLTRACE_BUFFER_FLUSH',
            'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
            'SQLTRACE_WAIT_ENTRIES',
            'WAIT_FOR_RESULTS',
            'WAITFOR',
            'WAITFOR_TASKSHUTDOWN',
            'WAIT_XTP_RECOVERY',
            'WAIT_XTP_HOST_WAIT',
            'WAIT_XTP_OFFLINE_CKPT_NEW_LOG',
            'WAIT_XTP_CKPT_CLOSE',
            'XE_DISPATCHER_JOIN',
            'XE_DISPATCHER_WAIT',
            'XE_TIMER_EVENT'
      )
),
totals AS (
    SELECT total_wait_time_ms = SUM(wait_time_ms)
    FROM waits
)
SELECT TOP 20
    w.wait_type,
    w.waiting_tasks_count,
    w.wait_time_ms / 1000.0 AS wait_time_sec,
    w.signal_wait_time_ms / 1000.0 AS signal_wait_sec,
    w.resource_wait_time_ms / 1000.0 AS resource_wait_sec,
    CAST(100.0 * w.wait_time_ms / NULLIF(t.total_wait_time_ms, 0) AS DECIMAL(6,2)) AS pct_of_total_waits
FROM waits w
CROSS JOIN totals t
ORDER BY w.wait_time_ms DESC;
