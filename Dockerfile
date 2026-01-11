
FROM public.ecr.aws/docker/library/python:3.11-slim
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE 1 \
    PYTHONUNBUFFERED 1

ARG APP_VERSION=dev
ARG APP_BUILD_TIME=unknown
ENV APP_VERSION=${APP_VERSION} \
    APP_BUILD_TIME=${APP_BUILD_TIME}


COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY . .
EXPOSE 5000
CMD ["gunicorn", "-b", "0.0.0.0:5000", "run:app"]