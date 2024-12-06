CREATE OR REPLACE VIEW dwh_detailed.passenger_flow_view AS
WITH departure_flights AS (
    SELECT
        ha.airport_code,
        hf.flight_id
    FROM dwh_detailed.hub_airports ha
    JOIN dwh_detailed.link_flights_departure_airports lfda ON lfda.airport_id = ha.airport_id
    JOIN dwh_detailed.hub_flights hf ON hf.flight_id = lfda.flight_id
),
arrival_flights AS (
    SELECT
        ha.airport_code,
        hf.flight_id
    FROM dwh_detailed.hub_airports ha
    JOIN dwh_detailed.link_flights_arrival_airports lfaa ON lfaa.airport_id = ha.airport_id
    JOIN dwh_detailed.hub_flights hf ON hf.flight_id = lfaa.flight_id
),
departure_tickets AS (
    SELECT
        df.airport_code,
        ht.ticket_id
    FROM departure_flights df
    JOIN dwh_detailed.link_tickets_flights ltf ON ltf.flight_id = df.flight_id
    JOIN dwh_detailed.hub_tickets ht ON ht.ticket_id = ltf.ticket_id
),
arrival_tickets AS (
    SELECT
        af.airport_code,
        ht.ticket_id
    FROM arrival_flights af
    JOIN dwh_detailed.link_tickets_flights ltf ON ltf.flight_id = af.flight_id
    JOIN dwh_detailed.hub_tickets ht ON ht.ticket_id = ltf.ticket_id
)
SELECT
    ha.airport_code,
    COUNT(DISTINCT df.flight_id) as departure_flights_num,
    COUNT(DISTINCT dt.ticket_id) as departure_psngr_num,
    COUNT(DISTINCT af.flight_id) as arrival_flights_num,
    COUNT(DISTINCT at.ticket_id) as arrival_psngr_num
FROM dwh_detailed.hub_airports ha
LEFT JOIN departure_flights df ON df.airport_code = ha.airport_code
LEFT JOIN arrival_flights af ON af.airport_code = ha.airport_code
LEFT JOIN departure_tickets dt ON dt.airport_code = ha.airport_code
LEFT JOIN arrival_tickets at ON at.airport_code = ha.airport_code
GROUP BY ha.airport_code;
