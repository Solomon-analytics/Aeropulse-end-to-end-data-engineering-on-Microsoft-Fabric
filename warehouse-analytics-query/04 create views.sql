/* ============================================================================
   Views
   ----------------------------------------------------------------------------
   Fixed, unparameterised aggregations meant to be sliced downstream by a
   semantic model.
============================================================================ */

/* ----------------------------------------------------------------------------
       Daily flight performance
       Answers: how many flights ran on a given date, what share arrived on
       time, and which origin airports had the worst delays that day.
---------------------------------------------------------------------------- */

CREATE VIEW analytics.vw_daily_flight_performance
AS
SELECT
    d.full_date,
    d.[year],
    d.[month],
    d.month_name,
    d.day_name,
    d.is_weekend,
    c.carrier_code,
    c.carrier_description,
    o.origin_airport_code,
    o.airport_city AS origin_city,
    o.airport_state AS origin_state,
    COUNT(*) AS total_flights,
    SUM(CASE WHEN f.is_delayed   = 1 THEN 1 ELSE 0 END) AS delayed_flights,
    SUM(CASE WHEN f.is_cancelled = 1 THEN 1 ELSE 0 END) AS cancelled_flights,
    SUM(CASE WHEN f.is_diverted  = 1 THEN 1 ELSE 0 END) AS diverted_flights,
    CAST(100.0 * SUM(CASE WHEN f.is_delayed = 0 AND f.is_cancelled = 0 THEN 1 ELSE 0 END)
         / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS on_time_pct,
    CAST(AVG(f.arrival_delay_minutes) AS DECIMAL(10,2)) AS avg_arrival_delay_minutes,
    CAST(AVG(f.departure_delay_minutes) AS DECIMAL(10,2)) AS avg_departure_delay_minutes,
    CAST(AVG(f.taxi_out_minutes) AS DECIMAL(10,2)) AS avg_taxi_out_minutes
FROM dbo.fact_flight f
JOIN dbo.dim_date d ON f.flight_date_id = d.date_id
LEFT JOIN dbo.dim_carrier c ON f.carrier_sk = c.carrier_sk
LEFT JOIN dbo.dim_origin_airport o ON f.origin_airport_sk = o.origin_airport_sk
GROUP BY
    d.full_date, d.[year], d.[month], d.month_name, d.day_name, d.is_weekend,
    c.carrier_code, c.carrier_description,
    o.origin_airport_code, o.airport_city, o.airport_state;
GO


/* ----------------------------------------------------------------------------
       Carrier monthly on-time performance
       Answers: monthly OTP trend by carrier against an 80% target, plus
       cancellation rate, with carriers ranked within each month.
---------------------------------------------------------------------------- */

CREATE VIEW analytics.vw_carrier_monthly_otp
AS
WITH monthly AS (
    SELECT
        d.[year],
        d.[month],
        d.month_name,
        c.carrier_code,
        c.carrier_description,
        COUNT(*) AS total_flights,
        SUM(CASE WHEN f.is_delayed = 0 AND f.is_cancelled = 0 THEN 1 ELSE 0 END) AS on_time_flights,
        SUM(CASE WHEN f.is_delayed = 1 THEN 1 ELSE 0 END) AS delayed_flights,
        SUM(CASE WHEN f.is_cancelled = 1 THEN 1 ELSE 0 END) AS cancelled_flights,
        SUM(CASE WHEN f.is_diverted = 1 THEN 1 ELSE 0 END) AS diverted_flights,
        AVG(f.arrival_delay_minutes) AS avg_arrival_delay_minutes,
        SUM(f.total_delay_minutes) AS total_delay_minutes
    FROM dbo.fact_flight f
    JOIN dbo.dim_date d ON f.flight_date_id = d.date_id
    LEFT JOIN dbo.dim_carrier c ON f.carrier_sk = c.carrier_sk
    GROUP BY d.[year], d.[month], d.month_name, c.carrier_code, c.carrier_description
)
SELECT
    [year],
    [month],
    month_name,
    carrier_code,
    carrier_description,
    total_flights,
    on_time_flights,
    delayed_flights,
    cancelled_flights,
    diverted_flights,
    CAST(100.0 * on_time_flights / NULLIF(total_flights, 0) AS DECIMAL(5,2)) AS on_time_pct,
    CAST(100.0 * cancelled_flights / NULLIF(total_flights, 0) AS DECIMAL(5,2)) AS cancellation_rate_pct,
    CAST(avg_arrival_delay_minutes AS DECIMAL(10,2))                          AS avg_arrival_delay_minutes,
    CAST(total_delay_minutes AS DECIMAL(18,2))                          AS total_delay_minutes,
    CASE WHEN 100.0 * on_time_flights / NULLIF(total_flights, 0) >= 80.0
         THEN 'Meets target' ELSE 'Below target' END                          AS target_status,
    RANK() OVER (PARTITION BY [year], [month]
                 ORDER BY 100.0 * on_time_flights / NULLIF(total_flights, 0) DESC) AS otp_rank_in_month
FROM monthly;
GO

/* ----------------------------------------------------------------------------
       Route performance
       Answers: which routes are consistently late, weighted by volume, and
       which are the worst offenders overall.

       Routes with very few flights are flagged rather than filtered out, so
       the consumer decides the volume threshold rather than the view deciding
       it for them.
---------------------------------------------------------------------------- */

CREATE VIEW analytics.vw_route_performance
AS
SELECT
    f.route,
    f.origin_city_name,
    f.destination_city_name,
    o.origin_airport_code,
    dest.destination_airport_code,
    d.[year],
    d.[month],
    d.month_name,
    COUNT(*) AS total_flights,
    SUM(CASE WHEN f.is_delayed   = 1 THEN 1 ELSE 0 END) AS delayed_flights,
    SUM(CASE WHEN f.is_cancelled = 1 THEN 1 ELSE 0 END) AS cancelled_flights,
    CAST(100.0 * SUM(CASE WHEN f.is_delayed = 0 AND f.is_cancelled = 0 THEN 1 ELSE 0 END)
         / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS on_time_pct,
    CAST(AVG(f.arrival_delay_minutes) AS DECIMAL(10,2)) AS avg_arrival_delay_minutes,
    CAST(AVG(f.air_time_minutes) AS DECIMAL(10,2)) AS avg_air_time_minutes,
    CAST(AVG(f.distance_miles) AS DECIMAL(10,2)) AS avg_distance_miles,
    CASE WHEN COUNT(*) < 30 THEN 1 ELSE 0 END AS is_low_volume_route
FROM dbo.fact_flight f
JOIN dbo.dim_date d ON f.flight_date_id = d.date_id
LEFT JOIN dbo.dim_origin_airport o ON f.origin_airport_sk = o.origin_airport_sk
LEFT JOIN dbo.dim_destination_airport dest ON f.airport_destination_sk = dest.airport_destination_sk
GROUP BY
    f.route, f.origin_city_name, f.destination_city_name,
    o.origin_airport_code, dest.destination_airport_code,
    d.[year], d.[month], d.month_name;
GO

/* ============================================================================
   cancellation analysis view
   ----------------------------------------------------------------------------
   Answers what is actually driving cancellations, by carrier, airport and month, rather than
   just how many there were.
============================================================================ */

CREATE VIEW analytics.vw_cancellation_analysis
AS
SELECT
    d.[year],
    d.[month],
    d.month_name,
    c.carrier_code,
    c.carrier_description,
    o.origin_airport_code,
    o.airport_city AS origin_city,
    CASE f.cancellation_code
        WHEN 'A' THEN 'Carrier'
        WHEN 'B' THEN 'Weather'
        WHEN 'C' THEN 'National Air System'
        WHEN 'D' THEN 'Security'
        ELSE 'Unknown'
    END AS cancellation_reason,
    COUNT(*) AS cancelled_flights,
    CAST(100.0 * COUNT(*)
         / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY d.[year], d.[month], c.carrier_code), 0)
         AS DECIMAL(5,2)) AS pct_of_carrier_cancellations
FROM dbo.fact_flight f
JOIN dbo.dim_date d ON f.flight_date_id = d.date_id
LEFT JOIN dbo.dim_carrier c ON f.carrier_sk = c.carrier_sk
LEFT JOIN dbo.dim_origin_airport o ON f.origin_airport_sk = o.origin_airport_sk
WHERE f.is_cancelled = 1
GROUP BY
    d.[year], d.[month], d.month_name,
    c.carrier_code, c.carrier_description,
    o.origin_airport_code, o.airport_city,
    CASE f.cancellation_code
        WHEN 'A' THEN 'Carrier'
        WHEN 'B' THEN 'Weather'
        WHEN 'C' THEN 'National Air System'
        WHEN 'D' THEN 'Security'
        ELSE 'Unknown'
    END;
GO


/* ============================================================================
   Checks
============================================================================ */

-- Every cancelled flight should carry a code. Any that do not will show as
-- 'Unknown' in the view above.
SELECT
    SUM(CASE WHEN is_cancelled = 1 AND cancellation_code IS NULL THEN 1 ELSE 0 END) AS cancelled_without_code,
    SUM(CASE WHEN is_cancelled = 0 AND cancellation_code IS NOT NULL THEN 1 ELSE 0 END) AS not_cancelled_with_code
FROM dbo.fact_flight;

-- Reason mix across the loaded batches
SELECT cancellation_reason, SUM(cancelled_flights) AS cancelled_flights
FROM analytics.vw_cancellation_analysis
GROUP BY cancellation_reason
ORDER BY cancelled_flights DESC;
