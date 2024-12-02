-- Создание схемы для DWH
CREATE SCHEMA IF NOT EXISTS dwh_detailed;

-- Хабы
CREATE TABLE dwh_detailed.hub_airports (
    airport_id SERIAL PRIMARY KEY,
    airport_code CHAR(3) UNIQUE NOT NULL,
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE dwh_detailed.hub_flights (
    flight_id SERIAL PRIMARY KEY,
    flight_no VARCHAR(6) UNIQUE NOT NULL,
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE dwh_detailed.hub_bookings (
    book_id SERIAL PRIMARY KEY,
    book_ref CHAR(6) UNIQUE NOT NULL,
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE dwh_detailed.hub_tickets (
    ticket_id SERIAL PRIMARY KEY,
    ticket_no CHAR(13) UNIQUE NOT NULL,
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-- Сателлиты
CREATE TABLE dwh_detailed.sat_airport_details (
    sat_id SERIAL PRIMARY KEY,
    airport_id INT REFERENCES dwh_detailed.hub_airports(airport_id),
    airport_name TEXT NOT NULL,
    city TEXT NOT NULL,
    coordinates_lon DOUBLE PRECISION NOT NULL,
    coordinates_lat DOUBLE PRECISION NOT NULL,
    timezone TEXT NOT NULL,
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE dwh_detailed.sat_flight_details (
    sat_id SERIAL PRIMARY KEY,
    flight_id INT REFERENCES dwh_detailed.hub_flights(flight_id),
    scheduled_departure TIMESTAMPTZ NOT NULL,
    scheduled_arrival TIMESTAMPTZ NOT NULL,
    departure_airport CHAR(3) NOT NULL,
    arrival_airport CHAR(3) NOT NULL,
    status VARCHAR(20),
    aircraft_code CHAR(3),
    actual_departure TIMESTAMPTZ,
    actual_arrival TIMESTAMPTZ,
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE dwh_detailed.sat_booking_details (
    sat_id SERIAL PRIMARY KEY,
    book_id INT REFERENCES dwh_detailed.hub_bookings(book_id),
    book_date TIMESTAMPTZ NOT NULL,
    total_amount NUMERIC(10,2) NOT NULL,
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE dwh_detailed.sat_ticket_details (
    sat_id SERIAL PRIMARY KEY,
    ticket_id INT REFERENCES dwh_detailed.hub_tickets(ticket_id),
    book_ref CHAR(6) NOT NULL,
    passenger_id VARCHAR(20) NOT NULL,
    passenger_name TEXT NOT NULL,
    contact_data JSONB,
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);