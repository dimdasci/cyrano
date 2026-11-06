# Synthetic windows for the context eval

Cases for reading context from a screenshot ([04 §4.5, §5.1](../../docs/specs/04-prompts.md)). The names, companies and conversations are made up, so the set lives in the repository. Real screenshots are in `evals/private/context/`, outside git.

- `cases.json` — the cases: a window, a draft (`text`), the target context (`target`, for reading by eye) and checks (`expect`).
- `templates/` — HTML window templates: `mail.html` (webmail: folders, message list, message, reply), `chat.html` (messenger: `work` and `personal` themes, a channel thread on the right). The shared window frame, notifications and avatars are in `common.css` and `common.js`. A template draws the window with the function `render(data, draft)`; the draft goes into the input field by itself.
- `cases/` — window data, one file per window; one file can serve several cases with different drafts.

The windows are deliberately dense and noisy, like real ones, because a clean mockup is easier for the model to read than a real window. The templates resemble kinds of apps without copying any particular product; their layout and noise come from the user's live windows in `evals/private/context/reference/`, with the content left out.

- density: an 11–13 pt font, several panes, button ribbons, banners ("External sender"), long signatures with addresses and disclaimers;
- cropping: a long email visible only in the middle or at the end, the sender's header scrolled away, the reply window over half the thread, a collapsed quote;
- mixing: other threads in the list, some with the same person and a similar subject; a calendar reminder or another chat's notification over the window; a second draft in Drafts; an older conversation on another topic above today's question;
- languages: the conversation in one language, the draft in another, previews in a third.

The situations the set is built around; mail gets the most, because there the whole conversation is almost never visible:

| # | Situation | What it checks |
|---|---|---|
| 1 | A reply to a long email, only the last part visible | a description from To, the subject, the sender and the signature, without quotes |
| 2 | Reply all: many recipients in To and Cc | who the draft is to; doesn't copy the long list |
| 3 | Forwarding: a draft to a new person about someone else's email | the addressee is the person it's forwarded to |
| 4 | Several threads with the same person in the list | picks the thread by the subject of the reply window |
| 5 | A new email, no thread | only the recipient and the subject; doesn't make up a conversation |
| 6 | The reply window separate from the thread (pop-out) | little data; the model doesn't fill in the gaps |
| 7 | A team channel, a thread reply to one person | who is being answered, rather than all the channel members |
| 8 | A 1:1 chat, previous messages fully visible | topic and tone from a short exchange, without retelling |
| 9 | A long chat message cut off; another chat's notification on top | the notification doesn't get into the context |
| 10 | A personal conversation in Russian | names as on the screen, informal tone, the description in English |
| 11 | An email to a manager or a client; the job title only in the signature | the title as in the signature; doesn't infer the relation to the user |
| 12 | A ticket or a PR review | technical context, the participants' roles |
| 13 | A document or a note without a conversation | empty, or a description of the document without a counterpart |
| 14 | An old conversation on another topic above, a new question today | About is today's question |
| 15 | A chat in Spanish with a photo of text in the feed; previews in Russian and English | Language is Spanish, the description in English |
| 16 | A draft with an account number and a link | neither the number nor the link is in the context |
| 17 | The last messages are one's own, unanswered; the draft is about something new | a new topic: the old messages don't go into About |
| 18 | The same screen, the draft follows up on yesterday's question | a follow-up: About is what that question was about |

A check looks only for what's explicit: the kind of conversation, the needed names and the topic are there; fragments of messages, the draft and other conversations aren't; for a window unrelated to the draft, Context is empty. A check that needs one wording fails correct answers ("contract" matched "contractions", "weekly" failed an answer that named the meeting), so check names and facts instead. The agent grades the report by eye, clear errors only: a check that failed a correct answer doesn't count, and a clear error the checks missed does. Results are in 04 §5.1.

Run from the repository root (build with `swift build --package-path Packages/CyranoCore --product cyrano-eval`):

```bash
Packages/CyranoCore/.build/debug/cyrano-eval context evals/context/cases.json [gpt-6-luna|gpt-6.1-sol|gpt-6.1-terra]
Packages/CyranoCore/.build/debug/cyrano-eval render evals/context/cases.json <folder>
```

`context` draws each window into a PNG at Retina density (1440 × 900 points by default), reads the context with the same code as the app's panel (`ProofreadingSession.readContext`, with a 60 s timeout instead of 20) and prints the Context, the language the pop-up would switch to, the time and the result of the checks. No answer (an error or a timeout) shows as `ERROR`, so it can't be mistaken for an empty Context. `render` only saves the images, to see a window the way the model sees it. The first `context` run asks for access to Cyrano's Keychain item.
