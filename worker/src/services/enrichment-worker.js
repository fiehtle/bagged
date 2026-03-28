import { FirecrawlReader } from "../readers/firecrawl-reader.js";
import { PlaceExtractor } from "./place-extractor.js";
import { CaptureStatus } from "../types/index.js";
import { getWorkerConfiguration } from "../config.js";

export class EnrichmentWorker {
  constructor({
    reader = new FirecrawlReader(),
    configuration = getWorkerConfiguration(),
    extractor = new PlaceExtractor()
  } = {}) {
    this.reader = reader;
    this.configuration = configuration;
    this.extractor = extractor;
  }

  async enrich(capture) {
    const document = await this.loadDocument(capture);
    const proposals = await this.extractor.extract(capture, document);
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

    try {
      const document = await this.reader.read(capture.source_url);
      if (this.isUsableDocument(document)) {
        return this.mergeRawText(document, capture.raw_text);
      }
    } catch (error) {
      if (capture.raw_text?.trim()) {
        return this.buildRawTextDocument(capture.raw_text);
      }

      throw error;
    }

    if (capture.raw_text?.trim()) {
      return this.buildRawTextDocument(capture.raw_text);
    }

    throw new Error(`Unable to read ${capture.source_url}: Firecrawl returned empty content`);
  }

  isUsableDocument(document) {
    return Boolean(document?.markdown?.trim());
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
}
