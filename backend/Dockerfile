FROM python:3.12-slim
WORKDIR /app

ARG APP_PASSWORD
ENV APP_PASSWORD=$APP_PASSWORD

# --- system deps -----------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    chromium \
    chromium-driver \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libnspr4 libnss3 libx11-6 libxcomposite1 libxdamage1 \
    libxrandr2 libgbm1 libxss1 libxtst6 libgtk-3-0 ca-certificates && \
    rm -rf /var/lib/apt/lists/*




# chrome & driver оказываются в /usr/bin/chromium-browser /usr/bin/chromedriver
ENV CHROME_BINARY=/usr/bin/chromium-browser
ENV CHROMEDRIVER=/usr/bin/chromedriver
ENV PATH="$PATH:/usr/bin"


# 1. системный git (для clone)
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

# 2. наши зависимости FastAPI и т.п.
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3. клонируем сам парсер и ставим его requirements
RUN git clone --branch add_arg_launch \
    https://github.com/goodven152/parser_GETenders.git /opt/parser \
    && pip install --no-cache-dir -r /opt/parser/requirements.txt

# 4. делаем код видимым для Python
ENV PYTHONPATH="/opt/parser:${PYTHONPATH}"

# 5. (опционально) впервые скачиваем грузинскую модель stanza,
#    чтобы потом запуск был без сети
RUN python -c "import stanza, os; stanza.download('ka')"

# 6. копируем наш API-код
COPY backend .
ENV PYTHONUNBUFFERED=1
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]


