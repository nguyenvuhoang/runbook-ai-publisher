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
