FROM python:3.12-slim
WORKDIR /app

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
