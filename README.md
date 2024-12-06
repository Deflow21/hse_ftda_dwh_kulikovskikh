<h1 style="color: red;">⚠️ ВНИМАНИЕ ⚠️</h1>
<p>Домашние задания 2, 3 и 4 находятся на других ветках проекта с соответствующими названиями:</p>
<ul>
  <li><strong>hw_2</strong></li>
  <li><strong>hw_3</strong></li>
  <li><strong>hw_4</strong></li>
</ul>

# PostgreSQL Master-Slave Репликация в Docker

## Описание

Этот проект демонстрирует настройку репликации PostgreSQL (Master-Slave) с использованием Docker и Docker Compose. Инициализация базы данных и настройка репликации происходят автоматически при запуске контейнеров.


## Шаги для запуска

1. **Клонируйте репозиторий:**

   ```bash
   git clone https://github.com/your_username/your_repository.git
   cd your_repository

2. **Запустите контейнеры**
    ```bash
   docker-compose up -d

3. Проверка состоянияя
   ```bash
   docker ps
   
4. Проверка статуса репликации
   ```bash
   ## на мастере
   docker exec -it postgres_master psql -U postgres -c "SELECT pid, state, client_addr FROM pg_stat_replication;"
   ## на слейве
   docker exec -it postgres_slave psql -U postgres -c "SELECT status, sender_host, sender_port FROM pg_stat_wal_receiver;"

5. Тестирование
   ```bash
   docker exec -it postgres_master psql -U postgres -c "
   CREATE TABLE test_table (id SERIAL PRIMARY KEY, data TEXT);
   INSERT INTO test_table (data) VALUES ('Hello, replication!');"
   
   ## Проверка наличия данных на слейве:
   docker exec -it postgres_slave psql -U postgres -c "SELECT * FROM test_table;"
   
6. Завершение работы
   ```bash
   docker-compose down --volumes --remove-orphans




Вьюшка находится в init-script/master/03-create-passenger-flow-view.sql
