FROM python:3.12
WORKDIR /app
COPY backend/requirements.txt .
RUN pip install -r requirements.txt
COPY backend /app
COPY shared/config.json /app
ENTRYPOINT ["bash", "-c"]
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]