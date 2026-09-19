/* ============================================================================
   SECTION 7 - Parameterised reporting procedure
   ----------------------------------------------------------------------------
   Does three things a view cannot: takes a date range chosen at runtime,
   accepts an optional carrier filter with a default, and returns more than one
   result set. The second result set uses the scalar function from section 4a
   to answer whether delay accumulates through the day.
============================================================================ */

CREATE PROCEDURE analytics.usp_carrier_performance_summary
    @start_date DATE,
    @end_date DATE,
    @carrier_code VARCHAR(10) = NULL   -- NULL means all carriers
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: performance by carrier over the requested range
    SELECT
        c.carrier_code,
        c.carrier_description,
        COUNT(*) AS total_flights,
        SUM(CASE WHEN f.is_delayed = 1 THEN 1 ELSE 0 END) AS delayed_flights,
        SUM(CASE WHEN f.is_cancelled = 1 THEN 1 ELSE 0 END) AS cancelled_flights,
        CAST(100.0 * SUM(CASE WHEN f.is_delayed = 0 AND f.is_cancelled = 0 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS on_time_pct,
        CAST(AVG(f.arrival_delay_minutes) AS DECIMAL(10,2)) AS avg_arrival_delay_minutes
    FROM dbo.fact_flight f
    LEFT JOIN dbo.dim_carrier c ON f.carrier_sk = c.carrier_sk
    WHERE f.flight_date BETWEEN @start_date AND @end_date
      AND (@carrier_code IS NULL OR c.carrier_code = @carrier_code)
    GROUP BY c.carrier_code, c.carrier_description;

    -- Result set 2: does delay build up through the day?
    SELECT
        analytics.fn_departure_time_band(f.departure_time) AS departure_time_band,
        COUNT(*)                                           AS total_flights,
        CAST(100.0 * SUM(CASE WHEN f.is_delayed = 0 AND f.is_cancelled = 0 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS on_time_pct,
        CAST(AVG(f.arrival_delay_minutes) AS DECIMAL(10,2)) AS avg_arrival_delay_minutes,
        CAST(AVG(f.departure_delay_minutes) AS DECIMAL(10,2)) AS avg_departure_delay_minutes
    FROM dbo.fact_flight f
    LEFT JOIN dbo.dim_carrier c ON f.carrier_sk = c.carrier_sk
    WHERE f.flight_date BETWEEN @start_date AND @end_date
      AND (@carrier_code IS NULL OR c.carrier_code = @carrier_code)
    GROUP BY analytics.fn_departure_time_band(f.departure_time);
END;
GO


EXEC analytics.usp_carrier_performance_summary @start_date = '2018-01-01', @end_date = '2018-02-28';
EXEC analytics.usp_carrier_performance_summary @start_date = '2018-01-01', @end_date = '2018-01-31', @carrier_code = 'AA';