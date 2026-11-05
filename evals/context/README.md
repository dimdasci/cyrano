# Synthetic windows for the context eval

Cases for reading context from a screenshot ([04 §4.5, §5](../../docs/specs/04-prompts.md)). The names, companies and conversations are made up, so the set lives in the repository. Real screenshots are in `evals/private/context/`, outside git.

- `cases.json` — the cases: a window, a draft (`text`), the target context (`target`, for reading by eye) and checks (`expect`).
- `templates/` — HTML window templates: `mail.html` (webmail: folders, message list, message, reply), `chat.html` (messenger: `work` and `personal` themes, a channel thread on the right). The shared window frame, notifications and avatars are in `common.css` and `common.js`. A template draws the window with the function `render(data, draft)`; the draft goes into the input field by itself.
- `cases/` — window data, one file per window; one file can serve several cases with different drafts.

The windows are deliberately dense and noisy, like real ones: small font, sidebars, banners, long messages cut off, other conversations next to the one that matters.

Run from the repository root (build with `swift build --package-path Packages/CyranoCore --product cyrano-eval`):

```bash
Packages/CyranoCore/.build/debug/cyrano-eval context evals/context/cases.json [gpt-6-luna|gpt-6.1-sol|gpt-6.1-terra]
Packages/CyranoCore/.build/debug/cyrano-eval render evals/context/cases.json <folder>
```

`context` draws each window into a PNG at Retina density (1440 × 900 points by default), reads the context with the same code as the app's panel (`ProofreadingSession.readContext`, with a 60 s timeout instead of 20) and prints the Context, the language the pop-up would switch to, the time and the result of the checks. No answer (an error or a timeout) shows as `ERROR`, so it can't be mistaken for an empty Context. `render` only saves the images, to see a window the way the model sees it. The first `context` run asks for access to Cyrano's Keychain item.
