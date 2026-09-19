CREATE SCHEMA analytics;
GO

/*=====================================================
   Section 2: create base tables
   ===================================================*/
CREATE TABLE dbo.dim_date (
    date_id INT NOT NULL,
    full_date DATE NOT NULL,
    [year] INT,
    [quarter] INT,
    [month] INT,
    month_name VARCHAR(20),
    day_of_month INT,
    day_of_week INT,
    day_name VARCHAR(20),
    is_weekend BIT
);
GO

CREATE TABLE dbo.dim_origin_airport (
    origin_airport_sk VARCHAR(64) NOT NULL,
    origin_airport_code VARCHAR(10),
    airport_description VARCHAR(500),
    airport_name VARCHAR(200),
    airport_city VARCHAR(100),
    airport_state VARCHAR(50),
    airport_city_name VARCHAR(100),
    created_timestamp DATETIME2(6),
    updated_timestamp DATETIME2(6)
);
GO

CREATE TABLE dbo.dim_destination_airport (
    airport_destination_sk VARCHAR(64) NOT NULL,
    destination_airport_code VARCHAR(10),
    destination_city_name VARCHAR(100),
    created_timestamp DATETIME2(6),
    updated_timestamp DATETIME2(6)
);
GO

CREATE TABLE dbo.dim_carrier (
    carrier_sk VARCHAR(64)     NOT NULL,
    carrier_code VARCHAR(10),
    carrier_description VARCHAR(200),
    created_timestamp DATETIME2(6),
    updated_timestamp DATETIME2(6)
);
GO


CREATE TABLE dbo.fact_flight (
    flight_sk VARCHAR(64) NOT NULL,
    flight_date DATE,
    flight_date_id INT,
    batch_id VARCHAR(10),
    tail_number VARCHAR(20),
    flight_number VARCHAR(10),
    origin_airport_sk VARCHAR(64),
    airport_destination_sk VARCHAR(64),
    carrier_sk VARCHAR(64),
    origin_city_name VARCHAR(100),
    destination_city_name VARCHAR(100),
    route VARCHAR(200),
    departure_time INT,
    arrival_time INT,
    departure_delay_minutes FLOAT,
    arrival_delay_minutes FLOAT,
    taxi_out_minutes FLOAT,
    taxi_in_minutes FLOAT,
    air_time_minutes FLOAT,
    distance_miles FLOAT,
    total_delay_minutes FLOAT,
    primary_delay_cause VARCHAR(20),
    delay_category VARCHAR(20),
    cancellation_code VARCHAR(5),
    flight_status VARCHAR(20),
    is_delayed BIT,
    is_cancelled BIT,
    is_diverted BIT,
    created_timestamp DATETIME2(6),
    updated_timestamp DATETIME2(6)
);
GO
