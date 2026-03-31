import { Readability } from "@mozilla/readability";
import { JSDOM } from "jsdom";

const DEFAULT_USER_AGENT =
  "Mozilla/5.0 (compatible; bagged/0.1; +https://github.com/fiehtle/bagged)";

const PLACE_TYPE_PATTERNS = [
  "place",
  "localbusiness",
  "foodestablishment",
  "restaurant",
  "cafeorcoffeeshop",
  "barorpub",
  "bakery",
  "icecreamshop",
  "fastfoodrestaurant",
  "touristattraction",
  "museum",
  "artgallery",
  "park",
  "store"
];

export class DirectHtmlReader {
  constructor({
    fetchImpl = fetch,
    userAgent = DEFAULT_USER_AGENT,
    timeoutMs = 8000
  } = {}) {
    this.fetchImpl = fetchImpl;
    this.userAgent = userAgent;
    this.timeoutMs = timeoutMs;
  }

  async read(url) {
    const response = await this.fetchImpl(url, {
      method: "GET",
      redirect: "follow",
      headers: {
        Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "User-Agent": this.userAgent
      },
      signal: AbortSignal.timeout(this.timeoutMs)
    });

    const html = await response.text();
    const dom = new JSDOM(html, { url: response.url });
    const document = dom.window.document;

    const metadata = {
      title: contentForMeta(document, [
        'meta[property="og:title"]',
        'meta[name="twitter:title"]'
      ]) || document.title || null,
      description: contentForMeta(document, [
        'meta[name="description"]',
        'meta[property="og:description"]',
        'meta[name="twitter:description"]'
      ]) || null,
      language: document.documentElement.getAttribute("lang") || null,
      statusCode: response.status,
      finalURL: response.url,
      contentType: response.headers.get("content-type") || null,
      places: extractSchemaPlaces(document)
    };

    const readable = new Readability(document, { charThreshold: 120 }).parse();
    const readableText =
      normalizeWhitespace(renderedContentToText(readable?.content) || readable?.textContent || extractBodyText(dom.window.document.body));
    const excerpt =
      normalizeWhitespace(readable?.excerpt) ||
      metadata.description ||
      firstSentence(readableText) ||
      null;

    return {
      provider: "direct-html",
      markdown: readableText,
      excerpt,
      metadata
    };
  }
}

function contentForMeta(document, selectors) {
  for (const selector of selectors) {
    const value = document.querySelector(selector)?.getAttribute("content")?.trim();
    if (value) {
      return value;
    }
  }

  return null;
}

function extractBodyText(body) {
  return normalizeWhitespace(body?.textContent || "");
}

function renderedContentToText(html) {
  if (!html) {
    return "";
  }

  const fragment = JSDOM.fragment(html);
  const parts = [];
  walkNode(fragment, parts);
  return parts.join("\n").replace(/\n{3,}/g, "\n\n").trim();
}

function walkNode(node, parts) {
  for (const child of node.childNodes ?? []) {
    if (child.nodeType === 3) {
      const text = normalizeWhitespace(child.textContent || "");
      if (text) {
        parts.push(text);
      }
      continue;
    }

    if (child.nodeType !== 1) {
      continue;
    }

    const tagName = child.tagName?.toLowerCase() || "";
    if (["script", "style", "noscript"].includes(tagName)) {
      continue;
    }

    const isBlock = ["p", "div", "section", "article", "aside", "header", "footer", "li", "ul", "ol", "h1", "h2", "h3", "h4", "blockquote"].includes(tagName);
    if (isBlock && parts.length > 0 && parts[parts.length - 1] !== "\n") {
      parts.push("\n");
    }

    walkNode(child, parts);

    if (isBlock && parts.length > 0 && parts[parts.length - 1] !== "\n") {
      parts.push("\n");
    }
  }
}

function normalizeWhitespace(text) {
  return String(text || "")
    .replace(/\u00a0/g, " ")
    .replace(/[ \t]{2,}/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .split("\n")
    .map((line) => line.trim())
    .join("\n")
    .trim();
}

function firstSentence(text) {
  const sentence = text.split(/(?<=[.!?])\s+/).find(Boolean);
  return sentence ? sentence.slice(0, 240) : null;
}

function extractSchemaPlaces(document) {
  const rawNodes = [];
  for (const script of document.querySelectorAll('script[type="application/ld+json"]')) {
    const json = script.textContent?.trim();
    if (!json) {
      continue;
    }

    try {
      collectSchemaNodes(JSON.parse(json), rawNodes);
    } catch {
      continue;
    }
  }

  const places = [];
  const seen = new Set();

  for (const node of rawNodes) {
    if (!isPlaceSchema(node?.["@type"])) {
      continue;
    }

    const mapped = mapSchemaPlace(node);
    if (!mapped?.title) {
      continue;
    }

    const key = mapped.title.toLowerCase();
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    places.push(mapped);
  }

  return places;
}

function collectSchemaNodes(value, target) {
  if (Array.isArray(value)) {
    for (const item of value) {
      collectSchemaNodes(item, target);
    }
    return;
  }

  if (!value || typeof value !== "object") {
    return;
  }

  if (value["@type"]) {
    target.push(value);
  }

  for (const nestedValue of Object.values(value)) {
    collectSchemaNodes(nestedValue, target);
  }
}

function isPlaceSchema(typeValue) {
  const types = Array.isArray(typeValue) ? typeValue : [typeValue];
  return types
    .map((value) => String(value || "").replace(/^https?:\/\/schema.org\//i, "").toLowerCase())
    .some((value) => PLACE_TYPE_PATTERNS.some((pattern) => value === pattern || value.endsWith(pattern)));
}

function mapSchemaPlace(node) {
  const address = normalizeAddress(node.address);
  const notes = cleanString(node.description)?.slice(0, 280) || null;
  const category = inferCategory(node["@type"], notes);
  const neighborhood = normalizeNeighborhood(node);

  return {
    title: cleanString(node.name) || cleanString(node.alternateName) || null,
    category,
    notes,
    addressLine: address.addressLine,
    city: address.city,
    neighborhood,
    confidence: address.addressLine ? 0.97 : 0.91
  };
}

function normalizeAddress(address) {
  if (!address) {
    return { addressLine: null, city: null };
  }

  if (typeof address === "string") {
    return { addressLine: cleanString(address), city: null };
  }

  const addressLine = [address.streetAddress, address.addressLocality, address.addressRegion, address.postalCode]
    .map(cleanString)
    .filter(Boolean)
    .join(", ") || null;

  return {
    addressLine,
    city: cleanString(address.addressLocality)
  };
}

function normalizeNeighborhood(node) {
  const candidates = [
    node.areaServed?.name,
    node.containedInPlace?.name,
    node.location?.name,
    node.address?.addressNeighborhood
  ].map(cleanString).filter(Boolean);

  return candidates[0] || null;
}

function inferCategory(typeValue, text) {
  const haystack = `${Array.isArray(typeValue) ? typeValue.join(" ") : typeValue || ""} ${text || ""}`.toLowerCase();
  if (/coffee|cafe|espresso/.test(haystack)) {
    return "coffee";
  }
  if (/bar|pub|wine|beer|cocktail/.test(haystack)) {
    return "bars";
  }
  if (/museum|gallery|theater|touristattraction|landmark/.test(haystack)) {
    return "sights";
  }
  if (/park|garden|trail|beach/.test(haystack)) {
    return "nature";
  }
  if (/store|shop|boutique|market/.test(haystack)) {
    return "shops";
  }
  if (/restaurant|food|bakery|deli|sandwich|pizza|taqueria|ramen/.test(haystack)) {
    return "food";
  }
  return "other";
}

function cleanString(value) {
  if (value == null) {
    return null;
  }

  const cleaned = String(value).replace(/\s+/g, " ").trim();
  return cleaned || null;
}
