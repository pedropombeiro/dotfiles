# Language and grammar

Source: [Google Developer Documentation Style Guide](https://developers.google.com/style)

## Voice and tone

- Be conversational, friendly, respectful, and direct without being frivolous.
- Sound like a knowledgeable colleague who understands the reader's goal.
- Don't use `please` in instructions.
- Avoid cutesy language, pop-culture references, internet slang, exclamation
  marks, and claims that a task is easy, simple, or quick.
- Use common contractions such as `you're`, `don't`, and `can't` when they sound
  natural. Don't invent contractions or use uncommon three-word contractions.
- Address the reader as `you`. Use `user` only for a person who uses software
  that the reader develops.
- Use the imperative for instructions: `Click **Submit**.`

Recommended: `To view the document, click **View**.`

Not recommended: `To view the document, please click **View**.`

## Active voice and present tense

- Prefer active voice. Make the actor the subject.
- Use passive voice when the object matters more than the actor, when naming the
  actor would blame the reader, or when the actor is irrelevant.
- Use present tense for current and general behavior.
- Use future tense only for an action that genuinely occurs later.
- Avoid hypothetical `would` when present tense is accurate.

Recommended: `Send a query to the service. The server sends an acknowledgment.`

Not recommended: `The service is queried, and an acknowledgment is sent.`

## Sentence structure

- Put the circumstance, condition, location, or goal before the instruction.
- Keep the main subject and verb near the beginning.
- Use standard subject-verb-object order.
- Keep sentences short enough to scan. As an accessibility target, try to stay
  below 26 words.
- Avoid double negatives and exceptions to exceptions.
- Follow `this` and `these` with a noun when the reference could be ambiguous.
- Include optional relative pronouns such as `that` and `which` when they improve
  clarity or translation.
- Use `that` for restrictive clauses and `which`, preceded by a comma, for
  nonrestrictive clauses.

Recommended: `To delete the document, click **Delete**.`

Not recommended: `Click **Delete** if you want to delete the document.`

Recommended: `Set this value to true.`

Not recommended: `Set this to true.`

## Global audience

- Write in US English.
- Prefer simple words: `start`, `so`, and `use`, rather than `commence`,
  `consequently`, and `utilize`.
- Avoid idioms, colloquialisms, humor, sports references, holidays, and seasonal
  references.
- Avoid phrasal verbs when a single clear verb works. Common technical phrases
  such as `set up`, `log in`, and `sign in` are acceptable.
- Don't stack more than two noun modifiers before another noun. Rewrite long
  compound modifiers.
- Put `only` immediately before the word that it modifies.
- Use one term consistently for one concept.
- Use helper words such as `then`, `that`, and `of` when they prevent ambiguity.
- Use a qualifying noun with technical literals: `the example.yaml file`.
- Avoid directional words such as `above`, `below`, and `right-hand side`. Use
  `preceding`, `following`, or the UI label.

Recommended: `Request only one token.`

Not recommended: `Only request one token.`

## Inclusive language

- Use gender-neutral language and singular `they` when a person's gender is
  unknown or irrelevant.
- Use `person-hours`, not `man-hours`; use `humanity`, not `mankind`.
- Avoid ableist language such as `crazy`, `insane`, `blind to`, `cripple`,
  `dumb`, `lame`, `sanity check`, and `dummy variable`.
- Prefer precise alternatives such as `unexpected`, `complex`, `ignore`,
  `slows`, `quick check`, and `placeholder`.
- Avoid divisive technical terms such as `blacklist`, `whitelist`, `master` and
  `slave`, and `first-class citizen` when an accurate alternative exists.
- Prefer `allowlist` and `blocklist` as nouns. Rewrite verbs rather than using
  `allowlist` or `denylist` as verbs.
- Prefer relationship-specific pairs such as `primary/replica`,
  `controller/worker`, or `leader/follower`.
- If code contains a non-inclusive term, use code font, explain the preferred
  term on first use, and use the preferred term thereafter.
- Use community-preferred disability language. Don't describe nondisabled
  people as `normal` or use euphemisms such as `differently abled`.
- Use diverse names, genders, ages, and locations in examples.

Recommended: `Replace the placeholder with the appropriate value.`

Not recommended: `Replace the dummy variable with the appropriate value.`

## Jargon and claims

- Avoid jargon unless the audience understands it, readers search for it, or no
  precise plain-language alternative exists.
- Define an unfamiliar term on first use or link to a trusted definition.
- Don't attribute human intentions or emotions to software and hardware.
- Avoid superlatives and absolutes such as `best`, `fastest`, `always`, and
  `never` unless evidence proves the claim.
- Use `ensure` and `guarantee` only when the result is genuinely certain.
- Cite a source for performance and cost claims.
- Describe security as part of a strategy that `helps` or is `designed to`
  improve security. Don't promise that a product prevents every incident.
- Don't document or pre-announce future features without approval.
- Prefer timeless statements that don't depend on `currently`, `new`, `now`, or
  a release-relative date.

Recommended: `A Delimiter object specifies where to split a string.`

Not recommended: `A Delimiter object tells the splitter where a string should
be broken.`

## Abbreviations

- Spell out an unfamiliar abbreviation on first use, followed by the
  abbreviation in parentheses. Use the abbreviation thereafter.
- Italicize both forms when introducing an abbreviation in documentation that
  follows Google formatting: *Border Gateway Protocol* (*BGP*).
- Don't capitalize the spelled-out term unless it is a proper noun.
- Don't spell out widely understood forms when doing so doesn't improve
  comprehension. Examples include `AI`, `API`, `HTML`, `PDF`, `RAM`, `REST`,
  `URL`, and `USB`.
- Don't use `i.e.` or `e.g.`. Use `that is` and `for example`.
- Avoid `etc.` by making it clear that a list contains examples.
- Don't use an abbreviation as a verb.
- Don't insert periods into acronyms or initialisms.
- Choose `a` or `an` by the abbreviation's spoken sound.

Recommended: `Use SSH to log in to the remote shell.`

Not recommended: `SSH into the remote shell.`

## Grammar and capitalization

- Use sentence case for titles, headings, navigation, list items, and table
  content.
- Don't end a heading with a period.
- Avoid all caps and camel case unless an official name or code requires them.
- Include articles such as `a`, `an`, and `the`; don't omit them for brevity.
- Never use an apostrophe to form a plural: write `APIs`, not `API's`.
- Add a noun after a class or code name rather than pluralizing or making the
  code item possessive: `` `Intent` objects ``, not `` `Intent`s ``.
- Don't form a possessive from a product, feature, company trademark, or code
  item. Rewrite with `of` or make the name a modifier.
- A sentence can end with a preposition when that placement sounds natural.
- In API reference descriptions, use the third-person singular verb that states
  what the method does: `Creates a task`, not `Create a task`.
