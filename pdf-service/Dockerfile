FROM python:3.11-slim

# WeasyPrint dependencies: libpango, cairo, gdk-pixbuf, etc.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libcairo2 \
    libgdk-pixbuf2.0-0 \
    libffi-dev \
    shared-mime-info \
    fonts-noto-core \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    fonts-noto-devanagari \
    fonts-noto-devanagari-extra \
    fonts-noto-bengali \
    fonts-noto-tamil \
    fonts-noto-telugu \
    fonts-noto-kannada \
    fonts-noto-malayalam \
    fonts-noto-gujarati \
    fonts-noto-oriya \
    fonts-noto-gurmukhi \
    fonts-noto-nastaliqurdu \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV PYTHONPATH=/app
ENV FLASK_APP=src.app:app

EXPOSE 5000

CMD ["flask", "run", "--host=0.0.0.0", "--port=5000"]
