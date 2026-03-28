export class ProviderUnavailableError extends Error {
  constructor(provider, message) {
    super(message);
    this.name = "ProviderUnavailableError";
    this.provider = provider;
    this.code = "PROVIDER_UNAVAILABLE";
  }
}

function parseBoolean(value, defaultValue = false) {
  if (value == null || value === "") {
    return defaultValue;
  }

  return ["1", "true", "yes", "on"].includes(String(value).trim().toLowerCase());
}

export function getWorkerConfiguration(env = process.env) {
  return {
    allowMockProviders: parseBoolean(env.BAGGED_ALLOW_MOCK_PROVIDERS, false),
    firecrawl: {
      configured: Boolean(env.BAGGED_FIRECRAWL_API_KEY),
      baseURL: env.BAGGED_FIRECRAWL_BASE_URL || "https://api.firecrawl.dev/v1"
    },
    openai: {
      configured: Boolean(env.BAGGED_OPENAI_API_KEY || env.OPENAI_API_KEY),
      baseURL: env.BAGGED_OPENAI_BASE_URL || "https://api.openai.com/v1",
      model: env.BAGGED_OPENAI_MODEL || "gpt-5-mini"
    }
  };
}
