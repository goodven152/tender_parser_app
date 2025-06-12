# syntax=docker/dockerfile:1.6

########################  STAGE 1 – deps  ########################
FROM python:3.12-slim AS deps
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1

# ── System deps ─────────────────────────────────────────────────
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git tesseract-ocr chromium chromium-driver ca-certificates \
        fonts-liberation libasound2 libatk-bridge2.0-0 \
        libnspr4 libnss3 libx11-6 libxcomposite1 libxdamage1 \
        libxrandr2 libgbm1 libxss1 libxtst6 libgtk-3-0 && \
    rm -rf /var/lib/apt/lists/*

# ── Backend python deps ─────────────────────────────────────────
WORKDIR /install
COPY backend/requirements.txt .
RUN pip install -r requirements.txt

# ── Stanza model (скачивается ровно один раз) ──────────────────
RUN python - <<'PY'
import stanza
stanza.download('ka', processors='tokenize,mwt,pos,lemma')
PY

########################  STAGE 2 – runtime  #####################
FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 \
    APP_DIR=/opt/parser \
    REPO_URL=https://github.com/goodven152/parser_GETenders.git \
    REPO_BRANCH=main

# ── копируем готовые библиотеки, chromium и модель ─────────────
COPY --from=deps /usr/local /usr/local
COPY --from=deps /usr/bin/chromium* /usr/bin/
COPY --from=deps /usr/lib/chromium /usr/lib/chromium
COPY --from=deps /root/stanza_resources /root/stanza_resources

# ── API-код бэкенда ─────────────────────────────────────────────
WORKDIR /srv/backend
COPY backend/ .

# ── код парсера и логи живут в отдельных томах ─────────────────
VOLUME ["${APP_DIR}", "/app/logs"]

# ── «ленивый» entrypoint: git pull + pip install при старте ────
COPY docker-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
