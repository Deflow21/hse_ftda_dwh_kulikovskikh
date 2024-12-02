-- Создание представления passenger_flow_view
CREATE OR REPLACE VIEW passenger_flow_view AS
SELECT
    a.airport_code,
    COUNT(DISTINCT CASE WHEN f.departure_airport = a.airport_code THEN f.flight_id END) AS departure_flights_num,
    COUNT(DISTINCT CASE WHEN f.departure_airport = a.airport_code THEN t.ticket_no END) AS departure_psngr_num,
    COUNT(DISTINCT CASE WHEN f.arrival_airport = a.airport_code THEN f.flight_id END) AS arrival_flights_num,
    COUNT(DISTINCT CASE WHEN f.arrival_airport = a.airport_code THEN t.ticket_no END) AS arrival_psngr_num
FROM airports a
LEFT JOIN flights f
    ON a.airport_code = f.departure_airport OR a.airport_code = f.arrival_airport
LEFT JOIN ticket_flights tf
    ON f.flight_id = tf.flight_id
LEFT JOIN tickets t
    ON tf.ticket_no = t.ticket_no
GROUP BY a.airport_code;