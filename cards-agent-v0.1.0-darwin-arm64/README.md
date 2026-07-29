# Cards Agent binary handoff

This bundle runs the Cards Agent backend locally. It contains no API key and does not require Go or Node.js.

## Bundle contents

- `cards-agent` or `cards-agent.exe`: platform-specific backend
- `frontend-contract.json`: versioned, framework-neutral frontend contract
- `fixtures/`: AG-UI event and verification fixtures for component tests
- `frontend-handoff.md`: detailed integration and acceptance-test guide

## Start in deterministic mode

Deterministic mode exercises the real ADK runner, AG-UI stream, tools, sessions, interrupts, MPIN verification, and REST middleware without calling Gemini.

macOS or Linux:

```bash
chmod +x ./cards-agent

AGENT_MODE=scripted \
BACKEND_ADDR=127.0.0.1:8080 \
CORS_ALLOWED_ORIGINS=http://localhost:3000 \
./cards-agent
```

Windows PowerShell:

```powershell
$env:AGENT_MODE = "scripted"
$env:BACKEND_ADDR = "127.0.0.1:8080"
$env:CORS_ALLOWED_ORIGINS = "http://localhost:3000"
.\cards-agent.exe
```

Replace `http://localhost:3000` with the frontend development server's exact origin. Multiple origins are comma-separated.

## Start with Gemini

Supply your own Gemini key at runtime. Never add it to frontend configuration, source control, screenshots, or test fixtures.

macOS or Linux:

```bash
AGENT_MODE=gemini \
GOOGLE_API_KEY='your-key' \
GEMINI_MODEL=gemini-flash-latest \
BACKEND_ADDR=127.0.0.1:8080 \
CORS_ALLOWED_ORIGINS=http://localhost:3000 \
./cards-agent
```

Windows PowerShell:

```powershell
$env:AGENT_MODE = "gemini"
$env:GOOGLE_API_KEY = "your-key"
$env:GEMINI_MODEL = "gemini-flash-latest"
$env:BACKEND_ADDR = "127.0.0.1:8080"
$env:CORS_ALLOWED_ORIGINS = "http://localhost:3000"
.\cards-agent.exe
```

## Frontend endpoints

Use `http://127.0.0.1:8080` as the local base URL:

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/api/agui` | AG-UI run input and SSE event stream |
| `POST` | `/api/confirmations/verify` | Out-of-band MPIN verification |
| `GET` | `/api/frontend-contract` | Runtime copy of the frontend contract |
| `GET` | `/api/cards` | Current demo user's card projection |
| `GET` | `/healthz` | Health and configured agent mode |

Send a stable, unique `X-Demo-User` header from the frontend. The default development MPIN is `4291`.

## Smoke test

After starting the binary:

```bash
curl --fail http://127.0.0.1:8080/healthz
curl --fail http://127.0.0.1:8080/api/frontend-contract
```

Check the binary version:

```bash
./cards-agent --version
```

## Frontend behavior

- Render cards from `STATE_SNAPSHOT`, not assistant text.
- Treat `TOOL_CALL_RESULT` as structured tool data, not a chat message.
- A `RUN_FINISHED` interrupt for `block_card` opens the approval component.
- Verify MPIN only through `/api/confirmations/verify`.
- On an incorrect MPIN, keep the approval open, mark the field invalid, show the returned error inline, and allow retry.
- Put only the returned one-time confirmation token in the resolved `resume[]` payload.
- Never put the MPIN in AG-UI messages, state, context, resume payloads, analytics, logs, or browser storage.

See `frontend-handoff.md` and `frontend-contract.json` for the complete contract.

## Runtime configuration

| Variable | Default | Description |
| --- | --- | --- |
| `AGENT_MODE` | `scripted` | `scripted` or `gemini` |
| `BACKEND_ADDR` | `:8080` | HTTP listen address |
| `CORS_ALLOWED_ORIGINS` | local Vite origins | Comma-separated exact frontend origins |
| `GOOGLE_API_KEY` | none | Required only in Gemini mode |
| `GEMINI_MODEL` | `gemini-flash-latest` | Gemini model name |
| `DEMO_MPIN` | `4291` | Local demonstration MPIN |

## Development limitations

- Identity is a demo `X-Demo-User` header, not production authentication.
- Sessions, cards, confirmation attempts, and tokens are held in memory.
- Restarting the process resets all state.
- The local MPIN mechanism is for UI integration only.
- Bind to `127.0.0.1` unless remote access is explicitly required.

If a hosted HTTPS frontend cannot call the local HTTP service because of browser private-network policy, expose this local process through an authenticated HTTPS tunnel instead.
