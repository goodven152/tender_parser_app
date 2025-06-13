# syntax=docker/dockerfile:1.6

######################## STAGE 1 — python deps ########################
FROM python:3.12-slim AS deps

ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1

WORKDIR /install

# 1. Берём ТОЛЬКО backend-requirements, чтобы слой кешировался по-максимуму
COPY requirements.txt .

# 2. Ставим зависимости + torch, грузим модель Stanza — всё один раз
RUN --mount=type=cache,target=/root/.cache/pip,id=pip-cache \
    pip install --no-cache-dir -r requirements.txt \
                torch==2.7.1+cpu \
                --extra-index-url=https://download.pytorch.org/whl/cpu \
 && python - <<'PY'               \
import stanza; stanza.download('ka', processors='tokenize,mwt,pos,lemma')
PY

######################## STAGE 2 — runtime ###########################
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 \
    APP_DIR=/opt/parser \
    REPO_URL=https://github.com/goodven152/parser_GETenders.git \
    REPO_BRANCH=main \
    CHROME_BINARY=/usr/bin/chromium-browser \
    CHROMEDRIVER=/usr/bin/chromedriver \
    PATH=$PATH:/usr/bin

WORKDIR /srv/backend

# ---- системные пакеты (git + Chromium + все нужные so) ------------
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        git curl ca-certificates \
        chromium chromium-driver \
        libglib2.0-0 libnss3 libnspr4 libx11-6 libxcomposite1 libxdamage1 \
        libxrandr2 libatk-bridge2.0-0 libgtk-3-0 libasound2 libxss1 libxtst6 \
        libgbm1 && \
    rm -rf /var/lib/apt/lists/*

# ---- переносим готовые библиотеки Python и модель Stanza ----------
COPY --from=deps /usr/local /usr/local
COPY --from=deps /root/stanza_resources /root/stanza_resources

# ---- клонируем парсер и ставим его зависимости (тоже кешируется) --
RUN --mount=type=cache,target=/root/.cache/pip,id=pip-cache \
    git clone --depth=1 --branch ${REPO_BRANCH} ${REPO_URL} ${APP_DIR} && \
    pip install --no-cache-dir -r ${APP_DIR}/requirements.txt && \
    pip install --no-cache-dir -e ${APP_DIR}

# ---- копируем исходники backend’а ----------------------------------
COPY . .

# ---- стартовый скрипт (у вас уже вызывает Uvicorn) ----------------
COPY docker-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
