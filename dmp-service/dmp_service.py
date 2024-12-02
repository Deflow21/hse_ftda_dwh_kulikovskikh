import os
import yaml
import json
import psycopg2
from confluent_kafka import Consumer, KafkaError



class DMPService:
    def __init__(self, config_path):
        with open(config_path, 'r') as file:
            self.config = yaml.safe_load(file)

        # Настройка Kafka Consumer
        self.consumer = Consumer({
            'bootstrap.servers': self.config['kafka']['broker'],
            'group.id': 'dmp_group',
            'auto.offset.reset': 'earliest'
        })
        self.consumer.subscribe(self.config['kafka']['topics'])

        # Подключение к DWH
        self.conn = psycopg2.connect(
            host=self.config['dwh']['host'],
            port=self.config['dwh']['port'],
            user=self.config['dwh']['user'],
            password=self.config['dwh']['password'],
            dbname=self.config['dwh']['dbname']
        )
        self.cursor = self.conn.cursor()

    def process_message(self, message):
        try:
            value = json.loads(message.value().decode('utf-8'))
            operation = value['op']
            table = value['source']['table']
            data = value['after'] if operation != 'd' else value['before']

            if operation in ['c', 'u']:
                if table == 'flights':
                    self.insert_flight(data)
                elif table == 'tickets':
                    self.insert_ticket(data)
                elif table == 'bookings':
                    self.insert_booking(data)
            elif operation == 'd':
                # В DWH insert-only, пропускаем операции delete
                pass
        except Exception as e:
            print(f"Error processing message: {e}")

    def insert_flight(self, data):
        # Вставка в Hub_Flights
        self.cursor.execute("""
            INSERT INTO dwh_detailed.hub_flights (flight_no, source_system_id)
            VALUES (%s, %s)
            ON CONFLICT (flight_no) DO NOTHING
        """, (data['flight_no'], 1))
        self.conn.commit()

        # Вставка в Sat_Flight_Details
        self.cursor.execute("""
            INSERT INTO dwh_detailed.sat_flight_details (
                flight_id, scheduled_departure, scheduled_arrival,
                departure_airport, arrival_airport, status, aircraft_code,
                actual_departure, actual_arrival, source_system_id
            )
            VALUES (
                (SELECT flight_id FROM dwh_detailed.hub_flights WHERE flight_no = %s),
                %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
        """, (
            data['flight_no'],
            data['scheduled_departure'],
            data['scheduled_arrival'],
            data['departure_airport'],
            data['arrival_airport'],
            data.get('status'),
            data.get('aircraft_code'),
            data.get('actual_departure'),
            data.get('actual_arrival'),
            1
        ))
        self.conn.commit()

    def insert_ticket(self, data):
        # Вставка в Hub_Tickets
        self.cursor.execute("""
            INSERT INTO dwh_detailed.hub_tickets (ticket_no, source_system_id)
            VALUES (%s, %s)
            ON CONFLICT (ticket_no) DO NOTHING
        """, (data['ticket_no'], 1))
        self.conn.commit()

        # Вставка в Sat_Ticket_Details
        self.cursor.execute("""
            INSERT INTO dwh_detailed.sat_ticket_details (
                ticket_no, book_ref, passenger_id, passenger_name,
                contact_data, source_system_id
            )
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            data['ticket_no'],
            data['book_ref'],
            data['passenger_id'],
            data['passenger_name'],
            json.dumps(data.get('contact_data', {})),
            1
        ))
        self.conn.commit()

    def insert_booking(self, data):
        # Вставка в Hub_Bookings
        self.cursor.execute("""
            INSERT INTO dwh_detailed.hub_bookings (book_ref, source_system_id)
            VALUES (%s, %s)
            ON CONFLICT (book_ref) DO NOTHING
        """, (data['book_ref'], 1))
        self.conn.commit()

        # Вставка в Sat_Booking_Details
        self.cursor.execute("""
            INSERT INTO dwh_detailed.sat_booking_details (
                book_ref, book_date, total_amount, source_system_id
            )
            VALUES (%s, %s, %s, %s)
        """, (
            data['book_ref'],
            data['book_date'],
            data['total_amount'],
            1
        ))
        self.conn.commit()

    def run(self):
        try:
            while True:
                msg = self.consumer.poll(timeout=1.0)
                if msg is None:
                    continue
                if msg.error():
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        continue
                    else:
                        print(msg.error())
                        break
                self.process_message(msg)
        except KeyboardInterrupt:
            pass
        finally:
            self.consumer.close()
            self.cursor.close()
            self.conn.close()


if __name__ == "__main__":
    service = DMPService('config.yaml')
    service.run()