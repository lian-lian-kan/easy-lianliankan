FROM python:3.11-slim

WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir fastapi==0.115.6 uvicorn==0.34.0 psycopg2-binary==2.9.10
COPY app ./app

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
