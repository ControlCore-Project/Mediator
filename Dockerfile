FROM python:3.6-slim

RUN apt-get update && apt-get install -y ca-certificates \
    && update-ca-certificates \
    && python3 -m ensurepip --default-pip \
    && pip install --upgrade pip setuptools wheel

COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

WORKDIR /mediator
COPY server /mediator

RUN useradd mediator && chown -R mediator /mediator
USER mediator

CMD ["gunicorn", "--timeout=180", "--workers=20", "--bind=0.0.0.0:8081", "--access-logfile=-", "Server:app"]