# Fix eval

Cases for Fix, Explain and the dialog ([04 §5](../../docs/specs/04-prompts.md)). Each case goes through the full flow, as in the panel: the check (Fix, then Explain), then the dialog turns, where the model replies to each message with a new version or an answer, as in the panel. The runner calls the same code as the panel (`ProofreadingSession.check` and `send`) and keeps no copies of the prompts.

Run from the repository root (build with `swift build --package-path Packages/CyranoCore --product cyrano-eval`):

```bash
Packages/CyranoCore/.build/debug/cyrano-eval fix evals/fix/cases.json gpt-6.1-sol > evals/private/fix-runs/gpt-6.1-sol.md
```

Without a model argument it uses the default check model (`gpt-6.1-sol`); the model from the argument does the check, the explanations and the dialog. The runner checks four cases at a time, so a run of the whole set takes two and a half to three and a half minutes (measured 2026-11-06); the report keeps the order of the cases. The first run after a build asks for access to Cyrano's Keychain item. Don't run the eval and the app at the same time, or two evals at once: each refreshes the token.

## A case

```json
{
  "id": "real-04-reply-to-ravi",
  "source": "real",
  "textType": "message", "tone": "neutral", "level": "fluency", "language": "sameAsText",
  "customInstructions": "",
  "context": "Ravi: Hi Alex, when you were off last week…",
  "dictionary": ["Quick"],
  "text": "…",
  "criteria": ["`this PRs` → `these PRs`", "`today's 420` is a corruption"],
  "turns": [{ "message": "Is this polite?", "criteria": ["an answer, no new version"] }],
  "notes": "…",
  "heldOut": true
}
```

- `source`: `real` is the user's message (names changed), `synthetic` is a made-up case. The real ones are a reality check: if results on them are noticeably worse than on the synthetic ones, the synthetic set is too easy.
- The panel header options are the `rawValue`s from `CheckOptions`; a missing field means the default (Message · Neutral · Fluency · Same as Text). `context` is the Context field, `dictionary` is the "Never change" dictionary.
- `criteria` describe in words what should come out: which error is fixed, what must stay intact, which variants are correct. They describe the outcome and leave the wording open: any correct variant passes.
- `notes` record decisions on disputed points, so we don't argue about them again next time. Write "decided" only for what the user decided.
- `heldOut: true` marks a case we never tune the prompts on: it only checks that a general rule holds on words the prompt hasn't seen. The report shows it as "held out". A rule is accepted only if it passes the held-out cases.

## Report and grading

The runner doesn't score the cases; it prints a Markdown report: the options, the Context, the text, each version with its number and its changes as "before → after", category and explanation, each dialog message and what came of it (a version or an answer), time and tokens, then the criteria. A failed call shows as `**ERROR**`, and the case ends there. Reports go to `evals/private/fix-runs/` (outside git).

The agent that ran the eval grades it: it reads the reports of all models side by side, case by case, and marks each as passed or failed with a reason. Disputed cases are settled with the user, and the decision goes into `notes`. The result is the table in 04 §5.

General rules on top of the case criteria. Only clear errors, no nuances:

- Fix: the error is fixed; correct text is left intact and the meaning unchanged; the output language comes from the pop-up, and with Same as Text it's the language of the text; Context isn't copied into the text.
- Explain: every change has an explanation; errors and matters of taste aren't mixed up (a change to correct text is `style`, a fix of an error is some other category); the explanation isn't made up.
- Dialog: the reply's kind fits the message, and the panel does what the user expects:
  - a request ("rewrite", "update", "apply", "translate", "add…") — a new version where the request is done;
  - a clarification (the context, who it's addressed to, what a word means) — a new version that takes the clarification into account and changes only what it affects; an "understood" answer without a version is a failure;
  - a question about the text ("polite?", "why did you replace it?", "what's wrong?") — an answer, the text doesn't change; the answer addresses the question instead of repeating the text;
  - a question that sounds like a correction ("how do I say more precisely that…", "isn't it too confident? I'm not sure we'll make it") — either a new version or an answer with a variant the user will then apply is fine;
  - a message that names a version ("take version 2 and…") or the original — a new version that starts from it, and keeps its language;
  - the first check of a text that is itself a question or a request — a version: the check can't answer.
- real-06 is a negative example from a real conversation: after a clarification the model replaced the user's words with the colleague's, and the user asked why. A version after a clarification keeps the author's words.
