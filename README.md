# ai-skills

A collection of AI agent skills for various use cases, following the [agentskills.io](https://agentskills.io) standard.

## Structure

- `skills/` — published skills, one directory per skill.
- `template/` — starter skill to copy when authoring a new one.

## What is a skill?

A skill is a directory containing a `SKILL.md` file with YAML frontmatter
(`name`, `description`) and Markdown instructions. Claude loads the `description`
to decide when the skill applies, then reads the body on demand. Skills may
bundle extra files (scripts, references, assets) alongside `SKILL.md`.

## Authoring a skill

1. Copy `template/` to `skills/<your-skill-name>/`.
2. Edit `SKILL.md` frontmatter and body.
3. Keep the `description` specific — it is the only text used for triggering.

## Frontmatter fields

| Field | Required | Notes |
|-------|----------|-------|
| `name` | yes | kebab-case, matches directory name |
| `description` | yes | when to use the skill + what it does |
| `license` | no | SPDX identifier |
| `allowed-tools` | no | restrict tools the skill may call |
