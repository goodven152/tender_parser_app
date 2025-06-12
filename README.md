# Tender Parser Admin (Branch `add_arg_test`)

**Tender Parser Admin** — это веб‑панель для управления парсером *tender parser GETenders* — внешним проектом, в котором производится загрузка и анализ грузинских тендеров.  
Панель полностью контейнеризована: backend (FastAPI + APScheduler) и frontend (Flutter Web) стартуют одной командой Docker Compose и работают «из коробки».

---

## 📂 Содержимое репозитория

| Путь | Содержимое |
|------|------------|
| `backend/` | FastAPI API, cron‑планировщик, Dockerfile |
| `frontend/` → `admin/` | Flutter Web‑админка |
| `config.json` | Конфиг парсера (ключевые слова, прокси и т.д.) |
| `docker-compose.yml` | Оркестрация `backend` + `frontend` |
| `logs/` | JSON‑файлы результатов и stdout‑логи |

---

## ⚡ Быстрый старт

> Требования: **Docker 20.10+** и **docker‑compose v2** (входит в CLI).

```bash
# 1. Клонируем репозиторий
git clone https://github.com/goodven152/tender_parser_app.git -b add_arg_test
cd tender_parser_app

# 2. (опционально) правим config.json под свои ключевые слова

# 3. Первый запуск (~5‑7 мин на билд образов)
docker compose up -d          # backend:8000, frontend:8080

# 4. Открываем браузер
http://localhost:8080
```

Что происходит под капотом:

1. **Backend‑контейнер**  
   * Клонирует нужную ветку `parser_GETenders` в `/opt/parser`.  
   * При первом старте скачивает модель Stanza (`ka`) и ставит зависимости.  
   * Запускает Uvicorn по адресу `0.0.0.0:8000`.

2. **Frontend‑контейнер**  
   * Собирает Flutter‑Web (образ `ghcr.io/cirruslabs/flutter`).  
   * Отдаёт статику Nginx‑alpine на `8080`.

---

## 🔄 Как обновляется код

* **Парсер** живёт в отдельном Docker‑томе `tender_parser_repo`.  
  При `docker restart backend` entrypoint делает `git pull` и, если изменился
  `requirements.txt`, — доустанавливает новые пакеты.  
* **Системные зависимости** (Chromium, Stanza‑модель, Python‑библиотеки backend)
  запекаются в образе и перестраиваются **только** когда правится
  `backend/Dockerfile` или `backend/requirements.txt`.

---

## 🌐 API‑эндпоинты backend

| Метод | URL | Описание |
|-------|-----|----------|
| `POST` | `/run` | Запуск парсера вручную, отвечает `run_id` |
| `WS` | `/ws` | Live‑стрим логов и прогресса |
| `GET` | `/runs` | Последние 10 запусков |
| `GET` | `/next_run` | Дата/время планового запуска |
| `GET/PUT` | `/config` | Получить/заменить целиком `config.json` |
| `GET/PUT` | `/keywords` | Получить/сохранить массив ключевых слов |

---

## ⚙️ Переменные окружения

| Переменная | По‑умолчанию | Назначение |
|------------|--------------|-----------|
| `CRON_EXPR` | `0 2 * * *` | Cron‑выражение планового запуска |
| `TZ` | `UTC` | Часовой пояс backend |
| `REPO_URL` | `https://github.com/goodven152/parser_GETenders.git` | URL парсера |
| `REPO_BRANCH` | `add_arg_test` | Ветка парсера |

Изменяются в `docker-compose.yml`, пример:

```yaml
services:
  backend:
    environment:
      - CRON_EXPR=0 */6 * * *   # каждые 6 часов
      - TZ=Asia/Tbilisi
      - REPO_BRANCH=add_arg_test
```

---

## 🛠️ Локальная разработка без Docker

```bash
# Backend
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload

# Frontend
cd frontend/admin
flutter run -d chrome   --web-port 8080   --dart-define=API_URL=http://localhost:8000
```

---

## ❓ FAQ

* **После обновления парсера появились новые зависимости**  
  Перезапустите backend: `docker compose up -d --build backend`.

* **CORS‑ошибка, если открываю HTML напрямую**  
  Запускайте фронт через Nginx (`docker compose up frontend`)
  или вручную указав `--dart-define=API_URL`.

* **Хочу поменять путь, где хранится клон парсера**  
  В `backend/Dockerfile` измените  
  `ENV APP_DIR=/opt/parser` и пересоберите образ.

---
