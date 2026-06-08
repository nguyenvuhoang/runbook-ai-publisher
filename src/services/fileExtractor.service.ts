import fs from "fs/promises";
import path from "path";
import { execFile } from "child_process";
import { promisify } from "util";

const execFileAsync = promisify(execFile);

const supportedTextExtensions = [
  ".txt",
  ".md",
  ".json",
  ".yml",
  ".yaml",
  ".html",
  ".csv",
  ".xml",
];

export async function extractMarkdownFromFile(
  filePath: string,
  originalFileName: string
): Promise<string> {
  const ext = path.extname(originalFileName).toLowerCase();

  if (supportedTextExtensions.includes(ext)) {
    const content = await fs.readFile(filePath, "utf-8");

    if (ext === ".md") {
      return content;
    }

    return [
      `# Imported content from ${originalFileName}`,
      "",
      "```txt",
      content,
      "```",
    ].join("\n");
  }

  return await convertFileToMarkdownByMarkItDown(filePath, originalFileName);
}

async function convertFileToMarkdownByMarkItDown(
  filePath: string,
  originalFileName: string
): Promise<string> {
  const markitdownCommand = process.env.MARKITDOWN_COMMAND || "markitdown";
  const timeout = Number(process.env.MARKITDOWN_TIMEOUT_MS || 120000);

  const ext = path.extname(originalFileName).toLowerCase();

  // Multer creates uploaded files without extension.
  // MarkItDown works better when the temp file has the original extension.
  const workingFilePath = ext ? `${filePath}${ext}` : filePath;

  try {
    if (workingFilePath !== filePath) {
      await fs.copyFile(filePath, workingFilePath);
    }

    const { stdout, stderr } = await execFileAsync(
      markitdownCommand,
      [workingFilePath],
      {
        timeout,
        maxBuffer: 50 * 1024 * 1024,
        encoding: "utf8",
        env: {
          ...process.env,

          // Important for Vietnamese / Unicode output on Windows
          PYTHONIOENCODING: "utf-8",
          PYTHONUTF8: "1",
        },
      }
    );

    if (stderr && stderr.trim().length > 0) {
      console.warn("MarkItDown stderr:", stderr);
    }

    if (!stdout || stdout.trim().length === 0) {
      throw new Error("MarkItDown returned empty Markdown content");
    }

    return stdout;
  } catch (error: any) {
    throw new Error(
      `Failed to convert file to Markdown by MarkItDown: ${error.message}`
    );
  } finally {
    if (workingFilePath !== filePath) {
      try {
        await fs.unlink(workingFilePath);
      } catch {
        // Ignore cleanup error
      }
    }
  }
}