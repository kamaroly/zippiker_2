# AI assistant: setup and operations

The assistant (sidebar **Assistant**, the **Ask AI** button, or ⌘K → type a question → Enter)
needs an AI provider. There are two ways to give it one, and a workspace's own choice wins:

1. **Bring your own AI (per workspace, no server access needed).** An admin opens
   **Settings → AI assistant**, picks a provider and model, pastes the company's API key and
   clicks **Save** (then **Test connection**). Supported:

   | Provider | API used | Where to get a key | Example model |
   |---|---|---|---|
   | Anthropic Claude | Messages API | platform.claude.com → Settings → API keys | `claude-opus-5-5` |
   | OpenAI (ChatGPT) | Chat Completions | platform.openai.com/api-keys | `gpt-5` |
   | xAI Grok | OpenAI-compatible | console.x.ai | `grok-4` |
   | Google Gemini | OpenAI-compatible endpoint | aistudio.google.com/apikey | `gemini-2.5-pro` |
   | Other | Any OpenAI-compatible base URL (OpenRouter, a local Ollama…) | your provider | your choice |

   The example models are only suggestions; type any model your account can use (check the
   provider's model list). Pick a strong model with good tool use. Keys are encrypted at rest
   (AES-GCM, see `Zippiker.Assistant.Vault`); only the last four characters are ever shown.
   Changing the provider later keeps the saved key unless you paste a new one.

2. **A server-wide default (Anthropic).** Set `ANTHROPIC_API_KEY` on the server (below).
   Every workspace without its own provider uses it, billed to whoever owns that key.

Without either, the app works normally and the assistant page shows "isn't switched on yet".

End-user instructions are in the app under **Help → AI assistant**
(`lib/zippiker_web/live/help_articles/ai_assistant.html.heex`).

The rest of this page covers the server-wide default.

## 1. Get an API key

1. Sign in at <https://platform.claude.com> (create an organization if you don't have one).
2. Add billing under **Settings → Billing**. The assistant is billed per use.
3. Go to **Settings → API keys → Create key**. Name it e.g. `zippiker-production`.
4. Copy the key (it starts with `sk-ant-`). It's shown once; store it in your password manager.

Use separate keys for development and production so you can revoke one without the other.

## 2. Give the key to Zippiker

The key is read from environment variables at boot (`config/runtime.exs`):

| Variable | Required | Default | What it does |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | yes | none | The API key. |
| `ANTHROPIC_MODEL` | no | `claude-opus-5-5` | The Claude model to use. |
| `ANTHROPIC_EFFORT` | no | `medium` | How hard Claude thinks: `low`, `medium`, `high`, `xhigh` or `max`. Higher is slower and costs more. |
| `AI_KEYS_SECRET` | no | `TOKEN_SIGNING_SECRET` | Secret used to encrypt workspace API keys. If it changes, workspaces must re-enter their keys. |

### Development (your machine)

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
mix phx.server
```

To avoid exporting it every time, put it in a file that git ignores, e.g. `.env`:

```bash
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> .env
echo '.env' >> .gitignore      # once
source .env && mix phx.server
```

Never commit the key.

### Production

Set `ANTHROPIC_API_KEY` wherever the app's other secrets (`DATABASE_URL`, `SECRET_KEY_BASE`,
`TOKEN_SIGNING_SECRET`) are set, then restart the app:

- **Fly.io:** `fly secrets set ANTHROPIC_API_KEY=sk-ant-...` (restarts automatically)
- **Docker / docker compose:** add `ANTHROPIC_API_KEY` to the service's `environment:` or env file
- **systemd:** `Environment=ANTHROPIC_API_KEY=sk-ant-...` in the unit (or an `EnvironmentFile=`)
- **Release started by hand:** `ANTHROPIC_API_KEY=sk-ant-... PHX_SERVER=true bin/zippiker start`

Runtime config is read at boot, so a restart is needed after changing it.

### Check it works

Open `/assistant`. The "isn't switched on yet" card should be gone and the model name
shows under the message box. Ask "Who owes us money?"; you should see "Searched…" /
"Ran the … report" lines, then an answer.

If you see an error instead:

| Message | Fix |
|---|---|
| "The Anthropic API key was rejected" | Wrong or revoked key; create a new one. |
| "busy (rate limited)" | Too many requests for your plan; wait, or raise limits in the Claude Console. |
| "returned an error (400): …" | Usually a model name your account can't use; unset `ANTHROPIC_MODEL`. |
| "Couldn't reach the AI service" | The server can't reach `api.anthropic.com:443`; check firewalls/proxies. |

## 3. Who can use and configure it

Choosing the provider and key needs an admin, or a role with **Choose the AI provider and
API key** (included in the IT support role).


Owners and admins always can. Members need a role with the permission
**Use the AI assistant** (Settings → Roles & permissions → Reports section). New
workspaces include it in Team member, Employee, Sales rep, Sales manager, Purchasing officer,
Accountant and HR manager. Workspaces created before the assistant existed need an admin to tick
it on their roles (or click **Reset** on a built-in role).

## 4. What it can do, and the safety model

The assistant runs every tool **as the signed-in user** through the normal Ash actions, so
policies and roles apply exactly as in the UI.

- **Read tools (run immediately):** search records, open a record, list and run standard
  reports, link to a page.
- **Write tools (only after the user clicks Approve):** add a contact, lead or task, log an
  activity, create a **draft** quote or invoice, log time.
- It can't issue, send, pay, approve, void or delete anything.

Conversations are kept in the browser session only (not stored in the database); reloading the
page starts a new chat. Questions and the data the tools return are sent to Anthropic to
produce answers; see Anthropic's commercial terms and data retention settings in the Claude
Console.

## 5. Costs

Each question makes several API calls (one per tool step). Watch spend in the Claude Console
(**Usage**), and set a monthly limit there. To spend less, set `ANTHROPIC_EFFORT=low` or point
`ANTHROPIC_MODEL` at a smaller model such as `claude-sonnet-5-5`.

## 6. Code map

| File | Role |
|---|---|
| `lib/zippiker/assistant/llm.ex` | Picks the workspace's provider or the server default; dispatches |
| `lib/zippiker/assistant/claude.ex` | Anthropic adapter (`POST /v1/messages`) |
| `lib/zippiker/assistant/openai_compatible.ex` | OpenAI / Grok / Gemini adapter: translates to and from Chat Completions |
| `lib/zippiker/assistant/providers.ex` | Provider list (labels, base URLs, suggested models) |
| `lib/zippiker/assistant/ai_settings*` | Per-workspace provider, model and encrypted key |
| `lib/zippiker/assistant/engine.ex` | The turn loop, approval pause, system prompt |
| `lib/zippiker/assistant/tools.ex` | Tool definitions and implementations |
| `lib/zippiker/assistant/conversation*` | Ash generic actions (`reply`, `resolve`, `status`) and the policy |
| `lib/zippiker_web/live/assistant_live.*` | The chat page |

To add a tool: add its definition to `Tools.definitions/0`, a `do_run/3` clause, and, if it
changes data, its name to `@writes` and a `describe/3` clause for the approval card.

The conversation is kept in the Anthropic Messages format; the OpenAI-compatible adapter
translates it on every request. Anthropic requests use adaptive thinking, automatic prompt
caching and, on models that support it, server-side refusal fallbacks (`fallbacks: "default"`):
if Claude declines a turn on safety grounds, the API retries it on a fallback model within the
same call. To add a provider with an OpenAI-compatible API, add it to `Providers`; for a
different API, write an adapter with `create(cfg, system, tools, messages)` returning
`{:ok, %{"content" => blocks, "stop_reason" => ...}}` and dispatch to it in `LLM.create/4`.
