/* ============================================================================
   Functions
   ----------------------------------------------------------------------------
   a. Scalar function: buckets departure_time (stored as an hhmm integer) into
       a time-of-day band. Deliberately something NOT already derived in Gold,
       it adds analytical capability rather than duplicating business logic
       that already exists upstream (delay_category, is_delayed and
       primary_delay_cause are all computed in the Gold notebook and should not
       be re-implemented here).
============================================================================ */

CREATE FUNCTION analytics.fn_departure_time_band (@departure_time INT)
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN
        CASE
            WHEN @departure_time IS NULL THEN 'Unknown'
            WHEN @departure_time < 600 THEN 'Red-eye'       
            WHEN @departure_time < 1200 THEN 'Morning'       
            WHEN @departure_time < 1700 THEN 'Afternoon'     
            WHEN @departure_time < 2100 THEN 'Evening'    
            ELSE  'Late evening'   
        END;
END;
GO


/* ----------------------------------------------------------------------------
   b. Inline table-valued function: a parameterised view. The key difference
       from a stored procedure is that this CAN be joined to and filtered
       further by the caller, a procedure's result set cannot.
---------------------------------------------------------------------------- */

CREATE FUNCTION analytics.fn_flights_in_range (@start_date DATE, @end_date DATE)
RETURNS TABLE
AS
RETURN
(
    SELECT
        f.flight_sk,
        f.flight_date,
        f.route,
        f.carrier_sk,
        f.origin_airport_sk,
        f.departure_time,
        f.arrival_delay_minutes,
        f.total_delay_minutes,
        f.primary_delay_cause,
        f.delay_category,
        f.flight_status,
        f.is_delayed,
        f.is_cancelled,
        f.is_diverted
    FROM dbo.fact_flight f
    WHERE f.flight_date BETWEEN @start_date AND @end_date
);
GO