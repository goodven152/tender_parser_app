# Tender Parser Admin

Этот репозиторий предоставляет **полностью контейнеризованный** веб‑интерфейс для управления Python‑парсером [parser_GETenders](https://github.com/goodven152/parser_GETenders) (ветка `add_arg_launch`).
Админ‑панель покрывает все публичные методы API, позволяет запускать парсер вручную, видеть прогресс в реальном времени, просматривать историю запусков, редактировать `config.json` и управлять списком ключевых слов.

## Состав проекта

| Путь                 | Назначение                               |
| -------------------- | ---------------------------------------- |
| `backend/`           | FastAPI + APScheduler + SQLite           |
| `frontend/` `admin/` | Flutter Web‑приложение                   |
| `config.json`        | Конфиг парсера (монтируется в контейнер) |
| `docker-compose.yml` | Оркестрация двух контейнеров             |
| `logs/`              | Папка для JSON‑файлов и stdout‑логов     |

## Быстрый старт

> Требования: **Docker 20.10+** и **docker‑compose v2**.

```bash
# 1. Склонируйте репозиторий и перейдите в каталог
$ git clone <repo>
$ cd tender_parser_app

# 2. Проверьте / отредактируйте config.json (ключевые слова, прокси и пр.)

# 3. Запуск (первый билд займёт ~5‑7 минут)
$ docker compose up -d        # билдит и поднимает backend:8000 + frontend:8080

# 4. Откройте админку
👉 http://localhost:8080
```

### Что происходит при первом запуске

1. **Backend‑контейнер**

   - скачивает ветку `add_arg_launch` парсера в `/opt/parser`;
   - ставит зависимости парсера + свои собственные (FastAPI, APScheduler…);
   - настраивает `PYTHONPATH`, чтобы `python -m ge_parser_tenders.cli` был видимым;
   - создаёт SQLite БД `/app/runs.db` для истории запусков;
   - стартует Uvicorn на `0.0.0.0:8000`.

2. **Frontend‑контейнер**

   - собирает Flutter Web через образ `ghcr.io/cirruslabs/flutter:3.29.3`;
   - кладёт статику в Nginx‑alpine, который слушает `:80` → пробрасывается наружу на `8080`.

## Структура API

| Метод  | URL         | Описание                                         |
| ------ | ----------- | ------------------------------------------------ |
| `POST` | `/run`      | Запустить парсер вручную. Возвращает `run_id`.   |
| `WS`   | `/ws`       | Live‑стрим прогресса и stdout‑логов.             |
| `GET`  | `/runs`     | Последние 10 запусков (id, время, код возврата). |
| `GET`  | `/next_run` | Дата/время следующего планового запуска.         |
| `GET`  | `/keywords` | Массив `KEYWORDS_GEO` из `config.json`.          |
| `PUT`  | `/keywords` | Сохраняет изменённый массив ключевых слов.       |
| `GET`  | `/config`   | Полный `config.json`                             |
| `PUT`  | `/config`   | Перезаписывает конфиг целиком.                   |

> **CORS**: Backend открыт для `http://localhost:8080` (см. middleware в `main.py`).

## Разработка локально без Docker

```bash
# Backend
cd backend
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
python main.py   # Uvicorn поднимется на :8000

# Frontend
cd frontend/admin
flutter run -d chrome --web-port 8080 --dart-define=API_URL=http://localhost:8000
```

> Маршруты в Flutter читаются из переменной `API_URL` (по умолчанию origin страницы).

## Переменные окружения

| Переменная  | По умолчанию  | Значение                                |
| ----------- | ------------- | --------------------------------------- |
| `CRON_EXPR` | `"0 2 * * *"` | crontab‑выражение для плановых запусков |
| `TZ`        | `UTC`         | часовой пояс внутри контейнера backend  |

Пример установки в `docker-compose.yml`:

```yaml
services:
  backend:
    environment:
      - CRON_EXPR=0 */6 * * * # раз в 6 часов
      - TZ=Asia/Nicosia
```

## FAQ

<details>
<summary>⚠️  CORS‑ошибка при прямом открытии фронта из файловой системы</summary>
Браузеру нужны одинаковые origin’ы. Запустите фронт через Docker/nginx (`localhost:8080`) **или** включите веб‑сервер с тем же доменом/портом.
</details>

<details>
<summary>⚙️  Как изменить путь, где хранится parser_GETenders?</summary>
Правьте `backend/Dockerfile`:
```dockerfile
RUN git clone … /opt/parser   # ← сюда
ENV PYTHONPATH="/opt/parser:${PYTHONPATH}"
```
И пересоберите backend.
</details>

---
