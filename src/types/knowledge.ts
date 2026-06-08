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
