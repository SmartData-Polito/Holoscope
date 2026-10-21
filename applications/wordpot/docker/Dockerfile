FROM python:2.7-slim

WORKDIR /opt/wordpot

COPY app/ .

RUN mkdir -p logs \
    && pip install --no-cache-dir \
       "Flask==0.10.1" \
       "Jinja2<3" \
       "Werkzeug<1" \
       "itsdangerous<2" \
       "MarkupSafe<2" \
       hpfeeds

EXPOSE 8080

CMD ["python", "wordpot.py", "--host=0.0.0.0", "--port=8080"]