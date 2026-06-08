import express from "express";
import multer from "multer";
import path from "path";
import {
  createImportJob,
  getImportJobById,
  getImportJobs,
  updateImportJob,
} from "../db/database";
import { extractMarkdownFromFile } from "../services/fileExtractor.service";
import { generateRunbookMarkdown } from "../services/aiMarkdown.service";
import { redactSecrets } from "../services/secretRedaction.service";
import { publishToGithub } from "../services/githubPublisher.service";
import {
  allowedCategories,
  categoryTitles,
  normalizeCategoryInput,
} from "../config/categories";

const router = express.Router();

const uploadDir = process.env.UPLOAD_DIR || "./uploads";

const upload = multer({
  dest: uploadDir,
  limits: {
    fileSize: 10 * 1024 * 1024,
  },
});

router.post("/import", upload.single("file"), async (req, res) => {
  let jobId: number | undefined;

  try {
    const file = req.file;

    if (!file) {
      return res.status(400).json({
        success: false,
        message: "File is required",
      });
    }

    const commandText = req.body.commandText || "Đưa nội dung này về kho";
    const mode = normalizeMode(req.body.mode);
    const createdBy = req.body.createdBy || "system";

    const convertOnly = req.body.convertOnly === "true";
    const dryRun = req.body.dryRun === "true";

    const preferredCategory = normalizeCategoryInput(req.body.category);

    jobId = createImportJob({
      originalFileName: file.originalname,
      fileType: path.extname(file.originalname).toLowerCase(),
      fileSize: file.size,
      commandText,
      status: "UPLOADED",
      createdBy,
    });

    const rawMarkdown = await extractMarkdownFromFile(
      file.path,
      file.originalname
    );

    updateImportJob(jobId, {
      status: "EXTRACTED",
      generatedMarkdown: rawMarkdown,
    });

    if (convertOnly) {
      return res.json({
        success: true,
        jobId,
        mode,
        category: preferredCategory || "auto",
        convertOnly: true,
        status: "EXTRACTED",
        originalFileName: file.originalname,
        markdownLength: rawMarkdown.length,
        markdownPreview: rawMarkdown.substring(0, 3000),
        message: "File converted to raw Markdown successfully.",
      });
    }

    const generated = await generateRunbookMarkdown({
      originalFileName: file.originalname,
      textContent: rawMarkdown,
      commandText,
      preferredCategory,
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
      generatedJson: JSON.stringify(generated),
    });

    if (dryRun) {
      return res.json({
        success: true,
        jobId,
        mode,
        dryRun: true,
        status: "GENERATED",
        title: generated.title,
        category: generated.category,
        categoryTitle: categoryTitles[generated.category] || generated.category,
        fileName: generated.fileName,
        navTitle: generated.navTitle,
        markdownPath,
        markdownLength: safeMarkdown.length,
        markdownPreview: safeMarkdown.substring(0, 5000),
        tags: generated.tags,
        message:
          "Runbook Markdown generated successfully. GitHub publish skipped because dryRun=true.",
      });
    }

    const githubResult = await publishToGithub({
      mode,
      category: generated.category,
      navTitle: generated.navTitle,
      markdownPath,
      markdownContent: safeMarkdown,
    });

    const finalStatus = mode === "publish" ? "PUBLISHED" : "PR_CREATED";

    updateImportJob(jobId, {
      status: finalStatus,
      gitBranch: githubResult.branch,
      pullRequestUrl: githubResult.pullRequestUrl,
      commitSha: githubResult.commitSha,
      publishUrl: githubResult.publishUrl,
    });

    return res.json({
      success: true,
      jobId,
      mode,
      status: finalStatus,
      title: generated.title,
      category: generated.category,
      categoryTitle: categoryTitles[generated.category] || generated.category,
      fileName: generated.fileName,
      markdownPath,
      pullRequestUrl: githubResult.pullRequestUrl,
      publishUrl: githubResult.publishUrl,
      message:
        mode === "publish"
          ? "Runbook published successfully."
          : "Runbook Pull Request created successfully.",
    });
  } catch (error: any) {
    if (jobId) {
      updateImportJob(jobId, {
        status: "FAILED",
        errorMessage: error.message,
      });
    }

    return res.status(500).json({
      success: false,
      jobId,
      message: error.message,
    });
  }
});

router.get("/categories", (_req, res) => {
  return res.json({
    success: true,
    data: allowedCategories.map((category) => ({
      value: category,
      label: categoryTitles[category] || category,
    })),
  });
});

router.get("/imports", (_req, res) => {
  const jobs = getImportJobs();

  return res.json({
    success: true,
    data: jobs,
  });
});

router.get("/imports/:id", (req, res) => {
  const id = Number(req.params.id);
  const job = getImportJobById(id);

  if (!job) {
    return res.status(404).json({
      success: false,
      message: "Import job not found",
    });
  }

  return res.json({
    success: true,
    data: job,
  });
});

function normalizeMode(mode: string | undefined): "review" | "publish" {
  if (mode === "publish") {
    return "publish";
  }

  return "review";
}

export default router;