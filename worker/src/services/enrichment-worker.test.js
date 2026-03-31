import test from "node:test";
import assert from "node:assert/strict";
import { EnrichmentWorker } from "./enrichment-worker.js";
import { PlaceExtractor } from "./place-extractor.js";

test("returns multiple proposals from the generic extractor for list-style pages", async () => {
  const worker = new EnrichmentWorker({
    reader: {
      async read() {
        return {
          provider: "stub",
          excerpt: "The best restaurants in San Francisco",
          markdown: "# Best Restaurants\n## The Shota\n## Trestle\n## Pinhole Coffee",
          metadata: {
            title: "The Best Restaurants in San Francisco",
            description: "A city guide",
            language: "en"
          }
        };
      }
    },
    extractor: {
      async extract() {
        return [
          { id: crypto.randomUUID(), title: "The Shota", category: "food", notes: "Omakase", addressLine: null, city: "San Francisco", neighborhood: null, confidence: 0.87, sourceExcerpt: "Guide" },
          { id: crypto.randomUUID(), title: "Trestle", category: "food", notes: "Pasta", addressLine: null, city: "San Francisco", neighborhood: null, confidence: 0.83, sourceExcerpt: "Guide" },
          { id: crypto.randomUUID(), title: "Pinhole Coffee", category: "coffee", notes: "Coffee", addressLine: null, city: "San Francisco", neighborhood: null, confidence: 0.8, sourceExcerpt: "Guide" }
        ];
      }
    }
  });

  const result = await worker.enrich({
    id: "capture-1",
    source_url: "https://example.com/best-restaurants",
    raw_text: null
  });

  assert.equal(result.status, "needs_review");
  assert.deepEqual(result.proposals.map((proposal) => proposal.title), ["The Shota", "Trestle", "Pinhole Coffee"]);
});

test("uses OCR text when no URL is provided", async () => {
  const worker = new EnrichmentWorker({
    extractor: {
      async extract(capture, document) {
        assert.equal(capture.source_url, null);
        assert.match(document.markdown, /Pinhole Coffee/);
        return [
          {
            id: crypto.randomUUID(),
            title: "Pinhole Coffee",
            category: "coffee",
            notes: "Neighborhood coffee stop",
            addressLine: "231 Cortland Ave",
            city: "San Francisco",
            neighborhood: null,
            confidence: 0.78,
            sourceExcerpt: "Pinhole Coffee 231 Cortland Ave"
          }
        ];
      }
    }
  });

  const result = await worker.enrich({
    id: "capture-2",
    source_url: null,
    raw_text: "Pinhole Coffee\n231 Cortland Ave\nSan Francisco, CA"
  });

  assert.equal(result.proposals.length, 1);
  assert.equal(result.proposals[0].title, "Pinhole Coffee");
});

test("falls back to raw text when Firecrawl fails but OCR text exists", async () => {
  const worker = new EnrichmentWorker({
    reader: {
      async read() {
        throw new Error("Firecrawl unavailable");
      }
    },
    extractor: {
      async extract(capture, document) {
        assert.equal(capture.source_url, "https://example.com/post");
        assert.equal(document.provider, "raw-text");
        return [
          {
            id: crypto.randomUUID(),
            title: "Ocean Subs",
            category: "food",
            notes: "Recovered from OCR",
            addressLine: "18 Ocean Ave",
            city: "San Francisco",
            neighborhood: "Excelsior",
            confidence: 0.71,
            sourceExcerpt: "Ocean Subs 18 Ocean Ave"
          }
        ];
      }
    }
  });

  const result = await worker.enrich({
    id: "capture-3",
    source_url: "https://example.com/post",
    raw_text: "Ocean Subs\n18 Ocean Ave\nSan Francisco, CA"
  });

  assert.equal(result.proposals[0].title, "Ocean Subs");
});

test("reports provider readiness in health status", () => {
  const worker = new EnrichmentWorker({
    configuration: {
      allowMockProviders: false,
      firecrawl: { configured: true, baseURL: "https://api.firecrawl.dev/v1" },
      openai: { configured: true, baseURL: "https://api.openai.com/v1", model: "gpt-5-mini" }
    }
  });

  assert.deepEqual(worker.healthStatus(), {
    status: "ok",
    providers: {
      allowMockProviders: false,
      firecrawl: { configured: true, baseURL: "https://api.firecrawl.dev/v1" },
      openai: { configured: true, baseURL: "https://api.openai.com/v1", model: "gpt-5-mini" }
    }
  });
});

test("fails loudly when no live reader is configured and no OCR text is available", async () => {
  const worker = new EnrichmentWorker();

  await assert.rejects(
    worker.enrich({
      id: "capture-4",
      source_url: "https://example.com/no-config",
      raw_text: null
    }),
    /BAGGED_FIRECRAWL_API_KEY is not set|Unable to read https:\/\/example\.com\/no-config/
  );
});

test("fails clearly when the scraped page returns an HTTP error", async () => {
  const worker = new EnrichmentWorker({
    reader: {
      async read() {
        return {
          provider: "stub",
          excerpt: "Page Not Found",
          markdown: "# Page Not Found",
          metadata: {
            title: "Page Not Found",
            description: "Missing page",
            language: "en",
            statusCode: 404
          }
        };
      }
    }
  });

  await assert.rejects(
    worker.enrich({
      id: "capture-404",
      source_url: "https://example.com/missing",
      raw_text: null
    }),
    /returned HTTP 404/
  );
});

test("parses structured places from the OpenAI extractor", async () => {
  const extractor = new PlaceExtractor({
    apiKey: "test-key",
    model: "gpt-5-mini",
    fetchImpl: async () => ({
      ok: true,
      async json() {
        return {
          output: [
            {
              type: "message",
              content: [
                {
                  type: "output_text",
                  text: JSON.stringify({
                    content_pattern: "single_place_review",
                    places: [
                      {
                        title: "Ocean Subs",
                        category: "food",
                        notes: "A strong sandwich shop in Excelsior.",
                        addressLine: "18 Ocean Ave, San Francisco, California 94112",
                        city: "San Francisco",
                        neighborhood: "Excelsior",
                        confidence: 0.95
                      }
                    ]
                  })
                }
              ]
            }
          ]
        };
      }
    })
  });

  const proposals = await extractor.extract(
    { source_url: "https://example.com/ocean-subs", raw_text: null },
    {
      markdown: "# Ocean Subs",
      excerpt: "A sandwich shop in Excelsior",
      metadata: { title: "Ocean Subs", description: "Review", language: "en" }
    }
  );

  assert.equal(proposals.length, 1);
  assert.equal(proposals[0].title, "Ocean Subs");
  assert.equal(proposals[0].addressLine, "18 Ocean Ave, San Francisco, California 94112");
});
