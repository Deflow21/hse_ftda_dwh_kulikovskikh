-- Создание схемы presentation
CREATE SCHEMA IF NOT EXISTS presentation;

-- Создание таблицы frequent_flyer в схеме presentation
CREATE TABLE IF NOT EXISTS presentation.frequent_flyer (
    created_at TIMESTAMPTZ DEFAULT NOW(),
    passenger_id VARCHAR(20) PRIMARY KEY,
    passenger_name TEXT,
    flights_number INTEGER,
    purchase_sum NUMERIC(10,2),
    home_airport CHAR(3),
    customer_group VARCHAR(3)
);

CREATE TABLE presentation.passenger_traffic (
    created_at TIMESTAMP NOT NULL,
    flight_date DATE NOT NULL,
    airport_code CHAR(3) NOT NULL,
    linked_airport_code CHAR(3) NOT NULL,
    flights_in INTEGER DEFAULT 0,
    passengers_in INTEGER DEFAULT 0,
    flights_out INTEGER DEFAULT 0,
    passengers_out INTEGER DEFAULT 0,
    PRIMARY KEY (flight_date, airport_code, linked_airport_code)
);