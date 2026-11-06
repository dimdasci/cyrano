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
| 19 | Tuning the context-reading prompt: three models, a model recommendation for Context | Core | 04 §4.5, §5 | ✓ 0.8.0 |
| 20 | Tuning the Fix and dialog prompts by the package 17 eval: answering a question, clarification, meaning, names, tones; one dialog without the classifier, replies by a schema (a version or an answer), versions numbered by the app, the material in XML tags | Core + App | 02 M3, M5; 04 §1, §2, §4.1–4.3, §5; 05 §2.4, §2.8 | ✓ 0.9.0 |
| 21 | Tuning Explain and the diff: optional points are `style`, changes aren't merged across a paragraph; a model recommendation for the user | Core | 04 §2, §4.4, §5 | ✓ 0.10.0 |
| 22 | Never Change before the check: an item in the context menu of the "Text to check" card, the term applies from the first check | App | 05 §2.4 | ✓ 0.7.0 |
| 23 | Accessibility: every function works with VoiceOver and with the keyboard alone, in the panel, onboarding, Settings and the menu; VoiceOver announces new cards and answers, streaming is off with Reduce Motion, contrast holds with Increase Contrast; an audit of every screen with VoiceOver and Accessibility Inspector | App | 05 §7 | — |
| 24 | Account and the limit: Account shows the tokens of the app session, the "Manage app usage limit" link in Account and in the limit error | App | 05 §2.8, §5, §9 | — |
| 25 | Internationalization: the interface in English, Spanish (Castilian, castellano) and Russian, English for any other system language; a String Catalog with English as the source, so a language is added by translating it; texts built from numbers and names ("5 fixes", "“k8s” added to Dictionary.") go through the catalog's plural and format rules; explanations in the interface language; the rule "everything the user sees is in English" in CLAUDE.md changes | Core + App | 02 M7; 04 §4.4; 05 §6 | — |

## Next

Done: preview 0.1 (packages 1–9), releases are automated ([releases.md](releases.md)); package 11 — images as context; package 16 — capture without guessing and context from the window screenshot (Luna), one Check/Send button, Quick Look; package 10 — the "Never change" dictionary; package 14 — polish (panel height, tips, models per operation, the per-app table, Launch at login, the icon, Screen Recording in onboarding); package 13 — Context describes the conversation (who with, the language, what about, format, style, formality), the conversation's language goes into the language pop-up, the language is no longer tied to the app, the `cyrano-eval context` eval; package 17 — the `cyrano-eval fix` eval: 49 cases, three models, results in 04 §5.2, `evals/cloud-runner` removed; package 22 — Never Change in "Text to check": a term is protected before the first check; package 18 — the docs and the agent's texts are in English, the voice and formatting rules are in [style.md](style.md), the historical draft 01 is removed; the changelog and release notes for the user ([CHANGELOG.md](../CHANGELOG.md)), CI publishes the GitHub Release; package 19 — the context-reading prompt: in a channel only the person the draft answers, every field in English with names and job titles as on the screen, nothing from the draft in About, a short About without amounts and IDs; Sol and Terra pass every case in three runs, Luna sometimes returns only the name, and Terra becomes the default for Context: right on every case and the steadiest on time (04 §5.1); package 20 — the Fix and dialog prompts: a question gets an answer in words in the same dialog, a clarification changes only what it explains, `noted` stays, one spelling for a name, the dictionary as a spelling hint, Friendly and Concise change correct sentences, formal Context removes slang, a request after a translation keeps the language; Sol and Terra 49–51 of 51 in three runs, Luna 43–44, and the default stays Sol (04 §5.2); package 21 — Explain and the diff: a change no longer spans a line break, optional points (the serial comma, `data are`, a contraction spelled out) are `style` and read as a choice, while calques keep `wordChoice`; `cyrano-eval fix` takes a separate explanation model; with Sol fixing, Sol explains 77–78 of 78 cases and every held-out case in three runs, Terra 77–78, Luna 75–77, and the default for explanations stays Sol; the README recommends a model for each operation (04 §5.3). On 2026-10-28 the specs were reconciled with the app: accepted deviations moved into the specs, the panel no longer has shortcuts of its own (02 T6), the rest is in [Deviations from the spec](#deviations-from-the-spec). On 2026-11-05 all docs were checked against the app again: the specs now describe what the app does (the output language isn't remembered for the app, the result is only copied, the panel title carries the source, launching again opens onboarding, and smaller details), and what 05 describes but the app lacks went into packages 23 (accessibility) and 24 (Account).

Order, decided 2026-10-28:

1. A working version for daily use: packages 16 → 10 → 14. The user tries the scenarios in their own routine, so every package ends with a release (`scripts/release`): 16 — 0.3.0, 10 — 0.4.0, 14 — 0.5.0. Done.
2. Quality of fixes: 13 and 17 (eval), 22, 18, 19, 20 and 21 are done, next 12. 22 went first: without it a term couldn't be protected before the check, and that's a daily scenario. The translation (18) came before prompt tuning: 19–21 write to 04 and the plan, and there was no point translating their results twice. 19–21 tune the prompts one category per package, based on the evals from 13 and 17 (decided 2026-11-05: 17 only measures). 12, editable prompts, comes after tuning: by then the built-in values are final. Since package 20 one Fix template covers the check and every dialog message, so `prompts.json` gets Proofread, Explain Changes and Read Context.
3. Giving it to people: 23 → 15. Accessibility is always a priority (decided 2026-11-05): the app goes to people only when every function works with VoiceOver and the keyboard, and every new package keeps it that way.

Packages 24 and 25 have no place in the order yet.

One package is one branch from a fresh `main` and one PR. A release follows if the package has changes for the user.

### Next: package 12, editable prompts

Prompt tuning (packages 19–21) is done, so the built-in prompts are final for now: Fix (the check and the dialog), Explain and Read Context, with their results in 04 §5. Package 12 makes them editable in `prompts.json` and Settings → Prompts, with Restore Default (02 M8, 05 §5).

### Postponed ideas

Notes so we don't forget; none of them is a task yet.

- How the other person relates to the user (manager, client) is often impossible to tell from a screenshot: Teams shows no job title. Postponed to later versions; for now Context doesn't infer it, and the user adds it. Decided 2026-11-03.
- The message the user is replying to can't be taken whole from a screenshot: often only part of it is on the screen. For now it's pasted into Context by hand when needed. If the description of the situation (packages 13 and 19) isn't enough, look into reading the conversation through Accessibility: Chrome exposes page text, but every app has its own element tree.
- The dictionary is JSON (02 M11). If we need to keep a history of checks to come back to, move to SQLite; decided 2026-10-29.

## Releases

The release procedure, rules and distribution decisions are in [releases.md](releases.md). Package 15 finishes what's described there in the Distribution section.

## What works

- The ⌥⌘G hotkey (configurable) → the text from the selection or the whole field (Accessibility or ⌘C of an explicit selection, without ⌘A and without reading from a screenshot — 02 C2) → the panel next to the field with Context open → Check next to the dialog field → a streamed check → the Version 1 card with highlighting and explanations.
- Context from a screenshot (02 C6): if the text was taken from an app window, the context-reading model (`gpt-6.1-terra` by default) describes the conversation from the window screenshot — who with, the language, what about, the format (a reply, a follow-up, a new topic), style, formality — and fills Context with lines, without copying messages; it puts the conversation's language into the language pop-up if the user hasn't chosen one. Check waits up to 20 s; the reading status is next to the Context title: seconds, Skip, "No conversation found", a timeout or an error with Try Again; Skip and typing in Context cancel the call. The toggle is in Settings → General and in onboarding. The eval is `cyrano-eval context`: 13 synthetic windows in `evals/context/` and 6 real ones in `evals/private/context/` (outside git), 13/13 and 6/6 on Sol and Terra in three runs each, Luna 11–13 of 13 (04 §5.1).
- The fix eval is `cyrano-eval fix evals/fix/cases.json [model] [explanation model]`: 78 cases (9 real, 18 held out), the full panel flow — Fix, Explain, the dialog, four cases at a time; the report gives the Explain call's own time and tokens; the agent grades the report, disputed cases go to the user. After package 20, in two runs of the final prompt: Sol 67–68/70, Terra 65–68/70, Luna 58–60/70; after package 21, with Sol fixing, explanations right in 77–78/78 cases with Sol, 77–78 with Terra, 75–77 with Luna (04 §5.2, §5.3).
- "Text to check" can be edited before the first check; if no text was captured (desktop, Finder), the panel opens with an empty card. Check Text… and Check Clipboard open the same panel; there's no separate window.
- The panel's height follows its content up to 70% of the screen height, after that only the feed scrolls; it grows downwards with the top edge in place.
- The header: type, tone, level, output language; a change rechecks the latest version. Type, tone and level are remembered for the app, the language isn't: the panel opens with "Auto". What's remembered is visible in Settings → Style → Per-app defaults; deleting a row brings back Message · Neutral · Fluency.
- TipKit tips in the panel: Context, 📷, the dialog field, one at a time, until they're closed or done.
- Context is input only: a field above the feed, open before the first check, collapsed on a request; a click on the line expands it.
- One button next to the dialog field: Check before the first check and when the context has changed while the field is empty (a recheck); otherwise Send, and the message goes together with the current context. The dialog field appears after the first check. The indicator is one number of tokens.
- Images in Context: 📷 captures the source app's window (before the first Screen Recording request, an explanation line), ⌘V pastes an image or an image file in any layout and with any focus in the panel, files and images can be dragged onto the panel. Thumbnails with ✕; after 10 images a caption warns about speed and usage. A click or Space on a thumbnail opens Quick Look. The images go in the first message of every Fix request.
- The dialog: one Fix conversation for the whole panel. The model decides what a message asks for: an answer or a question back streams into a bubble, a request or a clarification gives the next numbered card. "Take version 2 and…" and "go back to the original" work; VoiceOver reads an answer when it's whole.
- The card: Copy (the default on the latest one), the list of changes with reasons, rejecting a change locally. Changes one word apart merge into one, but never across a line break; an optional point (the serial comma, `data are`) is marked as style and its reason reads as a choice.
- The "Never change" dictionary (02 M11): a right click on a selection in a version card or in "Text to check" gives Never Change “…” or Remove “…” from Dictionary (in "Text to check", above the text field's items: Cut, Copy, Paste, spelling); a right click on a change row of the latest card gives Never Change for each changed word: the change is rejected and the word added in one action. The status line "“…” added to Dictionary." with Undo. Terms found in the text go into the first Fix message as the line `Keep these words exactly as written: …` from the next request; a term from "Text to check" already on the first check. A word one or two letters off a term (`Pria` for `Priya`) goes into the same message as a spelling hint, and the check spells it as in the dictionary. The file is `~/Library/Application Support/Cyrano/dictionary.json`.
- Errors: not signed in (a sign-in button and a retry), network, limit, "Copy Original".
- Models: `gpt-6.1-sol`, `gpt-6.1-terra`, `gpt-6-luna`; a separate choice for context reading (Terra by default), the check and the dialog (Sol), explanations (Sol). Which to pick and why is in the README.
- Onboarding in one window: sign-in, Accessibility, context from the window (a toggle and Screen Recording), the hotkey. Settings: General (menu, Launch at login, context reading, models, hotkey, permissions), Style (custom instructions, per-app defaults), Dictionary (search, adding, editing with a double click, deleting, import and export), Account.
- Menu bar: Check Text…, Check Clipboard, account, About, Settings, Quit. The app's own icon.

## Deviations from the spec

Only what the spec describes and the app doesn't do yet; each item has a package. Accepted simplifications go into the spec instead of here.

- The Settings → Prompts tab — package 12.
- Accessibility: VoiceOver announcements of new cards (answers are announced) and the `log` region, streaming off with Reduce Motion, no audit of every screen yet (05 §7) — package 23.
- Account: the tokens of the app session and the "Manage app usage limit" link; the same link in the limit error (05 §2.8, §5) — package 24.
- The interface only in English, explanations only in English (05 §6, 02 M7) — package 25.
- Builds for users: Developer ID signing, `.dmg`, automatic updates — package 15.
