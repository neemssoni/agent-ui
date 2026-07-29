# Frontend handoff: Cards Agent

This document is the UI team’s contract with the agent service. The frontend may use any framework. It should not depend on Go code or ADK internals.

## Canonical contract

- Runtime manifest: `GET /api/frontend-contract`
- Checked-in manifest: [`internal/api/frontend-contract.json`](../internal/api/frontend-contract.json)
- Component fixtures: [`frontend/fixtures/`](../frontend/fixtures)
- Reference client: [`frontend/src/App.tsx`](../frontend/src/App.tsx)
- Browser acceptance tests: [`frontend/tests/banking.spec.ts`](../frontend/tests/banking.spec.ts)

Treat `contractVersion` as the frontend compatibility version. Breaking changes require a new major version and coordinated rollout.

## Agent tools versus UI components

The two server-executed **agent tools** are:

| Tool | Input | Result | Confirmation |
| --- | --- | --- | --- |
| `list_cards` | `{}` | `{ cards: Card[] }` | No |
| `block_card` | `{ last_four: "4242" }` | `{ card: Card, status: "blocked" }` | Yes |

These tools execute in ADK on the backend. The frontend must not execute them or fabricate `TOOL_CALL_RESULT` events.

Recommended **UI components** are:

| Component | Required states |
| --- | --- |
| `MessageList` | empty, streaming assistant text, complete, error |
| `MessageComposer` | empty, ready, submitting, disabled during interrupt |
| `AgentRunStatus` | idle, running, interrupted, failed |
| `CardList` | empty/not loaded, loaded, status changed |
| `CardStatusBadge` | active, blocked |
| `ToolActivity` | tool started, arguments available, completed; optional to display |
| `BlockCardApproval` | open, verifying, invalid MPIN, too many attempts, expired, cancelled, resolved |
| `MPINInput` | empty, four digits, invalid, disabled |
| `InlineError` | field error inside approval; run-level error near conversation |

Unsupported in contract v1: frontend-executed tools, attachments, voice, transactions, add/replace card, and multiple simultaneous interrupts.

## AG-UI events the frontend must handle

| Event | Frontend behavior |
| --- | --- |
| `RUN_STARTED` | Mark the agent run as active. |
| `STATE_SNAPSHOT` | Replace the complete frontend state. Render `snapshot.cards`; do not infer card state from model text. |
| `TOOL_CALL_START` | Optionally show tool activity using `toolCallId` and `toolCallName`. |
| `TOOL_CALL_ARGS` | Accumulate the JSON argument string by `toolCallId`. |
| `TOOL_CALL_END` | Mark arguments complete. This does **not** mean the tool action succeeded. |
| `TOOL_CALL_RESULT` | Associate the result with the original `toolCallId`. Do not render raw result JSON as an assistant message. |
| `TEXT_MESSAGE_START` | Create one assistant message using `messageId`. |
| `TEXT_MESSAGE_CONTENT` | Append `delta` exactly; do not add spaces. |
| `TEXT_MESSAGE_END` | Mark the assistant message complete. |
| `RUN_FINISHED success` | Mark the run idle and clear resolved interrupts. |
| `RUN_FINISHED interrupt` | Store every interrupt and open the approval UI. Contract v1 emits at most one. |
| `RUN_ERROR` | Mark the run failed and show a run-level error. |

`list_cards` normally produces both structured state and a short final assistant message. This is expected: ADK executes the tool and then gives the model a final turn. The card UI must use `STATE_SNAPSHOT`; the sentence is conversational acknowledgement only.

## Block-card approval sequence

1. The agent calls `block_card`.
2. ADK pauses the tool before its handler mutates state.
3. AG-UI finishes the run with:

   ```json
   {
     "outcome": {
       "type": "interrupt",
       "interrupts": [
         {
           "id": "interrupt-id",
           "reason": "tool_call",
           "toolCallId": "original-block-tool-call-id",
           "metadata": { "toolName": "block_card", "lastFour": "4242" }
         }
       ]
     }
   }
   ```

4. Open `BlockCardApproval`. Keep the card active.
5. To approve, verify MPIN out of band:

   ```http
   POST /api/confirmations/verify
   Content-Type: application/json
   X-Demo-User: current-user

   {
     "threadId": "current-thread",
     "interruptId": "interrupt-id",
     "mpin": "four digits"
   }
   ```

6. For HTTP `401`, keep the approval open, set `aria-invalid=true`, show the returned message **inside the approval**, and allow retry.
7. On HTTP `200`, send a new AG-UI run:

   ```json
   {
     "resume": [
       {
         "interruptId": "interrupt-id",
         "status": "resolved",
         "payload": {
           "confirmationToken": "one-time-token"
         }
       }
     ]
   }
   ```

8. To cancel, skip MPIN verification and send:

   ```json
   {
     "resume": [
       {
         "interruptId": "interrupt-id",
         "status": "cancelled"
       }
     ]
   }
   ```

Never put MPIN in AG-UI messages, state, context, `resume[]`, analytics, logs, or browser persistence. Only the one-time confirmation token belongs in the resolved resume payload.

## Verification error behavior

| HTTP | Expected UX |
| --- | --- |
| `400` | Inline validation error; keep approval open when recoverable. |
| `401` | Incorrect MPIN; mark field invalid, show message, allow retry. |
| `403` | Identity/thread mismatch; close approval and require a new authenticated session. |
| `404` | Interrupt missing or expired; close approval and ask the user to start again. |
| `429` | Too many attempts; keep explanation visible and disable further confirmation. |

Run-level errors from `/api/agui` are separate from MPIN field errors.

## Build independently against the reference backend

Start only the deterministic backend, allowing the frontend team’s local origin:

```bash
cd use-cases/adk-agui-banking

AGENT_MODE=scripted \
BACKEND_ADDR=127.0.0.1:8080 \
CORS_ALLOWED_ORIGINS=http://localhost:3000 \
GOWORK=off \
go run ./cmd/server
```

Then point any frontend at:

- AG-UI endpoint: `http://127.0.0.1:8080/api/agui`
- Contract manifest: `http://127.0.0.1:8080/api/frontend-contract`
- MPIN verification: `http://127.0.0.1:8080/api/confirmations/verify`
- Demo identity header: `X-Demo-User: frontend-developer`

The scripted backend uses the same ADK runner, tools, session lifecycle, interrupts, and REST middleware as Gemini mode; only the LLM is deterministic.

## Minimum acceptance tests

1. Initial wallet is not loaded.
2. “Show my cards” renders two cards from `STATE_SNAPSHOT` and a short assistant acknowledgement.
3. “Block card 4242” opens an approval and leaves the card active.
4. Confirm is disabled until four digits are entered.
5. Incorrect MPIN displays inline, keeps the modal open, and leaves the card active.
6. Editing the MPIN clears the old field error.
7. Correct MPIN resolves the exact interrupt and changes card 4242 to blocked.
8. Cancel resolves with `status: cancelled` and leaves the card active.
9. Raw tool JSON is never rendered as assistant text.
10. A different user cannot reuse another user’s thread or confirmation token.

Use the JSON files under `frontend/fixtures/` for isolated Storybook, unit, or component tests. Run `npm --prefix frontend run test:e2e` for the reference end-to-end behavior.
