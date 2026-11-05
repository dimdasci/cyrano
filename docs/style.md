# Writing style

How we write the project docs, specs, the plan and texts for the agent. Everything is in English.

## Voice

A practitioner working through a question together with the reader. A section starts from the subject: an observation, a question or the problem at hand, then the context, the concrete differences and what they mean in practice. The aim is to give the reader enough to form their own judgment; once a choice is made, it's recorded briefly and definitely.

Tone. Calm, conversational, businesslike. Interest in new things, with a critical eye for promises and generalizations. Disagreement is direct and stays on the subject: say where the reasoning drifted and bring it back.

Language. Plain professional speech in connected paragraphs with explanations and qualifications, instead of a string of slogans. Specialist terms where they help. "I" marks a position, "we" invites the reader to look at it together. Cut repetition, split long sentences, keep the links between the thoughts. Side topics can be named once and left outside the scope.

Precision. Keep the difference between an observation and a claim, a possibility and an inevitability, an example and the main point. "We haven't seen it fail" must not become "it never fails". Keep meaningful caveats, and don't add doubt to every sentence either.

What not to add. Promotional tone, categorical forecasts, preaching, artificial drama. A comparison of options stays a comparison of options and doesn't turn into a ranking of winners. Simplify without erasing the differences between approaches.

Direct statements. Remove "not X but Y" when the negative part only amplifies the next statement, and check "not just", "much more than", "actually": a real difference must stand behind them. A contrast fits when it examines a position someone actually holds or a concrete difference; don't invent a misconception in order to refute it.

## Formatting

- Bold and italics only in rare cases, at most two per document, where nothing else works. Never for looks.
- No definitions by negation such as "A is not B". Explain A by what it is.

## In the docs

- Decisions keep their date: "decided 2026-11-05".
- References between documents use short forms: `04 §5` is section 5 of [specs/04-prompts.md](specs/04-prompts.md), `02 M8` is item M8 of [specs/02-tech-decisions.md](specs/02-tech-decisions.md). After renaming a heading, check the links to its anchor.
- Code, identifiers and interface strings are written exactly as in the app.
