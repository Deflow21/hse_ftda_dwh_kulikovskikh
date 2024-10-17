## Запуск проекта

1. Клонировать репозиторий:

   git clone https://github.com/yourusername/yourrepo.git
   cd yourrepo

2. Очистить данные (опционально):

   docker-compose down --volumes
   rm -rf ./data ./data-slave

3. Запустить проект:

   docker-compose up

4. База данных будет доступна:

   - Master: localhost:5432
   - Slave: localhost:5433

## Описание базы данных

- Включает таблицы аэропортов, самолётов, рейсов, бронирований, билетов.
- Создано представление `airport_traffic` для расчёта пассажиропотока аэропортов.

## Структура файлов

- docker-init.sh — скрипт инициализации.
- init.sql — DDL для создания таблиц.
- view.sql — скрипт для создания представления.
