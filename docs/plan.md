# Development plan

Status: in progress since 2026-10-27. The MVP ([03](specs/03-mvp-scope.md)) broken down into work packages, what's already done and what's next.

## Work packages

Packages are numbered as they appear; the order of work is in [Next](#next). Done means the work is finished. The check mark goes in right before the package's commit, together with the version the package will ship in. By then the version is known: it's the one after the latest tag (`git tag`). A package with no changes for the user gets a plain ✓ without a version.

| # | Package | Where | Spec | Done |
|---|---|---|---|---|
| 1 | Diff: word-level LCS, merging adjacent changes, rejecting a change | `CyranoCore/Diff` | 04 §2 | ✓ |
| 2 | Prompts: Fix, the first message, a dialog turn, Explain, the classifier, post-processing | `CyranoCore/Prompts` | 04 §4 | ✓ built-in, not editable |
| 3 | Responses API client: SSE, `usage`, limit errors, a 30 s timeout and one retry | `CyranoCore/OpenAI` | 02 M2, M6, M12, M13 | ✓ |
| 4 | Sign in with ChatGPT: PKCE, loopback, ID token, Keychain, refresh, revoke | `CyranoCore/Auth` | 02 A1–A7 | ✓ |
| 5 | Panel session: versions, Explain, question/edit, Recheck, rejecting, tokens, retry after an error | `CyranoCore/Session` | 03 S1, S1a; 02 M3–M5 | ✓ |
| 6 | Capture: AX, `AXManualAccessibility`, ⌘C with the clipboard restored, screenshot; the result only through Copy | `App/Capture` | 02 C1–C5 | ✓ |
| 7 | Panel: `NSPanel`, header, Context, the card feed, diff, the list of changes, composer, status, states | `App/Panel` | 05 §2 | ✓ |
| 8 | Menu bar, onboarding, About, the manual check window | `App` | 05 §1, §3, §4 | ✓ |
| 9 | Settings: General, Style, Account | `App/Settings` | 05 §5 | ✓ |
| 10 | The "Never change" dictionary: file, lookup in the text, context menu, Settings tab | Core + App | 02 M11; 04 §4.2; 05 §2.4, §2.7, §5 | ✓ 0.4.0 |
| 11 | Screenshot as context: ScreenCaptureKit, pasting and dragging images, `input_image` | Core + App | 02 M10; 05 §2.3a | ✓ 0.2.0 |
| 12 | Editable prompts: `prompts.json`, Settings → Prompts, Restore Default | Core + App | 02 M8; 05 §5 | — |
| 13 | Context from a screenshot: the `cyrano-eval context` runner on top of CyranoCore, a synthetic set of screenshots (dense windows, cut-off emails, other conversations nearby) and six real cases with a target context, a new context-reading prompt, the conversation's language becomes the output language, the language isn't tied to the app | Core + App + evals | 04 §4.5, §5 | ✓ 0.6.0 |
| 14 | Polish: panel height by content, TipKit, Launch at login, a per-app table in Style, a model choice for each operation (three models, without `/v1/models`), the app icon, Screen Recording in onboarding for context reading | Core + App | 02 M1; 05 §1, §2.1, §5 | ✓ 0.5.0 |
| 15 | Release pipeline: a CI build on a tag, Developer ID signing, notarization, a `.dmg` in the GitHub Release, automatic updates (Sparkle) with the same release notes | CI | [releases](releases.md) | partly: the tag and the GitHub Release with notes from `CHANGELOG.md` |
| 16 | Capture and context: capture without guessing, the text can be typed and corrected in the panel, Context is filled from the window screenshot (Luna); one action button (Check or Send), Context is input only, Quick Look on thumbnails | Core + App | 02 C2, C6; 04 §4.5; 05 §2.3a, §2.4, §2.7, §2.8, §3, §5 | ✓ 0.3.0 |
| 17 | Fix eval: `cyrano-eval fix` for Fix, Explain and the dialog on `ProofreadingSession`, 49 cases, grading by the agent from a report, three models including `gpt-6.1-terra` | `CyranoCore` + evals | 04 §5 | ✓ |
| 18 | Docs in English: README, `docs/`, the READMEs in `evals/`, CLAUDE.md, the `verify-app` skill, the PR template; the rule "project docs in Russian" becomes "everything in English"; the voice and formatting rules in [style.md](style.md) | docs | — | ✓ |
| 19 | Tuning the context-reading prompt: three models, a model recommendation for Context | Core | 04 §4.5, §5 | — |
| 20 | Tuning the Fix and dialog prompts by the package 17 eval: answering a question, clarification, meaning, names, tones | Core | 04 §4.1–4.3, §5 | — |
| 21 | Tuning Explain and the diff: optional points are `style`, changes aren't merged across a paragraph; a model recommendation for the user | Core | 04 §2, §4.4, §5 | — |
| 22 | Never Change before the check: an item in the context menu of the "Text to check" card, the term applies from the first check | App | 05 §2.4 | ✓ 0.7.0 |

## Next

Done: preview 0.1 (packages 1–9), releases are automated ([releases.md](releases.md)); package 11 — images as context; package 16 — capture without guessing and context from the window screenshot (Luna), one Check/Send button, Quick Look; package 10 — the "Never change" dictionary; package 14 — polish (panel height, tips, models per operation, the per-app table, Launch at login, the icon, Screen Recording in onboarding); package 13 — Context describes the conversation (who with, the language, what about, format, style, formality), the conversation's language goes into the language pop-up, the language is no longer tied to the app, the `cyrano-eval context` eval; package 17 — the `cyrano-eval fix` eval: 49 cases, three models, results in 04 §5, `evals/cloud-runner` removed; package 22 — Never Change in "Text to check": a term is protected before the first check; package 18 — the docs and the agent's texts are in English, the voice and formatting rules are in [style.md](style.md), the historical draft 01 is removed; the changelog and release notes for the user ([CHANGELOG.md](../CHANGELOG.md)), CI publishes the GitHub Release. On 2026-10-28 the specs were reconciled with the app: accepted deviations moved into the specs, the panel no longer has shortcuts of its own (02 T6), the rest is in [Deviations from the spec](#deviations-from-the-spec).

Order, decided 2026-10-28:

1. A working version for daily use: packages 16 → 10 → 14. The user tries the scenarios in their own routine, so every package ends with a release (`scripts/release`): 16 — 0.3.0, 10 — 0.4.0, 14 — 0.5.0. Done.
2. Quality of fixes: 13 and 17 (eval), 22 and 18 are done, next 19 → 20 → 21 → 12. 22 went first: without it a term couldn't be protected before the check, and that's a daily scenario. The translation (18) came before prompt tuning: 19–21 write to 04 and the plan, and there was no point translating their results twice. 19–21 tune the prompts one category per package, based on the evals from 13 and 17 (decided 2026-11-05: 17 only measures). 12, editable prompts, comes after tuning: by then the built-in values are final, and `prompts.json` will get the templates that may appear in 20 (for example, a separate instruction for answering a question).
3. Giving it to people: 15.

One package is one branch from a fresh `main` and one PR. A release follows if the package has changes for the user.

### Next: packages 19–21, prompt tuning

We tune the prompts one category per package, in pipeline order: context reading → fixes and the dialog → explanations. That way it's clear what exactly helped, and the time for runs and grading is split into iterations. Decided 2026-11-05.

Common to all three packages:

- Each prompt variant gets 2–3 eval runs on each of the three models (`gpt-6.1-sol`, `gpt-6-luna`, `gpt-6.1-terra`): the spread between runs is larger than the difference between models. Grading follows the same rules ([evals/fix/README.md](../evals/fix/README.md), [evals/context/README.md](../evals/context/README.md)), and the comparison is against the tables in 04 §5.
- Done when the cases the prompt was changed for pass in at least 2 runs out of 3, and the other cases show no new failures compared with 04 §5.
- The package's result is a table in 04 §5 across the three models: quality, turn time, tokens. From it, which model is best for this operation in the balance of price, quality and speed, and what we set as the default.
- If the prompt changes, a release.

#### Package 19: context reading

On the package 13 eval the prompt already passes almost everything (04 §5): Luna 13/13 and 6/6, Terra everything, but in more detail than needed and counting the channel members as recipients, Sol worse and slower. Run `cyrano-eval context` on the three models 2–3 times each, fix what repeats and confirm the default model. The material is the synthetic set and the six real cases we already have; we aren't waiting for new live screenshots, and a new situation goes into the synthetic set (decided 2026-11-05).

#### Package 20: fixes and the dialog

`cyrano-eval fix`; the Fix and dialog-turn prompts.

- Answering a question. When asked a question about the text, the model sometimes returns text instead of an answer (Sol, Terra). Hypothesis: the question goes into the same dialog where the instruction says to return only text. Test that first, then decide between a separate instruction and an answer outside the proofreader's dialog; the second option changes `ProofreadingSession`.
- Clarification. A new version changes only what the clarification is about. The user's words aren't replaced with words from the clarification, and with Errors Only even less so (real-06, dialog-05).
- Meaning over frequency: `noted` → `noticed`, `as soon as possible` instead of "soon", `today's PR 420`.
- Names. One name is spelled the same way throughout the text (`Pria` / `Priya`). The "Never change" dictionary is also a spelling hint: a similar but different spelling of a dictionary term is corrected to the dictionary's.
- Tones and formality. The tone in Fix is one line, `Tone: friendly.`, and the rules "don't rewrite correct sentences" and "keep the author's words" outweigh it: Friendly doesn't change "Check the docs before asking" with any model, Concise shortens only with Luna. Describe the tones in fragments. Formality from Context (`formal`, a manager) should remove `gonna`.

#### Package 21: explanations and the diff

- Explain. Optional points (a comma before `and` in a list) are `style`, and the explanation shouldn't present them as a rule. We compare explanation models with the same fix model: `cyrano-eval fix` gets a separate model choice for Explain.
- Diff. Don't merge changes across a paragraph boundary (04 §2).
- A recommendation for the user. From the tables of packages 19–21: which model to choose for each operation (context reading, the check and the dialog, explanations) and why: quality, speed, usage. In the README, next to the model choice in Settings.

### Postponed ideas

Notes so we don't forget; none of them is a task yet.

- How the other person relates to the user (manager, client) is often impossible to tell from a screenshot: Teams shows no job title. Postponed to later versions; for now Context doesn't infer it, and the user adds it. Decided 2026-11-03.
- The message the user is replying to can't be taken whole from a screenshot: often only part of it is on the screen. For now it's pasted into Context by hand when needed. If the description of the situation (packages 13 and 19) isn't enough, look into reading the conversation through Accessibility: Chrome exposes page text, but every app has its own element tree.
- The dictionary is JSON (02 M11). If we need to keep a history of checks to come back to, move to SQLite; decided 2026-10-29.

## Releases

The release procedure, rules and distribution decisions are in [releases.md](releases.md). Package 15 finishes what's described there in the Distribution section.

## What works

- The ⌥⌘G hotkey (configurable) → the text from the selection or the whole field (Accessibility or ⌘C of an explicit selection, without ⌘A and without reading from a screenshot — 02 C2) → the panel next to the field with Context open → Check next to the dialog field → a streamed check → the Version 1 card with highlighting and explanations.
- Context from a screenshot (02 C6): if the text was taken from an app window, the context-reading model (`gpt-6-luna` by default) describes the conversation from the window screenshot — who with, the language, what about, the format (a reply, a follow-up, a new topic), style, formality — and fills Context with lines, without copying messages; it puts the conversation's language into the language pop-up if the user hasn't chosen one. Check waits up to 20 s; the reading status is next to the Context title: seconds, Skip, "No conversation found", a timeout or an error with Try Again; Skip and typing in Context cancel the call. The toggle is in Settings → General and in onboarding. The eval is `cyrano-eval context`: 13 synthetic windows in `evals/context/` and 6 real ones in `evals/private/context/` (outside git), 13/13 and 6/6 on Luna (04 §5).
- The fix eval is `cyrano-eval fix evals/fix/cases.json [model]`: 49 cases (9 real), the full panel flow — Fix, Explain, the dialog; the agent grades the report, disputed cases go to the user. Sol 42/49, Luna 41/49, Terra 41/49 (04 §5).
- "Text to check" can be edited before the first check; if no text was captured (desktop, Finder), the panel opens with an empty card. Check Text… and Check Clipboard open the same panel; there's no separate window.
- The panel's height follows its content up to 70% of the screen height, after that only the feed scrolls; it grows downwards with the top edge in place.
- The header: type, tone, level, output language; a change rechecks the latest version. Type, tone and level are remembered for the app, the language isn't: the panel opens with "Auto". What's remembered is visible in Settings → Style → Per-app defaults; deleting a row brings back Message · Neutral · Fluency.
- TipKit tips in the panel: Context, 📷, the dialog field, one at a time, until they're closed or done.
- Context is input only: a field above the feed, open before the first check, collapsed on a request; a click on the line expands it.
- One button next to the dialog field: Check before the first check and when the context has changed while the field is empty (a recheck); otherwise Send, and the message goes together with the current context. The dialog field appears after the first check. The indicator is one number of tokens.
- Images in Context: 📷 captures the source app's window (before the first Screen Recording request, an explanation line), ⌘V pastes an image or an image file in any layout and with any focus in the panel, files and images can be dragged onto the panel. Thumbnails with ✕; after 10 images a caption warns about speed and usage. A click or Space on a thumbnail opens Quick Look. The images go in the first message of every Fix request.
- The dialog: a question → an answer as a bubble, a request → a new card.
- The card: Copy (the default on the latest one), the list of changes with reasons, rejecting a change locally.
- The "Never change" dictionary (02 M11): a right click on a selection in a version card or in "Text to check" gives Never Change “…” or Remove “…” from Dictionary (in "Text to check", above the text field's items: Cut, Copy, Paste, spelling); a right click on a change row of the latest card gives Never Change for each changed word: the change is rejected and the word added in one action. The status line "“…” added to Dictionary." with Undo. Terms found in the text go into the first Fix message as the line `Keep these words exactly as written: …` from the next request; a term from "Text to check" already on the first check. The file is `~/Library/Application Support/Cyrano/dictionary.json`.
- Errors: not signed in (a sign-in button and a retry), network, limit, "Copy Original".
- Models: `gpt-6.1-sol`, `gpt-6.1-terra`, `gpt-6-luna`; a separate choice for context reading (Luna by default), the check and the dialog (Sol), explanations (Sol). The classifier uses the check model.
- Onboarding in one window: sign-in, Accessibility, context from the window (a toggle and Screen Recording), the hotkey. Settings: General (menu, Launch at login, context reading, models, hotkey, permissions), Style (custom instructions, per-app defaults), Dictionary (search, adding, editing with a double click, deleting, import and export), Account.
- Menu bar: Check Text…, Check Clipboard, account, About, Settings, Quit. The app's own icon.

## Deviations from the spec

Only what the spec describes and the app doesn't do yet; each item has a package. Accepted simplifications go into the spec instead of here.

- The Settings → Prompts tab — package 12.
- Builds for users: Developer ID signing, `.dmg`, automatic updates — package 15.
