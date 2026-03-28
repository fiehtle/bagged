# bagged

`bagged` is an iPhone-first app for capturing place inspiration from links and screenshots, enriching that raw input into place drafts, and surfacing saved places nearby.

## Repo layout

- `project.yml`: XcodeGen project definition
- `Bagged/`: SwiftUI app target
- `Shared/`: shared models, persistence, and services for the app, widget, and share extension
- `BaggedShareExtension/`: share extension target
- `BaggedWidget/`: WidgetKit target
- `BaggedTests/`: XCTest target
- `worker/`: Render-friendly enrichment worker
- `supabase/`: SQL scaffold for later sync work

## Local setup

1. Generate the Xcode project:

```bash
xcodegen generate
```

2. Open `Bagged.xcodeproj` and set a signing team for the app, widget, and extension.

3. Preview mode works out of the box. Launch the app and use the `Test Lab` tab or the global `+` button to create URL and screenshot-style imports.

4. Optional live worker configuration:

- Edit `Bagged/Resources/BaggedConfig.plist`
- Set `BAGGED_API_BASE_URL` to a reachable worker URL
- Keep it blank to stay on the built-in preview importer

5. To run the worker locally:

```bash
cd worker
cp .env.example .env
node src/index.js
```

6. Optional worker environment variables:

- `BAGGED_ALLOW_MOCK_PROVIDERS=1` only if you explicitly want fake provider responses for local UI testing
- `BAGGED_FIRECRAWL_API_KEY`
- `BAGGED_FIRECRAWL_BASE_URL`
- `BAGGED_OPENAI_API_KEY`
- `BAGGED_OPENAI_BASE_URL`
- `BAGGED_OPENAI_MODEL`

## Worker architecture

- `Firecrawl` fetches and renders the shared URL into markdown.
- `OpenAI Responses API` converts that markdown into structured `place[]` output via a strict JSON schema.
- `Apple Maps` resolution still happens in the app after enrichment.
- The primary path is generic. There are no website-specific parsers in the live worker.

## First-pass test flow

1. Run the app on simulator or device.
2. Start the worker locally with valid Firecrawl and OpenAI keys.
3. Tap the global `+` button and paste a URL.
4. Confirm the generated drafts or auto-saved place.
5. Try `Screenshot OCR` from `Test Lab` to verify the OCR import path.
6. Open `Nearby` and confirm saved places sort correctly.
7. Add the widget and confirm only saved places appear.

Notes:

- Preview mode uses deterministic local coordinates so `Nearby` and the widget are testable without live place resolution.
- For simulator testing with a local worker, `http://127.0.0.1:8080` is the simplest `BAGGED_API_BASE_URL`.
- For physical devices, use a reachable HTTPS URL such as a Render deploy or a local tunnel.
- The worker now fails loudly if live provider keys are missing. Check `/health` before testing the app against a live worker.
- Live enrichment requires both `BAGGED_FIRECRAWL_API_KEY` and `BAGGED_OPENAI_API_KEY`.

## Notes

- Local app state is persisted in an App Group-backed JSON store so the app, widget, and share extension can share data in development.
- `render.yaml` is configured as a Render web service for the current HTTP-based first pass.
- The current first pass talks directly to the worker over HTTP; Supabase is not in the live path yet.
