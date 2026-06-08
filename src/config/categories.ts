export const allowedCategories = [
  "ubuntu",
  "docker",
  "nginx",
  "cloudflare",
  "sqlserver",
  "git",
  "errors",
  "tools",
];

export const categoryTitles: Record<string, string> = {
  ubuntu: "Ubuntu",
  docker: "Docker",
  nginx: "Nginx",
  cloudflare: "Cloudflare",
  sqlserver: "SQL Server",
  git: "Git",
  errors: "Errors",
  tools: "Tools",
};

export function normalizeCategoryInput(category?: string): string | undefined {
  if (!category) {
    return undefined;
  }

  const value = category.toLowerCase().trim();

  if (!value || value === "auto") {
    return undefined;
  }

  if (!allowedCategories.includes(value)) {
    throw new Error(
      `Invalid category: ${category}. Allowed categories: ${allowedCategories.join(", ")}`,
    );
  }

  return value;
}
