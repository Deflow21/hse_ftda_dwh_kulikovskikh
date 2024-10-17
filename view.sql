CREATE VIEW airport_traffic AS
SELECT
    airport_code,
    SUM(CASE WHEN flight_direction = 'departure' THEN 1 ELSE 0 END) AS departure_flights_num,
    SUM(CASE WHEN flight_direction = 'departure' THEN passengers_count ELSE 0 END) AS departure_psngr_num,
    SUM(CASE WHEN flight_direction = 'arrival' THEN 1 ELSE 0 END) AS arrival_flights_num,
    SUM(CASE WHEN flight_direction = 'arrival' THEN passengers_count ELSE 0 END) AS arrival_psngr_num
FROM flights
GROUP BY airport_code;