---
name: email-accessibility-checker
description: Analyze email HTML for accessibility issues, combining mechanical rule-based checks (lang/dir attributes, alt text, contrast ratios, heading structure, VML, tables, landmarks) with judgment-based analysis (alt text quality, semantic structure, link text quality, visual/interaction concerns like touch targets and font size). Use this skill whenever the user shares email HTML/markup and asks for an accessibility review, audit, or check, or mentions WCAG compliance, screen reader compatibility, alt text, color contrast, or heading structure in the context of email. Also trigger for requests like "is this email accessible" or "check this email for a11y issues."
---

# Email Accessibility Checker

Analyze email HTML for accessibility issues. Combines mechanical rule-based checks with judgment-based analysis to catch issues that rules alone miss.

**Token efficiency:** Only report issues found. Do not list passing checks or clean elements. If the email is long, prioritize critical and serious issues first.

**Severity must reflect impact, not fix complexity.** Assign severity based on how much the issue affects people using assistive technology — not how easy it is to fix. A finding described as "invisible", "unreadable", or "critically low contrast" must never be assigned mild or moderate. If the language you use to describe the problem contradicts the severity label, the label is wrong.

## Workflow

### Step 1: Get the HTML

Obtain the final email HTML to analyze. This may be provided directly by the user, read from a file, or fetched from an API.

**Before scanning:** Rendered HTML often splits element attributes across multiple lines. Before running any checks, flatten the HTML so each opening tag is a single logical line — attributes on continuation lines will be silently missed by line-by-line grep patterns. When using shell tools, collapse newlines within tags before grepping (e.g. `tr '\n' ' '` then `sed 's/  */ /g'`). When analyzing directly, always read the complete opening tag and its full text content before evaluating.

### Step 2: Rule-based checks

Scan the HTML for these mechanical pass/fail issues. Severities: **critical** > **serious** > **moderate** > **mild**.

#### Document structure

| Severity | Rule | Details |
|----------|------|---------|
| serious | `<html>` must have a valid `lang` attribute | e.g. `lang="en"`. Check the value is a valid BCP 47 language tag. `lang="und"` (undetermined) is valid and not a failure — but recommend setting a specific language for better screen reader pronunciation. |
| serious | Body content wrappers must have `lang` and `dir` | Email clients often strip `<html>`, so direct children of `<body>` (excluding empty elements, `<style>`, `<script>`, and `<img alt="">`) need their own `lang` and `dir` attributes. If `lang` and `dir` are present but set to generic values (`lang="und"`, `dir="auto"`), do not flag as a failure — instead note as a **recommendation** (mild) to set specific values for better assistive technology support. |
| serious | `dir` must be `ltr`, `rtl`, or `auto` | Flag any other value. `dir="auto"` is valid — recommend setting an explicit direction only as a mild improvement. |
| serious | Document should have a `<title>` element if the email has a view in browser link | Title is used for navigation on hosted version of the email. |
| critical | `<meta name="viewport">` must not disable zoom | Flag `maximum-scale=1`, `user-scalable=no`, or `user-scalable=0`. |

#### Headings

| Severity | Rule |
|----------|------|
| mild | Email should contain at least one `<h1>` (if it has structured content) |
| moderate | Email should have no more than one `<h1>` |
| moderate | Heading levels must be sequential — no skipping (e.g. `<h1>` then `<h3>`) |
| mild | Headings must have visible text content |

#### Images

| Severity | Rule |
|----------|------|
| critical | `<img>` elements must have an `alt` attribute (can be empty for decorative images) |
| mild | `alt` text should not repeat adjacent visible text |
| serious | Elements with `role="img"` and `<svg>` with img/graphics-document role must have accessible text |

#### Links

| Severity | Rule |
|----------|------|
| serious | Links must have discernible text (not empty or whitespace-only), this is a common issue for linked images without alt text |
| moderate | Link text should be descriptive — flag "here", "click here" and similar |
| critical | Links must not use `role="button"` — breaks assistive technology link menus |

#### Tables

| Severity | Rule |
|----------|------|
| serious | Layout tables must have `role="none"` or `role="presentation"` — without it, screen readers announce every cell. Only data tables (with `<th>`, `<thead>`, etc.) should omit the role. |

#### HTML5 elements and landmarks

HTML5 landmark elements have inconsistent support across email clients. Two different concerns apply here:

**Rendering compatibility** — `<article>`, `<section>`, and `<nav>` render inconsistently across clients. Using a `<div>` with the equivalent ARIA role gives the same semantics with a cleaner fallback where the element itself isn't supported. Flag these as rendering recommendations, not accessibility failures.

| Severity | Rule |
|----------|------|
| mild | Use `<div role="article">` instead of `<article>` — for wider client support and cleaner fallback |
| mild | Use `<div role="region">` instead of `<section>` — for wider client support and cleaner fallback |
| mild | Use `<div role="navigation">` instead of `<nav>` — for wider client support and cleaner fallback |

**Accessibility conflicts** — email clients already contain their own `header`/`footer`/`main`/`aside` landmarks. Duplicating them inside the email creates conflicting or redundant landmarks for screen reader users navigating by landmark.

| Severity | Rule |
|----------|------|
| moderate | Avoid `<header>` or `[role=banner]` — email client already has one |
| moderate | Avoid `<footer>` or `[role=contentinfo]` — email client already has one |
| moderate | Avoid `<main>` or `[role=main]` — email client already has one |
| moderate | Avoid `<aside>` or `[role=complementary]` — email client already has one |

#### Lists and IDs

| Severity | Rule |
|----------|------|
| serious | `<li>` must be inside `<ul>` or `<ol>`; `<dt>`/`<dd>` inside `<dl>` |
| mild | `id` attribute values must be unique across the document |

#### VML

| Severity | Rule |
|----------|------|
| critical | VML shapes (`v:rect`, `v:roundrect`, `v:oval`, `v:image`, `v:shape`, `v:group`, `v:line`, `v:polyline`, `v:curve`, `v:arc`) must have an `alt` attribute |
| critical | VML must not contain links — they are not keyboard-accessible |
| moderate | VML must not contain headings — they are not usable in some screen readers |

#### Color contrast (inline styles only)

When both text color and background color are explicitly set in inline styles on an element or its direct parent, check the WCAG AA contrast ratio: 4.5:1 for normal text, 3:1 for large text (18px+ bold or 24px+). Report the foreground color, background color, computed ratio, and required ratio.

**Contrast failure severity** (based on how far the ratio falls below the required threshold):
- **Critical** — ratio below 2:1 regardless of text size (effectively invisible to low-vision users)
- **Serious** — ratio is 2:1 or above but more than 1.5 points below the required threshold (e.g. required 4.5:1, actual below 3:1)
- **Moderate** — ratio fails but is within 1.5 points of the required threshold (e.g. required 4.5:1, actual 3:1–4.4:1; required 3:1, actual 2:1–2.9:1)

**Limitation:** This only catches contrast issues where colors are explicitly set in inline styles. Inherited, cascading, or computed styles cannot be evaluated. Note this limitation in the report.

**Optional: computed-style check via browser rendering.** If the Claude in Chrome connector is available, this limitation can be partly closed:

1. Load the email HTML in the browser (e.g. a local file or data URL).
2. For each text-containing element, read the computed `color` and `background-color` via JavaScript (walking up the tree for the effective background if the element itself is transparent).
3. Run the same WCAG AA contrast checks and severity thresholds as above against these resolved values, in addition to the inline-style pass.

Only do this if the connector is already available — don't prompt the user to connect it just for this step. If used, still include a caveat in the report: a browser's computed styles reflect standard CSS cascade behavior, not how a specific email client renders the message. Clients like Outlook (Word rendering engine) and Gmail (which strips `<style>` blocks and rewrites some CSS) can resolve colors differently, and dark-mode remapping in clients like Apple Mail or Outlook isn't captured by a standard browser render. Frame findings from this step as "likely" issues to verify with client testing, not confirmed failures.

### Step 3: Judgment-based analysis

These checks require understanding content and context — they can't be reduced to mechanical rules.

#### 3a. Image alt text quality

By default, you cannot see images — perform text-based checks only. Do not guess what images depict based on URLs or filenames.

**Optional: verifying alt text against actual image content.** Only attempt this if the user explicitly asks for it (e.g. "you can view the images" or "check the alt text against the actual images"). Don't offer or attempt it by default, and don't attempt it just because a viewing tool happens to be available.

If requested, and a way to view the image is available (`web_fetch` on the `src` URL, or Claude in Chrome navigating to it and taking a screenshot):

1. Attempt a fetch/view for each `img src`, one at a time.
2. **Only describe or evaluate an image's actual content if a tool call for that exact URL returned a viewable result in this run.** Never infer, assume, or reconstruct what an image shows from its filename, alt text, surrounding copy, or general plausibility — that is a guess, not a view, and must not be reported as one.
3. For each image, report explicitly whether it was viewed: e.g. "Viewed — alt text says X, image shows Y" vs "Not viewed — [reason: fetch failed / blocked domain / dynamic src / not attempted]". A reader should never be unsure whether a given finding came from real inspection or text-only inference.
4. Expect failures to be common: tracking pixels, personalized/templated `src` values (e.g. `{{product_image}}`), signed CDN URLs, and blocked domains often won't resolve. When a fetch fails, fall back to the standard text-only check for that image and say so — don't retry indefinitely or substitute a guess.
5. This can be tool-call-heavy for emails with many images. If there are more than ~10 images, ask the user whether to view all of them or a prioritized subset (e.g. hero images and any images the text-only check already flagged as suspicious).

For each `<img>` in the email (text-only checks, always performed):

1. **Empty alt (`alt=""`) is correct for decorative images** — don't flag it. Note that the user should verify the image is truly decorative.
2. **Read alt in context** — for each image, read the `alt` together with surrounding copy (headings, body text, captions, link labels). Does the alt make sense alongside that content? Flag when it contradicts nearby text, repeats what is already stated without describing what the image *shows*, or would sound confusing when a screen reader reads the image description and adjacent content in sequence.
3. **Flag low-quality alt text patterns:**
   - Filename-as-alt: `alt="IMG_2847.jpg"`, `alt="hero-banner-final-v2.png"`
   - Generic: `alt="image"`, `alt="logo"`, `alt="icon"`, `alt="banner"`
   - Redundant with surrounding text: if adjacent text says "Nike Air Max 90" and the alt is identical, the alt should describe what the image *shows*
4. **Dynamic image URLs** — if `src` contains template variables (e.g. `{{product_image}}`), note these can't be checked and advise ensuring alt text is also dynamic or provides a meaningful generic description.

#### 3b. Semantic structure

Look at the content and identify elements marked up incorrectly for their purpose.

- **Text that should be a heading but isn't** — check two independent signals, either is enough to flag:
  - *Styling signal:* visually styled as a heading (large, bold, introducing a section) but is a `<p>`, `<span>`, or `<td>`. Check `font-size` and `font-weight` in inline styles.
  - *Content signal:* a short standalone line that reads like a heading regardless of styling — no terminal punctuation (no `.`, `,`, `!`, `?`), sits on its own line/block, and introduces the content that follows (e.g. "Order Confirmation", "What happens next", "Your account details"). A line ending in a full stop is very unlikely to be a heading even if short.
  
  Report the element, its text content, current markup, and suggest the appropriate heading level.
- **Content that should be a list but isn't** — series of items as separate paragraphs or `<br>`-separated lines. Also check for manual list markers at the start of lines — `*`, `-`, `•`, `&bull;`, numbers like `1.`/`1)`, or letters like `a.` — which are a strong signal the content is a list even without visual separation. Suggest converting to a `<ul>` or `<ol>` with `<li>` elements.
- **Data that should be in a table** — structured data (order summaries, pricing) in layout hacks. Suggest a proper `<table>` with `<th>` headers. Layout tables should have `role="presentation"` — only data tables use default semantics.
- **Headings used for styling** — heading elements used for bold/large text when the content isn't actually a heading. Suggest styled paragraphs instead.

#### 3c. Link text quality

Evaluate whether link text describes the destination or action. The rule-based checks (Step 2) catch exact matches like "click here" — your job is to apply broader judgment.

- **Non-descriptive text:** Flag links whose text wouldn't make sense read out of context (screen reader users navigate by listing all links). This includes "read more", "learn more", "find out more", "see details", "continue", "tap here", and similar. Suggest descriptive replacements.
- **Duplicate text, different destinations:** Group links by visible text. For any group where links share text but point to different URLs, report all of them — screen reader users can't distinguish them. E.g., three "Shop now" links going to different categories should say "Shop men's", "Shop women's", "Shop accessories."

#### 3d. Visual and interaction concerns

Examine styles and layout for issues that pass mechanical checks but create real usability problems.

**Font size:** Body text below 14px is a concern; secondary text (footers, disclaimers) below 10px is critical. Check for responsive overrides — if it scales up on mobile, note that.

**Touch targets:** Links and buttons should have at least 44x44px tap area (WCAG 2.5.5). Flag short text links, closely spaced links (e.g. footer nav with `|` separators), and small icon links. Consider padding in your assessment.

**Center-aligned long text:** Flag center-aligned blocks likely to exceed 3 lines at mobile widths (~320px) — the ragged left edge hurts readability, especially for people with dyslexia. Check for responsive overrides that switch to left-align on small screens.

**Borderline contrast:** Flag color combinations that are hard to read in practice even if they technically pass AA: light grey on white at body text size, similar-hue colored text on colored backgrounds, text over images or gradients. This supplements the inline-style contrast check in Step 2 — focus here on cases where contrast can't be computed mechanically (inherited colors, gradients, background images).

**Line height:** Body text with line-height below 1.5x its font-size is harder to read (WCAG 1.4.12). Headings can go down to 1.2x.

**Other checks — flag if present:**
- `text-align: justify` — irregular word spacing hurts readability
- Color as the only way to convey meaning (e.g. red for error, green for success) without a text/icon indicator
- Repeated emoji (3+ same) or dense emoji strings (5+) — report how a screen reader would announce them
- Full sentences/paragraphs in all-caps (short labels like "SALE" are fine, but should be done with CSS unless it's an acronym/initialism)
- Content in a different language than the email's `lang` without its own `lang` attribute
- Hidden preheader text that is visually hidden but still exposed to screen readers (e.g. via `font-size:0`, `max-height:0`, or `overflow:hidden`) — suggest using `display:none` instead, which hides it from both visual users and screen readers. The preheader has already served its purpose in the email client preview pane.
- CSS animations without `@media (prefers-reduced-motion: reduce)` fallback

### Step 4: Present results

Combine all findings into a single report. Write for a non-technical audience — avoid raw HTML tags, CSS property names, and code snippets in your explanations. Instead, describe issues in plain language referencing the visible content (e.g. "the 'Summer Sale' heading" not "`<h2>` element", "the hero image" not "`<img src='...'>`"). Only include code when showing a specific fix the user needs to apply.

1. **Issues grouped by severity** (critical → serious → moderate → mild) — each with: what the issue is, where in the email it occurs (describe the content/location), why it matters for people using assistive technology, and how to fix it
2. **Summary** — brief overall assessment: how accessible is this email, and what are the highest-priority fixes?
3. **Limitations disclaimer** — always note that AI-based accessibility testing is limited and cannot replace manual testing with assistive technologies such as screen readers. Recommend manual testing to catch issues that automated and AI analysis cannot detect.

Do not list passing checks. Do not duplicate findings — if the same element was caught by both a rule-based check and a judgment-based check, report it once with the combined context.
