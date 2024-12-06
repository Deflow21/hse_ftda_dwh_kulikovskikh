## Инструкция по запуску проекта

### Требования
Для успешного выполнения проекта вам необходимо:
- Установленный **Docker** и **Docker Compose**.

### Описание ДЗ 3

Выполненное Дз 3 в отдельной ветке hw_3
Весь функционал с Аирфлоу и ETL реализован.

## Инструкция по запуску и проверке проекта

### Открытие интерфейса Airflow
1. Перейдите по адресу: [http://localhost:8080](http://localhost:8080).
2. Введите данные для входа:
   - **Логин**: `admin`
   - **Пароль**: `admin`

### Активация DAG’ов
1. Зайдите в интерфейс Airflow.
2. Найдите DAG в списке:
   - `frequent_flyer_dag`
   - `passenger_traffic_dag`
3. Нажмите на переключатель (Toggle) рядом с названием DAG, чтобы активировать его.

### Запуск DAG’ов вручную (опционально)
1. В интерфейсе Airflow выберите DAG.
2. Нажмите кнопку **Trigger DAG** в правом верхнем углу.

---

### Проверка результата

#### 1. Подключитесь к базе данных `dwh_detailed`:
```bash
docker exec -it postgres_dwh psql -U postgres -d dwh_detailed
```

### 2. Проверьте что витрины существую:
```bash
SELECT * FROM presentation.frequent_flyer LIMIT 1;
SELECT * FROM presentation.passenger_traffic LIMIT 1;
```