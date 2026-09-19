/* ============================================================================
   Load procedure (Gold prod lakehouse to Warehouse)
   ----------------------------------------------------------------------------
   TRUNCATE + INSERT rather than MERGE: the Warehouse is a full reload of the
   current Gold state, incremental merge logic already lives upstream in the
   Lakehouse layer and does not need repeating here.
============================================================================ */

CREATE PROCEDURE dbo.usp_load_warehouse_from_gold
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE dbo.dim_date;
    INSERT INTO dbo.dim_date (
        date_id, full_date, [year], [quarter], [month], month_name,
        day_of_month, day_of_week, day_name, is_weekend
    )
    SELECT
        date_id, full_date, [year], [quarter], [month], month_name,
        day_of_month, day_of_week, day_name, is_weekend
    FROM aeropulse_gold_lh.dbo.dim_date;

    TRUNCATE TABLE dbo.dim_origin_airport;
    INSERT INTO dbo.dim_origin_airport (
        origin_airport_sk, origin_airport_code, airport_description,
        airport_name, airport_city, airport_state, airport_city_name,
        created_timestamp, updated_timestamp
    )
    SELECT
        origin_airport_sk, origin_airport_code, airport_description,
        airport_name, airport_city, airport_state, airport_city_name,
        created_timestamp, updated_timestamp
    FROM aeropulse_gold_lh.dbo.dim_origin_airport;

    TRUNCATE TABLE dbo.dim_destination_airport;
    INSERT INTO dbo.dim_destination_airport (
        airport_destination_sk, destination_airport_code,
        destination_city_name, created_timestamp, updated_timestamp
    )
    SELECT
        airport_destination_sk, destination_airport_code,
        destination_city_name, created_timestamp, updated_timestamp
    FROM aeropulse_gold_lh.dbo.dim_destination_airport;

    TRUNCATE TABLE dbo.dim_carrier;
    INSERT INTO dbo.dim_carrier (
        carrier_sk, carrier_code, carrier_description,
        created_timestamp, updated_timestamp
    )
    SELECT
        carrier_sk, carrier_code, carrier_description,
        created_timestamp, updated_timestamp
    FROM aeropulse_gold_lh.dbo.dim_carrier;

    TRUNCATE TABLE dbo.fact_flight;
    INSERT INTO dbo.fact_flight (
        flight_sk, flight_date, flight_date_id, batch_id, tail_number,
        flight_number, origin_airport_sk, airport_destination_sk, carrier_sk,
        origin_city_name, destination_city_name, route, departure_time,
        arrival_time, departure_delay_minutes, arrival_delay_minutes,
        taxi_out_minutes, taxi_in_minutes, air_time_minutes, distance_miles,
        total_delay_minutes, primary_delay_cause, delay_category, cancellation_code,
        flight_status, is_delayed, is_cancelled, is_diverted,
        created_timestamp, updated_timestamp
    )
    SELECT
        flight_sk,
        flight_date,
        CAST(flight_date_id AS INT),
        batch_id, tail_number, flight_number,
        origin_airport_sk, airport_destination_sk, carrier_sk,
        origin_city_name, destination_city_name, route,
        departure_time, arrival_time,
        departure_delay_minutes, arrival_delay_minutes,
        taxi_out_minutes, taxi_in_minutes, air_time_minutes, distance_miles,
        total_delay_minutes, primary_delay_cause, delay_category, cancellation_code,
        flight_status, is_delayed, is_cancelled, is_diverted,
        created_timestamp, updated_timestamp
    FROM aeropulse_gold_lh.dbo.fact_flight;
END;
GO

EXEC dbo.usp_load_warehouse_from_gold;