# AI assistant: setup and operations

The assistant (sidebar **Assistant**, the **Ask AI** button, or ⌘K → type a question → Enter)
talks to Anthropic's Claude API. It needs one secret: an **Anthropic API key**. Without it
the app works normally and the assistant page shows "isn't switched on yet".

End-user instructions are in the app under **Help → AI assistant**
(`lib/zippiker_web/live/help_articles/ai_assistant.html.heex`).

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
| `ANTHROPIC_EFFORT` | no | `medium` | How hard the model thinks: `low`, `medium`, `high`, `xhigh` or `max`. Higher is slower and costs more. |

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

## 3. Who can use it

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
| `lib/zippiker/assistant/claude.ex` | HTTP calls to `POST /v1/messages` (Req), config, error messages |
| `lib/zippiker/assistant/engine.ex` | The turn loop, approval pause, system prompt |
| `lib/zippiker/assistant/tools.ex` | Tool definitions and implementations |
| `lib/zippiker/assistant/conversation*` | Ash generic actions (`reply`, `resolve`, `status`) and the policy |
| `lib/zippiker_web/live/assistant_live.*` | The chat page |

To add a tool: add its definition to `Tools.definitions/0`, a `do_run/3` clause, and, if it
changes data, its name to `@writes` and a `describe/3` clause for the approval card.

Requests use adaptive thinking, automatic prompt caching and server-side refusal fallbacks
(`fallbacks: "default"`): if Claude declines a turn on safety grounds, the API retries it on a
fallback model within the same call.
