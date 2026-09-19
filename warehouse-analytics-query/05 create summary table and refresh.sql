/* ============================================================================
   SECTION 6 - Pre-aggregated summary table and its refresh procedure
   ----------------------------------------------------------------------------
   A procedure that changes state rather than just wrapping a SELECT. Reloading
   is scoped to one batch and is idempotent: running it twice for the same
   batch leaves the same result, so it can safely be re-run after a corrected
   batch without duplicating rows.
============================================================================ */

CREATE TABLE analytics.monthly_carrier_summary (
    batch_id VARCHAR(10),
    [year] INT,
    [month] INT,
    month_name VARCHAR(20),
    carrier_code VARCHAR(10),
    carrier_description VARCHAR(200),
    total_flights INT,
    on_time_flights INT,
    delayed_flights INT,
    cancelled_flights INT,
    diverted_flights INT,
    on_time_pct DECIMAL(5,2),
    cancellation_rate_pct DECIMAL(5,2),
    avg_arrival_delay_minutes DECIMAL(10,2),
    total_delay_minutes DECIMAL(18,2),
    refreshed_at DATETIME2(6)
);
GO


CREATE PROCEDURE analytics.usp_refresh_monthly_summary
    @batch_id VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    -- Clear this batch's rows first, so a re-run replaces rather than duplicates
    DELETE FROM analytics.monthly_carrier_summary
    WHERE batch_id = @batch_id;

    INSERT INTO analytics.monthly_carrier_summary (
        batch_id, [year], [month], month_name, carrier_code, carrier_description,
        total_flights, on_time_flights, delayed_flights, cancelled_flights,
        diverted_flights, on_time_pct, cancellation_rate_pct,
        avg_arrival_delay_minutes, total_delay_minutes, refreshed_at
    )
    SELECT
        f.batch_id,
        d.[year],
        d.[month],
        d.month_name,
        c.carrier_code,
        c.carrier_description,
        COUNT(*),
        SUM(CASE WHEN f.is_delayed = 0 AND f.is_cancelled = 0 THEN 1 ELSE 0 END),
        SUM(CASE WHEN f.is_delayed   = 1 THEN 1 ELSE 0 END),
        SUM(CASE WHEN f.is_cancelled = 1 THEN 1 ELSE 0 END),
        SUM(CASE WHEN f.is_diverted  = 1 THEN 1 ELSE 0 END),
        CAST(100.0 * SUM(CASE WHEN f.is_delayed = 0 AND f.is_cancelled = 0 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)),
        CAST(100.0 * SUM(CASE WHEN f.is_cancelled = 1 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)),
        CAST(AVG(f.arrival_delay_minutes) AS DECIMAL(10,2)),
        CAST(SUM(f.total_delay_minutes)   AS DECIMAL(18,2)),
        SYSUTCDATETIME()
    FROM dbo.fact_flight f
    JOIN dbo.dim_date    d ON f.flight_date_id = d.date_id
    LEFT JOIN dbo.dim_carrier c ON f.carrier_sk     = c.carrier_sk
    WHERE f.batch_id = @batch_id
    GROUP BY f.batch_id, d.[year], d.[month], d.month_name,
             c.carrier_code, c.carrier_description;
END;
GO

EXEC analytics.usp_refresh_monthly_summary @batch_id = '2018_01';
EXEC analytics.usp_refresh_monthly_summary @batch_id = '2018_02';