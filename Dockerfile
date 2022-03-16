FROM centos/python-36-centos7

COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

WORKDIR /mediator
COPY server /mediator

USER root

RUN useradd mediator && chown -R mediator /mediator

USER mediator

# CMD ["python", "Server.py"]
CMD ["gunicorn", "--timeout=180", "--workers=20", "--bind=0.0.0.0:8081", "--access-logfile=-", "Server:app"]
