import { DirectHtmlReader } from "../readers/direct-html-reader.js";
import { FirecrawlReader } from "../readers/firecrawl-reader.js";
import { PlaceExtractor } from "./place-extractor.js";
import { CaptureStatus } from "../types/index.js";
import { getWorkerConfiguration } from "../config.js";

export class EnrichmentWorker {
  constructor({
    primaryReader = new DirectHtmlReader(),
    fallbackReader = new FirecrawlReader(),
    configuration = getWorkerConfiguration(),
    extractor = new PlaceExtractor()
  } = {}) {
    this.primaryReader = primaryReader;
    this.fallbackReader = fallbackReader;
    this.configuration = configuration;
    this.extractor = extractor;
  }

  async enrich(capture) {
    const document = await this.loadDocument(capture);
    const proposals = await this.extractor.extract(capture, document);
    if (proposals.length === 0) {
      throw new Error(`No places found in ${capture.source_url ?? "this capture"}.`);
    }

    return {
      captureId: capture.id,
      status: proposals.length > 1 ? CaptureStatus.NEEDS_REVIEW : CaptureStatus.PARTIALLY_RESOLVED,
      proposals
    };
  }

  healthStatus() {
    return {
      status: "ok",
      providers: this.configuration
    };
  }

  async loadDocument(capture) {
    if (!capture.source_url) {
      if (!capture.raw_text?.trim()) {
        throw new Error("Capture does not include a source URL or OCR text");
      }

      return this.buildRawTextDocument(capture.raw_text);
    }

    const readers = [this.primaryReader, this.fallbackReader].filter(Boolean);
    let lastError = null;

    for (const reader of readers) {
      try {
        const document = await reader.read(capture.source_url);
        this.validateDocument(document, capture);
        if (this.isUsableDocument(document)) {
          return this.mergeRawText(document, capture.raw_text);
        }
      } catch (error) {
        lastError = error;
      }
    }

    if (capture.raw_text?.trim()) {
      return this.buildRawTextDocument(capture.raw_text);
    }

    if (lastError) {
      throw lastError;
    }

    throw new Error(`Unable to read ${capture.source_url}: no parser returned usable content`);
  }

  isUsableDocument(document) {
    if (Array.isArray(document?.metadata?.places) && document.metadata.places.length > 0) {
      return true;
    }

    return (document?.markdown?.trim()?.length ?? 0) >= 120;
  }

  buildRawTextDocument(rawText) {
    const text = rawText?.trim() ?? "";
    return {
      provider: "raw-text",
      markdown: text,
      excerpt: text.split("\n").map((line) => line.trim()).filter(Boolean).slice(0, 2).join(" "),
      metadata: {
        title: null,
        description: null,
        language: null
      }
    };
  }

  mergeRawText(document, rawText) {
    const text = rawText?.trim();
    if (!text) {
      return document;
    }

    return {
      ...document,
      markdown: [document.markdown, text].filter(Boolean).join("\n\n"),
      excerpt: document.excerpt || text
    };
  }

  validateDocument(document, capture) {
    const statusCode = Number(document?.metadata?.statusCode);
    if (!Number.isNaN(statusCode) && statusCode >= 400) {
      throw new Error(`Unable to import ${capture.source_url}: the page returned HTTP ${statusCode}.`);
    }

    const title = String(document?.metadata?.title ?? "").toLowerCase();
    const excerpt = String(document?.excerpt ?? "").toLowerCase();
    if (/page not found|not found|404/.test(title) && /page not found|not found|404/.test(excerpt)) {
      throw new Error(`Unable to import ${capture.source_url}: the page appears to be missing.`);
    }
  }
}
