-- Создание представления для анализа пассажиропотока
CREATE OR REPLACE VIEW dwh_detailed.passenger_flow_view AS
SELECT
    h_airport.airport_code,
    COUNT(DISTINCT h_flight.flight_id) AS departure_flights_num,
    COUNT(DISTINCT h_ticket.ticket_id) AS departure_psngr_num,
    COUNT(DISTINCT h_flight_arr.flight_id) AS arrival_flights_num,
    COUNT(DISTINCT h_ticket_arr.ticket_id) AS arrival_psngr_num
FROM dwh_detailed.hub_airports h_airport
LEFT JOIN dwh_detailed.sat_flight_details s_flight
    ON h_airport.airport_code = s_flight.departure_airport
LEFT JOIN dwh_detailed.hub_flights h_flight
    ON s_flight.flight_id = h_flight.flight_id
LEFT JOIN dwh_detailed.sat_ticket_details s_ticket
    ON h_flight.flight_id = CAST(s_ticket.book_ref AS INTEGER)
LEFT JOIN dwh_detailed.hub_tickets h_ticket
    ON s_ticket.ticket_id = h_ticket.ticket_id
LEFT JOIN dwh_detailed.sat_flight_details s_flight_arr
    ON h_airport.airport_code = s_flight_arr.arrival_airport
LEFT JOIN dwh_detailed.hub_flights h_flight_arr
    ON s_flight_arr.flight_id = h_flight_arr.flight_id
LEFT JOIN dwh_detailed.sat_ticket_details s_ticket_arr
    ON h_flight_arr.flight_id = CAST(s_ticket_arr.book_ref AS INTEGER)
LEFT JOIN dwh_detailed.hub_tickets h_ticket_arr
    ON s_ticket_arr.ticket_id = h_ticket_arr.ticket_id
GROUP BY h_airport.airport_code;