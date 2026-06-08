import OpenAI from "openai";
import slugify from "slugify";
import { allowedCategories } from "../config/categories";

export interface GenerateRunbookMarkdownInput {
  originalFileName: string;
  textContent: string;
  commandText: string;
  preferredCategory?: string;
}

export interface GeneratedRunbookDocument {
  title: string;
  category: string;
  fileName: string;
  navTitle: string;
  markdown: string;
  tags: string[];
}

export async function generateRunbookMarkdown(
  input: GenerateRunbookMarkdownInput
): Promise<GeneratedRunbookDocument> {
  const apiKey = process.env.OPENAI_API_KEY;

  if (!apiKey) {
    throw new Error("OPENAI_API_KEY is missing in .env");
  }

  const client = new OpenAI({
    apiKey,
  });

  const model = process.env.OPENAI_MODEL || "gpt-5.2";
  const prompt = buildPrompt(input);

  const response = await client.responses.create({
    model,
    input: prompt,
  });

  const outputText = response.output_text;

  if (!outputText || outputText.trim().length === 0) {
    throw new Error("OpenAI returned empty response");
  }

  const parsed = parseJsonOutput(outputText);

  validateGeneratedDocument(parsed);

  parsed.category = input.preferredCategory
    ? input.preferredCategory
    : normalizeCategory(parsed.category);

  parsed.fileName = normalizeFileName(parsed.fileName || parsed.title);
  parsed.navTitle = parsed.navTitle || parsed.title;
  parsed.tags = Array.isArray(parsed.tags) ? parsed.tags : [];

  return parsed;
}

function buildPrompt(input: GenerateRunbookMarkdownInput): string {
  const allowedCategoryText = allowedCategories.join(", ");

  const categoryInstruction = input.preferredCategory
    ? `The user selected this category: ${input.preferredCategory}. You must use this category exactly.`
    : `The user did not select a category. Choose exactly one category from: ${allowedCategoryText}.`;

  return `
You are the AI Knowledge Publisher for a MkDocs Runbook Knowledge Base.

The user uploaded a file. It has already been converted to raw Markdown by MarkItDown.
Your job is to rewrite it into a clean, practical runbook Markdown document.

User command:
${input.commandText}

Original file name:
${input.originalFileName}

Category instruction:
${categoryInstruction}

Allowed categories:
${allowedCategoryText}

Rules:
1. Return JSON only. Do not wrap it in markdown code fences.
2. Choose exactly one category from the allowed categories.
3. Write a clear technical runbook.
4. Preserve important information from the uploaded content.
5. Remove duplicated or noisy text.
6. Keep commands copy-paste friendly.
7. Do not include real passwords, tokens, private keys, API keys, or sensitive credentials.
8. If a sensitive value appears, replace it with a safe placeholder.
9. Generate a lowercase kebab-case fileName ending with .md.
10. The markdown should be ready to save under docs/{category}/{fileName}.

Required JSON format:
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

Raw Markdown content:
${input.textContent}
`;
}

function parseJsonOutput(outputText: string): GeneratedRunbookDocument {
  let jsonText = outputText.trim();

  if (jsonText.startsWith("```json")) {
    jsonText = jsonText
      .replace(/^```json/i, "")
      .replace(/```$/i, "")
      .trim();
  }

  if (jsonText.startsWith("```")) {
    jsonText = jsonText
      .replace(/^```/i, "")
      .replace(/```$/i, "")
      .trim();
  }

  try {
    return JSON.parse(jsonText);
  } catch (error: any) {
    throw new Error(`Failed to parse OpenAI JSON output: ${error.message}`);
  }
}

function validateGeneratedDocument(doc: any): void {
  if (!doc.title) {
    throw new Error("Generated document title is missing");
  }

  if (!doc.category) {
    throw new Error("Generated document category is missing");
  }

  if (!doc.markdown) {
    throw new Error("Generated document markdown is missing");
  }

  if (!Array.isArray(doc.tags)) {
    doc.tags = [];
  }
}

function normalizeCategory(category: string): string {
  const value = String(category || "").toLowerCase().trim();

  if (allowedCategories.includes(value)) {
    return value;
  }

  return "tools";
}

function normalizeFileName(value: string): string {
  const name = slugify(value.replace(/\.md$/i, ""), {
    lower: true,
    strict: true,
    trim: true,
  });

  return `${name || "imported-runbook"}.md`;
}