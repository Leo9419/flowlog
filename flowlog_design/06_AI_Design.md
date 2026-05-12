# AI Integration Design

Goal: introduce AI capabilities without breaking the local-first UX, with a switchable local/cloud provider model and an optional backend path.

## 1. Principles
- Switchable providers: local or cloud at any time.
- Minimal context: only send the required fields.
- Safe writes: preview changes before applying.

## 2. Provider Model
### 2.1 Local Model (Ollama)
- Call a local Ollama HTTP service on the device.
- Default endpoint: http://localhost:11434
- Use /api/generate with format=json for task parsing.
- Best for quick add and lightweight summaries.

### 2.2 Cloud Model (OpenAI Compatible)
- Directly call OpenAI-compatible endpoints.
- Supports text parsing, image parsing, AI chat, and weekly report generation.
- Backend path reserved for future auth/rate-limit control.

### 2.3 Switching
- Settings allow Local / Cloud selection at any time.
- Text quick add and weekly report can use local or cloud.
- Image quick add and AI chat are cloud-only.

## 3. Client Settings
- Settings > AI Settings
- Stored config:
  - `ai_provider`: `local` or `cloud`
  - `ai_local_endpoint`: base URL for local service
  - `ai_local_model`: model name (for Ollama)
  - `ai_cloud_endpoint`: OpenAI-compatible base URL
  - `ai_cloud_api_key`: API key
  - `ai_cloud_model`: model name

## 4. Text Quick Add (Local/Cloud)
- Quick add dialog exposes an "AI parse" action.
- LLM returns JSON: `title`, `due_date`, `is_all_day`, `notes`, `tags`.
- Preview changes before applying to the database.

## 5. Image Quick Add (Cloud Only)
- User selects an image; optional hint text is included.
- Model returns the same JSON schema as text quick add.
- If multiple tasks are present, one becomes the title and the rest go into notes.

## 6. AI Chat (Cloud Only)
- Use local tasks as read-only context.
- Send a trimmed task list (title, due, tags, notes) and recent chat history.
- AI replies in user language; no writes to DB.

## 7. AI Reports (Local/Cloud)
- Triggered from AI chat quick actions (weekly/monthly/yearly).
- Build a structured payload from the selected range.
- Model returns a short, readable summary.

## 8. Backend Placeholders
- `POST /ai/parse`: parse natural language tasks
- `POST /ai/summary`: weekly summaries
- Return structured JSON for preview and apply.

## 9. Privacy
- User confirmation for writes.
- Cloud uses minimal fields.
- AI can be disabled at any time.
