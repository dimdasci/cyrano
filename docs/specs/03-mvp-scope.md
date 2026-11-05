# 03. MVP scope

Status: agreed 2026-10-27. Revised: the engine is models through the ChatGPT subscription ([02](02-tech-decisions.md) T7).

## Positioning

A companion assistant for short communication, primarily in English but in any language: chat messages, emails, comments, short pieces of documentation. Long texts aren't a target scenario. Quality comes first: natural English, honest explanations and a dialog. That's why the check is done by a cloud model through the user's ChatGPT subscription.

## Scenarios

### S1. Check with the panel (main)

1. The user writes text in any app and presses the check hotkey (⌥⌘G by default).
2. The app takes the selected text or the whole field (AX → ⌘C of an explicit selection). It guesses nothing beyond that: if the text wasn't read, the panel opens with an empty field where the text is typed or pasted.
3. Next to the field, or in the center of the screen if the position is unknown, a panel appears with the captured text and the Context field open. If the text was taken from an app window, Cyrano captures that window and fills in Context itself: who takes part in the conversation and which message the user is replying to. This takes a few seconds; the result can be corrected, extended or supplemented with images. The text can be corrected before Check too. The check doesn't start by itself: the user presses Check at the bottom of the panel. The Context section has no check buttons. Then a progress indicator, then the corrected text with the diff highlighted and a list of explanations. A check without context would waste the limit, and once context arrived it would have to be repeated anyway.
4. In the panel you can:
   - choose the context type: Message · Email · Docs (saved separately for each app);
   - choose the tone (a preset) and check again;
   - paste context into the Context field (above the text): the message you're replying to, a piece of the conversation, an explanation ("complaint is the metric"). It's ordinary copy and paste, no separate permission needed;
   - press 📷: take a screenshot of the active window and add it as context; an image can also be pasted with ⌘V or dragged in, and a click opens a large preview. Changed context is taken into account on Check or together with the next message ([05](05-ui.md) §2.3a, §2.7);
   - reject a single change;
   - refine the result in a dialog (see S1a);
   - Copy in the card of the version you want, then the user pastes it; Esc closes.
5. If there are no changes, the panel shows "Looks good ✓" but stays open: you can go straight to the dialog.
6. The result is always only copied (02 C3).

### S1a. Refining in a dialog

The first result is a starting version, and the dialog takes it further. Below it the panel has a multi-line input field with a Send button (↩ inserts a line break), where you can:

- add context or a wish: "mention that the deadline is Friday", "make it softer, this is my manager", "shorter";
- offer your own version: paste or rewrite the text and ask to check it. The model then corrects this version;
- ask: "why "have" and not "has"?". The model answers briefly, the text doesn't change.

The panel works like a chat: every answer of the model is a card with a new version, with changes relative to the previous one and explanations; between the cards are the user's messages and the answers to questions. The history is the scrolling feed. Every card has its own Copy button. The context type, tone, screenshot and wishes from the dialog apply to all following steps. The dialog lives while the panel is open and isn't saved after it closes.

Usage is visible: the panel shows how many tokens the current dialog has used and whether the subscription limit is exhausted (M12 in [02](02-tech-decisions.md)).

The user can write in the dialog in any language. The output language is the conversation's language if it could be read from the window, otherwise the same as the source text; you can choose another target language (the pop-up in the panel header); with another language chosen, the model translates and corrects at the same time.

### S2. Menu bar

An icon in the menu bar: Check Text… (the same panel with empty text: type or paste → the result and the same dialog as in S1a), Settings, the ChatGPT sign-in and permissions status, Quit.

### S0. First launch

1. The "Continue with ChatGPT" screen → sign-in in the system browser → permission to spend the subscription limit (Plus or Pro).
2. Onboarding for the Accessibility permission.
3. A short hint about the hotkey.

## Context type (explicit choice)

| Type | What it changes in the model's instructions |
|---|---|
| Message | A conversational register is fine, no greetings or signatures, contractions (I'm, don't) and emoji are left alone, brevity |
| Email | Email structure, polite formulas; greetings and signatures aren't made up, but are corrected if present |
| Docs | Neutral technical style, precise terms; Markdown and code (`backticks`) are left alone |

Context type and tone are independent: the type answers "what kind of text is this", the tone sets how it should sound.

## Settings (MVP)

- Keyboard shortcut: the global "Check text" is configurable; inside the panel there are no shortcuts of its own (02 T6).
- Prompts: the built-in prompts of the pipeline, text types, tones and levels can be viewed and edited, "Restore Default" brings back the original.
- Models: `gpt-6.1-sol` (quality) · `gpt-6.1-terra` · `gpt-6-luna` (faster), separately for context reading, the check and explanations (02 M1).
- Account: who is signed in, sign out.
- Tone: Neutral · Casual · Friendly · Professional · Concise.
- Level of intervention: Fix errors only · Improve fluency (default) · Rewrite.
- Custom instructions: free text.
- Dictionary ("Never change"): names, terms, slang. Filled in along the way: select a word in the panel → Never Change. A separate Settings tab with search, import and export. Only words found in the text go to the model.
- Output language: by default the same as the source text; changed only in the panel and remembered for the app.
- Explanations in English, one short line per change. Style changes are shown separately from errors.

## Outside the MVP

- Reading chat history through AX.
- Local models and working offline.
- History of checks, statistics.
- macOS Services, detecting the context type automatically from the app.

## Acceptance criteria

1. Capture and replacement work in: Safari, Chrome, Slack, Telegram, Mail, Notes, Messages. If replacement is impossible, the result is copied to the clipboard with a clear message.
2. Time from the hotkey to the corrected text for a message of up to 60 words: median ≤ 5 s on `gpt-6.1-sol`. Explanations may load after the text.
3. The user's clipboard is restored after the operation.
4. Without a ChatGPT sign-in, without network, with an exhausted limit or without permissions, a clear screen with instructions is shown, and the source text isn't lost.
5. The eval set (≥ 30 examples) passes without regressions: the model doesn't change the meaning, doesn't touch "do-not-change" words, answers questions in the dialog instead of editing them.
6. Network requests go only to `auth.openai.com` and `api.openai.com`, tokens are stored only in Keychain.
7. The token refreshes without signing in again; after access is revoked, the app returns to the sign-in screen.
