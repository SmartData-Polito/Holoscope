FROM python:3.11-slim

WORKDIR /opt/wordpot

COPY app/requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

RUN mkdir -p logs

EXPOSE 8080

CMD ["python", "-u", "wordpot2.py", "--host=0.0.0.0", "--port=8080"]