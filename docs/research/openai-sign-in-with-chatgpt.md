# Research: the ChatGPT subscription through Sign in with ChatGPT

Date: 2026-10-27. Source: the official documentation [developers.openai.com/siwc](https://developers.openai.com/siwc/quickstart), the rest from secondary reviews.

## What it is

At DevDay on 2026-09-29 OpenAI launched Sign in with ChatGPT. An app gets an OAuth token and spends the user's subscription limits instead of an API key.

- Who can use it: open-source and locally run apps, self-serve, with no application, client secret or partner API key. Paid or remotely hosted apps submit an [interest form](https://openai.com/form/sign-in-with-chatgpt-interest/). Our personal app on our own Mac falls under the first option.
- The user's plan: Plus or Pro.
- Control: the user sets a weekly limit for the app. Once it's used up, requests stop and nothing is charged.
- Data: the app gets only the name, email and avatar. It has no access to ChatGPT conversations or memory.

## Protocol (local app)

1. Store a stable `ext_agent_host_id`, for example `urn:uuid:…`, with no user data.
2. Start a loopback listener at `http://127.0.0.1:<port>/auth/callback`.
3. Open `https://auth.openai.com/api/accounts/authorize` in the system browser with the parameters:
   - `client_id=dynamic_agent_client` (on the first sign-in), `agent_name_hint=<app name>`, `ext_agent_host_id`;
   - `response_type=code`, `redirect_uri`, `resource=https://api.openai.com/v1`;
   - `scope=openid profile email offline_access resource.invoke chatgpt.tokens.use.direct`;
   - `state`, `nonce`, `code_challenge` (S256).
4. Callback: check `state`. Store the issued `client_id` (`oaiapp_…`) and use it for later sign-ins.
5. `POST https://auth.openai.com/api/accounts/oauth/token` (authorization_code + `code_verifier`).
6. Verify the ID token (JWKS, `iss`, `aud`, `exp`, `nonce`) and that the scope includes `chatgpt.tokens.use.direct`.
7. Store the tokens atomically (in our case, Keychain). The refresh token rotates: on refresh, replace it together with the access token.

## Calling the model

- `POST https://api.openai.com/v1/responses`, `Authorization: Bearer <access token>`.
- `store: false` and `stream: true` (SSE) are required. Success only after `response.completed`.
- Model list: `GET /v1/models` with the same token, take `visibility: "list"`. The documentation examples use `gpt-6.1-sol`. Checked 2026-11-01: the response is `{"models": [...]}`, about 670 KB; a model has `slug`, `display_name`, `description`, `visibility` (`list`/`hide`), `priority`, `input_modalities` and other fields. Cyrano doesn't call it: the model list is fixed and changes with releases ([02](../specs/02-tech-decisions.md) M1).
- Unsupported: `previous_response_id` (we send the whole dialog history in `input`), `system` items (`instructions` instead), `temperature`, `max_output_tokens`, `metadata` and others, as well as built-in tools (file search, code interpreter, image generation).
- Image input depends on the model. Structured outputs aren't mentioned in the limitations; that needs checking.
- Limit errors arrive in the middle of the stream: `subscription_sharing_usage_limit_exceeded`, `subscription_sharing_usage_unavailable`.

## The unofficial path (we don't use it)

Before DevDay, third-party tools reused `codex login` tokens and the `chatgpt.com/backend-api` endpoints. That's a gray area under OpenAI's terms, and such solutions break regularly. The documentation explicitly says not to use `backend-api`.

## Estimate for us

| Work | Estimate |
|---|---|
| OAuth PKCE + loopback (Network.framework) + Keychain + refresh | ~1 day |
| Responses API client with SSE, parsing events and limit errors | ~0.5 day |
| `CloudEngine` behind the shared engine interface, moving the prompts | ~0.5 day |
| An eval run on the cloud model | a few hours |

In total, 2–3 days to a working prototype. The alternative is an API key with pay-per-token billing: integration in a couple of hours, but it's a separate bill on top of the subscription.

## Consequences for the architecture

- Message text and context go to OpenAI (`store: false`, but processing happens on their servers). For the cloud mode this is a deliberate departure from "local only".
- The cloud engine doesn't need the 4096-token limits, compaction or Apple's guided generation. The engine interface should hide these differences.
- Needed: a sign-in screen ("Continue with ChatGPT" per OpenAI's guidelines), limit status, signing out, a fallback local engine on a limit error or without network.

## Sources

- [Quickstart](https://developers.openai.com/siwc/quickstart)
- [Open-source: Sign in](https://developers.openai.com/siwc/token-sharing-open-source/sign-in.md)
- [Models and inference](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference)
- [Preview limitations](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations)
- [The New Stack](https://thenewstack.io/sign-in-with-chatgpt/), [WorkOS](https://workos.com/blog/sign-in-with-chatgpt-plan-usage-scope) — launch reviews
