# syntax=docker/dockerfile:1.6
########################  STAGE 1 — deps  ########################
FROM python:3.12-slim AS deps

ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1

# ——— Python-зависимости бекенда (FastAPI, Stanza и т.д.) ———
WORKDIR /install
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    torch==2.7.1+cpu --extra-index-url=https://download.pytorch.org/whl/cpu && \
    python - <<'PY'                            # модель Stanza грузим один раз
import stanza; stanza.download('ka', processors='tokenize,mwt,pos,lemma')
PY

########################  STAGE 2 — runtime  #####################
FROM python:3.12-slim

# ---- окружение -------------------------------------------------
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 \
    APP_DIR=/opt/parser \
    REPO_URL=https://github.com/goodven152/parser_GETenders.git \
    REPO_BRANCH=main \
    WDM_SKIP=1                       

# ---- системные пакеты (git + браузер + драйвер + либы) ---------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        chromium chromium-driver \
        libglib2.0-0 libnss3 libnspr4 libx11-6 libxcomposite1 libxdamage1 \
        libxrandr2 libatk-bridge2.0-0 libgtk-3-0 libasound2 libxss1 libxtst6 \
        libgbm1 && \
    rm -rf /var/lib/apt/lists/*

# ---- переносим готовые Python-библиотеки и модель Stanza -------
COPY --from=deps /usr/local /usr/local
COPY --from=deps /root/stanza_resources /root/stanza_resources

# ---- код backend API -------------------------------------------
WORKDIR /srv/backend
COPY backend/ .

# ---- тома: клон парсера + логи ---------------------------------
VOLUME ["${APP_DIR}", "/app/logs"]

# ---- entrypoint с git-pull и pip-install -----------------------
COPY backend/docker-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
