FROM node:24-bookworm-slim

WORKDIR /app

# Install Python + build tools for better-sqlite3 and MarkItDown
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install MarkItDown in Python virtual environment
RUN python3 -m venv /opt/markitdown-venv \
    && /opt/markitdown-venv/bin/pip install --upgrade pip \
    && /opt/markitdown-venv/bin/pip install "markitdown[all]"

ENV PATH="/opt/markitdown-venv/bin:${PATH}"
ENV PYTHONIOENCODING=utf-8
ENV PYTHONUTF8=1

COPY package*.json ./

RUN npm install

COPY tsconfig.json ./
COPY src ./src

RUN npm run build

RUN mkdir -p /app/uploads /app/data /app/logs

EXPOSE 5055

CMD ["node", "dist/app.js"]