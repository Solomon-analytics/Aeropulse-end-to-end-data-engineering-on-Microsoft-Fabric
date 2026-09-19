/* ============================================================================
   tests
   ----------------------------------------------------------------------------
   confirming the Warehouse matches Gold and the
   objects behave. Row counts should match the source exactly.
============================================================================ */

-- Row counts, Warehouse vs Gold
SELECT 'warehouse' AS source, COUNT(*) AS fact_rows FROM dbo.fact_flight
UNION ALL
SELECT 'gold', COUNT(*) 
FROM aeropulse_gold_lh.dbo.fact_flight;

-- Orphaned surrogate keys, all three should return 0
SELECT COUNT(*) AS orphan_carrier 
FROM dbo.fact_flight f 
LEFT JOIN dbo.dim_carrier c ON f.carrier_sk = c.carrier_sk 
WHERE c.carrier_sk IS NULL;

SELECT COUNT(*) AS orphan_origin 
FROM dbo.fact_flight f 
LEFT JOIN dbo.dim_origin_airport o ON f.origin_airport_sk = o.origin_airport_sk  
WHERE o.origin_airport_sk IS NULL;

SELECT COUNT(*) AS orphan_date 
FROM dbo.fact_flight f 
LEFT JOIN dbo.dim_date d ON f.flight_date_id = d.date_id 
WHERE d.date_id IS NULL;

-- Views return rows
SELECT TOP 10 * FROM analytics.vw_daily_flight_performance;
SELECT TOP 10 * FROM analytics.vw_carrier_monthly_otp;
SELECT TOP 10 * FROM analytics.vw_route_performance;

-- Inline TVF can be joined and filtered further, unlike a procedure
SELECT c.carrier_code, COUNT(*) AS flights
FROM analytics.fn_flights_in_range('2018-01-01', '2018-01-31') r
LEFT JOIN dbo.dim_carrier c ON r.carrier_sk = c.carrier_sk
WHERE r.is_delayed = 1
GROUP BY c.carrier_code;
GO