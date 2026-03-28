import http from "node:http";
import { loadLocalEnv } from "./load-env.js";
import { EnrichmentWorker } from "./services/enrichment-worker.js";

loadLocalEnv();

const worker = new EnrichmentWorker();
const port = Number(process.env.PORT || 8080);

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === "POST" && req.url === "/v1/captures") {
      const chunks = [];
      for await (const chunk of req) {
        chunks.push(chunk);
      }

      const payload = JSON.parse(Buffer.concat(chunks).toString("utf8"));
      const result = await worker.enrich({
        id: payload.id,
        source_url: payload.sourceURL,
        source_app: payload.sourceApp,
        raw_text: payload.rawText
      });

      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify(result));
      return;
    }

    if (req.method === "POST" && /^\/v1\/place-drafts\/.+\/(confirm|reject)$/.test(req.url || "")) {
      res.writeHead(204);
      res.end();
      return;
    }

    if (req.method === "GET" && req.url === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify(worker.healthStatus()));
      return;
    }

    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Not found" }));
  } catch (error) {
    const statusCode = error.code === "PROVIDER_UNAVAILABLE" ? 503 : 500;
    res.writeHead(statusCode, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        error: error.message,
        code: error.code ?? "INTERNAL_ERROR",
        provider: error.provider ?? null
      })
    );
  }
});

server.listen(port, () => {
  console.log(`bagged worker listening on ${port}`);
});
