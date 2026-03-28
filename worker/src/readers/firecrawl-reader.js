import { getWorkerConfiguration, ProviderUnavailableError } from "../config.js";

export class FirecrawlReader {
  constructor({
    apiKey = process.env.BAGGED_FIRECRAWL_API_KEY,
    baseURL = process.env.BAGGED_FIRECRAWL_BASE_URL || "https://api.firecrawl.dev/v1",
    allowMockProviders = getWorkerConfiguration().allowMockProviders
  } = {}) {
    this.apiKey = apiKey;
    this.baseURL = baseURL;
    this.allowMockProviders = allowMockProviders;
  }

  async read(url) {
    if (!this.apiKey) {
      if (this.allowMockProviders) {
        return {
          provider: "firecrawl-mock",
          markdown: `# Mock import\n\nSource: ${url}`,
          excerpt: `Fallback Firecrawl mock for ${url}`
        };
      }

      throw new ProviderUnavailableError("firecrawl", "BAGGED_FIRECRAWL_API_KEY is not set");
    }

    const response = await fetch(`${this.baseURL}/scrape`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`
      },
      body: JSON.stringify({
        url,
        formats: ["markdown"],
        onlyMainContent: true
      })
    });

    if (!response.ok) {
      throw new Error(`Firecrawl scrape failed: ${response.status}`);
    }

    const payload = await response.json();
    return {
      provider: "firecrawl",
      markdown: payload.data?.markdown ?? "",
      excerpt: payload.data?.metadata?.description ?? payload.data?.metadata?.title ?? "",
      metadata: {
        title: payload.data?.metadata?.title ?? null,
        description: payload.data?.metadata?.description ?? null,
        language: payload.data?.metadata?.language ?? null
      }
    };
  }
}
