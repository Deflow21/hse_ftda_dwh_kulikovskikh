from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2023, 1, 1),
    'retries': 1,
    'retry_delay': timedelta(minutes=5)
}

with DAG(
        dag_id='frequent_flyer_dag',
        default_args=default_args,
        schedule='0 3 * * *',  # Запуск в 3 утра каждый день
        catchup=False
) as dag:
    # Задача очистки витрины перед полной перезагрузкой
    truncate_presentation = PostgresOperator(
        task_id='truncate_frequent_flyers',
        postgres_conn_id='postgres_dwh',
        sql="""
        TRUNCATE TABLE presentation.frequent_flyer;
        """
    )

    # Задача формирования витрины
    # Логика:
    # 1. Собираем данные по пассажирам, их билетам и рейсам.
    #    Используем DWH таблицы hub_tickets, sat_ticket_details, hub_bookings, sat_booking_details,
    #    hub_flights, sat_flight_details, hub_airports, sat_airport_details и link-таблицы (предположительно link_ticket_flights).
    #
    # 2. flights_number: count(distinct flight_id) для каждого пассажира
    # 3. purchase_sum: sum(amount) для всех рейсов пассажира (берется из ticket_flights)
    # 4. home_airport: аэропорт, с которым больше всего перелётов (departure_airport или arrival_airport), при равенстве - алфавитный первый
    # 5. customer_group: разбиваем по перцентилям.
    #
    # Ниже приводится примерный SQL. Возможно, потребуется адаптация под реальную структуру link-таблиц DWH.

    build_frequent_flyers = PostgresOperator(
        task_id='build_frequent_flyers',
        postgres_conn_id='postgres_dwh',
        sql="""
        WITH passenger_tickets AS (
    SELECT 
        hp.passenger_id,
        hp.passenger_hid,
        ltp.ticket_id
    FROM dwh_detailed.hub_passengers hp
    JOIN dwh_detailed.link_tickets_passengers ltp ON ltp.passenger_hid = hp.passenger_hid
),

passenger_flights AS (
    SELECT
        pt.passenger_id,
        lt.flight_id,
        pt.ticket_id
    FROM passenger_tickets pt
    JOIN dwh_detailed.link_tickets_flights lt ON lt.ticket_id = pt.ticket_id
),

passenger_bookings AS (
    SELECT
        pt.passenger_id,
        ltb.book_id,
        pt.ticket_id
    FROM passenger_tickets pt
    JOIN dwh_detailed.link_tickets_bookings ltb ON ltb.ticket_id = pt.ticket_id
),

-- Подсчет суммы покупок пассажира (суммируем total_amount из sat_booking_details для всех бронирований этого пассажира)
passenger_purchase AS (
    SELECT
        pb.passenger_id,
        SUM(sbd.total_amount) AS purchase_sum
    FROM passenger_bookings pb
    JOIN dwh_detailed.sat_booking_details sbd ON sbd.book_id = pb.book_id
    GROUP BY pb.passenger_id
),

-- Получаем информацию о рейсах пассажира
passenger_flights_info AS (
    SELECT DISTINCT
        pf.passenger_id,
        pf.flight_id
    FROM passenger_flights pf
),

-- Получаем аэропорты вылета и прилёта для каждого рейса через link-таблицы
departure_airports AS (
    SELECT 
        lfda.flight_id,
        ha.airport_code as departure_airport
    FROM dwh_detailed.link_flights_departure_airports lfda
    JOIN dwh_detailed.hub_airports ha ON ha.airport_id = lfda.airport_id
),

arrival_airports AS (
    SELECT 
        lfaa.flight_id,
        ha.airport_code as arrival_airport
    FROM dwh_detailed.link_flights_arrival_airports lfaa
    JOIN dwh_detailed.hub_airports ha ON ha.airport_id = lfaa.airport_id
),

full_flight_airports AS (
    SELECT 
        da.flight_id,
        da.departure_airport,
        aa.arrival_airport
    FROM departure_airports da
    JOIN arrival_airports aa ON aa.flight_id = da.flight_id
),

-- Присоединяем имена пассажиров из sat_ticket_details (можем взять первый попавшийся билет этого пассажира)
passenger_names AS (
    SELECT DISTINCT
        hp.passenger_id,
        std.passenger_name
    FROM passenger_tickets pt
    JOIN dwh_detailed.sat_ticket_details std ON std.ticket_id = pt.ticket_id
    JOIN dwh_detailed.hub_passengers hp ON hp.passenger_hid = pt.passenger_hid
),

-- Соединяем пассажира с его рейсами и аэропортами
passenger_flights_airports AS (
    SELECT
        pfi.passenger_id,
        pna.passenger_name,
        pfi.flight_id,
        ffa.departure_airport,
        ffa.arrival_airport
    FROM passenger_flights_info pfi
    JOIN full_flight_airports ffa ON ffa.flight_id = pfi.flight_id
    JOIN passenger_names pna ON pna.passenger_id = pfi.passenger_id
),

-- Считаем количество уникальных рейсов на пассажира
flights_count AS (
    SELECT
        passenger_id,
        COUNT(DISTINCT flight_id) AS flights_number
    FROM passenger_flights_info
    GROUP BY passenger_id
),

-- Определяем "домашний" аэропорт
home_airport_calc AS (
    SELECT
        passenger_id,
        unnest(array[departure_airport, arrival_airport]) as airport_code
    FROM passenger_flights_airports
),
home_airport_count AS (
    SELECT passenger_id, airport_code, COUNT(*) as cnt
    FROM home_airport_calc
    GROUP BY passenger_id, airport_code
),
home_airport_rank AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY passenger_id ORDER BY cnt DESC, airport_code ASC) as rn
    FROM home_airport_count
),
home_airport_selected AS (
    SELECT passenger_id, airport_code as home_airport
    FROM home_airport_rank
    WHERE rn = 1
),

-- Объединяем все метрики
final_stats AS (
    SELECT 
        pn.passenger_id,
        pn.passenger_name,
        fc.flights_number,
        pp.purchase_sum,
        ha.home_airport
    FROM passenger_names pn
    JOIN flights_count fc ON fc.passenger_id = pn.passenger_id
    JOIN passenger_purchase pp ON pp.passenger_id = pn.passenger_id
    JOIN home_airport_selected ha ON ha.passenger_id = pn.passenger_id
),

-- Расчет перцентилей
percentiles AS (
    SELECT
        percentile_cont(0.05) WITHIN GROUP (ORDER BY purchase_sum) AS p5,
        percentile_cont(0.10) WITHIN GROUP (ORDER BY purchase_sum) AS p10,
        percentile_cont(0.25) WITHIN GROUP (ORDER BY purchase_sum) AS p25,
        percentile_cont(0.50) WITHIN GROUP (ORDER BY purchase_sum) AS p50
    FROM final_stats
),

final_classified AS (
    SELECT
        fs.*,
        CASE
            WHEN fs.purchase_sum >= (SELECT p5 FROM percentiles) AND fs.purchase_sum < (SELECT p10 FROM percentiles) THEN '5'
            WHEN fs.purchase_sum >= (SELECT p10 FROM percentiles) AND fs.purchase_sum < (SELECT p25 FROM percentiles) THEN '10'
            WHEN fs.purchase_sum >= (SELECT p25 FROM percentiles) AND fs.purchase_sum < (SELECT p50 FROM percentiles) THEN '25'
            WHEN fs.purchase_sum >= (SELECT p50 FROM percentiles) THEN '50'
            ELSE '50+'
        END as customer_group
    FROM final_stats fs, percentiles
)
INSERT INTO presentation.frequent_flyer (
    created_at,
    passenger_id,
    passenger_name,
    flights_number,
    purchase_sum,
    home_airport,
    customer_group
)
SELECT
    NOW(),
    passenger_id,
    passenger_name,
    flights_number,
    purchase_sum,
    home_airport,
    customer_group
FROM final_classified;
        """
    )

    truncate_presentation >> build_frequent_flyers