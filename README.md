# Runbook AI Publisher

Node.js backend for uploading documents, converting them into Markdown runbooks using AI, and publishing them to the `ubuntu-runbook` GitHub repository.

## Main flow

```txt
Upload file
â†’ Extract text
â†’ Generate Markdown by AI
â†’ Create Markdown file in ubuntu-runbook
â†’ Update mkdocs.yml
â†’ Create Pull Request
```

## Development

```bash
npm install
npm run dev
```

## API

```txt
GET  /health
POST /api/knowledge/import
GET  /api/knowledge/imports
GET  /api/knowledge/imports/:id
```

## Environment

Copy `.env.example` to `.env` and update values.
