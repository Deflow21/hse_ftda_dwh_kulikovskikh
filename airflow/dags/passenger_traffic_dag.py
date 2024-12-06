from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.operators.python import PythonOperator
import pendulum

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2023, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5)
}


# Этот DAG обновляет данные за вчерашний день
# Предполагается, что актуальный бизнес-день - это yesterday
# при повторном запуске удаляем данные за этот день и пересчитываем их.

def get_business_date():
    # Возвращаем вчерашний день, например
    return (pendulum.now('UTC') - timedelta(days=1)).strftime('%Y-%m-%d')


with DAG(
        dag_id='passenger_traffic_dag',
        default_args=default_args,
        schedule='0 4 * * *',  # Запуск в 4 утра каждый день
        catchup=False
) as dag:
    business_date = get_business_date()

    # Очистка данных за конкретный день из витрины presentation.passenger_traffic
    truncate_for_day = PostgresOperator(
        task_id='truncate_for_day',
        postgres_conn_id='postgres_dwh',
        sql=f"""
        DELETE FROM presentation.passenger_traffic
        WHERE flight_date = DATE '{business_date}';
        """
    )

    # Формирование данных
    # Логика:
    # - За указанный день (business_date) выбираем рейсы, у которых actual_arrival или actual_departure попадает в этот день.
    # - Для каждого аэропорта считаем:
    #   flights_in/out: количество рейсов в/из airport_code из/в linked_airport_code.
    #   passengers_in/out: количество пассажиров на этих рейсах.
    #
    # Примерный SQL:
    build_traffic = PostgresOperator(
        task_id='build_traffic',
        postgres_conn_id='postgres_dwh',
        sql=f"""
        WITH flight_data AS (
    SELECT
        hf.flight_id,
        COALESCE(sfd.actual_arrival::date, sfd.actual_departure::date) as flight_date,
        sfd.actual_arrival,
        sfd.actual_departure
    FROM dwh_detailed.hub_flights hf
    JOIN dwh_detailed.sat_flight_details sfd ON sfd.flight_id = hf.flight_id
    WHERE COALESCE(sfd.actual_arrival::date, sfd.actual_departure::date) = DATE '{business_date}'
),

-- Получаем аэропорты вылета
departure_airports AS (
    SELECT 
        lfda.flight_id,
        ha.airport_code AS departure_airport
    FROM dwh_detailed.link_flights_departure_airports lfda
    JOIN dwh_detailed.hub_airports ha ON ha.airport_id = lfda.airport_id
),

-- Получаем аэропорты прилёта
arrival_airports AS (
    SELECT 
        lfaa.flight_id,
        ha.airport_code AS arrival_airport
    FROM dwh_detailed.link_flights_arrival_airports lfaa
    JOIN dwh_detailed.hub_airports ha ON ha.airport_id = lfaa.airport_id
),

-- Соединяем flight_data с аэропортами
flight_data_airports AS (
    SELECT 
        fd.flight_id,
        fd.flight_date,
        da.departure_airport,
        aa.arrival_airport
    FROM flight_data fd
    JOIN departure_airports da ON fd.flight_id = da.flight_id
    JOIN arrival_airports aa ON fd.flight_id = aa.flight_id
),

-- Подсчет пассажиров на рейс: через link_tickets_flights -> link_tickets_passengers -> hub_passengers
flight_passengers AS (
    SELECT
        fda.flight_id,
        COUNT(DISTINCT hp.passenger_id) AS passengers_count
    FROM flight_data_airports fda
    JOIN dwh_detailed.link_tickets_flights ltf ON fda.flight_id = ltf.flight_id
    JOIN dwh_detailed.link_tickets_passengers ltp ON ltf.ticket_id = ltp.ticket_id
    JOIN dwh_detailed.hub_passengers hp ON hp.passenger_hid = ltp.passenger_hid
    GROUP BY fda.flight_id
),

combined AS (
    SELECT
        fda.flight_date,
        fda.departure_airport AS airport_out,
        fda.arrival_airport AS airport_in,
        fp.passengers_count
    FROM flight_data_airports fda
    LEFT JOIN flight_passengers fp ON fp.flight_id = fda.flight_id
),

airport_pairs AS (
    SELECT 
        flight_date,
        airport_in AS airport_code,
        airport_out AS linked_airport_code,
        COUNT(*) AS flights_in,
        SUM(passengers_count) AS passengers_in
    FROM combined
    GROUP BY flight_date, airport_in, linked_airport_code
),

airport_pairs_out AS (
    SELECT
        flight_date,
        airport_out AS airport_code,
        airport_in AS linked_airport_code,
        COUNT(*) AS flights_out,
        SUM(passengers_count) AS passengers_out
    FROM combined
    GROUP BY flight_date, airport_code, linked_airport_code
),

final AS (
    SELECT
        COALESCE(a.flight_date, b.flight_date) AS flight_date,
        COALESCE(a.airport_code, b.airport_code) AS airport_code,
        COALESCE(a.linked_airport_code, b.linked_airport_code) AS linked_airport_code,
        COALESCE(a.flights_in, 0) AS flights_in,
        COALESCE(b.flights_out, 0) AS flights_out,
        COALESCE(a.passengers_in, 0) AS passengers_in,
        COALESCE(b.passengers_out, 0) AS passengers_out
    FROM airport_pairs a
    FULL OUTER JOIN airport_pairs_out b
    ON a.flight_date = b.flight_date 
       AND a.airport_code = b.airport_code 
       AND a.linked_airport_code = b.linked_airport_code
)

INSERT INTO presentation.passenger_traffic (
    created_at,
    flight_date,
    airport_code,
    linked_airport_code,
    flights_in,
    flights_out,
    passengers_in,
    passengers_out
)
SELECT
    NOW(),
    flight_date,
    airport_code,
    linked_airport_code,
    flights_in,
    flights_out,
    passengers_in,
    passengers_out
FROM final;
        """
    )

    truncate_for_day >> build_traffic