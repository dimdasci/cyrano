# Documentation

| Document | Contents | Status |
|---|---|---|
| [specs/02-tech-decisions.md](specs/02-tech-decisions.md) | Stack, authorization, model, text capture, storage, tests | agreed |
| [specs/03-mvp-scope.md](specs/03-mvp-scope.md) | Scenarios, settings, MVP acceptance criteria | agreed |
| [specs/04-prompts.md](specs/04-prompts.md) | Pipeline, built-in prompts, model choice, eval | agreed |
| [specs/05-ui.md](specs/05-ui.md) | Screens, chat panel, states, keyboard, Settings, HIG review | agreed |
| [plan.md](plan.md) | MVP broken down into work packages, what's done, the next package, deviations from the spec | in progress |
| [quality.md](quality.md) | Code quality checks: `scripts/check`, tools, thresholds | accepted |
| [releases.md](releases.md) | Version and build number, changelog and release notes, releasing, `main` protection, distribution | accepted |
| [style.md](style.md) | Writing style: voice, formatting rules | accepted |
| [wireframes/](wireframes/) | Wireframes of all screens and how to use them in development | agreed |
| [research/openai-sign-in-with-chatgpt.md](research/openai-sign-in-with-chatgpt.md) | Sign in with ChatGPT: protocol, limitations, assessment | accepted |

Reading order for development: 03 (what we build) → 02 (how) → 05 + wireframes (what it looks like) → 04 (what we send to the model). What's already done and what to do next is in [plan.md](plan.md), section [Next](plan.md#next). Before writing docs, read [style.md](style.md).

The specs are numbered from 02: 01 was the historical draft of implementation and UX options written for a local model; it was removed on 2026-11-05 and stays in git history.

Eval cases for testing prompts live in [`/evals`](../evals/): fixes in `evals/fix/`, context reading in `evals/context/`; the runner is `cyrano-eval` in `CyranoCore`.
