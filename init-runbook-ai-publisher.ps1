# init-runbook-ai-publisher.ps1
# Create base structure and install packages for Runbook AI Publisher

$ErrorActionPreference = "Stop"

$ProjectPath = "D:\1.ENVIRONMENT\53.JITS\runbook-ai-publisher"

Write-Host "Initializing Runbook AI Publisher project..." -ForegroundColor Cyan
Write-Host "Project path: $ProjectPath" -ForegroundColor Cyan

if (!(Test-Path $ProjectPath)) {
    New-Item -ItemType Directory -Path $ProjectPath -Force | Out-Null
}

Set-Location $ProjectPath

# -----------------------------
# Create folders
# -----------------------------

$folders = @(
    "src",
    "src\routes",
    "src\services",
    "src\db",
    "src\types",
    "src\utils",
    "uploads",
    "data",
    "logs"
)

foreach ($folder in $folders) {
    if (!(Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-Host "Created folder: $folder" -ForegroundColor Green
    }
}

# -----------------------------
# Initialize package.json
# -----------------------------

if (!(Test-Path "package.json")) {
    Write-Host "Creating package.json..." -ForegroundColor Cyan
    npm init -y
}

# -----------------------------
# Install dependencies
# -----------------------------

Write-Host "Installing dependencies..." -ForegroundColor Cyan
npm install express multer better-sqlite3 dotenv openai @octokit/rest yaml slugify cors morgan mammoth pdf-parse

Write-Host "Installing dev dependencies..." -ForegroundColor Cyan
npm install -D typescript tsx @types/node @types/express @types/multer @types/cors @types/morgan @types/better-sqlite3 rimraf

# -----------------------------
# Create tsconfig.json
# -----------------------------

$tsconfig = @'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "CommonJS",
    "moduleResolution": "Node",
    "rootDir": "src",
    "outDir": "dist",
    "strict": true,
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": [
    "src/**/*.ts"
  ],
  "exclude": [
    "node_modules",
    "dist"
  ]
}
'@

Set-Content -Path "tsconfig.json" -Value $tsconfig -Encoding UTF8
Write-Host "Created tsconfig.json" -ForegroundColor Green

# -----------------------------
# Create .env.example and .env
# -----------------------------

$envExample = @'
PORT=5055

OPENAI_API_KEY=your_openai_api_key

GITHUB_OWNER=nguyenvuhoang
GITHUB_REPO=ubuntu-runbook
GITHUB_BRANCH=main
GITHUB_TOKEN=your_github_token

RUNBOOK_SITE_URL=https://nguyenvuhoang.github.io/ubuntu-runbook

SQLITE_DB_PATH=./data/runbook-import.db
UPLOAD_DIR=./uploads
'@

Set-Content -Path ".env.example" -Value $envExample -Encoding UTF8

if (!(Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example" -ForegroundColor Green
}

# -----------------------------
# Create .gitignore
# -----------------------------

$gitignore = @'
node_modules/
dist/
.env
uploads/*
data/*.db
data/*.db-journal
logs/*
.DS_Store
Thumbs.db
'@

Set-Content -Path ".gitignore" -Value $gitignore -Encoding UTF8
Write-Host "Created .gitignore" -ForegroundColor Green

# -----------------------------
# Create README.md
# -----------------------------

$readme = @'
# Runbook AI Publisher

Node.js backend for uploading documents, converting them into Markdown runbooks using AI, and publishing them to the `ubuntu-runbook` GitHub repository.

## Main flow

```txt
Upload file
→ Extract text
→ Generate Markdown by AI
→ Create Markdown file in ubuntu-runbook
→ Update mkdocs.yml
→ Create Pull Request
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
'@

Set-Content -Path "README.md" -Value $readme -Encoding UTF8
Write-Host "Created README.md" -ForegroundColor Green

# -----------------------------
# Create src/app.ts
# -----------------------------

$appTs = @'
import express from "express";
import cors from "cors";
import morgan from "morgan";
import dotenv from "dotenv";
import knowledgeRoutes from "./routes/knowledge.routes";

dotenv.config();

const app = express();

app.use(cors());
app.use(morgan("dev"));
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

app.get("/health", (_req, res) => {
  res.json({
    success: true,
    message: "Runbook AI Publisher is running"
  });
});

app.use("/api/knowledge", knowledgeRoutes);

const port = process.env.PORT || 5055;

app.listen(port, () => {
  console.log(`Runbook AI Publisher is running on port ${port}`);
});
'@

Set-Content -Path "src\app.ts" -Value $appTs -Encoding UTF8
Write-Host "Created src/app.ts" -ForegroundColor Green

# -----------------------------
# Create src/routes/knowledge.routes.ts
# -----------------------------

$routesTs = @'
import express from "express";
import multer from "multer";
import path from "path";
import {
  createImportJob,
  getImportJobById,
  getImportJobs,
  updateImportJob
} from "../db/database";

const router = express.Router();

const uploadDir = process.env.UPLOAD_DIR || "./uploads";

const upload = multer({
  dest: uploadDir,
  limits: {
    fileSize: 10 * 1024 * 1024
  }
});

router.post("/import", upload.single("file"), async (req, res) => {
  let jobId: number | undefined;

  try {
    const file = req.file;

    if (!file) {
      return res.status(400).json({
        success: false,
        message: "File is required"
      });
    }

    const commandText = req.body.commandText || "Đưa nội dung này về kho";
    const mode = req.body.mode || "review";
    const createdBy = req.body.createdBy || "system";

    jobId = createImportJob({
      originalFileName: file.originalname,
      fileType: path.extname(file.originalname).toLowerCase(),
      fileSize: file.size,
      commandText,
      status: "UPLOADED",
      createdBy
    });

    // TODO:
    // 1. Extract text from uploaded file
    // 2. Generate Markdown by AI
    // 3. Redact secrets
    // 4. Push to GitHub or create PR
    // 5. Update job status

    updateImportJob(jobId, {
      status: "UPLOADED"
    });

    return res.json({
      success: true,
      jobId,
      mode,
      message: "File uploaded successfully. Next step: implement extractor and GitHub publisher."
    });
  } catch (error: any) {
    if (jobId) {
      updateImportJob(jobId, {
        status: "FAILED",
        errorMessage: error.message
      });
    }

    return res.status(500).json({
      success: false,
      jobId,
      message: error.message
    });
  }
});

router.get("/imports", (_req, res) => {
  const jobs = getImportJobs();

  res.json({
    success: true,
    data: jobs
  });
});

router.get("/imports/:id", (req, res) => {
  const id = Number(req.params.id);
  const job = getImportJobById(id);

  if (!job) {
    return res.status(404).json({
      success: false,
      message: "Import job not found"
    });
  }

  return res.json({
    success: true,
    data: job
  });
});

export default router;
'@

Set-Content -Path "src\routes\knowledge.routes.ts" -Value $routesTs -Encoding UTF8
Write-Host "Created src/routes/knowledge.routes.ts" -ForegroundColor Green

# -----------------------------
# Create src/db/database.ts
# -----------------------------

$databaseTs = @'
import Database from "better-sqlite3";
import fs from "fs";
import path from "path";

const dbPath = process.env.SQLITE_DB_PATH || "./data/runbook-import.db";
const dbDir = path.dirname(dbPath);

if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

const db = new Database(dbPath);

db.exec(`
CREATE TABLE IF NOT EXISTS KnowledgeImportJob (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,

    OriginalFileName TEXT NOT NULL,
    FileType TEXT NULL,
    FileSize INTEGER NULL,

    CommandText TEXT NULL,

    Title TEXT NULL,
    Category TEXT NULL,
    FileName TEXT NULL,
    MarkdownPath TEXT NULL,

    GeneratedMarkdown TEXT NULL,
    GeneratedJson TEXT NULL,

    GitBranch TEXT NULL,
    PullRequestUrl TEXT NULL,
    CommitSha TEXT NULL,
    PublishUrl TEXT NULL,

    Status TEXT NOT NULL,
    ErrorMessage TEXT NULL,

    CreatedBy TEXT NULL,
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TEXT NULL
);
`);

export function createImportJob(data: {
  originalFileName: string;
  fileType?: string;
  fileSize?: number;
  commandText?: string;
  status: string;
  createdBy?: string;
}): number {
  const stmt = db.prepare(`
    INSERT INTO KnowledgeImportJob (
      OriginalFileName,
      FileType,
      FileSize,
      CommandText,
      Status,
      CreatedBy
    )
    VALUES (
      @originalFileName,
      @fileType,
      @fileSize,
      @commandText,
      @status,
      @createdBy
    )
  `);

  const result = stmt.run(data);

  return Number(result.lastInsertRowid);
}

export function updateImportJob(id: number, data: Record<string, any>): void {
  const columnMap: Record<string, string> = {
    originalFileName: "OriginalFileName",
    fileType: "FileType",
    fileSize: "FileSize",
    commandText: "CommandText",
    title: "Title",
    category: "Category",
    fileName: "FileName",
    markdownPath: "MarkdownPath",
    generatedMarkdown: "GeneratedMarkdown",
    generatedJson: "GeneratedJson",
    gitBranch: "GitBranch",
    pullRequestUrl: "PullRequestUrl",
    commitSha: "CommitSha",
    publishUrl: "PublishUrl",
    status: "Status",
    errorMessage: "ErrorMessage",
    createdBy: "CreatedBy"
  };

  const fields = Object.keys(data).filter((key) => columnMap[key]);

  if (fields.length === 0) {
    return;
  }

  const setClause = fields
    .map((key) => `${columnMap[key]} = @${key}`)
    .join(", ");

  const stmt = db.prepare(`
    UPDATE KnowledgeImportJob
    SET ${setClause},
        UpdatedAt = CURRENT_TIMESTAMP
    WHERE Id = @id
  `);

  stmt.run({
    ...data,
    id
  });
}

export function getImportJobs() {
  return db.prepare(`
    SELECT *
    FROM KnowledgeImportJob
    ORDER BY Id DESC
  `).all();
}

export function getImportJobById(id: number) {
  return db.prepare(`
    SELECT *
    FROM KnowledgeImportJob
    WHERE Id = ?
  `).get(id);
}
'@

Set-Content -Path "src\db\database.ts" -Value $databaseTs -Encoding UTF8
Write-Host "Created src/db/database.ts" -ForegroundColor Green

# -----------------------------
# Create src/types/knowledge.ts
# -----------------------------

$typesTs = @'
export type KnowledgeImportStatus =
  | "UPLOADED"
  | "EXTRACTED"
  | "GENERATED"
  | "PR_CREATED"
  | "PUBLISHED"
  | "FAILED";

export interface GeneratedRunbookDocument {
  title: string;
  category: string;
  fileName: string;
  navTitle: string;
  markdown: string;
  tags: string[];
}

export interface KnowledgeImportResult {
  success: boolean;
  jobId: number;
  title?: string;
  category?: string;
  markdownPath?: string;
  pullRequestUrl?: string;
  publishUrl?: string;
  status: KnowledgeImportStatus;
  errorMessage?: string;
}
'@

Set-Content -Path "src\types\knowledge.ts" -Value $typesTs -Encoding UTF8
Write-Host "Created src/types/knowledge.ts" -ForegroundColor Green

# -----------------------------
# Create service files
# -----------------------------

$fileExtractor = @'
import fs from "fs/promises";
import path from "path";
import mammoth from "mammoth";
import pdf from "pdf-parse";

export async function extractTextFromFile(filePath: string, originalFileName: string): Promise<string> {
  const ext = path.extname(originalFileName).toLowerCase();

  if ([".txt", ".md", ".json", ".yml", ".yaml", ".html"].includes(ext)) {
    return await fs.readFile(filePath, "utf-8");
  }

  if (ext === ".docx") {
    const result = await mammoth.extractRawText({ path: filePath });
    return result.value;
  }

  if (ext === ".pdf") {
    const buffer = await fs.readFile(filePath);
    const result = await pdf(buffer);
    return result.text;
  }

  throw new Error(`Unsupported file type: ${ext}`);
}
'@

Set-Content -Path "src\services\fileExtractor.service.ts" -Value $fileExtractor -Encoding UTF8
Write-Host "Created src/services/fileExtractor.service.ts" -ForegroundColor Green

$secretRedaction = @'
export function redactSecrets(markdown: string): string {
  let result = markdown;

  const patterns: RegExp[] = [
    /password\s*=\s*['"]?[^'"\s]+['"]?/gi,
    /pwd\s*=\s*['"]?[^'"\s]+['"]?/gi,
    /token\s*=\s*['"]?[^'"\s]+['"]?/gi,
    /secret\s*=\s*['"]?[^'"\s]+['"]?/gi,
    /api[_-]?key\s*=\s*['"]?[^'"\s]+['"]?/gi,
    /-----BEGIN RSA PRIVATE KEY-----[\s\S]*?-----END RSA PRIVATE KEY-----/gi,
    /-----BEGIN PRIVATE KEY-----[\s\S]*?-----END PRIVATE KEY-----/gi
  ];

  for (const pattern of patterns) {
    result = result.replace(pattern, "<REDACTED_SECRET>");
  }

  return result;
}
'@

Set-Content -Path "src\services\secretRedaction.service.ts" -Value $secretRedaction -Encoding UTF8
Write-Host "Created src/services/secretRedaction.service.ts" -ForegroundColor Green

$aiMarkdown = @'
import OpenAI from "openai";
import { GeneratedRunbookDocument } from "../types/knowledge";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

export async function generateRunbookMarkdown(input: {
  originalFileName: string;
  textContent: string;
  commandText: string;
}): Promise<GeneratedRunbookDocument> {
  const prompt = `
You are the Runbook Knowledge Publisher.

Convert the uploaded technical content into clean Markdown for a MkDocs runbook repository.

Rules:
1. Use clear technical documentation format.
2. Keep commands copy-paste friendly.
3. Remove or mask sensitive data: password, token, private key, connection string, production IP.
4. Classify the document into one category:
   ubuntu, docker, nginx, cloudflare, sqlserver, git, errors, tools.
5. Generate a lowercase kebab-case file name.
6. Return JSON only. Do not wrap the JSON in markdown code fences.

Output JSON format:
{
  "title": "",
  "category": "",
  "fileName": "",
  "navTitle": "",
  "markdown": "",
  "tags": []
}

Markdown structure:
# Title

## Overview

## When to use

## Prerequisites

## Steps

## Verification

## Common errors

## Notes

## Tags

Original file name:
${input.originalFileName}

User command:
${input.commandText}

Content:
${input.textContent}
`;

  const response = await client.chat.completions.create({
    model: "gpt-4.1-mini",
    messages: [
      {
        role: "user",
        content: prompt
      }
    ],
    temperature: 0.2
  });

  const content = response.choices[0]?.message?.content;

  if (!content) {
    throw new Error("AI returned empty response");
  }

  return JSON.parse(content) as GeneratedRunbookDocument;
}
'@

Set-Content -Path "src\services\aiMarkdown.service.ts" -Value $aiMarkdown -Encoding UTF8
Write-Host "Created src/services/aiMarkdown.service.ts" -ForegroundColor Green

$mkdocsNav = @'
import yaml from "yaml";

export function updateMkdocsNav(input: {
  yamlContent: string;
  category: string;
  navTitle: string;
  markdownPath: string;
}): string {
  const doc: any = yaml.parse(input.yamlContent) || {};

  if (!doc.nav) {
    doc.nav = [];
  }

  const categoryTitle = toCategoryTitle(input.category);

  let categoryNode = doc.nav.find((item: any) => {
    return typeof item === "object" && item[categoryTitle];
  });

  if (!categoryNode) {
    categoryNode = {
      [categoryTitle]: []
    };
    doc.nav.push(categoryNode);
  }

  const items = categoryNode[categoryTitle];

  const exists = items.some((item: any) => {
    return typeof item === "object" && item[input.navTitle] === input.markdownPath;
  });

  if (!exists) {
    items.push({
      [input.navTitle]: input.markdownPath
    });
  }

  return yaml.stringify(doc);
}

function toCategoryTitle(category: string): string {
  const map: Record<string, string> = {
    ubuntu: "Ubuntu",
    docker: "Docker",
    nginx: "Nginx",
    cloudflare: "Cloudflare",
    sqlserver: "SQL Server",
    git: "Git",
    errors: "Errors",
    tools: "Tools"
  };

  return map[category] || category;
}
'@

Set-Content -Path "src\services\mkdocsNav.service.ts" -Value $mkdocsNav -Encoding UTF8
Write-Host "Created src/services/mkdocsNav.service.ts" -ForegroundColor Green

$githubPublisher = @'
import { Octokit } from "@octokit/rest";
import { updateMkdocsNav } from "./mkdocsNav.service";

const octokit = new Octokit({
  auth: process.env.GITHUB_TOKEN
});

const owner = process.env.GITHUB_OWNER || "nguyenvuhoang";
const repo = process.env.GITHUB_REPO || "ubuntu-runbook";
const baseBranch = process.env.GITHUB_BRANCH || "main";

export async function publishToGithub(input: {
  mode: "review" | "publish";
  category: string;
  navTitle: string;
  markdownPath: string;
  markdownContent: string;
}) {
  const fileSlug = input.markdownPath
    .split("/")
    .pop()
    ?.replace(".md", "") || "runbook";

  const branch = input.mode === "publish"
    ? baseBranch
    : `ai/import/${Date.now()}-${fileSlug}`;

  if (input.mode === "review") {
    await createBranch(branch);
  }

  await createOrUpdateFile({
    path: input.markdownPath,
    content: input.markdownContent,
    branch,
    message: `Add runbook: ${input.navTitle}`
  });

  const mkdocsContent = await getFileContent("mkdocs.yml", branch);

  const updatedMkdocs = updateMkdocsNav({
    yamlContent: mkdocsContent,
    category: input.category,
    navTitle: input.navTitle,
    markdownPath: input.markdownPath.replace(/^docs\//, "")
  });

  await createOrUpdateFile({
    path: "mkdocs.yml",
    content: updatedMkdocs,
    branch,
    message: `Update navigation for ${input.navTitle}`
  });

  let pullRequestUrl: string | undefined;

  if (input.mode === "review") {
    const pr = await octokit.pulls.create({
      owner,
      repo,
      title: `Add runbook: ${input.navTitle}`,
      head: branch,
      base: baseBranch,
      body: "Auto-generated runbook document from uploaded content."
    });

    pullRequestUrl = pr.data.html_url;
  }

  const publishUrl = `${process.env.RUNBOOK_SITE_URL || ""}/${input.markdownPath
    .replace(/^docs\//, "")
    .replace(/\.md$/, "")}`;

  return {
    branch,
    pullRequestUrl,
    commitSha: undefined,
    publishUrl
  };
}

async function createBranch(branchName: string): Promise<void> {
  const baseRef = await octokit.git.getRef({
    owner,
    repo,
    ref: `heads/${baseBranch}`
  });

  await octokit.git.createRef({
    owner,
    repo,
    ref: `refs/heads/${branchName}`,
    sha: baseRef.data.object.sha
  });
}

async function getFileContent(filePath: string, branch: string): Promise<string> {
  const response = await octokit.repos.getContent({
    owner,
    repo,
    path: filePath,
    ref: branch
  });

  if (Array.isArray(response.data) || response.data.type !== "file") {
    throw new Error(`Invalid file: ${filePath}`);
  }

  return Buffer.from(response.data.content, "base64").toString("utf-8");
}

async function createOrUpdateFile(input: {
  path: string;
  content: string;
  branch: string;
  message: string;
}): Promise<void> {
  let sha: string | undefined;

  try {
    const existing = await octokit.repos.getContent({
      owner,
      repo,
      path: input.path,
      ref: input.branch
    });

    if (!Array.isArray(existing.data) && existing.data.type === "file") {
      sha = existing.data.sha;
    }
  } catch {
    sha = undefined;
  }

  await octokit.repos.createOrUpdateFileContents({
    owner,
    repo,
    path: input.path,
    message: input.message,
    content: Buffer.from(input.content, "utf-8").toString("base64"),
    branch: input.branch,
    sha
  });
}
'@

Set-Content -Path "src\services\githubPublisher.service.ts" -Value $githubPublisher -Encoding UTF8
Write-Host "Created src/services/githubPublisher.service.ts" -ForegroundColor Green

# -----------------------------
# Update route to wire actual services
# -----------------------------

$routesWithServicesTs = @'
import express from "express";
import multer from "multer";
import path from "path";
import {
  createImportJob,
  getImportJobById,
  getImportJobs,
  updateImportJob
} from "../db/database";
import { extractTextFromFile } from "../services/fileExtractor.service";
import { generateRunbookMarkdown } from "../services/aiMarkdown.service";
import { redactSecrets } from "../services/secretRedaction.service";
import { publishToGithub } from "../services/githubPublisher.service";

const router = express.Router();

const uploadDir = process.env.UPLOAD_DIR || "./uploads";

const upload = multer({
  dest: uploadDir,
  limits: {
    fileSize: 10 * 1024 * 1024
  }
});

router.post("/import", upload.single("file"), async (req, res) => {
  let jobId: number | undefined;

  try {
    const file = req.file;

    if (!file) {
      return res.status(400).json({
        success: false,
        message: "File is required"
      });
    }

    const commandText = req.body.commandText || "Đưa nội dung này về kho";
    const mode = (req.body.mode || "review") as "review" | "publish";
    const createdBy = req.body.createdBy || "system";

    jobId = createImportJob({
      originalFileName: file.originalname,
      fileType: path.extname(file.originalname).toLowerCase(),
      fileSize: file.size,
      commandText,
      status: "UPLOADED",
      createdBy
    });

    const extractedText = await extractTextFromFile(file.path, file.originalname);

    updateImportJob(jobId, {
      status: "EXTRACTED"
    });

    const generated = await generateRunbookMarkdown({
      originalFileName: file.originalname,
      textContent: extractedText,
      commandText
    });

    const safeMarkdown = redactSecrets(generated.markdown);
    const markdownPath = `docs/${generated.category}/${generated.fileName}`;

    updateImportJob(jobId, {
      status: "GENERATED",
      title: generated.title,
      category: generated.category,
      fileName: generated.fileName,
      markdownPath,
      generatedMarkdown: safeMarkdown,
      generatedJson: JSON.stringify(generated)
    });

    const githubResult = await publishToGithub({
      mode,
      category: generated.category,
      navTitle: generated.navTitle,
      markdownPath,
      markdownContent: safeMarkdown
    });

    const finalStatus = mode === "publish" ? "PUBLISHED" : "PR_CREATED";

    updateImportJob(jobId, {
      status: finalStatus,
      gitBranch: githubResult.branch,
      pullRequestUrl: githubResult.pullRequestUrl,
      commitSha: githubResult.commitSha,
      publishUrl: githubResult.publishUrl
    });

    return res.json({
      success: true,
      jobId,
      title: generated.title,
      category: generated.category,
      markdownPath,
      pullRequestUrl: githubResult.pullRequestUrl,
      publishUrl: githubResult.publishUrl,
      status: finalStatus
    });
  } catch (error: any) {
    if (jobId) {
      updateImportJob(jobId, {
        status: "FAILED",
        errorMessage: error.message
      });
    }

    return res.status(500).json({
      success: false,
      jobId,
      message: error.message
    });
  }
});

router.get("/imports", (_req, res) => {
  const jobs = getImportJobs();

  res.json({
    success: true,
    data: jobs
  });
});

router.get("/imports/:id", (req, res) => {
  const id = Number(req.params.id);
  const job = getImportJobById(id);

  if (!job) {
    return res.status(404).json({
      success: false,
      message: "Import job not found"
    });
  }

  return res.json({
    success: true,
    data: job
  });
});

export default router;
'@

Set-Content -Path "src\routes\knowledge.routes.ts" -Value $routesWithServicesTs -Encoding UTF8
Write-Host "Updated src/routes/knowledge.routes.ts with real services" -ForegroundColor Green

# -----------------------------
# Update package.json scripts
# -----------------------------

$packageJson = Get-Content "package.json" -Raw | ConvertFrom-Json

$packageJson.scripts = [PSCustomObject]@{
    dev = "tsx watch src/app.ts"
    build = "rimraf dist && tsc"
    start = "node dist/app.js"
}

$packageJson | ConvertTo-Json -Depth 20 | Set-Content "package.json" -Encoding UTF8
Write-Host "Updated package.json scripts" -ForegroundColor Green

Write-Host ""
Write-Host "Runbook AI Publisher initialized successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next commands:" -ForegroundColor Yellow
Write-Host "cd `"$ProjectPath`""
Write-Host "npm run dev"
Write-Host ""
Write-Host "Health check:" -ForegroundColor Yellow
Write-Host "http://localhost:5055/health"
Write-Host ""
Write-Host "Important:" -ForegroundColor Yellow
Write-Host "Update .env with OPENAI_API_KEY and GITHUB_TOKEN before calling /api/knowledge/import"
