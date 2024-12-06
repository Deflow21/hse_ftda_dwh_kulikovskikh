-- Создаем схему
CREATE SCHEMA IF NOT EXISTS dwh_detailed;

-------------------------------------------------------------
-- HUBS
-------------------------------------------------------------
-- HUB Airports
CREATE TABLE dwh_detailed.hub_airports (
    airport_id SERIAL PRIMARY KEY,
    airport_code CHAR(3) UNIQUE NOT NULL,   -- бизнес-ключ аэропорта
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-- HUB Flights
CREATE TABLE dwh_detailed.hub_flights (
    flight_id SERIAL PRIMARY KEY,
    flight_no VARCHAR(6) UNIQUE NOT NULL,   -- бизнес-ключ рейса
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-- HUB Bookings
CREATE TABLE dwh_detailed.hub_bookings (
    book_id SERIAL PRIMARY KEY,
    book_ref CHAR(6) UNIQUE NOT NULL,       -- бизнес-ключ бронирования
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-- HUB Tickets
CREATE TABLE dwh_detailed.hub_tickets (
    ticket_id SERIAL PRIMARY KEY,
    ticket_no CHAR(13) UNIQUE NOT NULL,     -- бизнес-ключ билета
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-- HUB Passengers (новая сущность для хранения пассажиров, идентифицируем по passenger_id)
CREATE TABLE dwh_detailed.hub_passengers (
    passenger_hid SERIAL PRIMARY KEY,
    passenger_id VARCHAR(20) UNIQUE NOT NULL, -- бизнес-ключ пассажира
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-------------------------------------------------------------
-- LINKS
-------------------------------------------------------------
-- LINK between Bookings and Flights (1:n или 1:1 в зависимости от логики)
CREATE TABLE dwh_detailed.link_bookings_flights (
    link_id SERIAL PRIMARY KEY,
    book_id INT NOT NULL REFERENCES dwh_detailed.hub_bookings(book_id),
    flight_id INT NOT NULL REFERENCES dwh_detailed.hub_flights(flight_id),
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-- LINK between Tickets and Bookings
CREATE TABLE dwh_detailed.link_tickets_bookings (
    link_id SERIAL PRIMARY KEY,
    ticket_id INT NOT NULL REFERENCES dwh_detailed.hub_tickets(ticket_id),
    book_id INT NOT NULL REFERENCES dwh_detailed.hub_bookings(book_id),
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-- LINK between Tickets and Flights (ticket_flights из исходной БД)
CREATE TABLE dwh_detailed.link_tickets_flights (
    link_id SERIAL PRIMARY KEY,
    ticket_id INT NOT NULL REFERENCES dwh_detailed.hub_tickets(ticket_id),
    flight_id INT NOT NULL REFERENCES dwh_detailed.hub_flights(flight_id),
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-- LINK between Tickets and Passengers
CREATE TABLE dwh_detailed.link_tickets_passengers (
    link_id SERIAL PRIMARY KEY,
    ticket_id INT NOT NULL REFERENCES dwh_detailed.hub_tickets(ticket_id),
    passenger_hid INT NOT NULL REFERENCES dwh_detailed.hub_passengers(passenger_hid),
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-- LINK Flights -> Departure Airports
CREATE TABLE dwh_detailed.link_flights_departure_airports (
    link_id SERIAL PRIMARY KEY,
    flight_id INT NOT NULL REFERENCES dwh_detailed.hub_flights(flight_id),
    airport_id INT NOT NULL REFERENCES dwh_detailed.hub_airports(airport_id),
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-- LINK Flights -> Arrival Airports
CREATE TABLE dwh_detailed.link_flights_arrival_airports (
    link_id SERIAL PRIMARY KEY,
    flight_id INT NOT NULL REFERENCES dwh_detailed.hub_flights(flight_id),
    airport_id INT NOT NULL REFERENCES dwh_detailed.hub_airports(airport_id),
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-------------------------------------------------------------
-- SATELLITES
-------------------------------------------------------------
-- SAT for Airports
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

-- SAT for Flights
-- Здесь мы храним расписание, статус и т.п., но НЕ departure_airport/arrival_airport (они в link)
CREATE TABLE dwh_detailed.sat_flight_details (
    sat_id SERIAL PRIMARY KEY,
    flight_id INT REFERENCES dwh_detailed.hub_flights(flight_id),
    scheduled_departure TIMESTAMPTZ NOT NULL,
    scheduled_arrival TIMESTAMPTZ NOT NULL,
    status VARCHAR(20),
    aircraft_code CHAR(3),
    actual_departure TIMESTAMPTZ,
    actual_arrival TIMESTAMPTZ,
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-- SAT for Bookings
CREATE TABLE dwh_detailed.sat_booking_details (
    sat_id SERIAL PRIMARY KEY,
    book_id INT REFERENCES dwh_detailed.hub_bookings(book_id),
    book_date TIMESTAMPTZ NOT NULL,
    total_amount NUMERIC(10,2) NOT NULL,
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-- SAT for Tickets
-- Убираем отсюда book_ref и passenger_id, т.к. они связаны через link-таблицы
CREATE TABLE dwh_detailed.sat_ticket_details (
    sat_id SERIAL PRIMARY KEY,
    ticket_id INT REFERENCES dwh_detailed.hub_tickets(ticket_id),
    passenger_name TEXT NOT NULL,
    contact_data JSONB,
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);

-- SAT for Passengers
-- Хранит дополнительные атрибуты пассажиров (например, имя), если нужно.
-- Если имя пассажира хранится уже в sat_ticket_details, можно либо дублировать, либо выбрать другой подход.
-- Лучше пассажира отразить отдельно, если passenger_id является стабильным ключом.
CREATE TABLE dwh_detailed.sat_passenger_details (
    sat_id SERIAL PRIMARY KEY,
    passenger_hid INT REFERENCES dwh_detailed.hub_passengers(passenger_hid),
    passenger_name TEXT,
    source_system_id INT NOT NULL,
    load_date TIMESTAMPTZ DEFAULT NOW()
);