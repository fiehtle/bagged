import { getWorkerConfiguration, ProviderUnavailableError } from "../config.js";

const PLACE_CATEGORIES = ["food", "coffee", "bars", "sights", "nature", "shops", "other"];
const CONTENT_PATTERNS = ["single_place_review", "multi_place_listicle", "social_post", "ocr_text", "unknown"];
const MAX_DOCUMENT_CHARS = 9000;

const PLACE_EXTRACTION_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    content_pattern: {
      type: "string",
      enum: CONTENT_PATTERNS
    },
    places: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          title: { type: "string", minLength: 1 },
          category: { type: "string", enum: PLACE_CATEGORIES },
          notes: { type: ["string", "null"] },
          addressLine: { type: ["string", "null"] },
          city: { type: ["string", "null"] },
          neighborhood: { type: ["string", "null"] },
          confidence: { type: "number", minimum: 0, maximum: 1 }
        },
        required: ["title", "category", "notes", "addressLine", "city", "neighborhood", "confidence"]
      }
    }
  },
  required: ["content_pattern", "places"]
};

export class PlaceExtractor {
  constructor({
    apiKey = process.env.BAGGED_OPENAI_API_KEY || process.env.OPENAI_API_KEY,
    baseURL = process.env.BAGGED_OPENAI_BASE_URL || "https://api.openai.com/v1",
    model = process.env.BAGGED_OPENAI_MODEL || "gpt-5-mini",
    allowMockProviders = getWorkerConfiguration().allowMockProviders,
    fetchImpl = fetch
  } = {}) {
    this.apiKey = apiKey;
    this.baseURL = baseURL;
    this.model = model;
    this.allowMockProviders = allowMockProviders;
    this.fetchImpl = fetchImpl;
  }

  async extract(capture, document) {
    const metadataPlaces = this.extractMetadataPlaces(document);
    if (metadataPlaces.length > 0) {
      return metadataPlaces;
    }

    if (!this.apiKey) {
      if (!this.allowMockProviders) {
        throw new ProviderUnavailableError("openai", "BAGGED_OPENAI_API_KEY is not set");
      }

      return [this.buildFallbackProposal(capture, document, 0.35)];
    }

    const response = await this.fetchImpl(`${this.baseURL}/responses`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`
      },
      body: JSON.stringify({
        model: this.model,
        store: false,
        input: this.buildPrompt(capture, document),
        text: {
          format: {
            type: "json_schema",
            name: "bagged_place_extraction",
            strict: true,
            schema: PLACE_EXTRACTION_SCHEMA
          }
        }
      })
    });

    if (!response.ok) {
      const payload = await safeJSON(response);
      const message = payload?.error?.message ?? payload?.error ?? `OpenAI responses request failed: ${response.status}`;
      throw new Error(typeof message === "string" ? message : `OpenAI responses request failed: ${response.status}`);
    }

    const payload = await response.json();
    const outputText = this.extractOutputText(payload);
    if (!outputText) {
      throw new Error("OpenAI returned no structured extraction output");
    }

    const parsed = JSON.parse(stripCodeFences(outputText));
    return this.normalizePlaces(parsed.places ?? [], capture, document);
  }

  buildPrompt(capture, document) {
    const cleanedDocument = truncate(normalizeDocument(document.markdown), MAX_DOCUMENT_CHARS);
    const source = capture.source_url ?? "OCR input";
    const contentType = capture.source_url ? "webpage" : "ocr_text";
    const pageTitle = document.metadata?.title?.trim() || firstHeading(document.markdown) || null;
    const excerpt = document.excerpt?.trim() || null;

    return [
      "You extract real-world places from a single source so they can be saved in a location app.",
      "",
      "Rules:",
      "- Return one object per distinct place that is positively recommended or clearly being reviewed.",
      "- For listicles or guides, return every distinct place mentioned as a recommendation.",
      "- For single-place reviews, return exactly one place when the page is clearly about one venue.",
      "- If the content is not clearly about one or more real places, return an empty places array.",
      "- Do not invent addresses, cities, or neighborhoods.",
      "- Deduplicate repeated mentions of the same place.",
      "- Keep notes short and factual.",
      `- Categories must be one of: ${PLACE_CATEGORIES.join(", ")}.`,
      "- Confidence should reflect extraction certainty from 0 to 1.",
      "",
      `Source type: ${contentType}`,
      `Source URL: ${source}`,
      pageTitle ? `Page title: ${pageTitle}` : null,
      excerpt ? `Excerpt: ${excerpt}` : null,
      "",
      "Content:",
      cleanedDocument
    ]
      .filter(Boolean)
      .join("\n");
  }

  extractOutputText(payload) {
    if (typeof payload.output_text === "string" && payload.output_text.trim()) {
      return payload.output_text;
    }

    const fragments = [];
    for (const item of payload.output ?? []) {
      for (const content of item.content ?? []) {
        if (typeof content.text === "string") {
          fragments.push(content.text);
        }
      }
    }

    return fragments.join("\n").trim();
  }

  extractMetadataPlaces(document) {
    const places = Array.isArray(document?.metadata?.places) ? document.metadata.places : [];
    if (places.length === 0) {
      return [];
    }

    return this.normalizePlaces(places, null, document);
  }

  normalizePlaces(places, capture, document) {
    const normalized = [];
    const seenTitles = new Set();

    for (const place of places) {
      const title = String(place.title ?? "").trim();
      if (!title) {
        continue;
      }

      const normalizedTitle = title.toLowerCase();
      if (seenTitles.has(normalizedTitle)) {
        continue;
      }
      seenTitles.add(normalizedTitle);

      normalized.push({
        id: crypto.randomUUID(),
        title,
        category: normalizeCategory(place.category),
        notes: normalizedString(place.notes),
        addressLine: normalizedString(place.addressLine),
        city: normalizedString(place.city),
        neighborhood: normalizedString(place.neighborhood),
        confidence: clampConfidence(place.confidence),
        sourceExcerpt: document.excerpt ?? document.metadata?.description ?? null
      });
    }

    return normalized;
  }

  buildFallbackProposal(capture, document, confidence) {
    const title =
      document.metadata?.title?.trim() ||
      firstHeading(document.markdown) ||
      normalizedString(capture.raw_text?.split("\n").map((line) => line.trim()).find(Boolean)) ||
      humanizeSlug(capture.source_url) ||
      "Unknown place";

    return {
      id: crypto.randomUUID(),
      title,
      category: inferCategory(`${document.excerpt ?? ""} ${document.markdown ?? ""}`),
      notes: normalizedString(document.excerpt),
      addressLine: null,
      city: null,
      neighborhood: null,
      confidence,
      sourceExcerpt: document.excerpt ?? document.metadata?.description ?? null
    };
  }
}

function normalizeDocument(markdown = "") {
  return markdown
    .replace(/!\[[^\]]*\]\([^)]+\)/g, " ")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/<[^>]+>/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/[ \t]{2,}/g, " ")
    .trim();
}

function stripCodeFences(text) {
  return text
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/, "")
    .trim();
}

function firstHeading(markdown = "") {
  return markdown
    .split("\n")
    .map((line) => line.trim())
    .find((line) => /^#\s+/.test(line))
    ?.replace(/^#\s+/, "")
    .trim() ?? null;
}

function truncate(text, maxLength) {
  if (text.length <= maxLength) {
    return text;
  }

  return `${text.slice(0, maxLength)}\n\n[TRUNCATED]`;
}

function normalizeCategory(category) {
  const value = String(category ?? "").trim().toLowerCase();
  return PLACE_CATEGORIES.includes(value) ? value : inferCategory(value);
}

function inferCategory(text) {
  if (/coffee|cafe|espresso|latte/i.test(text)) {
    return "coffee";
  }
  if (/bar|cocktail|wine|beer|pub/i.test(text)) {
    return "bars";
  }
  if (/park|hike|trail|beach|garden/i.test(text)) {
    return "nature";
  }
  if (/museum|gallery|landmark|theater|exhibit/i.test(text)) {
    return "sights";
  }
  if (/shop|store|boutique|market/i.test(text)) {
    return "shops";
  }
  if (/restaurant|sandwich|pizza|ramen|bakery|taqueria|deli|cuisine|food/i.test(text)) {
    return "food";
  }
  return "other";
}

function normalizedString(value) {
  if (value == null) {
    return null;
  }

  const trimmed = String(value).trim();
  return trimmed.length > 0 ? trimmed : null;
}

function clampConfidence(value) {
  const numeric = Number(value);
  if (Number.isNaN(numeric)) {
    return 0.5;
  }

  return Math.max(0, Math.min(1, numeric));
}

function humanizeSlug(url) {
  if (!url) {
    return null;
  }

  try {
    const slug = new URL(url).pathname.split("/").filter(Boolean).pop();
    if (!slug) {
      return null;
    }

    return slug
      .replace(/\.[a-z0-9]+$/i, "")
      .split(/[-_]+/)
      .filter(Boolean)
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(" ");
  } catch {
    return null;
  }
}

async function safeJSON(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}
