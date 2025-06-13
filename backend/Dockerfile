# syntax=docker/dockerfile:1.6
FROM python:3.12-slim
WORKDIR /app

# ─── system deps ───────────────────────────────────────────────────
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        git curl ca-certificates \
        chromium chromium-driver \
        fonts-liberation \
        libasound2 libatk-bridge2.0-0 libnspr4 libnss3 libx11-6 \
        libxcomposite1 libxdamage1 libxrandr2 libgbm1 libxss1 \
        libxtst6 libgtk-3-0 && \
    rm -rf /var/lib/apt/lists/*

ENV CHROME_BINARY=/usr/bin/chromium-browser \
    CHROMEDRIVER=/usr/bin/chromedriver \
    PATH="$PATH:/usr/bin" \
    PYTHONUNBUFFERED=1 \
    # ── что и где клонировать ──
    REPO_URL=https://github.com/goodven152/parser_GETenders.git \
    REPO_BRANCH=add_arg_launch \
    APP_DIR=/opt/parser

# ─── FastAPI-зависимости проекта ───────────────────────────────────
COPY backend/requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip,id=pip-cache \
    pip install --no-cache-dir -r requirements.txt

# ─── первый clone парсера + его requirements (кешируется) ──────────
RUN --mount=type=cache,target=/root/.cache/pip,id=pip-cache \
    git clone --depth 1 --branch ${REPO_BRANCH} ${REPO_URL} ${APP_DIR} && \
    if [ -f ${APP_DIR}/requirements.txt ]; then \
        pip install --no-cache-dir -r ${APP_DIR}/requirements.txt ; fi

# ─── грузинская модель Stanza — тоже один раз ──────────────────────
RUN python - <<'PY'
import stanza
stanza.download('ka')
PY

# ─── копируем ваш API-код ──────────────────────────────────────────
COPY backend .

# ─── запускаемся через entrypoint, который делает git pull + pip ──
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
