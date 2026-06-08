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
