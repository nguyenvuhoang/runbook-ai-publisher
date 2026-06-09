import "dotenv/config";
import express from "express";
import cors from "cors";
import morgan from "morgan";
import path from "path";
import knowledgeRoutes from "./routes/knowledge.routes";

const app = express();

app.use(cors());
app.use(morgan("dev"));
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

app.use(express.static(path.join(process.cwd(), "public")));

app.get("/health", (_req, res) => {
  res.json({
    success: true,
    message: "Runbook AI Publisher is running",
    openaiConfigured: Boolean(process.env.OPENAI_API_KEY),
    githubConfigured: Boolean(process.env.GITHUB_TOKEN),
    markitdownConfigured: Boolean(process.env.MARKITDOWN_COMMAND),
  });
});

app.use("/api/knowledge", knowledgeRoutes);

app.get("/", (_req, res) => {
  res.sendFile(path.join(process.cwd(), "public", "index.html"));
});

const port = process.env.PORT || 5055;

app.listen(port, () => {
  console.log(`Runbook AI Publisher is running on port ${port}`);
});