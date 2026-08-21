# Code, interfaces, and links

Sources:

- [Google computer-interface guidance](https://developers.google.com/style#computer-interfaces)
- [Google linking guidance](https://developers.google.com/style#linking)

## Code in text

- Use backticks in Markdown and the `code` element in HTML for code-related
  literals.
- Use code font for filenames, paths, directories, extensions, commands,
  utilities, flags, environment variables, class names, methods, functions,
  attributes, values, data types, database elements, HTTP verbs and status
  codes, ports, IP addresses, package names, user input, and command output.
- Don't use code font for product, service, organization, or ordinary domain
  names unless the name appears as input, output, or another code entity.
- Don't put quotation marks around code font unless the quotation marks are part
  of the literal value.
- Add a descriptive noun after a code item. Don't pluralize it, make it
  possessive, or use it as an English verb.
- Omit a class qualifier from a method name unless readers need it to resolve
  ambiguity.
- Call an HTTP code a `status code`, not a `response code` or `error code`.

Recommended: `Send a POST request.`

Not recommended: `POST the data.`

Recommended: `` `Intent` objects ``

Not recommended: `` `Intent`s ``

## UI elements

- Put visible UI labels in bold: `Click **Save**.`
- Match the UI label's capitalization and wording exactly.
- Refer to an element by its label, not its color, shape, icon, or location.
- If a UI value is also a code literal, apply both bold and code formatting:
  `select **`my-net-2`**`.
- Put the location before the action: `In the **Network** list, select...`.
- For a menu path, use `>` between selections and bold each label.
- Use `click` for buttons, links, menu items, and other clickable controls. Use
  `select` for checkboxes, list items, and options. Use `enter` or `type` for
  text input.
- Don't document keyboard shortcuts unless the shortcut is the feature being
  documented.

Recommended: `Click **Notifications**.`

Not recommended: `Click the bell icon.`

## Code samples

- Introduce a code sample with a sentence that states what the sample does.
- End the introduction with a colon when the sample follows immediately.
- Use a fenced code block and specify the language when the renderer supports
  it.
- Follow the relevant language's code style. Don't change valid syntax to fit
  prose style.
- Keep lines at or below 80 characters when practical.
- Show omitted code with a language-appropriate comment. Don't use an ellipsis
  to represent omitted source code.
- Don't make an incomplete sample click-to-copy.
- Include only the code required for the task and make copied commands runnable
  after placeholder replacement.

## Command-line syntax

Use these conventions in reference syntax:

| Notation           | Meaning                                |
| ------------------ | -------------------------------------- |
| `[OPTION]`         | Optional item                          |
| `{ONE\|TWO}`       | Exactly one required choice            |
| `\|`               | Mutually exclusive choices             |
| `ITEM...`          | Repeatable item                        |
| `UPPER_SNAKE_CASE` | Placeholder                            |
| `\`                | Linux or Cloud Shell line continuation |
| `^`                | Windows line continuation              |
| `$`                | Shell prompt                           |

- Don't put brackets, braces, or ellipses inside placeholder formatting.
- Avoid syntax notation in click-to-copy commands. Show the recommended command
  and link to the reference for optional arguments.
- Break long commands before a flag or another logical boundary.
- End every continued line except the last with the platform's continuation
  character. Indent continuation lines by four spaces.
- Don't include the working directory before a shell prompt.
- Put input and output in separate code blocks.
- Show output only when readers need to copy a value or verify a result.
- Introduce approximate output with `The output is similar to the following:`.
- Use three periods on their own line to mark omitted command output.

## Placeholders

- Name placeholders with uppercase letters and underscores:
  `PROJECT_ID`, not `project-id`, `apiName`, or `YOUR_PROJECT_ID`.
- Use a descriptive name instead of `X` unless `x` is an established notation,
  such as an HTTP `2xx` status code.
- Explain each placeholder the first time it appears.
- After a command with one placeholder, write `Replace PLACEHOLDER with...`.
- After a command with several placeholders, write `Replace the following:` and
  list them in appearance order.
- Start each placeholder description with lowercase text after a colon.
- In Markdown prose, format an inline placeholder as _`PLACEHOLDER`_. Inside a
  fenced block, use plain `PLACEHOLDER` text because Markdown styling doesn't
  apply there.

## Links and cross-references

- Use short, unique, descriptive link text that makes sense without surrounding
  context.
- Put the most important words near the beginning of the link text.
- Link to the most relevant heading, not merely the top of a page.
- Don't use `click here`, `this document`, `this article`, `this link`, or a URL
  as link text.
- Don't repeat the same destination throughout a short page unless readers need
  another entry point.
- Introduce a standalone cross-reference with `For more information, see...`.
- Use `about`, not `on`, to state the subject of a cross-reference.
- Include both the expanded term and abbreviation in link text.
- Keep punctuation and quotation marks outside link text.
- Don't put a linked title in quotation marks.
- Explain unexpected behavior such as a download, email action, same-page jump,
  or a forced new tab.
- Let links open in the current tab unless a platform constraint requires
  otherwise.
- Don't use an external-link icon as the only indication that a link leaves the
  site.

Recommended: `For more information, see [Make headings into link targets].`

Not recommended: `For more information, see [this document].`

## Code references in GitLab prose

Pedro's convention, applied in issues, merge request descriptions, and review
comments. See the Formatting Preferences section of
[`writing-style.md`](../../../../.agents/docs/writing-style.md).

- Hyperlink a file, function, config key, or line range rather than only naming it.
- Pin the link to a commit SHA and include the line range, so it keeps pointing at
  the same code after the file changes.
- Link a branch only when the current state of that branch is the point.
- State the SHA in the prose when a document carries several permalinks.
- Check repository visibility first. Inline the snippet when the target is private.

Recommended:
`the [confidence criteria](https://gitlab.com/group/project/-/blob/b00832b9/path/prompt.jinja#L229-246) restrict this to two categories`

Not recommended: `the confidence criteria in prompt.jinja restrict this to two categories`

## Filenames and examples

- Use lowercase filenames unless a platform or established name requires
  another case.
- Separate words with hyphens rather than spaces or underscores when defining a
  new documentation filename.
- Include the extension when readers need it to identify or enter the file.
- Use `example.com`, `example.org`, and `example.net` for example domains.
- Use documentation ranges and reserved values for example IP addresses and
  identifiers.
- Use realistic, diverse names that don't imply a real person's data.
- Never put credentials, personal data, or production identifiers in examples.
