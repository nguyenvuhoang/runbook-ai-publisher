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
