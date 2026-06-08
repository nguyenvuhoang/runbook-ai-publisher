import "dotenv/config";
import express from "express";
import cors from "cors";
import morgan from "morgan";
import knowledgeRoutes from "./routes/knowledge.routes";

const app = express();

app.use(cors());
app.use(morgan("dev"));
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

app.get("/", (_req, res) => {
  res.json({
    success: true,
    name: "Runbook AI Publisher",
    version: "1.0.0",
    endpoints: {
      health: "/health",
      import: "POST /api/knowledge/import",
      imports: "GET /api/knowledge/imports",
    },
  });
});

app.get("/health", (_req, res) => {
  res.json({
    success: true,
    message: "Runbook AI Publisher is running",
    openaiConfigured: Boolean(process.env.OPENAI_API_KEY),
    markitdownConfigured: Boolean(process.env.MARKITDOWN_COMMAND),
  });
});

app.use("/api/knowledge", knowledgeRoutes);

const port = process.env.PORT || 5055;

app.listen(port, () => {
  console.log(`Runbook AI Publisher is running on port ${port}`);
});